// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IRaffle } from "./IRaffle.sol";

/// @title IRaffleLens
/// @notice Read-only bounded aggregation interface for chain-authoritative web application state.
interface IRaffleLens {
    /// @notice Chain state and account-specific action availability for one canonical raffle.
    /// @param factoryId Numeric factory identifier.
    /// @param registered Whether the supplied address belongs to the configured factory.
    /// @param raffle Raffle clone address.
    /// @param state Current lifecycle state.
    /// @param outcome Terminal outcome or none.
    /// @param sponsor Prize sponsor.
    /// @param protocolTreasury Treasury captured by this clone.
    /// @param quoteToken Gross payment token.
    /// @param prizeToken Prize NFT contract.
    /// @param prizeTokenId Prize token ID.
    /// @param ticketPrice Gross price per ticket.
    /// @param minimumTickets NFT-outcome threshold.
    /// @param startTime Inclusive start timestamp.
    /// @param endTime Exclusive end timestamp.
    /// @param totalTickets Tickets sold.
    /// @param grossSales Historical gross sales.
    /// @param netPot Unallocated pre-resolution pot.
    /// @param winningTicketId Resolved winning ticket.
    /// @param winner Snapshotted resolved winner.
    /// @param accountTicketBalance Tickets currently owned by the requested account.
    /// @param accountQuoteClaim Quote-token accrual for the requested account.
    /// @param accountIsPrizeClaimant Whether the requested account may claim the prize.
    /// @param entropyFee Current draw-request fee.
    /// @param canBuy Whether a purchase is currently accepted.
    /// @param canDraw Whether the only draw request is currently available.
    /// @param canClaimQuote Whether the requested account has a quote claim.
    /// @param canClaimPrize Whether the requested account can pull the unclaimed prize.
    struct RaffleView {
        uint256 factoryId;
        bool registered;
        address raffle;
        IRaffle.RaffleState state;
        IRaffle.RaffleOutcome outcome;
        address sponsor;
        address protocolTreasury;
        address quoteToken;
        address prizeToken;
        uint256 prizeTokenId;
        uint256 ticketPrice;
        uint256 minimumTickets;
        uint256 startTime;
        uint256 endTime;
        uint256 totalTickets;
        uint256 grossSales;
        uint256 netPot;
        uint256 winningTicketId;
        address winner;
        uint256 accountTicketBalance;
        uint256 accountQuoteClaim;
        bool accountIsPrizeClaimant;
        uint256 entropyFee;
        bool canBuy;
        bool canDraw;
        bool canClaimQuote;
        bool canClaimPrize;
    }

    /// @notice Raised when a candidate address is not registered by the configured factory.
    error UnregisteredRaffle(address raffle);
    /// @notice Raised when an aggregate request exceeds the explicit read bound.
    error BatchTooLarge(uint256 supplied, uint256 maximum);
    /// @notice Raised when the configured factory is zero or has no runtime code.
    error InvalidFactory(address factory);

    /// @notice Returns chain-authoritative state for one canonical raffle and account.
    /// @param raffle Canonical clone.
    /// @param account Optional account for ticket and claim reads.
    /// @return raffleView Aggregated state.
    function getRaffleState(address raffle, address account) external view returns (RaffleView memory raffleView);

    /// @notice Returns chain-authoritative state for a bounded list of canonical raffles.
    /// @param raffles Canonical clone addresses.
    /// @param account Optional account for ticket and claim reads.
    /// @return raffleViews Aggregated states in input order.
    function getRaffleStates(address[] calldata raffles, address account)
        external
        view
        returns (RaffleView[] memory raffleViews);
}
