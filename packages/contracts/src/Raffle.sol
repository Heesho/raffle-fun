// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
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
 * @title raffle.fun Raffle Escrow and Bearer Ticket
 * @author Heesho
 * @notice Escrows one NFT, sells transferable tickets, and settles through Pyth Entropy v2 or exact ticket refunds.
 * @dev Each raffle is a non-upgradeable constructor deployment. Ticket ownership is the claim credential: the winning
 *      ticket burns for the NFT or cash award, and refundable tickets burn for their purchase price. No ownership
 *      snapshot or transfer freeze exists. Normal sponsor and treasury proceeds remain pull claims so one recipient
 *      cannot block another. The Entropy callback performs bounded storage work and no external asset transfer.
 * @custom:version 2.0.0
 */
contract Raffle is IRaffle, ERC721, ReentrancyGuard, IERC721Receiver, IEntropyConsumer {
    using SafeERC20 for IERC20;

    address public immutable override factory;
    address public immutable override sponsor;
    address public immutable override sponsorPrizeRecoveryRecipient;
    address public immutable override protocolTreasury;
    IERC20 public immutable override quoteToken;
    IEntropyV2 public immutable override entropy;
    IERC721 public immutable override prizeToken;
    uint256 public immutable override prizeTokenId;
    uint256 public immutable override raffleId;
    uint256 public immutable override ticketPrice;
    uint256 public immutable override minimumTickets;
    uint256 public immutable override startTime;
    uint256 public immutable override endTime;
    uint32 public immutable override callbackGasLimit;

    uint256 public override totalTickets;
    uint256 public override grossSales;
    uint256 public override unsettledPot;
    uint256 public override remainingRefundLiability;
    uint256 public override winnerCashLiability;
    uint256 public override totalClaimableQuote;
    uint64 public override entropySequenceNumber;
    uint256 public override drawRequestedAt;
    uint256 public override winningTicketId;
    Status public override status;
    bool public override prizeClaimed;
    string public override raffleMetadataURI;
    mapping(address account => uint256 amount) public override claimableQuote;

    bool private _requestInFlight;

    /// @notice Raised when native currency is sent outside the payable draw-request path.
    error DirectNativeTransfer();

    /**
     * @notice Creates one immutable raffle in an awaiting-prize state.
     * @dev The factory registers this address and deposits the exact prize in the same transaction. Any later failure
     *      reverts this deployment as well as factory registry changes.
     * @param params Complete factory-validated raffle configuration.
     */
    constructor(RaffleParams memory params) ERC721("raffle.fun Ticket", "RAFFLE") {
        if (msg.sender != params.factory) revert OnlyFactory();
        bool missingParty = params.sponsor == address(0) || params.sponsorPrizeRecoveryRecipient == address(0)
            || params.protocolTreasury == address(0);
        bool missingDependency =
            params.quoteToken == address(0) || params.entropy == address(0) || params.prizeToken == address(0);
        if (missingParty || missingDependency) revert ZeroAddress();
        if (_isConstructorProtocolDestination(params.sponsorPrizeRecoveryRecipient, params)) {
            revert UnsafeProtocolDestination(params.sponsorPrizeRecoveryRecipient);
        }
        if (_isConstructorProtocolDestination(params.protocolTreasury, params)) {
            revert UnsafeProtocolDestination(params.protocolTreasury);
        }

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
        status = Status.AwaitingPrize;
    }

    /// @inheritdoc IRaffle
    function buyTickets(address recipient, uint256 quantity)
        external
        override
        nonReentrant
        returns (uint256 firstTicketId, uint256 lastTicketId)
    {
        _requireStatus(Status.Active);
        if (block.timestamp < startTime) revert SaleNotStarted(startTime, block.timestamp);
        if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
        if (recipient == address(0)) revert InvalidRecipient();
        if (quantity == 0 || quantity > RaffleConstants.MAX_TICKETS_PER_PURCHASE) {
            revert InvalidQuantity(quantity, RaffleConstants.MAX_TICKETS_PER_PURCHASE);
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
    function closeEmptyRaffle() external override nonReentrant {
        _requireStatus(Status.Active);
        if (totalTickets != 0) revert TicketsWereSold(totalTickets);
        if (block.timestamp < endTime && msg.sender != sponsor) revert OnlySponsor();

        status = Status.Closed;
        emit EmptyRaffleClosed(msg.sender, sponsorPrizeRecoveryRecipient);
    }

    /// @inheritdoc IRaffle
    function getEntropyFee() public view override returns (uint256 fee) {
        fee = uint256(entropy.getFeeV2(callbackGasLimit));
    }

    /// @inheritdoc IRaffle
    function requestDraw() external payable override nonReentrant returns (uint64 sequenceNumber) {
        _requireStatus(Status.Active);
        if (block.timestamp < endTime) revert RaffleNotEnded(endTime, block.timestamp);
        if (totalTickets == 0) revert NoTicketsSold();

        uint256 graceDeadline = requestGraceDeadline();
        if (block.timestamp >= graceDeadline) revert DrawRequestWindowExpired(graceDeadline, block.timestamp);

        uint256 fee = getEntropyFee();
        if (msg.value < fee) revert InsufficientEntropyFee(fee, msg.value);

        status = Status.Drawing;
        drawRequestedAt = block.timestamp;
        _requestInFlight = true;
        sequenceNumber = entropy.requestV2{ value: fee }(callbackGasLimit);
        entropySequenceNumber = sequenceNumber;
        _requestInFlight = false;

        uint256 excess = msg.value - fee;
        if (excess != 0) {
            (bool success,) = payable(msg.sender).call{ value: excess }("");
            if (!success) revert NativeRefundFailed(msg.sender, excess);
        }

        emit DrawRequested(sequenceNumber, msg.sender, fee, excess, drawRequestedAt, callbackDeadline());
    }

    /// @inheritdoc IRaffle
    function enableRefunds() external override nonReentrant {
        bool requestWasAccepted = false;
        uint256 deadline = 0;

        if (status == Status.Active) {
            if (totalTickets == 0) revert NoTicketsSold();
            deadline = requestGraceDeadline();
        } else if (status == Status.Drawing) {
            requestWasAccepted = true;
            deadline = callbackDeadline();
        } else {
            revert InvalidStatus(status);
        }

        if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);

        uint256 grossRefundLiability = unsettledPot;
        unsettledPot = 0;
        remainingRefundLiability = grossRefundLiability;
        status = Status.Refunding;
        emit RefundsEnabled(msg.sender, requestWasAccepted, grossRefundLiability);
    }

    /// @inheritdoc IRaffle
    function redeemWinningTicket(address to) external override nonReentrant returns (uint256 cashAmount) {
        Status result = status;
        if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);
        if (to == address(0)) revert ZeroAddress();

        uint256 ticketId = winningTicketId;
        address owner = ownerOf(ticketId);
        if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner);

        _burn(ticketId);
        if (result == Status.NftWon) {
            prizeClaimed = true;
            prizeToken.safeTransferFrom(address(this), to, prizeTokenId);
        } else {
            cashAmount = winnerCashLiability;
            winnerCashLiability = 0;
            if (cashAmount != 0) _transferQuoteExact(to, cashAmount);
        }

        emit WinningTicketRedeemed(ticketId, owner, to, result, cashAmount);
    }

    /// @inheritdoc IRaffle
    function redeemRefundTickets(uint256[] calldata ticketIds, address to)
        external
        override
        nonReentrant
        returns (uint256 amount)
    {
        _requireStatus(Status.Refunding);
        if (to == address(0)) revert ZeroAddress();
        uint256 quantity = ticketIds.length;
        if (quantity == 0 || quantity > RaffleConstants.MAX_REFUND_REDEMPTION_BATCH_SIZE) {
            revert InvalidQuantity(quantity, RaffleConstants.MAX_REFUND_REDEMPTION_BATCH_SIZE);
        }

        for (uint256 index; index < quantity; ++index) {
            uint256 ticketId = ticketIds[index];
            address owner = ownerOf(ticketId);
            if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner);
            _burn(ticketId);
        }

        amount = ticketPrice * quantity;
        remainingRefundLiability -= amount;
        _transferQuoteExact(to, amount);
        emit RefundTicketsRedeemed(msg.sender, to, quantity, amount, remainingRefundLiability);
    }

    /// @inheritdoc IRaffle
    function recoverProtocolOwnedClaim(address raffle, ProtocolOwnedClaim claim, uint256[] calldata refundTicketIds)
        external
        override
        nonReentrant
        returns (uint256 amount)
    {
        if (!IRaffleFactory(factory).isRaffle(raffle)) revert UnsafeProtocolDestination(raffle);
        IRaffle target = IRaffle(raffle);
        address recipient = sponsorPrizeRecoveryRecipient;
        if (claim == ProtocolOwnedClaim.WinningTicket) {
            amount = target.redeemWinningTicket(recipient);
        } else if (claim == ProtocolOwnedClaim.RefundTickets) {
            amount = target.redeemRefundTickets(refundTicketIds, recipient);
        } else if (claim == ProtocolOwnedClaim.Quote) {
            amount = target.claimQuote(recipient);
        } else {
            target.claimSponsorPrize(recipient);
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
    function claimSponsorPrize(address to) external override nonReentrant {
        if (msg.sender != sponsorPrizeRecoveryRecipient) {
            revert OnlyPrizeRecoveryRecipient(msg.sender, sponsorPrizeRecoveryRecipient);
        }
        Status currentStatus = status;
        if (currentStatus != Status.CashWon && currentStatus != Status.Refunding && currentStatus != Status.Closed) {
            revert SponsorPrizeUnavailable(currentStatus);
        }
        if (to == address(0)) revert ZeroAddress();
        if (prizeClaimed) revert PrizeAlreadyClaimed();

        prizeClaimed = true;
        prizeToken.safeTransferFrom(address(this), to, prizeTokenId);
        emit SponsorPrizeClaimed(msg.sender, to, address(prizeToken), prizeTokenId);
    }

    /// @inheritdoc IRaffle
    function requestGraceDeadline() public view override returns (uint256 deadline) {
        deadline = endTime + RaffleConstants.DRAW_REQUEST_GRACE_PERIOD;
    }

    /// @inheritdoc IRaffle
    function callbackDeadline() public view override returns (uint256 deadline) {
        if (drawRequestedAt != 0) deadline = drawRequestedAt + RaffleConstants.DRAW_CALLBACK_TIMEOUT;
    }

    /// @inheritdoc IRaffle
    function winningTicketRedeemed() public view override returns (bool redeemed) {
        uint256 ticketId = winningTicketId;
        redeemed = ticketId != 0 && _ownerOf(ticketId) == address(0);
    }

    /// @inheritdoc IRaffle
    function accountedQuoteBalance() public view override returns (uint256 amount) {
        amount = unsettledPot + remainingRefundLiability + winnerCashLiability + totalClaimableQuote;
    }

    /**
     * @notice Returns the configured metadata URI for an existing unredeemed ticket.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory uri) {
        _requireOwned(tokenId);
        uri = raffleMetadataURI;
    }

    /**
     * @dev Prevents a bearer claim from being assigned to this raffle or another deterministically known protocol
     *      contract that has no method for initiating ticket redemption. OpenZeppelin safe transfers route through
     *      this virtual function before their receiver callback. Arbitrary third-party contracts remain the sender's
     *      responsibility because capability cannot be inferred reliably from deployed bytecode.
     */
    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (to != address(0) && _isKnownProtocolDestination(to)) revert UnsafeProtocolDestination(to);
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @notice Accepts only the exact configured prize deposited by the factory on behalf of the sponsor.
     * @dev Unsafe `transferFrom` can still force unrelated NFTs here without invoking this hook; they remain outside
     *      protocol accounting and intentionally have no administrator rescue path.
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

    /// @notice Rejects accidental direct native transfers; forced native currency remains outside protocol accounting.
    receive() external payable {
        revert DirectNativeTransfer();
    }

    /**
     * @dev Pyth authenticates its external wrapper. This handler never calls user or token contracts, and stale,
     *      duplicate, wrong-sequence, or request-in-flight callbacks are ignored rather than reverted.
     */
    function entropyCallback(uint64 sequence, address, bytes32 randomNumber) internal override {
        if (_requestInFlight || status != Status.Drawing || sequence != entropySequenceNumber) {
            emit EntropyCallbackIgnored(sequence, entropySequenceNumber, status);
            return;
        }

        uint256 resolvedTicketId = (uint256(randomNumber) % totalTickets) + 1;
        uint256 grossPot = unsettledPot;
        uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
        uint256 distributablePot = grossPot - protocolFee;
        uint256 winnerCashAmount = 0;
        uint256 sponsorCashAmount = 0;

        winningTicketId = resolvedTicketId;
        unsettledPot = 0;
        _creditQuote(protocolTreasury, protocolFee);

        if (totalTickets >= minimumTickets) {
            status = Status.NftWon;
            sponsorCashAmount = distributablePot;
        } else {
            status = Status.CashWon;
            winnerCashAmount = Math.mulDiv(distributablePot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS);
            winnerCashLiability = winnerCashAmount;
            sponsorCashAmount = distributablePot - winnerCashAmount;
        }
        _creditQuote(sponsor, sponsorCashAmount);

        emit RaffleResolved(sequence, resolvedTicketId, status, protocolFee, winnerCashAmount, sponsorCashAmount);
    }

    /// @dev Returns the immutable Pyth Entropy contract authenticated by IEntropyConsumer.
    function getEntropy() internal view override returns (address entropyAddress) {
        entropyAddress = address(entropy);
    }

    /// @dev Adds a normal sponsor or treasury pull claim while preserving the aggregate liability.
    function _creditQuote(address account, uint256 amount) internal {
        if (amount == 0) return;
        claimableQuote[account] += amount;
        totalClaimableQuote += amount;
    }

    /// @dev Clears a normal pull liability before making its exact-transfer ERC-20 interaction.
    function _claimQuote(address account, address to) internal returns (uint256 amount) {
        if (to == address(0)) revert ZeroAddress();
        amount = claimableQuote[account];
        if (amount == 0) revert NoQuoteClaim(account);

        claimableQuote[account] = 0;
        totalClaimableQuote -= amount;
        _transferQuoteExact(to, amount);
        emit QuoteClaimed(account, to, amount);
    }

    /**
     * @dev Requires the raffle debit and recipient credit to both equal the liability. Reverting restores all effects,
     *      including ticket burns and cleared claims, for fee-on-transfer or sender-tax behavior.
     */
    function _transferQuoteExact(address to, uint256 amount) internal {
        if (to == address(this)) revert InvalidQuoteDestination(to);
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

    /// @dev Enforces the single authoritative lifecycle value.
    function _requireStatus(Status expected) internal view {
        if (status != expected) revert InvalidStatus(status);
    }

    /// @dev Constructor-time defense against a new raffle owning either of its own fixed claims.
    function _isConstructorProtocolDestination(address destination, RaffleParams memory params)
        private
        view
        returns (bool unsafeDestination)
    {
        unsafeDestination = destination == address(this) || destination == params.factory
            || destination == params.quoteToken || destination == params.entropy || destination == params.prizeToken;
        if (!unsafeDestination && destination.code.length != 0) {
            unsafeDestination = IRaffleFactory(params.factory).isRaffle(destination);
        }
    }

    /// @dev Covers this raffle, its fixed dependencies, its factory, and already registered sibling raffles.
    function _isKnownProtocolDestination(address destination) private view returns (bool unsafeDestination) {
        unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
            || destination == address(entropy) || destination == address(prizeToken);
        if (!unsafeDestination && destination.code.length != 0) {
            unsafeDestination = IRaffleFactory(factory).isRaffle(destination);
        }
    }
}
