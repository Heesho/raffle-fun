// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { RaffleFactory } from "raffle/RaffleFactory.sol";

/// @notice Keeps the factory+implementation creation code out of the handler's initcode (EIP-3860 limit in Echidna).
contract FactoryDeployer {
    function deploy(address usdc, address wrapper, address treasury) external returns (RaffleFactory factory) {
        factory = new RaffleFactory(usdc, wrapper, treasury);
    }
}
