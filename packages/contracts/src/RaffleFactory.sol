// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {Raffle} from "./Raffle.sol";
import {IRaffle} from "./interfaces/IRaffle.sol";
import {IRaffleFactory} from "./interfaces/IRaffleFactory.sol";
import {RaffleConstants} from "./libraries/RaffleConstants.sol";

/**
 * @title raffle.fun Canonical USDC Raffle Factory
 * @author Heesho
 * @notice Constructor-deploys autonomous raffles that all use one immutable factory-wide USDC token.
 * @dev Ownership affects only future creation through treasury selection and creation pause. Each new Raffle is
 *      registered, funded with its exact prize, and verified in one reverting transaction. Existing raffles have no
 *      administrator, upgrade, token-policy change, or rescue path.
 * @custom:version 2.0.0
 */
contract RaffleFactory is IRaffleFactory, Ownable2Step, ReentrancyGuard {
    address public immutable override quoteToken;
    address public immutable override entropy;
    uint32 public immutable override callbackGasLimit;

    /// @notice Treasury captured only by raffles created after the latest update.
    address public protocolTreasury;
    /// @notice Number of constructor-deployed raffles successfully registered and funded.
    uint256 public raffleCount;
    /// @notice Creation pause that cannot affect any existing raffle.
    bool public creationPaused;

    mapping(uint256 raffleId => address raffle) public override raffleById;
    mapping(address raffle => uint256 raffleId) public override idByRaffle;
    mapping(address raffle => bool registered) public override isRaffle;

    /**
     * @notice Deploys a factory permanently bound to one production USDC and Entropy v2 deployment.
     * @param quoteToken_ Exact-transfer, non-rebasing USDC contract for this factory version.
     * @param entropy_ Official Pyth Entropy v2 deployment for the target chain.
     * @param protocolTreasury_ Initial protocol-fee recipient captured by new raffles.
     * @param callbackGasLimit_ Measured callback limit with an explicit safety margin.
     * @param initialOwner Two-step administrative owner for future-creation policy.
     */
    constructor(
        address quoteToken_,
        address entropy_,
        address protocolTreasury_,
        uint32 callbackGasLimit_,
        address initialOwner
    ) Ownable(initialOwner) {
        _requireContract(quoteToken_);
        _requireContract(entropy_);
        if (protocolTreasury_ == address(0) || initialOwner == address(0)) revert ZeroAddress();
        if (callbackGasLimit_ == 0) revert ZeroCallbackGasLimit();
        if (protocolTreasury_ == address(this) || protocolTreasury_ == quoteToken_ || protocolTreasury_ == entropy_) {
            revert UnsafeProtocolDestination(protocolTreasury_);
        }

        quoteToken = quoteToken_;
        entropy = entropy_;
        protocolTreasury = protocolTreasury_;
        callbackGasLimit = callbackGasLimit_;
    }

    /// @inheritdoc IRaffleFactory
    function createRaffle(CreateRaffleParams calldata params) external override nonReentrant returns (address raffle) {
        if (creationPaused) revert CreationPaused();
        _validateCreateParams(params);

        uint256 normalizedStartTime = params.startTime == 0 ? block.timestamp : params.startTime;
        if (normalizedStartTime < block.timestamp) {
            revert StartTimeInPast(normalizedStartTime, block.timestamp);
        }
        uint256 maximumStartTime = block.timestamp + RaffleConstants.MAX_START_DELAY;
        if (normalizedStartTime > maximumStartTime) {
            revert StartTimeTooDistant(normalizedStartTime, maximumStartTime);
        }
        if (params.endTime <= normalizedStartTime) revert InvalidEndTime(normalizedStartTime, params.endTime);
        uint256 saleDuration = params.endTime - normalizedStartTime;
        if (saleDuration > RaffleConstants.MAX_SALE_DURATION) {
            revert SaleDurationTooLong(saleDuration, RaffleConstants.MAX_SALE_DURATION);
        }

        address recoveryRecipient =
            params.sponsorPrizeRecoveryRecipient == address(0) ? msg.sender : params.sponsorPrizeRecoveryRecipient;
        uint256 raffleId = ++raffleCount;
        raffle = address(
            new Raffle(
                IRaffle.RaffleParams({
                    factory: address(this),
                    sponsor: msg.sender,
                    sponsorPrizeRecoveryRecipient: recoveryRecipient,
                    protocolTreasury: protocolTreasury,
                    quoteToken: quoteToken,
                    entropy: entropy,
                    prizeToken: params.prizeToken,
                    prizeTokenId: params.prizeTokenId,
                    raffleId: raffleId,
                    ticketPrice: params.ticketPrice,
                    minimumTickets: params.minimumTickets,
                    startTime: normalizedStartTime,
                    endTime: params.endTime,
                    callbackGasLimit: callbackGasLimit,
                    metadataURI: params.metadataURI
                })
            )
        );

        raffleById[raffleId] = raffle;
        idByRaffle[raffle] = raffleId;
        isRaffle[raffle] = true;
        _emitRaffleCreated(raffleId, raffle, recoveryRecipient, params, normalizedStartTime);

        IERC721(params.prizeToken).safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
        if (IERC721(params.prizeToken).ownerOf(params.prizeTokenId) != raffle) {
            revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
        }
        if (IRaffle(raffle).status() != IRaffle.Status.Active) {
            revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
        }
    }

    /// @inheritdoc IRaffleFactory
    function setProtocolTreasury(address newTreasury) external override onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        if (
            newTreasury == address(this) || newTreasury == quoteToken || newTreasury == entropy || isRaffle[newTreasury]
        ) {
            revert UnsafeProtocolDestination(newTreasury);
        }
        address previousTreasury = protocolTreasury;
        protocolTreasury = newTreasury;
        emit ProtocolTreasuryUpdated(previousTreasury, newTreasury);
    }

    /// @inheritdoc IRaffleFactory
    function setCreationPaused(bool paused) external override onlyOwner {
        bool previousPaused = creationPaused;
        creationPaused = paused;
        emit CreationPauseUpdated(previousPaused, paused);
    }

    /// @notice Disabled so the creation pause and treasury controls can never be stranded without an administrator.
    function renounceOwnership() public pure override {
        revert OwnershipRenunciationDisabled();
    }

    /// @dev Keeps the indexer-complete event out of the stack-heavy deployment function.
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
            quoteToken,
            protocolTreasury,
            params.ticketPrice,
            params.minimumTickets,
            normalizedStartTime,
            params.endTime,
            params.endTime + RaffleConstants.DRAW_REQUEST_GRACE_PERIOD,
            params.metadataURI
        );
    }

    /// @dev Validates only sponsor-controlled fields; factory-wide USDC and Entropy dependencies are immutable.
    function _validateCreateParams(CreateRaffleParams calldata params) internal view {
        _requireContract(params.prizeToken);
        bool supports721 = false;
        try IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
            supports721 = supported;
        } catch {
            revert UnsupportedPrizeToken(params.prizeToken);
        }
        if (!supports721) revert UnsupportedPrizeToken(params.prizeToken);
        if (params.ticketPrice == 0) revert ZeroTicketPrice();
        if (params.minimumTickets == 0) revert ZeroMinimumTickets();
        uint256 metadataLength = bytes(params.metadataURI).length;
        if (metadataLength > RaffleConstants.MAX_METADATA_URI_LENGTH) {
            revert MetadataURITooLong(metadataLength, RaffleConstants.MAX_METADATA_URI_LENGTH);
        }
    }

    /// @dev Rejects zero, EOAs, and constructor-only addresses for long-lived dependencies.
    function _requireContract(address account) internal view {
        if (account.code.length == 0) revert NotContract(account);
    }
}
