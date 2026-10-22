// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";

import { S6TestBase } from "./S6TestBase.sol";
import { HonestPrize, LyingPrize, MockQuoteToken, MockVrfWrapper } from "./S6Mocks.sol";

/// @dev These tests encode desired DESIGN.md properties and are intentionally run as a separate negative campaign.
///      They are expected to fail on the frozen source; passing reproductions live in S6SecureWorkflow.t.sol.
contract S6KnownViolationTest is S6TestBase {
    address internal constant BUYER = address(0x7100);
    address internal constant SPONSOR_RECIPIENT = address(0x7200);
    address internal constant TREASURY = address(0x7300);
    uint256 internal constant ENTRY_PRICE = 1_000_000;

    function _deployHonest() internal returns (MockQuoteToken quote, RaffleFactory factory, Raffle raffle) {
        quote = new MockQuoteToken();
        MockVrfWrapper wrapper = new MockVrfWrapper(address(quote));
        factory = new RaffleFactory(address(quote), address(wrapper), TREASURY);
        HonestPrize prize = new HonestPrize();
        prize.mint(address(this), 1);
        prize.approve(address(factory), 1);
        raffle = Raffle(
            payable(
                factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: SPONSOR_RECIPIENT,
                        prizeToken: address(prize),
                        prizeTokenId: 1,
                        reserveEntries: 1,
                        endTime: uint64(block.timestamp + 1 days)
                    })
                )
            )
        );
    }

    function test_Property_AllRaffleClonesAreRejectedDestinations() public {
        (MockQuoteToken quoteA,, Raffle raffleA) = _deployHonest();
        (,, Raffle raffleB) = _deployHonest();
        quoteA.mint(BUYER, ENTRY_PRICE);
        vm.prank(BUYER);
        quoteA.approve(address(raffleA), ENTRY_PRICE);
        vm.prank(BUYER);
        uint256 ticketId = raffleA.buyEntries(BUYER, 1);

        vm.expectPartialRevert(IRaffle.UnsafeProtocolDestination.selector);
        vm.prank(BUYER);
        raffleA.transferFrom(BUYER, address(raffleB), ticketId);
    }

    function test_Property_PrizeEscrowRequiresRealRatherThanSelfReportedCustody() public {
        MockQuoteToken quote = new MockQuoteToken();
        MockVrfWrapper wrapper = new MockVrfWrapper(address(quote));
        RaffleFactory factory = new RaffleFactory(address(quote), address(wrapper), TREASURY);
        LyingPrize prize = new LyingPrize(address(this), 1);
        prize.approve(address(factory), 1);

        vm.expectRevert();
        factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                sponsorRecipient: SPONSOR_RECIPIENT,
                prizeToken: address(prize),
                prizeTokenId: 1,
                reserveEntries: 1,
                endTime: uint64(block.timestamp + 1 days)
            })
        );
    }
}
