// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/**
 * @title raffle.fun Raffle Factory Interface
 * @author Heesho
 * @notice Defines creation, allowlist administration, and canonical raffle-registry reads.
 * @dev The production factory gates new raffles to owner-reviewed exact-transfer quote tokens. Removing a token affects
 *      only future creation and cannot alter an existing clone's immutable-by-convention configuration.
 * @custom:version 1.0.0
 */
interface IRaffleFactory {
    /**
     * @notice Parameters defining a new raffle's prize, economics, recovery destination, timing, and metadata.
     * @param prizeToken Standards-compliant ERC-721 collection containing the prize.
     * @param prizeTokenId Token ID deposited atomically as the prize.
     * @param quoteToken Factory-allowlisted exact-transfer ERC-20 used in raw token units.
     * @param sponsorPrizeRecoveryRecipient Fixed sponsor-side prize recovery recipient; zero defaults to the sponsor.
     * @param ticketPrice Gross raw quote-token units paid per ticket.
     * @param minimumTickets Threshold at which successful randomness awards the NFT rather than cash fallback.
     * @param startTime Inclusive sale start; zero normalizes to the creation timestamp.
     * @param endTime Exclusive sale end, bounded by the factory's maximum duration.
     * @param metadataURI Constrained metadata URI shared by the raffle and ticket NFTs.
     */
    struct CreateRaffleParams {
        address prizeToken;
        uint256 prizeTokenId;
        address quoteToken;
        address sponsorPrizeRecoveryRecipient;
        uint256 ticketPrice;
        uint256 minimumTickets;
        uint256 startTime;
        uint256 endTime;
        string metadataURI;
    }

    /// @notice Raised when a required address is zero.
    error ZeroAddress();
    /// @notice Raised when an address expected to contain runtime code does not.
    error NotContract(address account);
    /// @notice Raised when a prize contract does not affirm ERC-721 support through ERC-165.
    error UnsupportedPrizeToken(address prizeToken);
    /// @notice Raised when no production quote token is supplied at deployment.
    error NoInitialVerifiedQuoteTokens();
    /// @notice Raised when the bounded quote-token registry is full.
    error TooManyVerifiedQuoteTokens(uint256 maximum);
    /// @notice Raised when a quote token already has the requested allowlist status.
    error QuoteTokenVerificationUnchanged(address quoteToken, bool verified);
    /// @notice Raised when creation of new raffles is paused.
    error CreationPaused();
    /// @notice Raised when a new raffle uses a quote token outside the production allowlist.
    error QuoteTokenNotVerified(address quoteToken);
    /// @notice Raised when the raw ticket price is zero.
    error ZeroTicketPrice();
    /// @notice Raised when the NFT-award threshold is zero.
    error ZeroMinimumTickets();
    /// @notice Raised when the normalized start precedes the current block timestamp.
    error StartTimeInPast(uint256 startTime, uint256 currentTime);
    /// @notice Raised when a future start exceeds the protocol's bounded scheduling delay.
    error StartTimeTooDistant(uint256 startTime, uint256 maximumStartTime);
    /// @notice Raised when sale end does not follow sale start.
    error InvalidEndTime(uint256 startTime, uint256 endTime);
    /// @notice Raised when the configured sale window exceeds the protocol maximum.
    error SaleDurationTooLong(uint256 duration, uint256 maximumDuration);
    /// @notice Raised when metadata exceeds the protocol byte limit.
    error MetadataURITooLong(uint256 actualLength, uint256 maximumLength);
    /// @notice Raised when the Entropy callback gas limit is zero.
    error ZeroCallbackGasLimit();
    /// @notice Raised when the supported factory deposit flow does not leave the exact prize owned by the clone.
    error PrizeEscrowVerificationFailed(address raffle, address prizeToken, uint256 prizeTokenId);

    /**
     * @notice Emitted when a clone is created, registered, initialized, and funded in one reverting transaction.
     * @param raffleId Monotonic factory identifier.
     * @param raffle Deployed EIP-1167 clone.
     * @param sponsor Prize depositor and sponsor cash recipient.
     * @param sponsorPrizeRecoveryRecipient Immutable sponsor-side prize recovery destination.
     * @param prizeToken Escrowed ERC-721 contract.
     * @param prizeTokenId Escrowed token ID.
     * @param quoteToken Allowlisted payment token.
     * @param protocolTreasury Treasury captured by this clone.
     * @param ticketPrice Raw quote-token units per ticket.
     * @param minimumTickets NFT-award threshold.
     * @param startTime Inclusive sale start.
     * @param endTime Exclusive sale end.
     * @param requestGraceDeadline First timestamp at which a never-requested draw may be failed.
     * @param metadataURI Raffle and ticket metadata URI.
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

    /// @notice Emitted when a token's production-creation allowlist status changes.
    event QuoteTokenVerificationUpdated(address indexed quoteToken, bool previousVerified, bool newVerified);

    /// @notice Emitted when creation of future raffles is paused or resumed.
    event CreationPauseUpdated(bool previousPaused, bool newPaused);

    /// @notice Creates, initializes, registers, deposits, and verifies one raffle atomically.
    function createRaffle(CreateRaffleParams calldata params) external returns (address raffle);

    /// @notice Predicts a clone address for a reserved identity and prize.
    function predictRaffleAddress(
        uint256 raffleId,
        address sponsor,
        address quoteToken,
        address prizeToken,
        uint256 prizeTokenId
    ) external view returns (address predicted);

    /// @notice Changes the treasury captured only by future raffle clones.
    function setProtocolTreasury(address newTreasury) external;

    /// @notice Adds or removes a quote token from production creation for future raffles.
    function setQuoteTokenVerification(address quoteToken, bool verified) external;

    /// @notice Pauses or resumes creation without affecting existing clone lifecycles.
    function setCreationPaused(bool paused) external;

    /// @notice Returns the implementation whose bytecode is delegated to by canonical clones.
    function raffleImplementation() external view returns (address implementation);

    /// @notice Returns the Pyth Entropy v2 deployment captured by new clones.
    function entropy() external view returns (address entropyAddress);

    /// @notice Returns the callback gas limit captured by new clones.
    function callbackGasLimit() external view returns (uint32 gasLimit);

    /// @notice Returns whether a token is allowed for production raffle creation.
    function isVerifiedQuoteToken(address quoteToken) external view returns (bool verified);

    /// @notice Returns the stable number of tokens ever added to the bounded registry.
    function verifiedQuoteTokenCount() external view returns (uint256 count);

    /// @notice Returns a registry token at a stable zero-based index.
    function verifiedQuoteTokenAt(uint256 index) external view returns (address quoteToken);

    /// @notice Returns whether an address is a canonical clone created by this factory.
    function isRaffle(address raffle) external view returns (bool registered);

    /// @notice Returns the canonical raffle for a numeric identifier.
    function raffleById(uint256 raffleId) external view returns (address raffle);

    /// @notice Returns a canonical clone's identifier or zero for an unknown address.
    function idByRaffle(address raffle) external view returns (uint256 raffleId);
}
