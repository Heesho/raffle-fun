// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Script } from "forge-std/Script.sol";

import { Raffle } from "../src/Raffle.sol";
import { RaffleFactory } from "../src/RaffleFactory.sol";
import { RaffleLens } from "../src/RaffleLens.sol";

/// @title DeployRaffleFun
/// @notice Independent local/debug deployment that mirrors Ignition constructor inputs.
/// @dev Ignition remains the only production source of truth. This script deliberately
///      starts two-step ownership transfer but cannot impersonate the configured Safe.
contract DeployRaffleFun is Script {
    /// @notice Deploys implementation, factory, and lens and starts Safe ownership transfer.
    function run() external returns (Raffle implementation, RaffleFactory factory, RaffleLens lens) {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address[] memory verifiedQuoteTokens = vm.envAddress("VERIFIED_QUOTE_TOKENS", ",");
        address entropy = vm.envAddress("ENTROPY");
        address treasury = vm.envAddress("PROTOCOL_TREASURY");
        address finalOwner = vm.envAddress("FACTORY_OWNER");
        uint256 configuredCallbackGasLimit = vm.envOr("CALLBACK_GAS_LIMIT", uint256(300_000));
        require(configuredCallbackGasLimit <= type(uint32).max, "CALLBACK_GAS_LIMIT exceeds uint32");
        uint32 callbackGasLimit = uint32(configuredCallbackGasLimit);

        vm.startBroadcast(deployerKey);
        implementation = new Raffle();
        factory = new RaffleFactory(
            address(implementation), verifiedQuoteTokens, entropy, treasury, callbackGasLimit, vm.addr(deployerKey)
        );
        lens = new RaffleLens(address(factory));
        factory.transferOwnership(finalOwner);
        vm.stopBroadcast();
    }
}
