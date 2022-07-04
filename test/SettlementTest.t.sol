pragma solidity 0.8.13;

// test dependency
import "@std/Test.sol";
import {SigUtils} from "../src/utils/SigUtils.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {console} from "@std/console.sol";

// contract
import {Settlement} from "../src/Settlement.sol";

contract SettlementTest is Test {
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
        usdc = new MockERC20("USDC", "USDC", 6);
        squeeth = new MockERC20("SQUEETH", "oSQTH", 18);
        settlement = new Settlement("1");
        sigUtils = new SigUtils(settlement.DOMAIN_SEPARATOR());

        sellerPrivateKey = 0xA11CE;
        bidderPrivateKey = 0xB0B;
        signerPrivateKey = 0x1337;
        seller = vm.addr(sellerPrivateKey);
        bidder = vm.addr(bidderPrivateKey);
        signer = vm.addr(signerPrivateKey);

        usdc.mint(bidder, 100000e6);
        squeeth.mint(seller, 10e18);

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

    function testSettleOffer() public {
        uint256 offerId = _createOffer(seller, address(squeeth), address(usdc), uint128(1000e6), uint128(1e18), 10e18);
        
        // bidder signature vars
        uint8 v; 
        bytes32 r;
        bytes32 s;

        {
            // bidder signing bid
            SigUtils.OpynRfq memory bigSign = SigUtils.OpynRfq({
                offerId: settlement.offersCounter(),
                bidId: 1,
                signerAddress: bidder,
                bidderAddress: bidder,
                bidToken: address(usdc),
                offerToken: address(squeeth),
                bidAmount: 10e18,
                sellAmount: 10000e6,
                nonce: settlement.nonces(bidder)
            });
            bytes32 bidDigest = sigUtils.getTypedDataHash(bigSign);
            (v, r, s) = vm.sign(bidderPrivateKey, bidDigest);

            console.logUint(v);
        }

        // constrcuting settleRfq() args
        Settlement.BidData memory bidData = Settlement.BidData({
            offerId: settlement.offersCounter(),
            bidId: 1,
            signerAddress: bidder,
            bidderAddress: bidder,
            bidToken: address(usdc),
            offerToken: address(squeeth),
            bidAmount: 10e18,
            sellAmount: 10000e6,
            v: v,
            r: r,
            s: s
        });

        assertEq(usdc.balanceOf(seller), 0);
        assertEq(squeeth.balanceOf(bidder), 0);

        // seller send settlement tx
        vm.startPrank(seller);
        settlement.settleOffer(offerId, bidData);
        vm.stopPrank();

        assertEq(settlement.nonces(bidder), 1);
        assertEq(usdc.balanceOf(seller), 10000e6);
        assertEq(squeeth.balanceOf(bidder), 10e18);
    }

    function testRevertInvalidBidSignature() public {
        uint256 offerId = _createOffer(seller, address(squeeth), address(usdc), uint128(1000e6), uint128(1e18), 10e18);

        // bidder signature vars
        uint8 v; 
        bytes32 r;
        bytes32 s;

        {
            // bidder signing bid
            SigUtils.OpynRfq memory bigSign = SigUtils.OpynRfq({
                offerId: settlement.offersCounter(),
                bidId: 1,
                signerAddress: bidder,
                bidderAddress: bidder,
                bidToken: address(usdc),
                offerToken: address(squeeth),
                bidAmount: 10e18,
                sellAmount: 10000e6,
                nonce: settlement.nonces(bidder)
            });
            bytes32 bidDigest = sigUtils.getTypedDataHash(bigSign);
            (v, r, s) = vm.sign(bidderPrivateKey, bidDigest);
        }

        // constrcuting settleRfq() args
        Settlement.BidData memory bidData = Settlement.BidData({
            offerId: settlement.offersCounter(),
            bidId: 10,
            signerAddress: bidder,
            bidderAddress: bidder,
            bidToken: address(usdc),
            offerToken: address(squeeth),
            bidAmount: 10e18,
            sellAmount: 200000e6,
            v: v,
            r: r,
            s: s
        });
        
        vm.startPrank(seller);
        vm.expectRevert("Invalid bid signature");
        settlement.settleOffer(offerId, bidData);
        vm.stopPrank();
    }

    function testRevertSignatureReplay() public {
        uint256 offerId = _createOffer(seller, address(squeeth), address(usdc), uint128(1000e6), uint128(1e18), 10e18);
        
        // bidder signature vars
        uint8 v; 
        bytes32 r;
        bytes32 s;

        {
            // bidder signing bid
            SigUtils.OpynRfq memory bigSign = SigUtils.OpynRfq({
                offerId: settlement.offersCounter(),
                bidId: 1,
                signerAddress: bidder,
                bidderAddress: bidder,
                bidToken: address(usdc),
                offerToken: address(squeeth),
                bidAmount: 10e18,
                sellAmount: 10000e6,
                nonce: settlement.nonces(bidder)
            });
            bytes32 bidDigest = sigUtils.getTypedDataHash(bigSign);
            (v, r, s) = vm.sign(bidderPrivateKey, bidDigest);
        }

        // constrcuting settleRfq() args
        Settlement.BidData memory bidData = Settlement.BidData({
            offerId: settlement.offersCounter(),
            bidId: 1,
            signerAddress: bidder,
            bidderAddress: bidder,
            bidToken: address(usdc),
            offerToken: address(squeeth),
            bidAmount: 10e18,
            sellAmount: 10000e6,
            v: v,
            r: r,
            s: s
        });

        assertEq(usdc.balanceOf(seller), 0);
        assertEq(squeeth.balanceOf(bidder), 0);

        // seller send settlement tx
        vm.startPrank(seller);
        settlement.settleOffer(offerId, bidData);
        vm.expectRevert("Invalid bid signature");
        settlement.settleOffer(offerId, bidData);
        vm.stopPrank();
    }

    function testRevertSettleOfferWithUnauthorizedSigner() public {
        uint256 offerId = _createOffer(seller, address(squeeth), address(usdc), uint128(1000e6), uint128(1e18), 10e18);
        
        // bidder signature vars
        uint8 v; 
        bytes32 r;
        bytes32 s;

        {
            // bidder signing bid
            SigUtils.OpynRfq memory bigSign = SigUtils.OpynRfq({
                offerId: settlement.offersCounter(),
                bidId: 1,
                signerAddress: signer,
                bidderAddress: bidder,
                bidToken: address(usdc),
                offerToken: address(squeeth),
                bidAmount: 10e18,
                sellAmount: 10000e6,
                nonce: settlement.nonces(bidder)
            });
            bytes32 bidDigest = sigUtils.getTypedDataHash(bigSign);
            (v, r, s) = vm.sign(signerPrivateKey, bidDigest);
        }

        // constrcuting settleRfq() args
        Settlement.BidData memory bidData = Settlement.BidData({
            offerId: settlement.offersCounter(),
            bidId: 1,
            signerAddress: signer,
            bidderAddress: bidder,
            bidToken: address(usdc),
            offerToken: address(squeeth),
            bidAmount: 10e18,
            sellAmount: 10000e6,
            v: v,
            r: r,
            s: s
        });

        assertEq(usdc.balanceOf(seller), 0);
        assertEq(squeeth.balanceOf(bidder), 0);

        // seller send settlement tx
        vm.startPrank(seller);
        vm.expectRevert("Invalid signer for bidder address");
        settlement.settleOffer(offerId, bidData);
        vm.stopPrank();
    }

    function testDelegateToSigner() public {
        _delegateToSigner(bidder, signer);

        address bidderDelegator = settlement.bidderDelegator(bidder);
        assertEq(bidderDelegator, signer);
    }

    function testSettleOfferWithSigner() public {
        _delegateToSigner(bidder, signer);
        uint256 offerId = _createOffer(seller, address(squeeth), address(usdc), uint128(1000e6), uint128(1e18), 10e18);
        
        // bidder signature vars
        uint8 v; 
        bytes32 r;
        bytes32 s;

        {
            // bidder signing bid
            SigUtils.OpynRfq memory bigSign = SigUtils.OpynRfq({
                offerId: settlement.offersCounter(),
                bidId: 1,
                signerAddress: signer,
                bidderAddress: bidder,
                bidToken: address(usdc),
                offerToken: address(squeeth),
                bidAmount: 10e18,
                sellAmount: 10000e6,
                nonce: settlement.nonces(bidder)
            });
            bytes32 bidDigest = sigUtils.getTypedDataHash(bigSign);
            (v, r, s) = vm.sign(signerPrivateKey, bidDigest);
        }

        // constrcuting settleRfq() args
        Settlement.BidData memory bidData = Settlement.BidData({
            offerId: settlement.offersCounter(),
            bidId: 1,
            signerAddress: signer,
            bidderAddress: bidder,
            bidToken: address(usdc),
            offerToken: address(squeeth),
            bidAmount: 10e18,
            sellAmount: 10000e6,
            v: v,
            r: r,
            s: s
        });

        assertEq(usdc.balanceOf(seller), 0);
        assertEq(squeeth.balanceOf(bidder), 0);

        // seller send settlement tx
        vm.startPrank(seller);
        settlement.settleOffer(offerId, bidData);
        vm.stopPrank();

        assertEq(usdc.balanceOf(seller), 10000e6);
        assertEq(squeeth.balanceOf(bidder), 10e18);
    }

    function testCheckBid() public {
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
                sellAmount: 10000e6,
                nonce: settlement.nonces(bidder)
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
            sellAmount: 10000e6,
            v: v,
            r: r,
            s: s
        });

        (uint256 errorsNumber,) = settlement.checkBid(bidData);
        console.logUint(errorsNumber);
        assertEq(errorsNumber, 0);

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
                sellAmount: 10000e6,
                nonce: settlement.nonces(bidder)
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
            sellAmount: 10000e6,
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