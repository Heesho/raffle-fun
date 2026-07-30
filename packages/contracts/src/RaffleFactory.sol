// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

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

/// @title RaffleFactory
/// @notice Deploys and registers non-upgradeable raffle clones while administering only future creation policy.
contract RaffleFactory is IRaffleFactory, Ownable2Step, ReentrancyGuard {
    using Strings for uint256;

    /// @notice Denominator used for all basis-point calculations.
    uint256 public constant BPS = RaffleConstants.BPS;
    /// @notice Protocol fee allocated once against aggregate gross sales at resolution.
    uint256 public constant PROTOCOL_FEE_BPS = RaffleConstants.PROTOCOL_FEE_BPS;
    /// @notice Winner share of the distributable pot in the cash-fallback branch.
    uint256 public constant CASH_WINNER_BPS = RaffleConstants.CASH_WINNER_BPS;
    /// @notice Bounded ticket quantity minted by one purchase.
    uint256 public constant MAX_TICKETS_PER_PURCHASE = RaffleConstants.MAX_TICKETS_PER_PURCHASE;
    /// @notice Maximum number of unique quote tokens one factory can mark verified.
    uint256 public constant MAX_VERIFIED_QUOTE_TOKENS = 32;

    /// @notice Pyth Entropy v2 contract inherited by every clone.
    address public immutable entropy;
    /// @notice Locked implementation copied by every EIP-1167 clone.
    address public immutable raffleImplementation;
    /// @notice Entropy callback limit inherited by every clone.
    uint32 public immutable callbackGasLimit;

    /// @notice Treasury captured only by raffles created after an update.
    address public protocolTreasury;
    /// @notice Number of canonical raffle clones created by this factory.
    uint256 public raffleCount;
    /// @notice Creation pause that cannot affect existing clones.
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

    /// @notice Creates a versioned factory bound to one implementation and Entropy deployment.
    /// @param raffleImplementation_ Locked Raffle implementation with runtime code.
    /// @param initialVerifiedQuoteTokens ERC20s initially verified for official discovery.
    /// @param entropy_ Pyth Entropy v2 deployment.
    /// @param protocolTreasury_ Treasury captured by initial raffles.
    /// @param callbackGasLimit_ Per-raffle callback limit passed to Entropy.
    /// @param initialOwner Multisig or temporary deployment authority using two-step ownership transfers.
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

        for (uint256 i; i < initialVerifiedQuoteTokens.length; ++i) {
            address quoteToken_ = initialVerifiedQuoteTokens[i];
            if (!isVerifiedQuoteToken[quoteToken_]) _setQuoteTokenVerification(quoteToken_, true);
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
        if (params.endTime <= normalizedStartTime) {
            revert InvalidEndTime(normalizedStartTime, params.endTime);
        }

        uint256 raffleId = ++raffleCount;
        bytes32 salt = _raffleSalt(raffleId, msg.sender, params.quoteToken, params.prizeToken, params.prizeTokenId);
        raffle = Clones.cloneDeterministic(raffleImplementation, salt);

        IRaffle(raffle).initialize(
            IRaffle.InitializeParams({
                factory: address(this),
                sponsor: msg.sender,
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

        _emitRaffleCreated(raffleId, raffle, msg.sender, params, normalizedStartTime);

        IERC721(params.prizeToken).safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
    }

    /// @inheritdoc IRaffleFactory
    function predictRaffleAddress(
        uint256 raffleId,
        address sponsor,
        address quoteToken_,
        address prizeToken,
        uint256 prizeTokenId
    ) external view override returns (address predicted) {
        bytes32 salt = _raffleSalt(raffleId, sponsor, quoteToken_, prizeToken, prizeTokenId);
        predicted = Clones.predictDeterministicAddress(raffleImplementation, salt, address(this));
    }

    /// @inheritdoc IRaffleFactory
    function verifiedQuoteTokenCount() external view override returns (uint256 count) {
        count = _verifiedQuoteTokens.length;
    }

    /// @inheritdoc IRaffleFactory
    function verifiedQuoteTokenAt(uint256 index) external view override returns (address quoteToken_) {
        quoteToken_ = _verifiedQuoteTokens[index];
    }

    /// @notice Changes the treasury captured only by future raffle clones.
    /// @param newTreasury Nonzero replacement treasury.
    function setProtocolTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        address previousTreasury = protocolTreasury;
        protocolTreasury = newTreasury;
        emit ProtocolTreasuryUpdated(previousTreasury, newTreasury);
    }

    /// @notice Updates a quote token's official discovery verification without gating raffle creation.
    /// @param quoteToken_ ERC20 to update.
    /// @param verified New discovery verification status.
    function setQuoteTokenVerification(address quoteToken_, bool verified) external onlyOwner {
        if (isVerifiedQuoteToken[quoteToken_] == verified) {
            revert QuoteTokenVerificationUnchanged(quoteToken_, verified);
        }
        _setQuoteTokenVerification(quoteToken_, verified);
    }

    /// @notice Pauses or resumes only the creation of new raffles.
    /// @param paused New creation pause state.
    function setCreationPaused(bool paused) external onlyOwner {
        bool previousPaused = creationPaused;
        creationPaused = paused;
        emit CreationPauseUpdated(previousPaused, paused);
    }

    /// @dev Keeping the indexer-complete event in one helper avoids excessive creation-flow stack pressure.
    function _emitRaffleCreated(
        uint256 raffleId,
        address raffle,
        address sponsor,
        CreateRaffleParams calldata params,
        uint256 normalizedStartTime
    ) internal {
        emit RaffleCreated(
            raffleId,
            raffle,
            sponsor,
            params.prizeToken,
            params.prizeTokenId,
            params.quoteToken,
            protocolTreasury,
            params.ticketPrice,
            params.minimumTickets,
            normalizedStartTime,
            params.endTime,
            params.metadataURI
        );
    }

    /// @dev The deployment salt commits to identity and prize while the factory address namespaces CREATE2.
    function _raffleSalt(
        uint256 raffleId,
        address sponsor,
        address quoteToken_,
        address prizeToken,
        uint256 prizeTokenId
    ) internal view returns (bytes32) {
        return keccak256(abi.encode(block.chainid, raffleId, sponsor, quoteToken_, prizeToken, prizeTokenId));
    }

    /// @dev Explicit ERC165 rejections are respected, while legacy ERC721 contracts that revert are tolerated.
    function _validateCreateParams(CreateRaffleParams calldata params) internal view {
        _requireContract(params.prizeToken);
        _requireContract(params.quoteToken);
        if (params.ticketPrice == 0) revert ZeroTicketPrice();
        if (params.minimumTickets == 0) revert ZeroMinimumTickets();
        if (bytes(params.metadataURI).length > RaffleConstants.MAX_METADATA_URI_LENGTH) {
            revert MetadataURITooLong(bytes(params.metadataURI).length, RaffleConstants.MAX_METADATA_URI_LENGTH);
        }

        try IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
            if (!supported) revert UnsupportedPrizeToken(params.prizeToken);
        } catch {
            // Some established ERC721 deployments predate or incompletely implement ERC165.
        }
    }

    /// @dev Protocol dependencies must contain runtime code at factory deployment or raffle creation.
    function _requireContract(address account) internal view {
        if (account == address(0)) revert ZeroAddress();
        if (account.code.length == 0) revert NotContract(account);
    }

    /// @dev Known tokens retain a stable registry index across verification changes.
    function _setQuoteTokenVerification(address quoteToken_, bool verified) internal {
        if (verified) {
            _requireContract(quoteToken_);
            if (!_knownVerifiedQuoteToken[quoteToken_]) {
                if (_verifiedQuoteTokens.length == MAX_VERIFIED_QUOTE_TOKENS) {
                    revert TooManyVerifiedQuoteTokens(MAX_VERIFIED_QUOTE_TOKENS);
                }
                _knownVerifiedQuoteToken[quoteToken_] = true;
                _verifiedQuoteTokens.push(quoteToken_);
            }
        }
        bool previousVerified = isVerifiedQuoteToken[quoteToken_];
        isVerifiedQuoteToken[quoteToken_] = verified;
        emit QuoteTokenVerificationUpdated(quoteToken_, previousVerified, verified);
    }
}
