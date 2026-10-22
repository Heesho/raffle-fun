// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract FoundryTest is Test {
    address constant USER1 = address(0x10000);

    // TODO: Replace with your actual contract instance
    RafflePropertiesHarness Target;

  function setUp() public {
      // TODO: Initialize your contract here
      Target = new RafflePropertiesHarness();
  }

  function test_replay() public {
        _setUpActor(USER1);
        Target.createRaffle(0, 1, 0);
        _setUpActor(USER1);
        Target.buy(0, 0, 0, 113526434078166817345300);
        _setUpActor(USER1);
        Target.fastDrawAndResolve(0, 0, 0, 0);
        _setUpActor(USER1);
        Target.redeem(0, 0, 1, false);
        vm.stopPrank();
        vm.prank(address(0x10000));
        assertFalse(Target.echidna_no_action_violations());
  }

  function _setUpActor(address actor) internal {
      vm.startPrank(actor);
      // Add any additional actor setup here if needed
  }

  function _delay(uint256 timeInSeconds, uint256 numBlocks) internal {
      vm.warp(block.timestamp + timeInSeconds);
      vm.roll(block.number + numBlocks);
  }

}
