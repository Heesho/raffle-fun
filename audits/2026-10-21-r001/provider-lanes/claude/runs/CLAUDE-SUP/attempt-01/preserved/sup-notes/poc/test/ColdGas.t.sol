// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Base } from "./Base.sol";
import { Raffle } from "raffle/Raffle.sol";

interface VmCool { function cool(address) external; }

contract ColdGasTest is Base {
    event CallbackGas(uint256 warm, uint256 cold);

    function test_callbackGasCold() public {
        Raffle r = _create(1, 5, uint64(T0 + 1 days));
        _buy(r, alice, 3);
        vm.warp(T0 + 1 days);
        _request(r);
        uint256 id = r.vrfRequestId();
        VmCool(address(vm)).cool(address(r));
        VmCool(address(vm)).cool(r.factory());
        VmCool(address(vm)).cool(address(factory.raffleImplementation()));
        require(wrapper.fulfillOne(id, 9), "cb");
        uint256 cold = wrapper.lastCallbackGasUsed();
        require(cold < 300_000, "under limit");
        emit CallbackGas(0, cold);
    }
}
