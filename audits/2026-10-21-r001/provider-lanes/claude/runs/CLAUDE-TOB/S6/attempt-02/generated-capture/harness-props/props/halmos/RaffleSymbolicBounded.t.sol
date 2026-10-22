// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

// GENERATED SCRATCH TEST CODE (S6 attempt-02): narrower-domain variants of the two Halmos checks that timed out in the
// full-domain run (60-halmos-symbolic). Entry counts are bounded to uint32 (2^32 values each), which keeps the 256-bit
// division reasoning tractable. Separately recorded experiment; bounded evidence, not a proof over uint128.
import { IRaffle } from "../../src/interfaces/IRaffle.sol";
import { RaffleSymbolicTest } from "./RaffleSymbolic.t.sol";

contract RaffleSymbolicBoundedTest is RaffleSymbolicTest {
    /// A-5 over every uint32 entry count: exact 5/95 or 5/80/15 split and full conservation.
    function check_split_exact_u32_entries(uint32 entries, bool reserveMet) public {
        vm.assume(entries > 0);
        IRaffle r = _create(reserveMet ? 1 : type(uint128).max);
        _buy(r, ALICE, entries);
        vm.warp(T0 + 7 days);
        _request(r);
        assert(_fulfill(r, 0));
        uint256 gross = uint256(entries) * PRICE;
        r.settleWinningTicket(1);
        uint256 fee = r.protocolFees();
        uint256 cash = r.winnerProceeds();
        assert(fee * 20 == gross);
        assert(reserveMet ? cash == 0 : cash * 5 == gross * 4);
        assert(fee + cash + r.sponsorProceeds() == gross);
        assert(r.unsettledPot() == 0 && usdc.balanceOf(address(r)) == gross);
    }

    /// A-4/A-7/T-4 over every pair of uint32 purchase sizes.
    function check_refund_conservation_u32(uint32 a, uint32 b) public {
        vm.assume(a > 0 && b > 0);
        IRaffle r = _create(1);
        _buy(r, ALICE, a);
        _buy(r, BOB, b);
        vm.warp(T0 + 9 days);
        r.enableRefunds();
        uint256[] memory one = new uint256[](1);
        one[0] = 1;
        vm.prank(ALICE);
        r.refundTickets(one);
        one[0] = 2;
        vm.prank(BOB);
        r.refundTickets(one);
        assert(usdc.balanceOf(ALICE) == uint256(a) * PRICE && usdc.balanceOf(BOB) == uint256(b) * PRICE);
        assert(r.remainingRefundLiability() == 0 && usdc.balanceOf(address(r)) == 0);
    }
}
