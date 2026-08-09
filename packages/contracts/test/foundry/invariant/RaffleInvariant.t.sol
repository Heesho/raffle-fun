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
import { MockEntropyV2 } from "../../../src/mocks/MockEntropyV2.sol";
import { RaffleHandler } from "./RaffleHandler.sol";

contract RaffleInvariantTest is StdInvariant, Test {
    MockERC20 internal quote;
    MockERC721 internal prize;
    MockEntropyV2 internal entropy;
    Raffle internal raffle;
    RaffleHandler internal handler;

    address internal treasury = makeAddr("treasury");
    address internal recipientOne = makeAddr("recipientOne");
    address internal recipientTwo = makeAddr("recipientTwo");
    address internal recipientThree = makeAddr("recipientThree");

    function setUp() public {
        vm.warp(100_000);
        quote = new MockERC20();
        prize = new MockERC721();
        entropy = new MockEntropyV2();
        handler = new RaffleHandler(quote, entropy, treasury, recipientOne, recipientTwo, recipientThree);

        Raffle implementation = new Raffle();
        RaffleFactory factory = new RaffleFactory(
            address(implementation), _quoteTokens(address(quote)), address(entropy), treasury, 300_000, address(this)
        );
        prize.mint(address(handler), 1);
        vm.prank(address(handler));
        prize.setApprovalForAll(address(factory), true);
        vm.prank(address(handler));
        address raffleAddress = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prize),
                prizeTokenId: 1,
                quoteToken: address(quote),
                sponsorPrizeRecoveryRecipient: address(0),
                ticketPrice: 1e6,
                minimumTickets: 250,
                startTime: block.timestamp,
                endTime: block.timestamp + 7 days,
                metadataURI: "ipfs://invariant"
            })
        );
        raffle = Raffle(payable(raffleAddress));
        quote.mint(address(handler), 1_000_000 * 1e6);
        handler.configure(raffle);

        targetContract(address(handler));
    }

    function invariantStateTransitionsNeverMoveBackward() public view {
        assertFalse(handler.stateWentBackward());
    }

    function invariantAtMostOneRequestAndResolutionExist() public view {
        assertLe(handler.ghostRequestCount(), 1);
        assertLe(handler.ghostResolutionCount(), 1);
        assertLe(handler.ghostFailureCount(), 1);
        assertLe(handler.ghostResolutionCount() + handler.ghostFailureCount(), 1);
        if (raffle.entropySequenceNumber() != 0) assertEq(handler.ghostRequestCount(), 1);
    }

    function invariantResolvedWinnerIsAlwaysARealSoldTicket() public view {
        if (raffle.state() == IRaffle.RaffleState.Resolved && raffle.totalTickets() != 0) {
            assertGe(raffle.winningTicketId(), 1);
            assertLe(raffle.winningTicketId(), raffle.totalTickets());
            assertNotEq(raffle.winner(), address(0));
        }
    }

    function invariantEverySoldTicketHasANonzeroOwner() public view {
        uint256 sold = raffle.totalTickets();
        for (uint256 ticketId = 1; ticketId <= sold; ++ticketId) {
            assertNotEq(raffle.ownerOf(ticketId), address(0));
        }
    }

    function invariantPrizeLeavesEscrowAtMostOnceAndOnlyAfterAClaimPathExists() public view {
        assertLe(handler.ghostPrizeClaims(), 1);
        if (!raffle.prizeClaimed()) {
            assertEq(prize.ownerOf(raffle.prizeTokenId()), address(raffle));
        } else {
            assertTrue(
                raffle.state() == IRaffle.RaffleState.Resolved || raffle.state() == IRaffle.RaffleState.Cancelled
                    || raffle.state() == IRaffle.RaffleState.Refunding
            );
            assertNotEq(raffle.prizeClaimant(), address(0));
            assertNotEq(prize.ownerOf(raffle.prizeTokenId()), address(raffle));
        }
    }

    function invariantQuotePaidInEqualsPaidOutPlusContractBalance() public view {
        assertEq(raffle.grossSales(), handler.ghostGrossPaid());
        assertEq(raffle.grossSales(), quote.balanceOf(address(raffle)) + handler.ghostQuoteClaimed());
    }

    function invariantAccountedQuoteAlwaysReconcilesAndIsSolvent() public view {
        assertEq(
            raffle.accountedQuoteBalance(),
            raffle.unsettledPot() + raffle.uncreditedRefundLiability() + raffle.totalClaimableQuote()
        );
        assertGe(quote.balanceOf(address(raffle)), raffle.accountedQuoteBalance());
        assertLe(raffle.totalClaimableQuote(), raffle.grossSales());
    }

    function invariantRefundingConservesGrossAndNeverCreditsProtocolFee() public view {
        if (raffle.state() != IRaffle.RaffleState.Refunding) return;
        assertEq(raffle.unsettledPot(), 0);
        assertEq(raffle.claimableQuote(treasury), 0);
        assertEq(handler.ghostRefundCredited() + raffle.uncreditedRefundLiability(), raffle.grossSales());
        assertTrue(
            raffle.outcome() == IRaffle.RaffleOutcome.DrawNotRequested
                || raffle.outcome() == IRaffle.RaffleOutcome.DrawTimedOut
        );
    }

    function invariantResolutionBranchMatchesExactThresholdBoundary() public view {
        if (handler.ghostResolutionCount() == 0) return;
        IRaffle.RaffleOutcome expected = raffle.totalTickets() >= raffle.minimumTickets()
            ? IRaffle.RaffleOutcome.NftAwarded
            : IRaffle.RaffleOutcome.CashFallback;
        assertEq(uint256(raffle.outcome()), uint256(expected));
        assertEq(raffle.winner(), handler.resolvedWinner());
        assertEq(uint256(raffle.outcome()), uint256(handler.resolvedOutcome()));
        if (expected == IRaffle.RaffleOutcome.NftAwarded) {
            assertEq(raffle.prizeClaimant(), raffle.winner());
        } else {
            assertEq(raffle.prizeClaimant(), address(handler));
        }
    }

    function _quoteTokens(address quoteToken_) internal pure returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = quoteToken_;
    }
}
