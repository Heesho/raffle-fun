// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { FalseERC20 } from "../../../src/mocks/FalseERC20.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";
import { MockVRFV2PlusWrapper } from "../../../src/mocks/MockVRFV2PlusWrapper.sol";
import { ReentrantERC20 } from "../../../src/mocks/ReentrantERC20.sol";
import { ReentrantPrizeERC721 } from "../../../src/mocks/ReentrantPrizeERC721.sol";
import { ReentrantTicketReceiver } from "../../../src/mocks/ReentrantTicketReceiver.sol";

contract RaffleSecurityTest is Test {
    uint256 internal constant USDC = 1e6;
    bytes4 internal constant REENTRANCY_ERROR = bytes4(keccak256("ReentrancyGuardReentrantCall()"));

    address internal sponsor = makeAddr("security-sponsor");
    address internal buyer = makeAddr("security-buyer");
    address internal treasury = makeAddr("security-treasury");
    address internal outsider = makeAddr("security-outsider");

    MockERC20 internal quote;
    MockERC721 internal prize;
    MockVRFV2PlusWrapper internal vrfWrapper;
    RaffleFactory internal factory;
    uint256 internal nextPrizeId = 1;

    function setUp() public {
        vm.warp(1_000_000);
        quote = new MockERC20();
        prize = new MockERC721();
        vrfWrapper = new MockVRFV2PlusWrapper();
        factory = new RaffleFactory(address(quote), address(vrfWrapper), treasury);
        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), true);
        quote.mint(buyer, 1_000_000 * USDC);
        vm.deal(outsider, 100 ether);
    }

    function testReentrantReceiptReceiverCannotNestPurchase() public {
        Raffle raffle = _create(factory, address(prize), 10);
        ReentrantTicketReceiver receiver = new ReentrantTicketReceiver();
        receiver.configure(raffle, true);
        quote.mint(address(receiver), 2 * USDC);
        receiver.approveQuote(quote);

        receiver.buyTicket();

        assertTrue(receiver.reentryBlocked());
        assertEq(raffle.totalEntries(), 1);
        assertEq(raffle.ticketCount(), 1);
        assertEq(raffle.balanceOf(address(receiver)), 1);
        assertEq(raffle.grossSales(), USDC);
    }

    function testReentrantQuoteTokenCannotNestInboundPurchase() public {
        ReentrantERC20 hostile = new ReentrantERC20();
        RaffleFactory hostileFactory = _factoryWithQuote(address(hostile));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(hostileFactory), true);
        Raffle raffle = _create(hostileFactory, address(prize), 2);

        hostile.mint(buyer, USDC);
        vm.prank(buyer);
        hostile.approve(address(raffle), USDC);
        hostile.arm(address(raffle));
        vm.prank(buyer);
        raffle.buyEntries(buyer, 1);

        assertTrue(hostile.reentryBlocked());
        assertEq(raffle.totalEntries(), 1);
        assertEq(hostile.balanceOf(address(raffle)), USDC);
    }

    function testReentrantQuoteTokenCannotNestWinnerWithdrawal() public {
        ReentrantERC20 hostile = new ReentrantERC20();
        RaffleFactory hostileFactory = _factoryWithQuote(address(hostile));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(hostileFactory), true);
        Raffle raffle = _create(hostileFactory, address(prize), 2);

        hostile.mint(buyer, USDC);
        vm.prank(buyer);
        hostile.approve(address(raffle), USDC);
        vm.prank(buyer);
        uint256 receiptId = raffle.buyEntries(buyer, 1);
        _resolve(raffle, 0);

        hostile.armOutbound(address(raffle));
        vm.prank(buyer);
        raffle.settleWinningTicket(receiptId);
        assertFalse(hostile.reentryBlocked());
        vm.prank(buyer);
        raffle.redeemWinningTicket(receiptId);
        assertTrue(hostile.reentryBlocked());
        assertEq(raffle.unsettledPot(), 0);
    }

    function testFalseReturningQuoteCannotCreateReceipt() public {
        FalseERC20 falseQuote = new FalseERC20();
        RaffleFactory falseFactory = new RaffleFactory(address(falseQuote), address(vrfWrapper), treasury);
        vm.prank(sponsor);
        prize.setApprovalForAll(address(falseFactory), true);
        Raffle falseRaffle = _create(falseFactory, address(prize), 1);
        falseQuote.mint(buyer, USDC);
        vm.prank(buyer);
        falseQuote.approve(address(falseRaffle), USDC);
        vm.prank(buyer);
        vm.expectRevert();
        falseRaffle.buyEntries(buyer, 1);
        assertEq(falseRaffle.totalEntries(), 0);
    }

    function testFalseReturningOutboundTransferRestoresClaimAndAccounting() public {
        ReentrantERC20 hostile = new ReentrantERC20();
        RaffleFactory hostileFactory = _factoryWithQuote(address(hostile));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(hostileFactory), true);
        Raffle raffle = _create(hostileFactory, address(prize), 2);

        hostile.mint(buyer, USDC);
        vm.prank(buyer);
        hostile.approve(address(raffle), USDC);
        vm.prank(buyer);
        uint256 receiptId = raffle.buyEntries(buyer, 1);
        _resolve(raffle, 0);
        raffle.settleWinningTicket(receiptId);

        uint256 treasuryClaim = raffle.protocolFees();
        hostile.setFailOutboundTransfer(true);
        vm.expectRevert();
        raffle.releaseProtocolFees();
        assertEq(raffle.protocolFees(), treasuryClaim);
        assertEq(raffle.accountedQuoteBalance(), USDC);

        hostile.setFailOutboundTransfer(false);
        assertEq(raffle.releaseProtocolFees(), treasuryClaim);
        assertEq(raffle.protocolFees(), 0);
        assertEq(hostile.balanceOf(treasury), treasuryClaim);
    }

    function testFalseReturningWinnerTransferRestoresTicketAndLazySettlement() public {
        ReentrantERC20 hostile = new ReentrantERC20();
        RaffleFactory hostileFactory = _factoryWithQuote(address(hostile));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(hostileFactory), true);
        Raffle raffle = _create(hostileFactory, address(prize), 2);

        hostile.mint(buyer, USDC);
        vm.prank(buyer);
        hostile.approve(address(raffle), USDC);
        vm.prank(buyer);
        uint256 receiptId = raffle.buyEntries(buyer, 1);
        _resolve(raffle, 0);

        hostile.setFailOutboundTransfer(true);
        vm.prank(buyer);
        vm.expectRevert();
        raffle.redeemWinningTicket(receiptId);
        assertEq(raffle.ownerOf(receiptId), buyer);
        assertFalse(raffle.winnerRedeemed());
        assertFalse(raffle.settlementComplete());
        assertEq(raffle.unsettledPot(), USDC);

        hostile.setFailOutboundTransfer(false);
        vm.prank(buyer);
        assertEq(raffle.redeemWinningTicket(receiptId), 800_000);
        assertEq(raffle.winnerProceeds(), 0);
        assertEq(hostile.balanceOf(buyer), 800_000);
    }

    function testFactoryReentrancyDuringPrizeEscrowIsBlockedAtomically() public {
        ReentrantPrizeERC721 hostilePrize = new ReentrantPrizeERC721();
        hostilePrize.mint(sponsor, 1);
        vm.prank(sponsor);
        hostilePrize.setApprovalForAll(address(factory), true);
        hostilePrize.arm(factory, 2);

        vm.prank(sponsor);
        Raffle raffle = Raffle(
            payable(factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: sponsor,
                        prizeToken: address(hostilePrize),
                        prizeTokenId: 1,
                        reserveEntries: 1,
                        endTime: uint64(block.timestamp + 1 days)
                    })
                ))
        );

        assertTrue(hostilePrize.reentryBlocked());
        assertEq(factory.raffleCount(), 1);
        assertEq(hostilePrize.ownerOf(1), address(raffle));
        assertEq(hostilePrize.ownerOf(2), address(hostilePrize));
    }

    function testPrizeCannotReenterDuringWinnerTransfer() public {
        ReentrantPrizeERC721 hostilePrize = new ReentrantPrizeERC721();
        uint256 tokenId = nextPrizeId;
        hostilePrize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        hostilePrize.setApprovalForAll(address(factory), true);
        Raffle raffle = _create(factory, address(hostilePrize), 1);
        uint256 receiptId = _buy(raffle, 1);
        _resolve(raffle, 0);

        hostilePrize.armWinnerTransfer(IRaffle(address(raffle)), receiptId, buyer);
        vm.prank(outsider);
        raffle.settleWinningTicket(receiptId);
        assertEq(hostilePrize.reentryAttempts(), 0);
        vm.prank(buyer);
        raffle.redeemWinningTicket(receiptId);

        assertTrue(hostilePrize.reentryBlocked());
        assertEq(hostilePrize.reentryAttempts(), 1);
        assertEq(hostilePrize.reentryBlocks(), 1);
        assertEq(hostilePrize.reentrySelector(), REENTRANCY_ERROR);
        assertEq(hostilePrize.ownerOf(tokenId), buyer);
        assertTrue(raffle.prizeClaimed());
        assertEq(raffle.winningTicketId(), receiptId);
        assertEq(raffle.balanceOf(buyer), 0);
        assertEq(raffle.unsettledPot(), 0);
        assertEq(raffle.protocolFees(), 50_000);
        assertEq(raffle.sponsorProceeds(), 950_000);
        assertEq(raffle.accountedQuoteBalance(), USDC);
    }

    function testPrizeCannotReenterDuringSponsorSafeTransfer() public {
        ReentrantPrizeERC721 hostilePrize = new ReentrantPrizeERC721();
        uint256 tokenId = nextPrizeId;
        hostilePrize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        hostilePrize.setApprovalForAll(address(factory), true);
        Raffle raffle = _create(factory, address(hostilePrize), 2);
        uint256 receiptId = _buy(raffle, 1);
        _resolve(raffle, 0);

        hostilePrize.armSponsorSafeTransfer(IRaffle(address(raffle)), receiptId, buyer);
        vm.prank(outsider);
        raffle.releaseSponsorPrize();

        assertTrue(hostilePrize.reentryBlocked());
        assertEq(hostilePrize.reentryAttempts(), 1);
        assertEq(hostilePrize.reentryBlocks(), 1);
        assertEq(hostilePrize.reentrySelector(), REENTRANCY_ERROR);
        assertEq(hostilePrize.ownerOf(tokenId), sponsor);
        assertTrue(raffle.prizeClaimed());
        assertEq(raffle.ownerOf(receiptId), buyer);
        assertEq(raffle.unsettledPot(), USDC);
        assertEq(raffle.protocolFees(), 0);
        assertEq(raffle.sponsorProceeds(), 0);
        assertEq(raffle.accountedQuoteBalance(), USDC);

        vm.prank(buyer);
        raffle.settleWinningTicket(receiptId);
        assertEq(raffle.unsettledPot(), 0);
        assertEq(raffle.accountedQuoteBalance(), USDC);
    }

    function testProtocolDestinationsCannotReceiveReceiptsOrPayouts() public {
        Raffle raffle = _create(factory, address(prize), 1);
        vm.prank(buyer);
        quote.approve(address(raffle), 2 * USDC);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(factory)));
        raffle.buyEntries(address(factory), 1);
        assertEq(raffle.totalEntries(), 0);
        assertEq(quote.balanceOf(address(raffle)), 0);

        vm.prank(buyer);
        uint256 receiptId = raffle.buyEntries(buyer, 1);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(raffle)));
        raffle.transferFrom(buyer, address(raffle), receiptId);

        _resolve(raffle, 0);
        vm.prank(outsider);
        raffle.settleWinningTicket(receiptId);
        vm.prank(buyer);
        raffle.redeemWinningTicket(receiptId);
        assertEq(prize.ownerOf(raffle.prizeTokenId()), buyer);
    }

    function testCallbackMakesNoQuoteOrPrizeExternalTransfers() public {
        Raffle nft = _create(factory, address(prize), 1);
        uint256 nftReceipt = _buy(nft, 1);
        uint256 quoteBefore = quote.balanceOf(address(nft));
        _resolve(nft, 0);
        assertEq(quote.balanceOf(address(nft)), quoteBefore);
        assertEq(prize.ownerOf(nft.prizeTokenId()), address(nft));
        assertEq(nft.ownerOf(nftReceipt), buyer);

        Raffle cash = _create(factory, address(prize), 2);
        uint256 cashReceipt = _buy(cash, 1);
        quoteBefore = quote.balanceOf(address(cash));
        _resolve(cash, 0);
        assertEq(quote.balanceOf(address(cash)), quoteBefore);
        assertEq(prize.ownerOf(cash.prizeTokenId()), address(cash));
        assertEq(cash.ownerOf(cashReceipt), buyer);
    }

    function _create(RaffleFactory selectedFactory, address prizeAddress, uint128 reserve)
        internal
        returns (Raffle raffle)
    {
        uint256 tokenId = nextPrizeId++;
        if (prizeAddress == address(prize)) prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        raffle = Raffle(
            payable(selectedFactory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: sponsor,
                        prizeToken: prizeAddress,
                        prizeTokenId: tokenId,
                        reserveEntries: reserve,
                        endTime: uint64(block.timestamp + 1 days)
                    })
                ))
        );
    }

    function _factoryWithQuote(address selectedQuote) internal returns (RaffleFactory) {
        return new RaffleFactory(selectedQuote, address(vrfWrapper), treasury);
    }

    function _buy(Raffle raffle, uint128 entries) internal returns (uint256 receiptId) {
        vm.prank(buyer);
        quote.approve(address(raffle), type(uint256).max);
        vm.prank(buyer);
        receiptId = raffle.buyEntries(buyer, entries);
    }

    function _resolve(Raffle raffle, uint256 randomWord) internal {
        vm.warp(raffle.endTime());
        vm.prank(outsider);
        uint256 requestId = raffle.requestDraw{ value: raffle.getVrfRequestPrice() }();
        vrfWrapper.fulfill(requestId, randomWord);
    }
}
