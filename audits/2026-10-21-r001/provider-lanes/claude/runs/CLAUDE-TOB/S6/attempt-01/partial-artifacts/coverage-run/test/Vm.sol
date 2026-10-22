// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @notice Minimal Foundry cheatcode interface (forge-std is not installed and there is no network access).
interface Vm {
    function warp(uint256) external;
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function deal(address, uint256) external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
    function expectRevert() external;
    function getNonce(address) external view returns (uint64);
    function label(address, string calldata) external;
    function assume(bool) external pure;
}

abstract contract TestBase {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function assertTrue(bool c, string memory why) internal pure {
        require(c, why);
    }

    function assertEq(uint256 a, uint256 b, string memory why) internal pure {
        if (a != b) revert(string.concat(why, " (", _u(a), " != ", _u(b), ")"));
    }

    function assertEq(address a, address b, string memory why) internal pure {
        require(a == b, why);
    }

    function _u(uint256 v) internal pure returns (string memory s) {
        if (v == 0) return "0";
        bytes memory b;
        while (v != 0) {
            b = abi.encodePacked(bytes1(uint8(48 + v % 10)), b);
            v /= 10;
        }
        s = string(b);
    }
}
