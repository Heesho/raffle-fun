// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title RaffleConstants
/// @notice Canonical economic and bounded-execution constants shared by the protocol contracts.
library RaffleConstants {
    /// @notice Denominator used for all basis-point calculations.
    uint256 internal constant BPS = 10_000;
    /// @notice Protocol fee charged against gross ticket payments.
    uint256 internal constant PROTOCOL_FEE_BPS = 500;
    /// @notice Optional allowlisted-provider fee charged against gross ticket payments.
    uint256 internal constant PROVIDER_FEE_BPS = 500;
    /// @notice Cash-fallback share allocated to the snapshotted winning account.
    uint256 internal constant CASH_WINNER_BPS = 8000;
    /// @notice Maximum number of ERC721 tickets minted in one purchase transaction.
    uint256 internal constant MAX_TICKETS_PER_PURCHASE = 100;
    /// @notice Maximum accepted byte length for raffle metadata URIs.
    uint256 internal constant MAX_METADATA_URI_LENGTH = 2048;
}
