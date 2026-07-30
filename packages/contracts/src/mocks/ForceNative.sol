// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title ForceNative
/// @notice Adversarial helper that bypasses receive-function policy through SELFDESTRUCT balance delivery.
contract ForceNative {
    /// @notice Funds the helper before forced delivery.
    constructor() payable { }

    /// @notice Forces the helper's full native balance into a target.
    /// @param target Target that may reject ordinary transfers.
    function force(address payable target) external {
        selfdestruct(target);
    }
}
