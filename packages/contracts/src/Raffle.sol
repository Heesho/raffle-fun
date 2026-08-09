// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IEntropyConsumer } from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import { IEntropyV2 } from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";

import { IRaffle } from "./interfaces/IRaffle.sol";
import { IRaffleFactory } from "./interfaces/IRaffleFactory.sol";
import { RaffleConstants } from "./libraries/RaffleConstants.sol";

/**
 * @title raffle.fun Raffle Escrow and Ticket
 * @author Heesho
 * @notice Escrows one ERC-721 prize, sells equal-chance ticket NFTs, and settles through Pyth Entropy v2 or refunds.
 * @dev EIP-1167 clones are non-upgradeable and use fresh zeroed storage. OpenZeppelin 5.6.1 ReentrancyGuard treats only
 *      status `2` as entered, so a clone's initial zero status safely enters once and is normalized to `1` on exit.
 *      The implementation disables initialization, each clone authenticates the factory against the implementation
 *      address embedded in this bytecode, and all clone configuration is immutable by convention after initialization.
 *      Supported quote tokens must be non-rebasing and transfer exact amounts in both directions. Supported prizes must
 *      honestly implement ERC-721 ownership and safe transfer. Issuer controls, chain failure, and lost keys remain
 *      outside the recovery guarantee. Unsafe transfers can force unrelated NFTs here without invoking the receiver.
 * @custom:version 1.0.0
 */
contract Raffle is IRaffle, Initializable, ERC721Upgradeable, ReentrancyGuard, IERC721Receiver, IEntropyConsumer {
    using SafeERC20 for IERC20;

    /// @notice Maximum tickets minted in one purchase.
    uint256 public constant MAX_TICKETS_PER_PURCHASE = RaffleConstants.MAX_TICKETS_PER_PURCHASE;

    /// @notice Maximum refunds credited in one permissionless batch.
    uint256 public constant MAX_REFUND_CREDIT_BATCH_SIZE = RaffleConstants.MAX_REFUND_CREDIT_BATCH_SIZE;

    /// @notice Fixed post-sale window for submitting the sole draw request.
    uint256 public constant DRAW_REQUEST_GRACE_PERIOD = RaffleConstants.DRAW_REQUEST_GRACE_PERIOD;

    /// @notice Fixed wait after an accepted request before timeout finalization becomes available.
    uint256 public constant DRAW_CALLBACK_TIMEOUT = RaffleConstants.DRAW_CALLBACK_TIMEOUT;

    /// @dev Implementation address embedded in runtime bytecode and therefore visible consistently through every clone.
    address private immutable _implementation;

    /// @inheritdoc IRaffle
    address public override factory;
    /// @inheritdoc IRaffle
    address public override sponsor;
    /// @inheritdoc IRaffle
    address public override sponsorPrizeRecoveryRecipient;
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
    uint256 public override uncreditedRefundLiability;
    /// @inheritdoc IRaffle
    uint256 public override totalClaimableQuote;
    /// @inheritdoc IRaffle
    uint256 public override totalClaimableNative;

    /// @inheritdoc IRaffle
    uint64 public override entropySequenceNumber;
    /// @inheritdoc IRaffle
    uint256 public override drawRequestedAt;
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
    mapping(uint256 ticketId => bool credited) private _ticketRefundCredited;
    bool private _requestInFlight;

    /// @notice Raised when native currency is sent outside the payable draw-request path.
    error DirectNativeTransfer();

    /// @notice Locks the shared implementation and embeds its address for clone-factory authentication.
    constructor() {
        _implementation = address(this);
        _disableInitializers();
    }

    /// @inheritdoc IRaffle
    function initialize(InitializeParams calldata params) external override initializer {
        if (msg.sender != params.factory || params.factory.code.length == 0) revert OnlyFactory();
        if (IRaffleFactory(params.factory).raffleImplementation() != _implementation) revert OnlyFactory();
        bool missingParty = params.sponsor == address(0) || params.sponsorPrizeRecoveryRecipient == address(0)
            || params.protocolTreasury == address(0);
        bool missingDependency =
            params.quoteToken == address(0) || params.entropy == address(0) || params.prizeToken == address(0);
        if (missingParty || missingDependency) {
            revert ZeroAddress();
        }

        __ERC721_init(params.name, params.symbol);

        factory = params.factory;
        sponsor = params.sponsor;
        sponsorPrizeRecoveryRecipient = params.sponsorPrizeRecoveryRecipient;
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

        for (uint256 offset; offset < quantity; ++offset) {
            _safeMint(recipient, firstTicketId + offset);
        }

        emit TicketsPurchased(msg.sender, recipient, quantity, firstTicketId, lastTicketId, grossAmount);
    }

    /// @inheritdoc IRaffle
    function cancelBeforeSales() external override nonReentrant {
        _requireState(RaffleState.Active);
        if (msg.sender != sponsor) revert OnlySponsor();
        if (totalTickets != 0) revert TicketsAlreadySold(totalTickets);

        outcome = RaffleOutcome.CancelledBeforeSale;
        prizeClaimant = sponsorPrizeRecoveryRecipient;
        state = RaffleState.Cancelled;
        emit RaffleCancelled(sponsor, sponsorPrizeRecoveryRecipient);
    }

    /// @inheritdoc IRaffle
    function closeNoSales() external override nonReentrant {
        _requireState(RaffleState.Active);
        if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
        if (totalTickets != 0) revert TicketsWereSold(totalTickets);

        outcome = RaffleOutcome.NoSales;
        prizeClaimant = sponsorPrizeRecoveryRecipient;
        state = RaffleState.Resolved;
        emit NoSalesClosed(msg.sender, sponsorPrizeRecoveryRecipient);
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

        uint256 graceDeadline = requestGraceDeadline();
        if (block.timestamp >= graceDeadline) revert DrawRequestWindowExpired(graceDeadline, block.timestamp);

        uint256 fee = getEntropyFee();
        if (msg.value < fee) revert InsufficientEntropyFee(fee, msg.value);

        state = RaffleState.DrawRequested;
        drawRequestedAt = block.timestamp;
        _requestInFlight = true;
        sequenceNumber = entropy.requestV2{ value: fee }(callbackGasLimit);
        entropySequenceNumber = sequenceNumber;
        _requestInFlight = false;

        uint256 excess = msg.value - fee;
        if (excess != 0) {
            claimableNative[msg.sender] += excess;
            totalClaimableNative += excess;
        }
        emit DrawRequested(sequenceNumber, msg.sender, fee, excess, drawRequestedAt, callbackDeadline());
    }

    /// @inheritdoc IRaffle
    function finalizeUnrequestedDraw() external override nonReentrant {
        _requireState(RaffleState.Active);
        if (totalTickets == 0) revert NoTicketsSold();
        uint256 deadline = requestGraceDeadline();
        if (block.timestamp < deadline) revert DrawRequestGraceActive(deadline, block.timestamp);
        _enterRefunding(RaffleOutcome.DrawNotRequested);
    }

    /// @inheritdoc IRaffle
    function finalizeTimedOutDraw() external override nonReentrant {
        _requireState(RaffleState.DrawRequested);
        uint256 deadline = callbackDeadline();
        if (block.timestamp < deadline) revert CallbackStillPending(deadline, block.timestamp);
        _enterRefunding(RaffleOutcome.DrawTimedOut);
    }

    /// @inheritdoc IRaffle
    function creditTicketRefunds(uint256[] calldata ticketIds) external override nonReentrant {
        _requireState(RaffleState.Refunding);
        uint256 quantity = ticketIds.length;
        if (quantity == 0 || quantity > MAX_REFUND_CREDIT_BATCH_SIZE) {
            revert InvalidQuantity(quantity, MAX_REFUND_CREDIT_BATCH_SIZE);
        }

        uint256 refundAmount = ticketPrice;
        for (uint256 index; index < quantity; ++index) {
            uint256 ticketId = ticketIds[index];
            if (ticketId == 0 || ticketId > totalTickets) revert InvalidRefundTicket(ticketId);
            if (_ticketRefundCredited[ticketId]) revert TicketRefundAlreadyCredited(ticketId);

            address frozenOwner = ownerOf(ticketId);
            _ticketRefundCredited[ticketId] = true;
            uncreditedRefundLiability -= refundAmount;
            _creditQuote(frozenOwner, refundAmount);
            emit TicketRefundCredited(ticketId, frozenOwner, refundAmount, uncreditedRefundLiability);
        }
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
        if (state != RaffleState.Resolved && state != RaffleState.Cancelled && state != RaffleState.Refunding) {
            revert InvalidState(RaffleState.Resolved, state);
        }
        if (msg.sender != prizeClaimant) revert NotPrizeClaimant(msg.sender, prizeClaimant);
        _claimPrize(prizeClaimant, to);
    }

    /// @inheritdoc IRaffle
    function claimPrizeFor() external override nonReentrant {
        address claimant = prizeClaimant;
        if (claimant == address(0)) revert NoPrizeClaimant();
        _claimPrize(claimant, claimant);
    }

    /// @inheritdoc IRaffle
    function claimNative(address payable to) external override nonReentrant returns (uint256 amount) {
        if (to == address(0)) revert ZeroAddress();
        amount = claimableNative[msg.sender];
        if (amount == 0) revert NoNativeClaim(msg.sender);

        claimableNative[msg.sender] = 0;
        totalClaimableNative -= amount;
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
        available = state == RaffleState.Active && block.timestamp >= endTime
            && block.timestamp < requestGraceDeadline() && totalTickets != 0;
    }

    /// @inheritdoc IRaffle
    function canFinalizeUnrequestedDraw() public view override returns (bool available) {
        available = state == RaffleState.Active && totalTickets != 0 && block.timestamp >= requestGraceDeadline();
    }

    /// @inheritdoc IRaffle
    function canFinalizeTimedOutDraw() public view override returns (bool available) {
        available = state == RaffleState.DrawRequested && block.timestamp >= callbackDeadline();
    }

    /// @inheritdoc IRaffle
    function requestGraceDeadline() public view override returns (uint256 deadline) {
        deadline = endTime + DRAW_REQUEST_GRACE_PERIOD;
    }

    /// @inheritdoc IRaffle
    function callbackDeadline() public view override returns (uint256 deadline) {
        if (drawRequestedAt != 0) deadline = drawRequestedAt + DRAW_CALLBACK_TIMEOUT;
    }

    /// @inheritdoc IRaffle
    function isTicketRefundCredited(uint256 ticketId) external view override returns (bool credited) {
        credited = _ticketRefundCredited[ticketId];
    }

    /// @inheritdoc IRaffle
    function accountedQuoteBalance() public view override returns (uint256 amount) {
        amount = unsettledPot + uncreditedRefundLiability + totalClaimableQuote;
    }

    /// @inheritdoc IRaffle
    function accountedNativeBalance() public view override returns (uint256 amount) {
        amount = totalClaimableNative;
    }

    /// @inheritdoc IRaffle
    function unaccountedQuoteSurplus() external view override returns (uint256 amount) {
        uint256 balance = quoteToken.balanceOf(address(this));
        uint256 accounted = accountedQuoteBalance();
        amount = balance > accounted ? balance - accounted : 0;
    }

    /// @inheritdoc IRaffle
    function unaccountedNativeSurplus() external view override returns (uint256 amount) {
        uint256 accounted = accountedNativeBalance();
        amount = address(this).balance > accounted ? address(this).balance - accounted : 0;
    }

    /// @inheritdoc IRaffle
    function isQuoteSolvent() external view override returns (bool solvent) {
        solvent = quoteToken.balanceOf(address(this)) >= accountedQuoteBalance();
    }

    /// @inheritdoc IRaffle
    function oddsFor(address account) external view override returns (uint256 odds) {
        if (totalTickets != 0) odds = Math.mulDiv(balanceOf(account), 1e18, totalTickets);
    }

    /**
     * @notice Returns the same constrained raffle metadata URI for every issued souvenir ticket.
     * @param tokenId Existing ticket ID.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory uri) {
        _requireOwned(tokenId);
        uri = raffleMetadataURI;
    }

    /**
     * @notice Accepts only the exact initialized prize deposited by the canonical factory on behalf of the sponsor.
     * @dev An unsafe `transferFrom` bypasses this hook and can force unrelated NFTs into the contract; such assets are
     *      outside protocol accounting and have no administrator rescue path.
     */
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

    /// @notice Rejects accidental direct native transfers; forced value is reported only as unaccounted surplus.
    receive() external payable {
        revert DirectNativeTransfer();
    }

    /**
     * @dev Pyth's external wrapper authenticates `msg.sender`. The handler performs only bounded storage work. A
     *      callback remains valid after its deadline until a timeout transaction wins the terminal transition; once
     *      either transition executes, the other path is harmless. The first included transaction wins this race.
     */
    function entropyCallback(uint64 sequence, address, bytes32 randomNumber) internal override {
        if (_requestInFlight || state != RaffleState.DrawRequested || sequence != entropySequenceNumber) {
            emit EntropyCallbackIgnored(sequence, entropySequenceNumber, state);
            return;
        }

        uint256 resolvedTicketId = (uint256(randomNumber) % totalTickets) + 1;
        address resolvedWinner = ownerOf(resolvedTicketId);
        uint256 grossPot = unsettledPot;
        uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
        uint256 distributablePot = grossPot - protocolFee;
        uint256 winnerCashAmount = 0;
        uint256 sponsorCashAmount;

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
            prizeClaimant = sponsorPrizeRecoveryRecipient;
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

    /// @dev Returns the immutable Entropy contract used by Pyth's authenticated external callback wrapper.
    function getEntropy() internal view override returns (address entropyAddress) {
        entropyAddress = address(entropy);
    }

    /**
     * @dev Freezes owner-to-owner moves during unresolved randomness. Each refundable ticket remains frozen until its
     *      refund is credited to the failure-time owner. Minting occurs only in `Active`; burning is unsupported.
     */
    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            if (state == RaffleState.DrawRequested) revert TicketTransfersFrozen();
            if (state == RaffleState.Refunding && !_ticketRefundCredited[tokenId]) revert RefundTicketFrozen(tokenId);
        }
        from = super._update(to, tokenId, auth);
    }

    /// @dev Performs the single state transition that conserves gross sales entirely as ticket refund liability.
    function _enterRefunding(RaffleOutcome failureOutcome) internal {
        uint256 grossRefundLiability = unsettledPot;
        unsettledPot = 0;
        uncreditedRefundLiability = grossRefundLiability;
        outcome = failureOutcome;
        prizeClaimant = sponsorPrizeRecoveryRecipient;
        state = RaffleState.Refunding;
        emit DrawFailureFinalized(failureOutcome, msg.sender, sponsorPrizeRecoveryRecipient, grossRefundLiability);
    }

    /// @dev Centralizes quote liability creation so aggregate accounting cannot diverge from per-account claims.
    function _creditQuote(address account, uint256 amount) internal {
        if (amount == 0) return;
        claimableQuote[account] += amount;
        totalClaimableQuote += amount;
    }

    /**
     * @dev Clears accrual before interaction and verifies both the raffle debit and recipient credit. Any failure or
     *      non-exact delta reverts the entire transaction and restores the liability.
     */
    function _claimQuote(address account, address to) internal returns (uint256 amount) {
        if (to == address(0)) revert ZeroAddress();
        if (to == address(this)) revert InvalidQuoteDestination(to);
        amount = claimableQuote[account];
        if (amount == 0) revert NoQuoteClaim(account);

        claimableQuote[account] = 0;
        totalClaimableQuote -= amount;

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
        emit QuoteClaimed(account, to, amount);
    }

    /**
     * @dev Marks the prize claimed before the ERC-721 interaction. A failed safe transfer reverts atomically, restoring
     *      the claim; reentrancy cannot consume the prize twice.
     */
    function _claimPrize(address claimant, address to) internal {
        if (state != RaffleState.Resolved && state != RaffleState.Cancelled && state != RaffleState.Refunding) {
            revert InvalidState(RaffleState.Resolved, state);
        }
        if (prizeClaimed) revert PrizeAlreadyClaimed();
        if (to == address(0)) revert ZeroAddress();

        prizeClaimed = true;
        prizeToken.safeTransferFrom(address(this), to, prizeTokenId);
        emit PrizeClaimed(claimant, to, address(prizeToken), prizeTokenId);
    }

    /// @dev Exact state checks prevent implicit balance- or timestamp-only settlement decisions.
    function _requireState(RaffleState expected) internal view {
        if (state != expected) revert InvalidState(expected, state);
    }
}
