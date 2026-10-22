// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.36;

interface Vm {
    function warp(uint256 newTimestamp) external;
    function prank(address msgSender) external;
    function startPrank(address msgSender) external;
    function stopPrank() external;
    function deal(address account, uint256 newBalance) external;
    function expectRevert() external;
    function expectRevert(bytes4 revertData) external;
    function expectRevert(bytes calldata revertData) external;
    function expectPartialRevert(bytes4 revertData) external;
    function assume(bool condition) external;
}

abstract contract S6TestBase {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    error AssertionFailed(string message);
    error AssertionEqUint(string message, uint256 left, uint256 right);
    error AssertionEqAddress(string message, address left, address right);
    error AssertionEqBytes32(string message, bytes32 left, bytes32 right);

    function assertTrue(bool condition, string memory message) internal pure {
        if (!condition) revert AssertionFailed(message);
    }

    function assertFalse(bool condition, string memory message) internal pure {
        if (condition) revert AssertionFailed(message);
    }

    function assertEq(uint256 left, uint256 right, string memory message) internal pure {
        if (left != right) revert AssertionEqUint(message, left, right);
    }

    function assertEq(address left, address right, string memory message) internal pure {
        if (left != right) revert AssertionEqAddress(message, left, right);
    }

    function assertEq(bytes32 left, bytes32 right, string memory message) internal pure {
        if (left != right) revert AssertionEqBytes32(message, left, right);
    }
}
