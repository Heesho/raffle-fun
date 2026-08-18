// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";
import { MockVRFV2PlusWrapper } from "../../../src/mocks/MockVRFV2PlusWrapper.sol";
import { RaffleHandler } from "./RaffleHandler.sol";

contract RaffleInvariantTest is StdInvariant, Test {
    uint256 internal constant ENTRY_PRICE = 1e6;

    MockERC20 internal quote;
    MockERC721 internal prize;
    MockVRFV2PlusWrapper internal vrfWrapper;
    Raffle internal raffle;
    RaffleHandler internal handler;
    address internal treasury = makeAddr("invariant-treasury");

    function setUp() public {
        vm.warp(100_000);
        quote = new MockERC20();
        prize = new MockERC721();
        vrfWrapper = new MockVRFV2PlusWrapper();
        handler = new RaffleHandler(quote, vrfWrapper, treasury);
        RaffleFactory factory = new RaffleFactory(address(quote), address(vrfWrapper), treasury, address(this));

        prize.mint(address(handler), 1);
        vm.prank(address(handler));
        prize.setApprovalForAll(address(factory), true);
        vm.prank(address(handler));
        raffle = Raffle(
            payable(factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: address(handler),
                        prizeToken: address(prize),
                        prizeTokenId: 1,
                        reserveEntries: 50,
                        endTime: uint64(block.timestamp + 7 days)
                    })
                ))
        );
        quote.mint(address(handler), 1_000_000 * ENTRY_PRICE);
        quote.mint(handler.alternateOwner(), 1_000_000 * ENTRY_PRICE);
        handler.configure(raffle);

        bytes4[] memory selectors = new bytes4[](14);
        selectors[0] = handler.buy.selector;
        selectors[1] = handler.transferBeforeOrAfterEnd.selector;
        selectors[2] = handler.warpToEnd.selector;
        selectors[3] = handler.warpToCallbackDeadline.selector;
        selectors[4] = handler.warpFarPastEnd.selector;
        selectors[5] = handler.requestDraw.selector;
        selectors[6] = handler.fulfill.selector;
        selectors[7] = handler.wrongCallback.selector;
        selectors[8] = handler.enableRefunds.selector;
        selectors[9] = handler.settleCandidateWinner.selector;
        selectors[10] = handler.redeemRefund.selector;
        selectors[11] = handler.releaseProceeds.selector;
        selectors[12] = handler.donate.selector;
        selectors[13] = handler.releaseSponsorPrize.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    }

    function invariantStatusAndTerminalTransitionsAreMonotonic() public view {
        assertFalse(handler.statusWentBackward());
        assertLe(handler.ghostRequestCount(), 1);
        assertLe(handler.ghostResolutionCount(), 1);
        assertLe(handler.ghostRefundEnableCount(), 1);
        assertLe(handler.ghostWinnerRedemptions(), 1);
        if (handler.ghostCashResolved()) {
            assertNotEq(uint256(raffle.status()), uint256(IRaffle.Status.Refunding));
        }
    }

    function invariantRangesPartitionEverySoldEntryExactlyOnce() public view {
        uint256 expectedFirst = 1;
        uint256 length = handler.receiptIdsLength();
        for (uint256 index; index < length; ++index) {
            (uint128 firstEntry, uint128 lastEntry) = raffle.ticketRange(handler.receiptIdAt(index));
            assertEq(firstEntry, expectedFirst);
            assertGe(lastEntry, firstEntry);
            expectedFirst = uint256(lastEntry) + 1;
        }
        assertEq(expectedFirst - 1, raffle.totalEntries());
        assertEq(length, raffle.ticketCount());
        assertEq(raffle.grossSales(), uint256(raffle.totalEntries()) * ENTRY_PRICE);
    }

    function invariantWinningEntryHasExactlyOneReceiptProof() public view {
        if (raffle.winningEntry() == 0) return;
        assertGe(raffle.winningEntry(), 1);
        assertLe(raffle.winningEntry(), raffle.totalEntries());
        uint256 containingRanges;
        for (uint256 index; index < handler.receiptIdsLength(); ++index) {
            (uint128 firstEntry, uint128 lastEntry) = raffle.ticketRange(handler.receiptIdAt(index));
            if (raffle.winningEntry() >= firstEntry && raffle.winningEntry() <= lastEntry) ++containingRanges;
        }
        assertEq(containingRanges, 1);
    }

    function invariantTicketIdsAreSequential() public view {
        for (uint256 index; index < handler.receiptIdsLength(); ++index) {
            assertEq(handler.receiptIdAt(index), index + 1);
        }
    }

    function invariantQuoteAccountingIsExactAndSolvent() public view {
        assertEq(raffle.grossSales(), handler.ghostGrossPaid());
        assertEq(
            raffle.grossSales() + handler.ghostDonations(),
            quote.balanceOf(address(raffle)) + handler.ghostQuotePaidOut()
        );
        assertEq(
            raffle.accountedQuoteBalance(),
            raffle.unsettledPot() + raffle.remainingRefundLiability() + raffle.sponsorProceeds() + raffle.protocolFees()
        );
        assertGe(quote.balanceOf(address(raffle)), raffle.accountedQuoteBalance());
    }

    function invariantBranchEconomicsRemainEightyFifteenFiveNinetyFiveFiveOrFullRefund() public view {
        IRaffle.Status current = raffle.status();
        uint256 fee = raffle.grossSales() * 500 / 10_000;
        if (current == IRaffle.Status.CashWon) {
            if (handler.ghostWinnerRedemptions() == 0) {
                assertEq(raffle.unsettledPot(), raffle.grossSales());
                assertEq(raffle.sponsorProceeds(), 0);
                assertEq(raffle.protocolFees(), 0);
            } else {
                assertEq(raffle.unsettledPot(), 0);
                assertEq(handler.ghostWinnerPaidOut(), raffle.grossSales() * 8000 / 10_000);
                assertEq(raffle.sponsorProceeds() + handler.ghostSponsorPaidOut(), raffle.grossSales() * 1500 / 10_000);
                assertEq(raffle.protocolFees() + handler.ghostProtocolPaidOut(), fee);
            }
        } else if (current == IRaffle.Status.NftWon && handler.ghostWinnerRedemptions() != 0) {
            assertEq(raffle.unsettledPot(), 0);
            assertEq(raffle.sponsorProceeds() + handler.ghostSponsorPaidOut(), raffle.grossSales() - fee);
            assertEq(raffle.protocolFees() + handler.ghostProtocolPaidOut(), fee);
        } else if (current == IRaffle.Status.Refunding) {
            assertEq(raffle.unsettledPot(), 0);
            assertEq(raffle.sponsorProceeds(), 0);
            assertEq(raffle.protocolFees(), 0);
            assertEq(raffle.remainingRefundLiability() + handler.ghostRefundPaidOut(), raffle.grossSales());
        }
    }

    function invariantPrizeCustodyMatchesClaimMarker() public view {
        if (raffle.prizeClaimed()) assertNotEq(prize.ownerOf(1), address(raffle));
        else assertEq(prize.ownerOf(1), address(raffle));
    }
}
