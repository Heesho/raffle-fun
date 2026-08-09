// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IRaffle } from "./IRaffle.sol";

/**
 * @title raffle.fun Raffle Lens Interface
 * @author Heesho
 * @notice Defines bounded, wallet-oriented reads for canonical raffle.fun clones.
 * @dev Every implementation must authenticate clone addresses through its immutable factory before forwarding reads.
 * @custom:version 1.0.0
 */
interface IRaffleLens {
    /**
     * @notice Chain-authoritative lifecycle, liability, deadline, and account action data for one raffle.
     * @dev `entropyFeeAvailable` distinguishes a real zero fee from an oracle fee read that currently reverts.
     */
    struct RaffleView {
        uint256 factoryId;
        bool registered;
        address raffle;
        IRaffle.RaffleState state;
        IRaffle.RaffleOutcome outcome;
        address sponsor;
        address sponsorPrizeRecoveryRecipient;
        address protocolTreasury;
        address prizeClaimant;
        address quoteToken;
        address prizeToken;
        uint256 prizeTokenId;
        uint256 ticketPrice;
        uint256 minimumTickets;
        uint256 startTime;
        uint256 endTime;
        uint256 requestGraceDeadline;
        uint256 drawRequestedAt;
        uint256 callbackDeadline;
        uint64 entropySequenceNumber;
        uint256 totalTickets;
        uint256 grossSales;
        uint256 unsettledPot;
        uint256 uncreditedRefundLiability;
        uint256 totalClaimableQuote;
        uint256 totalClaimableNative;
        uint256 accountedQuoteBalance;
        uint256 accountedNativeBalance;
        uint256 winningTicketId;
        address winner;
        uint256 accountTicketBalance;
        uint256 accountQuoteClaim;
        uint256 accountNativeClaim;
        bool accountIsPrizeClaimant;
        uint256 entropyFee;
        bool entropyFeeAvailable;
        bool canBuy;
        bool canDraw;
        bool canFinalizeUnrequestedDraw;
        bool canFinalizeTimedOutDraw;
        bool canClaimQuote;
        bool canClaimNative;
        bool canClaimPrize;
    }

    /// @notice Raised before any forwarded read when an address is not registered by the immutable factory.
    error UnregisteredRaffle(address raffle);
    /// @notice Raised when an aggregate request exceeds the explicit read bound.
    error BatchTooLarge(uint256 supplied, uint256 maximum);
    /// @notice Raised when construction is attempted with a zero or code-less factory.
    error InvalidFactory(address factory);

    /// @notice Returns wallet-oriented state for one canonical raffle and optional account.
    function getRaffleState(address raffle, address account) external view returns (RaffleView memory raffleView);

    /// @notice Returns wallet-oriented state for a bounded list of canonical raffles.
    function getRaffleStates(address[] calldata raffles, address account)
        external
        view
        returns (RaffleView[] memory raffleViews);
}
