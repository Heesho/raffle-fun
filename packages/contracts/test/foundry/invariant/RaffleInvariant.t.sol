// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";

import {Raffle} from "../../../src/Raffle.sol";
import {RaffleFactory} from "../../../src/RaffleFactory.sol";
import {IRaffle} from "../../../src/interfaces/IRaffle.sol";
import {IRaffleFactory} from "../../../src/interfaces/IRaffleFactory.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {MockERC721} from "../../../src/mocks/MockERC721.sol";
import {MockEntropyV2} from "../../../src/mocks/MockEntropyV2.sol";
import {RaffleHandler} from "./RaffleHandler.sol";

contract RaffleInvariantTest is StdInvariant, Test {
    MockERC20 internal quote;
    MockERC721 internal prize;
    MockEntropyV2 internal entropy;
    Raffle internal raffle;
    RaffleHandler internal handler;
    address internal treasury = makeAddr("treasury");

    function setUp() public {
        vm.warp(100_000);
        quote = new MockERC20();
        prize = new MockERC721();
        entropy = new MockEntropyV2();
        handler = new RaffleHandler(quote, entropy, treasury);

        RaffleFactory factory = new RaffleFactory(address(quote), address(entropy), treasury, 300_000, address(this));
        prize.mint(address(handler), 1);
        vm.prank(address(handler));
        prize.setApprovalForAll(address(factory), true);
        vm.prank(address(handler));
        raffle = Raffle(
            payable(factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        prizeToken: address(prize),
                        prizeTokenId: 1,
                        sponsorPrizeRecoveryRecipient: address(0),
                        ticketPrice: 1e6,
                        minimumTickets: 50,
                        startTime: block.timestamp,
                        endTime: block.timestamp + 7 days,
                        metadataURI: "ipfs://invariant"
                    })
                ))
        );
        quote.mint(address(handler), 1_000_000 * 1e6);
        handler.configure(raffle);

        bytes4[] memory selectors = new bytes4[](14);
        selectors[0] = handler.buy.selector;
        selectors[1] = handler.warpToEnd.selector;
        selectors[2] = handler.warpToRequestGraceDeadline.selector;
        selectors[3] = handler.warpToCallbackDeadline.selector;
        selectors[4] = handler.warpToNftRedemptionDeadline.selector;
        selectors[5] = handler.requestDraw.selector;
        selectors[6] = handler.fulfill.selector;
        selectors[7] = handler.wrongSequence.selector;
        selectors[8] = handler.enableRefunds.selector;
        selectors[9] = handler.redeemRefundTicket.selector;
        selectors[10] = handler.redeemWinningTicket.selector;
        selectors[11] = handler.claimQuote.selector;
        selectors[12] = handler.claimSponsorPrize.selector;
        selectors[13] = handler.closeEmptyRaffle.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariantStatusTransitionsNeverMoveBackward() public view {
        assertFalse(handler.statusWentBackward());
    }

    function invariantSetupOnlyConfigureIsNeverFuzzed() public view {
        assertEq(handler.ghostConfigureReentryAttempts(), 0);
    }

    function invariantAtMostOneRequestAndTerminalChoiceExist() public view {
        assertLe(handler.ghostRequestCount(), 1);
        assertLe(handler.ghostResolutionCount(), 1);
        assertLe(handler.ghostRefundEnableCount(), 1);
        assertLe(handler.ghostResolutionCount() + handler.ghostRefundEnableCount(), 2);
        if (handler.ghostResolutionCount() + handler.ghostRefundEnableCount() == 2) {
            assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Refunding));
        }
        if (raffle.entropySequenceNumber() != 0) assertEq(handler.ghostRequestCount(), 1);
    }

    function invariantResolvedWinningTicketIsAlwaysInSoldRange() public view {
        IRaffle.Status current = raffle.status();
        if (current != IRaffle.Status.NftWon && current != IRaffle.Status.CashWon) return;
        assertGe(raffle.winningTicketId(), 1);
        assertLe(raffle.winningTicketId(), raffle.totalTickets());
    }

    function invariantQuotePaidInEqualsPaidOutPlusContractBalance() public view {
        assertEq(raffle.grossSales(), handler.ghostGrossPaid());
        assertEq(raffle.grossSales(), quote.balanceOf(address(raffle)) + handler.ghostQuotePaidOut());
    }

    function invariantAccountedQuoteIsExactlyTheFourLiabilitiesAndSolvent() public view {
        assertEq(
            raffle.accountedQuoteBalance(),
            raffle.unsettledPot() + raffle.remainingRefundLiability() + raffle.winnerCashLiability()
                + raffle.totalClaimableQuote()
        );
        assertGe(quote.balanceOf(address(raffle)), raffle.accountedQuoteBalance());
        assertLe(raffle.accountedQuoteBalance(), raffle.grossSales());
    }

    function invariantRefundingNeverChargesProtocolFee() public view {
        if (raffle.status() != IRaffle.Status.Refunding) return;
        assertEq(raffle.unsettledPot(), 0);
        assertEq(raffle.winnerCashLiability(), 0);
        assertEq(raffle.claimableQuote(treasury), 0);
        assertEq(raffle.remainingRefundLiability() + handler.ghostQuotePaidOut(), raffle.grossSales());
    }

    function invariantSuccessfulSettlementAlwaysChargesFivePercent() public view {
        IRaffle.Status current = raffle.status();
        if (current != IRaffle.Status.NftWon && current != IRaffle.Status.CashWon) return;
        if (current == IRaffle.Status.NftWon) {
            assertEq(raffle.winnerCashLiability(), 0);
            if (!raffle.prizeClaimed()) {
                assertEq(raffle.unsettledPot(), raffle.grossSales());
                assertEq(raffle.claimableQuote(treasury) + handler.ghostProtocolPaidOut(), 0);
                return;
            }
        }
        assertEq(raffle.claimableQuote(treasury) + handler.ghostProtocolPaidOut(), raffle.grossSales() * 500 / 10_000);
    }

    function invariantPrizeCanLeaveEscrowOnlyOnceOnAnExplicitClaimPath() public view {
        assertLe(handler.ghostSponsorPrizeClaims(), 1);
        assertLe(handler.ghostWinningTicketRedemptions(), 1);
        if (!raffle.prizeClaimed()) {
            assertEq(prize.ownerOf(raffle.prizeTokenId()), address(raffle));
        } else {
            assertNotEq(prize.ownerOf(raffle.prizeTokenId()), address(raffle));
            IRaffle.Status current = raffle.status();
            assertTrue(
                current == IRaffle.Status.NftWon || current == IRaffle.Status.CashWon
                    || current == IRaffle.Status.Refunding || current == IRaffle.Status.Closed
            );
            if (current == IRaffle.Status.NftWon) {
                assertEq(handler.ghostWinningTicketRedemptions(), 1);
                assertEq(handler.ghostSponsorPrizeClaims(), 0);
            } else {
                assertEq(handler.ghostSponsorPrizeClaims(), 1);
            }
        }
    }
}
