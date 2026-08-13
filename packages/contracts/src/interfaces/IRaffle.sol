// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IEntropyV2} from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";

/**
 * @title raffle.fun Raffle Escrow and Bearer Ticket Interface
 * @author Heesho
 * @notice Defines a constructor-deployed raffle whose tickets burn to redeem the winning asset or their own refund.
 * @dev The current ticket owner is the claim owner. Ownership freezes while randomness is pending, and the selected
 *      ticket remains locked after resolution so advance knowledge or stale marketplace approvals cannot redirect
 *      the award. Refundable tickets are transferable until they burn for their purchase-price refund. Supported quote
 *      tokens are non-rebasing exact-transfer ERC-20s. Supported prizes are honest, standards-compliant ERC-721s.
 * @custom:version 2.0.0
 */
interface IRaffle {
    /// @notice The single authoritative lifecycle and economic result.
    enum Status {
        AwaitingPrize,
        Active,
        Drawing,
        NftWon,
        CashWon,
        Refunding,
        Closed
    }

    /**
     * @notice Complete immutable raffle configuration supplied by the canonical factory constructor call.
     * @param factory Canonical factory deploying and registering this raffle.
     * @param sponsor Prize depositor and successful sponsor-cash recipient.
     * @param sponsorPrizeRecoveryRecipient Fixed sponsor-side NFT recovery account.
     * @param protocolTreasury Treasury captured for this raffle.
     * @param quoteToken Factory-wide exact-transfer USDC deployment.
     * @param entropy Pyth Entropy v2 deployment.
     * @param prizeToken Standards-compliant ERC-721 prize contract.
     * @param prizeTokenId Escrowed prize token ID.
     * @param raffleId Canonical factory identifier.
     * @param ticketPrice Raw USDC units per ticket.
     * @param minimumTickets Threshold selecting NFT versus cash outcome after a successful draw.
     * @param startTime Inclusive ticket-sale start.
     * @param endTime Exclusive ticket-sale end.
     * @param callbackGasLimit Gas limit supplied to Entropy v2.
     * @param metadataURI Raffle and souvenir-ticket metadata URI.
     */
    struct RaffleParams {
        address factory;
        address sponsor;
        address sponsorPrizeRecoveryRecipient;
        address protocolTreasury;
        address quoteToken;
        address entropy;
        address prizeToken;
        uint256 prizeTokenId;
        uint256 raffleId;
        uint256 ticketPrice;
        uint256 minimumTickets;
        uint256 startTime;
        uint256 endTime;
        uint32 callbackGasLimit;
        string metadataURI;
    }

    /// @notice Raised when construction is not performed by the configured factory.
    error OnlyFactory();
    /// @notice Raised when a required account or destination is zero.
    error ZeroAddress();
    /// @notice Raised when an action requires another lifecycle status.
    error InvalidStatus(Status actual);
    /// @notice Raised when the factory-operated safe deposit differs from the configured prize.
    error UnexpectedPrize(address token, uint256 tokenId, address from, address operator);
    /// @notice Raised when a purchase precedes the inclusive start timestamp.
    error SaleNotStarted(uint256 startTime, uint256 currentTime);
    /// @notice Raised when a purchase occurs at or after the exclusive end timestamp.
    error SaleEnded(uint256 endTime, uint256 currentTime);
    /// @notice Raised when a ticket recipient is zero.
    error InvalidRecipient();
    /// @notice Raised when a purchase or redemption batch is empty or exceeds its explicit bound.
    error InvalidQuantity(uint256 quantity, uint256 maximum);
    /// @notice Raised when purchase multiplication would overflow.
    error GrossAmountOverflow();
    /// @notice Raised when an incoming quote transfer does not credit the exact advertised amount.
    error UnsupportedQuoteToken(uint256 expectedAmount, uint256 receivedAmount);
    /// @notice Raised when an outgoing quote transfer does not debit and credit the exact liability amount.
    error UnsupportedQuoteTokenTransfer(uint256 expectedAmount, uint256 debitedAmount, uint256 creditedAmount);
    /// @notice Raised when a quote payment targets a known protocol contract that cannot recover the payment.
    error InvalidQuoteDestination(address destination);
    /// @notice Raised when an early empty-raffle closure is attempted by anyone other than the sponsor.
    error OnlySponsor();
    /// @notice Raised when an empty-raffle action is attempted after a ticket sale.
    error TicketsWereSold(uint256 totalTickets);
    /// @notice Raised when an end-dependent action is attempted before sale end.
    error RaffleNotEnded(uint256 endTime, uint256 currentTime);
    /// @notice Raised when a draw or refund action requires at least one ticket.
    error NoTicketsSold();
    /// @notice Raised when a draw request is attempted at or after the request-grace deadline.
    error DrawRequestWindowExpired(uint256 deadline, uint256 currentTime);
    /// @notice Raised when refunds are enabled before the applicable oracle-liveness deadline.
    error RefundsNotAvailable(uint256 deadline, uint256 currentTime);
    /// @notice Raised when less than the current Entropy fee is supplied.
    error InsufficientEntropyFee(uint256 requiredFee, uint256 suppliedValue);
    /// @notice Raised when immediate return of excess Entropy payment fails.
    error NativeRefundFailed(address recipient, uint256 amount);
    /// @notice Raised when an account has no ordinary quote-token claim.
    error NoQuoteClaim(address account);
    /// @notice Raised when a bearer or fixed claimant would become a known non-callable protocol address.
    error UnsafeProtocolDestination(address destination);
    /// @notice Raised when ticket ownership is fixed during the draw or for the selected winning credential.
    error TicketTransferLocked(uint256 ticketId, Status status);
    /// @notice Raised when the caller does not own the ticket being redeemed.
    error NotTicketOwner(uint256 ticketId, address caller, address owner);
    /// @notice Raised when sponsor-side NFT recovery is unavailable for the current result.
    error SponsorPrizeUnavailable(Status status);
    /// @notice Raised when anyone other than the immutable recovery recipient attempts sponsor-side NFT recovery.
    error OnlyPrizeRecoveryRecipient(address caller, address recipient);
    /// @notice Raised when the configured prize already left escrow.
    error PrizeAlreadyClaimed();
    /// @notice Raised when a prize transfer reports success without assigning the NFT to the requested recipient.
    error PrizeDeliveryVerificationFailed(address recipient);

    /// @notice Emitted after the exact configured prize enters escrow and activates ticket sales.
    event PrizeDeposited(address indexed prizeToken, uint256 indexed prizeTokenId, address indexed sponsor);

    /// @notice Emitted once per bounded multi-ticket purchase after exact-transfer verification.
    event TicketsPurchased(
        address indexed buyer,
        address indexed recipient,
        uint256 quantity,
        uint256 firstTicketId,
        uint256 lastTicketId,
        uint256 grossAmount
    );

    /// @notice Emitted when a raffle with no ticket sales closes and exposes sponsor-side prize recovery.
    event EmptyRaffleClosed(address indexed caller, address indexed prizeRecoveryRecipient);

    /// @notice Emitted when the single Entropy v2 request is accepted and any overpayment is returned immediately.
    event DrawRequested(
        uint64 indexed sequenceNumber,
        address indexed requester,
        uint256 fee,
        uint256 excessReturned,
        uint256 drawRequestedAt,
        uint256 callbackDeadline
    );

    /// @notice Emitted when a wrong-sequence, in-flight, stale, or duplicate callback is ignored without reverting.
    event EntropyCallbackIgnored(uint64 indexed receivedSequence, uint64 indexed expectedSequence, Status status);

    /// @notice Emitted when verified randomness selects the bearer winning ticket and successful economic branch.
    event RaffleResolved(
        uint64 indexed sequenceNumber,
        uint256 indexed winningTicketId,
        Status indexed result,
        uint256 protocolFee,
        uint256 winnerCashAmount,
        uint256 sponsorCashAmount
    );

    /// @notice Emitted when either oracle-liveness deadline makes every outstanding ticket refundable.
    event RefundsEnabled(address indexed finalizer, bool indexed requestWasAccepted, uint256 remainingRefundLiability);

    /// @notice Emitted when the winning bearer ticket burns for the NFT or cash award.
    event WinningTicketRedeemed(
        uint256 indexed ticketId, address indexed owner, address indexed to, Status result, uint256 cashAmount
    );

    /// @notice Emitted when refundable bearer tickets burn for their aggregate purchase-price refund.
    event RefundTicketsRedeemed(
        address indexed owner, address indexed to, uint256 quantity, uint256 amount, uint256 remainingRefundLiability
    );

    /// @notice Emitted after an exact ordinary quote-token claim succeeds.
    event QuoteClaimed(address indexed account, address indexed to, uint256 amount);

    /// @notice Emitted after the recovery recipient withdraws the NFT from a cash, refund, or empty result.
    event SponsorPrizeClaimed(
        address indexed recipient, address indexed to, address indexed prizeToken, uint256 prizeTokenId
    );

    /// @notice Purchases and safely mints a bounded quantity of sequential bearer tickets.
    function buyTickets(address recipient, uint256 quantity)
        external
        returns (uint256 firstTicketId, uint256 lastTicketId);

    /// @notice Closes a zero-sales raffle; only the sponsor may do so before the configured end.
    function closeEmptyRaffle() external;

    /// @notice Returns the current Entropy v2 fee for the configured callback gas limit.
    function getEntropyFee() external view returns (uint256 fee);

    /// @notice Submits the sole draw request and immediately returns any native overpayment.
    function requestDraw() external payable returns (uint64 sequenceNumber);

    /// @notice Enables bearer-ticket refunds after either oracle-liveness deadline.
    function enableRefunds() external;

    /// @notice Burns the caller-owned winning ticket for its NFT or cash award.
    function redeemWinningTicket(address to) external returns (uint256 cashAmount);

    /// @notice Burns a bounded batch of caller-owned tickets for their aggregate exact refund.
    function redeemRefundTickets(uint256[] calldata ticketIds, address to) external returns (uint256 amount);
    /// @notice Pays the caller's ordinary quote claim to a chosen destination.
    function claimQuote(address to) external returns (uint256 amount);

    /// @notice Pays another account's ordinary quote claim only to that same account.
    function claimQuoteFor(address account) external returns (uint256 amount);

    /// @notice Lets the immutable recovery recipient withdraw the NFT after cash, refund, or empty settlement.
    function claimSponsorPrize(address to) external;

    /// @notice Returns `endTime + DRAW_REQUEST_GRACE_PERIOD`.
    function requestGraceDeadline() external view returns (uint256 deadline);

    /// @notice Returns the callback deadline, or zero before a request is accepted.
    function callbackDeadline() external view returns (uint256 deadline);

    /// @notice Returns the NFT delivery deadline, or zero unless the result is an unredeemed NFT win.
    function nftRedemptionDeadline() external view returns (uint256 deadline);

    /// @notice Returns whether the winning ticket has already burned for its award.
    function winningTicketRedeemed() external view returns (bool redeemed);

    /// @notice Returns all quote liabilities held by the raffle.
    function accountedQuoteBalance() external view returns (uint256 amount);

    /// @notice Returns the canonical factory that constructed and registered this raffle.
    function factory() external view returns (address);
    /// @notice Returns the immutable sponsor and successful sponsor-cash recipient.
    function sponsor() external view returns (address);
    /// @notice Returns the immutable sponsor-side NFT recovery account.
    function sponsorPrizeRecoveryRecipient() external view returns (address);
    /// @notice Returns the treasury captured when this raffle was created.
    function protocolTreasury() external view returns (address);
    /// @notice Returns the exact-transfer quote token used for purchases and settlements.
    function quoteToken() external view returns (IERC20);
    /// @notice Returns the immutable Pyth Entropy v2 deployment.
    function entropy() external view returns (IEntropyV2);
    /// @notice Returns the configured prize collection.
    function prizeToken() external view returns (IERC721);
    /// @notice Returns the configured prize token ID.
    function prizeTokenId() external view returns (uint256);
    /// @notice Returns the canonical factory-assigned identifier.
    function raffleId() external view returns (uint256);
    /// @notice Returns the price of one ticket in raw quote-token units.
    function ticketPrice() external view returns (uint256);
    /// @notice Returns the sold-ticket threshold selecting NFT rather than cash settlement.
    function minimumTickets() external view returns (uint256);
    /// @notice Returns the inclusive sale start timestamp.
    function startTime() external view returns (uint256);
    /// @notice Returns the exclusive sale end timestamp.
    function endTime() external view returns (uint256);
    /// @notice Returns the callback gas limit used consistently for Entropy fee quotes and requests.
    function callbackGasLimit() external view returns (uint32);
    /// @notice Returns the total number of tickets ever minted.
    function totalTickets() external view returns (uint256);
    /// @notice Returns cumulative gross ticket sales without subtracting later settlement.
    function grossSales() external view returns (uint256);
    /// @notice Returns sales awaiting either successful draw settlement or refund finalization.
    function unsettledPot() external view returns (uint256);
    /// @notice Returns the exact aggregate value of refundable tickets not yet burned.
    function remainingRefundLiability() external view returns (uint256);
    /// @notice Returns the cash award reserved for the unredeemed winning ticket.
    function winnerCashLiability() external view returns (uint256);
    /// @notice Returns aggregate sponsor and treasury pull claims.
    function totalClaimableQuote() external view returns (uint256);
    /// @notice Returns the accepted Entropy sequence, or zero before a request.
    function entropySequenceNumber() external view returns (uint64);
    /// @notice Returns the timestamp at which Entropy accepted the request, or zero before one.
    function drawRequestedAt() external view returns (uint256);
    /// @notice Returns the timestamp at which authenticated randomness resolved the raffle.
    function resolvedAt() external view returns (uint256);
    /// @notice Returns the selected winning ticket, or zero before successful resolution.
    function winningTicketId() external view returns (uint256);
    /// @notice Returns the single authoritative lifecycle and economic result.
    function status() external view returns (Status);
    /// @notice Returns an account's ordinary sponsor or treasury quote claim.
    function claimableQuote(address account) external view returns (uint256);
    /// @notice Returns whether the configured prize has left escrow through a supported settlement path.
    function prizeClaimed() external view returns (bool);
    /// @notice Returns the immutable metadata URI shared by the raffle tickets.
    function raffleMetadataURI() external view returns (string memory);
}
