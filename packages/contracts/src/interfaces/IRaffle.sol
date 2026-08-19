// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { IChainlinkVRFV2PlusWrapper } from "./IChainlinkVRFV2PlusWrapper.sol";

/**
 * @title raffle.fun Raffle Interface
 * @author Heesho
 * @notice Defines one autonomous NFT raffle using fixed-price USDC entries and one transferable ERC-721 ticket per
 *         purchase.
 * @dev Ticket IDs are sequential. Each ticket stores one inclusive uint128 entry range and remains a bearer claim
 *      until it is atomically burned for settlement or refund. Supported quote tokens are exact-transfer, non-rebasing
 *      six-decimal ERC-20s. Supported prizes are honest, standards-compliant ERC-721s.
 * @custom:version 1.0.0
 */
interface IRaffle {
    /// @notice The single authoritative lifecycle and economic result.
    enum Status {
        AwaitingPrize,
        Active,
        Drawing,
        NftWon,
        CashWon,
        Refunding
    }

    /**
     * @notice Complete clone-specific configuration supplied once by the canonical factory.
     * @param sponsor Prize depositor and empty-raffle cancellation authority.
     * @param sponsorRecipient Immutable recipient of all sponsor quote proceeds and returned prizes.
     * @param protocolTreasury Treasury captured by this immutable factory.
     * @param prizeToken Standards-compliant ERC-721 prize contract.
     * @param prizeTokenId Escrowed prize token ID.
     * @param raffleId Canonical factory identifier.
     * @param reserveEntries Entry threshold selecting the NFT rather than cash outcome.
     * @param endTime Exclusive sale end; the sale begins when the prize is deposited during creation.
     */
    struct RaffleInitParams {
        address sponsor;
        address sponsorRecipient;
        address protocolTreasury;
        address prizeToken;
        uint256 prizeTokenId;
        uint256 raffleId;
        uint128 reserveEntries;
        uint64 endTime;
    }

    error OnlyFactory();
    error AlreadyInitialized();
    error ZeroAddress();
    error InvalidStatus(Status actual);
    error UnexpectedPrize(address token, uint256 tokenId, address from, address operator);
    error SaleEnded(uint256 endTime, uint256 currentTime);
    error InvalidRecipient();
    error ZeroEntryCount();
    error TotalEntriesOverflow(uint128 totalEntries, uint128 requestedEntries);
    error InvalidTicketBatchSize(uint256 quantity, uint256 maximum);
    error UnsupportedQuoteToken(uint256 expectedAmount, uint256 receivedAmount);
    error UnsupportedQuoteTokenTransfer(uint256 expectedAmount, uint256 debitedAmount, uint256 creditedAmount);
    error InvalidQuoteDestination(address destination);
    error OnlySponsor(address caller, address sponsor);
    error RaffleNotEnded(uint256 endTime, uint256 currentTime);
    error DrawRequestWindowExpired(uint256 deadline, uint256 currentTime);
    error NoEntriesSold();
    error RefundsNotAvailable(uint256 deadline, uint256 currentTime);
    error InsufficientVrfFee(uint256 requiredFee, uint256 suppliedValue);
    error NativeRefundFailed(address recipient, uint256 amount);
    error OnlyVRFWrapperCanFulfill(address have, address want);
    error NoWinnerProceeds();
    error NoSponsorProceeds();
    error NoProtocolFees();
    error UnsafeProtocolDestination(address destination);
    error NotTicketOwner(uint256 ticketId, address caller, address owner);
    error TicketDoesNotContainWinningEntry(uint256 ticketId, uint128 winningEntry);
    error SponsorPrizeUnavailable(Status status);
    error WinnerPrizeUnavailable(Status status);
    error PrizeAlreadyClaimed();
    error PrizeDeliveryVerificationFailed(address recipient);

    event PrizeDeposited(address indexed prizeToken, uint256 indexed prizeTokenId, address indexed sponsor);

    event TicketPurchased(
        address indexed buyer,
        address indexed recipient,
        uint256 indexed ticketId,
        uint128 firstEntry,
        uint128 lastEntry,
        uint128 entryCount,
        uint256 grossAmount
    );

    event DrawRequested(
        uint256 indexed requestId,
        address indexed requester,
        uint256 fee,
        uint256 excessReturned,
        uint256 drawRequestedAt,
        uint256 callbackDeadline
    );

    event VrfCallbackIgnored(uint256 indexed receivedRequestId, uint256 indexed expectedRequestId, Status status);

    event RaffleResolved(uint256 indexed requestId, uint128 indexed winningEntry, Status indexed result);

    event RefundsEnabled(address indexed finalizer, uint256 remainingRefundLiability);

    event WinningTicketSettled(
        uint256 indexed ticketId,
        address indexed winner,
        Status indexed result,
        uint256 cashAmount,
        uint256 protocolFee,
        uint256 sponsorAmount
    );

    event TicketsRefunded(
        address indexed owner,
        uint256 ticketQuantity,
        uint256 entryQuantity,
        uint256 amount,
        uint256 remainingRefundLiability
    );

    event SponsorProceedsReleased(address indexed caller, address indexed recipient, uint256 amount);
    event ProtocolFeesReleased(address indexed caller, address indexed treasury, uint256 amount);
    event WinnerProceedsReleased(address indexed caller, address indexed recipient, uint256 amount);

    event WinnerPrizeReleased(
        address indexed caller, address indexed recipient, address indexed prizeToken, uint256 prizeTokenId
    );

    event SponsorPrizeReleased(
        address indexed caller, address indexed recipient, address indexed prizeToken, uint256 prizeTokenId
    );

    function initialize(RaffleInitParams calldata params) external;

    /// @notice Buys any positive number of entries and mints one sequential ticket containing their inclusive range.
    function buyEntries(address recipient, uint128 entryCount) external returns (uint256 ticketId);

    function getVrfRequestPrice() external view returns (uint256 fee);
    function estimateVrfRequestPrice(uint256 requestGasPriceWei) external view returns (uint256 fee);
    function requestDraw() external payable returns (uint256 requestId);
    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external;

    /**
     * @notice Enables full refunds after either the sold-raffle draw-request deadline or an accepted request's callback
     *         deadline. Also closes an empty raffle immediately for the sponsor and after sale end for anyone.
     */
    function enableRefunds() external;

    /**
     * @notice Settles with the ticket containing the winning entry. Anyone may execute; the current bearer is
     *         snapshotted as the fixed winner recipient, the ticket is burned, and all quote liabilities are credited
     *         without making an external asset transfer.
     */
    function settleWinningTicket(uint256 ticketId) external returns (uint256 cashAmount);

    function refundTickets(uint256[] calldata ticketIds) external returns (uint256 amount);
    function releaseWinnerProceeds() external returns (uint256 amount);
    function releaseWinnerPrize() external;
    function releaseSponsorProceeds() external returns (uint256 amount);
    function releaseProtocolFees() external returns (uint256 amount);
    function releaseSponsorPrize() external;

    function ticketRange(uint256 ticketId) external view returns (uint128 firstEntry, uint128 lastEntry);
    function drawRequestDeadline() external view returns (uint256 deadline);
    function callbackDeadline() external view returns (uint256 deadline);
    function accountedQuoteBalance() external view returns (uint256 amount);

    function ENTRY_PRICE() external view returns (uint256 price);
    function callbackGasLimit() external view returns (uint32 gasLimit);
    function requestConfirmations() external view returns (uint16 confirmations);
    function factory() external view returns (address);
    function sponsor() external view returns (address);
    function sponsorRecipient() external view returns (address);
    function protocolTreasury() external view returns (address);
    function quoteToken() external view returns (IERC20);
    function vrfWrapper() external view returns (IChainlinkVRFV2PlusWrapper);
    function prizeToken() external view returns (IERC721);
    function prizeTokenId() external view returns (uint256);
    function raffleId() external view returns (uint256);
    function reserveEntries() external view returns (uint128);
    function endTime() external view returns (uint64);
    function totalEntries() external view returns (uint128);
    function ticketCount() external view returns (uint128);
    /// @notice Returns `totalEntries * ENTRY_PRICE`; no redundant gross-sales value is stored.
    function grossSales() external view returns (uint256);
    function unsettledPot() external view returns (uint256);
    function remainingRefundLiability() external view returns (uint256);
    function winnerRecipient() external view returns (address);
    function winnerProceeds() external view returns (uint256);
    function sponsorProceeds() external view returns (uint256);
    function protocolFees() external view returns (uint256);
    function vrfRequestId() external view returns (uint256);
    function drawRequestedAt() external view returns (uint64);
    function resolvedAt() external view returns (uint64);
    function winningEntry() external view returns (uint128);
    function winningTicketId() external view returns (uint256);
    function status() external view returns (Status);
    function prizeClaimed() external view returns (bool);
    function initialized() external view returns (bool);
}
