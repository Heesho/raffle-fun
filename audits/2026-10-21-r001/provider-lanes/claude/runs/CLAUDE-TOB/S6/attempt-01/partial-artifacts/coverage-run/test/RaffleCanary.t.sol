// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { FactoryDeployer } from "../src/FactoryDeployer.sol";
import { MockPrizeNFT } from "../src/mocks/MockPrizeNFT.sol";
import { MockUSDC } from "../src/mocks/MockUSDC.sol";
import { MockVRFV2PlusWrapper } from "../src/mocks/MockVRFV2PlusWrapper.sol";
import { RaffleHandler } from "../src/RaffleHandler.sol";
import { TestBase } from "./Vm.sol";

/// @notice Reachability canaries. Each invariant is EXPECTED TO FAIL: a counterexample proves the fuzzer reaches that
///         deep state, so the passing properties in RaffleInvariantTest are not vacuous.
contract RaffleCanaryTest is TestBase {
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

    function invariant_canary_resolveNft() public view { require(handler.hits(bytes32("resolveNft")) == 0, "REACHED resolveNft"); }
    function invariant_canary_resolveCash() public view { require(handler.hits(bytes32("resolveCash")) == 0, "REACHED resolveCash"); }
    function invariant_canary_redeemNft() public view { require(handler.hits(bytes32("redeemNft")) == 0, "REACHED redeemNft"); }
    function invariant_canary_redeemCash() public view { require(handler.hits(bytes32("redeemCash")) == 0, "REACHED redeemCash"); }
    function invariant_canary_settle() public view { require(handler.hits(bytes32("settle")) == 0, "REACHED settle"); }
    function invariant_canary_refund() public view { require(handler.hits(bytes32("refund")) == 0, "REACHED refund"); }
    function invariant_canary_refundsAfterDrawing() public view { require(handler.hits(bytes32("refundsAfterDrawing")) == 0, "REACHED refundsAfterDrawing"); }
    function invariant_canary_fulfillIgnored() public view { require(handler.hits(bytes32("fulfillIgnored")) == 0, "REACHED fulfillIgnored"); }
    function invariant_canary_sponsorEarlyCancel() public view { require(handler.hits(bytes32("sponsorEarlyCancel")) == 0, "REACHED sponsorEarlyCancel"); }
    function invariant_canary_releasePrize() public view { require(handler.hits(bytes32("releasePrize")) == 0, "REACHED releasePrize"); }
    function invariant_canary_releaseFees() public view { require(handler.hits(bytes32("releaseFees")) == 0, "REACHED releaseFees"); }
    function invariant_canary_releaseSponsor() public view { require(handler.hits(bytes32("releaseSponsor")) == 0, "REACHED releaseSponsor"); }
    function invariant_canary_refundsFromActiveTimeout() public view { require(handler.hits(bytes32("refundsFromActiveTimeout")) == 0, "REACHED refundsFromActiveTimeout"); }
    function invariant_canary_threeRaffles() public view { require(handler.hits(bytes32("createRaffle")) < 3, "REACHED 3 raffles"); }
}
