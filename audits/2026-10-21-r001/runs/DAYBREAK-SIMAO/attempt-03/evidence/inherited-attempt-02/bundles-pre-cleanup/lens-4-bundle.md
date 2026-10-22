### target/packages/contracts/src/Raffle.sol
\`\`\`solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { VRFV2PlusWrapperConsumerBase } from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import { IVRFV2PlusWrapper } from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";
import { VRFV2PlusClient } from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IRaffle } from "./interfaces/IRaffle.sol";
import { IRaffleFactory } from "./interfaces/IRaffleFactory.sol";
import { RaffleConstants } from "./libraries/RaffleConstants.sol";

/// @title raffle.fun Raffle Escrow and Entry Ticket
/// @author heesho
/// @notice Escrows one NFT and sells fixed-price USDC entries through one transferable ERC-721 ticket per purchase.
/// @dev Ticket IDs are sequential and map to one inclusive `[firstEntry,lastEntry]` uint128 range. Purchases, Chainlink
///      callbacks, and winner proofs are O(1) in entry count. Tickets remain transferable bearer claims until their
///      owners burn them for redemption or refund. Each raffle is a fixed, non-upgradeable ERC-1167 clone with no
///      administrator or rescue path. Permissionless settlement only allocates liabilities; the winning-ticket owner
///      atomically burns the ticket while receiving the NFT or cash prize.
/// @custom:version 1.0.0
contract Raffle is IRaffle, ERC721, ReentrancyGuard, IERC721Receiver, VRFV2PlusWrapperConsumerBase {
    using SafeERC20 for IERC20;

    // Types

    /// @notice Inclusive global entry-number range represented by one sequential ERC-721 ticket.
    /// @param firstEntry First represented one-based global entry.
    /// @param lastEntry Last represented one-based global entry.
    struct TicketRange {
        uint128 firstEntry;
        uint128 lastEntry;
    }

    // Constants

    /// @inheritdoc IRaffle
    uint256 public constant override ENTRY_PRICE = RaffleConstants.ENTRY_PRICE;

    /// @inheritdoc IRaffle
    uint32 public constant override callbackGasLimit = RaffleConstants.VRF_CALLBACK_GAS_LIMIT;

    /// @inheritdoc IRaffle
    uint16 public constant override requestConfirmations = RaffleConstants.VRF_REQUEST_CONFIRMATIONS;

    // Immutables and state

    /// @inheritdoc IRaffle
    address public immutable override factory;

    /// @inheritdoc IRaffle
    IERC20 public immutable override quoteToken;

    /// @inheritdoc IRaffle
    address public override sponsor;

    /// @inheritdoc IRaffle
    address public override sponsorRecipient;

    /// @inheritdoc IRaffle
    address public override protocolTreasury;

    /// @inheritdoc IRaffle
    IERC721 public override prizeToken;

    /// @inheritdoc IRaffle
    uint256 public override prizeTokenId;

    /// @inheritdoc IRaffle
    uint256 public override raffleId;

    /// @inheritdoc IRaffle
    uint128 public override reserveEntries;

    /// @inheritdoc IRaffle
    uint64 public override endTime;

    /// @inheritdoc IRaffle
    uint128 public override totalEntries;

    /// @inheritdoc IRaffle
    uint128 public override ticketCount;

    /// @inheritdoc IRaffle
    uint256 public override unsettledPot;

    /// @inheritdoc IRaffle
    uint256 public override remainingRefundLiability;

    /// @inheritdoc IRaffle
    address public override winnerRecipient;

    /// @inheritdoc IRaffle
    uint256 public override winnerProceeds;

    /// @inheritdoc IRaffle
    uint256 public override sponsorProceeds;

    /// @inheritdoc IRaffle
    uint256 public override protocolFees;

    /// @inheritdoc IRaffle
    uint256 public override vrfRequestId;

    /// @inheritdoc IRaffle
    uint64 public override drawRequestedAt;

    /// @inheritdoc IRaffle
    uint64 public override resolvedAt;

    /// @inheritdoc IRaffle
    uint128 public override winningEntry;

    /// @inheritdoc IRaffle
    uint256 public override winningTicketId;

    /// @inheritdoc IRaffle
    Status public override status;

    /// @inheritdoc IRaffle
    bool public override settlementComplete;

    /// @inheritdoc IRaffle
    bool public override winnerRedeemed;

    /// @inheritdoc IRaffle
    bool public override prizeClaimed;

    /// @inheritdoc IRaffle
    bool public override initialized;

    /// @dev Historical ticket ranges remain stored after burns so indexers and callers can reconstruct entry coverage.
    mapping(uint256 ticketId => TicketRange range) private _ticketRanges;

    /// @dev True only while the wrapper request call is executing, so a synchronous callback cannot resolve early.
    bool private _requestInFlight;

    // Errors

    /// @notice Raised when native currency is sent outside the payable draw-request path.
    error DirectNativeTransfer();

    // Constructor

    /// @notice Deploys and locks the implementation shared by one factory's minimal-proxy raffles.
    /// @dev Constructor state belongs to the implementation. Clones share these immutables but hold isolated storage.
    /// @param quoteToken_ Canonical six-decimal USDC contract fixed for the implementation and every clone.
    /// @param vrfWrapper_ Chainlink VRF v2.5 native direct-funding wrapper fixed for the implementation and all clones.
    constructor(address quoteToken_, address vrfWrapper_)
        ERC721("", "")
        VRFV2PlusWrapperConsumerBase(_validatedVrfWrapper(vrfWrapper_))
    {
        if (msg.sender == address(0) || quoteToken_ == address(0)) revert ZeroAddress();

        factory = msg.sender;
        quoteToken = IERC20(quoteToken_);

        initialized = true;
        status = Status.Refunding;
    }

    // External state-changing functions

    /// @notice Rejects direct native-token transfers that are not attached to `requestDraw`.
    receive() external payable {
        revert DirectNativeTransfer();
    }

    /// @inheritdoc IRaffle
    function initialize(RaffleInitParams calldata params) external override {
        if (initialized) revert AlreadyInitialized();
        if (msg.sender != factory) revert OnlyFactory();
        initialized = true;

        if (
            params.sponsor == address(0) || params.sponsorRecipient == address(0)
                || params.protocolTreasury == address(0) || params.prizeToken == address(0)
        ) {
            revert ZeroAddress();
        }
        if (_isProtocolDestination(params.sponsor, params.prizeToken)) {
            revert UnsafeProtocolDestination(params.sponsor);
        }
        if (_isProtocolDestination(params.protocolTreasury, params.prizeToken)) {
            revert UnsafeProtocolDestination(params.protocolTreasury);
        }
        if (_isProtocolDestination(params.sponsorRecipient, params.prizeToken)) {
            revert UnsafeProtocolDestination(params.sponsorRecipient);
        }

        sponsor = params.sponsor;
        sponsorRecipient = params.sponsorRecipient;
        protocolTreasury = params.protocolTreasury;
        prizeToken = IERC721(params.prizeToken);
        prizeTokenId = params.prizeTokenId;
        raffleId = params.raffleId;
        reserveEntries = params.reserveEntries;
        endTime = params.endTime;
        status = Status.AwaitingPrize;
    }

    /// @inheritdoc IRaffle
    function buyEntries(address recipient, uint128 entryCount)
        external
        override
        nonReentrant
        returns (uint256 ticketId)
    {
        _requireStatus(Status.Active);
        if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
        if (recipient == address(0)) revert InvalidRecipient();
        if (entryCount == 0) revert ZeroEntryCount();
        if (entryCount > type(uint128).max - totalEntries) {
            revert TotalEntriesOverflow(totalEntries, entryCount);
        }

        uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
        quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);

        uint128 firstEntry = totalEntries + 1;
        uint128 lastEntry = totalEntries + entryCount;
        ticketId = uint256(ticketCount) + 1;

        totalEntries = lastEntry;
        ++ticketCount;
        _ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
        unsettledPot += grossAmount;

        _safeMint(recipient, ticketId);
        emit TicketPurchased(msg.sender, recipient, ticketId, firstEntry, lastEntry, entryCount, grossAmount);
    }

    /// @inheritdoc IRaffle
    function requestDraw() external payable override nonReentrant returns (uint256 requestId) {
        _requireStatus(Status.Active);
        if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
        if (totalEntries == 0) revert NoEntriesSold();
        uint256 requestDeadline = drawRequestDeadline();
        if (block.timestamp >= requestDeadline) {
            revert DrawRequestWindowExpired(requestDeadline, block.timestamp);
        }

        uint256 quotedFee = getVrfRequestPrice();
        if (msg.value < quotedFee) revert InsufficientVrfFee(quotedFee, msg.value);

        status = Status.Drawing;
        drawRequestedAt = uint64(block.timestamp);
        _requestInFlight = true;
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({ nativePayment: true }));
        uint256 paidPrice;
        (requestId, paidPrice) = requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, 1, extraArgs);
        if (paidPrice > msg.value) revert InsufficientVrfFee(paidPrice, msg.value);
        vrfRequestId = requestId;
        _requestInFlight = false;

        uint256 excess = msg.value - paidPrice;
        if (excess != 0) {
            bool success;
            address refundRecipient = msg.sender;
            assembly ("memory-safe") {
                success := call(gas(), refundRecipient, excess, 0, 0, 0, 0)
            }
            if (!success) revert NativeRefundFailed(msg.sender, excess);
        }

        emit DrawRequested(requestId, msg.sender, paidPrice, excess, drawRequestedAt, callbackDeadline());
    }

    /// @inheritdoc IRaffle
    function enableRefunds() external override nonReentrant {
        uint256 deadline;

        if (status == Status.Active) {
            if (totalEntries == 0) {
                deadline = endTime;
                if (msg.sender != sponsor && block.timestamp < deadline) {
                    revert RefundsNotAvailable(deadline, block.timestamp);
                }
            } else {
                deadline = drawRequestDeadline();
                if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
            }
        } else if (status == Status.Drawing) {
            deadline = callbackDeadline();
            if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
        } else {
            revert InvalidStatus(status);
        }

        uint256 liability = unsettledPot;
        unsettledPot = 0;
        remainingRefundLiability = liability;
        status = Status.Refunding;
        emit RefundsEnabled(msg.sender, liability);
    }

    /// @inheritdoc IRaffle
    function settleWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
        cashAmount = _settleWinningTicket(ticketId);
    }

    /// @inheritdoc IRaffle
    function redeemWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
        if (winnerRedeemed) revert WinningTicketAlreadyRedeemed();
        Status result = status;
        if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);

        if (!settlementComplete) {
            _settleWinningTicket(ticketId);
        } else if (ticketId != winningTicketId) {
            revert WinningTicketMismatch(ticketId, winningTicketId);
        }

        address winner = ownerOf(ticketId);
        if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);

        winnerRecipient = winner;
        winnerRedeemed = true;
        _burn(ticketId);

        address deliveredPrizeToken = address(0);
        uint256 deliveredPrizeTokenId = 0;
        if (result == Status.NftWon) {
            if (prizeClaimed) revert PrizeAlreadyClaimed();
            prizeClaimed = true;
            deliveredPrizeToken = address(prizeToken);
            deliveredPrizeTokenId = prizeTokenId;
            prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId);
            if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) {
                revert PrizeDeliveryVerificationFailed(winner);
            }
        } else {
            cashAmount = winnerProceeds;
            if (cashAmount == 0) revert NoWinnerProceeds();
            winnerProceeds = 0;
            _transferQuote(winner, cashAmount);
        }

        emit WinningTicketRedeemed(ticketId, winner, result, cashAmount, deliveredPrizeToken, deliveredPrizeTokenId);
    }

    /// @inheritdoc IRaffle
    function refundTickets(uint256[] calldata ticketIds) external override nonReentrant returns (uint256 amount) {
        _requireStatus(Status.Refunding);
        uint256 ticketQuantity = ticketIds.length;
        if (ticketQuantity == 0 || ticketQuantity > RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE) {
            revert InvalidTicketBatchSize(ticketQuantity, RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE);
        }

        uint256 aggregateEntries = 0;
        for (uint256 index; index < ticketQuantity; ++index) {
            uint256 ticketId = ticketIds[index];
            address owner = ownerOf(ticketId);
            if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner);

            (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
            aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;
            _burn(ticketId);
        }

        amount = aggregateEntries * ENTRY_PRICE;
        remainingRefundLiability -= amount;
        _transferQuote(msg.sender, amount);
        uint256 liabilityAfter = remainingRefundLiability;
        emit TicketsRefunded(msg.sender, ticketQuantity, aggregateEntries, amount, liabilityAfter);
    }

    /// @inheritdoc IRaffle
    function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
        amount = sponsorProceeds;
        if (amount == 0) revert NoSponsorProceeds();
        sponsorProceeds = 0;
        address recipient = sponsorRecipient;
        _transferQuote(recipient, amount);
        emit SponsorProceedsReleased(msg.sender, recipient, amount);
    }

    /// @inheritdoc IRaffle
    function releaseProtocolFees() external override nonReentrant returns (uint256 amount) {
        amount = protocolFees;
        if (amount == 0) revert NoProtocolFees();
        protocolFees = 0;
        address treasury = protocolTreasury;
        _transferQuote(treasury, amount);
        emit ProtocolFeesReleased(msg.sender, treasury, amount);
    }

    /// @inheritdoc IRaffle
    function releaseSponsorPrize() external override nonReentrant {
        Status currentStatus = status;
        if (currentStatus != Status.CashWon && currentStatus != Status.Refunding) {
            revert SponsorPrizeUnavailable(currentStatus);
        }
        if (prizeClaimed) revert PrizeAlreadyClaimed();

        address recipient = sponsorRecipient;
        prizeClaimed = true;
        prizeToken.transferFrom(address(this), recipient, prizeTokenId);
        if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);
        emit SponsorPrizeReleased(msg.sender, recipient, address(prizeToken), prizeTokenId);
    }

    /// @notice Accepts only the exact configured prize deposited by the factory for the sponsor.
    /// @dev Unrelated NFTs forced here with unsafe `transferFrom` remain outside protocol accounting and cannot be
    ///      rescued.
    /// @param operator ERC-721 transfer operator, which must be the canonical factory.
    /// @param from Previous owner, which must be the configured sponsor.
    /// @param tokenId Transferred token ID, which must match the configured prize.
    /// @return selector ERC-721 receiver acceptance selector.
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)
        external
        override
        returns (bytes4 selector)
    {
        if (
            status != Status.AwaitingPrize || msg.sender != address(prizeToken) || tokenId != prizeTokenId
                || from != sponsor || operator != factory
        ) {
            revert UnexpectedPrize(msg.sender, tokenId, from, operator);
        }

        status = Status.Active;
        emit PrizeDeposited(msg.sender, tokenId, from);
        selector = IERC721Receiver.onERC721Received.selector;
    }

    // Public view and pure functions

    /// @inheritdoc IRaffle
    function getVrfRequestPrice() public view override returns (uint256 fee) {
        fee = i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1);
    }

    /// @inheritdoc IRaffle
    function estimateVrfRequestPrice(uint256 requestGasPriceWei) public view override returns (uint256 fee) {
        fee = i_vrfV2PlusWrapper.estimateRequestPriceNative(callbackGasLimit, 1, requestGasPriceWei);
    }

    /// @inheritdoc IRaffle
    function vrfWrapper() public view override returns (IVRFV2PlusWrapper wrapper) {
        wrapper = i_vrfV2PlusWrapper;
    }

    /// @inheritdoc IRaffle
    function ticketRange(uint256 ticketId) public view override returns (uint128 firstEntry, uint128 lastEntry) {
        TicketRange storage range = _ticketRanges[ticketId];
        firstEntry = range.firstEntry;
        lastEntry = range.lastEntry;
    }

    /// @inheritdoc IRaffle
    function drawRequestDeadline() public view override returns (uint256 deadline) {
        deadline = uint256(endTime) + RaffleConstants.DRAW_REQUEST_TIMEOUT;
    }

    /// @inheritdoc IRaffle
    function callbackDeadline() public view override returns (uint256 deadline) {
        if (drawRequestedAt != 0) deadline = uint256(drawRequestedAt) + RaffleConstants.DRAW_CALLBACK_TIMEOUT;
    }

    /// @inheritdoc IRaffle
    function accountedQuoteBalance() public view override returns (uint256 amount) {
        amount = unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees;
    }

    /// @inheritdoc IRaffle
    function grossSales() public view override returns (uint256 amount) {
        amount = uint256(totalEntries) * ENTRY_PRICE;
    }

    /// @notice Returns the fixed display name shared by every raffle ticket collection.
    /// @return Exact ERC-721 collection name, `raffle.fun Ticket`.
    function name() public pure override returns (string memory) {
        return "raffle.fun Ticket";
    }

    /// @notice Returns the fixed display symbol shared by every raffle ticket collection.
    /// @return Exact ERC-721 collection symbol, `RAFFLE`.
    function symbol() public pure override returns (string memory) {
        return "RAFFLE";
    }

    // Internal state-changing functions

    /// @dev Tickets remain transferable bearer claims in every lifecycle state. Known protocol sinks are rejected
    ///      before their ownership could make a claim unreachable. Burns pass the zero address and remain permitted.
    /// @param to Prospective ticket recipient, or the zero address for a burn.
    /// @param ticketId Ticket being minted, transferred, or burned.
    /// @param auth Caller whose owner or operator authority is checked by ERC-721.
    /// @return previousOwner Ticket owner before the update, or the zero address for a mint.
    function _update(address to, uint256 ticketId, address auth) internal override returns (address previousOwner) {
        if (to != address(0) && _isProtocolDestination(to, address(prizeToken))) {
            revert UnsafeProtocolDestination(to);
        }
        previousOwner = super._update(to, ticketId, auth);
    }

    /// @dev Authenticated randomness selects only an entry. No ticket search, loop, user call, or token transfer
    ///      occurs. In-flight, late, wrong-request, duplicate, and ABI-decodable wrong-length callbacks are ignored for
    ///      liveness; malformed ABI calldata reverts during Solidity decoding before this handler runs.
    /// @param requestId Wrapper-authenticated request identifier supplied by the callback.
    /// @param randomWords Callback words; exactly one word is required for resolution.
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        if (
            _requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1
                || block.timestamp >= callbackDeadline()
        ) {
            emit VrfCallbackIgnored(requestId, vrfRequestId, status);
            return;
        }

        uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
        winningEntry = resolvedEntry;
        resolvedAt = uint64(block.timestamp);
        status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;

        emit RaffleResolved(requestId, resolvedEntry, status);
    }

    // Private state-changing helpers

    /// @dev Validates the winning range once and allocates all terminal quote-token liabilities without transferring
    ///      an asset or reading ticket ownership. Both percentage allocations round down; sponsor proceeds are the
    ///      remainder.
    /// @param ticketId Ticket whose inclusive range must contain the selected winning entry.
    /// @return cashAmount Raw six-decimal quote-token units allocated to the cash winner, or zero for `NftWon`.
    function _settleWinningTicket(uint256 ticketId) private returns (uint256 cashAmount) {
        if (settlementComplete) revert SettlementAlreadyComplete();
        Status result = status;
        if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);

        _requireWinningTicket(ticketId);
        uint256 grossPot = unsettledPot;
        uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
        uint256 sponsorAmount;

        if (result == Status.NftWon) {
            sponsorAmount = grossPot - protocolFee;
        } else {
            cashAmount = Math.mulDiv(grossPot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS);
            sponsorAmount = grossPot - protocolFee - cashAmount;
            winnerProceeds = cashAmount;
        }

        settlementComplete = true;
        winningTicketId = ticketId;
        unsettledPot = 0;
        sponsorProceeds = sponsorAmount;
        protocolFees = protocolFee;

        emit WinningTicketSettled(ticketId, msg.sender, result, cashAmount, protocolFee, sponsorAmount);
    }

    /// @dev Transfers one complete current USDC claim through SafeERC20 after rejecting known protocol sinks. The
    ///      canonical USDC trust model assumes standard, non-rebasing, fee-free transfer semantics.
    /// @param to Immutable or owner-derived recipient of the claim.
    /// @param amount Raw six-decimal USDC units transferred.
    function _transferQuote(address to, uint256 amount) private {
        if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);
        quoteToken.safeTransfer(to, amount);
    }

    // Private view and pure helpers

    /// @dev Reverts unless the raffle is in the expected lifecycle state.
    /// @param expected Status required by the calling operation.
    function _requireStatus(Status expected) private view {
        if (status != expected) revert InvalidStatus(status);
    }

    /// @dev Reverts unless the supplied ticket's stored inclusive range contains the selected winning entry.
    /// @param ticketId Candidate winning ticket ID.
    function _requireWinningTicket(uint256 ticketId) private view {
        (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
        uint128 selectedEntry = winningEntry;
        if (selectedEntry < firstEntry || selectedEntry > lastEntry) {
            revert TicketDoesNotContainWinningEntry(ticketId, selectedEntry);
        }
    }

    /// @dev Identifies same-factory protocol plumbing that cannot safely own a ticket or receive a payout.
    ///      Initialization supplies the prospective prize token because clone storage is not populated yet; runtime
    ///      checks pass the stored prize token. Code-less addresses are not queried in the registry.
    /// @param destination Address being screened.
    /// @param prizeToken_ Configured or prospective prize-token address to reject.
    /// @return unsafeDestination True when the address is known same-factory protocol plumbing.
    function _isProtocolDestination(address destination, address prizeToken_)
        private
        view
        returns (bool unsafeDestination)
    {
        IRaffleFactory canonicalFactory = IRaffleFactory(factory);
        unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
            || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_
            || destination == canonicalFactory.raffleImplementation();
        if (!unsafeDestination && destination.code.length != 0) {
            unsafeDestination = canonicalFactory.isRaffle(destination);
        }
    }

    /// @dev Validates the wrapper before passing it to the inherited constructor initializer.
    /// @param wrapper Prospective Chainlink wrapper address.
    /// @return validatedWrapper The same nonzero wrapper address.
    function _validatedVrfWrapper(address wrapper) private pure returns (address validatedWrapper) {
        if (wrapper == address(0)) revert ZeroAddress();
        validatedWrapper = wrapper;
    }
}
\`\`\`

### target/packages/contracts/src/RaffleFactory.sol
\`\`\`solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { Raffle } from "./Raffle.sol";
import { IRaffle } from "./interfaces/IRaffle.sol";
import { IRaffleFactory } from "./interfaces/IRaffleFactory.sol";
import { RaffleConstants } from "./libraries/RaffleConstants.sol";

/// @title raffle.fun Canonical USDC Raffle Factory
/// @author heesho
/// @notice Atomically creates, funds, and registers autonomous fixed-implementation raffle clones.
/// @dev The implementation, canonical six-decimal USDC, treasury, fee, and Chainlink configuration are immutable. The
///      factory has no owner, pause, upgrade, rescue, or mutable protocol configuration.
/// @custom:version 1.0.0
contract RaffleFactory is IRaffleFactory, ReentrancyGuard {
    // Constants

    /// @inheritdoc IRaffleFactory
    uint32 public constant override callbackGasLimit = RaffleConstants.VRF_CALLBACK_GAS_LIMIT;

    /// @inheritdoc IRaffleFactory
    uint16 public constant override requestConfirmations = RaffleConstants.VRF_REQUEST_CONFIRMATIONS;

    // Immutables and state

    /// @inheritdoc IRaffleFactory
    address public immutable override quoteToken;

    /// @inheritdoc IRaffleFactory
    address public immutable override vrfWrapper;

    /// @inheritdoc IRaffleFactory
    address public immutable override protocolTreasury;

    /// @inheritdoc IRaffleFactory
    address public immutable override raffleImplementation;

    /// @inheritdoc IRaffleFactory
    uint256 public override raffleCount;

    /// @inheritdoc IRaffleFactory
    mapping(uint256 raffleId => address raffle) public override raffleById;

    /// @inheritdoc IRaffleFactory
    mapping(address raffle => uint256 raffleId) public override idByRaffle;

    /// @inheritdoc IRaffleFactory
    mapping(address raffle => bool registered) public override isRaffle;

    // Constructor

    /// @notice Deploys the ownerless factory and its locked raffle implementation with one immutable configuration.
    /// @dev The quote token must report exactly six decimals; the wrapper and quote token must contain deployed code.
    ///      Deployment tooling must supply and verify the target chain's official USDC address because the constructor
    ///      cannot prove token identity from metadata.
    /// @param quoteToken_ Target chain's official six-decimal USDC contract trusted by every raffle.
    /// @param vrfWrapper_ Official Chainlink VRF v2.5 native direct-funding wrapper for the target chain.
    /// @param protocolTreasury_ Immutable protocol-fee recipient used by every raffle.
    constructor(address quoteToken_, address vrfWrapper_, address protocolTreasury_) {
        _requireContract(quoteToken_);
        _requireContract(vrfWrapper_);
        if (protocolTreasury_ == address(0)) revert ZeroAddress();

        uint8 quoteDecimals = 0;
        try IERC20Metadata(quoteToken_).decimals() returns (uint8 decimals_) {
            quoteDecimals = decimals_;
        } catch {
            revert UnsupportedQuoteToken(quoteToken_);
        }
        if (quoteDecimals != RaffleConstants.QUOTE_TOKEN_DECIMALS) {
            revert InvalidQuoteTokenDecimals(quoteDecimals, RaffleConstants.QUOTE_TOKEN_DECIMALS);
        }

        if (protocolTreasury_ == address(this) || protocolTreasury_ == quoteToken_ || protocolTreasury_ == vrfWrapper_)
        {
            revert UnsafeProtocolDestination(protocolTreasury_);
        }

        quoteToken = quoteToken_;
        vrfWrapper = vrfWrapper_;
        protocolTreasury = protocolTreasury_;

        address implementation = address(new Raffle(quoteToken_, vrfWrapper_));
        if (protocolTreasury_ == implementation) revert UnsafeProtocolDestination(protocolTreasury_);
        raffleImplementation = implementation;
    }

    // External state-changing functions

    /// @inheritdoc IRaffleFactory
    function createRaffle(CreateRaffleParams calldata params) external override nonReentrant returns (address raffle) {
        _validateCreateParams(params);
        uint256 currentTime = block.timestamp;
        if (params.endTime <= currentTime) revert InvalidEndTime(currentTime, params.endTime);
        uint256 saleDuration = uint256(params.endTime) - currentTime;
        if (saleDuration > RaffleConstants.MAX_SALE_DURATION) {
            revert SaleDurationTooLong(saleDuration, RaffleConstants.MAX_SALE_DURATION);
        }
        uint256 raffleId = ++raffleCount;
        raffle = Clones.clone(raffleImplementation);
        // The fresh fixed-target clone can initialize only once; this function is nonReentrant and atomic.
        // slither-disable-next-line reentrancy-no-eth
        IRaffle(raffle)
            .initialize(
                IRaffle.RaffleInitParams({
                sponsor: msg.sender,
                sponsorRecipient: params.sponsorRecipient,
                protocolTreasury: protocolTreasury,
                prizeToken: params.prizeToken,
                prizeTokenId: params.prizeTokenId,
                raffleId: raffleId,
                reserveEntries: params.reserveEntries,
                endTime: params.endTime
            })
            );

        raffleById[raffleId] = raffle;
        idByRaffle[raffle] = raffleId;
        isRaffle[raffle] = true;

        IERC721 prize = IERC721(params.prizeToken);
        prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
        if (prize.ownerOf(params.prizeTokenId) != raffle) {
            revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
        }
        if (IRaffle(raffle).status() != IRaffle.Status.Active) {
            revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
        }

        emit RaffleCreated(
            raffleId,
            raffle,
            msg.sender,
            params.sponsorRecipient,
            params.prizeToken,
            params.prizeTokenId,
            quoteToken,
            protocolTreasury,
            params.reserveEntries,
            params.endTime
        );
    }

    // Private view helpers

    /// @dev Validates the sponsor-selected token, recipient, reserve, and supported ERC-721 interface before cloning.
    /// @param params Prospective raffle configuration supplied by the sponsor.
    function _validateCreateParams(CreateRaffleParams calldata params) private view {
        _requireContract(params.prizeToken);
        if (params.sponsorRecipient == address(0)) revert ZeroAddress();
        if (
            params.prizeToken == address(this) || params.prizeToken == quoteToken || params.prizeToken == vrfWrapper
                || params.prizeToken == raffleImplementation || isRaffle[params.prizeToken]
        ) {
            revert UnsafeProtocolDestination(params.prizeToken);
        }
        if (
            params.sponsorRecipient == address(this) || params.sponsorRecipient == quoteToken
                || params.sponsorRecipient == vrfWrapper || params.sponsorRecipient == params.prizeToken
                || params.sponsorRecipient == raffleImplementation || isRaffle[params.sponsorRecipient]
        ) {
            revert UnsafeProtocolDestination(params.sponsorRecipient);
        }

        bool supports721 = false;
        try IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
            supports721 = supported;
        } catch {
            revert UnsupportedPrizeToken(params.prizeToken);
        }
        if (!supports721) revert UnsupportedPrizeToken(params.prizeToken);
        if (params.reserveEntries == 0) revert ZeroReserveEntries();
    }

    /// @dev Reverts unless an address contains deployed code.
    /// @param account Address required to be a contract.
    function _requireContract(address account) private view {
        if (account.code.length == 0) revert NotContract(account);
    }
}
\`\`\`

### target/packages/contracts/src/interfaces/IRaffle.sol
\`\`\`solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IVRFV2PlusWrapper } from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title raffle.fun Raffle Interface
/// @author heesho
/// @notice Defines one autonomous NFT raffle using fixed-price USDC entries and one transferable ERC-721 ticket per
///         purchase.
/// @dev Ticket IDs are sequential. Each ticket stores one inclusive uint128 entry range and remains a transferable
///      bearer claim until its owner atomically burns it for redemption or refund. The immutable quote token is trusted
///      canonical six-decimal USDC with standard, non-rebasing, fee-free transfers. Supported prizes are honest,
///      standards-compliant ERC-721s.
/// @custom:version 1.0.0
interface IRaffle {
    // Types

    /// @notice The single authoritative raffle lifecycle and economic result.
    enum Status {
        /// @notice The clone is initialized and waiting for the factory to escrow the configured prize.
        AwaitingPrize,
        /// @notice The prize is escrowed and entry sales or post-sale draw initiation are available.
        Active,
        /// @notice A Chainlink VRF request was accepted and its callback window is open.
        Drawing,
        /// @notice The reserve was met and the winning ticket may redeem the prize NFT.
        NftWon,
        /// @notice The reserve was missed and the winning ticket may redeem its cash allocation.
        CashWon,
        /// @notice Full ticket refunds are enabled and the sponsor may recover the prize NFT.
        Refunding
    }

    /// @notice Complete clone-specific configuration supplied once by the canonical factory.
    /// @param sponsor Prize depositor and empty-raffle cancellation authority.
    /// @param sponsorRecipient Immutable recipient of sponsor quote proceeds and any returned prize.
    /// @param protocolTreasury Immutable recipient of protocol fees.
    /// @param prizeToken Standards-compliant ERC-721 prize contract.
    /// @param prizeTokenId Token ID of the prize escrowed by this raffle.
    /// @param raffleId One-based canonical factory identifier for this raffle.
    /// @param reserveEntries Global raw entry-count threshold selecting the NFT outcome when met or exceeded.
    /// @param endTime Unix timestamp, in seconds, at which entry sales end exclusively.
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

    // Events

    /// @notice Emitted when the factory deposits the configured prize and activates the raffle.
    /// @param prizeToken ERC-721 contract of the deposited prize.
    /// @param prizeTokenId Token ID of the deposited prize.
    /// @param sponsor Address that deposited the prize through the factory.
    event PrizeDeposited(address indexed prizeToken, uint256 indexed prizeTokenId, address indexed sponsor);

    /// @notice Emitted when a buyer pays for entries and one range ticket is minted.
    /// @param buyer Address that paid the six-decimal quote-token amount.
    /// @param recipient Address that received the newly minted ticket.
    /// @param ticketId Sequential ticket ID assigned to the purchase.
    /// @param firstEntry First global raffle entry represented by the ticket, inclusive.
    /// @param lastEntry Last global raffle entry represented by the ticket, inclusive.
    /// @param entryCount Number of entries represented by the ticket.
    /// @param grossAmount Raw six-decimal quote-token units paid, equal to `entryCount * ENTRY_PRICE`.
    event TicketPurchased(
        address indexed buyer,
        address indexed recipient,
        uint256 indexed ticketId,
        uint128 firstEntry,
        uint128 lastEntry,
        uint128 entryCount,
        uint256 grossAmount
    );

    /// @notice Emitted when the raffle pays for and records its one Chainlink VRF request.
    /// @param requestId Wrapper-assigned request identifier.
    /// @param requester Address that initiated and funded the request.
    /// @param fee Native-token wei actually paid to the wrapper for the request.
    /// @param excessReturned Native-token wei returned to the requester after paying the actual fee.
    /// @param drawRequestedAt Unix timestamp, in seconds, when the request was accepted.
    /// @param callbackDeadline Exclusive Unix-timestamp deadline for accepting the authenticated callback.
    event DrawRequested(
        uint256 indexed requestId,
        address indexed requester,
        uint256 fee,
        uint256 excessReturned,
        uint256 drawRequestedAt,
        uint256 callbackDeadline
    );

    /// @notice Emitted when an authenticated, ABI-decodable callback cannot resolve the raffle.
    /// @param receivedRequestId Request ID supplied by the wrapper callback.
    /// @param expectedRequestId Request ID currently recorded by the raffle, or zero before request persistence.
    /// @param status Current raffle status when the callback is ignored.
    event VrfCallbackIgnored(uint256 indexed receivedRequestId, uint256 indexed expectedRequestId, Status status);

    /// @notice Emitted when an authenticated callback selects the winning entry and final result.
    /// @param requestId Request ID that produced the accepted randomness.
    /// @param winningEntry Selected one-based global entry number in `[1,totalEntries]`.
    /// @param result Final `NftWon` or `CashWon` result.
    event RaffleResolved(uint256 indexed requestId, uint128 indexed winningEntry, Status indexed result);

    /// @notice Emitted when the raffle enters the full-refund branch.
    /// @param finalizer Address that enabled refunds.
    /// @param remainingRefundLiability Raw six-decimal quote-token units initially available for ticket refunds.
    event RefundsEnabled(address indexed finalizer, uint256 remainingRefundLiability);

    /// @notice Emitted when the winning ticket is proven and all terminal quote-token liabilities are allocated.
    /// @param ticketId Ticket proven to contain the selected winning entry.
    /// @param settler Address that performed permissionless settlement.
    /// @param result Final `NftWon` or `CashWon` result.
    /// @param cashAmount Raw six-decimal quote-token units allocated to the cash winner; zero for `NftWon`.
    /// @param protocolFee Raw six-decimal quote-token units allocated to the treasury, rounded down from gross sales.
    /// @param sponsorAmount Raw six-decimal quote-token units allocated to the sponsor recipient as the remainder.
    event WinningTicketSettled(
        uint256 indexed ticketId,
        address indexed settler,
        Status indexed result,
        uint256 cashAmount,
        uint256 protocolFee,
        uint256 sponsorAmount
    );

    /// @notice Emitted when the winning ticket owner burns the ticket and receives the corresponding prize.
    /// @param ticketId Burned winning ticket ID.
    /// @param winner Ticket owner that received the prize at redemption time.
    /// @param result Final `NftWon` or `CashWon` result.
    /// @param cashAmount Raw six-decimal quote-token units paid for `CashWon`; zero for `NftWon`.
    /// @param prizeToken ERC-721 prize contract for `NftWon`; the zero address for `CashWon`.
    /// @param prizeTokenId ERC-721 prize token ID for `NftWon`; zero for `CashWon`.
    event WinningTicketRedeemed(
        uint256 indexed ticketId,
        address indexed winner,
        Status indexed result,
        uint256 cashAmount,
        address prizeToken,
        uint256 prizeTokenId
    );

    /// @notice Emitted when an owner burns one or more tickets for a full quote-token refund.
    /// @param owner Ticket owner that burned the tickets and received the refund.
    /// @param ticketQuantity Number of tickets burned in this transaction.
    /// @param entryQuantity Aggregate number of entries represented by the burned tickets.
    /// @param amount Raw six-decimal quote-token units refunded, equal to `entryQuantity * ENTRY_PRICE`.
    /// @param remainingRefundLiability Raw six-decimal quote-token units still claimable after this refund.
    event TicketsRefunded(
        address indexed owner,
        uint256 ticketQuantity,
        uint256 entryQuantity,
        uint256 amount,
        uint256 remainingRefundLiability
    );

    /// @notice Emitted when the complete current sponsor balance is released to its immutable recipient.
    /// @param caller Address that triggered the permissionless release.
    /// @param recipient Immutable sponsor recipient that received the payment.
    /// @param amount Raw six-decimal quote-token units paid.
    event SponsorProceedsReleased(address indexed caller, address indexed recipient, uint256 amount);

    /// @notice Emitted when the complete current protocol-fee balance is released to the immutable treasury.
    /// @param caller Address that triggered the permissionless release.
    /// @param treasury Immutable protocol treasury that received the payment.
    /// @param amount Raw six-decimal quote-token units paid.
    event ProtocolFeesReleased(address indexed caller, address indexed treasury, uint256 amount);

    /// @notice Emitted when the escrowed prize is returned after a cash result or refund transition.
    /// @param caller Address that triggered the permissionless release.
    /// @param recipient Immutable sponsor recipient that received the prize.
    /// @param prizeToken ERC-721 contract of the returned prize.
    /// @param prizeTokenId Token ID of the returned prize.
    event SponsorPrizeReleased(
        address indexed caller, address indexed recipient, address indexed prizeToken, uint256 prizeTokenId
    );

    // Errors

    /// @notice Raised when a caller other than the immutable factory attempts clone initialization.
    error OnlyFactory();

    /// @notice Raised when initialization is attempted more than once or on the locked implementation.
    error AlreadyInitialized();

    /// @notice Raised when a required address is the zero address.
    error ZeroAddress();

    /// @notice Raised when an operation is unavailable in the current lifecycle state.
    /// @param actual Current raffle status.
    error InvalidStatus(Status actual);

    /// @notice Raised when an ERC-721 receiver callback does not exactly match the configured factory prize deposit.
    /// @param token ERC-721 contract that invoked the receiver callback.
    /// @param tokenId Token ID supplied by the callback.
    /// @param from Address identified as the previous token owner.
    /// @param operator Address identified as the transfer operator.
    error UnexpectedPrize(address token, uint256 tokenId, address from, address operator);

    /// @notice Raised when an entry purchase is submitted at or after the exclusive sale end.
    /// @param endTime Exclusive sale-end Unix timestamp, in seconds.
    /// @param currentTime Current block Unix timestamp, in seconds.
    error SaleEnded(uint256 endTime, uint256 currentTime);

    /// @notice Raised when an entry ticket would be minted to the zero address.
    error InvalidRecipient();

    /// @notice Raised when a purchase requests no entries.
    error ZeroEntryCount();

    /// @notice Raised when a purchase would exceed the `uint128` global entry-number representation.
    /// @param totalEntries Current global sold-entry count.
    /// @param requestedEntries Prospective entry count requested by the purchase.
    error TotalEntriesOverflow(uint128 totalEntries, uint128 requestedEntries);

    /// @notice Raised when a refund batch is empty or exceeds the bounded ticket limit.
    /// @param quantity Number of supplied ticket IDs.
    /// @param maximum Maximum ticket IDs accepted per refund transaction.
    error InvalidTicketBatchSize(uint256 quantity, uint256 maximum);

    /// @notice Raised when a quote-token claim targets a known protocol destination that could strand the claim.
    /// @param destination Rejected payout recipient.
    error InvalidQuoteDestination(address destination);

    /// @notice Raised when a draw request is submitted before the sale end.
    /// @param endTime Exclusive sale-end Unix timestamp, in seconds.
    /// @param currentTime Current block Unix timestamp, in seconds.
    error RaffleNotEnded(uint256 endTime, uint256 currentTime);

    /// @notice Raised when a draw request is submitted at or after the exclusive request deadline.
    /// @param deadline Exclusive draw-request Unix-timestamp deadline, in seconds.
    /// @param currentTime Current block Unix timestamp, in seconds.
    error DrawRequestWindowExpired(uint256 deadline, uint256 currentTime);

    /// @notice Raised when draw initiation is attempted for a raffle with zero sold entries.
    error NoEntriesSold();

    /// @notice Raised when refunds are requested before the applicable liveness deadline.
    /// @param deadline Unix timestamp, in seconds, at which refunds become available.
    /// @param currentTime Current block Unix timestamp, in seconds.
    error RefundsNotAvailable(uint256 deadline, uint256 currentTime);

    /// @notice Raised when supplied native value cannot cover the quoted or actual Chainlink request fee.
    /// @param requiredFee Native-token wei required for the request.
    /// @param suppliedValue Native-token wei supplied by the caller.
    error InsufficientVrfFee(uint256 requiredFee, uint256 suppliedValue);

    /// @notice Raised when excess native value cannot be returned to the draw requester.
    /// @param recipient Draw requester that was due the refund.
    /// @param amount Native-token wei that could not be returned.
    error NativeRefundFailed(address recipient, uint256 amount);

    /// @notice Raised when no current cash-winner proceeds remain claimable.
    error NoWinnerProceeds();

    /// @notice Raised when no current sponsor proceeds remain claimable.
    error NoSponsorProceeds();

    /// @notice Raised when no current protocol fees remain claimable.
    error NoProtocolFees();

    /// @notice Raised when initialization or a ticket transfer targets known protocol plumbing.
    /// @param destination Rejected address.
    error UnsafeProtocolDestination(address destination);

    /// @notice Raised when the caller is not the current owner of the supplied ticket.
    /// @param ticketId Ticket whose ownership was checked.
    /// @param caller Address attempting the owner-only operation.
    /// @param owner Current ticket owner.
    error NotTicketOwner(uint256 ticketId, address caller, address owner);

    /// @notice Raised when the supplied ticket range does not contain the selected winning entry.
    /// @param ticketId Supplied ticket ID.
    /// @param winningEntry Selected one-based global winning entry.
    error TicketDoesNotContainWinningEntry(uint256 ticketId, uint128 winningEntry);

    /// @notice Raised when terminal liabilities have already been allocated.
    error SettlementAlreadyComplete();

    /// @notice Raised when redemption supplies a ticket other than the recorded winning ticket.
    /// @param suppliedTicketId Ticket ID supplied for redemption.
    /// @param winningTicketId Previously settled winning ticket ID.
    error WinningTicketMismatch(uint256 suppliedTicketId, uint256 winningTicketId);

    /// @notice Raised when the winning ticket has already been burned and redeemed.
    error WinningTicketAlreadyRedeemed();

    /// @notice Raised when the sponsor prize cannot be returned in the current result state.
    /// @param status Current raffle status.
    error SponsorPrizeUnavailable(Status status);

    /// @notice Raised when the escrowed prize has already been released.
    error PrizeAlreadyClaimed();

    /// @notice Raised when the prize token does not report the expected owner after transfer.
    /// @param recipient Address that should own the prize after delivery.
    error PrizeDeliveryVerificationFailed(address recipient);

    // External state-changing functions

    /// @notice Initializes a fresh fixed-target clone with its immutable-per-raffle configuration.
    /// @dev Callable exactly once and only by the immutable canonical factory. Prize escrow activates the raffle later.
    /// @param params Clone-specific sponsor, prize, accounting, identifier, reserve, and timing configuration.
    function initialize(RaffleInitParams calldata params) external;

    /// @notice Buys any positive number of entries and mints one sequential ticket containing their inclusive range.
    /// @param recipient Address that receives the newly minted ERC-721 range ticket.
    /// @param entryCount Prospective number of entries to buy for this ticket.
    /// @return ticketId Sequential ID of the newly minted ticket.
    function buyEntries(address recipient, uint128 entryCount) external returns (uint256 ticketId);

    /// @notice Pays the current native Chainlink fee and requests the raffle's one random word.
    /// @dev Callable by anyone only in `[endTime,drawRequestDeadline())` after at least one entry is sold. Any native
    ///      value above the wrapper's actual fee is returned to the caller atomically.
    /// @return requestId Wrapper-assigned request identifier recorded by the raffle.
    function requestDraw() external payable returns (uint256 requestId);

    /// @notice Enables full refunds after the sold-raffle request deadline or an accepted request's callback deadline.
    ///         Also closes an empty raffle immediately for the sponsor and after sale end for anyone.
    function enableRefunds() external;

    /// @notice Proves which ticket contains the winning entry and allocates winner, sponsor, and protocol liabilities.
    /// @dev Anyone may execute; ownership is not read, the ticket remains transferable, and no external asset transfer
    ///      occurs. The cash-winner allocation is rounded down; the sponsor receives the remaining raw units.
    /// @param ticketId Ticket whose stored inclusive range must contain `winningEntry`.
    /// @return cashAmount Raw six-decimal quote-token units allocated to the winner, or zero for an NFT result.
    function settleWinningTicket(uint256 ticketId) external returns (uint256 cashAmount);

    /// @notice Lets the current winning-ticket owner atomically burn the ticket and receive the NFT or cash prize.
    /// @dev If necessary, this first settles the supplied winning ticket so the owner can complete both steps in one
    ///      transaction. Any failed delivery reverts the burn and every redemption state change.
    /// @param ticketId Winning ticket to settle if needed, burn, and redeem.
    /// @return cashAmount Raw six-decimal quote-token units paid for `CashWon`, or zero for `NftWon`.
    function redeemWinningTicket(uint256 ticketId) external returns (uint256 cashAmount);

    /// @notice Burns an owner-selected batch of tickets and returns their full entry purchase value.
    /// @dev Accepts one to 100 tickets. Duplicate, nonexistent, or foreign-owned IDs revert the entire batch.
    /// @param ticketIds Ticket IDs owned by the caller and submitted for refund.
    /// @return amount Raw six-decimal quote-token units paid, equal to represented entries times `ENTRY_PRICE`.
    function refundTickets(uint256[] calldata ticketIds) external returns (uint256 amount);

    /// @notice Releases the complete current sponsor-proceeds balance to the immutable sponsor recipient.
    /// @return amount Raw six-decimal quote-token units paid in this release.
    function releaseSponsorProceeds() external returns (uint256 amount);

    /// @notice Releases the complete current protocol-fee balance to the immutable treasury.
    /// @return amount Raw six-decimal quote-token units paid in this release.
    function releaseProtocolFees() external returns (uint256 amount);

    /// @notice Returns the escrowed prize to the immutable sponsor recipient after `CashWon` or `Refunding`.
    function releaseSponsorPrize() external;

    // External view functions

    /// @notice Returns the wrapper's current native direct-funding price for the configured callback.
    /// @return fee Native-token wei currently quoted by the wrapper; the value may change before request inclusion.
    function getVrfRequestPrice() external view returns (uint256 fee);

    /// @notice Estimates the native direct-funding price at a caller-selected gas price.
    /// @param requestGasPriceWei Prospective transaction gas price in wei per gas.
    /// @return fee Estimated native-token wei for the configured callback and one random word.
    function estimateVrfRequestPrice(uint256 requestGasPriceWei) external view returns (uint256 fee);

    /// @notice Returns the inclusive global entry range represented by a ticket ID.
    /// @dev Returns zeros for an ID that has never been minted; ranges remain historical after ticket burns.
    /// @param ticketId Sequential ticket ID to inspect.
    /// @return firstEntry First represented one-based global entry, inclusive.
    /// @return lastEntry Last represented one-based global entry, inclusive.
    function ticketRange(uint256 ticketId) external view returns (uint128 firstEntry, uint128 lastEntry);

    /// @notice Returns the exclusive deadline for initiating the draw.
    /// @return deadline Unix timestamp, in seconds, equal to `endTime + 2 days`.
    function drawRequestDeadline() external view returns (uint256 deadline);

    /// @notice Returns the exclusive deadline for accepting the authenticated callback.
    /// @return deadline Unix timestamp, in seconds, equal to `drawRequestedAt + 2 days`, or zero before a request.
    function callbackDeadline() external view returns (uint256 deadline);

    /// @notice Returns all currently outstanding quote-token liabilities tracked by the raffle.
    /// @return amount Raw six-decimal quote-token units across the unsettled pot, refunds, and allocated claims.
    function accountedQuoteBalance() external view returns (uint256 amount);

    /// @notice Returns lifetime gross sales derived from the global sold-entry count.
    /// @dev No redundant gross-sales value is stored.
    /// @return amount Raw six-decimal quote-token units equal to `totalEntries * ENTRY_PRICE`.
    function grossSales() external view returns (uint256 amount);

    // Public generated getters

    /// @notice Returns the fixed raw six-decimal quote-token price of one entry.
    /// @return price One entry price, exactly 1,000,000 raw units.
    function ENTRY_PRICE() external view returns (uint256 price);

    /// @notice Returns the fixed Chainlink callback execution limit.
    /// @return gasLimit Callback gas units requested from the wrapper.
    function callbackGasLimit() external view returns (uint32 gasLimit);

    /// @notice Returns the fixed Chainlink confirmation count.
    /// @return confirmations Blocks requested before callback fulfillment.
    function requestConfirmations() external view returns (uint16 confirmations);

    /// @notice Returns the immutable factory authorized to initialize this implementation's clones.
    /// @return factoryAddress Canonical factory address.
    function factory() external view returns (address factoryAddress);

    /// @notice Returns the prize depositor and pre-end empty-raffle refund authority.
    /// @return sponsorAddress Immutable-per-raffle sponsor address.
    function sponsor() external view returns (address sponsorAddress);

    /// @notice Returns the immutable recipient of sponsor quote proceeds and returned prizes.
    /// @return recipient Sponsor recipient address.
    function sponsorRecipient() external view returns (address recipient);

    /// @notice Returns the immutable recipient of this raffle's protocol fees.
    /// @return treasury Protocol treasury address.
    function protocolTreasury() external view returns (address treasury);

    /// @notice Returns the immutable canonical six-decimal USDC contract.
    /// @return token Canonical USDC contract trusted by this factory deployment.
    function quoteToken() external view returns (IERC20 token);

    /// @notice Returns the immutable Chainlink VRF v2.5 native direct-funding wrapper.
    /// @return wrapper Wrapper contract.
    function vrfWrapper() external view returns (IVRFV2PlusWrapper wrapper);

    /// @notice Returns the configured ERC-721 prize contract.
    /// @return token Prize-token contract.
    function prizeToken() external view returns (IERC721 token);

    /// @notice Returns the configured ERC-721 prize token ID.
    /// @return tokenId Escrowed prize token ID.
    function prizeTokenId() external view returns (uint256 tokenId);

    /// @notice Returns this raffle's one-based canonical factory identifier.
    /// @return id Raffle identifier.
    function raffleId() external view returns (uint256 id);

    /// @notice Returns the global entry threshold that selects the NFT outcome when met or exceeded.
    /// @return entries Reserve entry count.
    function reserveEntries() external view returns (uint128 entries);

    /// @notice Returns the exclusive sale-end timestamp.
    /// @return timestamp Unix timestamp, in seconds.
    function endTime() external view returns (uint64 timestamp);

    /// @notice Returns the lifetime global number of entries sold.
    /// @return entries Sold-entry count; also the last assigned global entry number.
    function totalEntries() external view returns (uint128 entries);

    /// @notice Returns the lifetime number of range tickets minted.
    /// @return tickets Ticket count; also the latest assigned ticket ID.
    function ticketCount() external view returns (uint128 tickets);

    /// @notice Returns the current unallocated sale pot.
    /// @return amount Raw six-decimal quote-token units collected before settlement or refund activation.
    function unsettledPot() external view returns (uint256 amount);

    /// @notice Returns the current aggregate full-refund liability.
    /// @return amount Raw six-decimal quote-token units still claimable by unrefunded tickets.
    function remainingRefundLiability() external view returns (uint256 amount);

    /// @notice Returns the address that burned and redeemed the winning ticket.
    /// @return recipient Winner at redemption time, or the zero address before redemption.
    function winnerRecipient() external view returns (address recipient);

    /// @notice Returns the current cash-winner liability.
    /// @return amount Raw six-decimal quote-token units claimable by the winning ticket, or zero otherwise.
    function winnerProceeds() external view returns (uint256 amount);

    /// @notice Returns the current sponsor liability.
    /// @return amount Raw six-decimal quote-token units claimable by the immutable sponsor recipient.
    function sponsorProceeds() external view returns (uint256 amount);

    /// @notice Returns the current protocol-fee liability.
    /// @return amount Raw six-decimal quote-token units claimable by the immutable treasury.
    function protocolFees() external view returns (uint256 amount);

    /// @notice Returns the accepted Chainlink request ID.
    /// @return requestId Wrapper-assigned ID, or zero before request persistence.
    function vrfRequestId() external view returns (uint256 requestId);

    /// @notice Returns when the accepted draw request was recorded.
    /// @return timestamp Unix timestamp, in seconds, or zero before request persistence.
    function drawRequestedAt() external view returns (uint64 timestamp);

    /// @notice Returns when an authenticated callback resolved the raffle.
    /// @return timestamp Unix timestamp, in seconds, or zero before resolution.
    function resolvedAt() external view returns (uint64 timestamp);

    /// @notice Returns the selected one-based global winning entry.
    /// @return entry Entry in `[1,totalEntries]`, or zero before resolution.
    function winningEntry() external view returns (uint128 entry);

    /// @notice Returns the ticket proven to contain the winning entry.
    /// @return ticketId Sequential ticket ID, or zero before settlement.
    function winningTicketId() external view returns (uint256 ticketId);

    /// @notice Returns the current lifecycle and economic result.
    /// @return currentStatus Current `Status` value.
    function status() external view returns (Status currentStatus);

    /// @notice Returns whether terminal winner, sponsor, and protocol liabilities have been allocated.
    /// @return complete True after winning-ticket settlement.
    function settlementComplete() external view returns (bool complete);

    /// @notice Returns whether the winning ticket has been burned and its NFT or cash prize delivered.
    /// @return redeemed True after successful winner redemption.
    function winnerRedeemed() external view returns (bool redeemed);

    /// @notice Returns whether the prize has been delivered to the winner or returned to the sponsor recipient.
    /// @return claimed True after successful prize release.
    function prizeClaimed() external view returns (bool claimed);

    /// @notice Returns whether this implementation or clone has completed its one-time initialization step.
    /// @return complete True for the locked implementation and every initialized clone.
    function initialized() external view returns (bool complete);
}
\`\`\`

### target/packages/contracts/src/interfaces/IRaffleFactory.sol
\`\`\`solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @title raffle.fun Raffle Factory Interface
/// @author heesho
/// @notice Defines atomic ERC-1167 raffle creation for one immutable USDC, treasury, and Chainlink configuration.
/// @dev The factory has no owner, pause, upgrade, rescue, or mutable protocol configuration. Deployment tooling must
///      verify that the immutable quote-token address is the target chain's official USDC; onchain construction checks
///      only code presence and six-decimal metadata.
/// @custom:version 1.0.0
interface IRaffleFactory {
    // Types

    /// @notice Sponsor-selected configuration for one new raffle.
    /// @param sponsorRecipient Immutable recipient of sponsor quote proceeds and any returned prize.
    /// @param prizeToken Standards-compliant ERC-721 prize contract.
    /// @param prizeTokenId Token ID to escrow atomically during creation.
    /// @param reserveEntries Global raw entry-count threshold selecting the NFT outcome when met or exceeded.
    /// @param endTime Exclusive sale-end Unix timestamp, in seconds.
    struct CreateRaffleParams {
        address sponsorRecipient;
        address prizeToken;
        uint256 prizeTokenId;
        uint128 reserveEntries;
        uint64 endTime;
    }

    // Events

    /// @notice Emitted after a raffle clone is initialized, registered, funded, and active.
    /// @param raffleId One-based canonical raffle identifier.
    /// @param raffle Newly created fixed-target ERC-1167 clone.
    /// @param sponsor Prize depositor and pre-end empty-raffle refund authority.
    /// @param sponsorRecipient Immutable recipient of sponsor quote proceeds and any returned prize.
    /// @param prizeToken ERC-721 contract of the escrowed prize.
    /// @param prizeTokenId Token ID of the escrowed prize.
    /// @param quoteToken Immutable canonical six-decimal USDC contract used by the raffle.
    /// @param protocolTreasury Immutable recipient of protocol fees.
    /// @param reserveEntries Global raw entry-count threshold selecting the NFT outcome when met or exceeded.
    /// @param endTime Exclusive sale-end Unix timestamp, in seconds.
    event RaffleCreated(
        uint256 indexed raffleId,
        address indexed raffle,
        address indexed sponsor,
        address sponsorRecipient,
        address prizeToken,
        uint256 prizeTokenId,
        address quoteToken,
        address protocolTreasury,
        uint128 reserveEntries,
        uint64 endTime
    );

    // Errors

    /// @notice Raised when a required address is the zero address.
    error ZeroAddress();

    /// @notice Raised when an address required to contain deployed code is not a contract.
    /// @param account Address whose code length was zero.
    error NotContract(address account);

    /// @notice Raised when the quote token cannot report its decimal precision.
    /// @param quoteToken Rejected quote-token contract.
    error UnsupportedQuoteToken(address quoteToken);

    /// @notice Raised when the quote token does not use the required six-decimal precision.
    /// @param actualDecimals Decimal precision reported by the quote token.
    /// @param requiredDecimals Required decimal precision, exactly six.
    error InvalidQuoteTokenDecimals(uint8 actualDecimals, uint8 requiredDecimals);

    /// @notice Raised when the prize contract does not report ERC-721 interface support.
    /// @param prizeToken Rejected prize-token contract.
    error UnsupportedPrizeToken(address prizeToken);

    /// @notice Raised when a raffle is configured with a zero reserve entry threshold.
    error ZeroReserveEntries();

    /// @notice Raised when the sale end is not strictly after the creation block timestamp.
    /// @param currentTime Current block Unix timestamp, in seconds.
    /// @param endTime Supplied exclusive sale-end Unix timestamp, in seconds.
    error InvalidEndTime(uint256 currentTime, uint256 endTime);

    /// @notice Raised when the prospective sale duration exceeds the fixed 30-day limit.
    /// @param duration Prospective sale duration in seconds.
    /// @param maximumDuration Maximum permitted sale duration in seconds.
    error SaleDurationTooLong(uint256 duration, uint256 maximumDuration);

    /// @notice Raised when a configured token or recipient is known protocol plumbing.
    /// @param destination Rejected address.
    error UnsafeProtocolDestination(address destination);

    /// @notice Raised when the exact configured prize is not owned by an active clone after escrow.
    /// @param raffle Newly created clone expected to hold the prize and report `Active`.
    /// @param prizeToken ERC-721 prize contract.
    /// @param prizeTokenId Configured prize token ID.
    error PrizeEscrowVerificationFailed(address raffle, address prizeToken, uint256 prizeTokenId);

    // External state-changing functions

    /// @notice Creates, initializes, registers, and funds one autonomous fixed-target raffle clone atomically.
    /// @param params Sponsor-selected recipient, prize, reserve, and timing configuration.
    /// @return raffle Address of the newly created and activated clone.
    function createRaffle(CreateRaffleParams calldata params) external returns (address raffle);

    // Public generated getters

    /// @notice Returns the immutable canonical six-decimal USDC contract used by every raffle.
    /// @return quoteTokenAddress Canonical USDC contract address trusted by this deployment.
    function quoteToken() external view returns (address quoteTokenAddress);

    /// @notice Returns the immutable Chainlink VRF v2.5 native direct-funding wrapper used by every raffle.
    /// @return wrapperAddress Wrapper contract address.
    function vrfWrapper() external view returns (address wrapperAddress);

    /// @notice Returns the immutable recipient of protocol fees from every raffle.
    /// @return treasuryAddress Protocol treasury address.
    function protocolTreasury() external view returns (address treasuryAddress);

    /// @notice Returns the fixed Chainlink callback execution limit used by every raffle.
    /// @return gasLimit Callback gas units requested from the wrapper.
    function callbackGasLimit() external view returns (uint32 gasLimit);

    /// @notice Returns the fixed Chainlink confirmation count used by every raffle.
    /// @return confirmations Blocks requested before callback fulfillment.
    function requestConfirmations() external view returns (uint16 confirmations);

    /// @notice Returns the immutable implementation targeted by every registered ERC-1167 clone.
    /// @return implementation Locked raffle implementation address.
    function raffleImplementation() external view returns (address implementation);

    /// @notice Returns the lifetime number of successfully created raffles.
    /// @return count Latest one-based raffle identifier and total registered raffle count.
    function raffleCount() external view returns (uint256 count);

    /// @notice Returns whether an address is a raffle registered by this factory.
    /// @param raffle Address to check.
    /// @return registered True only for a successfully created canonical clone.
    function isRaffle(address raffle) external view returns (bool registered);

    /// @notice Returns the canonical raffle address for an identifier.
    /// @param raffleId One-based raffle identifier.
    /// @return raffle Registered clone address, or the zero address for an unknown identifier.
    function raffleById(uint256 raffleId) external view returns (address raffle);

    /// @notice Returns the canonical identifier assigned to a raffle address.
    /// @param raffle Address to query.
    /// @return raffleId One-based identifier, or zero for an unregistered address.
    function idByRaffle(address raffle) external view returns (uint256 raffleId);
}
\`\`\`

### target/packages/contracts/src/libraries/RaffleConstants.sol
\`\`\`solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @title raffle.fun Protocol Constants
/// @author heesho
/// @notice Defines the fixed v1 economics, timing, and bounded-execution limits shared by the factory and raffles.
/// @dev Quote-token amounts use raw six-decimal units. Basis-point calculations round down through `Math.mulDiv`, and
///      the sponsor receives the remaining raw units after winner and protocol allocations.
/// @custom:version 1.0.0
library RaffleConstants {
    /// @notice Denominator used for every global protocol basis-point rate.
    uint256 internal constant BPS = 10_000;

    /// @notice Global protocol fee rate: 500 basis points, or 5% of gross sales.
    uint256 internal constant PROTOCOL_FEE_BPS = 500;

    /// @notice Cash-result winner rate: 8,000 basis points, or 80% of gross sales.
    uint256 internal constant CASH_WINNER_BPS = 8000;

    /// @notice Global entry price: exactly 1,000,000 raw six-decimal quote-token units, or one USDC.
    uint256 internal constant ENTRY_PRICE = 1_000_000;

    /// @notice Decimal precision required from the immutable quote token.
    uint8 internal constant QUOTE_TOKEN_DECIMALS = 6;

    /// @notice Refund execution is bounded by tickets, while each ticket may represent any uint128 entry count.
    uint256 internal constant MAX_REFUND_TICKET_BATCH_SIZE = 100;

    /// @notice Maximum prospective raffle sale duration, measured from creation to the exclusive sale end.
    uint256 internal constant MAX_SALE_DURATION = 30 days;

    /// @notice Duration after sale end during which a sold raffle may initiate its draw, in seconds.
    uint256 internal constant DRAW_REQUEST_TIMEOUT = 2 days;

    /// @notice Duration after an accepted request during which its authenticated callback may resolve, in seconds.
    uint256 internal constant DRAW_CALLBACK_TIMEOUT = 2 days;

    /// @notice Gas-unit limit requested for the single-word Chainlink callback.
    uint32 internal constant VRF_CALLBACK_GAS_LIMIT = 300_000;

    /// @notice Block confirmations requested from Chainlink before callback fulfillment.
    uint16 internal constant VRF_REQUEST_CONFIRMATIONS = 30;
}
\`\`\`

### target/DESIGN.md
\`\`\`markdown
# Clean design specification
Ethereum NFT raffle; immutable factory, ERC-1167 clones with immutable implementation. One entry costs 1,000,000 units of canonical six-decimal USDC. One purchase mints a transferable ERC721 ticket representing a contiguous inclusive range. Exactly one ERC721 prize is escrowed atomically at creation. Reserve met awards NFT and 95% sponsor / 5% treasury. Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury. Refund outcome pays 100% per entry and returns prize. Rounding is floor on aggregate protocol fee; remainder must be allocated without loss. No administrator, mutable configuration or upgrade. Request window [sale end, end+2days); callback accepted strictly before request timestamp+2days. Refunds open at deadline. Callback records result only. Settlement is permissionless, storage-only; redemption requires current ticket owner, burns claim atomically, and must revert all effects on delivery failure. Sponsor and treasury can claim independently after settlement. Never move assets between raffle clones. Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted. Frontend discovery is advisory; transaction decisions must reread current chain state.

This specification was composed before scanner results and historical findings. Source, not design prose, determines actual behavior. No tests, audit history, accepted-risk lists or scanner results are provided.
\`\`\`
# raffle.fun money map

Scope: `Raffle.sol`, `RaffleFactory.sol`, `IRaffle.sol`, `IRaffleFactory.sol`,
`RaffleConstants.sol`, and `DESIGN.md`. The quote token and Chainlink wrapper
are trusted canonical dependencies. Prize contracts and ticket recipients are
untrusted. Each clone has isolated storage and custody.

## Plain-English model

A sponsor escrows one NFT through the immutable factory. Buyers pay exactly
1,000,000 raw six-decimal USDC units per entry and receive transferable ERC-721
tickets representing contiguous entry ranges. An authenticated VRF callback
chooses one entry. If the reserve is met, its ticket owner receives the NFT and
the USDC pot is split 95% sponsor / 5% treasury; otherwise the owner receives
80% of gross USDC, the sponsor 15%, and the treasury 5%. If the draw is not
requested or fulfilled by the deadlines, every ticket can be burned for its
full entry price and the NFT returns to the sponsor recipient.

## Assets and movement

| Asset | Enters | Leaves | Custodian / receiver |
| --- | --- | --- | --- |
| Canonical 6-decimal USDC | `Raffle::buyEntries`: buyer -> clone, `entryCount * ENTRY_PRICE` | `refundTickets`; cash branch of `redeemWinningTicket`; `releaseSponsorProceeds`; `releaseProtocolFees` | One raffle clone; ticket owner, winner, sponsor recipient, treasury |
| Configured prize ERC-721 | `RaffleFactory::createRaffle`: sponsor -> clone via `safeTransferFrom` | `redeemWinningTicket` after `NftWon`; `releaseSponsorPrize` after `CashWon` or `Refunding` | One raffle clone; winning-ticket owner or sponsor recipient |
| Native ETH | `requestDraw` call value | exact wrapper request price to Chainlink; excess synchronously returned to requester | Pass-through only; no intended retained balance |
| Ticket ERC-721 claim | Minted by `buyEntries` | Burned by winning redemption or refund | Current ticket owner; ticket ranges remain historical |

## Tracked totals and all writes

| Variable | Meaning | Increasing / setting writes | Decreasing / clearing writes |
| --- | --- | --- | --- |
| `totalEntries` | Lifetime sold entries and last assigned global entry | `buyEntries`: set to prior + `entryCount` | None; lifetime counter by design |
| `ticketCount` | Lifetime tickets minted / latest ID | `buyEntries`: `+1` | None; lifetime counter by design |
| `unsettledPot` | Collected USDC not yet allocated | `buyEntries`: `+ grossAmount` | `enableRefunds`: set 0 after copying; `_settleWinningTicket`: set 0 after allocating |
| `remainingRefundLiability` | USDC owed to all unrefunded tickets | `enableRefunds`: set to old `unsettledPot` | `refundTickets`: `- aggregateEntries * ENTRY_PRICE` |
| `winnerProceeds` | Current cash-winner USDC claim | `_settleWinningTicket`: set to 80% floor in `CashWon` | `redeemWinningTicket`: set 0 before transfer |
| `sponsorProceeds` | Current sponsor-recipient USDC claim | `_settleWinningTicket`: set to remainder | `releaseSponsorProceeds`: set 0 before transfer |
| `protocolFees` | Current treasury USDC claim | `_settleWinningTicket`: set to 5% floor | `releaseProtocolFees`: set 0 before transfer |
| `raffleCount` | Lifetime canonical clones | `RaffleFactory::createRaffle`: `+1` | None; lifetime counter |
| `raffleById`, `idByRaffle`, `isRaffle` | Bidirectional clone registry | `createRaffle`: one registration after initialization | None; immutable registry |
| `winningEntry` | Selected global entry | `fulfillRandomWords`: set once from authenticated word | None |
| `winningTicketId` | Proven range containing winning entry | `_settleWinningTicket`: set once | None |
| `settlementComplete` | Terminal liabilities allocated | `_settleWinningTicket`: false -> true | None |
| `winnerRedeemed` | Winning ticket burned and prize delivered | `redeemWinningTicket`: false -> true before atomic delivery | None |
| `prizeClaimed` | Escrowed prize released | `redeemWinningTicket` NFT branch or `releaseSponsorPrize`: false -> true | None |
| `status` | Lifecycle / economic result | constructor locks implementation; `initialize`, `onERC721Received`, `requestDraw`, `fulfillRandomWords`, `enableRefunds` transition it | Not numeric |

Derived totals:

- `accountedQuoteBalance = unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees`.
- `grossSales = totalEntries * ENTRY_PRICE` is historical, not a current liability.
- A live ticket's refundable amount is `(lastEntry - firstEntry + 1) * ENTRY_PRICE` only in `Refunding`.

## Asymmetry table

| Movement / branch | Matching write | Assessment |
| --- | --- | --- |
| USDC enters in `buyEntries` | `unsettledPot += grossAmount` after transfer | Symmetric under trusted standard USDC; callback reverts roll back both |
| Pot becomes refundable | `unsettledPot = 0`; `remainingRefundLiability = old pot` | Exact liability migration |
| Refund USDC leaves | liability decremented before `_transferQuote` | Symmetric and atomic |
| Pot settles | pot clears; winner/sponsor/fee liabilities sum exactly to gross | Sponsor receives both percentage-rounding remainders |
| Cash winner / sponsor / treasury USDC leaves | respective claim clears before transfer | Symmetric and non-reentrant |
| Prize enters clone | receiver changes `AwaitingPrize -> Active`; factory checks `ownerOf` and status | Custody proof relies on behavior reported by the untrusted prize contract; attack this boundary |
| Prize leaves clone | `prizeClaimed = true`; caller checks reported `ownerOf` | State is atomic on revert, but verification again trusts the untrusted prize contract |
| Native ETH enters `requestDraw` | paid amount leaves to trusted wrapper and remainder is returned | No stored aggregate; intended same-transaction pass-through |
| Ticket burns on refund | represented entries debit aggregate refund liability | Symmetric |
| Ticket burns on winning redemption | `winnerProceeds` clears or `prizeClaimed` sets | Symmetric; losing tickets retain no terminal liability |
| Forced USDC or unrelated NFT arrives | no accounting write | Donation/untracked surplus; never used to increase claims. Unrelated NFTs are intentionally unrecoverable |

## Invariants

1. For every clone, `quoteToken.balanceOf(clone) >= accountedQuoteBalance()`; with canonical fee-free USDC and no donations, equality holds after each transaction.
2. Before terminal allocation, `unsettledPot == totalEntries * ENTRY_PRICE` and every other quote liability is zero.
3. In `Refunding`, `remainingRefundLiability` equals the sum of refund values of all unburned tickets, and no other quote claim is created.
4. After settlement, `winnerProceeds + sponsorProceeds + protocolFees == pre-settlement unsettledPot`; every raw unit is allocated exactly once.
5. Protocol fee is floor(`gross * 500 / 10_000`); cash winner is floor(`gross * 8_000 / 10_000`); sponsor receives the full remainder.
6. Ticket ranges are one-based, contiguous, non-overlapping, and cover exactly `[1,totalEntries]`.
7. `winningEntry` is always in `[1,totalEntries]`, and exactly one historical ticket range contains it.
8. Only the current winning-ticket owner can burn it and redeem; failed prize or quote delivery reverts the burn and all claim changes.
9. The configured prize is held by the clone from activation until exactly one successful winner delivery or sponsor return; it never moves between clones.
10. `initialize`, callback resolution, settlement, winning redemption, and prize release are each one-shot.
11. Draw requests occur only in `[endTime,endTime+2 days)`; accepted callbacks occur strictly before `drawRequestedAt+2 days`; refunds open at the applicable deadline.
12. Each factory registry entry binds one ID to one clone, and no clone is registered before atomic initialization and eventual prize escrow completes.

## Lifecycles and touched state

1. **Create / escrow:** `raffleCount` -> clone `initialized`, configuration, `AwaitingPrize` -> registries -> prize transfer -> `Active`, `prizeClaimed=false`.
2. **Buy / transfer:** USDC balance, `totalEntries`, `ticketCount`, `_ticketRanges`, `unsettledPot`, ticket owner/balance/approval.
3. **Successful draw:** `Active` -> `Drawing`, `drawRequestedAt`, `_requestInFlight`, `vrfRequestId` -> `winningEntry`, `resolvedAt`, `NftWon|CashWon`.
4. **Settle / redeem NFT:** `settlementComplete`, `winningTicketId`, `unsettledPot=0`, `sponsorProceeds`, `protocolFees` -> `winnerRecipient`, `winnerRedeemed`, ticket burn, `prizeClaimed`.
5. **Settle / redeem cash:** same plus `winnerProceeds` allocation -> ticket burn, `winnerProceeds=0`, USDC transfer; sponsor prize separately sets `prizeClaimed`.
6. **Timeout / refund:** `Active|Drawing` -> `unsettledPot=0`, `remainingRefundLiability`, `Refunding` -> ticket burns and liability decrements -> prize return sets `prizeClaimed`.
7. **Empty raffle:** sponsor may enable refunds before end, or anyone at/after end; no quote liability; prize returns once.
8. **Independent releases:** sponsor and treasury claims clear and transfer in either order after settlement.

## Cohorts and trust boundaries

- Sponsor: escrows prize; owed 95% if reserve met, 15% plus prize if missed, or prize on refund.
- Current ticket owners: bearer claim holders; all get full refunds on timeout, exactly one gets the terminal prize.
- Buyer vs recipient: buyer pays, but recipient owns the claim immediately.
- Winning-ticket owner at redemption: receives prize even if different from purchaser or owner at draw time.
- Sponsor recipient and protocol treasury: immutable independent beneficiaries.
- Permissionless requester / settler / releaser: pays VRF fee or advances state but receives no protocol value except fee excess.
- Factory and Chainlink wrapper: trusted immutable plumbing; the wrapper alone authenticates callbacks.
- Prize contracts and ticket-recipient contracts: expressly untrusted external-call boundaries.
- Late/last actors: there is no pro-rata yield cohort; the critical last-user test is the last refund ticket or last terminal liability claimant.

No share/exchange-rate, lending/liquidation, reward-index, oracle-price, or cross-chain aggregate exists. Those lens sections should attack the analogous ticket-range, asynchronous callback, escrow, and terminal-liability boundaries rather than invent absent accounting.
# The 0xSimao Method

Derived from 869 published findings across 143 reviews. This is HOW to think. Your lens file is WHAT to look for. Work them together.

## The core thesis

Most auditors read code looking for bad lines. That finds the bugs a linter finds.

0xSimao reads code looking for **a claim that has drifted from what actually backs it**. Value moves through a protocol in sequences: deposit, accrue, borrow, liquidate, withdraw. Each step writes some subset of the accounting state, and drift is any way that state stops describing reality:

| Drift | Shape |
| --- | --- |
| The write is missing | value moved and no variable recorded it — or one branch updates it and the sibling branch does not |
| The write is wrong | the variable is updated with the wrong amount, direction, rounding, units, or decimals |
| The write is mistimed | the right value at the wrong moment, so someone's snapshot is taken against state that is about to change |
| The write goes to the wrong party | the total is intact; the split between cohorts is not |
| The input was never trustworthy | the number is faithfully propagated from an oracle, a live balance, or a caller-supplied parameter an attacker controls |
| The state is unreachable | the accounting is correct but a revert, a pause, an unbounded loop, or a missing path means it can never be settled |

The drift is invisible at any single line. It only appears when you ask: *after this whole sequence, does the protocol still owe exactly what it holds — and can everyone actually collect it?*

A defect nobody can be shown to lose money from is a curiosity. So every candidate gets one more question, and it is the one that separates a finding from a smell:

> **Who is left holding the loss?**

Answer with a named class of actor, never "users". For accounting drift it is often whoever withdraws last, because a shortfall stays invisible until the balance runs out — but for a bricked liquidation it is the solvent lenders eating the bad debt, for a mistimed snapshot it is the cohort that held through the accrual, and for a forged signature it is whoever the forged message was drawn against. If the only person worse off is the caller, there is no finding.

**This lens is the sharpest one, not the only one.** Accounting drift is the largest single class in his corpus, but it is not the majority of it. The rest is DoS and permanently stuck funds, access control and signature defects, token- and integration-behaviour assumptions (`USDT` approvals, fee-on-transfer, blacklists, pausable collateral), oracle and parameter validation, and cross-chain state — and those are what your lens file owns. Work the money map first because it is what makes the drift class visible; then work your lens on its own terms. When the target has little accounting to speak of — a router, a registry, a verifier, a signature scheme — say so, keep the money map short, and go straight to your lens. Do not force a finding into the drift frame to make it sound like his.

## Phase 0 — Learn the protocol's own vocabulary before reading for bugs

His findings are written in the protocol's language: `cdsPoolValue`, `abond`, `downsideProtected`, `unassignedEarnings`, `raBalance`, `floatingBackupBorrowed`. He does not audit "a vault"; he audits *this* vault's specific accounting model.

Before hunting, be able to state in plain English:
- What does a user give, and what claim do they receive in return?
- What is that claim worth, and which variables determine the value?
- Where does yield come from, and who is entitled to it?
- What happens when the protocol is short — who absorbs the shortfall?

If you cannot answer these without Solidity jargon, you are not ready to find his class of bug. Any spot where your plain-English explanation goes fuzzy is exactly where the bug is; mark it and come back.

## Phase 1 — Build the money map

For every storage variable that claims to be an aggregate — `total*`, `*Supply`, `*Balance`, `*Deposited`, `*Locked`, `*Reserve`, `*Debt`, `*Accrued`, indices, cumulative rates — enumerate **every** function that writes it and whether that write increases or decreases it.

Then build the asymmetry table. Three columns of pure gold:

| Asymmetry | What to look for | Real finding |
| --- | --- | --- |
| Moved without tracking | value transferred out with no matching decrement | *"Users redeeming early will withdraw `Ra` without decreasing the amount locked, which will lead to stolen funds when withdrawing after expiry"* |
| Tracked in one branch only | `if` updates the total, `else` does not | *"Users will steal excess funds from the Vault due to `VaultPoolLib::redeem()` not always decreasing `raBalance` and `paBalance`"* |
| Never tracked at all | a balance is real but no variable represents it | *"Total `ETH`, `WETH` and `gameETH` are not tracked which will lead to insolvency"* |

Also flag every place a **live balance read** (`token.balanceOf(address(this))`, `address(this).balance`) is used as an accounting source. That is a donation attack or a cross-user theft waiting to happen — *"`ManagedLeveragedVault::openDen()` using all `asset()` balance"*, *"SDAIPriceFeed is vulnerable to donation attack via manipulatable vault rate"*.

## Phase 2 — Write the invariants down

5–15 statements that must always hold. Concretely, not vaguely:

- `Σ(all user withdrawable) <= actual token balance` — the solvency invariant, his single most productive one
- `totalX == Σ userX` for every aggregate with a per-user counterpart
- every credited unit is debited exactly once, in exactly one place
- monotonic things (indices, cumulative rates, timestamps) never go backwards and cannot be advanced for free
- a user's claim cannot increase from an action that costs them nothing
- state on chain A and chain B agree after every message settles

An invariant you can state and then break with a sequence is a finding. An invariant the docs assert and the code does not enforce is his highest-yield source of all.

## Phase 3 — Run the lifecycles, not the functions

Do not audit function by function. Audit *sequences*, and after each step write down which accounting variables changed and which should have.

Canonical sequences to run:

1. deposit → accrue yield → withdraw
2. deposit → borrow → price moves → liquidate → withdraw
3. stake → rewards distributed → unstake → claim
4. deposit → withdraw → deposit again (re-entry into the same accounting slot — *"Borrower deposit, withdraw, deposit will reinit `omniChainData.cdsPoolValue`"*)
5. open → adjust position → close (does the adjust path keep every invariant the open path established? — *"The health of a `ProtectedListing` is incorrectly calculated if `tokenTaken` has been changed through `adjustPosition()`"*)
6. source chain send → destination chain receive → failure/retry
7. the same sequence at expiry / after maturity / after the vault has ended

For each, ask at every step: **what did we just change that something else still assumes the old value of?**

## Phase 4 — Attack across cohorts and across time

This is the most distinctive part of his method, and the least commonly imitated.

Value in DeFi is split pro-rata among a changing set of holders. Any calculation that uses a *current* total to distribute a *historically accumulated* amount lets someone join late and take a share of value they did not earn.

Three questions, applied to every distribution, reward, fee, yield, and profit path:

1. **Can I join immediately before a distribution and take a share of it?**
   *"Immediately start getting rewards belonging to others after staking"*, *"Late abond holders steal USDa amount from liquidations from earlier abond holders"*, *"increaseNetworkTotal() allows big arbitrage opportunities by depositing before an increase transaction"*
2. **Can I leave immediately before a loss and push it onto whoever stays?**
   *"Borrower withdrawing at a loss will cause losses for cds depositors that only withdraw after the price recovers"*
3. **The Last User Out test.** Have every user withdraw, in sequence, in the worst order. Does the last one get paid? If the protocol is short by even dust, the money map has a leak upstream — go find it.
   *"`totalEarnings` is incorrect when withdrawing after ending which will withdraw too many funds leaving the `Vault` insolvent"*

Cumulative-rate and index-based accounting deserves special hostility: check whether the index can be advanced without cost (*"Malicious user can call `calculateCumulativeRate()` any number of times to inflate debt rate as `lastEventTime` is not updated"*), and whether a user's snapshot is taken at the right moment (*"Depositing to another receiver other than `msg.sender` will lead to stuck funds by increasing `avgStart` without claiming"*).

## Phase 5 — Saturate the subsystem

When you find one bug, **do not move on**. His reports cluster: 38 findings in one protocol, most in a single accounting subsystem. That is not luck. Once the accounting model is in your head, mine it out.

After every finding:
1. Search the codebase for every other site with the same code shape — by function name *and* by pattern. If `redeem()` forgets a decrement, check `withdraw()`, `emergencyWithdraw()`, `redeemExpired()`, and the cross-chain variant.
2. Attack the other branches of the function where you found it.
3. Escalate: a DoS often conceals fund theft; a rounding error often compounds into drain. Push each finding to its worst exploitable variant before writing it up.

A repeat instance you missed is an audit failure, not an omission.

## Phase 6 — Prove it, with preconditions stated honestly

His writeups make the reader's job trivial by separating what the protocol must look like from what the world must look like:

- **Internal pre-conditions** — protocol state required (a maturity exists, a position is near liquidation, deposits are non-zero). "None" is common and is the strongest possible case.
- **External pre-conditions** — market/oracle/chain conditions required (price moves X%, sequencer down, gas above Y). "None" is again the strongest case.
- **Attack path** — numbered, concrete, with actors and numbers. Not "an attacker could manipulate the rate" but "1. User deposits 100e18. 2. User is liquidated via `liquidationType1()`, adding 5e18 USDa. 3. Attacker deposits via flashloan and withdraws, taking 4.9e18 of it."
- **Impact** — who loses what. Name the victim class.

If you cannot fill the attack path with real numbers, you have a LEAD. Say so. A well-described lead is worth more than a finding you inflated.

## Phase 7 — Minimal mitigation

One change, the smallest that removes the defect, stated in the protocol's own terms:

- "Add a cumulative tracking variable to handle this case."
- "Set the vesting interest to 0 when the new interest is 0."
- "Decrease `raBalance` in the early-redemption branch as well."
- "Use `mulDiv` when converting between token and share amounts."

Not "refactor the accounting system." Not "consider adding validation." Name the operation to add, remove, or reorder.

## Three habits that separate his findings from noise

**Root cause is a missing operation at a named line.** Very often the bug is not a wrong line but an absent one. Write it that way: *"In `PsmLib.sol:125`, `self.psm.balances.ra.decLocked(amount)` is not called."* Pointing at the absence is what makes the fix obvious.

**Judge what the code allows, never what the deployer intends.** "The admin wouldn't do that" is not a mitigation. But equally, "admin can rug" with no concrete mechanism is not a finding.

**Doubt the clean-looking path hardest.** The functions that read as obviously correct are the ones everyone else also skipped. When a guard looks sufficient, name three specific ways to defeat it — with addresses, values, and states, not abstractions — before you accept it.

## Do not report

Admin-only functions doing admin things. Standard, accepted DeFi tradeoffs (ordinary MEV on a swap the user chose, rounding dust with no amplification, first-depositor inflation where `MINIMUM_LIQUIDITY` or a virtual-share offset is already present). Self-harm-only bugs. "Centralization risk" with no mechanism. Gas optimizations dressed as vulnerabilities. Missing zero-address checks on admin setters.
# Lens 4 — Liquidation, Bad Debt & Solvency

You own the machinery that keeps a lending or leverage protocol solvent: health calculations, liquidation eligibility, seize amounts, bonuses, bad-debt clearing, and the interaction between liquidation and every other accounting path.

Liquidation is where the most accounting variables move at once, under the most adversarial conditions, and it is the path teams test least. It is one of his richest veins.

## The shape

Liquidation must (a) be possible whenever the position is unhealthy, (b) be impossible when it is healthy, (c) leave the books balanced afterwards, and (d) actually clear the bad debt it was meant to clear. Break any one and you have either a stuck insolvent position or a profitable attack.

## Attack surfaces

**Block the liquidation.** Anything an unhealthy borrower can do to make liquidation revert or become unprofitable is a High — bad debt accrues and the protocol eats it. Look for: paused assets, reverting hooks, dust positions, minimum-debt floors, ordering requirements, gas-unbounded loops, and self-triggerable state that resets a timer.
> *Cannot repay or liquidate on paused asset*
> *Liquidations can be prevented by frontrunning and liquidating 1 debt (or more) due to wrong assumption in POS_MANAGER*
> *Liquidations can be prevented by updating the SL timeout before it expires*
> *`Market::liquidate()` will not work when most of the liquidity is borrowed due to wrong liquidator `transferFrom()` order*
> *Malicious users can DOS the protocol by setting downsideProtected to a large value*

**Check the health formula against the liquidation formula.** The predicate that says "liquidatable" and the math that executes the liquidation are often written by different people. Verify they agree at the boundary, and that the max liquidatable amount accounts for the bonus — otherwise the position is still unhealthy after a full liquidation.
> *`ViewLogic::maxLiquidatable()` doesn't take the bonus into account, making the agent liquidatable again*
> *Base calculation in `Leverager::isLiquidateable()` is incorrect as the max leverage may be smaller*
> *Contradiction between high-leverage and liquidation check of position*
> *`TARGET_HEALTH` calculation does not consider the adjust factors of the picked seize and repay markets*
> *The health of a `ProtectedListing` is incorrectly calculated if `tokenTaken` has been changed through `adjustPosition()`*

**Accrue before you judge.** Interest, earnings accumulators, and cumulative rates must be brought current before any health check or liquidation, or positions are judged on stale numbers and liquidations become profitable-but-wrong.
> *Profitable liquidations and accumulation of bad debt due to earnings accumulator not being triggered before liquidating*
> *Market interest is not always accrued*
> *It's possible to borrow, redeem, transfer tokens and exit markets with outdated collateral prices and borrow interest*
> *Liquidating maturities with unassigned earnings will not take into account floating assets increase leading to loss of funds*

**Follow every variable liquidation touches.** Liquidation moves collateral, debt, insurance, profit, and protocol totals simultaneously. Trace each one and confirm the counterpart update exists. Missing counterparts here are his signature High.
> *Liquidation will reduce total cds deposited amount, leading to incorrect option fees*
> *Type 1 borrower liquidation will incorrectly add cds profit directly to `totalCdsDepositedAmount`*
> *Liquidation profit is never given to cds depositors who will take these losses*
> *Some liquidated collateral will be locked*
> *Missing Update to `omnichain.totalAvailableLiquidationAmount` in `withdrawUser`*

**Verify bad debt actually clears.** A clearing function that leaves dust, or that only works on the last maturity, or that leaves unassigned earnings claimable by anyone, means insolvency accumulates silently.
> *Liquidations will leave dust when repaying expired maturities, making it impossible to clear bad debt putting the protocol at a risk of insolvency*
> *Some bad debt will not be cleared when it should which will cause accrual of bad debt decreasing the protocol's solvency*
> *Liquidator will leave a pool with unassigned earnings on `Market::clearBadDebt()` free to claim for anyone when the repaid maturity is not the last*
> *Bad debt is never handled which places insolvency risks on BendDAO*

**Cap the price and the seize.** Unbounded liquidation prices, unprioritized collateral selection, and missing slippage on the liquidator's swap all leak value.
> *Major insolvency risk in `LiquidationLogic::executeCrossLiquidateERC721()` due to not setting a maximum liquidation price*
> *Liquidation does not prioritize lowest LTV tokens*
> *Liquidations miss delegate call to swapper*
> *Lack of slippage protection leads to loss of protocol funds*

**Probe the leverage-adjustment boundary.** Increase/decrease leverage, partial repay, and position adjustment paths must respect minimum debt, maximum debt, and fees. They routinely do not.
> *`ManagedLeveragedVault::decreaseLeverage()` will not work when it goes below the minimum debt*
> *`ManagedLeveragedVault::executeWithdrawalEpoch()` incorrect ICR and DoSed withdrawals due to not accounting for fees*
> *DoSed withdrawals due to `ManagedLeveragedVault::executeWithdrawalEpoch()` repaying debt above limit*

## Every finding needs the position

Give the concrete position: collateral amount, debt amount, price, resulting health factor before and after. State whether the protocol is left short and by how much.
# Shared Lens Rules

## Bundle contents

Your bundle is five concatenated parts: all in-scope source, the protocol's **money map** (built by the orchestrator), the **method** (how to think), your **lens** (what you own), and these shared rules (output format and protocol).

Read the whole bundle once at the start. Do not re-read in-scope files for the initial scan. Read or search the repo only for cross-file lookups or out-of-scope context (`interfaces/`, `lib/`, `mocks/`, `test/`).

**Start from the money map, not the file list.** Pick the tracked totals, lifecycles, and cohorts your lens owns, and attack those. The file list is where you go to confirm, not where you begin.

When matching function names, check both `functionName` and `_functionName` (Solidity convention), and check library variants (`XLib::function`).

## Mandatory reasoning protocol

Four markers. Each has a trigger. When the trigger fires you MUST emit the marker before continuing. Markers live in your working text — they do NOT go inside FINDING/LEAD blocks.

| Trigger | Marker | Content |
| --- | --- | --- |
| You open a function that moves value or writes a tracked total | `[Model: <name>]` | Explain in plain English what a user gives, what they get, and which totals change. No Solidity jargon — no `safeTransfer`, `mload`, `shares`, `wad`. Where you have to reach for a Solidity term to stay accurate, mark that spot: that is where the bug is. |
| You stop on a line whose purpose is not immediately obvious | `[Why: <file:line>]` | One question that drills past "because that is how it is written." If your answer restates the code, ask again. Stop when the answer exposes the implicit belief the code rests on. |
| A path reads as clean, or a guard looks sufficient | `[Defeat: <function>]` | Three concrete attacker moves against it. Specific addresses, values, and states — never abstractions. |
| You finish a lifecycle from the money map | `[LastOut: <lifecycle>]` | Walk every user withdrawing in the worst order. State explicitly whether the last one gets paid in full, and if not, by how much the protocol is short. |

Heavy use of these is what produces the audit. Skipping them yields surface-level scanning, which is the failure mode of every junior auditor. The orchestrator checks marker counts.

## Saturation is mandatory

When you find a bug, weaponize the pattern across the entire codebase before moving on. Search by function name AND by code shape. If one redemption path forgets a decrement, check every other redemption, withdrawal, emergency, expiry, and cross-chain variant. Then attack the other branches of the function where you found it. Then escalate the finding to its worst exploitable variant — a DoS often hides fund theft.

A repeat instance you missed is an audit failure.

## Do not report

Admin-only functions doing admin things. Accepted DeFi tradeoffs (ordinary MEV on a user-chosen swap, rounding dust with no amplification path, first-depositor inflation where a virtual-share offset or `MINIMUM_LIQUIDITY` already exists). Self-harm-only bugs. "Centralization risk" or "admin can rug" without a concrete mechanism. Missing zero-address checks on admin setters. Gas findings.

## Output

FINDINGs have a concrete, unguarded, exploitable path with a named victim. LEADs have a real accounting or logic smell with a partial path. Default to LEAD over dropping — never drop.

**One vulnerability per block.** Same root cause = one block. Needs a different fix = separate block.

```
FINDING | contract: Name | function: func | bug_class: kebab-tag | group_key: Contract | function | bug-class
root_cause: the defect at File.sol:LINE, naming the missing or wrong operation
internal_pre: protocol state required, or None
external_pre: market/oracle/chain conditions required, or None
path:
  1. actor does X with concrete amount
  2. state changes to Y
  3. actor does Z
impact: who loses what, and who is left holding the loss
mitigation: the single smallest change that removes the defect
```

```
LEAD | contract: Name | function: func | bug_class: kebab-tag | group_key: Contract | function | bug-class
smell: what you found
unverified: precisely what you could not establish
description: one sentence on the trail
```

`group_key` drives deduplication and is always `ContractName | functionName | bug_class`.

An `internal_pre` or `external_pre` of `None` is the strongest possible finding — never pad these to look thorough. State the truth.
