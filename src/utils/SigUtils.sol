// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    bytes32 public constant OPYN_RFQ_TYPEHASH =
        keccak256(
            "OpynRfq(uint256 offerId, uint256 bidId, address signerAddress, address bidderAddress, address bidToken, address offerToken, uint256 bidAmount, uint256 sellAmount, uint256 nonce)"
        );

    struct OpynRfq {
        uint256 offerId;
        uint256 bidId;
        address signerAddress;
        address bidderAddress;
        address bidToken;
        address offerToken;
        uint256 bidAmount;
        uint256 sellAmount;
        uint256 nonce;
    }

    // computes the hash of a OpynRfq
    function getStructHash(OpynRfq memory _rfq)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    OPYN_RFQ_TYPEHASH,
                    _rfq.offerId,
                    _rfq.bidId,
                    _rfq.signerAddress,
                    _rfq.bidderAddress,
                    _rfq.bidToken,
                    _rfq.offerToken,
                    _rfq.bidAmount,
                    _rfq.sellAmount,
                    _rfq.nonce
                )
            );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(OpynRfq memory _rfq)
        public
        view
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    getStructHash(_rfq)
                )
            );
    }
}
