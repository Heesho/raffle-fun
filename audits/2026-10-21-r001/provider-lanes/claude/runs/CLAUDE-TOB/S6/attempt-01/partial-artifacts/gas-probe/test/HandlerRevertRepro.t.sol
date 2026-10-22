// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { FactoryDeployer } from "../src/FactoryDeployer.sol";
import { RaffleHandler } from "../src/RaffleHandler.sol";
import { MockPrizeNFT } from "../src/mocks/MockPrizeNFT.sol";
import { MockUSDC } from "../src/mocks/MockUSDC.sol";
import { MockVRFV2PlusWrapper } from "../src/mocks/MockVRFV2PlusWrapper.sol";

interface VmR {
    function warp(uint256) external;
    function deal(address, uint256) external;
    function expectRevert(bytes calldata) external;
}

/// @notice Reproduces the single handler revert seen in the Foundry invariant run (refund action, 1 of 13,603 calls):
///         `callerSeed + k` overflows in the harness's owner-targeting loop when callerSeed == type(uint256).max and the
///         first candidate ticket is already burned. Harness-only arithmetic; the protocol is not involved.
contract HandlerRevertReproTest {
    VmR constant vm = VmR(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function test_refundActionMaxSeedNoLongerReverts() public {
        RaffleHandler h = new RaffleHandler(new MockUSDC(), new MockVRFV2PlusWrapper(), new MockPrizeNFT(), new FactoryDeployer());
        vm.deal(address(h), 10 ether);
        h.buy(0, 0, 0, 0); // ticket 1 -> actor 0
        h.buy(0, 1, 1, 0); // ticket 2 -> actor 1
        vm.warp(block.timestamp + 6 days); // past endTime + 2 days, no draw requested
        h.enableRefunds(0, 2, false);
        h.refund(0, 1, 0, false); // callerSeed 1 -> owner of ts[1] (ticket 2) refunds it: ticket 2 burned
        require(h.burned(address(h.raffles(0)), 2), "ticket 2 burned");
        // max % 2 == 1 -> first candidate ts[1] is burned -> k = 1 -> (max + 1) overflows -> Panic(0x11)
        // Pre-fix this call reverted with Panic(0x11) (see step4/handler-revert-repro-prefix.txt); post-fix it must not.
        h.refund(0, type(uint256).max, 0, false);
        require(h.violations() == 0, "no spec violation involved");
    }
}
