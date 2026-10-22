// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

// Lane gap tests added after the first mutation pass (survivors M01, M19, M21). Concrete regression controls,
// not proofs.

import { LaneHalmosTest } from "./LaneHalmos.t.sol";
import { Raffle } from "../src/Raffle.sol";
import { RaffleFactory } from "../src/RaffleFactory.sol";
import { IRaffle } from "../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../src/interfaces/IRaffleFactory.sol";
import { LaneUSDC, LanePrize, IRawFulfill } from "./mocks/LaneMocks.sol";

/// Wrapper that tries to fulfill synchronously inside the request (models a misbehaving or upgraded wrapper).
contract SyncCallbackWrapper {
    uint256 public fee = 0.001 ether;
    uint256 public lastRequestId;
    address public link = address(0x1111);

    function calculateRequestPriceNative(uint32, uint32) external view returns (uint256) { return fee; }
    function estimateRequestPriceNative(uint32, uint32, uint256) external view returns (uint256) { return fee; }

    function requestRandomWordsInNative(uint32, uint16, uint32, bytes calldata) external payable returns (uint256 id) {
        id = ++lastRequestId;
        uint256[] memory w = new uint256[](1);
        w[0] = 12345;
        IRawFulfill(msg.sender).rawFulfillRandomWords(id, w); // synchronous callback attempt
    }
}

contract LaneGapTests is LaneHalmosTest {
    /// M01: buying exactly at endTime must revert (sale window is [creation, endTime)).
    function test_buyAtEndTimeReverts() public {
        _setUp(1);
        _buy(A, 1);
        vm.warp(end - 1);
        _buy(B, 1);
        vm.warp(end);
        usdc.mint(B, 1e6);
        vm.prank(B);
        usdc.approve(address(raffle), 1e6);
        vm.prank(B);
        (bool ok,) = address(raffle).call(abi.encodeCall(raffle.buyEntries, (B, 1)));
        assertFalse(ok, "purchase at endTime accepted");
    }

    /// M19: a non-owner cannot refund someone else's ticket.
    function test_refundRequiresOwner() public {
        _setUp(1);
        _buy(A, 2);
        vm.warp(uint256(end) + 2 days);
        raffle.enableRefunds();
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        vm.prank(B);
        (bool ok,) = address(raffle).call(abi.encodeCall(raffle.refundTickets, (ids)));
        assertFalse(ok, "non-owner refunded");
        assertEq(raffle.ownerOf(1), A);
    }

    /// M21: a synchronous callback during requestDraw must not resolve the raffle.
    function test_syncCallbackIgnored() public {
        vm.warp(1_700_000_000);
        usdc = new LaneUSDC();
        prize = new LanePrize();
        SyncCallbackWrapper sw = new SyncCallbackWrapper();
        factory = new RaffleFactory(address(usdc), address(sw), TREASURY);
        prize.mint(SPONSOR, 1);
        vm.prank(SPONSOR);
        prize.setApprovalForAll(address(factory), true);
        end = uint64(block.timestamp + 1 days);
        vm.prank(SPONSOR);
        raffle = Raffle(payable(factory.createRaffle(IRaffleFactory.CreateRaffleParams({
            sponsorRecipient: SREC, prizeToken: address(prize), prizeTokenId: 1, reserveEntries: 1, endTime: end
        }))));
        _buy(A, 3);
        vm.warp(end);
        vm.deal(A, 1 ether);
        vm.prank(A);
        raffle.requestDraw{ value: 0.001 ether }();
        assertEq(uint8(raffle.status()), uint8(IRaffle.Status.Drawing), "sync callback resolved the draw");
        assertEq(raffle.winningEntry(), 0);
    }

    /// M06: with entries sold and no draw, refunds open exactly at endTime + 2 days, not one second earlier.
    function test_activeRefundBoundary() public {
        _setUp(1);
        _buy(A, 2);
        vm.warp(uint256(end) + 2 days - 1);
        (bool early,) = address(raffle).call(abi.encodeCall(raffle.enableRefunds, ()));
        assertFalse(early, "refunds opened early");
        vm.warp(uint256(end) + 2 days);
        raffle.enableRefunds();
        assertEq(uint8(raffle.status()), uint8(IRaffle.Status.Refunding));
    }
}
