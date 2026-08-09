// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/**
 * @title raffle.fun USDC Raffle Factory Interface
 * @author Heesho
 * @notice Defines constructor deployment and canonical registry reads for raffles using one factory-wide USDC token.
 * @dev The quote token, Entropy deployment, and callback gas limit are immutable. Factory ownership controls only the
 *      treasury captured by future raffles and whether new creation is paused; existing raffles remain autonomous.
 * @custom:version 2.0.0
 */
interface IRaffleFactory {
    /**
     * @notice Parameters defining a new raffle's prize, economics, recovery destination, timing, and metadata.
     * @param prizeToken Standards-compliant ERC-721 collection containing the prize.
     * @param prizeTokenId Token ID deposited atomically as the prize.
     * @param sponsorPrizeRecoveryRecipient Fixed sponsor-side NFT recovery recipient; zero defaults to the sponsor.
     * @param ticketPrice Gross raw USDC units paid per ticket.
     * @param minimumTickets Threshold at which successful randomness awards the NFT rather than cash fallback.
     * @param startTime Inclusive sale start; zero normalizes to the creation timestamp.
     * @param endTime Exclusive sale end, bounded by the factory's maximum duration.
     * @param metadataURI Constrained metadata URI shared by the raffle and ticket NFTs.
     */
    struct CreateRaffleParams {
        address prizeToken;
        uint256 prizeTokenId;
        address sponsorPrizeRecoveryRecipient;
        uint256 ticketPrice;
        uint256 minimumTickets;
        uint256 startTime;
        uint256 endTime;
        string metadataURI;
    }

    /// @notice Raised when the required owner or treasury is zero.
    error ZeroAddress();
    /// @notice Raised when a long-lived token or Entropy dependency is zero or has no deployed code.
    error NotContract(address account);
    /// @notice Raised when a proposed prize contract does not report ERC-721 support.
    error UnsupportedPrizeToken(address prizeToken);
    /// @notice Raised when creation is disabled for future raffles.
    error CreationPaused();
    /// @notice Raised when a raffle would sell free tickets.
    error ZeroTicketPrice();
    /// @notice Raised when a raffle has no reachable NFT-award threshold.
    error ZeroMinimumTickets();
    /// @notice Raised when a nonzero scheduled start precedes creation.
    error StartTimeInPast(uint256 startTime, uint256 currentTime);
    /// @notice Raised when a scheduled start exceeds the immutable custody bound.
    error StartTimeTooDistant(uint256 startTime, uint256 maximumStartTime);
    /// @notice Raised when the exclusive sale end does not follow the inclusive start.
    error InvalidEndTime(uint256 startTime, uint256 endTime);
    /// @notice Raised when the requested sale duration exceeds the immutable maximum.
    error SaleDurationTooLong(uint256 duration, uint256 maximumDuration);
    /// @notice Raised when metadata would make deployment unreasonably expensive.
    error MetadataURITooLong(uint256 actualLength, uint256 maximumLength);
    /// @notice Raised when Entropy callbacks would be requested with no gas allowance.
    error ZeroCallbackGasLimit();
    /// @notice Raised when a fixed claimant would be a known non-callable protocol address.
    error UnsafeProtocolDestination(address destination);
    /// @notice Raised when the post-deposit ownership or activation check fails.
    error PrizeEscrowVerificationFailed(address raffle, address prizeToken, uint256 prizeTokenId);

    /**
     * @notice Emitted after one constructor-deployed raffle is registered, funded, and verified atomically.
     */
    event RaffleCreated(
        uint256 indexed raffleId,
        address indexed raffle,
        address indexed sponsor,
        address sponsorPrizeRecoveryRecipient,
        address prizeToken,
        uint256 prizeTokenId,
        address quoteToken,
        address protocolTreasury,
        uint256 ticketPrice,
        uint256 minimumTickets,
        uint256 startTime,
        uint256 endTime,
        uint256 requestGraceDeadline,
        string metadataURI
    );

    /// @notice Emitted when the treasury captured only by future raffles changes.
    event ProtocolTreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
    /// @notice Emitted when creation of future raffles is paused or resumed.
    event CreationPauseUpdated(bool previousPaused, bool newPaused);

    /// @notice Deploys, registers, deposits, and verifies one raffle atomically.
    function createRaffle(CreateRaffleParams calldata params) external returns (address raffle);
    /// @notice Changes the treasury captured only by future raffles.
    function setProtocolTreasury(address newTreasury) external;
    /// @notice Pauses or resumes creation without affecting existing raffle lifecycles.
    function setCreationPaused(bool paused) external;

    /// @notice Returns the one immutable quote token shared by every registered raffle.
    function quoteToken() external view returns (address quoteTokenAddress);
    /// @notice Returns the immutable official Pyth Entropy v2 deployment.
    function entropy() external view returns (address entropyAddress);
    /// @notice Returns the immutable, measured Entropy callback gas limit.
    function callbackGasLimit() external view returns (uint32 gasLimit);
    /// @notice Returns whether an address is a successfully funded canonical raffle.
    function isRaffle(address raffle) external view returns (bool registered);
    /// @notice Returns the canonical raffle address for an assigned identifier.
    function raffleById(uint256 raffleId) external view returns (address raffle);
    /// @notice Returns a canonical raffle's identifier, or zero when unregistered.
    function idByRaffle(address raffle) external view returns (uint256 raffleId);
}
