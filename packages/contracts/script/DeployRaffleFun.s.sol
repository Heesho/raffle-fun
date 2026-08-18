// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Script } from "forge-std/Script.sol";

import { RaffleFactory } from "../src/RaffleFactory.sol";

/// @title DeployRaffleFun
/// @notice Independent local/debug deployment that mirrors Ignition constructor inputs.
/// @dev Ignition remains the only production source of truth. This script deliberately
///      starts two-step ownership transfer but cannot impersonate the configured Safe.
contract DeployRaffleFun is Script {
    /// @notice Deploys the single-USDC factory and starts Safe ownership transfer.
    function run() external returns (RaffleFactory factory) {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address quoteToken = vm.envAddress("QUOTE_TOKEN");
        address vrfWrapper = vm.envAddress("VRF_WRAPPER");
        address treasury = vm.envAddress("PROTOCOL_TREASURY");
        address finalOwner = vm.envAddress("FACTORY_OWNER");

        vm.startBroadcast(deployerKey);
        factory = new RaffleFactory(quoteToken, vrfWrapper, treasury, vm.addr(deployerKey));
        factory.transferOwnership(finalOwner);
        vm.stopBroadcast();
    }
}
