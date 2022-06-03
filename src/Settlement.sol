// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.13;

// interface
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
// contract
import {EIP712} from "@openzeppelin/utils/cryptography/draft-EIP712.sol";
// lib
import {Counters} from "@openzeppelin/utils/Counters.sol";
import {ECDSA} from "@openzeppelin/utils/cryptography/ECDSA.sol";

/// @title Settlement
/// @author Haythem Sellami
contract Settlement is EIP712 {
    using Counters for Counters.Counter;

    struct OrderData {
        uint256 bidId;
        address trader;
        address token;
        uint256 amount;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    bytes32 private constant _OPYN_RFQ_TYPEHASH =
        keccak256(
            "OpynRfq(uint256 bidId,address trader,address token,uint256 amount,uint256 nonce)"
        );

    mapping(address => Counters.Counter) private _nonces;

    constructor(string memory _version) EIP712("OPYN RFQ", _version) {}

    function settleRfq(OrderData memory _offerOrder, OrderData memory _bidOrder)
        external
    {
        // verify offer signature
        bytes32 structHash = keccak256(
            abi.encode(
                _OPYN_RFQ_TYPEHASH,
                _offerOrder.bidId,
                _offerOrder.trader,
                _offerOrder.token,
                _offerOrder.amount,
                _useNonce(_offerOrder.trader)
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address offerSigner = ECDSA.recover(hash, _offerOrder.v, _offerOrder.r, _offerOrder.s);
        require(offerSigner == _offerOrder.trader, "Invalid offer signature");

        // verify big signature
        structHash = keccak256(
            abi.encode(
                _OPYN_RFQ_TYPEHASH,
                _bidOrder.bidId,
                _bidOrder.trader,
                _bidOrder.token,
                _bidOrder.amount,
                _useNonce(_bidOrder.trader)
            )
        );
        hash = _hashTypedDataV4(structHash);
        address bidSigner = ECDSA.recover(hash, _bidOrder.v, _bidOrder.r, _bidOrder.s);
        require(bidSigner == _bidOrder.trader, "Invalid bid signature");        

        // transfer offer amount of offer token from offer trader to bid trader
        IERC20(_offerOrder.token).transferFrom(_offerOrder.trader, _bidOrder.trader, _offerOrder.amount);
        // transfer bid amount of bid token fro =m bid trader to offer trader
        IERC20(_bidOrder.token).transferFrom(_bidOrder.trader, _offerOrder.trader, _bidOrder.amount);
    }

    function nonces(address owner) external view returns (uint256) {
        return _nonces[owner].current();
    }

    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function _useNonce(address owner) internal returns (uint256 current) {
        Counters.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }
}
