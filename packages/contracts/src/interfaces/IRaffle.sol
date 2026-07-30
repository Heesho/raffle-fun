// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IEntropyV2 } from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";

/// @title IRaffle
/// @notice Stable external surface for one immutable raffle clone and its ticket ERC721.
interface IRaffle {
    /// @notice Lifecycle state; transitions are monotonic except that cancellation has its own terminal state.
    enum RaffleState {
        Uninitialized,
        AwaitingPrize,
        Active,
        DrawRequested,
        Resolved,
        Cancelled
    }

    /// @notice Terminal economic branch selected by cancellation, no sales, or verified randomness.
    enum RaffleOutcome {
        None,
        NftAwarded,
        CashFallback,
        NoSales,
        CancelledBeforeSale
    }

    /// @notice Complete one-time clone configuration supplied by the factory.
    /// @param factory Canonical factory registry.
    /// @param sponsor Prize depositor and sponsor payout recipient.
    /// @param protocolTreasury Treasury captured when the raffle is created.
    /// @param quoteToken ERC20 used for ticket payments and payouts.
    /// @param entropy Pyth Entropy v2 contract.
    /// @param prizeToken ERC721 prize contract.
    /// @param prizeTokenId Escrowed prize token ID.
    /// @param raffleId Factory identifier.
    /// @param ticketPrice Gross quote-token amount per ticket.
    /// @param minimumTickets NFT outcome threshold.
    /// @param startTime Inclusive sales start timestamp.
    /// @param endTime Exclusive sales end timestamp.
    /// @param callbackGasLimit Gas limit requested for the Entropy callback.
    /// @param name ERC721 ticket collection name.
    /// @param symbol ERC721 ticket collection symbol.
    /// @param metadataURI Raffle and ticket metadata URI.
    struct InitializeParams {
        address factory;
        address sponsor;
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

    /// @notice Raised when clone initialization is not performed by the configured factory.
    error OnlyFactory();
    /// @notice Raised when a required destination or recipient is zero.
    error ZeroAddress();
    /// @notice Raised when an operation requires a different lifecycle state.
    error InvalidState(RaffleState expected, RaffleState actual);
    /// @notice Raised when a prize transfer does not exactly match the initialized escrow expectation.
    error UnexpectedPrize(address token, uint256 tokenId, address from, address operator);
    /// @notice Raised when tickets are purchased before the inclusive start timestamp.
    error SaleNotStarted(uint256 startTime, uint256 currentTime);
    /// @notice Raised when tickets are purchased at or after the exclusive end timestamp.
    error SaleEnded(uint256 endTime, uint256 currentTime);
    /// @notice Raised when a purchase recipient is zero.
    error InvalidRecipient();
    /// @notice Raised when purchase quantity is outside the documented bounded range.
    error InvalidQuantity(uint256 quantity, uint256 maximum);
    /// @notice Raised when multiplication would overflow the accepted ERC20 amount range.
    error GrossAmountOverflow();
    /// @notice Raised when a quote token does not deliver the exact requested transfer amount.
    error UnsupportedQuoteToken(uint256 expectedAmount, uint256 receivedAmount);
    /// @notice Raised when cancellation is attempted by an account other than the sponsor.
    error OnlySponsor();
    /// @notice Raised when sponsor cancellation is attempted after any ticket was sold.
    error TicketsAlreadySold(uint256 totalTickets);
    /// @notice Raised when a post-sale action is attempted before the raffle end timestamp.
    error RaffleNotEnded(uint256 endTime, uint256 currentTime);
    /// @notice Raised when the no-sales path is used after tickets were sold.
    error TicketsWereSold(uint256 totalTickets);
    /// @notice Raised when a draw is requested for a raffle with no ticket holders.
    error NoTicketsSold();
    /// @notice Raised when less than the current Entropy fee is supplied.
    error InsufficientEntropyFee(uint256 requiredFee, uint256 suppliedValue);
    /// @notice Raised when an account has no quote-token amount to claim.
    error NoQuoteClaim(address account);
    /// @notice Raised when an account has no native-currency refund to claim.
    error NoNativeClaim(address account);
    /// @notice Raised when an account other than the snapshotted prize claimant attempts a prize claim.
    error NotPrizeClaimant(address caller, address claimant);
    /// @notice Raised when the single prize has already left escrow.
    error PrizeAlreadyClaimed();
    /// @notice Raised when a native-currency pull payment cannot be delivered.
    error NativeTransferFailed(address to, uint256 amount);

    /// @notice Emitted after the exact expected prize enters clone escrow.
    /// @param prizeToken Escrowed ERC721 contract.
    /// @param prizeTokenId Escrowed token ID.
    /// @param sponsor Prize depositor.
    event PrizeDeposited(address indexed prizeToken, uint256 indexed prizeTokenId, address indexed sponsor);

    /// @notice Emitted once per bounded multi-ticket purchase.
    /// @param buyer Account paying the quote token.
    /// @param recipient Account receiving ticket NFTs.
    /// @param quantity Number of sequential tickets minted.
    /// @param firstTicketId First minted ticket ID.
    /// @param lastTicketId Last minted ticket ID.
    /// @param grossAmount Advertised total paid by the buyer.
    event TicketsPurchased(
        address indexed buyer,
        address indexed recipient,
        uint256 quantity,
        uint256 firstTicketId,
        uint256 lastTicketId,
        uint256 grossAmount
    );

    /// @notice Emitted when the sponsor terminally cancels before any ticket sale.
    /// @param sponsor Prize claimant.
    event RaffleCancelled(address indexed sponsor);

    /// @notice Emitted when anyone terminally closes an ended raffle with no sales.
    /// @param sponsor Prize claimant.
    event NoSalesClosed(address indexed sponsor);

    /// @notice Emitted when the sole Entropy request is accepted.
    /// @param sequenceNumber Entropy request identifier.
    /// @param requester Account funding the request.
    /// @param fee Paid Entropy fee.
    /// @param excessCredited Pull-based native refund credited to the requester.
    event DrawRequested(uint64 indexed sequenceNumber, address indexed requester, uint256 fee, uint256 excessCredited);

    /// @notice Emitted when a stale, duplicate, or unexpected callback is safely ignored.
    /// @param receivedSequence Callback sequence received.
    /// @param expectedSequence Stored request sequence.
    /// @param currentState Lifecycle state at callback time.
    event EntropyCallbackIgnored(
        uint64 indexed receivedSequence, uint64 indexed expectedSequence, RaffleState currentState
    );

    /// @notice Emitted after verified randomness fixes the winner and all pull-payment allocations.
    /// @param sequenceNumber Entropy request identifier.
    /// @param winningTicketId Winning ticket in the inclusive range from one through total tickets.
    /// @param winner Owner snapshotted during the callback.
    /// @param outcome Selected economic branch.
    /// @param prizeClaimant Account authorized to claim the prize.
    /// @param protocolFee Aggregate protocol fee allocated from gross sales.
    /// @param winnerCashAmount Cash-fallback amount allocated to the winner.
    /// @param sponsorCashAmount Amount allocated to the sponsor.
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

    /// @notice Emitted after a quote-token claim is paid.
    /// @param account Account whose accrual was consumed.
    /// @param to Payment destination.
    /// @param amount Quote-token amount paid.
    event QuoteClaimed(address indexed account, address indexed to, uint256 amount);

    /// @notice Emitted after the single escrowed prize leaves the raffle.
    /// @param claimant Authorized claimant.
    /// @param to NFT destination.
    /// @param prizeToken Prize contract.
    /// @param prizeTokenId Prize token ID.
    event PrizeClaimed(address indexed claimant, address indexed to, address indexed prizeToken, uint256 prizeTokenId);

    /// @notice Emitted after an excess Entropy payment refund is pulled.
    /// @param account Account whose accrual was consumed.
    /// @param to Native-currency destination.
    /// @param amount Native amount paid.
    event NativeClaimed(address indexed account, address indexed to, uint256 amount);

    /// @notice Initializes a fresh clone exactly once.
    /// @param params Complete immutable-by-convention raffle configuration.
    function initialize(InitializeParams calldata params) external;

    /// @notice Purchases sequential ticket NFTs using the gross advertised price.
    /// @param recipient Ticket recipient, which may differ from the buyer.
    /// @param quantity Bounded ticket quantity.
    /// @return firstTicketId First newly minted ticket.
    /// @return lastTicketId Last newly minted ticket.
    function buyTickets(address recipient, uint256 quantity)
        external
        returns (uint256 firstTicketId, uint256 lastTicketId);

    /// @notice Allows the sponsor to cancel only before the first ticket sale.
    function cancelBeforeSales() external;

    /// @notice Closes an ended zero-ticket raffle without requesting randomness.
    function closeNoSales() external;

    /// @notice Returns the current Pyth Entropy v2 fee for this raffle's callback gas limit.
    /// @return fee Current native-currency fee.
    function getEntropyFee() external view returns (uint256 fee);

    /// @notice Makes the raffle's only randomness request and credits any overpayment for pull refund.
    /// @return sequenceNumber Assigned Pyth Entropy v2 request identifier.
    function requestDraw() external payable returns (uint64 sequenceNumber);

    /// @notice Pays the caller's quote-token accrual to a chosen nonzero destination.
    /// @param to Payment destination.
    /// @return amount Amount paid.
    function claimQuote(address to) external returns (uint256 amount);

    /// @notice Pays another account's quote accrual only to that same account.
    /// @param account Accrued account and fixed destination.
    /// @return amount Amount paid.
    function claimQuoteFor(address account) external returns (uint256 amount);

    /// @notice Transfers the escrowed prize to a destination selected by the snapshotted claimant.
    /// @param to NFT destination.
    function claimPrize(address to) external;

    /// @notice Pays the caller's excess Entropy funding to a chosen destination.
    /// @param to Native-currency destination.
    /// @return amount Amount paid.
    function claimNative(address payable to) external returns (uint256 amount);

    /// @notice Returns whether sold tickets meet the NFT-outcome threshold.
    /// @return thresholdMet True when total tickets are at least the configured minimum.
    function isThresholdMet() external view returns (bool thresholdMet);

    /// @notice Returns whether ticket sales are currently accepted.
    /// @return open True only during the active inclusive-start/exclusive-end window.
    function isOpen() external view returns (bool open);

    /// @notice Returns whether the sole draw request can currently be submitted.
    /// @return available True only after close with at least one ticket and no earlier transition.
    function canRequestDraw() external view returns (bool available);

    /// @notice Returns quote-token liabilities still held by the raffle.
    /// @return amount Unsettled gross pot plus all quote claims.
    function accountedQuoteBalance() external view returns (uint256 amount);

    /// @notice Returns direct quote-token donations above all accounted liabilities.
    /// @return amount Unaccounted surplus that no protocol administrator can seize.
    function unaccountedQuoteSurplus() external view returns (uint256 amount);

    /// @notice Returns an account's current ticket share in 1e18 fixed-point precision.
    /// @param account Ticket holder.
    /// @return odds Current owned-ticket share, or zero before any sale.
    function oddsFor(address account) external view returns (uint256 odds);

    /// @notice Canonical factory that initialized this clone.
    function factory() external view returns (address);
    /// @notice Prize sponsor and sponsor payout account.
    function sponsor() external view returns (address);
    /// @notice Treasury captured at creation for this clone's protocol fees.
    function protocolTreasury() external view returns (address);
    /// @notice Quote token used by this clone.
    function quoteToken() external view returns (IERC20);
    /// @notice Pyth Entropy v2 contract used by this clone.
    function entropy() external view returns (IEntropyV2);
    /// @notice Escrowed prize contract.
    function prizeToken() external view returns (IERC721);
    /// @notice Escrowed prize token ID.
    function prizeTokenId() external view returns (uint256);
    /// @notice Factory identifier.
    function raffleId() external view returns (uint256);
    /// @notice Gross quote-token price per ticket.
    function ticketPrice() external view returns (uint256);
    /// @notice Ticket threshold for the NFT-awarded outcome.
    function minimumTickets() external view returns (uint256);
    /// @notice Inclusive sales start timestamp.
    function startTime() external view returns (uint256);
    /// @notice Exclusive sales end timestamp.
    function endTime() external view returns (uint256);
    /// @notice Total sequential ticket NFTs sold.
    function totalTickets() external view returns (uint256);
    /// @notice Historical gross quote-token sales.
    function grossSales() external view returns (uint256);
    /// @notice Aggregate gross quote-token amount awaiting resolution.
    function unsettledPot() external view returns (uint256);
    /// @notice Aggregate outstanding quote-token claims.
    function totalClaimableQuote() external view returns (uint256);
    /// @notice Accepted Entropy sequence number.
    function entropySequenceNumber() external view returns (uint64);
    /// @notice Winning ticket ID fixed at resolution.
    function winningTicketId() external view returns (uint256);
    /// @notice Winning ticket owner snapshotted at resolution.
    function winner() external view returns (address);
    /// @notice Account authorized to pull the prize.
    function prizeClaimant() external view returns (address);
    /// @notice Current raffle lifecycle state.
    function state() external view returns (RaffleState);
    /// @notice Terminal economic outcome, or none before a terminal transition.
    function outcome() external view returns (RaffleOutcome);
    /// @notice Returns an account's outstanding quote-token claim.
    function claimableQuote(address account) external view returns (uint256);
    /// @notice Returns an account's outstanding native-currency refund.
    function claimableNative(address account) external view returns (uint256);
    /// @notice Returns whether the prize has already left escrow.
    function prizeClaimed() external view returns (bool);
    /// @notice Returns the configured callback gas limit.
    function callbackGasLimit() external view returns (uint32);
    /// @notice Returns the constrained metadata URI.
    function raffleMetadataURI() external view returns (string memory);
}
