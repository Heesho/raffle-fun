// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IRaffle } from "../interfaces/IRaffle.sol";

/// @title ReentrantERC20
/// @notice Adversarial quote token that attempts a nested purchase during transferFrom.
contract ReentrantERC20 is ERC20 {
    /// @notice Target raffle for the nested call.
    address public target;
    /// @notice Whether the next transferFrom should attack.
    bool public attackEnabled;
    /// @notice Whether the nested purchase was rejected.
    bool public reentryBlocked;
    bool private attacking;

    /// @notice Creates the adversarial quote token.
    constructor() ERC20("Reentrant Token", "REENT") { }

    /// @notice Mints test balances.
    /// @param to Recipient.
    /// @param amount Amount.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Configures the next transferFrom reentry attempt.
    /// @param target_ Target raffle.
    function arm(address target_) external {
        target = target_;
        attackEnabled = true;
        reentryBlocked = false;
    }

    /// @notice Attempts reentry once before completing the exact requested transfer.
    function transferFrom(address from, address to, uint256 value) public override returns (bool success) {
        if (attackEnabled && !attacking) {
            attacking = true;
            (bool nestedSuccess,) = target.call(abi.encodeCall(IRaffle.buyTickets, (address(this), 1, address(0))));
            reentryBlocked = !nestedSuccess;
            attacking = false;
            attackEnabled = false;
        }
        success = super.transferFrom(from, to, value);
    }
}
