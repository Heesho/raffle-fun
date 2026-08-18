// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { Raffle } from "./Raffle.sol";
import { IRaffle } from "./interfaces/IRaffle.sol";
import { IRaffleFactory } from "./interfaces/IRaffleFactory.sol";
import { RaffleConstants } from "./libraries/RaffleConstants.sol";

/**
 * @title raffle.fun Canonical USDC Raffle Factory
 * @author Heesho
 * @notice Atomically creates, funds, and registers autonomous fixed-implementation raffle clones.
 * @dev The implementation, six-decimal quote token, treasury, fee, and Chainlink configuration are immutable. Factory
 *      ownership controls only whether future raffles may be created and has no authority over existing clones.
 * @custom:version 1.0.0
 */
contract RaffleFactory is IRaffleFactory, Ownable2Step, ReentrancyGuard {
    address public immutable override quoteToken;
    address public immutable override vrfWrapper;
    address public immutable override protocolTreasury;
    uint32 public constant override callbackGasLimit = RaffleConstants.VRF_CALLBACK_GAS_LIMIT;
    uint16 public constant override requestConfirmations = RaffleConstants.VRF_REQUEST_CONFIRMATIONS;
    address public immutable override raffleImplementation;

    uint256 public raffleCount;
    bool public creationPaused;

    mapping(uint256 raffleId => address raffle) public override raffleById;
    mapping(address raffle => uint256 raffleId) public override idByRaffle;
    mapping(address raffle => bool registered) public override isRaffle;

    /**
     * @param quoteToken_ Official-style exact-transfer six-decimal quote token used by every raffle.
     * @param vrfWrapper_ Official Chainlink VRF v2.5 native direct-funding wrapper for the target chain.
     * @param protocolTreasury_ Immutable protocol-fee recipient used by every raffle.
     * @param initialOwner Two-step owner able to pause only future raffle creation.
     */
    constructor(address quoteToken_, address vrfWrapper_, address protocolTreasury_, address initialOwner)
        Ownable(initialOwner)
    {
        _requireContract(quoteToken_);
        _requireContract(vrfWrapper_);
        if (protocolTreasury_ == address(0) || initialOwner == address(0)) revert ZeroAddress();

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

    /// @inheritdoc IRaffleFactory
    function createRaffle(CreateRaffleParams calldata params) external override nonReentrant returns (address raffle) {
        if (creationPaused) revert CreationPaused();
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

        IERC721(params.prizeToken).safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
        if (IERC721(params.prizeToken).ownerOf(params.prizeTokenId) != raffle) {
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

    /// @inheritdoc IRaffleFactory
    function setCreationPaused(bool paused) external override onlyOwner {
        bool previousPaused = creationPaused;
        creationPaused = paused;
        emit CreationPauseUpdated(previousPaused, paused);
    }

    /// @notice Disabled so the future-creation pause cannot be permanently stranded without an administrator.
    function renounceOwnership() public pure override {
        revert OwnershipRenunciationDisabled();
    }

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

    function _requireContract(address account) private view {
        if (account.code.length == 0) revert NotContract(account);
    }
}
