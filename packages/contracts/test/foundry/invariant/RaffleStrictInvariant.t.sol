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
import { StrictRaffleHandler } from "./StrictRaffleHandler.sol";

contract RaffleStrictInvariantTest is StdInvariant, Test {
    MockERC20 internal quote;
    MockERC721 internal prize;
    MockEntropyV2 internal entropy;
    Raffle internal raffle;
    StrictRaffleHandler internal handler;
    address internal treasury = makeAddr("strict-treasury");

    function setUp() public {
        vm.warp(100_000);
        quote = new MockERC20();
        prize = new MockERC721();
        entropy = new MockEntropyV2();
        handler = new StrictRaffleHandler(quote, entropy, treasury);
        RaffleFactory factory = new RaffleFactory(address(quote), address(entropy), treasury, 300_000, address(this));

        prize.mint(address(handler), 1);
        vm.prank(address(handler));
        prize.setApprovalForAll(address(factory), true);
        vm.prank(address(handler));
        raffle = Raffle(
            payable(
                factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        prizeToken: address(prize),
                        prizeTokenId: 1,
                        sponsorPrizeRecoveryRecipient: address(0),
                        ticketPrice: 1e6,
                        minimumTickets: 50,
                        startTime: block.timestamp,
                        endTime: block.timestamp + 7 days,
                        metadataURI: "ipfs://strict-invariant"
                    })
                )
            )
        );
        quote.mint(address(handler), 1_000_000 * 1e6);
        handler.configure(raffle);

        bytes4[] memory selectors = new bytes4[](11);
        selectors[0] = handler.buy.selector;
        selectors[1] = handler.warpToEnd.selector;
        selectors[2] = handler.warpToRequestGraceDeadline.selector;
        selectors[3] = handler.warpToCallbackDeadline.selector;
        selectors[4] = handler.requestDraw.selector;
        selectors[5] = handler.fulfill.selector;
        selectors[6] = handler.enableRefunds.selector;
        selectors[7] = handler.redeemRefundTicket.selector;
        selectors[8] = handler.redeemWinningTicket.selector;
        selectors[9] = handler.claimQuote.selector;
        selectors[10] = handler.claimSponsorPrize.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    }

    function invariantStrictStatusAndResolutionAreMonotonic() public view {
        assertFalse(handler.statusWentBackward());
        assertLe(handler.ghostRequestCount(), 1);
        assertLe(handler.ghostResolutionCount(), 1);
        assertLe(handler.ghostRefundEnableCount(), 1);
        assertLe(handler.ghostResolutionCount() + handler.ghostRefundEnableCount(), 1);
    }

    function invariantStrictQuoteAccountingReconciles() public view {
        assertEq(raffle.grossSales(), handler.ghostGrossPaid());
        assertEq(raffle.grossSales(), quote.balanceOf(address(raffle)) + handler.ghostQuotePaidOut());
        assertEq(
            raffle.accountedQuoteBalance(),
            raffle.unsettledPot() + raffle.remainingRefundLiability() + raffle.winnerCashLiability()
                + raffle.totalClaimableQuote()
        );
        assertGe(quote.balanceOf(address(raffle)), raffle.accountedQuoteBalance());
    }

    function invariantStrictWinnerAndFeeAreBounded() public view {
        IRaffle.Status current = raffle.status();
        if (current != IRaffle.Status.NftWon && current != IRaffle.Status.CashWon) return;
        assertGe(raffle.winningTicketId(), 1);
        assertLe(raffle.winningTicketId(), raffle.totalTickets());
        assertEq(raffle.claimableQuote(treasury) + handler.ghostProtocolPaidOut(), raffle.grossSales() * 500 / 10_000);
    }

    function invariantStrictPrizeEscrowMatchesClaimState() public view {
        assertLe(handler.ghostSponsorPrizeClaims(), 1);
        assertLe(handler.ghostWinningTicketRedemptions(), 1);
        if (!raffle.prizeClaimed()) {
            assertEq(prize.ownerOf(raffle.prizeTokenId()), address(raffle));
        } else {
            assertNotEq(prize.ownerOf(raffle.prizeTokenId()), address(raffle));
        }
    }
}
