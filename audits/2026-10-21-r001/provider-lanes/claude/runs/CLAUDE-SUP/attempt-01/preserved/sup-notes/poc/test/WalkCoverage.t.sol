// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { RandomWalkTest } from "./RandomWalk.t.sol";
import { IRaffle } from "raffle/interfaces/IRaffle.sol";

/// Re-runs the walk over fixed seeds and reports which lifecycle paths were exercised in-walk (pre-drain).
contract WalkCoverageTest is RandomWalkTest {
    uint256[6] internal inWalkStatus;
    uint256[6] internal terminal;
    uint256 internal inWalkRedeems;
    uint256 internal inWalkRefunds;
    uint256 internal inWalkSettles;

    event Coverage(uint256[6] inWalkStatusSeen, uint256[6] terminal, uint256 redeems, uint256 refunds, uint256 settles);

    function test_walkCoverage() public {
        for (uint256 s = 1; s <= 150; ++s) {
            seed = s;
            n = 0;
            paidIn = 0; paidOut = 0; donated = 0; paidWinner = 0; paidSponsor = 0; paidTreasury = 0;
            prizeId = uint256(keccak256(abi.encode(s, "cov")));
            r = _create(prizeId, uint128(1 + (s * 7) % 40), uint64(block.timestamp + 1 + (s * 7919) % 3 days));
            bool[6] memory seen;
            for (uint256 step; step < 60; ++step) {
                uint256 x = _r();
                uint256 pOut = paidOut;
                bool settledBefore = r.settlementComplete();
                bool redeemedBefore = r.winnerRedeemed();
                _act(x % 14, actors[(x >> 8) % actors.length], x >> 16);
                _check();
                seen[uint8(r.status())] = true;
                if (!redeemedBefore && r.winnerRedeemed()) inWalkRedeems++;
                if (!settledBefore && r.settlementComplete()) inWalkSettles++;
                if (r.status() == IRaffle.Status.Refunding && paidOut > pOut && x % 14 == 10) inWalkRefunds++;
            }
            for (uint256 k; k < 6; ++k) if (seen[k]) inWalkStatus[k]++;
            _drain();
            _check();
            terminal[uint8(r.status())]++;
            _eq(usdc.balanceOf(address(r)), donated, "drained");
            vm.warp(block.timestamp + 1 days);
        }
        emit Coverage(inWalkStatus, terminal, inWalkRedeems, inWalkRefunds, inWalkSettles);
    }
}
