// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";

import { S6TestBase } from "./S6TestBase.sol";
import {
    AcceptingReceiver,
    HonestPrize,
    LyingPrize,
    MockQuoteToken,
    MockVrfWrapper,
    NoCallbackPrize,
    ReentrantPrize,
    ReentrantTicketReceiver,
    RejectingReceiver,
    TicketOnlyReceiver
} from "./S6Mocks.sol";

contract S6SecureWorkflowTest is S6TestBase {
    address internal constant SPONSOR = address(0x5100);
    address internal constant SPONSOR_RECIPIENT = address(0x5200);
    address internal constant TREASURY = address(0x5300);
    address internal constant BUYER = address(0x5400);
    address internal constant BUYER_TWO = address(0x5500);
    address internal constant KEEPER = address(0x5600);
    address internal constant OPERATOR = address(0x5700);
    address internal constant ATTACKER = address(0x5800);

    uint256 internal constant ENTRY_PRICE = 1_000_000;

    struct System {
        MockQuoteToken quote;
        MockVrfWrapper wrapper;
        RaffleFactory factory;
        HonestPrize prize;
        Raffle raffle;
        uint64 endTime;
    }

    function _deploySystem(uint128 reserveEntries) internal returns (System memory system) {
        system.quote = new MockQuoteToken();
        system.wrapper = new MockVrfWrapper(address(system.quote));
        system.factory = new RaffleFactory(address(system.quote), address(system.wrapper), TREASURY);
        system.prize = new HonestPrize();
        system.prize.mint(SPONSOR, 1);
        system.endTime = uint64(block.timestamp + 1 days);

        vm.startPrank(SPONSOR);
        system.prize.approve(address(system.factory), 1);
        address raffleAddress = system.factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                sponsorRecipient: SPONSOR_RECIPIENT,
                prizeToken: address(system.prize),
                prizeTokenId: 1,
                reserveEntries: reserveEntries,
                endTime: system.endTime
            })
        );
        vm.stopPrank();
        system.raffle = Raffle(payable(raffleAddress));
    }

    function _buy(System memory system, address payer, address recipient, uint128 entries)
        internal
        returns (uint256 ticketId)
    {
        uint256 amount = uint256(entries) * ENTRY_PRICE;
        system.quote.mint(payer, amount);
        vm.prank(payer);
        system.quote.approve(address(system.raffle), type(uint256).max);
        vm.prank(payer);
        ticketId = system.raffle.buyEntries(recipient, entries);
    }

    function _requestDraw(System memory system) internal returns (uint256 requestId) {
        vm.warp(system.endTime);
        vm.deal(KEEPER, 1 ether);
        vm.prank(KEEPER);
        requestId = system.raffle.requestDraw{ value: system.wrapper.price() }();
    }

    function _resolve(System memory system, uint256 word) internal returns (uint256 requestId) {
        requestId = _requestDraw(system);
        system.wrapper.fulfill(address(system.raffle), requestId, word);
    }

    function _createSecondRaffle(System memory system) internal returns (Raffle second) {
        system.prize.mint(SPONSOR, 2);
        vm.startPrank(SPONSOR);
        system.prize.approve(address(system.factory), 2);
        address raffleAddress = system.factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                sponsorRecipient: SPONSOR_RECIPIENT,
                prizeToken: address(system.prize),
                prizeTokenId: 2,
                reserveEntries: 1,
                endTime: uint64(block.timestamp + 1 days)
            })
        );
        vm.stopPrank();
        second = Raffle(payable(raffleAddress));
    }

    function test_InitializationIsFactoryOnlyAndOneTime() public {
        System memory system = _deploySystem(1);
        address rawClone = Clones.clone(system.factory.raffleImplementation());
        IRaffle.RaffleInitParams memory params = IRaffle.RaffleInitParams({
            sponsor: SPONSOR,
            sponsorRecipient: SPONSOR_RECIPIENT,
            protocolTreasury: TREASURY,
            prizeToken: address(system.prize),
            prizeTokenId: 99,
            raffleId: 99,
            reserveEntries: 1,
            endTime: uint64(block.timestamp + 1 days)
        });

        vm.expectRevert(IRaffle.OnlyFactory.selector);
        vm.prank(ATTACKER);
        IRaffle(rawClone).initialize(params);

        vm.expectRevert(IRaffle.AlreadyInitialized.selector);
        vm.prank(address(system.factory));
        system.raffle.initialize(params);

        assertTrue(system.raffle.initialized(), "canonical clone initialized");
        assertEq(uint256(system.raffle.status()), uint256(IRaffle.Status.Active), "clone active after escrow");
        assertTrue(IRaffle(system.factory.raffleImplementation()).initialized(), "implementation locked");
        assertEq(
            uint256(IRaffle(system.factory.raffleImplementation()).status()),
            uint256(IRaffle.Status.Refunding),
            "implementation inert"
        );
    }

    function test_SaleAndDrawRequestTimeBoundaries() public {
        System memory saleBoundary = _deploySystem(1);
        saleBoundary.quote.mint(BUYER, ENTRY_PRICE);
        vm.prank(BUYER);
        saleBoundary.quote.approve(address(saleBoundary.raffle), ENTRY_PRICE);
        vm.warp(saleBoundary.endTime);
        vm.expectPartialRevert(IRaffle.SaleEnded.selector);
        vm.prank(BUYER);
        saleBoundary.raffle.buyEntries(BUYER, 1);

        System memory openAtEnd = _deploySystem(1);
        _buy(openAtEnd, BUYER, BUYER, 1);
        uint256 requestId = _requestDraw(openAtEnd);
        assertEq(requestId, 1, "draw opens exactly at endTime");
        assertEq(uint256(openAtEnd.raffle.status()), uint256(IRaffle.Status.Drawing), "drawing state");

        System memory closedAtDeadline = _deploySystem(1);
        _buy(closedAtDeadline, BUYER, BUYER, 1);
        vm.warp(closedAtDeadline.raffle.drawRequestDeadline());
        vm.deal(KEEPER, 1 ether);
        uint256 closedAtDeadlinePrice = closedAtDeadline.wrapper.price();
        vm.expectPartialRevert(IRaffle.DrawRequestWindowExpired.selector);
        vm.prank(KEEPER);
        closedAtDeadline.raffle.requestDraw{ value: closedAtDeadlinePrice }();
        closedAtDeadline.raffle.enableRefunds();
        assertEq(
            uint256(closedAtDeadline.raffle.status()), uint256(IRaffle.Status.Refunding), "refund opens at deadline"
        );
    }

    function test_CallbackDeadlineIsExclusiveAndRefundOpensAtBoundary() public {
        System memory system = _deploySystem(1);
        _buy(system, BUYER, BUYER, 2);
        uint256 requestId = _requestDraw(system);
        vm.warp(system.raffle.callbackDeadline());
        system.wrapper.fulfill(address(system.raffle), requestId, 0);
        assertEq(uint256(system.raffle.status()), uint256(IRaffle.Status.Drawing), "late callback ignored");
        assertEq(system.raffle.winningEntry(), 0, "late callback records no winner");
        system.raffle.enableRefunds();
        assertEq(uint256(system.raffle.status()), uint256(IRaffle.Status.Refunding), "refund available at boundary");
    }

    function test_SynchronousWrongShapeWrongIdAndDuplicateCallbacksAreContained() public {
        System memory system = _deploySystem(1);
        _buy(system, BUYER, BUYER, 3);
        system.wrapper.configureSynchronousCallback(true, 777);
        uint256 requestId = _requestDraw(system);
        assertEq(uint256(system.raffle.status()), uint256(IRaffle.Status.Drawing), "in-flight callback ignored");
        assertEq(system.raffle.winningEntry(), 0, "in-flight callback no winner");

        uint256[] memory noWords = new uint256[](0);
        system.wrapper.fulfillWords(address(system.raffle), requestId, noWords);
        system.wrapper.fulfill(address(system.raffle), requestId + 1, 0);
        assertEq(uint256(system.raffle.status()), uint256(IRaffle.Status.Drawing), "bad callbacks ignored");

        system.wrapper.fulfill(address(system.raffle), requestId, 1);
        assertEq(uint256(system.raffle.status()), uint256(IRaffle.Status.NftWon), "valid callback accepted");
        uint256 winningEntry = system.raffle.winningEntry();
        system.wrapper.fulfill(address(system.raffle), requestId, 2);
        assertEq(system.raffle.winningEntry(), winningEntry, "duplicate callback cannot rewrite winner");

        vm.expectRevert();
        vm.prank(ATTACKER);
        system.raffle.rawFulfillRandomWords(requestId, noWords);
    }

    function testFuzz_TicketRangesPartitionSalesAndAccounting(uint128 firstRaw, uint128 secondRaw) public {
        uint128 first = uint128(uint256(firstRaw) % 1_000_000 + 1);
        uint128 second = uint128(uint256(secondRaw) % 1_000_000 + 1);
        System memory system = _deploySystem(1);
        uint256 ticketOne = _buy(system, BUYER, BUYER, first);
        uint256 ticketTwo = _buy(system, BUYER_TWO, BUYER_TWO, second);

        (uint128 firstStart, uint128 firstEnd) = system.raffle.ticketRange(ticketOne);
        (uint128 secondStart, uint128 secondEnd) = system.raffle.ticketRange(ticketTwo);
        assertEq(firstStart, 1, "first range starts at one");
        assertEq(firstEnd, first, "first range length");
        assertEq(secondStart, uint256(first) + 1, "ranges contiguous");
        assertEq(secondEnd, uint256(first) + uint256(second), "second range ends at total");
        assertEq(system.raffle.totalEntries(), uint256(first) + uint256(second), "entry total");
        assertEq(system.raffle.ticketCount(), 2, "ticket total");
        assertEq(system.raffle.grossSales(), (uint256(first) + uint256(second)) * ENTRY_PRICE, "gross sales");
        assertEq(system.raffle.accountedQuoteBalance(), system.raffle.grossSales(), "accounting conservation");
        assertEq(system.quote.balanceOf(address(system.raffle)), system.raffle.grossSales(), "custody conservation");
    }

    function testFuzz_FeeArithmeticAndRoundingConserveEveryReachablePot(uint128 rawEntries, bool reserveMet) public pure {
        uint256 entries = uint256(rawEntries) + 1;
        uint256 gross = entries * ENTRY_PRICE;
        uint256 protocol = gross * 500 / 10_000;
        uint256 winner = reserveMet ? 0 : gross * 8_000 / 10_000;
        uint256 sponsor = gross - protocol - winner;
        if (protocol + winner + sponsor != gross) revert AssertionFailed("allocation sum");
        if (protocol != entries * 50_000) revert AssertionFailed("protocol exact at reachable granularity");
        if (!reserveMet && winner != entries * 800_000) revert AssertionFailed("cash exact at reachable granularity");
    }

    function test_NftSettlementClaimsAndRedemptionConserveLiabilities() public {
        System memory system = _deploySystem(3);
        uint256 ticketId = _buy(system, BUYER, BUYER, 3);
        _resolve(system, 0);
        system.raffle.settleWinningTicket(ticketId);

        uint256 gross = 3 * ENTRY_PRICE;
        assertEq(system.raffle.protocolFees(), 150_000, "five percent protocol");
        assertEq(system.raffle.sponsorProceeds(), 2_850_000, "sponsor remainder");
        assertEq(system.raffle.winnerProceeds(), 0, "NFT winner has no quote claim");
        assertEq(system.raffle.accountedQuoteBalance(), gross, "settlement conserves gross");

        vm.prank(ATTACKER);
        system.raffle.releaseProtocolFees();
        vm.prank(ATTACKER);
        system.raffle.releaseSponsorProceeds();
        vm.prank(BUYER);
        system.raffle.redeemWinningTicket(ticketId);

        assertEq(system.quote.balanceOf(TREASURY), 150_000, "treasury fixed destination");
        assertEq(system.quote.balanceOf(SPONSOR_RECIPIENT), 2_850_000, "sponsor fixed destination");
        assertEq(system.quote.balanceOf(address(system.raffle)), 0, "quote custody drained exactly");
        assertEq(system.raffle.accountedQuoteBalance(), 0, "all buckets cleared");
        assertEq(system.prize.ownerOf(1), BUYER, "prize delivered to ticket owner");
    }

    function test_CashSettlementRedemptionAndPrizeReturnConserveLiabilities() public {
        System memory system = _deploySystem(10);
        uint256 ticketId = _buy(system, BUYER, BUYER, 4);
        _resolve(system, 0);
        system.raffle.settleWinningTicket(ticketId);
        assertEq(uint256(system.raffle.status()), uint256(IRaffle.Status.CashWon), "reserve missed");
        assertEq(system.raffle.winnerProceeds(), 3_200_000, "winner eighty percent");
        assertEq(system.raffle.protocolFees(), 200_000, "protocol five percent");
        assertEq(system.raffle.sponsorProceeds(), 600_000, "sponsor remainder fifteen percent");

        vm.prank(BUYER);
        system.raffle.redeemWinningTicket(ticketId);
        system.raffle.releaseSponsorProceeds();
        system.raffle.releaseProtocolFees();
        system.raffle.releaseSponsorPrize();

        assertEq(system.quote.balanceOf(BUYER), 3_200_000, "winner paid");
        assertEq(system.quote.balanceOf(SPONSOR_RECIPIENT), 600_000, "sponsor paid");
        assertEq(system.quote.balanceOf(TREASURY), 200_000, "treasury paid");
        assertEq(system.raffle.accountedQuoteBalance(), 0, "no liability remains");
        assertEq(system.quote.balanceOf(address(system.raffle)), 0, "no quote remains");
        assertEq(system.prize.ownerOf(1), SPONSOR_RECIPIENT, "prize returned");
    }

    function test_RefundsBurnTicketsAndConserveFullPot() public {
        System memory system = _deploySystem(100);
        uint256 firstTicket = _buy(system, BUYER, BUYER, 2);
        uint256 secondTicket = _buy(system, BUYER, BUYER, 5);
        vm.warp(system.raffle.drawRequestDeadline());
        system.raffle.enableRefunds();
        assertEq(system.raffle.remainingRefundLiability(), 7 * ENTRY_PRICE, "full pot becomes refund liability");
        uint256[] memory tickets = new uint256[](2);
        tickets[0] = firstTicket;
        tickets[1] = secondTicket;
        vm.prank(BUYER);
        system.raffle.refundTickets(tickets);
        assertEq(system.quote.balanceOf(BUYER), 7 * ENTRY_PRICE, "full purchase value returned");
        assertEq(system.raffle.remainingRefundLiability(), 0, "refund bucket cleared");
        assertEq(system.quote.balanceOf(address(system.raffle)), 0, "custody cleared");
        vm.expectRevert();
        system.raffle.ownerOf(firstTicket);
    }

    function test_IncompatibleTicketRecipientRevertsPurchaseAtomically() public {
        System memory system = _deploySystem(1);
        RejectingReceiver receiver = new RejectingReceiver();
        system.quote.mint(BUYER, ENTRY_PRICE);
        vm.prank(BUYER);
        system.quote.approve(address(system.raffle), ENTRY_PRICE);
        vm.expectRevert();
        vm.prank(BUYER);
        system.raffle.buyEntries(address(receiver), 1);
        assertEq(system.raffle.totalEntries(), 0, "entry write reverted");
        assertEq(system.raffle.ticketCount(), 0, "ticket write reverted");
        assertEq(system.raffle.unsettledPot(), 0, "liability write reverted");
        assertEq(system.quote.balanceOf(address(system.raffle)), 0, "payment reverted");
        assertEq(system.quote.balanceOf(BUYER), ENTRY_PRICE, "buyer restored");
    }

    function test_TicketReceiverAndQuoteCallbacksCannotReenterProtectedPurchase() public {
        System memory receiverSystem = _deploySystem(1);
        ReentrantTicketReceiver receiver = new ReentrantTicketReceiver();
        receiver.configure(address(receiverSystem.raffle), BUYER_TWO);
        _buy(receiverSystem, BUYER, address(receiver), 1);
        assertTrue(receiver.attempted(), "receiver attempted reentry");
        assertFalse(receiver.succeeded(), "receiver reentry blocked");
        assertEq(receiverSystem.raffle.ticketCount(), 1, "only outer purchase minted");

        System memory quoteSystem = _deploySystem(1);
        quoteSystem.quote.configureCallback(
            address(quoteSystem.raffle), abi.encodeCall(IRaffle.buyEntries, (BUYER_TWO, uint128(1))), true
        );
        _buy(quoteSystem, BUYER, BUYER, 1);
        assertTrue(quoteSystem.quote.callbackAttempted(), "quote attempted reentry");
        assertFalse(quoteSystem.quote.callbackSucceeded(), "quote reentry blocked");
        assertEq(quoteSystem.raffle.ticketCount(), 1, "only outer quote-funded purchase minted");
    }

    function test_NonstandardFalseReturnQuoteRevertsAtomically() public {
        System memory system = _deploySystem(1);
        system.quote.mint(BUYER, ENTRY_PRICE);
        vm.prank(BUYER);
        system.quote.approve(address(system.raffle), ENTRY_PRICE);
        system.quote.setReturnFalse(true);
        vm.expectRevert();
        vm.prank(BUYER);
        system.raffle.buyEntries(BUYER, 1);
        assertEq(system.raffle.totalEntries(), 0, "false-return token cannot create entries");
        assertEq(system.raffle.unsettledPot(), 0, "false-return token cannot create liability");
    }

    function test_Evidence_FeeOnTransferQuoteCreatesCustodyDeficit() public {
        System memory system = _deploySystem(1);
        system.quote.setFeeBps(100);
        _buy(system, BUYER, BUYER, 10);
        assertEq(system.raffle.accountedQuoteBalance(), 10 * ENTRY_PRICE, "gross liability recorded");
        assertEq(system.quote.balanceOf(address(system.raffle)), 9_900_000, "one percent fee removed");
        assertTrue(
            system.quote.balanceOf(address(system.raffle)) < system.raffle.accountedQuoteBalance(),
            "conditional quote-token deficit reproduced"
        );
    }

    function test_PrizeWithoutReceiverCallbackIsRejectedAtomically() public {
        MockQuoteToken quote = new MockQuoteToken();
        MockVrfWrapper wrapper = new MockVrfWrapper(address(quote));
        RaffleFactory factory = new RaffleFactory(address(quote), address(wrapper), TREASURY);
        NoCallbackPrize prize = new NoCallbackPrize();
        prize.mint(SPONSOR, 1);
        vm.startPrank(SPONSOR);
        prize.approve(address(factory), 1);
        vm.expectPartialRevert(IRaffleFactory.PrizeEscrowVerificationFailed.selector);
        factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                sponsorRecipient: SPONSOR_RECIPIENT,
                prizeToken: address(prize),
                prizeTokenId: 1,
                reserveEntries: 1,
                endTime: uint64(block.timestamp + 1 days)
            })
        );
        vm.stopPrank();
        assertEq(factory.raffleCount(), 0, "factory registry rolled back");
        assertEq(prize.ownerOf(1), SPONSOR, "prize transfer rolled back");
    }

    function test_Evidence_MaliciousPrizeCanFakeEscrowAndDelivery() public {
        MockQuoteToken quote = new MockQuoteToken();
        MockVrfWrapper wrapper = new MockVrfWrapper(address(quote));
        RaffleFactory factory = new RaffleFactory(address(quote), address(wrapper), TREASURY);
        LyingPrize prize = new LyingPrize(SPONSOR, 1);
        vm.startPrank(SPONSOR);
        prize.approve(address(factory), 1);
        address raffleAddress = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                sponsorRecipient: SPONSOR_RECIPIENT,
                prizeToken: address(prize),
                prizeTokenId: 1,
                reserveEntries: 1,
                endTime: uint64(block.timestamp + 1 days)
            })
        );
        vm.stopPrank();
        assertEq(prize.ownerOf(1), raffleAddress, "reported custody passes factory check");
        assertEq(prize.actualOwner(), SPONSOR, "actual custody never changed");
        assertEq(uint256(IRaffle(raffleAddress).status()), uint256(IRaffle.Status.Active), "fake prize activates sales");

        Raffle raffle = Raffle(payable(raffleAddress));
        quote.mint(BUYER, ENTRY_PRICE);
        vm.prank(BUYER);
        quote.approve(raffleAddress, ENTRY_PRICE);
        vm.prank(BUYER);
        uint256 ticketId = raffle.buyEntries(BUYER, 1);

        vm.warp(raffle.endTime());
        vm.deal(KEEPER, 1 ether);
        vm.prank(KEEPER);
        uint256 requestId = raffle.requestDraw{ value: wrapper.price() }();
        wrapper.fulfill(raffleAddress, requestId, 0);
        raffle.settleWinningTicket(ticketId);
        raffle.releaseSponsorProceeds();
        raffle.releaseProtocolFees();
        vm.prank(BUYER);
        raffle.redeemWinningTicket(ticketId);

        assertEq(quote.balanceOf(SPONSOR_RECIPIENT), 950_000, "sponsor extracts ninety-five percent");
        assertEq(quote.balanceOf(TREASURY), 50_000, "protocol fee released");
        assertEq(prize.ownerOf(1), BUYER, "reported delivery passes redemption check");
        assertEq(prize.actualOwner(), SPONSOR, "actual prize remains with malicious sponsor after redemption");
    }

    function test_Evidence_PrizeCanBuyEntriesBeforeCreateRaffleReturns() public {
        MockQuoteToken quote = new MockQuoteToken();
        MockVrfWrapper wrapper = new MockVrfWrapper(address(quote));
        RaffleFactory factory = new RaffleFactory(address(quote), address(wrapper), TREASURY);
        ReentrantPrize prize = new ReentrantPrize(quote);
        prize.mint(SPONSOR);
        quote.mint(address(prize), ENTRY_PRICE);
        prize.arm(BUYER);
        vm.startPrank(SPONSOR);
        prize.approve(address(factory), 1);
        address raffleAddress = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                sponsorRecipient: SPONSOR_RECIPIENT,
                prizeToken: address(prize),
                prizeTokenId: 1,
                reserveEntries: 1,
                endTime: uint64(block.timestamp + 1 days)
            })
        );
        vm.stopPrank();
        prize.disarm();
        IRaffle raffle = IRaffle(raffleAddress);
        assertEq(raffle.totalEntries(), 1, "entry sold within prize transfer call");
        assertEq(raffle.ticketCount(), 1, "ticket minted before factory return");
        assertEq(IERC721(raffleAddress).ownerOf(1), BUYER, "prebuyer owns ticket");
    }

    function test_ERC721RuntimeConformanceOnClone() public {
        System memory system = _deploySystem(1);
        assertTrue(IERC165(address(system.raffle)).supportsInterface(0x01ffc9a7), "ERC165 interface");
        assertTrue(IERC165(address(system.raffle)).supportsInterface(0x80ac58cd), "ERC721 interface");
        assertTrue(IERC165(address(system.raffle)).supportsInterface(0x5b5e139f), "metadata interface");
        assertFalse(IERC165(address(system.raffle)).supportsInterface(0xffffffff), "invalid interface rejected");
        assertEq(keccak256(bytes(system.raffle.name())), keccak256(bytes("raffle.fun Ticket")), "name");
        assertEq(keccak256(bytes(system.raffle.symbol())), keccak256(bytes("RAFFLE")), "symbol");

        uint256 ticketId = _buy(system, BUYER, BUYER, 1);
        assertEq(system.raffle.ownerOf(ticketId), BUYER, "owner after mint");
        assertEq(system.raffle.balanceOf(BUYER), 1, "balance after mint");
        vm.prank(BUYER);
        system.raffle.approve(OPERATOR, ticketId);
        vm.prank(OPERATOR);
        system.raffle.transferFrom(BUYER, BUYER_TWO, ticketId);
        assertEq(system.raffle.ownerOf(ticketId), BUYER_TWO, "approved transfer");
        assertEq(system.raffle.balanceOf(BUYER), 0, "sender balance decremented");
        assertEq(system.raffle.balanceOf(BUYER_TWO), 1, "recipient balance incremented");

        RejectingReceiver rejector = new RejectingReceiver();
        vm.expectRevert();
        vm.prank(BUYER_TWO);
        system.raffle.safeTransferFrom(BUYER_TWO, address(rejector), ticketId);
        assertEq(system.raffle.ownerOf(ticketId), BUYER_TWO, "failed safe transfer rolls back owner");
    }

    function test_CurrentOwnerAuthorizationAndPermissionlessFixedDestinationClaims() public {
        System memory system = _deploySystem(1);
        uint256 ticketId = _buy(system, BUYER, BUYER, 1);
        _resolve(system, 0);
        system.raffle.settleWinningTicket(ticketId);
        vm.expectPartialRevert(IRaffle.NotTicketOwner.selector);
        vm.prank(ATTACKER);
        system.raffle.redeemWinningTicket(ticketId);
        vm.prank(ATTACKER);
        system.raffle.releaseSponsorProceeds();
        vm.prank(ATTACKER);
        system.raffle.releaseProtocolFees();
        assertEq(system.quote.balanceOf(SPONSOR_RECIPIENT), 950_000, "caller cannot redirect sponsor proceeds");
        assertEq(system.quote.balanceOf(TREASURY), 50_000, "caller cannot redirect protocol fees");
    }

    function test_SameFactoryRaffleDestinationIsRejected() public {
        System memory system = _deploySystem(1);
        Raffle second = _createSecondRaffle(system);
        uint256 ticketId = _buy(system, BUYER, BUYER, 1);
        vm.expectPartialRevert(IRaffle.UnsafeProtocolDestination.selector);
        vm.prank(BUYER);
        system.raffle.transferFrom(BUYER, address(second), ticketId);
        assertEq(system.raffle.ownerOf(ticketId), BUYER, "same-factory sink rejected");
    }

    function test_Evidence_CrossFactoryRaffleDestinationIsAcceptedAndStrandsTicket() public {
        System memory first = _deploySystem(1);
        System memory second = _deploySystem(1);
        uint256 ticketId = _buy(first, BUYER, BUYER, 1);
        vm.prank(BUYER);
        first.raffle.transferFrom(BUYER, address(second.raffle), ticketId);
        assertEq(first.raffle.ownerOf(ticketId), address(second.raffle), "cross-factory clone accepted as owner");
        assertFalse(first.factory.isRaffle(address(second.raffle)), "registry scope explains bypass");
    }

    function test_Evidence_PrizeTransferSkipsIncompatibleContractReceiverCheck() public {
        System memory system = _deploySystem(1);
        TicketOnlyReceiver receiver = new TicketOnlyReceiver();
        receiver.configure(address(system.raffle));
        uint256 ticketId = _buy(system, BUYER, address(receiver), 1);
        _resolve(system, 0);
        receiver.redeem(system.raffle, ticketId);
        assertEq(receiver.callbacks(), 1, "only ticket safe-mint callback occurred");
        assertEq(system.prize.ownerOf(1), address(receiver), "prize delivered without receiver acceptance");
    }
}
