// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IRaffle } from "./IRaffle.sol";

/**
 * @title raffle.fun Raffle Lens Interface
 * @author Heesho
 * @notice Defines bounded wallet-oriented reads for canonical constructor-deployed raffles.
 * @dev Every read authenticates the raffle through the immutable factory registry before forwarding calls.
 * @custom:version 2.0.0
 */
interface IRaffleLens {
    /// @notice Chain-authoritative lifecycle, liabilities, bearer claims, deadlines, and account actions.
    struct RaffleView {
        uint256 factoryId;
        bool registered;
        address raffle;
        IRaffle.Status status;
        address sponsor;
        address sponsorPrizeRecoveryRecipient;
        address protocolTreasury;
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
        uint256 remainingRefundLiability;
        uint256 winnerCashLiability;
        uint256 totalClaimableQuote;
        uint256 accountedQuoteBalance;
        uint256 winningTicketId;
        address winningTicketOwner;
        bool winningTicketRedeemed;
        bool prizeClaimed;
        uint256 accountTicketBalance;
        uint256 accountQuoteClaim;
        bool accountOwnsWinningTicket;
        bool accountIsPrizeRecoveryRecipient;
        uint256 entropyFee;
        bool entropyFeeAvailable;
        bool canBuy;
        bool canDraw;
        bool canEnableRefunds;
        bool canRedeemWinningTicket;
        bool canRedeemRefundTickets;
        bool canClaimQuote;
        bool canClaimSponsorPrize;
    }

    /// @notice Raised before forwarding any read to an address outside the canonical registry.
    error UnregisteredRaffle(address raffle);
    /// @notice Raised when a wallet batch exceeds the explicit read bound.
    error BatchTooLarge(uint256 supplied, uint256 maximum);
    /// @notice Raised when the immutable factory dependency is zero or has no code.
    error InvalidFactory(address factory);

    /// @notice Aggregates protocol and optional account state for one registered raffle.
    function getRaffleState(address raffle, address account) external view returns (RaffleView memory raffleView);
    /// @notice Aggregates protocol and optional account state for a bounded registered-raffle batch.
    function getRaffleStates(address[] calldata raffles, address account)
        external
        view
        returns (RaffleView[] memory raffleViews);
}
