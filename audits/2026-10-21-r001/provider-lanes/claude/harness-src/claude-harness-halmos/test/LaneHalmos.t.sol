// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

// Lane-owned Halmos symbolic checks (Anthropic lane, audit r001). Each check_* executes the real
// contracts with symbolic inputs; assertions use independently derived reference values.

import { Test } from "forge-std/Test.sol";
import { RaffleFactory } from "../src/RaffleFactory.sol";
import { Raffle } from "../src/Raffle.sol";
import { IRaffle } from "../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../src/interfaces/IRaffleFactory.sol";
import { LaneUSDC, LanePrize, LaneVRFWrapper } from "./mocks/LaneMocks.sol";

contract LaneHalmosTest is Test {
    LaneUSDC usdc;
    LanePrize prize;
    LaneVRFWrapper wrapper;
    RaffleFactory factory;
    Raffle raffle;
    address constant TREASURY = address(0x7EA5);
    address constant SPONSOR = address(0x5905);
    address constant SREC = address(0x5EC1);
    address constant A = address(0xA11CE);
    address constant B = address(0xB0B);
    uint64 end;

    function _setUp(uint128 reserve) internal {
        vm.warp(1_700_000_000);
        usdc = new LaneUSDC();
        prize = new LanePrize();
        wrapper = new LaneVRFWrapper();
        factory = new RaffleFactory(address(usdc), address(wrapper), TREASURY);
        prize.mint(SPONSOR, 1);
        vm.prank(SPONSOR);
        prize.setApprovalForAll(address(factory), true);
        end = uint64(block.timestamp + 1 days);
        vm.prank(SPONSOR);
        raffle = Raffle(payable(factory.createRaffle(IRaffleFactory.CreateRaffleParams({
            sponsorRecipient: SREC, prizeToken: address(prize), prizeTokenId: 1, reserveEntries: reserve, endTime: end
        }))));
    }

    function _buy(address who, uint128 n) internal {
        usdc.mint(who, uint256(n) * 1e6);
        vm.prank(who);
        usdc.approve(address(raffle), uint256(n) * 1e6);
        vm.prank(who);
        raffle.buyEntries(who, n);
    }

    function _drawAndResolve(uint256 word) internal {
        vm.warp(end);
        vm.deal(A, 1 ether);
        vm.prank(A);
        raffle.requestDraw{ value: 0.001 ether }();
        wrapper.fulfill(raffle.vrfRequestId(), word);
    }

    /// Settlement allocates exactly the gross pot with 5% floor fee and 80% floor cash (reserve missed).
    function check_settlementSplit(uint128 n, uint128 reserve) public {
        vm.assume(n > 0 && n <= 1e15);
        vm.assume(reserve > 0);
        _setUp(reserve);
        _buy(A, n);
        _drawAndResolve(0); // winning entry 1 -> ticket 1
        raffle.settleWinningTicket(1);
        uint256 pot = uint256(n) * 1e6;
        uint256 fee = pot / 20;
        bool cash = n < reserve;
        assert(raffle.protocolFees() == fee);
        assert(raffle.winnerProceeds() == (cash ? pot * 4 / 5 : 0));
        assert(raffle.protocolFees() + raffle.winnerProceeds() + raffle.sponsorProceeds() == pot);
        assert(raffle.unsettledPot() == 0);
        assert(raffle.accountedQuoteBalance() == usdc.balanceOf(address(raffle)));
        assert(uint8(raffle.status()) == uint8(cash ? IRaffle.Status.CashWon : IRaffle.Status.NftWon));
    }

    /// Any random word selects an entry in [1,total] contained by exactly one of two tickets.
    function check_winnerInRange(uint128 n1, uint128 n2, uint256 word) public {
        vm.assume(n1 > 0 && n1 <= 1e9 && n2 > 0 && n2 <= 1e9);
        _setUp(1);
        _buy(A, n1);
        _buy(B, n2);
        _drawAndResolve(word);
        uint128 w = raffle.winningEntry();
        assert(w >= 1 && w <= n1 + n2);
        bool in1 = w <= n1;
        // exactly one ticket can settle
        (bool ok1,) = address(raffle).call(abi.encodeCall(raffle.settleWinningTicket, (1)));
        if (!ok1) {
            (bool ok2,) = address(raffle).call(abi.encodeCall(raffle.settleWinningTicket, (2)));
            assert(ok2 && !in1);
        } else {
            assert(in1);
        }
    }

    /// Refund pays exactly entries*price, decrements liability exactly, and cannot be repeated.
    function check_refundExact(uint128 n1, uint128 n2) public {
        vm.assume(n1 > 0 && n1 <= 1e12 && n2 > 0 && n2 <= 1e12);
        _setUp(1);
        _buy(A, n1);
        _buy(B, n2);
        vm.warp(uint256(end) + 2 days); // no draw requested -> refunds open at request deadline
        raffle.enableRefunds();
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256 balBefore = usdc.balanceOf(A);
        vm.prank(A);
        uint256 paid = raffle.refundTickets(ids);
        assert(paid == uint256(n1) * 1e6);
        assert(usdc.balanceOf(A) - balBefore == paid);
        assert(raffle.remainingRefundLiability() == uint256(n2) * 1e6);
        vm.prank(A);
        (bool again,) = address(raffle).call(abi.encodeCall(raffle.refundTickets, (ids)));
        assert(!again);
    }

    /// requestDraw succeeds iff end <= t < end + 2 days (Active, entries sold).
    function check_requestDrawWindow(uint64 dt) public {
        _setUp(1);
        _buy(A, 1);
        uint256 t = uint256(block.timestamp) + dt;
        vm.warp(t);
        vm.deal(A, 1 ether);
        vm.prank(A);
        (bool ok,) = address(raffle).call{ value: 0.001 ether }(abi.encodeCall(raffle.requestDraw, ()));
        bool inWindow = t >= end && t < uint256(end) + 2 days;
        assert(ok == inWindow);
    }

    /// The callback resolves iff it lands strictly before drawRequestedAt + 2 days.
    function check_callbackDeadline(uint64 dt, uint256 word) public {
        _setUp(1);
        _buy(A, 3);
        vm.warp(end);
        vm.deal(A, 1 ether);
        vm.prank(A);
        raffle.requestDraw{ value: 0.001 ether }();
        uint256 req = raffle.drawRequestedAt();
        vm.warp(req + dt);
        wrapper.fulfill(raffle.vrfRequestId(), word);
        bool resolved = raffle.status() != IRaffle.Status.Drawing;
        assert(resolved == (uint256(dt) < 2 days));
    }

    /// Refunds from Drawing open exactly at the callback deadline, never earlier.
    function check_enableRefundsFromDrawing(uint64 dt, address caller) public {
        _setUp(1);
        _buy(A, 3);
        vm.warp(end);
        vm.deal(A, 1 ether);
        vm.prank(A);
        raffle.requestDraw{ value: 0.001 ether }();
        vm.warp(uint256(raffle.drawRequestedAt()) + dt);
        vm.prank(caller);
        (bool ok,) = address(raffle).call(abi.encodeCall(raffle.enableRefunds, ()));
        assert(ok == (uint256(dt) >= 2 days));
    }

    /// Only the factory can initialize, only once.
    function check_initializeOnlyFactory(address caller) public {
        _setUp(1);
        IRaffle.RaffleInitParams memory p = IRaffle.RaffleInitParams({
            sponsor: caller, sponsorRecipient: caller, protocolTreasury: caller, prizeToken: address(prize),
            prizeTokenId: 7, raffleId: 9, reserveEntries: 1, endTime: end
        });
        vm.prank(caller);
        (bool ok,) = address(raffle).call(abi.encodeCall(raffle.initialize, (p)));
        assert(!ok);
        Raffle impl = Raffle(payable(factory.raffleImplementation()));
        vm.prank(caller);
        (bool ok2,) = address(impl).call(abi.encodeCall(impl.initialize, (p)));
        assert(!ok2);
    }

    /// Only the wrapper can deliver randomness.
    function check_fulfillOnlyWrapper(address caller, uint256 word) public {
        _setUp(1);
        vm.assume(caller != address(wrapper)); // (attempt-03 fix: assume after deployment)
        _buy(A, 2);
        vm.warp(end);
        vm.deal(A, 1 ether);
        vm.prank(A);
        raffle.requestDraw{ value: 0.001 ether }();
        uint256[] memory w = new uint256[](1);
        w[0] = word;
        uint256 id = raffle.vrfRequestId();
        vm.prank(caller);
        (bool ok,) = address(raffle).call(abi.encodeCall(raffle.rawFulfillRandomWords, (id, w)));
        assert(!ok);
        assert(raffle.status() == IRaffle.Status.Drawing);
    }

    /// The sponsor prize cannot leave escrow while the raffle is Active or after an NFT win.
    function check_sponsorPrizeLocked(address caller, uint256 word) public {
        _setUp(1);
        _buy(A, 2);
        vm.prank(caller);
        (bool ok,) = address(raffle).call(abi.encodeCall(raffle.releaseSponsorPrize, ()));
        assert(!ok);
        _drawAndResolve(word); // reserve 1 met -> NftWon
        vm.prank(caller);
        (bool ok2,) = address(raffle).call(abi.encodeCall(raffle.releaseSponsorPrize, ()));
        assert(!ok2);
        assert(prize.ownerOf(1) == address(raffle));
    }

    /// Only the current winning-ticket owner can redeem, and only once.
    function check_redeemOnlyOwner(address caller, uint256 word) public {
        vm.assume(caller != A);
        _setUp(1);
        _buy(A, 2);
        _drawAndResolve(word);
        vm.prank(caller);
        (bool ok,) = address(raffle).call(abi.encodeCall(raffle.redeemWinningTicket, (1)));
        assert(!ok);
        vm.prank(A);
        raffle.redeemWinningTicket(1);
        assert(prize.ownerOf(1) == A);
        vm.prank(A);
        (bool again,) = address(raffle).call(abi.encodeCall(raffle.redeemWinningTicket, (1)));
        assert(!again);
    }

    /// Fixed ticket sizes (3 and 5 entries), fully symbolic random word: selected entry in range and owned by exactly one ticket.
    function check_winnerInRangeFixedSizes(uint256 word) public {
        _setUp(1);
        _buy(A, 3);
        _buy(B, 5);
        _drawAndResolve(word);
        uint128 w = raffle.winningEntry();
        assert(w >= 1 && w <= 8);
        (bool ok1,) = address(raffle).call(abi.encodeCall(raffle.settleWinningTicket, (1)));
        if (!ok1) {
            (bool ok2,) = address(raffle).call(abi.encodeCall(raffle.settleWinningTicket, (2)));
            assert(ok2 && w > 3);
        } else {
            assert(w <= 3);
        }
    }
}
