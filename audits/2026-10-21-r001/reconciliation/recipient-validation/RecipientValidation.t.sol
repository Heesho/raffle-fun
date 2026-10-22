// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;
import { Test } from "forge-std/Test.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { Raffle } from "../../../src/Raffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";
import { MockVRFV2PlusWrapper } from "../../../src/mocks/MockVRFV2PlusWrapper.sol";
contract RecipientValidation is Test {
 function testConfiguredFutureCloneRecipientCanStrandSponsorsOwnPrize() public {
  vm.warp(1800000000);
  MockERC20 q = new MockERC20();
  MockERC721 p = new MockERC721();
  MockVRFV2PlusWrapper w = new MockVRFV2PlusWrapper();
  RaffleFactory f = new RaffleFactory(address(q), address(w), address(0xCAFE));
  address sponsor = address(0xABCD);
  p.mint(sponsor, 1); p.mint(sponsor, 2);
  vm.prank(sponsor); p.setApprovalForAll(address(f), true);
  address future = vm.computeCreateAddress(address(f), 3);
  assertEq(future.code.length, 0);
  vm.startPrank(sponsor);
  Raffle a = Raffle(payable(f.createRaffle(IRaffleFactory.CreateRaffleParams({sponsorRecipient:future,prizeToken:address(p),prizeTokenId:1,reserveEntries:1,endTime:uint64(block.timestamp+7 days)}))));
  Raffle b = Raffle(payable(f.createRaffle(IRaffleFactory.CreateRaffleParams({sponsorRecipient:sponsor,prizeToken:address(p),prizeTokenId:2,reserveEntries:1,endTime:uint64(block.timestamp+7 days)}))));
  assertEq(address(b), future); assertTrue(f.isRaffle(future));
  a.enableRefunds();
  a.releaseSponsorPrize();
  assertEq(p.ownerOf(1), address(b)); assertTrue(a.prizeClaimed());
  // Normal completion of the recipient clone can release only its configured token2.
  b.enableRefunds(); b.releaseSponsorPrize();
  assertEq(p.ownerOf(2), sponsor); assertEq(p.ownerOf(1),address(b));
  assertEq(b.prizeTokenId(), 2);
  vm.stopPrank();
 }
}
