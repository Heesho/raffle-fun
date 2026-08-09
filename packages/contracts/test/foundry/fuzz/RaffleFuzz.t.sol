// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";
import { MockEntropyV2 } from "../../../src/mocks/MockEntropyV2.sol";

contract RaffleFuzzTest is Test {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant PROTOCOL_FEE_BPS = 500;
    uint256 internal constant CASH_WINNER_BPS = 8000;

    address internal sponsor = makeAddr("sponsor");
    address internal buyer = makeAddr("buyer");
    address internal recipient = makeAddr("recipient");
    address internal treasury = makeAddr("treasury");
    address internal requester = makeAddr("requester");

    MockERC20 internal quote;
    MockERC721 internal prize;
    MockEntropyV2 internal entropy;
    RaffleFactory internal factory;
    uint256 internal nextPrizeId = 1;

    function setUp() public {
        vm.warp(10_000);
        quote = new MockERC20();
        prize = new MockERC721();
        entropy = new MockEntropyV2();
        factory = new RaffleFactory(address(quote), address(entropy), treasury, 300_000, address(this));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), true);
        vm.deal(requester, 100 ether);
    }

    function testFuzzPurchaseAccountingReconciles(uint128 ticketPriceSeed, uint256 quantitySeed) public {
        uint256 ticketPrice = bound(uint256(ticketPriceSeed), 1, 1e24);
        uint256 quantity = bound(quantitySeed, 1, 100);
        Raffle raffle = _create(ticketPrice, type(uint256).max);
        uint256 gross = ticketPrice * quantity;
        _fundAndApprove(raffle, gross);

        vm.prank(buyer);
        raffle.buyTickets(recipient, quantity);

        assertEq(raffle.grossSales(), gross);
        assertEq(raffle.unsettledPot(), gross);
        assertEq(raffle.accountedQuoteBalance(), gross);
        assertEq(quote.balanceOf(address(raffle)), gross);
    }

    function testFuzzWinningTicketAlwaysUsesInclusiveSoldRange(uint256 ticketCountSeed, bytes32 randomNumber) public {
        uint256 ticketCount = bound(ticketCountSeed, 1, 100);
        Raffle raffle = _create(1e6, ticketCount);
        _fundAndApprove(raffle, ticketCount * 1e6);
        vm.prank(buyer);
        raffle.buyTickets(buyer, ticketCount);

        _resolve(raffle, randomNumber);

        uint256 winningTicket = raffle.winningTicketId();
        assertEq(winningTicket, (uint256(randomNumber) % ticketCount) + 1);
        assertGe(winningTicket, 1);
        assertLe(winningTicket, ticketCount);
        assertEq(raffle.ownerOf(winningTicket), buyer);
    }

    function testFuzzThresholdBoundarySelectsSingleStatus(uint256 ticketCountSeed, uint256 thresholdSeed) public {
        uint256 ticketCount = bound(ticketCountSeed, 1, 100);
        uint256 threshold = bound(thresholdSeed, 1, 150);
        Raffle raffle = _create(1e6, threshold);
        _fundAndApprove(raffle, ticketCount * 1e6);
        vm.prank(buyer);
        raffle.buyTickets(buyer, ticketCount);

        _resolve(raffle, bytes32(0));

        IRaffle.Status expected = ticketCount >= threshold ? IRaffle.Status.NftWon : IRaffle.Status.CashWon;
        assertEq(uint256(raffle.status()), uint256(expected));
    }

    function testFuzzCashRoundingConservesGrossAndFeesBothBranches(uint128 ticketPriceSeed) public {
        uint256 ticketPrice = bound(uint256(ticketPriceSeed), 1, 1e24);
        Raffle raffle = _create(ticketPrice, 2);
        _fundAndApprove(raffle, ticketPrice);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);

        _resolve(raffle, bytes32(0));

        uint256 fee = Math.mulDiv(ticketPrice, PROTOCOL_FEE_BPS, BPS);
        uint256 distributable = ticketPrice - fee;
        uint256 winnerCash = Math.mulDiv(distributable, CASH_WINNER_BPS, BPS);
        uint256 sponsorCash = distributable - winnerCash;
        assertEq(raffle.claimableQuote(treasury), fee);
        assertEq(raffle.winnerCashLiability(), winnerCash);
        assertEq(raffle.claimableQuote(sponsor), sponsorCash);
        assertEq(fee + winnerCash + sponsorCash, ticketPrice);
    }

    function testFuzzCurrentOwnerCanRedeemWinningTicket(uint256 ticketCountSeed, uint256 transferSeed) public {
        uint256 ticketCount = bound(ticketCountSeed, 1, 100);
        Raffle raffle = _create(1e6, ticketCount);
        _fundAndApprove(raffle, ticketCount * 1e6);
        vm.prank(buyer);
        raffle.buyTickets(buyer, ticketCount);

        uint256 winningTicket = bound(transferSeed, 1, ticketCount);
        vm.prank(buyer);
        raffle.transferFrom(buyer, recipient, winningTicket);
        _resolve(raffle, bytes32(winningTicket - 1));

        vm.prank(recipient);
        raffle.redeemWinningTicket(recipient);
        assertEq(prize.ownerOf(raffle.prizeTokenId()), recipient);
        assertTrue(raffle.winningTicketRedeemed());
    }

    function testFuzzRefundBurnsPayExactlyOnce(uint128 ticketPriceSeed, uint256 ticketCountSeed) public {
        uint256 ticketPrice = bound(uint256(ticketPriceSeed), 1, 1e24);
        uint256 ticketCount = bound(ticketCountSeed, 1, 100);
        Raffle raffle = _create(ticketPrice, ticketCount + 1);
        uint256 gross = ticketPrice * ticketCount;
        _fundAndApprove(raffle, gross);
        vm.prank(buyer);
        raffle.buyTickets(buyer, ticketCount);
        vm.warp(raffle.requestGraceDeadline());
        raffle.enableRefunds();

        uint256[] memory ticketIds = new uint256[](ticketCount);
        for (uint256 i; i < ticketCount; ++i) {
            ticketIds[i] = i + 1;
        }
        uint256 beforeBalance = quote.balanceOf(buyer);
        vm.prank(buyer);
        raffle.redeemRefundTickets(ticketIds, buyer);

        assertEq(quote.balanceOf(buyer), beforeBalance + gross);
        assertEq(raffle.remainingRefundLiability(), 0);
        assertEq(raffle.accountedQuoteBalance(), 0);
        vm.prank(buyer);
        vm.expectRevert();
        raffle.redeemRefundTickets(ticketIds, buyer);
    }

    function _create(uint256 ticketPrice, uint256 minimumTickets) internal returns (Raffle raffle) {
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        raffle = Raffle(
            payable(
                factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        prizeToken: address(prize),
                        prizeTokenId: tokenId,
                        sponsorPrizeRecoveryRecipient: address(0),
                        ticketPrice: ticketPrice,
                        minimumTickets: minimumTickets,
                        startTime: block.timestamp,
                        endTime: block.timestamp + 1 days,
                        metadataURI: "ipfs://fuzz"
                    })
                )
            )
        );
    }

    function _fundAndApprove(Raffle raffle, uint256 amount) internal {
        quote.mint(buyer, amount);
        vm.prank(buyer);
        quote.approve(address(raffle), type(uint256).max);
    }

    function _resolve(Raffle raffle, bytes32 randomNumber) internal {
        vm.warp(raffle.endTime());
        vm.prank(requester);
        uint64 sequence = raffle.requestDraw{ value: raffle.getEntropyFee() }();
        entropy.fulfill(sequence, randomNumber);
    }
}
