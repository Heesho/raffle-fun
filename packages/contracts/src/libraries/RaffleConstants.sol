// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/**
 * @title raffle.fun Protocol Constants
 * @author Heesho
 * @notice Fixed v1 economics, timing, and bounded-execution limits.
 * @custom:version 1.0.0
 */
library RaffleConstants {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant PROTOCOL_FEE_BPS = 500;
    uint256 internal constant CASH_WINNER_BPS = 8000;

    /// @notice One entry costs exactly one six-decimal quote token unit (one USDC).
    uint256 internal constant ENTRY_PRICE = 1_000_000;
    uint8 internal constant QUOTE_TOKEN_DECIMALS = 6;

    /// @notice Refund execution is bounded by tickets, while each ticket may represent any uint128 entry count.
    uint256 internal constant MAX_REFUND_TICKET_BATCH_SIZE = 100;

    uint256 internal constant MAX_SALE_DURATION = 30 days;
    uint256 internal constant DRAW_REQUEST_TIMEOUT = 2 days;
    uint256 internal constant DRAW_CALLBACK_TIMEOUT = 2 days;

    uint32 internal constant VRF_CALLBACK_GAS_LIMIT = 300_000;
    uint16 internal constant VRF_REQUEST_CONFIRMATIONS = 30;
}
