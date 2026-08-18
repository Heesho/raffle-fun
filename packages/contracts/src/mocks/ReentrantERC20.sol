// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IRaffle } from "../interfaces/IRaffle.sol";

/// @title ReentrantERC20
/// @notice Adversarial quote token that attempts nested protocol calls during inbound and outbound transfers.
contract ReentrantERC20 is ERC20 {
    /// @notice Target raffle for the nested call.
    address public target;
    /// @notice Whether the next transferFrom should attack.
    bool public attackEnabled;
    /// @notice Whether the nested purchase was rejected.
    bool public reentryBlocked;
    bool private attacking;
    bool public attackOutbound;

    /// @notice Creates the adversarial quote token.
    constructor() ERC20("Reentrant Token", "REENT") { }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

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

    /// @notice Configures the next outbound transfer to attack settlement.
    function armOutbound(address target_) external {
        target = target_;
        attackOutbound = true;
        reentryBlocked = false;
    }

    /// @notice Attempts reentry once before completing the exact requested transfer.
    function transferFrom(address from, address to, uint256 value) public override returns (bool success) {
        if (attackEnabled && !attacking) {
            attacking = true;
            (bool nestedSuccess,) = target.call(abi.encodeCall(IRaffle.buyEntries, (address(this), uint128(1))));
            reentryBlocked = !nestedSuccess;
            attacking = false;
            attackEnabled = false;
        }
        success = super.transferFrom(from, to, value);
    }

    function transfer(address to, uint256 value) public override returns (bool success) {
        if (attackOutbound && !attacking) {
            attacking = true;
            (bool nestedSuccess,) = target.call(abi.encodeCall(IRaffle.releaseProtocolFees, ()));
            reentryBlocked = !nestedSuccess;
            attacking = false;
            attackOutbound = false;
        }
        success = super.transfer(to, value);
    }
}
