// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { Raffle } from "../../src/Raffle.sol";
import { IRaffle } from "../../src/interfaces/IRaffle.sol";
import { MockERC20 } from "../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../src/mocks/MockERC721.sol";
import { MockEntropyV2 } from "../../src/mocks/MockEntropyV2.sol";

/// @notice Independent Echidna harness base; it does not inherit Foundry helpers or production models.
abstract contract RaffleEchidnaBase is IERC721Receiver {
    uint256 internal constant PRICE = 1e6;
    address internal constant RECOVERY = address(0xBEEF);
    address internal constant TREASURY = address(0xCAFE);

    MockERC20 public immutable quote;
    MockERC721 public immutable prize;
    MockEntropyV2 public immutable entropy;
    Raffle public immutable raffle;

    uint256 public ghostPaidOut;
    uint256 public highestStatus;
    bool public statusRegressed;

    constructor(uint256 minimumTickets_) payable {
        quote = new MockERC20();
        prize = new MockERC721();
        entropy = new MockEntropyV2();
        entropy.setFee(0);
        prize.mint(address(this), 1);
        raffle = new Raffle(
            IRaffle.RaffleParams({
                factory: address(this),
                sponsor: address(this),
                sponsorPrizeRecoveryRecipient: RECOVERY,
                protocolTreasury: TREASURY,
                quoteToken: address(quote),
                entropy: address(entropy),
                prizeToken: address(prize),
                prizeTokenId: 1,
                raffleId: 1,
                ticketPrice: PRICE,
                minimumTickets: minimumTickets_,
                startTime: block.timestamp,
                endTime: block.timestamp + 7 days,
                callbackGasLimit: 300_000,
                metadataURI: "ipfs://echidna"
            })
        );
        prize.safeTransferFrom(address(this), address(raffle), 1);
        quote.mint(address(this), 1_000_000 * PRICE);
        quote.approve(address(raffle), type(uint256).max);
        highestStatus = uint256(raffle.status());
    }

    function buy(uint8 quantitySeed) external {
        if (
            raffle.status() != IRaffle.Status.Active || block.timestamp < raffle.startTime()
                || block.timestamp >= raffle.endTime() || raffle.totalTickets() >= 100
        ) return;
        uint256 remaining = 100 - raffle.totalTickets();
        uint256 quantity = (uint256(quantitySeed) % 5) + 1;
        if (quantity > remaining) quantity = remaining;
        try raffle.buyTickets(address(this), quantity) { } catch { }
        _observe();
    }

    function requestDraw() external {
        if (
            raffle.status() != IRaffle.Status.Active || raffle.totalTickets() == 0
                || block.timestamp < raffle.endTime() || block.timestamp >= raffle.requestGraceDeadline()
        ) return;
        try raffle.requestDraw() { } catch { }
        _observe();
    }

    function fulfill(bytes32 randomNumber) external {
        if (raffle.status() != IRaffle.Status.Drawing) return;
        try entropy.fulfill(raffle.entropySequenceNumber(), randomNumber) { } catch { }
        _observe();
    }

    function enableRefunds() external {
        IRaffle.Status current = raffle.status();
        bool ready = current == IRaffle.Status.Active && raffle.totalTickets() != 0
            && block.timestamp >= raffle.requestGraceDeadline();
        ready = ready
            || (current == IRaffle.Status.Drawing && block.timestamp >= raffle.callbackDeadline());
        ready = ready
            || (current == IRaffle.Status.NftWon
                && !raffle.prizeClaimed()
                && block.timestamp >= raffle.nftRedemptionDeadline());
        if (!ready) return;
        try raffle.enableRefunds() { } catch { }
        _observe();
    }

    function redeemOneRefund(uint256 ticketSeed) external {
        if (raffle.status() != IRaffle.Status.Refunding || raffle.balanceOf(address(this)) == 0) return;
        uint256 sold = raffle.totalTickets();
        uint256 start = (ticketSeed % sold) + 1;
        for (uint256 offset; offset < sold; ++offset) {
            uint256 ticketId = ((start - 1 + offset) % sold) + 1;
            try raffle.ownerOf(ticketId) returns (address owner) {
                if (owner == address(this)) {
                    uint256[] memory ids = new uint256[](1);
                    ids[0] = ticketId;
                    try raffle.redeemRefundTickets(ids, address(this)) returns (uint256 amount) {
                        ghostPaidOut += amount;
                    } catch { }
                    break;
                }
            } catch { }
        }
        _observe();
    }

    function redeemWinner() external {
        IRaffle.Status current = raffle.status();
        if (current != IRaffle.Status.NftWon && current != IRaffle.Status.CashWon) return;
        uint256 winner = raffle.winningTicketId();
        try raffle.ownerOf(winner) returns (address owner) {
            if (owner != address(this)) return;
            try raffle.redeemWinningTicket(RECOVERY) returns (uint256 amount) {
                ghostPaidOut += amount;
            } catch { }
        } catch { }
        _observe();
    }

    function claimSponsorQuote() external {
        uint256 amount = raffle.claimableQuote(address(this));
        if (amount == 0) return;
        try raffle.claimQuote(address(this)) returns (uint256 paid) {
            ghostPaidOut += paid;
        } catch { }
        _observe();
    }

    function claimProtocolQuote() external {
        uint256 amount = raffle.claimableQuote(TREASURY);
        if (amount == 0) return;
        try raffle.claimQuoteFor(TREASURY) returns (uint256 paid) {
            ghostPaidOut += paid;
        } catch { }
        _observe();
    }

    function closeAndRecoverEmpty() external {
        if (raffle.status() == IRaffle.Status.Active && raffle.totalTickets() == 0) {
            try raffle.closeEmptyRaffle() { } catch { }
        }
        IRaffle.Status current = raffle.status();
        if (
            !raffle.prizeClaimed()
                && (
                    current == IRaffle.Status.CashWon || current == IRaffle.Status.Refunding
                        || current == IRaffle.Status.Closed
                )
        ) {
            // The fixed recovery account, rather than this harness, is the only authorized caller.
        }
        _observe();
    }

    function echidna_status_never_regresses() external view returns (bool) {
        return !statusRegressed;
    }

    function echidna_ticket_and_sales_accounting() external view returns (bool) {
        return raffle.grossSales() == raffle.totalTickets() * PRICE;
    }

    function echidna_quote_liability_identity_and_solvency() external view returns (bool) {
        uint256 liabilities = raffle.unsettledPot() + raffle.remainingRefundLiability()
            + raffle.winnerCashLiability() + raffle.totalClaimableQuote();
        return raffle.accountedQuoteBalance() == liabilities && quote.balanceOf(address(raffle)) >= liabilities;
    }

    function echidna_gross_equals_balance_plus_payouts() external view returns (bool) {
        return raffle.grossSales() == quote.balanceOf(address(raffle)) + ghostPaidOut;
    }

    function echidna_winner_is_in_sold_range() external view returns (bool) {
        IRaffle.Status current = raffle.status();
        uint256 winner = raffle.winningTicketId();
        if (raffle.resolvedAt() == 0) return winner == 0;
        if (current != IRaffle.Status.NftWon && current != IRaffle.Status.CashWon) {
            if (current != IRaffle.Status.Refunding) return false;
        }
        return winner >= 1 && winner <= raffle.totalTickets();
    }

    function echidna_prize_leaves_only_after_claim_marker() external view returns (bool) {
        if (raffle.prizeClaimed()) return prize.ownerOf(1) != address(raffle);
        return prize.ownerOf(1) == address(raffle);
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

/// @notice Exercises both the below-threshold cash branch and the above-threshold NFT branch.
contract RaffleEchidna is RaffleEchidnaBase {
    constructor() payable RaffleEchidnaBase(25) { }
}

/// @notice Forces every successful draw through the NFT branch, including its redemption timeout fallback.
contract RaffleNftEchidna is RaffleEchidnaBase {
    constructor() payable RaffleEchidnaBase(1) { }
}
