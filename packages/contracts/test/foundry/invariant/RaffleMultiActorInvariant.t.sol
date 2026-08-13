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
import {MultiActorRaffleHandler} from "./MultiActorRaffleHandler.sol";

contract RaffleMultiActorInvariantTest is StdInvariant, Test {
    MockERC20 internal quote;
    MockERC721 internal prize;
    MockEntropyV2 internal entropy;
    Raffle internal raffle;
    MultiActorRaffleHandler internal handler;
    address internal sponsor = address(0xD001);
    address internal recovery = address(0xD002);
    address internal treasury = address(0xD003);

    function setUp() public {
        vm.warp(100_000);
        quote = new MockERC20();
        prize = new MockERC721();
        entropy = new MockEntropyV2();
        RaffleFactory factory = new RaffleFactory(address(quote), address(entropy), treasury, 300_000, address(this));
        prize.mint(sponsor, 1);
        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), true);
        vm.prank(sponsor);
        raffle = Raffle(
            payable(factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        prizeToken: address(prize),
                        prizeTokenId: 1,
                        sponsorPrizeRecoveryRecipient: recovery,
                        ticketPrice: 1e6,
                        minimumTickets: 50,
                        startTime: block.timestamp,
                        endTime: block.timestamp + 7 days,
                        metadataURI: "ipfs://multi-actor"
                    })
                ))
        );
        handler = new MultiActorRaffleHandler(quote, prize, entropy, factory, raffle, sponsor, recovery, treasury);
        for (uint256 index; index < 3; ++index) {
            address buyer = handler.buyers(index);
            quote.mint(buyer, 1_000_000 * 1e6);
            vm.prank(buyer);
            quote.approve(address(raffle), type(uint256).max);
        }
        targetContract(address(handler));
    }

    function invariantMultiActorStatusAndTerminalCountsAreMonotonic() public view {
        assertFalse(handler.statusWentBackward());
        assertLe(handler.ghostRequestCount(), 1);
        assertLe(handler.ghostResolutionCount(), 1);
        assertLe(handler.ghostFailureCount(), 1);
        assertLe(handler.ghostResolutionCount() + handler.ghostFailureCount(), 2);
        assertLe(handler.ghostPrizeClaims(), 1);
    }

    function invariantMultiActorTicketsAndQuoteReconcile() public view {
        assertEq(raffle.grossSales(), raffle.totalTickets() * raffle.ticketPrice());
        assertEq(raffle.grossSales(), handler.ghostGrossPaid());
        assertEq(
            raffle.grossSales() + handler.ghostQuoteDonations(),
            quote.balanceOf(address(raffle)) + handler.ghostQuotePaidOut()
        );
        assertEq(
            raffle.accountedQuoteBalance(),
            raffle.unsettledPot() + raffle.remainingRefundLiability() + raffle.winnerCashLiability()
                + raffle.totalClaimableQuote()
        );
        assertGe(quote.balanceOf(address(raffle)), raffle.accountedQuoteBalance());
    }

    function invariantMultiActorWinnerAndPrizeStayBounded() public view {
        IRaffle.Status current = raffle.status();
        if (current == IRaffle.Status.NftWon || current == IRaffle.Status.CashWon) {
            assertGe(raffle.winningTicketId(), 1);
            assertLe(raffle.winningTicketId(), raffle.totalTickets());
        }
        if (!raffle.prizeClaimed()) assertEq(prize.ownerOf(1), address(raffle));
        else assertEq(prize.ownerOf(1), handler.prizeReceiver());
    }
}
