// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";
import { MockVRFV2PlusWrapper } from "../../../src/mocks/MockVRFV2PlusWrapper.sol";

contract RaffleFuzzTest is Test {
    uint256 internal constant ENTRY_PRICE = 1e6;

    address internal sponsor = makeAddr("fuzz-sponsor");
    address internal buyer = makeAddr("fuzz-buyer");
    address internal recipient = makeAddr("fuzz-recipient");
    address internal treasury = makeAddr("fuzz-treasury");
    address internal requester = makeAddr("fuzz-requester");

    MockERC20 internal quote;
    MockERC721 internal prize;
    MockVRFV2PlusWrapper internal vrfWrapper;
    RaffleFactory internal factory;
    uint256 internal nextPrizeId = 1;

    function setUp() public {
        vm.warp(10_000);
        quote = new MockERC20();
        prize = new MockERC721();
        vrfWrapper = new MockVRFV2PlusWrapper();
        factory = new RaffleFactory(address(quote), address(vrfWrapper), treasury, address(this));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), true);
        vm.deal(requester, 100 ether);
    }

    function testFuzzPurchaseCreatesOneSequentialTicketWithExactRange(uint128 entrySeed) public {
        uint128 entries = uint128(bound(uint256(entrySeed), 1, type(uint96).max));
        Raffle raffle = _create(type(uint128).max);
        _fundAndApprove(raffle, uint256(entries) * ENTRY_PRICE);

        vm.prank(buyer);
        uint256 ticketId = raffle.buyEntries(recipient, entries);
        (uint128 firstEntry, uint128 lastEntry) = raffle.ticketRange(ticketId);

        assertEq(firstEntry, 1);
        assertEq(lastEntry, entries);
        assertEq(ticketId, 1);
        assertEq(raffle.totalEntries(), entries);
        assertEq(raffle.ticketCount(), 1);
        assertEq(raffle.balanceOf(recipient), 1);
        assertEq(raffle.grossSales(), uint256(entries) * ENTRY_PRICE);
        assertEq(raffle.accountedQuoteBalance(), raffle.grossSales());
    }

    function testFuzzSeparatePurchasesPartitionEntriesWithoutGaps(uint128 firstSeed, uint128 secondSeed) public {
        uint128 firstCount = uint128(bound(uint256(firstSeed), 1, type(uint64).max));
        uint128 secondCount = uint128(bound(uint256(secondSeed), 1, type(uint64).max));
        Raffle raffle = _create(type(uint128).max);
        _fundAndApprove(raffle, (uint256(firstCount) + secondCount) * ENTRY_PRICE);

        vm.startPrank(buyer);
        uint256 firstId = raffle.buyEntries(buyer, firstCount);
        uint256 secondId = raffle.buyEntries(buyer, secondCount);
        vm.stopPrank();

        assertEq(firstId, 1);
        assertEq(secondId, 2);
        (uint128 firstStart, uint128 firstEnd) = raffle.ticketRange(firstId);
        (uint128 secondStart, uint128 secondEnd) = raffle.ticketRange(secondId);
        assertEq(firstStart, 1);
        assertEq(firstEnd, firstCount);
        assertEq(secondStart, firstCount + 1);
        assertEq(secondEnd, firstCount + secondCount);
        assertEq(uint256(firstEnd) + 1, secondStart);
    }

    function testFuzzWinningEntryAlwaysUsesInclusiveSoldRange(uint96 countSeed, uint256 randomWord) public {
        uint128 entries = uint128(bound(uint256(countSeed), 1, type(uint64).max));
        Raffle raffle = _create(entries);
        _fundAndApprove(raffle, uint256(entries) * ENTRY_PRICE);
        vm.prank(buyer);
        uint256 receiptId = raffle.buyEntries(buyer, entries);

        _resolve(raffle, randomWord);

        uint128 expected = uint128((randomWord % uint256(entries)) + 1);
        assertEq(raffle.winningEntry(), expected);
        (uint128 firstEntry, uint128 lastEntry) = raffle.ticketRange(receiptId);
        assertGe(expected, firstEntry);
        assertLe(expected, lastEntry);
    }

    function testFuzzOnlyContainingReceiptCanSettle(uint32 firstSeed, uint32 secondSeed, uint256 randomWord) public {
        uint128 firstCount = uint128(bound(uint256(firstSeed), 1, 1_000_000));
        uint128 secondCount = uint128(bound(uint256(secondSeed), 1, 1_000_000));
        uint128 total = firstCount + secondCount;
        Raffle raffle = _create(total);
        _fundAndApprove(raffle, uint256(total) * ENTRY_PRICE);

        vm.startPrank(buyer);
        uint256 firstId = raffle.buyEntries(buyer, firstCount);
        uint256 secondId = raffle.buyEntries(recipient, secondCount);
        vm.stopPrank();
        _resolve(raffle, randomWord);

        uint256 winningId = raffle.winningEntry() <= firstCount ? firstId : secondId;
        uint256 losingId = winningId == firstId ? secondId : firstId;
        address winner = winningId == firstId ? buyer : recipient;
        uint128 selectedEntry = raffle.winningEntry();
        vm.expectRevert(
            abi.encodeWithSelector(IRaffle.TicketDoesNotContainWinningEntry.selector, losingId, selectedEntry)
        );
        raffle.settleWinningTicket(losingId);

        raffle.settleWinningTicket(winningId);
        assertEq(raffle.winnerRecipient(), winner);
        assertEq(prize.ownerOf(raffle.prizeTokenId()), address(raffle));
        raffle.releaseWinnerPrize();
        assertEq(prize.ownerOf(raffle.prizeTokenId()), winner);
    }

    function testFuzzReserveEqualityIsNftAndOneBelowIsCash(uint32 reserveSeed) public {
        uint128 reserve = uint128(bound(uint256(reserveSeed), 2, 1_000_000));

        Raffle below = _create(reserve);
        _fundAndApprove(below, uint256(reserve - 1) * ENTRY_PRICE);
        vm.prank(buyer);
        below.buyEntries(buyer, reserve - 1);
        _resolve(below, 0);
        assertEq(uint256(below.status()), uint256(IRaffle.Status.CashWon));

        Raffle equal = _create(reserve);
        _fundAndApprove(equal, uint256(reserve) * ENTRY_PRICE);
        vm.prank(buyer);
        equal.buyEntries(buyer, reserve);
        _resolve(equal, 0);
        assertEq(uint256(equal.status()), uint256(IRaffle.Status.NftWon));
    }

    function testFuzzCashSplitAlwaysConservesEightyFifteenFive(uint64 entrySeed) public {
        uint128 entries = uint128(bound(uint256(entrySeed), 1, type(uint32).max));
        Raffle raffle = _create(entries + 1);
        uint256 gross = uint256(entries) * ENTRY_PRICE;
        _fundAndApprove(raffle, gross);
        vm.prank(buyer);
        uint256 ticketId = raffle.buyEntries(buyer, entries);
        _resolve(raffle, 0);

        uint256 fee = gross * 500 / 10_000;
        uint256 distributable = gross - fee;
        uint256 winnerCash = gross * 8000 / 10_000;
        uint256 sponsorCash = distributable - winnerCash;
        assertEq(raffle.protocolFees(), 0);
        assertEq(raffle.sponsorProceeds(), 0);
        assertEq(raffle.accountedQuoteBalance(), gross);

        uint256 winnerBefore = quote.balanceOf(buyer);
        raffle.settleWinningTicket(ticketId);
        assertEq(quote.balanceOf(buyer) - winnerBefore, 0);
        assertEq(raffle.winnerProceeds(), winnerCash);
        assertEq(raffle.protocolFees(), fee);
        assertEq(raffle.sponsorProceeds(), sponsorCash);
        assertEq(raffle.accountedQuoteBalance(), gross);

        raffle.releaseWinnerProceeds();
        assertEq(quote.balanceOf(buyer) - winnerBefore, winnerCash);
        assertEq(raffle.winnerProceeds(), 0);
        assertEq(raffle.accountedQuoteBalance(), fee + sponsorCash);
    }

    function testFuzzRefundPaysWeightedRangeExactlyOnce(uint64 entrySeed) public {
        uint128 entries = uint128(bound(uint256(entrySeed), 1, type(uint32).max));
        Raffle raffle = _create(type(uint128).max);
        uint256 gross = uint256(entries) * ENTRY_PRICE;
        _fundAndApprove(raffle, gross);
        vm.prank(buyer);
        uint256 receiptId = raffle.buyEntries(buyer, entries);
        vm.warp(raffle.endTime());
        vm.prank(requester);
        raffle.requestDraw{ value: raffle.getVrfRequestPrice() }();
        vm.warp(raffle.callbackDeadline());
        raffle.enableRefunds();

        uint256 before = quote.balanceOf(buyer);
        vm.prank(buyer);
        assertEq(raffle.refundTickets(_single(receiptId)), gross);
        assertEq(quote.balanceOf(buyer) - before, gross);
        assertEq(raffle.remainingRefundLiability(), 0);
        vm.prank(buyer);
        vm.expectRevert();
        raffle.refundTickets(_single(receiptId));
    }

    function testFuzzNoRequestTimeoutPaysFullWeightedRange(uint64 entrySeed) public {
        uint128 entries = uint128(bound(uint256(entrySeed), 1, type(uint32).max));
        Raffle raffle = _create(type(uint128).max);
        uint256 gross = uint256(entries) * ENTRY_PRICE;
        _fundAndApprove(raffle, gross);
        vm.prank(buyer);
        uint256 receiptId = raffle.buyEntries(buyer, entries);

        vm.warp(raffle.drawRequestDeadline());
        raffle.enableRefunds();
        assertEq(raffle.unsettledPot(), 0);
        assertEq(raffle.remainingRefundLiability(), gross);
        assertEq(raffle.accountedQuoteBalance(), gross);

        uint256 before = quote.balanceOf(buyer);
        vm.prank(buyer);
        assertEq(raffle.refundTickets(_single(receiptId)), gross);
        assertEq(quote.balanceOf(buyer) - before, gross);
        assertEq(raffle.remainingRefundLiability(), 0);
    }

    function testFuzzPostResolutionBearerCanReceivePermissionlessNftSettlement(uint64 entrySeed) public {
        uint128 entries = uint128(bound(uint256(entrySeed), 1, type(uint32).max));
        Raffle raffle = _create(entries);
        _fundAndApprove(raffle, uint256(entries) * ENTRY_PRICE);
        vm.prank(buyer);
        uint256 receiptId = raffle.buyEntries(buyer, entries);
        _resolve(raffle, 0);
        vm.prank(buyer);
        raffle.transferFrom(buyer, recipient, receiptId);
        vm.prank(requester);
        raffle.settleWinningTicket(receiptId);
        assertEq(raffle.winnerRecipient(), recipient);
        vm.prank(requester);
        raffle.releaseWinnerPrize();
        assertEq(prize.ownerOf(raffle.prizeTokenId()), recipient);
    }

    function _create(uint128 reserveEntries) internal returns (Raffle raffle) {
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        raffle = Raffle(
            payable(factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: sponsor,
                        prizeToken: address(prize),
                        prizeTokenId: tokenId,
                        reserveEntries: reserveEntries,
                        endTime: uint64(block.timestamp + 1 days)
                    })
                ))
        );
    }

    function _fundAndApprove(Raffle raffle, uint256 amount) internal {
        quote.mint(buyer, amount);
        vm.prank(buyer);
        quote.approve(address(raffle), type(uint256).max);
    }

    function _resolve(Raffle raffle, uint256 randomWord) internal {
        vm.warp(raffle.endTime());
        vm.prank(requester);
        uint256 requestId = raffle.requestDraw{ value: raffle.getVrfRequestPrice() }();
        vrfWrapper.fulfill(requestId, randomWord);
    }

    function _single(uint256 receiptId) internal pure returns (uint256[] memory ids) {
        ids = new uint256[](1);
        ids[0] = receiptId;
    }
}
