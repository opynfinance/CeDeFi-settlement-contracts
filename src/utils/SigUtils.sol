// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    bytes32 private constant OPYN_RFQ_TYPEHASH =
        keccak256(
            "RFQ(uint256 offerId, address bidderAddress, uint256 bidId, address signerAddress, uint256 bidAmount, address offerToken, uint256 sellAmount, address bidToken, uint256 nonce)"
        );

    struct OpynRfq {
        uint256 offerId;
        address bidderAddress;
        uint256 bidId;
        address signerAddress;
        uint256 bidAmount;
        address offerToken;
        uint256 sellAmount;
        address bidToken;
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
                    _rfq.bidderAddress,
                    _rfq.bidId,
                    _rfq.signerAddress,
                    _rfq.bidAmount,
                    _rfq.offerToken,
                    _rfq.sellAmount,
                    _rfq.bidToken,
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
