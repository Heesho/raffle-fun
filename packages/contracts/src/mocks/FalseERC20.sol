// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title FalseERC20
/// @notice Adversarial ERC20 that returns false instead of transferring.
contract FalseERC20 is IERC20 {
    function decimals() external pure returns (uint8) {
        return 6;
    }

    /// @inheritdoc IERC20
    uint256 public override totalSupply;
    /// @inheritdoc IERC20
    mapping(address account => uint256 amount) public override balanceOf;
    /// @inheritdoc IERC20
    mapping(address owner => mapping(address spender => uint256 amount)) public override allowance;

    /// @notice Mints test balances.
    /// @param to Recipient.
    /// @param amount Amount.
    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    /// @inheritdoc IERC20
    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @inheritdoc IERC20
    function transfer(address, uint256) external pure override returns (bool) {
        return false;
    }

    /// @inheritdoc IERC20
    function transferFrom(address, address, uint256) external pure override returns (bool) {
        return false;
    }
}
