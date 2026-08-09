// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IEntropyV2 } from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";

/**
 * @title raffle.fun Raffle Escrow and Ticket Interface
 * @author Heesho
 * @notice Defines one immutable raffle clone, its transferable ticket NFTs, bounded draw, refunds, and pull claims.
 * @dev Supported prizes are honest standards-compliant ERC-721s. Supported quote tokens are non-rebasing exact-transfer
 *      ERC-20s admitted by the canonical factory. Token issuer controls, chain liveness, and lost keys remain external
 *      risks; the lifecycle guarantees recovery only while those supported assets and Base remain operational.
 * @custom:version 1.0.0
 */
interface IRaffle {
    /**
     * @notice Monotonic lifecycle state.
     * @dev `Refunding` freezes each uncredited ticket until its owner-at-failure refund is credited.
     */
    enum RaffleState {
        Uninitialized,
        AwaitingPrize,
        Active,
        DrawRequested,
        Resolved,
        Cancelled,
        Refunding
    }

    /// @notice Terminal economic outcome, including distinct oracle-liveness failures.
    enum RaffleOutcome {
        None,
        NftAwarded,
        CashFallback,
        NoSales,
        CancelledBeforeSale,
        DrawNotRequested,
        DrawTimedOut
    }

    /**
     * @notice Complete one-time configuration written to fresh EIP-1167 clone storage.
     * @param factory Canonical factory whose implementation getter must reference this implementation.
     * @param sponsor Prize depositor and successful sponsor-cash recipient.
     * @param sponsorPrizeRecoveryRecipient Fixed sponsor-side prize recovery destination.
     * @param protocolTreasury Treasury captured at creation.
     * @param quoteToken Factory-allowlisted exact-transfer ERC-20.
     * @param entropy Pyth Entropy v2 deployment.
     * @param prizeToken Standards-compliant ERC-721 prize contract.
     * @param prizeTokenId Escrowed prize token ID.
     * @param raffleId Canonical factory identifier.
     * @param ticketPrice Raw quote-token units per ticket.
     * @param minimumTickets Successful-draw NFT-award threshold.
     * @param startTime Inclusive ticket-sale start.
     * @param endTime Exclusive ticket-sale end.
     * @param callbackGasLimit Gas limit supplied to Entropy v2.
     * @param name ERC-721 ticket collection name.
     * @param symbol ERC-721 ticket collection symbol.
     * @param metadataURI Raffle and souvenir-ticket metadata URI.
     */
    struct InitializeParams {
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
        string name;
        string symbol;
        string metadataURI;
    }

    /// @notice Raised when initialization is not authenticated to this implementation's canonical factory.
    error OnlyFactory();
    /// @notice Raised when a required address or destination is zero.
    error ZeroAddress();
    /// @notice Raised when a lifecycle action requires another exact state.
    error InvalidState(RaffleState expected, RaffleState actual);
    /// @notice Raised when the factory-operated safe deposit differs from the initialized prize expectation.
    error UnexpectedPrize(address token, uint256 tokenId, address from, address operator);
    /// @notice Raised when a purchase precedes the inclusive start timestamp.
    error SaleNotStarted(uint256 startTime, uint256 currentTime);
    /// @notice Raised when a purchase occurs at or after the exclusive end timestamp.
    error SaleEnded(uint256 endTime, uint256 currentTime);
    /// @notice Raised when a ticket recipient is zero.
    error InvalidRecipient();
    /// @notice Raised when a purchase or refund batch is empty or exceeds its explicit bound.
    error InvalidQuantity(uint256 quantity, uint256 maximum);
    /// @notice Raised when purchase multiplication would overflow.
    error GrossAmountOverflow();
    /// @notice Raised when an incoming quote-token transfer does not credit the exact advertised amount.
    error UnsupportedQuoteToken(uint256 expectedAmount, uint256 receivedAmount);
    /// @notice Raised when an outgoing quote transfer does not debit and credit the exact liability amount.
    error UnsupportedQuoteTokenTransfer(uint256 expectedAmount, uint256 debitedAmount, uint256 creditedAmount);
    /// @notice Raised when a quote claim attempts to pay the raffle itself.
    error InvalidQuoteDestination(address destination);
    /// @notice Raised when cancellation is attempted by an account other than the sponsor.
    error OnlySponsor();
    /// @notice Raised when sponsor cancellation is attempted after any sale.
    error TicketsAlreadySold(uint256 totalTickets);
    /// @notice Raised when an end-dependent action is attempted before sale end.
    error RaffleNotEnded(uint256 endTime, uint256 currentTime);
    /// @notice Raised when the no-sales path is attempted after any sale.
    error TicketsWereSold(uint256 totalTickets);
    /// @notice Raised when a draw or failed-draw action requires at least one ticket.
    error NoTicketsSold();
    /// @notice Raised when a draw request is attempted at or after the request-grace deadline.
    error DrawRequestWindowExpired(uint256 deadline, uint256 currentTime);
    /// @notice Raised when failure is attempted before the never-requested draw grace deadline.
    error DrawRequestGraceActive(uint256 deadline, uint256 currentTime);
    /// @notice Raised when callback-timeout failure is attempted before the exact timeout boundary.
    error CallbackStillPending(uint256 deadline, uint256 currentTime);
    /// @notice Raised when less than the current Entropy fee is supplied.
    error InsufficientEntropyFee(uint256 requiredFee, uint256 suppliedValue);
    /// @notice Raised when a ticket ID is outside the sold sequential range.
    error InvalidRefundTicket(uint256 ticketId);
    /// @notice Raised when a ticket refund has already been credited.
    error TicketRefundAlreadyCredited(uint256 ticketId);
    /// @notice Raised when an account has no quote-token claim.
    error NoQuoteClaim(address account);
    /// @notice Raised when an account has no native-currency refund.
    error NoNativeClaim(address account);
    /// @notice Raised when a caller is not the current snapshotted prize claimant.
    error NotPrizeClaimant(address caller, address claimant);
    /// @notice Raised when the single configured prize already left escrow.
    error PrizeAlreadyClaimed();
    /// @notice Raised when no terminal branch has assigned a prize claimant.
    error NoPrizeClaimant();
    /// @notice Raised when a native-currency pull payment fails.
    error NativeTransferFailed(address to, uint256 amount);
    /// @notice Raised when ticket ownership transfer is frozen while winner resolution is pending.
    error TicketTransfersFrozen();
    /// @notice Raised when an uncredited refundable ticket attempts to move from its frozen owner.
    error RefundTicketFrozen(uint256 ticketId);

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

    /// @notice Emitted when the sponsor cancels before the first sale.
    event RaffleCancelled(address indexed sponsor, address indexed prizeClaimant);

    /// @notice Emitted when anyone closes an ended raffle with zero sales.
    event NoSalesClosed(address indexed caller, address indexed prizeClaimant);

    /// @notice Emitted when the one accepted Entropy v2 request creates a bounded callback window.
    event DrawRequested(
        uint64 indexed sequenceNumber,
        address indexed requester,
        uint256 fee,
        uint256 excessCredited,
        uint256 drawRequestedAt,
        uint256 callbackDeadline
    );

    /// @notice Emitted when a wrong-sequence, in-flight, stale, or duplicate callback is ignored without reverting.
    event EntropyCallbackIgnored(
        uint64 indexed receivedSequence, uint64 indexed expectedSequence, RaffleState currentState
    );

    /// @notice Emitted when verified randomness resolves the winner and all aggregate quote liabilities.
    event RaffleResolved(
        uint64 indexed sequenceNumber,
        uint256 indexed winningTicketId,
        address indexed winner,
        RaffleOutcome outcome,
        address prizeClaimant,
        uint256 protocolFee,
        uint256 winnerCashAmount,
        uint256 sponsorCashAmount
    );

    /// @notice Emitted when an oracle-liveness deadline converts the entire gross pot into refunds.
    event DrawFailureFinalized(
        RaffleOutcome indexed outcome,
        address indexed finalizer,
        address indexed prizeClaimant,
        uint256 grossRefundLiability
    );

    /// @notice Emitted when one ticket's refund is irreversibly credited to its frozen owner.
    event TicketRefundCredited(
        uint256 indexed ticketId, address indexed owner, uint256 amount, uint256 remainingRefundLiability
    );

    /// @notice Emitted after an exact outgoing quote-token claim succeeds.
    event QuoteClaimed(address indexed account, address indexed to, uint256 amount);

    /// @notice Emitted after the configured prize leaves escrow exactly once.
    event PrizeClaimed(address indexed claimant, address indexed to, address indexed prizeToken, uint256 prizeTokenId);

    /// @notice Emitted after an excess Entropy payment is pulled.
    event NativeClaimed(address indexed account, address indexed to, uint256 amount);

    /// @notice Initializes fresh clone storage exactly once through the canonical factory.
    function initialize(InitializeParams calldata params) external;

    /// @notice Purchases and safely mints a bounded quantity of sequential tickets.
    function buyTickets(address recipient, uint256 quantity)
        external
        returns (uint256 firstTicketId, uint256 lastTicketId);

    /// @notice Lets the sponsor cancel only while no ticket has ever been sold.
    function cancelBeforeSales() external;

    /// @notice Lets anyone close an ended raffle with zero sold tickets.
    function closeNoSales() external;

    /// @notice Returns the current Entropy v2 fee for the configured callback gas limit.
    function getEntropyFee() external view returns (uint256 fee);

    /// @notice Submits the only draw request before the fixed request-grace deadline.
    function requestDraw() external payable returns (uint64 sequenceNumber);

    /// @notice Converts a sold raffle with no accepted request by its deadline into refunds.
    function finalizeUnrequestedDraw() external;

    /// @notice Converts an unfulfilled accepted request at or after its timeout into refunds.
    function finalizeTimedOutDraw() external;

    /// @notice Credits bounded ticket refunds to the owners frozen by the failed-draw transition.
    function creditTicketRefunds(uint256[] calldata ticketIds) external;

    /// @notice Pays the caller's quote claim to a chosen destination after exact-transfer verification.
    function claimQuote(address to) external returns (uint256 amount);

    /// @notice Pays another account's quote claim only to that same account.
    function claimQuoteFor(address account) external returns (uint256 amount);

    /// @notice Lets the current claimant transfer the prize to a chosen safe destination.
    function claimPrize(address to) external;

    /// @notice Lets anyone send the prize only to the fixed current claimant.
    function claimPrizeFor() external;

    /// @notice Pays the caller's native refund to a chosen destination.
    function claimNative(address payable to) external returns (uint256 amount);

    /// @notice Returns whether sold tickets meet the NFT-award threshold.
    function isThresholdMet() external view returns (bool thresholdMet);

    /// @notice Returns whether ticket sales are currently accepted.
    function isOpen() external view returns (bool open);

    /// @notice Returns whether the sole draw request is currently available.
    function canRequestDraw() external view returns (bool available);

    /// @notice Returns whether the no-request failure path is currently executable.
    function canFinalizeUnrequestedDraw() external view returns (bool available);

    /// @notice Returns whether the callback-timeout failure path is currently executable.
    function canFinalizeTimedOutDraw() external view returns (bool available);

    /// @notice Returns `endTime + DRAW_REQUEST_GRACE_PERIOD`.
    function requestGraceDeadline() external view returns (uint256 deadline);

    /// @notice Returns the callback deadline, or zero before a request is accepted.
    function callbackDeadline() external view returns (uint256 deadline);

    /// @notice Returns whether a sold ticket's failed-draw refund was credited.
    function isTicketRefundCredited(uint256 ticketId) external view returns (bool credited);

    /// @notice Returns all accounted quote liabilities held by the raffle.
    function accountedQuoteBalance() external view returns (uint256 amount);

    /// @notice Returns all outstanding native refund liabilities.
    function accountedNativeBalance() external view returns (uint256 amount);

    /// @notice Returns direct quote-token donations above accounted liabilities.
    function unaccountedQuoteSurplus() external view returns (uint256 amount);

    /// @notice Returns forced native currency above outstanding native liabilities.
    function unaccountedNativeSurplus() external view returns (uint256 amount);

    /// @notice Returns whether the current quote balance covers all accounted liabilities.
    function isQuoteSolvent() external view returns (bool solvent);

    /// @notice Returns an account's current ticket share using 1e18 fixed-point precision.
    function oddsFor(address account) external view returns (uint256 odds);

    /// @notice Canonical factory that atomically initialized this clone.
    function factory() external view returns (address);
    /// @notice Prize depositor and successful sponsor-cash recipient.
    function sponsor() external view returns (address);
    /// @notice Fixed sponsor-side prize recovery recipient.
    function sponsorPrizeRecoveryRecipient() external view returns (address);
    /// @notice Treasury captured at creation.
    function protocolTreasury() external view returns (address);
    /// @notice Exact-transfer ERC-20 used for all quote accounting.
    function quoteToken() external view returns (IERC20);
    /// @notice Pyth Entropy v2 deployment used for the sole draw request.
    function entropy() external view returns (IEntropyV2);
    /// @notice Configured ERC-721 prize contract.
    function prizeToken() external view returns (IERC721);
    /// @notice Configured ERC-721 prize token ID.
    function prizeTokenId() external view returns (uint256);
    /// @notice Canonical factory raffle identifier.
    function raffleId() external view returns (uint256);
    /// @notice Raw quote-token units per ticket.
    function ticketPrice() external view returns (uint256);
    /// @notice Ticket threshold for the successful NFT-award outcome.
    function minimumTickets() external view returns (uint256);
    /// @notice Inclusive sale start timestamp.
    function startTime() external view returns (uint256);
    /// @notice Exclusive sale end timestamp.
    function endTime() external view returns (uint256);
    /// @notice Total sequential tickets ever sold.
    function totalTickets() external view returns (uint256);
    /// @notice Historical gross quote-token sales.
    function grossSales() external view returns (uint256);
    /// @notice Gross pot not yet assigned to normal claims or refund liability.
    function unsettledPot() external view returns (uint256);
    /// @notice Failed-draw liability not yet credited ticket by ticket.
    function uncreditedRefundLiability() external view returns (uint256);
    /// @notice Aggregate outstanding quote-token pull claims.
    function totalClaimableQuote() external view returns (uint256);
    /// @notice Aggregate outstanding native-currency pull claims.
    function totalClaimableNative() external view returns (uint256);
    /// @notice Accepted Entropy request sequence, or zero before acceptance.
    function entropySequenceNumber() external view returns (uint64);
    /// @notice Timestamp at which the sole Entropy request returned successfully.
    function drawRequestedAt() external view returns (uint256);
    /// @notice Winning ticket fixed by verified randomness, or zero otherwise.
    function winningTicketId() external view returns (uint256);
    /// @notice Winning owner snapshotted by verified randomness, or zero otherwise.
    function winner() external view returns (address);
    /// @notice Current account authorized to choose the prize destination.
    function prizeClaimant() external view returns (address);
    /// @notice Current monotonic lifecycle state.
    function state() external view returns (RaffleState);
    /// @notice Terminal economic outcome, or `None` before terminal transition.
    function outcome() external view returns (RaffleOutcome);
    /// @notice Returns one account's outstanding quote claim.
    function claimableQuote(address account) external view returns (uint256);
    /// @notice Returns one account's outstanding native claim.
    function claimableNative(address account) external view returns (uint256);
    /// @notice Returns whether the configured prize already left escrow.
    function prizeClaimed() external view returns (bool);
    /// @notice Returns the callback gas limit captured at initialization.
    function callbackGasLimit() external view returns (uint32);
    /// @notice Returns the constrained raffle and souvenir-ticket metadata URI.
    function raffleMetadataURI() external view returns (string memory);
}
