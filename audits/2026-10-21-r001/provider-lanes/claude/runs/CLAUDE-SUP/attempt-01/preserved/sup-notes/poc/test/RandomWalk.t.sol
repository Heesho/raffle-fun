// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Base } from "./Base.sol";
import { Raffle } from "raffle/Raffle.sol";
import { IRaffle } from "raffle/interfaces/IRaffle.sol";

/// Stateful random-walk property test. After every step:
///  I1 usdc.balanceOf(raffle) == accountedQuoteBalance() + donations          (solvency, exact)
///  I2 balance + paidOut == paidIn + donations                                  (conservation)
///  I3 paidIn == grossSales() == totalEntries * 1e6
///  I4 ticket ranges contiguous, disjoint, cover [1,totalEntries]
///  I5 per-status liability shape; Refunding liability == 1e6 * live entries
///  I6 settled splits: 95/5 or 80/15/5 of gross (paid + outstanding), exactly one ticket contains winningEntry
///  I7 prize custody: unclaimed => raffle owns prize; claimed => winner (NftWon) or sponsorRecipient
///  I8 no native retained by the raffle
/// After the walk, every raffle is driven to a terminal state and must drain to exactly the donations.
contract RandomWalkTest is Base {
    Raffle internal r;
    uint256 internal prizeId;
    address[] internal actors;
    uint256 internal paidIn;
    uint256 internal paidOut;
    uint256 internal donated;
    uint256 internal paidWinner;
    uint256 internal paidSponsor;
    uint256 internal paidTreasury;
    uint256 internal n;
    uint256 internal seed;

    function setUp() public override {
        super.setUp();
        actors.push(alice);
        actors.push(bob);
        actors.push(carol);
        actors.push(sponsor);
        actors.push(recipient);
        actors.push(treasury);
    }

    function _r() internal returns (uint256) {
        return uint256(keccak256(abi.encode(seed, ++n)));
    }

    function testFuzz_walk(uint256 seed_, uint8 reserveRaw, uint32 durRaw) public {
        seed = seed_;
        uint128 reserve = uint128(1 + (reserveRaw % 40));
        uint64 end = uint64(block.timestamp + 1 + (durRaw % 30 days));
        prizeId = uint256(keccak256(abi.encode(seed_)));
        r = _create(prizeId, reserve, end);
        _check();
        for (uint256 step; step < 60; ++step) {
            uint256 x = _r();
            _act(x % 14, actors[(x >> 8) % actors.length], x >> 16);
            _check();
        }
        _drain();
        _check();
        _eq(usdc.balanceOf(address(r)), donated, "drained to donations");
        require(r.prizeClaimed(), "prize delivered or returned");
        _eq(r.accountedQuoteBalance(), 0, "no liabilities left");
    }

    // ------------------------------------------------------------ actions

    function _act(uint256 a, address actor, uint256 y) internal {
        if (a <= 1) _actBuy(actor, uint128(1 + (y % 7)));
        else if (a == 2) _actTransfer(actor, y);
        else if (a == 3) vm.warp(block.timestamp + (y % 6 hours));
        else if (a == 4) vm.warp(block.timestamp + (y % 3 days));
        else if (a == 5) _actRequest(actor);
        else if (a == 6) _actFulfill(y);
        else if (a == 7) _actEnableRefunds(actor);
        else if (a == 8) _actSettle(actor, y);
        else if (a == 9) _actRedeem(actor, y);
        else if (a == 10) _actRefund(actor, y);
        else if (a == 11) _actReleaseQuote(actor, y);
        else if (a == 12) _actReleasePrize(actor);
        else _actDonate(y);
    }

    function _actBuy(address actor, uint128 k) internal {
        usdc.mint(actor, uint256(k) * E);
        vm.prank(actor);
        usdc.approve(address(r), type(uint256).max);
        vm.prank(actor);
        try r.buyEntries(actor, k) {
            paidIn += uint256(k) * E;
        } catch { }
    }

    function _actTransfer(address to, uint256 y) internal {
        uint256 tc = r.ticketCount();
        if (tc == 0) return;
        uint256 id = 1 + (y % tc);
        try r.ownerOf(id) returns (address o) {
            vm.prank(o);
            r.transferFrom(o, to, id);
        } catch { }
    }

    function _actRequest(address actor) internal {
        vm.deal(actor, 1 ether);
        vm.prank(actor);
        try r.requestDraw{ value: 0.01 ether }() { } catch { }
    }

    function _actFulfill(uint256 y) internal {
        uint256 id = r.vrfRequestId();
        if (id == 0) return;
        (address cb,) = wrapper.callbacks(id);
        if (y % 5 == 0) {
            uint256[] memory two = new uint256[](2);
            two[0] = y;
            require(wrapper.rawCall(address(r), id, two), "len2 must not revert");
        } else if (cb != address(0)) {
            require(wrapper.fulfillOne(id, y), "callback must not revert");
        } else {
            uint256[] memory one = new uint256[](1);
            one[0] = y;
            require(wrapper.rawCall(address(r), id, one), "dup must not revert");
        }
    }

    function _actEnableRefunds(address actor) internal {
        vm.prank(actor);
        try r.enableRefunds() { } catch { }
    }

    function _actSettle(address actor, uint256 y) internal {
        vm.prank(actor);
        try r.settleWinningTicket(1 + (y % (uint256(r.ticketCount()) + 2))) { } catch { }
    }

    function _actRedeem(address actor, uint256 y) internal {
        uint256 id = y % 2 == 0 ? _winningTicket() : 1 + (y % (uint256(r.ticketCount()) + 1));
        vm.prank(actor);
        try r.redeemWinningTicket(id) returns (uint256 cash) {
            paidOut += cash;
            paidWinner += cash;
        } catch { }
    }

    function _actRefund(address actor, uint256 y) internal {
        uint256 tc = r.ticketCount();
        uint256[] memory tmp = new uint256[](tc);
        uint256 k;
        for (uint256 i = 1; i <= tc; ++i) {
            try r.ownerOf(i) returns (address o) {
                if (o == actor && (y >> i) & 1 == 1 && k < 100) tmp[k++] = i;
            } catch { }
        }
        uint256[] memory ids = new uint256[](k);
        for (uint256 i; i < k; ++i) {
            ids[i] = tmp[i];
        }
        vm.prank(actor);
        try r.refundTickets(ids) returns (uint256 amt) {
            paidOut += amt;
        } catch { }
    }

    function _actReleaseQuote(address actor, uint256 y) internal {
        vm.prank(actor);
        if (y % 2 == 0) {
            try r.releaseSponsorProceeds() returns (uint256 amt) {
                paidOut += amt;
                paidSponsor += amt;
            } catch { }
        } else {
            try r.releaseProtocolFees() returns (uint256 amt) {
                paidOut += amt;
                paidTreasury += amt;
            } catch { }
        }
    }

    function _actReleasePrize(address actor) internal {
        vm.prank(actor);
        try r.releaseSponsorPrize() { } catch { }
    }

    function _actDonate(uint256 y) internal {
        uint256 amt = 1 + (y % 3_000_000);
        usdc.mint(address(r), amt);
        donated += amt;
    }

    // ------------------------------------------------------------ drain to terminal

    function _drain() internal {
        uint256 c = _r();
        IRaffle.Status st = r.status();
        uint64 end = r.endTime();
        if (st == IRaffle.Status.Active) {
            if (r.totalEntries() == 0) {
                if (block.timestamp < end) vm.warp(end);
                r.enableRefunds();
            } else {
                if (block.timestamp < end) vm.warp(end);
                if (block.timestamp < r.drawRequestDeadline() && c % 3 != 0) {
                    _request(r);
                } else {
                    if (block.timestamp < r.drawRequestDeadline()) vm.warp(r.drawRequestDeadline());
                    r.enableRefunds();
                }
            }
            _check();
            st = r.status();
        }
        if (st == IRaffle.Status.Drawing) {
            (address cb,) = wrapper.callbacks(r.vrfRequestId());
            if (cb != address(0) && block.timestamp < r.callbackDeadline() && c % 5 != 0) {
                require(wrapper.fulfillOne(r.vrfRequestId(), _r()), "cb");
            }
            if (r.status() == IRaffle.Status.Drawing) {
                if (block.timestamp < r.callbackDeadline()) vm.warp(r.callbackDeadline());
                r.enableRefunds();
            }
            _check();
            st = r.status();
        }
        if (st == IRaffle.Status.NftWon || st == IRaffle.Status.CashWon) {
            uint256 w = _winningTicket();
            if (!r.settlementComplete()) r.settleWinningTicket(w);
            _check();
            if (!r.winnerRedeemed()) {
                address o = r.ownerOf(w);
                vm.prank(o);
                uint256 cash = r.redeemWinningTicket(w);
                paidOut += cash;
                paidWinner += cash;
                _check();
            }
            if (st == IRaffle.Status.CashWon && !r.prizeClaimed()) r.releaseSponsorPrize();
            if (r.sponsorProceeds() != 0) {
                uint256 a = r.releaseSponsorProceeds();
                paidOut += a;
                paidSponsor += a;
            }
            if (r.protocolFees() != 0) {
                uint256 a = r.releaseProtocolFees();
                paidOut += a;
                paidTreasury += a;
            }
        } else if (st == IRaffle.Status.Refunding) {
            uint256 tc = r.ticketCount();
            for (uint256 i = 1; i <= tc; ++i) {
                try r.ownerOf(i) returns (address o) {
                    uint256[] memory ids = new uint256[](1);
                    ids[0] = i;
                    vm.prank(o);
                    paidOut += r.refundTickets(ids);
                } catch { }
            }
            if (!r.prizeClaimed()) r.releaseSponsorPrize();
        } else {
            revert("unexpected terminal status");
        }
    }

    // ------------------------------------------------------------ invariants

    function _winningTicket() internal view returns (uint256 w) {
        uint128 we = r.winningEntry();
        if (we == 0) return 0;
        uint256 tc = r.ticketCount();
        for (uint256 i = 1; i <= tc; ++i) {
            (uint128 f, uint128 l) = r.ticketRange(i);
            if (we >= f && we <= l) return i;
        }
    }

    function _check() internal view {
        uint256 bal = usdc.balanceOf(address(r));
        _eq(bal, r.accountedQuoteBalance() + donated, "I1 balance == liabilities + donations");
        _eq(bal + paidOut, paidIn + donated, "I2 conservation");
        _eq(paidIn, r.grossSales(), "I3 gross");
        uint256 gross = r.grossSales();

        uint256 tc = r.ticketCount();
        uint128 prev;
        uint256 liveEntries;
        uint256 containing;
        uint128 we = r.winningEntry();
        for (uint256 i = 1; i <= tc; ++i) {
            (uint128 f, uint128 l) = r.ticketRange(i);
            require(f == prev + 1 && l >= f, "I4 contiguity");
            prev = l;
            if (we != 0 && we >= f && we <= l) containing++;
            try r.ownerOf(i) returns (address) {
                liveEntries += uint256(l) - f + 1;
            } catch { }
        }
        _eq(prev, r.totalEntries(), "I4 coverage");

        IRaffle.Status st = r.status();
        if (st == IRaffle.Status.Active || st == IRaffle.Status.Drawing) {
            _eq(r.unsettledPot(), gross, "I5 pot");
            _eq(r.remainingRefundLiability() + r.winnerProceeds() + r.sponsorProceeds() + r.protocolFees(), 0, "I5");
            _eq(liveEntries, r.totalEntries(), "I5 no burns pre-result");
        } else if (st == IRaffle.Status.Refunding) {
            _eq(r.unsettledPot(), 0, "I5 pot moved");
            _eq(r.remainingRefundLiability(), liveEntries * E, "I5 refund liability == live entries");
        } else if (st == IRaffle.Status.NftWon || st == IRaffle.Status.CashWon) {
            require(we >= 1 && we <= r.totalEntries(), "I6 entry in range");
            _eq(containing, 1, "I6 unique winner");
            if (!r.settlementComplete()) {
                _eq(r.unsettledPot(), gross, "I6 pot pre-settle");
            } else {
                _eq(r.unsettledPot(), 0, "I6 pot post-settle");
                (uint128 f, uint128 l) = r.ticketRange(r.winningTicketId());
                require(we >= f && we <= l, "I6 settled ticket contains entry");
                uint256 fee = gross * 500 / 10_000;
                _eq(paidTreasury + r.protocolFees(), fee, "I6 5% treasury");
                if (st == IRaffle.Status.NftWon) {
                    _eq(paidSponsor + r.sponsorProceeds(), gross - fee, "I6 95% sponsor");
                    _eq(paidWinner + r.winnerProceeds(), 0, "I6 no cash");
                } else {
                    uint256 cash = gross * 8000 / 10_000;
                    _eq(paidWinner + r.winnerProceeds(), cash, "I6 80% winner");
                    _eq(paidSponsor + r.sponsorProceeds(), gross - fee - cash, "I6 15% sponsor");
                }
            }
            if (r.winnerRedeemed()) require(r.settlementComplete(), "redeemed => settled");
        } else {
            revert("AwaitingPrize persisted");
        }

        if (!r.prizeClaimed()) {
            require(nft.ownerOf(prizeId) == address(r), "I7 escrow");
        } else if (st == IRaffle.Status.NftWon) {
            require(r.winnerRedeemed() && nft.ownerOf(prizeId) == r.winnerRecipient(), "I7 winner");
        } else {
            require(
                (st == IRaffle.Status.CashWon || st == IRaffle.Status.Refunding) && nft.ownerOf(prizeId) == recipient,
                "I7 sponsor return"
            );
        }
        _eq(address(r).balance, 0, "I8 native");
    }
}
