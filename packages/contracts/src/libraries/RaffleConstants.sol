// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/**
 * @title raffle.fun Protocol Constants
 * @author Heesho
 * @notice Defines the economic percentages and bounded-execution limits shared by raffle.fun contracts.
 * @dev Constants are compiled into each constructor-deployed raffle, so factory ownership cannot extend an
 *      existing raffle's custody period or increase its per-transaction loops.
 * @custom:version 2.0.0
 */
library RaffleConstants {
    /// @notice Denominator used for all basis-point calculations.
    uint256 internal constant BPS = 10_000;

    /// @notice Protocol fee charged only when verified randomness resolves a sold raffle.
    uint256 internal constant PROTOCOL_FEE_BPS = 500;

    /// @notice Winner share of the post-fee pot when the minimum-ticket threshold is missed.
    uint256 internal constant CASH_WINNER_BPS = 8000;

    /// @notice Maximum ERC-721 tickets minted by one purchase, bounding receiver callbacks and gas consumption.
    uint256 internal constant MAX_TICKETS_PER_PURCHASE = 100;

    /// @notice Maximum refundable bearer tickets burned by one redemption transaction.
    uint256 internal constant MAX_REFUND_REDEMPTION_BATCH_SIZE = 100;

    /// @notice Maximum time between raffle creation and its configured sale start.
    uint256 internal constant MAX_START_DELAY = 7 days;

    /// @notice Maximum inclusive-start/exclusive-end ticket-sale duration.
    uint256 internal constant MAX_SALE_DURATION = 30 days;

    /// @notice Time after sale end during which the one Entropy request may be submitted.
    uint256 internal constant DRAW_REQUEST_GRACE_PERIOD = 3 days;

    /// @notice Time after an accepted Entropy request before permissionless refund finalization becomes available.
    uint256 internal constant DRAW_CALLBACK_TIMEOUT = 2 days;

    /// @notice Maximum accepted byte length for a raffle and ticket metadata URI.
    uint256 internal constant MAX_METADATA_URI_LENGTH = 2048;
}
