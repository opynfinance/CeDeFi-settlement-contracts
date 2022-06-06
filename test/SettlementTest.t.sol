pragma solidity 0.8.13;

// test dependency
import "@std/Test.sol";
import {SigUtils} from "../src/utils/SigUtils.sol";
import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";

// contract
import {Settlement} from "../src/Settlement.sol";

contract SettlementTest is Test {
    MockERC20 internal usdc;
    MockERC20 internal squeeth;
    SigUtils internal sigUtils;
    Settlement internal settlement;

    uint256 internal sellerPrivateKey;
    uint256 internal bidderPrivateKey;

    address internal seller;
    address internal bidder;

    function setUp() public {
        usdc = new MockERC20("USDC", "USDC", 6);
        squeeth = new MockERC20("SQUEETH", "oSQTH", 18);
        settlement = new Settlement("1");
        sigUtils = new SigUtils(settlement.DOMAIN_SEPARATOR());

        sellerPrivateKey = 0xA11CE;
        bidderPrivateKey = 0xB0B;
        seller = vm.addr(sellerPrivateKey);
        bidder = vm.addr(bidderPrivateKey);

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

    function testSettleRfq() public {
        uint256 squeethAmountToSell = 1e18;
        uint256 usdcAmountToBid = 1000e6;
        uint256 bidId = 1;
        
        uint8 bidV; 
        bytes32 bidR;
        bytes32 bidS;

        uint8 sellerV;
        bytes32 sellerR;
        bytes32 sellerS;

        {
            SigUtils.OpynRfq memory bigSign = SigUtils.OpynRfq({
                bidId: bidId,
                trader: bidder,
                token: address(usdc),
                amount: usdcAmountToBid,
                nonce: 0
            });
            bytes32 bidDigest = sigUtils.getTypedDataHash(bigSign);
            (bidV, bidR, bidS) = vm.sign(bidderPrivateKey, bidDigest);

            SigUtils.OpynRfq memory sellerRfq = SigUtils.OpynRfq({
                bidId: bidId,
                trader: seller,
                token: address(squeeth),
                amount: squeethAmountToSell,
                nonce: 0
            });
            bytes32 offerDigest = sigUtils.getTypedDataHash(sellerRfq);
            (sellerV, sellerR, sellerS) = vm.sign(sellerPrivateKey, offerDigest);
        }

        Settlement.OrderData memory bidOrder = Settlement.OrderData({
            bidId: bidId,
            trader: bidder,
            token: address(usdc),
            amount: usdcAmountToBid,
            v: bidV,
            r: bidR,
            s: bidS
        });
        Settlement.OrderData memory offerOrder = Settlement.OrderData({
            bidId: bidId,
            trader: seller,
            token: address(squeeth),
            amount: squeethAmountToSell,
            v: sellerV,
            r: sellerR,
            s: sellerS
        });

        assertEq(usdc.balanceOf(seller), 0);
        assertEq(squeeth.balanceOf(bidder), 0);

        vm.prank(seller);
        settlement.settleRfq(offerOrder, bidOrder);

        assertEq(settlement.nonces(seller), 1);
        assertEq(settlement.nonces(bidder), 1);
        assertEq(usdc.balanceOf(seller), usdcAmountToBid);
        assertEq(squeeth.balanceOf(bidder), squeethAmountToSell);
    }
}