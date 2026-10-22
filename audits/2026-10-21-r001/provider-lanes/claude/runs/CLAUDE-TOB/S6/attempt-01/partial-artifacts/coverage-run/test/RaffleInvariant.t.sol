// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { FactoryDeployer } from "../src/FactoryDeployer.sol";
import { MockPrizeNFT } from "../src/mocks/MockPrizeNFT.sol";
import { MockUSDC } from "../src/mocks/MockUSDC.sol";
import { MockVRFV2PlusWrapper } from "../src/mocks/MockVRFV2PlusWrapper.sol";
import { RaffleHandler } from "../src/RaffleHandler.sol";
import { TestBase } from "./Vm.sol";

/// @notice Foundry invariant campaign over the shared handler (same model as the Echidna harness).
contract RaffleInvariantTest is TestBase {
    RaffleHandler internal handler;

    function _newHandler() internal returns (RaffleHandler) {
        return new RaffleHandler(new MockUSDC(), new MockVRFV2PlusWrapper(), new MockPrizeNFT(), new FactoryDeployer());
    }

    function setUp() public {
        handler = _newHandler();
        vm.deal(address(handler), 1_000_000 ether);
    }

    function targetContracts() public view returns (address[] memory targets) {
        targets = new address[](1);
        targets[0] = address(handler);
    }

    function invariant_noSpecViolation() public view {
        require(handler.violations() == 0, handler.lastViolation());
    }

    function invariant_globalProperties() public view {
        (bool ok, string memory why) = handler.checkInvariants();
        require(ok, why);
    }
}
