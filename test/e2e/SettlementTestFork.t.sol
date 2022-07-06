pragma solidity 0.8.13;

// test dependency
import "@std/Test.sol";
import {SigUtils} from "../../src/utils/SigUtils.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {console} from "@std/console.sol";
import {Solenv} from "solenv/Solenv.sol";

// contract
import {Settlement} from "../../src/Settlement.sol";

/**
 * @notice Ropsten fork testing
 */
contract SettlementTestFork is Test {
    MockERC20 internal usdc;
    MockERC20 internal squeeth;
    SigUtils internal sigUtils;
    Settlement internal settlement;

    uint256 internal sellerPrivateKey;
    uint256 internal bidderPrivateKey;
    uint256 internal signerPrivateKey;
    address internal seller;
    address internal bidder;
    address internal signer;

    function setUp() public {
        Solenv.config();

        usdc = MockERC20(0x27415c30d8c87437BeCbd4f98474f26E712047f4);
        squeeth = MockERC20(0xa4222f78d23593e82Aa74742d25D06720DCa4ab7);
        settlement = Settlement(0xe2614be428D6B835110231028Ae70279f2e7ec17);
        sigUtils = new SigUtils(settlement.DOMAIN_SEPARATOR());

        sellerPrivateKey = vm.envUint("E2E_SELLER_PK");
        bidderPrivateKey = vm.envUint("E2E_BIDDER_PK");
        signerPrivateKey = vm.envUint("E2E_SIGNER_PK");
        seller = vm.addr(sellerPrivateKey);
        bidder = vm.addr(bidderPrivateKey);
        signer = vm.addr(signerPrivateKey);

        vm.prank(seller);
        squeeth.approve(address(settlement), type(uint256).max);
        vm.prank(bidder);
        usdc.approve(address(settlement), type(uint256).max);

        vm.label(seller, "Seller");
        vm.label(bidder, "Bidder");
        vm.label(address(sigUtils), "SigUtils");
        vm.label(address(settlement), "Settlement");
        vm.label(address(usdc), "USDC");
        vm.label(address(squeeth), "oSQTH");
    }

    function testCreateOffer() public {
        uint256 offerId = _createOffer(seller, address(squeeth), address(usdc), uint128(1000e6), uint128(1), 100);
        (address sellerAddr, address offerToken, address bidToken, uint128 minPrice, uint128 minBidSize) = settlement.getOfferDetails(offerId);

        assertEq(sellerAddr, seller);
        assertEq(offerToken, address(squeeth));
        assertEq(bidToken, address(usdc));
        assertEq(minPrice, uint128(1000e6));
        assertEq(minBidSize, uint128(1));
    }

    function testGetBidSigner() public {        
        uint256 offerId = _createOffer(seller, address(squeeth), address(usdc), uint128(1000e6), uint128(1e18), 10e18);

        // bidder signature vars
        uint8 v; 
        bytes32 r;
        bytes32 s;

        {
            // bidder signing bid
            SigUtils.OpynRfq memory bigSign = SigUtils.OpynRfq({
                offerId: offerId,
                bidId: 1,
                signerAddress: bidder,
                bidderAddress: bidder,
                bidToken: address(usdc),
                offerToken: address(squeeth),
                bidAmount: 10e18,
                sellAmount: 10e6,
                nonce: 0
            });
            bytes32 bidDigest = sigUtils.getTypedDataHash(bigSign);
            (v, r, s) = vm.sign(bidderPrivateKey, bidDigest);
        }

        Settlement.BidData memory bidData = Settlement.BidData({
            offerId: offerId,
            bidId: 1,
            signerAddress: bidder,
            bidderAddress: bidder,
            bidToken: address(usdc),
            offerToken: address(squeeth),
            bidAmount: 10e18,
            sellAmount: 10e6,
            nonce: 0,
            v: v,
            r: r,
            s: s
        });

        address signerAddr = settlement.getBidSigner(bidData);
        assertEq(signerAddr, bidder);
    }

    function _createOffer(    
        address _seller,
        address _offerToken,
        address _bidToken,
        uint128 _minPrice,
        uint128 _minBidSize,
        uint256 _totalSize
    ) internal returns (uint256) {
        vm.startPrank(_seller);
        uint256 offerId = settlement.createOffer(_offerToken, _bidToken, _minPrice, _minBidSize, _totalSize);
        vm.stopPrank();

        return offerId;
    }

    function _delegateToSigner(address _bidder, address _signer) internal {
        vm.prank(_bidder);
        settlement.delegateToSigner(_signer);
    }
}