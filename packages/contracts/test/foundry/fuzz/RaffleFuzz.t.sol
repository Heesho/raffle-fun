// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

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
        Raffle implementation = new Raffle();
        factory = new RaffleFactory(
            address(implementation), _quoteTokens(address(quote)), address(entropy), treasury, 300_000, address(this)
        );
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
        assertEq(raffle.claimableQuote(treasury), 0);
        assertEq(raffle.unsettledPot(), gross);
        assertEq(raffle.accountedQuoteBalance(), gross);
        assertEq(quote.balanceOf(address(raffle)), gross);
    }

    function testFuzzWinnerAlwaysInInclusiveTicketRange(uint256 ticketCountSeed, bytes32 randomNumber) public {
        uint256 ticketCount = bound(ticketCountSeed, 1, 100);
        Raffle raffle = _create(1e6, ticketCount);
        _fundAndApprove(raffle, ticketCount * 1e6);
        vm.prank(buyer);
        raffle.buyTickets(buyer, ticketCount);

        _resolve(raffle, randomNumber);

        uint256 winningTicket = raffle.winningTicketId();
        assertGe(winningTicket, 1);
        assertLe(winningTicket, ticketCount);
        assertEq(winningTicket, (uint256(randomNumber) % ticketCount) + 1);
        assertEq(raffle.ownerOf(winningTicket), raffle.winner());
    }

    function testFuzzLastTicketRemainsEligible(uint256 ticketCountSeed) public {
        uint256 ticketCount = bound(ticketCountSeed, 1, 100);
        Raffle raffle = _create(1e6, ticketCount);
        _fundAndApprove(raffle, ticketCount * 1e6);
        vm.prank(buyer);
        raffle.buyTickets(buyer, ticketCount);

        _resolve(raffle, bytes32(ticketCount - 1));
        assertEq(raffle.winningTicketId(), ticketCount);
    }

    function testFuzzThresholdBoundarySelectsExactBranch(uint256 ticketCountSeed, uint256 thresholdSeed) public {
        uint256 ticketCount = bound(ticketCountSeed, 1, 100);
        uint256 threshold = bound(thresholdSeed, 1, 150);
        Raffle raffle = _create(1e6, threshold);
        _fundAndApprove(raffle, ticketCount * 1e6);
        vm.prank(buyer);
        raffle.buyTickets(buyer, ticketCount);

        _resolve(raffle, bytes32(0));

        IRaffle.RaffleOutcome expected =
            ticketCount >= threshold ? IRaffle.RaffleOutcome.NftAwarded : IRaffle.RaffleOutcome.CashFallback;
        assertEq(uint256(raffle.outcome()), uint256(expected));
    }

    function testFuzzCashFallbackRoundingAssignsRemainderToSponsor(uint128 ticketPriceSeed) public {
        uint256 ticketPrice = bound(uint256(ticketPriceSeed), 1, 1e24);
        Raffle raffle = _create(ticketPrice, 2);
        _fundAndApprove(raffle, ticketPrice);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);

        uint256 protocolFee = Math.mulDiv(ticketPrice, PROTOCOL_FEE_BPS, BPS);
        uint256 net = ticketPrice - protocolFee;
        uint256 winnerAmount = Math.mulDiv(net, CASH_WINNER_BPS, BPS);
        uint256 sponsorAmount = net - winnerAmount;
        _resolve(raffle, bytes32(0));

        assertEq(raffle.claimableQuote(buyer), winnerAmount);
        assertEq(raffle.claimableQuote(sponsor), sponsorAmount);
        assertEq(raffle.claimableQuote(treasury), protocolFee);
        assertEq(winnerAmount + sponsorAmount, net);
    }

    function testFuzzTransferBeforeRequestPreservesEqualEligibility(
        uint256 ticketCountSeed,
        uint256 transferTicketSeed,
        bytes32 randomNumber
    ) public {
        uint256 ticketCount = bound(ticketCountSeed, 1, 100);
        uint256 transferTicket = bound(transferTicketSeed, 1, ticketCount);
        Raffle raffle = _create(1e6, ticketCount + 1);
        _fundAndApprove(raffle, ticketCount * 1e6);
        vm.prank(buyer);
        raffle.buyTickets(buyer, ticketCount);

        vm.prank(buyer);
        raffle.transferFrom(buyer, recipient, transferTicket);
        _resolve(raffle, randomNumber);

        uint256 expectedTicket = (uint256(randomNumber) % ticketCount) + 1;
        address expectedWinner = expectedTicket == transferTicket ? recipient : buyer;
        assertEq(raffle.winningTicketId(), expectedTicket);
        assertEq(raffle.winner(), expectedWinner);
    }

    function testFuzzArbitraryQuoteClaimOrder(bool reverseOrder) public {
        Raffle raffle = _create(1e6, 2);
        _fundAndApprove(raffle, 1e6);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);
        _resolve(raffle, bytes32(0));

        address[3] memory accounts = [treasury, buyer, sponsor];
        if (reverseOrder) {
            for (uint256 i = accounts.length; i != 0; --i) {
                if (raffle.claimableQuote(accounts[i - 1]) != 0) raffle.claimQuoteFor(accounts[i - 1]);
            }
        } else {
            for (uint256 i; i < accounts.length; ++i) {
                if (raffle.claimableQuote(accounts[i]) != 0) raffle.claimQuoteFor(accounts[i]);
            }
        }

        assertEq(raffle.totalClaimableQuote(), 0);
        assertEq(raffle.accountedQuoteBalance(), 0);
        assertEq(quote.balanceOf(address(raffle)), 0);
    }

    function _create(uint256 ticketPrice, uint256 minimumTickets) internal returns (Raffle raffle) {
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        address raffleAddress = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prize),
                prizeTokenId: tokenId,
                quoteToken: address(quote),
                ticketPrice: ticketPrice,
                minimumTickets: minimumTickets,
                startTime: block.timestamp,
                endTime: block.timestamp + 1 days,
                metadataURI: "ipfs://fuzz"
            })
        );
        raffle = Raffle(payable(raffleAddress));
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

    function _quoteTokens(address quoteToken_) internal pure returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = quoteToken_;
    }
}
