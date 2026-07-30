// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IEntropyConsumer } from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import { IEntropyV2 } from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";

import { IRaffle } from "./interfaces/IRaffle.sol";
import { RaffleConstants } from "./libraries/RaffleConstants.sol";

/// @title Raffle
/// @notice Escrows one ERC721 prize, issues equal-chance ERC721 tickets, and settles via Pyth Entropy v2.
contract Raffle is IRaffle, Initializable, ERC721Upgradeable, ReentrancyGuard, IERC721Receiver, IEntropyConsumer {
    using SafeERC20 for IERC20;

    /// @notice Bounded quantity that makes the only ticket-minting loop predictable.
    uint256 public constant MAX_TICKETS_PER_PURCHASE = RaffleConstants.MAX_TICKETS_PER_PURCHASE;

    /// @inheritdoc IRaffle
    address public override factory;
    /// @inheritdoc IRaffle
    address public override sponsor;
    /// @inheritdoc IRaffle
    address public override protocolTreasury;
    /// @inheritdoc IRaffle
    IERC20 public override quoteToken;
    /// @inheritdoc IRaffle
    IEntropyV2 public override entropy;
    /// @inheritdoc IRaffle
    IERC721 public override prizeToken;
    /// @inheritdoc IRaffle
    uint256 public override prizeTokenId;
    /// @inheritdoc IRaffle
    uint256 public override raffleId;

    /// @inheritdoc IRaffle
    uint256 public override ticketPrice;
    /// @inheritdoc IRaffle
    uint256 public override minimumTickets;
    /// @inheritdoc IRaffle
    uint256 public override startTime;
    /// @inheritdoc IRaffle
    uint256 public override endTime;
    /// @inheritdoc IRaffle
    uint32 public override callbackGasLimit;

    /// @inheritdoc IRaffle
    uint256 public override totalTickets;
    /// @inheritdoc IRaffle
    uint256 public override grossSales;
    /// @inheritdoc IRaffle
    uint256 public override unsettledPot;
    /// @inheritdoc IRaffle
    uint256 public override totalClaimableQuote;

    /// @inheritdoc IRaffle
    uint64 public override entropySequenceNumber;
    /// @inheritdoc IRaffle
    uint256 public override winningTicketId;
    /// @inheritdoc IRaffle
    address public override winner;
    /// @inheritdoc IRaffle
    address public override prizeClaimant;

    /// @inheritdoc IRaffle
    RaffleState public override state;
    /// @inheritdoc IRaffle
    RaffleOutcome public override outcome;
    /// @inheritdoc IRaffle
    bool public override prizeClaimed;
    /// @inheritdoc IRaffle
    string public override raffleMetadataURI;

    /// @inheritdoc IRaffle
    mapping(address account => uint256 amount) public override claimableQuote;
    /// @inheritdoc IRaffle
    mapping(address account => uint256 amount) public override claimableNative;

    /// @notice Raised when native currency is sent outside the draw-request entry point.
    error DirectNativeTransfer();

    /// @notice Locks the shared implementation against direct initialization.
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IRaffle
    function initialize(InitializeParams calldata params) external override initializer {
        if (msg.sender != params.factory) revert OnlyFactory();
        if (
            params.factory == address(0) || params.sponsor == address(0) || params.protocolTreasury == address(0)
                || params.quoteToken == address(0) || params.entropy == address(0) || params.prizeToken == address(0)
        ) {
            revert ZeroAddress();
        }

        __ERC721_init(params.name, params.symbol);

        factory = params.factory;
        sponsor = params.sponsor;
        protocolTreasury = params.protocolTreasury;
        quoteToken = IERC20(params.quoteToken);
        entropy = IEntropyV2(params.entropy);
        prizeToken = IERC721(params.prizeToken);
        prizeTokenId = params.prizeTokenId;
        raffleId = params.raffleId;
        ticketPrice = params.ticketPrice;
        minimumTickets = params.minimumTickets;
        startTime = params.startTime;
        endTime = params.endTime;
        callbackGasLimit = params.callbackGasLimit;
        raffleMetadataURI = params.metadataURI;
        state = RaffleState.AwaitingPrize;
    }

    /// @inheritdoc IRaffle
    function buyTickets(address recipient, uint256 quantity)
        external
        override
        nonReentrant
        returns (uint256 firstTicketId, uint256 lastTicketId)
    {
        _requireState(RaffleState.Active);
        if (block.timestamp < startTime) revert SaleNotStarted(startTime, block.timestamp);
        if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
        if (recipient == address(0)) revert InvalidRecipient();
        if (quantity == 0 || quantity > MAX_TICKETS_PER_PURCHASE) {
            revert InvalidQuantity(quantity, MAX_TICKETS_PER_PURCHASE);
        }
        if (ticketPrice > type(uint256).max / quantity) revert GrossAmountOverflow();

        uint256 grossAmount = ticketPrice * quantity;

        uint256 balanceBefore = quoteToken.balanceOf(address(this));
        quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);
        uint256 balanceAfter = quoteToken.balanceOf(address(this));
        uint256 receivedAmount = balanceAfter >= balanceBefore ? balanceAfter - balanceBefore : 0;
        if (receivedAmount != grossAmount) revert UnsupportedQuoteToken(grossAmount, receivedAmount);

        grossSales += grossAmount;
        unsettledPot += grossAmount;

        firstTicketId = totalTickets + 1;
        lastTicketId = totalTickets + quantity;
        totalTickets = lastTicketId;

        for (uint256 ticketId = firstTicketId; ticketId <= lastTicketId; ++ticketId) {
            _safeMint(recipient, ticketId);
        }

        emit TicketsPurchased(msg.sender, recipient, quantity, firstTicketId, lastTicketId, grossAmount);
    }

    /// @inheritdoc IRaffle
    function cancelBeforeSales() external override {
        _requireState(RaffleState.Active);
        if (msg.sender != sponsor) revert OnlySponsor();
        if (totalTickets != 0) revert TicketsAlreadySold(totalTickets);

        outcome = RaffleOutcome.CancelledBeforeSale;
        prizeClaimant = sponsor;
        state = RaffleState.Cancelled;
        emit RaffleCancelled(sponsor);
    }

    /// @inheritdoc IRaffle
    function closeNoSales() external override {
        _requireState(RaffleState.Active);
        if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
        if (totalTickets != 0) revert TicketsWereSold(totalTickets);

        outcome = RaffleOutcome.NoSales;
        prizeClaimant = sponsor;
        state = RaffleState.Resolved;
        emit NoSalesClosed(sponsor);
    }

    /// @inheritdoc IRaffle
    function getEntropyFee() public view override returns (uint256 fee) {
        fee = uint256(entropy.getFeeV2(callbackGasLimit));
    }

    /// @inheritdoc IRaffle
    function requestDraw() external payable override nonReentrant returns (uint64 sequenceNumber) {
        _requireState(RaffleState.Active);
        if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
        if (totalTickets == 0) revert NoTicketsSold();

        uint256 fee = getEntropyFee();
        if (msg.value < fee) revert InsufficientEntropyFee(fee, msg.value);

        state = RaffleState.DrawRequested;
        sequenceNumber = entropy.requestV2{ value: fee }(callbackGasLimit);
        entropySequenceNumber = sequenceNumber;

        uint256 excess = msg.value - fee;
        if (excess != 0) claimableNative[msg.sender] += excess;
        emit DrawRequested(sequenceNumber, msg.sender, fee, excess);
    }

    /// @inheritdoc IRaffle
    function claimQuote(address to) external override nonReentrant returns (uint256 amount) {
        amount = _claimQuote(msg.sender, to);
    }

    /// @inheritdoc IRaffle
    function claimQuoteFor(address account) external override nonReentrant returns (uint256 amount) {
        amount = _claimQuote(account, account);
    }

    /// @inheritdoc IRaffle
    function claimPrize(address to) external override nonReentrant {
        if (state != RaffleState.Resolved && state != RaffleState.Cancelled) {
            revert InvalidState(RaffleState.Resolved, state);
        }
        if (msg.sender != prizeClaimant) revert NotPrizeClaimant(msg.sender, prizeClaimant);
        if (prizeClaimed) revert PrizeAlreadyClaimed();
        if (to == address(0)) revert ZeroAddress();

        prizeClaimed = true;
        prizeToken.safeTransferFrom(address(this), to, prizeTokenId);
        emit PrizeClaimed(msg.sender, to, address(prizeToken), prizeTokenId);
    }

    /// @inheritdoc IRaffle
    function claimNative(address payable to) external override nonReentrant returns (uint256 amount) {
        if (to == address(0)) revert ZeroAddress();
        amount = claimableNative[msg.sender];
        if (amount == 0) revert NoNativeClaim(msg.sender);

        claimableNative[msg.sender] = 0;
        (bool success,) = to.call{ value: amount }("");
        if (!success) revert NativeTransferFailed(to, amount);
        emit NativeClaimed(msg.sender, to, amount);
    }

    /// @inheritdoc IRaffle
    function isThresholdMet() public view override returns (bool thresholdMet) {
        thresholdMet = totalTickets >= minimumTickets;
    }

    /// @inheritdoc IRaffle
    function isOpen() public view override returns (bool open) {
        open = state == RaffleState.Active && block.timestamp >= startTime && block.timestamp < endTime;
    }

    /// @inheritdoc IRaffle
    function canRequestDraw() public view override returns (bool available) {
        available = state == RaffleState.Active && block.timestamp >= endTime && totalTickets != 0;
    }

    /// @inheritdoc IRaffle
    function accountedQuoteBalance() public view override returns (uint256 amount) {
        amount = unsettledPot + totalClaimableQuote;
    }

    /// @inheritdoc IRaffle
    function unaccountedQuoteSurplus() external view override returns (uint256 amount) {
        uint256 balance = quoteToken.balanceOf(address(this));
        uint256 accounted = accountedQuoteBalance();
        amount = balance > accounted ? balance - accounted : 0;
    }

    /// @inheritdoc IRaffle
    function oddsFor(address account) external view override returns (uint256 odds) {
        if (totalTickets != 0) odds = Math.mulDiv(balanceOf(account), 1e18, totalTickets);
    }

    /// @notice Returns the raffle metadata URI for every issued souvenir ticket.
    /// @param tokenId Existing ticket ID.
    /// @return uri Constrained raffle metadata URI.
    function tokenURI(uint256 tokenId) public view override returns (string memory uri) {
        _requireOwned(tokenId);
        uri = raffleMetadataURI;
    }

    /// @notice Accepts only the exact initialized prize transfer performed by the canonical factory.
    /// @param operator ERC721 transfer operator, which must be the factory.
    /// @param from Prize owner, which must be the sponsor.
    /// @param tokenId Prize token ID, which must match initialization.
    /// @return selector ERC721 receiver selector.
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)
        external
        override
        returns (bytes4 selector)
    {
        if (
            state != RaffleState.AwaitingPrize || msg.sender != address(prizeToken) || tokenId != prizeTokenId
                || from != sponsor || operator != factory
        ) {
            revert UnexpectedPrize(msg.sender, tokenId, from, operator);
        }

        state = RaffleState.Active;
        emit PrizeDeposited(msg.sender, tokenId, from);
        selector = IERC721Receiver.onERC721Received.selector;
    }

    /// @notice Rejects accidental direct native transfers; forced native currency remains harmless and unaccounted.
    receive() external payable {
        revert DirectNativeTransfer();
    }

    /// @dev Pyth's external wrapper authenticates msg.sender before this storage-only handler runs.
    function entropyCallback(uint64 sequence, address, bytes32 randomNumber) internal override {
        if (state != RaffleState.DrawRequested || sequence != entropySequenceNumber) {
            emit EntropyCallbackIgnored(sequence, entropySequenceNumber, state);
            return;
        }

        uint256 resolvedTicketId = (uint256(randomNumber) % totalTickets) + 1;
        address resolvedWinner = ownerOf(resolvedTicketId);
        uint256 grossPot = unsettledPot;
        uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
        uint256 distributablePot = grossPot - protocolFee;
        uint256 winnerCashAmount = 0;
        uint256 sponsorCashAmount = 0;

        winningTicketId = resolvedTicketId;
        winner = resolvedWinner;
        unsettledPot = 0;
        _creditQuote(protocolTreasury, protocolFee);

        if (isThresholdMet()) {
            outcome = RaffleOutcome.NftAwarded;
            prizeClaimant = resolvedWinner;
            sponsorCashAmount = distributablePot;
            _creditQuote(sponsor, sponsorCashAmount);
        } else {
            outcome = RaffleOutcome.CashFallback;
            prizeClaimant = sponsor;
            winnerCashAmount = Math.mulDiv(distributablePot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS);
            sponsorCashAmount = distributablePot - winnerCashAmount;
            _creditQuote(resolvedWinner, winnerCashAmount);
            _creditQuote(sponsor, sponsorCashAmount);
        }

        state = RaffleState.Resolved;
        emit RaffleResolved(
            sequence,
            resolvedTicketId,
            resolvedWinner,
            outcome,
            prizeClaimant,
            protocolFee,
            winnerCashAmount,
            sponsorCashAmount
        );
    }

    /// @dev Used by Pyth's authenticated external callback wrapper.
    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    /// @dev Transfer locking targets only owner-to-owner moves and cannot block minting.
    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        from = _ownerOf(tokenId);
        if (state == RaffleState.DrawRequested && from != address(0) && to != address(0)) {
            revert InvalidState(RaffleState.Active, state);
        }
        from = super._update(to, tokenId, auth);
    }

    /// @dev All quote liabilities use one accounting path so balance reconciliation remains exact.
    function _creditQuote(address account, uint256 amount) internal {
        if (amount == 0) return;
        claimableQuote[account] += amount;
        totalClaimableQuote += amount;
    }

    /// @dev Accrual is cleared before interacting with the configured quote token.
    function _claimQuote(address account, address to) internal returns (uint256 amount) {
        if (to == address(0)) revert ZeroAddress();
        amount = claimableQuote[account];
        if (amount == 0) revert NoQuoteClaim(account);

        claimableQuote[account] = 0;
        totalClaimableQuote -= amount;
        quoteToken.safeTransfer(to, amount);
        emit QuoteClaimed(account, to, amount);
    }

    /// @dev Exact state checks prevent implicit balance-based settlement detection.
    function _requireState(RaffleState expected) internal view {
        if (state != expected) revert InvalidState(expected, state);
    }
}
