// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IRaffleFactory
/// @notice External interface for raffle creation and canonical registry reads.
interface IRaffleFactory {
    /// @notice Parameters that define immutable economics and timing for a new raffle.
    /// @param prizeToken ERC721 collection containing the escrowed prize.
    /// @param prizeTokenId Token ID deposited as the single prize.
    /// @param quoteToken Contract-backed ERC20 fixed for the lifetime of the raffle.
    /// @param ticketPrice Gross quote-token amount paid for each ticket.
    /// @param minimumTickets Threshold at which the winner receives the prize NFT.
    /// @param startTime First timestamp at which a purchase is accepted; zero means the current timestamp.
    /// @param endTime First timestamp at which purchases are no longer accepted.
    /// @param metadataURI Constrained metadata URI describing the raffle.
    struct CreateRaffleParams {
        address prizeToken;
        uint256 prizeTokenId;
        address quoteToken;
        uint256 ticketPrice;
        uint256 minimumTickets;
        uint256 startTime;
        uint256 endTime;
        string metadataURI;
    }

    /// @notice Raised when an address argument must not be zero.
    error ZeroAddress();
    /// @notice Raised when an address expected to be a contract has no runtime code.
    error NotContract(address account);
    /// @notice Raised when an NFT contract explicitly reports that it does not implement ERC721.
    error UnsupportedPrizeToken(address prizeToken);
    /// @notice Raised when no initially verified quote token is supplied to a factory deployment.
    error NoInitialVerifiedQuoteTokens();
    /// @notice Raised when adding another verified quote token would exceed the registry bound.
    error TooManyVerifiedQuoteTokens(uint256 maximum);
    /// @notice Raised when a quote token already has the requested verification status.
    error QuoteTokenVerificationUnchanged(address quoteToken, bool verified);
    /// @notice Raised when creation is disabled for new raffles.
    error CreationPaused();
    /// @notice Raised when the gross ticket price is zero.
    error ZeroTicketPrice();
    /// @notice Raised when the minimum ticket threshold is zero.
    error ZeroMinimumTickets();
    /// @notice Raised when the configured start timestamp is already in the past.
    error StartTimeInPast(uint256 startTime, uint256 currentTime);
    /// @notice Raised when the end timestamp does not follow the normalized start timestamp.
    error InvalidEndTime(uint256 startTime, uint256 endTime);
    /// @notice Raised when raffle metadata exceeds the documented byte limit.
    error MetadataURITooLong(uint256 actualLength, uint256 maximumLength);
    /// @notice Raised when the configured callback gas limit is zero.
    error ZeroCallbackGasLimit();

    /// @notice Emitted before prize transfer so dynamic indexers can observe clone events in the same block.
    /// @param raffleId Monotonic factory identifier.
    /// @param raffle Deployed EIP-1167 clone.
    /// @param sponsor Account depositing the prize.
    /// @param prizeToken Escrowed ERC721 contract.
    /// @param prizeTokenId Escrowed ERC721 token ID.
    /// @param quoteToken Gross payment token.
    /// @param protocolTreasury Treasury captured for this raffle.
    /// @param ticketPrice Gross price per ticket.
    /// @param minimumTickets Threshold for the NFT-awarded outcome.
    /// @param startTime Normalized purchase start timestamp.
    /// @param endTime Purchase end timestamp.
    /// @param metadataURI Raffle metadata URI.
    event RaffleCreated(
        uint256 indexed raffleId,
        address indexed raffle,
        address indexed sponsor,
        address prizeToken,
        uint256 prizeTokenId,
        address quoteToken,
        address protocolTreasury,
        uint256 ticketPrice,
        uint256 minimumTickets,
        uint256 startTime,
        uint256 endTime,
        string metadataURI
    );

    /// @notice Emitted when the treasury captured by future raffles changes.
    /// @param previousTreasury Former treasury.
    /// @param newTreasury Replacement treasury.
    event ProtocolTreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);

    /// @notice Emitted when a quote token's discovery verification changes.
    /// @param quoteToken ERC20 whose verification changed.
    /// @param previousVerified Previous verification status.
    /// @param newVerified New verification status.
    event QuoteTokenVerificationUpdated(address indexed quoteToken, bool previousVerified, bool newVerified);

    /// @notice Emitted when creation of future raffles is paused or resumed.
    /// @param previousPaused Previous creation state.
    /// @param newPaused New creation state.
    event CreationPauseUpdated(bool previousPaused, bool newPaused);

    /// @notice Creates, initializes, registers, and funds one raffle atomically.
    /// @param params Raffle configuration.
    /// @return raffle Newly created clone address.
    function createRaffle(CreateRaffleParams calldata params) external returns (address raffle);

    /// @notice Computes the deterministic clone address for a specific reserved identity.
    /// @param raffleId Factory identifier to include in the deployment salt.
    /// @param sponsor Sponsor included in the deployment salt.
    /// @param quoteToken Payment token included in the deployment salt.
    /// @param prizeToken Prize contract included in the deployment salt.
    /// @param prizeTokenId Prize ID included in the deployment salt.
    /// @return predicted Deterministic clone address.
    function predictRaffleAddress(
        uint256 raffleId,
        address sponsor,
        address quoteToken,
        address prizeToken,
        uint256 prizeTokenId
    ) external view returns (address predicted);

    /// @notice Returns whether a quote token is verified for official discovery surfaces.
    /// @param quoteToken Candidate ERC20.
    /// @return verified Current discovery verification status.
    function isVerifiedQuoteToken(address quoteToken) external view returns (bool verified);

    /// @notice Returns the number of quote tokens ever added to the verification registry.
    function verifiedQuoteTokenCount() external view returns (uint256 count);

    /// @notice Returns a known verification-registry token by stable index.
    /// @param index Zero-based registry index.
    function verifiedQuoteTokenAt(uint256 index) external view returns (address quoteToken);

    /// @notice Returns whether an address is a canonical clone from this factory.
    /// @param raffle Candidate clone address.
    /// @return registered Registry status.
    function isRaffle(address raffle) external view returns (bool registered);

    /// @notice Returns a canonical raffle by its numeric identifier.
    /// @param raffleId Factory identifier.
    /// @return raffle Canonical clone address.
    function raffleById(uint256 raffleId) external view returns (address raffle);

    /// @notice Returns the factory identifier for a canonical raffle, or zero for unknown addresses.
    /// @param raffle Candidate clone address.
    /// @return raffleId Factory identifier.
    function idByRaffle(address raffle) external view returns (uint256 raffleId);
}
