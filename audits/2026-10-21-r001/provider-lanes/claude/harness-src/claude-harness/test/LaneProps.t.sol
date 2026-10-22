// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { LaneHalmosTest } from "./LaneHalmos.t.sol";

/// Concrete-fuzz drivers for the symbolic checks (used as the fast mutation-kill suite). These are NOT proofs.
contract LanePropsFuzz is LaneHalmosTest {
    function testFuzz_settlementSplit(uint128 n, uint128 reserve) public { n = uint128(bound(n, 1, 1e15)); reserve = uint128(bound(reserve, 1, type(uint128).max)); check_settlementSplit(n, reserve); }
    function testFuzz_winnerInRange(uint128 a, uint128 b, uint256 w) public { a = uint128(bound(a, 1, 1e9)); b = uint128(bound(b, 1, 1e9)); check_winnerInRange(a, b, w); }
    function testFuzz_refundExact(uint128 a, uint128 b) public { a = uint128(bound(a, 1, 1e12)); b = uint128(bound(b, 1, 1e12)); check_refundExact(a, b); }
    function testFuzz_requestDrawWindow(uint64 dt) public { dt = uint64(bound(dt, 0, 5 days)); check_requestDrawWindow(dt); }
    function test_requestDrawWindowEdges() public { check_requestDrawWindow(1 days - 1); check_requestDrawWindow(1 days); check_requestDrawWindow(3 days - 1); check_requestDrawWindow(3 days); }
    function testFuzz_callbackDeadline(uint64 dt, uint256 w) public { dt = uint64(bound(dt, 0, 4 days)); check_callbackDeadline(dt, w); }
    function test_callbackDeadlineEdges() public { check_callbackDeadline(2 days - 1, 7); check_callbackDeadline(2 days, 7); }
    function testFuzz_enableRefundsFromDrawing(uint64 dt, address c) public { dt = uint64(bound(dt, 0, 4 days)); check_enableRefundsFromDrawing(dt, c); }
    function test_enableRefundsEdges() public { check_enableRefundsFromDrawing(2 days - 1, address(1)); check_enableRefundsFromDrawing(2 days, address(1)); }
    function testFuzz_initializeOnlyFactory(address c) public { check_initializeOnlyFactory(c); }
    function testFuzz_fulfillOnlyWrapper(address c, uint256 w) public { vm.assume(c != address(0)); check_fulfillOnlyWrapper(c, w); }
    function testFuzz_sponsorPrizeLocked(address c, uint256 w) public { check_sponsorPrizeLocked(c, w); }
    function testFuzz_redeemOnlyOwner(address c, uint256 w) public { vm.assume(c != address(0x0A11CE)); check_redeemOnlyOwner(c, w); }
}
