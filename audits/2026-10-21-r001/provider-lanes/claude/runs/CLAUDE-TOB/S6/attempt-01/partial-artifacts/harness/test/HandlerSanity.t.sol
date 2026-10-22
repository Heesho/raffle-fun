// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IRaffle } from "raffle/interfaces/IRaffle.sol";
import { FactoryDeployer } from "../src/FactoryDeployer.sol";
import { MockPrizeNFT } from "../src/mocks/MockPrizeNFT.sol";
import { MockUSDC } from "../src/mocks/MockUSDC.sol";
import { MockVRFV2PlusWrapper } from "../src/mocks/MockVRFV2PlusWrapper.sol";
import { RaffleHandler } from "../src/RaffleHandler.sol";
import { TestBase } from "./Vm.sol";

/// @notice Validates the reference model itself: scripted full lifecycles must produce zero violations and must reach
///         every terminal branch (otherwise the fuzzing oracle could be vacuous).
contract HandlerSanityTest is TestBase {
    RaffleHandler internal h;

    function _newHandler() internal returns (RaffleHandler) {
        return new RaffleHandler(new MockUSDC(), new MockVRFV2PlusWrapper(), new MockPrizeNFT(), new FactoryDeployer());
    }

    function setUp() public {
        h = _newHandler();
        vm.deal(address(h), 1_000 ether);
    }

    function _noViolation() internal view {
        require(h.violations() == 0, h.lastViolation());
        (bool ok, string memory why) = h.checkInvariants();
        require(ok, why);
    }

    function test_sanity_cashWonLifecycle() public {
        // raffle 0: reserve 5 entries; buy 2 + 2 = 4 -> reserve missed -> CashWon
        h.buy(0, 0, 1, 1);
        h.buy(0, 1, 2, 1);
        h.transferTicket(0, 0, 3);
        h.donate(0, 123);
        h.requestDraw(0, 2, 5);           // too early -> must revert (model expects revert)
        vm.warp(block.timestamp + 3 days);
        h.buy(0, 0, 0, 1);                // after end -> must revert
        h.requestDraw(0, 2, 5);
        h.fulfillWrong(0, 7, 0);
        h.fulfillWrong(0, 7, 1);
        h.fulfillWrong(0, 7, 2);
        h.fulfill(0, 4);
        require(h.raffles(0).status() == IRaffle.Status.CashWon, "expected CashWon");
        h.settle(0, 1, 0, false);         // random ticket
        h.redeem(0, 0, 0, true, false);   // winner ticket, non-owner caller -> revert expected
        h.releaseSponsorPrize(0, 1);
        h.redeem(0, 0, 0, true, true);    // owner redeems (settles inline)
        h.releaseSponsorProceeds(0, 2);
        h.releaseProtocolFees(0, 3);
        h.fulfillWrong(0, 9, 3);          // replay after resolution
        h.reinitialize(0, 1);
        _noViolation();
        require(h.hits(bytes32("redeemCash")) == 1 && h.hits(bytes32("releasePrize")) == 1, "branches");
    }

    function test_sanity_nftWonAndRefundLifecycles() public {
        h.createRaffle(1, 2, 5 days);     // raffle 1: reserve 2
        h.createRaffle(2, 50, 1 days);    // raffle 2: reserve 50 -> will time out to refunds
        h.buy(1, 0, 1, 1);
        h.buy(1, 2, 2, 4);
        h.buy(2, 3, 3, 7);
        h.buy(2, 1, 1, 2);
        vm.warp(block.timestamp + 5 days);
        h.requestDraw(1, 0, 0);
        h.enableRefunds(2, 0, false);     // raffle 2 request deadline passed? end+2d = day 3 < day 5 -> ok
        h.fulfill(1, 999);
        require(h.raffles(1).status() == IRaffle.Status.NftWon, "expected NftWon");
        h.settle(1, 0, 0, true);
        h.redeem(1, 0, 0, true, true);
        h.refund(2, 0, 6, false);
        h.refund(2, 0, 8, true);          // with nonexistent id (maxSeed%8==0) -> revert expected
        h.refund(2, 1, 6, false);
        h.refund(2, 2, 6, false);
        h.refundDuplicate(2, 3);
        h.releaseSponsorPrize(2, 0);
        h.transferTicketToProtocol(1, 0, 6);
        _noViolation();
        require(h.hits(bytes32("redeemNft")) == 1 && h.hits(bytes32("refund")) == 2, "branches");
    }

    function test_sanity_drawingTimeoutAndEmptyRaffle() public {
        h.createRaffle(3, 1, 2 days);     // raffle 1 (sponsor actor 3), stays empty
        h.enableRefunds(1, 3, true);      // sponsor cancels empty raffle before end (documented behaviour)
        h.buy(0, 0, 0, 2);
        vm.warp(block.timestamp + 3 days);
        h.requestDraw(0, 1, 0);
        vm.warp(block.timestamp + 2 days - 1);
        h.enableRefunds(0, 2, false);     // one second early -> revert expected
        vm.warp(block.timestamp + 1);
        h.fulfill(0, 1);                  // exactly at deadline -> ignored
        h.enableRefunds(0, 2, false);     // now allowed
        h.refund(0, 1, 3, false);
        h.releaseSponsorPrize(0, 0);
        h.releaseSponsorPrize(1, 0);
        _noViolation();
        require(h.hits(bytes32("sponsorEarlyCancel")) == 1 && h.hits(bytes32("fulfillIgnored")) == 1, "branches");
        require(h.hits(bytes32("refundsAfterDrawing")) == 1, "drawing timeout branch");
    }

    function test_sanity_failureModes() public {
        h.buy(0, 0, 1, 2);                // 3 entries < reserve 5 -> CashWon later
        h.toggleUsdcPaused(0);
        h.buy(0, 0, 1, 5);                // paused -> revert expected
        h.toggleUsdcPaused(1);
        vm.warp(block.timestamp + 3 days);
        h.setVrfPrice(0.02 ether);
        h.underpaidRequestDraw(0, 0);
        h.requestDraw(0, 0, 3);
        h.fulfill(0, 3);
        h.toggleNftFrozen(0);
        h.redeem(0, 0, 0, true, true);    // CashWon (3 < 5) -> USDC delivery unaffected by NFT freeze
        h.releaseSponsorPrize(0, 1);      // frozen -> revert expected
        h.toggleNftFrozen(1);
        h.releaseSponsorPrize(0, 1);
        _noViolation();
    }
}
