// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/**
 * @title raffle.fun Raffle Factory Interface
 * @author Heesho
 * @notice Defines atomic ERC-1167 raffle creation for one immutable USDC, treasury, and Chainlink configuration.
 * @dev The factory has no owner, pause, upgrade, rescue, or mutable protocol configuration.
 * @custom:version 1.0.0
 */
interface IRaffleFactory {
    struct CreateRaffleParams {
        address sponsorRecipient;
        address prizeToken;
        uint256 prizeTokenId;
        uint128 reserveEntries;
        uint64 endTime;
    }

    error ZeroAddress();
    error NotContract(address account);
    error UnsupportedQuoteToken(address quoteToken);
    error InvalidQuoteTokenDecimals(uint8 actualDecimals, uint8 requiredDecimals);
    error UnsupportedPrizeToken(address prizeToken);
    error ZeroReserveEntries();
    error InvalidEndTime(uint256 currentTime, uint256 endTime);
    error SaleDurationTooLong(uint256 duration, uint256 maximumDuration);
    error UnsafeProtocolDestination(address destination);
    error PrizeEscrowVerificationFailed(address raffle, address prizeToken, uint256 prizeTokenId);

    event RaffleCreated(
        uint256 indexed raffleId,
        address indexed raffle,
        address indexed sponsor,
        address sponsorRecipient,
        address prizeToken,
        uint256 prizeTokenId,
        address quoteToken,
        address protocolTreasury,
        uint128 reserveEntries,
        uint64 endTime
    );

    function createRaffle(CreateRaffleParams calldata params) external returns (address raffle);

    function quoteToken() external view returns (address quoteTokenAddress);
    function vrfWrapper() external view returns (address wrapperAddress);
    function protocolTreasury() external view returns (address treasuryAddress);
    function callbackGasLimit() external view returns (uint32 gasLimit);
    function requestConfirmations() external view returns (uint16 confirmations);
    function raffleImplementation() external view returns (address implementation);
    function isRaffle(address raffle) external view returns (bool registered);
    function raffleById(uint256 raffleId) external view returns (address raffle);
    function idByRaffle(address raffle) external view returns (uint256 raffleId);
}
