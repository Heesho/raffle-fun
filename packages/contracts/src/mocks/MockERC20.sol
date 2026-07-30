// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockERC20
/// @notice Six-decimal exact-transfer quote token for local and test environments.
contract MockERC20 is ERC20 {
    /// @notice Creates a mock token named Mock USDC.
    constructor() ERC20("Mock USDC", "mUSDC") { }

    /// @notice Returns USDC-compatible decimal precision.
    /// @return decimals_ Six decimal places.
    function decimals() public pure override returns (uint8 decimals_) {
        decimals_ = 6;
    }

    /// @notice Mints test balances without production authorization semantics.
    /// @param to Recipient.
    /// @param amount Raw six-decimal amount.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
