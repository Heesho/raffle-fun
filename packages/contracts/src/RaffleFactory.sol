// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { IRaffle } from "./interfaces/IRaffle.sol";
import { IRaffleFactory } from "./interfaces/IRaffleFactory.sol";
import { RaffleConstants } from "./libraries/RaffleConstants.sol";

/**
 * @title raffle.fun Canonical Raffle Factory
 * @author Heesho
 * @notice Creates and registers non-upgradeable raffle clones and atomically deposits their exact configured prizes.
 * @dev Ownership administers only future creation: treasury selection, quote-token allowlisting, and creation pause.
 *      Existing clones have no administrator. The production allowlist is a custody safety gate, not merely discovery
 *      metadata; admitted tokens must be reviewed as non-rebasing exact-transfer ERC-20s in both directions.
 * @custom:version 1.0.0
 */
contract RaffleFactory is IRaffleFactory, Ownable2Step, ReentrancyGuard {
    using Strings for uint256;

    /// @notice Denominator used for all basis-point calculations.
    uint256 public constant BPS = RaffleConstants.BPS;
    /// @notice Fee charged only by successful verified-randomness resolution.
    uint256 public constant PROTOCOL_FEE_BPS = RaffleConstants.PROTOCOL_FEE_BPS;
    /// @notice Winner share of the post-fee cash-fallback pot.
    uint256 public constant CASH_WINNER_BPS = RaffleConstants.CASH_WINNER_BPS;
    /// @notice Maximum tickets minted by one purchase.
    uint256 public constant MAX_TICKETS_PER_PURCHASE = RaffleConstants.MAX_TICKETS_PER_PURCHASE;
    /// @notice Maximum refunds credited by one transaction.
    uint256 public constant MAX_REFUND_CREDIT_BATCH_SIZE = RaffleConstants.MAX_REFUND_CREDIT_BATCH_SIZE;
    /// @notice Maximum scheduling delay for a new raffle's start.
    uint256 public constant MAX_START_DELAY = RaffleConstants.MAX_START_DELAY;
    /// @notice Maximum ticket-sale duration for a new raffle.
    uint256 public constant MAX_SALE_DURATION = RaffleConstants.MAX_SALE_DURATION;
    /// @notice Fixed request grace period compiled into this factory version and its implementation.
    uint256 public constant DRAW_REQUEST_GRACE_PERIOD = RaffleConstants.DRAW_REQUEST_GRACE_PERIOD;
    /// @notice Fixed callback timeout compiled into this factory version and its implementation.
    uint256 public constant DRAW_CALLBACK_TIMEOUT = RaffleConstants.DRAW_CALLBACK_TIMEOUT;
    /// @notice Maximum unique tokens retained by the stable allowlist registry.
    uint256 public constant MAX_VERIFIED_QUOTE_TOKENS = 32;

    /// @inheritdoc IRaffleFactory
    address public immutable override entropy;
    /// @inheritdoc IRaffleFactory
    address public immutable override raffleImplementation;
    /// @inheritdoc IRaffleFactory
    uint32 public immutable override callbackGasLimit;

    /// @notice Treasury captured only by raffles created after the latest update.
    address public protocolTreasury;
    /// @notice Number of canonical clones successfully created and funded.
    uint256 public raffleCount;
    /// @notice Creation pause that cannot affect an existing clone.
    bool public creationPaused;

    /// @inheritdoc IRaffleFactory
    mapping(uint256 raffleId => address raffle) public override raffleById;
    /// @inheritdoc IRaffleFactory
    mapping(address raffle => uint256 raffleId) public override idByRaffle;
    /// @inheritdoc IRaffleFactory
    mapping(address raffle => bool registered) public override isRaffle;
    /// @inheritdoc IRaffleFactory
    mapping(address quoteToken => bool verified) public override isVerifiedQuoteToken;
    address[] private _verifiedQuoteTokens;
    mapping(address quoteToken => bool known) private _knownVerifiedQuoteToken;

    /**
     * @notice Deploys a factory permanently bound to one implementation, Entropy deployment, and callback gas limit.
     * @param raffleImplementation_ Locked Raffle implementation with initialization disabled.
     * @param initialVerifiedQuoteTokens Exact-transfer ERC-20s reviewed for production custody.
     * @param entropy_ Official Pyth Entropy v2 deployment for the target chain.
     * @param protocolTreasury_ Initial protocol-fee recipient.
     * @param callbackGasLimit_ Bounded gas supplied to the storage-only callback.
     * @param initialOwner Two-step administrative owner for future-creation policy.
     */
    constructor(
        address raffleImplementation_,
        address[] memory initialVerifiedQuoteTokens,
        address entropy_,
        address protocolTreasury_,
        uint32 callbackGasLimit_,
        address initialOwner
    ) Ownable(initialOwner) {
        _requireContract(raffleImplementation_);
        _requireContract(entropy_);
        if (protocolTreasury_ == address(0) || initialOwner == address(0)) revert ZeroAddress();
        if (callbackGasLimit_ == 0) revert ZeroCallbackGasLimit();
        if (initialVerifiedQuoteTokens.length == 0) revert NoInitialVerifiedQuoteTokens();

        raffleImplementation = raffleImplementation_;
        entropy = entropy_;
        protocolTreasury = protocolTreasury_;
        callbackGasLimit = callbackGasLimit_;

        for (uint256 index; index < initialVerifiedQuoteTokens.length; ++index) {
            address quoteToken = initialVerifiedQuoteTokens[index];
            if (!isVerifiedQuoteToken[quoteToken]) _setQuoteTokenVerification(quoteToken, true);
        }
    }

    /// @inheritdoc IRaffleFactory
    function createRaffle(CreateRaffleParams calldata params) external override nonReentrant returns (address raffle) {
        if (creationPaused) revert CreationPaused();
        _validateCreateParams(params);

        uint256 normalizedStartTime = params.startTime == 0 ? block.timestamp : params.startTime;
        if (normalizedStartTime < block.timestamp) {
            revert StartTimeInPast(normalizedStartTime, block.timestamp);
        }
        uint256 maximumStartTime = block.timestamp + MAX_START_DELAY;
        if (normalizedStartTime > maximumStartTime) {
            revert StartTimeTooDistant(normalizedStartTime, maximumStartTime);
        }
        if (params.endTime <= normalizedStartTime) revert InvalidEndTime(normalizedStartTime, params.endTime);
        uint256 saleDuration = params.endTime - normalizedStartTime;
        if (saleDuration > MAX_SALE_DURATION) revert SaleDurationTooLong(saleDuration, MAX_SALE_DURATION);

        address recoveryRecipient =
            params.sponsorPrizeRecoveryRecipient == address(0) ? msg.sender : params.sponsorPrizeRecoveryRecipient;
        uint256 raffleId = ++raffleCount;
        bytes32 salt = _raffleSalt(raffleId, msg.sender, params.quoteToken, params.prizeToken, params.prizeTokenId);
        raffle = Clones.cloneDeterministic(raffleImplementation, salt);

        IRaffle(raffle).initialize(
            IRaffle.InitializeParams({
                factory: address(this),
                sponsor: msg.sender,
                sponsorPrizeRecoveryRecipient: recoveryRecipient,
                protocolTreasury: protocolTreasury,
                quoteToken: params.quoteToken,
                entropy: entropy,
                prizeToken: params.prizeToken,
                prizeTokenId: params.prizeTokenId,
                raffleId: raffleId,
                ticketPrice: params.ticketPrice,
                minimumTickets: params.minimumTickets,
                startTime: normalizedStartTime,
                endTime: params.endTime,
                callbackGasLimit: callbackGasLimit,
                name: string.concat("Raffle Fun Ticket #", raffleId.toString()),
                symbol: string.concat("RFT-", raffleId.toString()),
                metadataURI: params.metadataURI
            })
        );

        raffleById[raffleId] = raffle;
        idByRaffle[raffle] = raffleId;
        isRaffle[raffle] = true;
        _emitRaffleCreated(raffleId, raffle, recoveryRecipient, params, normalizedStartTime);

        IERC721(params.prizeToken).safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
        _verifyPrizeEscrow(raffle, params.prizeToken, params.prizeTokenId);
    }

    /// @inheritdoc IRaffleFactory
    function predictRaffleAddress(
        uint256 raffleId,
        address sponsor,
        address quoteToken,
        address prizeToken,
        uint256 prizeTokenId
    ) external view override returns (address predicted) {
        bytes32 salt = _raffleSalt(raffleId, sponsor, quoteToken, prizeToken, prizeTokenId);
        predicted = Clones.predictDeterministicAddress(raffleImplementation, salt, address(this));
    }

    /// @inheritdoc IRaffleFactory
    function verifiedQuoteTokenCount() external view override returns (uint256 count) {
        count = _verifiedQuoteTokens.length;
    }

    /// @inheritdoc IRaffleFactory
    function verifiedQuoteTokenAt(uint256 index) external view override returns (address quoteToken) {
        quoteToken = _verifiedQuoteTokens[index];
    }

    /// @inheritdoc IRaffleFactory
    function setProtocolTreasury(address newTreasury) external override onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        address previousTreasury = protocolTreasury;
        protocolTreasury = newTreasury;
        emit ProtocolTreasuryUpdated(previousTreasury, newTreasury);
    }

    /// @inheritdoc IRaffleFactory
    function setQuoteTokenVerification(address quoteToken, bool verified) external override onlyOwner {
        if (isVerifiedQuoteToken[quoteToken] == verified) {
            revert QuoteTokenVerificationUnchanged(quoteToken, verified);
        }
        _setQuoteTokenVerification(quoteToken, verified);
    }

    /// @inheritdoc IRaffleFactory
    function setCreationPaused(bool paused) external override onlyOwner {
        bool previousPaused = creationPaused;
        creationPaused = paused;
        emit CreationPauseUpdated(previousPaused, paused);
    }

    /// @dev Keeps the indexer-complete event out of the already stack-heavy atomic creation function.
    function _emitRaffleCreated(
        uint256 raffleId,
        address raffle,
        address recoveryRecipient,
        CreateRaffleParams calldata params,
        uint256 normalizedStartTime
    ) internal {
        emit RaffleCreated(
            raffleId,
            raffle,
            msg.sender,
            recoveryRecipient,
            params.prizeToken,
            params.prizeTokenId,
            params.quoteToken,
            protocolTreasury,
            params.ticketPrice,
            params.minimumTickets,
            normalizedStartTime,
            params.endTime,
            params.endTime + DRAW_REQUEST_GRACE_PERIOD,
            params.metadataURI
        );
    }

    /// @dev CREATE2 identity commits to chain, factory sequence, sponsor, payment token, and exact prize.
    function _raffleSalt(
        uint256 raffleId,
        address sponsor,
        address quoteToken,
        address prizeToken,
        uint256 prizeTokenId
    ) internal view returns (bytes32 salt) {
        salt = keccak256(abi.encode(block.chainid, raffleId, sponsor, quoteToken, prizeToken, prizeTokenId));
    }

    /// @dev Enforces the production quote-token gate and strict standards-compliant ERC-721 support envelope.
    function _validateCreateParams(CreateRaffleParams calldata params) internal view {
        _requireContract(params.prizeToken);
        _requireContract(params.quoteToken);
        if (!isVerifiedQuoteToken[params.quoteToken]) revert QuoteTokenNotVerified(params.quoteToken);
        if (params.ticketPrice == 0) revert ZeroTicketPrice();
        if (params.minimumTickets == 0) revert ZeroMinimumTickets();
        uint256 metadataLength = bytes(params.metadataURI).length;
        if (metadataLength > RaffleConstants.MAX_METADATA_URI_LENGTH) {
            revert MetadataURITooLong(metadataLength, RaffleConstants.MAX_METADATA_URI_LENGTH);
        }

        try IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
            if (!supported) revert UnsupportedPrizeToken(params.prizeToken);
        } catch {
            revert UnsupportedPrizeToken(params.prizeToken);
        }
    }

    /// @dev A successful receiver callback is insufficient: honest ERC-721 ownership must also report the clone.
    function _verifyPrizeEscrow(address raffle, address prizeToken, uint256 prizeTokenId) internal view {
        if (IRaffle(raffle).state() != IRaffle.RaffleState.Active) {
            revert PrizeEscrowVerificationFailed(raffle, prizeToken, prizeTokenId);
        }
        try IERC721(prizeToken).ownerOf(prizeTokenId) returns (address owner) {
            if (owner != raffle) revert PrizeEscrowVerificationFailed(raffle, prizeToken, prizeTokenId);
        } catch {
            revert PrizeEscrowVerificationFailed(raffle, prizeToken, prizeTokenId);
        }
    }

    /// @dev Protocol dependencies must contain runtime code when configured or admitted.
    function _requireContract(address account) internal view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert NotContract(account);
    }

    /// @dev Registry indices remain stable when tokens are removed and later re-admitted.
    function _setQuoteTokenVerification(address quoteToken, bool verified) internal {
        if (verified) {
            _requireContract(quoteToken);
            if (!_knownVerifiedQuoteToken[quoteToken]) {
                if (_verifiedQuoteTokens.length == MAX_VERIFIED_QUOTE_TOKENS) {
                    revert TooManyVerifiedQuoteTokens(MAX_VERIFIED_QUOTE_TOKENS);
                }
                _knownVerifiedQuoteToken[quoteToken] = true;
                _verifiedQuoteTokens.push(quoteToken);
            }
        }
        bool previousVerified = isVerifiedQuoteToken[quoteToken];
        isVerifiedQuoteToken[quoteToken] = verified;
        emit QuoteTokenVerificationUpdated(quoteToken, previousVerified, verified);
    }
}
