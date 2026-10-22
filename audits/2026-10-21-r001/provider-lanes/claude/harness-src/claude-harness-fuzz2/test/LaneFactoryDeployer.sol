// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;
import { RaffleFactory } from "../src/RaffleFactory.sol";
/// Echidna-only helper: predeployed via echidna.yaml `deployContracts` so the property contract's initcode
/// stays under the EIP-3860 limit. Deploys the unmodified RaffleFactory at runtime.
contract LaneFactoryDeployer {
    function deploy(address usdc, address wrapper, address treasury) external returns (RaffleFactory f) {
        f = new RaffleFactory(usdc, wrapper, treasury);
    }
}
