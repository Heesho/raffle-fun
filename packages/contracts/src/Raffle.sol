// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IChainlinkVRFV2PlusWrapper } from "./interfaces/IChainlinkVRFV2PlusWrapper.sol";
import { IRaffle } from "./interfaces/IRaffle.sol";
import { IRaffleFactory } from "./interfaces/IRaffleFactory.sol";
import { RaffleConstants } from "./libraries/RaffleConstants.sol";

/**
 * @title raffle.fun Raffle Escrow and Entry Ticket
 * @author Heesho
 * @notice Escrows one NFT and sells fixed-price USDC entries through one transferable ERC-721 ticket per purchase.
 * @dev Ticket IDs are sequential and map to one inclusive `[firstEntry,lastEntry]` uint128 range. Purchases, Chainlink
 *      callbacks, and winner proofs are O(1) in entry count. Tickets remain transferable bearer claims until burned for
 *      settlement or refund. Each raffle is a fixed, non-upgradeable ERC-1167 clone with no administrator or rescue
 *      path. Winners have fixed bearer destinations, while sponsor and protocol proceeds use fixed-recipient pull
 *      balances that anyone may release.
 * @custom:version 1.0.0
 */
contract Raffle is IRaffle, ERC721, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;

    struct TicketRange {
        uint128 firstEntry;
        uint128 lastEntry;
    }

    bytes4 private constant VRF_EXTRA_ARGS_V1_TAG = bytes4(keccak256("VRF ExtraArgsV1"));

    uint256 public constant override ENTRY_PRICE = RaffleConstants.ENTRY_PRICE;
    uint32 public constant override callbackGasLimit = RaffleConstants.VRF_CALLBACK_GAS_LIMIT;
    uint16 public constant override requestConfirmations = RaffleConstants.VRF_REQUEST_CONFIRMATIONS;

    address public immutable override factory;
    IERC20 public immutable override quoteToken;
    IChainlinkVRFV2PlusWrapper public immutable override vrfWrapper;

    address public override sponsor;
    address public override sponsorRecipient;
    address public override protocolTreasury;
    IERC721 public override prizeToken;
    uint256 public override prizeTokenId;
    uint256 public override raffleId;
    uint128 public override reserveEntries;
    uint64 public override endTime;
    uint128 public override totalEntries;
    uint128 public override ticketCount;
    uint256 public override unsettledPot;
    uint256 public override remainingRefundLiability;
    uint256 public override sponsorProceeds;
    uint256 public override protocolFees;
    uint256 public override vrfRequestId;
    uint64 public override drawRequestedAt;
    uint64 public override resolvedAt;
    uint128 public override winningEntry;
    uint256 public override winningTicketId;
    Status public override status;
    bool public override prizeClaimed;
    bool public override initialized;
    mapping(uint256 ticketId => TicketRange range) private _ticketRanges;

    bool private _requestInFlight;

    /// @notice Raised when native currency is sent outside the payable draw-request path.
    error DirectNativeTransfer();

    /**
     * @notice Deploys and locks the implementation shared by one factory's minimal-proxy raffles.
     * @dev Constructor state belongs to the implementation. Clones share these immutables but hold isolated storage.
     */
    constructor(address quoteToken_, address vrfWrapper_) ERC721("", "") {
        if (msg.sender == address(0) || quoteToken_ == address(0) || vrfWrapper_ == address(0)) revert ZeroAddress();

        factory = msg.sender;
        quoteToken = IERC20(quoteToken_);
        vrfWrapper = IChainlinkVRFV2PlusWrapper(vrfWrapper_);

        initialized = true;
        status = Status.Refunding;
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
        if (_isInitializationProtocolDestination(params.sponsor, params.prizeToken)) {
            revert UnsafeProtocolDestination(params.sponsor);
        }
        if (_isInitializationProtocolDestination(params.protocolTreasury, params.prizeToken)) {
            revert UnsafeProtocolDestination(params.protocolTreasury);
        }
        if (_isInitializationProtocolDestination(params.sponsorRecipient, params.prizeToken)) {
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

    function name() public pure override returns (string memory) {
        return "raffle.fun Ticket";
    }

    function symbol() public pure override returns (string memory) {
        return "RAFFLE";
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
        uint256 balanceBefore = quoteToken.balanceOf(address(this));
        quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
        uint256 balanceAfter = quoteToken.balanceOf(address(this));
        uint256 receivedAmount = balanceAfter >= balanceBefore ? balanceAfter - balanceBefore : 0;
        if (receivedAmount != grossAmount) revert UnsupportedQuoteToken(grossAmount, receivedAmount);

        uint128 firstEntry = totalEntries + 1;
        uint128 lastEntry = totalEntries + entryCount;
        ticketId = uint256(ticketCount) + 1;

        totalEntries = lastEntry;
        unchecked {
            // Every ticket contains at least one entry, so ticketCount cannot overflow before totalEntries does.
            ++ticketCount;
        }
        _ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
        unsettledPot += grossAmount;

        _safeMint(recipient, ticketId);
        emit TicketPurchased(msg.sender, recipient, ticketId, firstEntry, lastEntry, entryCount, grossAmount);
    }

    /// @inheritdoc IRaffle
    function getVrfRequestPrice() public view override returns (uint256 fee) {
        fee = vrfWrapper.calculateRequestPriceNative(callbackGasLimit, 1);
    }

    /// @inheritdoc IRaffle
    function estimateVrfRequestPrice(uint256 requestGasPriceWei) public view override returns (uint256 fee) {
        fee = vrfWrapper.estimateRequestPriceNative(callbackGasLimit, 1, requestGasPriceWei);
    }

    /// @inheritdoc IRaffle
    function requestDraw() external payable override nonReentrant returns (uint256 requestId) {
        _requireStatus(Status.Active);
        if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
        if (totalEntries == 0) revert NoEntriesSold();

        uint256 fee = getVrfRequestPrice();
        if (msg.value < fee) revert InsufficientVrfFee(fee, msg.value);

        status = Status.Drawing;
        drawRequestedAt = uint64(block.timestamp);
        _requestInFlight = true;
        bytes memory extraArgs = abi.encodeWithSelector(VRF_EXTRA_ARGS_V1_TAG, true);
        requestId =
            vrfWrapper.requestRandomWordsInNative{ value: fee }(callbackGasLimit, requestConfirmations, 1, extraArgs);
        vrfRequestId = requestId;
        _requestInFlight = false;

        uint256 excess = msg.value - fee;
        if (excess != 0) {
            bool success;
            address refundRecipient = msg.sender;
            assembly ("memory-safe") {
                success := call(gas(), refundRecipient, excess, 0, 0, 0, 0)
            }
            if (!success) revert NativeRefundFailed(msg.sender, excess);
        }

        emit DrawRequested(requestId, msg.sender, fee, excess, drawRequestedAt, callbackDeadline());
    }

    /// @inheritdoc IRaffle
    function enableRefunds() external override nonReentrant {
        uint256 deadline;

        if (status == Status.Active) {
            if (totalEntries != 0) revert InvalidStatus(status);
            deadline = endTime;
            if (msg.sender != sponsor && block.timestamp < deadline) {
                revert RefundsNotAvailable(deadline, block.timestamp);
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
        Status result = status;
        if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);

        address winner = ownerOf(ticketId);
        _requireWinningTicket(ticketId);
        uint256 grossPot = unsettledPot;
        uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
        uint256 sponsorAmount;

        if (result == Status.NftWon) {
            sponsorAmount = grossPot - protocolFee;
            prizeClaimed = true;
        } else {
            cashAmount = Math.mulDiv(grossPot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS);
            sponsorAmount = grossPot - protocolFee - cashAmount;
        }

        winningTicketId = ticketId;
        unsettledPot = 0;
        sponsorProceeds = sponsorAmount;
        protocolFees = protocolFee;
        _burn(ticketId);

        if (result == Status.NftWon) {
            // Deliberately avoids an ERC721Receiver callback so a contract winner cannot veto permissionless delivery.
            prizeToken.transferFrom(address(this), winner, prizeTokenId);
            if (prizeToken.ownerOf(prizeTokenId) != winner) revert PrizeDeliveryVerificationFailed(winner);
        } else {
            _transferQuoteExact(winner, cashAmount);
        }

        emit WinningTicketSettled(ticketId, winner, result, cashAmount, protocolFee, sponsorAmount);
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
        _transferQuoteExact(msg.sender, amount);
        uint256 liabilityAfter = remainingRefundLiability;
        emit TicketsRefunded(msg.sender, ticketQuantity, aggregateEntries, amount, liabilityAfter);
    }

    /// @inheritdoc IRaffle
    function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
        amount = sponsorProceeds;
        if (amount == 0) revert NoSponsorProceeds();
        sponsorProceeds = 0;
        address recipient = sponsorRecipient;
        _transferQuoteExact(recipient, amount);
        emit SponsorProceedsReleased(msg.sender, recipient, amount);
    }

    /// @inheritdoc IRaffle
    function releaseProtocolFees() external override nonReentrant returns (uint256 amount) {
        amount = protocolFees;
        if (amount == 0) revert NoProtocolFees();
        protocolFees = 0;
        address treasury = protocolTreasury;
        _transferQuoteExact(treasury, amount);
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

    /// @inheritdoc IRaffle
    function ticketRange(uint256 ticketId) public view override returns (uint128 firstEntry, uint128 lastEntry) {
        TicketRange storage range = _ticketRanges[ticketId];
        firstEntry = range.firstEntry;
        lastEntry = range.lastEntry;
    }

    /// @inheritdoc IRaffle
    function callbackDeadline() public view override returns (uint256 deadline) {
        if (drawRequestedAt != 0) deadline = uint256(drawRequestedAt) + RaffleConstants.DRAW_CALLBACK_TIMEOUT;
    }

    /// @inheritdoc IRaffle
    function accountedQuoteBalance() public view override returns (uint256 amount) {
        amount = unsettledPot + remainingRefundLiability + sponsorProceeds + protocolFees;
    }

    /// @inheritdoc IRaffle
    function grossSales() public view override returns (uint256 amount) {
        amount = uint256(totalEntries) * ENTRY_PRICE;
    }

    /**
     * @dev Tickets remain transferable bearer claims in every lifecycle state. Known protocol sinks are rejected before
     *      their ownership could make a claim unreachable.
     */
    function _update(address to, uint256 ticketId, address auth) internal override returns (address previousOwner) {
        if (to != address(0) && _isKnownProtocolDestination(to)) revert UnsafeProtocolDestination(to);
        previousOwner = super._update(to, ticketId, auth);
    }

    /**
     * @notice Accepts only the exact configured prize deposited by the factory for the sponsor.
     * @dev Unrelated NFTs forced here with unsafe `transferFrom` remain outside protocol accounting and have no rescue.
     */
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

    receive() external payable {
        revert DirectNativeTransfer();
    }

    /// @inheritdoc IRaffle
    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external override {
        address wrapperAddress = address(vrfWrapper);
        if (msg.sender != wrapperAddress) revert OnlyVRFWrapperCanFulfill(msg.sender, wrapperAddress);
        _fulfillRandomWords(requestId, randomWords);
    }

    /**
     * @dev Authenticated randomness selects only an entry. No ticket search, loop, user call, or token transfer
     *      occurs. Wrong-request, in-flight, stale, malformed, and duplicate callbacks are ignored for liveness.
     */
    function _fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) private {
        if (_requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1) {
            emit VrfCallbackIgnored(requestId, vrfRequestId, status);
            return;
        }

        uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
        winningEntry = resolvedEntry;
        resolvedAt = uint64(block.timestamp);
        status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;

        emit RaffleResolved(requestId, resolvedEntry, status);
    }

    function _requireWinningTicket(uint256 ticketId) private view {
        (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
        uint128 selectedEntry = winningEntry;
        if (selectedEntry < firstEntry || selectedEntry > lastEntry) {
            revert TicketDoesNotContainWinningEntry(ticketId, selectedEntry);
        }
    }

    function _transferQuoteExact(address to, uint256 amount) private {
        if (_isKnownProtocolDestination(to)) revert InvalidQuoteDestination(to);
        uint256 raffleBalanceBefore = quoteToken.balanceOf(address(this));
        uint256 recipientBalanceBefore = quoteToken.balanceOf(to);
        quoteToken.safeTransfer(to, amount);
        uint256 raffleBalanceAfter = quoteToken.balanceOf(address(this));
        uint256 recipientBalanceAfter = quoteToken.balanceOf(to);

        uint256 debitedAmount = 0;
        if (raffleBalanceBefore >= raffleBalanceAfter) {
            debitedAmount = raffleBalanceBefore - raffleBalanceAfter;
        }
        uint256 creditedAmount =
            recipientBalanceAfter >= recipientBalanceBefore ? recipientBalanceAfter - recipientBalanceBefore : 0;
        if (debitedAmount != amount || creditedAmount != amount) {
            revert UnsupportedQuoteTokenTransfer(amount, debitedAmount, creditedAmount);
        }
    }

    function _requireStatus(Status expected) private view {
        if (status != expected) revert InvalidStatus(status);
    }

    function _isInitializationProtocolDestination(address destination, address prizeToken_)
        private
        view
        returns (bool unsafeDestination)
    {
        IRaffleFactory canonicalFactory = IRaffleFactory(factory);
        unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
            || destination == address(vrfWrapper) || destination == prizeToken_
            || destination == canonicalFactory.raffleImplementation();
        if (!unsafeDestination && destination.code.length != 0) {
            unsafeDestination = canonicalFactory.isRaffle(destination);
        }
    }

    function _isKnownProtocolDestination(address destination) private view returns (bool unsafeDestination) {
        IRaffleFactory canonicalFactory = IRaffleFactory(factory);
        unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
            || destination == address(vrfWrapper) || destination == address(prizeToken)
            || destination == canonicalFactory.raffleImplementation();
        if (!unsafeDestination && destination.code.length != 0) {
            unsafeDestination = canonicalFactory.isRaffle(destination);
        }
    }
}
