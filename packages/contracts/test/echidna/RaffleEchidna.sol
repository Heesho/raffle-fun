// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { Raffle } from "../../src/Raffle.sol";
import { RaffleFactory } from "../../src/RaffleFactory.sol";
import { IRaffle } from "../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../src/interfaces/IRaffleFactory.sol";
import { MockERC20 } from "../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../src/mocks/MockERC721.sol";
import { MockVRFV2PlusWrapper } from "../../src/mocks/MockVRFV2PlusWrapper.sol";

abstract contract RaffleEchidnaBase is IERC721Receiver {
    uint256 internal constant ENTRY_PRICE = 1e6;
    address internal constant TREASURY = address(0xCAFE);

    MockERC20 public immutable quote;
    MockERC721 public immutable prize;
    MockVRFV2PlusWrapper public immutable vrfWrapper;
    RaffleFactory public immutable factory;
    Raffle public immutable raffle;

    uint256[] public receiptIds;
    uint256 public ghostPaidOut;
    uint256 public highestStatus;
    bool public statusRegressed;

    constructor(uint128 reserveEntries_) payable {
        quote = new MockERC20();
        prize = new MockERC721();
        vrfWrapper = new MockVRFV2PlusWrapper();
        vrfWrapper.setFee(0);
        factory = new RaffleFactory(address(quote), address(vrfWrapper), TREASURY, address(this));
        prize.mint(address(this), 1);
        prize.setApprovalForAll(address(factory), true);
        raffle = Raffle(
            payable(factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: address(this),
                        prizeToken: address(prize),
                        prizeTokenId: 1,
                        reserveEntries: reserveEntries_,
                        endTime: uint64(block.timestamp + 7 days)
                    })
                ))
        );
        quote.mint(address(this), 1_000_000 * ENTRY_PRICE);
        quote.approve(address(raffle), type(uint256).max);
        highestStatus = uint256(raffle.status());
    }

    function buy(uint8 quantitySeed) external {
        if (
            raffle.status() != IRaffle.Status.Active || block.timestamp >= raffle.endTime()
                || raffle.totalEntries() >= 100
        ) return;
        uint128 remaining = 100 - raffle.totalEntries();
        uint128 quantity = uint128((uint256(quantitySeed) % 5) + 1);
        if (quantity > remaining) quantity = remaining;
        try raffle.buyEntries(address(this), quantity) returns (uint256 receiptId) {
            receiptIds.push(receiptId);
        } catch { }
        _observe();
    }

    function requestDraw() external {
        if (
            raffle.status() != IRaffle.Status.Active || raffle.totalEntries() == 0 || block.timestamp < raffle.endTime()
                || block.timestamp >= raffle.drawRequestDeadline()
        ) {
            return;
        }
        try raffle.requestDraw() { } catch { }
        _observe();
    }

    function fulfill(uint256 randomWord) external {
        if (raffle.status() != IRaffle.Status.Drawing) return;
        try vrfWrapper.fulfill(raffle.vrfRequestId(), randomWord) { } catch { }
        _observe();
    }

    function enableRefunds() external {
        IRaffle.Status current = raffle.status();
        bool ready = current == IRaffle.Status.Active && raffle.totalEntries() == 0;
        ready = ready
            || (current == IRaffle.Status.Active
                && raffle.totalEntries() != 0
                && block.timestamp >= raffle.drawRequestDeadline());
        ready = ready || (current == IRaffle.Status.Drawing && block.timestamp >= raffle.callbackDeadline());
        if (!ready) return;
        try raffle.enableRefunds() { } catch { }
        _observe();
    }

    function redeemCandidateWinner(uint256 receiptSeed) external {
        IRaffle.Status current = raffle.status();
        if ((current != IRaffle.Status.NftWon && current != IRaffle.Status.CashWon) || receiptIds.length == 0) return;
        uint256 receiptId = receiptIds[receiptSeed % receiptIds.length];
        try raffle.ownerOf(receiptId) returns (address owner) {
            if (owner != address(this)) return;
            try raffle.redeemWinningTicket(receiptId) returns (uint256 amount) {
                ghostPaidOut += amount;
            } catch { }
        } catch { }
        _observe();
    }

    function settleCandidateWinner(uint256 receiptSeed) external {
        IRaffle.Status current = raffle.status();
        if ((current != IRaffle.Status.NftWon && current != IRaffle.Status.CashWon) || receiptIds.length == 0) return;
        uint256 receiptId = receiptIds[receiptSeed % receiptIds.length];
        try raffle.settleWinningTicket(receiptId) { } catch { }
        _observe();
    }

    function redeemCandidateRefund(uint256 receiptSeed) external {
        if (raffle.status() != IRaffle.Status.Refunding || receiptIds.length == 0) return;
        uint256 receiptId = receiptIds[receiptSeed % receiptIds.length];
        try raffle.ownerOf(receiptId) returns (address owner) {
            if (owner != address(this)) return;
            uint256[] memory ids = new uint256[](1);
            ids[0] = receiptId;
            try raffle.refundTickets(ids) returns (uint256 amount) {
                ghostPaidOut += amount;
            } catch { }
        } catch { }
        _observe();
    }

    function releaseSponsorProceeds() external {
        if (raffle.sponsorProceeds() == 0) return;
        try raffle.releaseSponsorProceeds() returns (uint256 amount) {
            ghostPaidOut += amount;
        } catch { }
        _observe();
    }

    function releaseProtocolFees() external {
        if (raffle.protocolFees() == 0) return;
        try raffle.releaseProtocolFees() returns (uint256 amount) {
            ghostPaidOut += amount;
        } catch { }
        _observe();
    }

    function releaseSponsorPrize() external {
        IRaffle.Status current = raffle.status();
        if (raffle.prizeClaimed() || (current != IRaffle.Status.CashWon && current != IRaffle.Status.Refunding)) {
            return;
        }
        try raffle.releaseSponsorPrize() { } catch { }
        _observe();
    }

    function echidna_status_never_regresses() external view returns (bool) {
        return !statusRegressed;
    }

    function echidna_ranges_partition_all_entries() external view returns (bool) {
        uint256 expectedFirst = 1;
        for (uint256 index; index < receiptIds.length; ++index) {
            (uint128 firstEntry, uint128 lastEntry) = raffle.ticketRange(receiptIds[index]);
            if (firstEntry != expectedFirst || lastEntry < firstEntry) return false;
            expectedFirst = uint256(lastEntry) + 1;
        }
        return expectedFirst - 1 == raffle.totalEntries() && receiptIds.length == raffle.ticketCount();
    }

    function echidna_sales_and_liabilities_are_exact() external view returns (bool) {
        uint256 liabilities = raffle.unsettledPot() + raffle.remainingRefundLiability() + raffle.winnerProceeds()
            + raffle.sponsorProceeds() + raffle.protocolFees();
        return raffle.grossSales() == uint256(raffle.totalEntries()) * ENTRY_PRICE
            && raffle.accountedQuoteBalance() == liabilities && quote.balanceOf(address(raffle)) >= liabilities
            && raffle.grossSales() == quote.balanceOf(address(raffle)) + ghostPaidOut;
    }

    function echidna_winner_is_in_sold_range() external view returns (bool) {
        if (raffle.winningEntry() == 0) return true;
        return raffle.winningEntry() >= 1 && raffle.winningEntry() <= raffle.totalEntries();
    }

    function echidna_prize_custody_matches_claim_marker() external view returns (bool) {
        if (raffle.prizeClaimed()) return prize.ownerOf(1) != address(raffle);
        return prize.ownerOf(1) == address(raffle);
    }

    function echidna_draw_and_callback_deadlines_are_ordered() external view returns (bool) {
        if (raffle.drawRequestDeadline() != uint256(raffle.endTime()) + 2 days) return false;
        uint256 requestedAt = raffle.drawRequestedAt();
        if (requestedAt != 0) {
            if (requestedAt < raffle.endTime() || requestedAt >= raffle.drawRequestDeadline()) return false;
            if (raffle.callbackDeadline() != requestedAt + 2 days) return false;
        }
        uint256 resolvedAt = raffle.resolvedAt();
        return resolvedAt == 0 || (resolvedAt >= requestedAt && resolvedAt < raffle.callbackDeadline());
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _observe() internal {
        uint256 current = uint256(raffle.status());
        if (current < highestStatus) statusRegressed = true;
        if (current > highestStatus) highestStatus = current;
    }
}

contract RaffleEchidna is RaffleEchidnaBase {
    constructor() payable RaffleEchidnaBase(25) { }
}

contract RaffleNftEchidna is RaffleEchidnaBase {
    constructor() payable RaffleEchidnaBase(1) { }
}
