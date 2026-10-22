// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";

import { HonestPrize, MockQuoteToken, MockVrfWrapper } from "./S6Mocks.sol";

contract S6Echidna is IERC721Receiver {
    uint256 private constant ENTRY_PRICE = 1_000_000;
    uint256 private constant MAX_ACTIONS = 64;

    MockQuoteToken public immutable quote;
    MockVrfWrapper public immutable wrapper;
    RaffleFactory public immutable factory;
    HonestPrize public immutable prize;
    Raffle public immutable raffle;
    uint256 public successfulBuys;

    constructor() {
        quote = new MockQuoteToken();
        wrapper = new MockVrfWrapper(address(quote));
        factory = new RaffleFactory(address(quote), address(wrapper), address(0xE71D));
        prize = new HonestPrize();
        prize.mint(address(this), 1);
        prize.approve(address(factory), 1);
        raffle = Raffle(
            payable(
                factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: address(0xE510),
                        prizeToken: address(prize),
                        prizeTokenId: 1,
                        reserveEntries: type(uint128).max,
                        endTime: uint64(block.timestamp + 30 days)
                    })
                )
            )
        );
        quote.mint(address(this), uint256(type(uint128).max) * ENTRY_PRICE);
        quote.approve(address(raffle), type(uint256).max);
    }

    function buy(uint128 rawEntries) external {
        if (successfulBuys >= MAX_ACTIONS) return;
        uint128 entries = uint128(uint256(rawEntries) % 1_000 + 1);
        raffle.buyEntries(address(this), entries);
        ++successfulBuys;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function echidna_active_sales_accounting_equals_custody() external view returns (bool) {
        return raffle.status() == IRaffle.Status.Active && raffle.unsettledPot() == raffle.grossSales()
            && raffle.accountedQuoteBalance() == raffle.grossSales()
            && quote.balanceOf(address(raffle)) == raffle.accountedQuoteBalance();
    }

    function echidna_ranges_form_contiguous_partition() external view returns (bool) {
        uint256 tickets = raffle.ticketCount();
        uint256 expectedFirst = 1;
        for (uint256 ticketId = 1; ticketId <= tickets; ++ticketId) {
            (uint128 firstEntry, uint128 lastEntry) = raffle.ticketRange(ticketId);
            if (firstEntry != expectedFirst || lastEntry < firstEntry || raffle.ownerOf(ticketId) != address(this)) {
                return false;
            }
            expectedFirst = uint256(lastEntry) + 1;
        }
        return expectedFirst - 1 == raffle.totalEntries() && tickets == successfulBuys;
    }

    function echidna_no_terminal_liabilities_during_active_sales() external view returns (bool) {
        return raffle.remainingRefundLiability() == 0 && raffle.winnerProceeds() == 0
            && raffle.sponsorProceeds() == 0 && raffle.protocolFees() == 0 && !raffle.settlementComplete()
            && !raffle.winnerRedeemed() && !raffle.prizeClaimed();
    }

    function echidna_factory_registry_is_bidirectionally_consistent() external view returns (bool) {
        return factory.raffleCount() == 1 && factory.raffleById(1) == address(raffle)
            && factory.idByRaffle(address(raffle)) == 1 && factory.isRaffle(address(raffle));
    }
}
