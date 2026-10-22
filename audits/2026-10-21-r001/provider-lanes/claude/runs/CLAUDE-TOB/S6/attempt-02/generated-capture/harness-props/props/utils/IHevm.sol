// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

// GENERATED SCRATCH TEST CODE (S6 attempt-02). Minimal cheatcode interface shared by Echidna, Medusa, Foundry and
// Halmos (all expose the hevm cheatcode address). forge-std is not part of the provided inputs, so it is not used.
interface IHevm {
    function warp(uint256 newTimestamp) external;
    function roll(uint256 newBlockNumber) external;
    function prank(address sender) external;
    function deal(address account, uint256 newBalance) external;
    function assume(bool condition) external;
    function expectRevert() external;
    function etch(address target, bytes calldata code) external;
}

address constant HEVM_ADDRESS = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
