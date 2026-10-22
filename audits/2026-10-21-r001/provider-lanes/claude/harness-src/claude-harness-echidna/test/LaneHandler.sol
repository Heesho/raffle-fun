// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

// Lane-owned stateful harness (Anthropic lane, audit r001). Shared by the Foundry invariant
// campaign (LaneInvariant.t.sol) and the Echidna/Medusa campaigns (LaneEchidna.sol).
// Two raffles from one factory: R0 reserve 3 entries (NFT outcome reachable), R1 reserve 1e9
// entries (cash outcome). Properties are derived from DESIGN.md and IRaffle NatSpec, not from code.

import { RaffleFactory } from "../src/RaffleFactory.sol";
import { Raffle } from "../src/Raffle.sol";
import { IRaffle } from "../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../src/interfaces/IRaffleFactory.sol";
import { LaneUSDC, LanePrize, LaneVRFWrapper } from "./mocks/LaneMocks.sol";
import { LaneFactoryDeployer } from "./LaneFactoryDeployer.sol";

interface Hevm {
    function warp(uint256) external;
    function prank(address) external;
    function deal(address, uint256) external;
}

contract LaneHandler {
    Hevm internal constant hevm = Hevm(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint256 internal constant PRICE = 1_000_000;
    LaneUSDC public usdc;
    LanePrize public prize;
    LaneVRFWrapper public wrapper;
    RaffleFactory public factory;
    Raffle[2] public raffles;
    address public constant TREASURY = address(0x7EA5);
    address public constant SPONSOR = address(0x5905);
    address public constant SPONSOR_RECIPIENT = address(0x5EC1);
    address[4] public actors = [address(0xA11CE), address(0xB0B), address(0xCA401), address(0xD0D0)];

    // ghosts per raffle
    uint256[2] public ghostIn;
    uint256[2] public ghostOut;
    uint256[2] public ghostDonated;
    uint256[2] public ghostOutWinner;
    uint256[2] public ghostOutSponsor;
    uint256[2] public ghostOutProtocol;
    uint256[2] public ghostOutRefund;
    uint256[2] public ghostPotAtSettle;
    bool[2] public ghostSettled;
    uint256 public calls;
    // vacuity counters: successful actions and lifecycle states reached
    mapping(bytes32 => uint256) public ok;
    uint256 public statusSeenMask;

    function _seen() internal {
        for (uint256 i; i < 2; i++) statusSeenMask |= (1 << uint256(raffles[i].status()));
    }
    // property flags raised by handler-level assertions
    bool public payoutMismatch;
    bool public crossRaffleLeak;
    bool public illegalTransition;
    bool public lateCallbackAccepted;
    bool public earlyRefundAccepted;
    bool public drawOutsideWindow;
    bool public settleSplitWrong;

    constructor() {
        hevm.warp(1_700_000_000);
        usdc = new LaneUSDC();
        prize = new LanePrize();
        wrapper = new LaneVRFWrapper();
        factory = LaneFactoryDeployer(address(0x1f)).deploy(address(usdc), address(wrapper), TREASURY); // echidna-only variant
        prize.mint(SPONSOR, 1);
        prize.mint(SPONSOR, 2);
        hevm.prank(SPONSOR);
        prize.setApprovalForAll(address(factory), true);
        uint64 end = uint64(block.timestamp + 7 days);
        hevm.prank(SPONSOR);
        raffles[0] = Raffle(payable(factory.createRaffle(IRaffleFactory.CreateRaffleParams({
            sponsorRecipient: SPONSOR_RECIPIENT, prizeToken: address(prize), prizeTokenId: 1, reserveEntries: 3, endTime: end
        }))));
        hevm.prank(SPONSOR);
        raffles[1] = Raffle(payable(factory.createRaffle(IRaffleFactory.CreateRaffleParams({
            sponsorRecipient: SPONSOR_RECIPIENT, prizeToken: address(prize), prizeTokenId: 2, reserveEntries: 1e9, endTime: end
        }))));
    }

    // ---------- helpers
    function _r(uint256 s) internal view returns (Raffle) {
        return raffles[s % 2];
    }

    function _actor(uint256 s) internal view returns (address) {
        return actors[s % 4];
    }

    function _otherBalance(uint256 idx) internal view returns (uint256) {
        return usdc.balanceOf(address(raffles[1 - idx]));
    }

    // ---------- actions
    function buy(uint256 rs, uint256 as_, uint256 recipientSeed, uint128 count) public {
        calls++;
        uint256 idx = rs % 2;
        Raffle r = raffles[idx];
        count = uint128(1 + (count % 20));
        address a = _actor(as_);
        address recipient = _actor(recipientSeed);
        uint256 cost = uint256(count) * PRICE;
        usdc.mint(a, cost);
        uint256 before = usdc.balanceOf(address(r));
        uint256 other = _otherBalance(idx);
        hevm.prank(a);
        usdc.approve(address(r), cost);
        hevm.prank(a);
        try r.buyEntries(recipient, count) {
            ghostIn[idx] += cost; ok["buy"]++; _seen();
            if (usdc.balanceOf(address(r)) != before + cost) payoutMismatch = true;
            if (_otherBalance(idx) != other) crossRaffleLeak = true;
        } catch { }
    }

    function transferTicket(uint256 rs, uint256 ticketSeed, uint256 toSeed) public {
        calls++;
        Raffle r = _r(rs);
        uint256 n = r.ticketCount();
        if (n == 0) return;
        uint256 id = 1 + ticketSeed % n;
        address owner;
        try r.ownerOf(id) returns (address o) { owner = o; } catch { return; }
        hevm.prank(owner);
        try r.transferFrom(owner, _actor(toSeed), id) { ok["transfer"]++; } catch { }
    }

    function warp(uint256 dt) public {
        calls++;
        dt = dt % (3 days);
        hevm.warp(block.timestamp + dt);
    }

    function requestDraw(uint256 rs, uint256 callerSeed, uint256 extra) public {
        calls++;
        uint256 idx = rs % 2;
        Raffle r = raffles[idx];
        address c = _actor(callerSeed);
        uint256 v = wrapper.fee() + (extra % 1 ether);
        hevm.deal(c, v);
        uint256 end = r.endTime();
        IRaffle.Status st = r.status();
        hevm.prank(c);
        try r.requestDraw{ value: v }() {
            ok["requestDraw"]++; _seen();
            if (st != IRaffle.Status.Active || block.timestamp < end || block.timestamp >= end + 2 days) {
                drawOutsideWindow = true;
            }
        } catch { }
    }

    function fulfill(uint256 rs, uint256 word, bool useStale) public {
        calls++;
        Raffle r = _r(rs);
        uint256 id = r.vrfRequestId();
        if (id == 0) return;
        if (useStale && id > 1) id = id - 1; // wrong-request callback
        IRaffle.Status before = r.status();
        uint256 deadline = r.callbackDeadline();
        try wrapper.fulfill(id, word) {
            ok["fulfillCall"]++; _seen();
            IRaffle.Status afterS = r.status();
            if (before == IRaffle.Status.Drawing && afterS != IRaffle.Status.Drawing && block.timestamp >= deadline) {
                lateCallbackAccepted = true;
            }
            if (before != afterS && before != IRaffle.Status.Drawing) illegalTransition = true;
        } catch { }
    }

    function enableRefunds(uint256 rs, uint256 callerSeed, bool asSponsor) public {
        calls++;
        Raffle r = _r(rs);
        address c = asSponsor ? SPONSOR : _actor(callerSeed);
        IRaffle.Status st = r.status();
        uint256 te = r.totalEntries();
        uint256 end = r.endTime();
        uint256 cb = r.callbackDeadline();
        hevm.prank(c);
        try r.enableRefunds() {
            ok["enableRefunds"]++; _seen();
            bool ok;
            if (st == IRaffle.Status.Active && te == 0) ok = (c == SPONSOR) || block.timestamp >= end;
            else if (st == IRaffle.Status.Active) ok = block.timestamp >= end + 2 days;
            else if (st == IRaffle.Status.Drawing) ok = block.timestamp >= cb;
            if (!ok) earlyRefundAccepted = true;
        } catch { }
    }

    function settle(uint256 rs, uint256 ticketSeed, uint256 callerSeed) public {
        calls++;
        uint256 idx = rs % 2;
        Raffle r = raffles[idx];
        uint256 n = r.ticketCount();
        if (n == 0) return;
        uint256 id = 1 + ticketSeed % n;
        uint256 pot = r.unsettledPot();
        hevm.prank(_actor(callerSeed));
        try r.settleWinningTicket(id) {
            _recordSettle(idx, r, pot); ok["settle"]++;
        } catch { }
    }

    function _recordSettle(uint256 idx, Raffle r, uint256 pot) internal {
        _recordSettlePaid(idx, r, pot, r.winnerProceeds());
    }

    /// @dev `winnerAlloc` is the winner allocation observed (stored proceeds, or the amount just paid when
    ///      settlement and redemption happened atomically).
    function _recordSettlePaid(uint256 idx, Raffle r, uint256 pot, uint256 winnerAlloc) internal {
        ghostSettled[idx] = true;
        ghostPotAtSettle[idx] = pot;
        uint256 fee = pot * 500 / 10_000;
        uint256 cash = r.status() == IRaffle.Status.CashWon ? pot * 8000 / 10_000 : 0;
        if (r.protocolFees() != fee || winnerAlloc != cash || r.sponsorProceeds() != pot - fee - cash) {
            settleSplitWrong = true;
        }
    }

    function redeem(uint256 rs, uint256 ticketSeed) public {
        calls++;
        uint256 idx = rs % 2;
        Raffle r = raffles[idx];
        uint256 n = r.ticketCount();
        if (n == 0) return;
        uint256 id = r.settlementComplete() ? r.winningTicketId() : 1 + ticketSeed % n;
        if (id == 0) return;
        address owner;
        try r.ownerOf(id) returns (address o) { owner = o; } catch { return; }
        uint256 pot = r.unsettledPot();
        bool wasSettled = r.settlementComplete();
        uint256 before = usdc.balanceOf(address(r));
        uint256 ownerBefore = usdc.balanceOf(owner);
        uint256 other = _otherBalance(idx);
        hevm.prank(owner);
        try r.redeemWinningTicket(id) returns (uint256 cash) {
            if (!wasSettled) _recordSettlePaid(idx, r, pot, cash);
            ghostOut[idx] += cash;
            ghostOutWinner[idx] += cash; ok[r.status() == IRaffle.Status.NftWon ? bytes32("redeemNft") : bytes32("redeemCash")]++;
            if (before - usdc.balanceOf(address(r)) != cash || usdc.balanceOf(owner) - ownerBefore != cash) {
                payoutMismatch = true;
            }
            if (_otherBalance(idx) != other) crossRaffleLeak = true;
        } catch { }
    }

    function refund(uint256 rs, uint256 actorSeed, uint256 mask) public {
        calls++;
        uint256 idx = rs % 2;
        Raffle r = raffles[idx];
        address a = _actor(actorSeed);
        uint256 n = r.ticketCount();
        uint256[] memory tmp = new uint256[](n);
        uint256 k;
        for (uint256 id = 1; id <= n && k < 100; id++) {
            try r.ownerOf(id) returns (address o) {
                if (o == a && (mask >> (id % 256)) & 1 == 1) tmp[k++] = id;
            } catch { }
        }
        if (k == 0) return;
        uint256[] memory ids = new uint256[](k);
        for (uint256 i; i < k; i++) ids[i] = tmp[i];
        uint256 before = usdc.balanceOf(address(r));
        uint256 aBefore = usdc.balanceOf(a);
        hevm.prank(a);
        try r.refundTickets(ids) returns (uint256 amt) {
            ghostOut[idx] += amt;
            ghostOutRefund[idx] += amt; ok["refund"]++;
            if (before - usdc.balanceOf(address(r)) != amt || usdc.balanceOf(a) - aBefore != amt) payoutMismatch = true;
        } catch { }
    }

    function releaseSponsor(uint256 rs, uint256 callerSeed) public {
        calls++;
        uint256 idx = rs % 2;
        Raffle r = raffles[idx];
        uint256 before = usdc.balanceOf(SPONSOR_RECIPIENT);
        hevm.prank(_actor(callerSeed));
        try r.releaseSponsorProceeds() returns (uint256 amt) {
            ghostOut[idx] += amt;
            ghostOutSponsor[idx] += amt; ok["releaseSponsor"]++;
            if (usdc.balanceOf(SPONSOR_RECIPIENT) - before != amt) payoutMismatch = true;
        } catch { }
    }

    function releaseProtocol(uint256 rs, uint256 callerSeed) public {
        calls++;
        uint256 idx = rs % 2;
        Raffle r = raffles[idx];
        uint256 before = usdc.balanceOf(TREASURY);
        hevm.prank(_actor(callerSeed));
        try r.releaseProtocolFees() returns (uint256 amt) {
            ghostOut[idx] += amt;
            ghostOutProtocol[idx] += amt; ok["releaseProtocol"]++;
            if (usdc.balanceOf(TREASURY) - before != amt) payoutMismatch = true;
        } catch { }
    }

    function releasePrize(uint256 rs, uint256 callerSeed) public {
        calls++;
        Raffle r = _r(rs);
        hevm.prank(_actor(callerSeed));
        try r.releaseSponsorPrize() { ok["releasePrize"]++; } catch { }
    }

    function donate(uint256 rs, uint256 amount) public {
        calls++;
        uint256 idx = rs % 2;
        amount = amount % (1000 * PRICE);
        usdc.mint(address(raffles[idx]), amount);
        ghostDonated[idx] += amount;
    }

    // ---------- property views (true = holds)
    function propSolvency() public view returns (bool) {
        for (uint256 i; i < 2; i++) {
            if (usdc.balanceOf(address(raffles[i])) < raffles[i].accountedQuoteBalance()) return false;
        }
        return true;
    }

    function propConservation() public view returns (bool) {
        for (uint256 i; i < 2; i++) {
            Raffle r = raffles[i];
            if (r.accountedQuoteBalance() + ghostOut[i] != ghostIn[i]) return false;
            if (usdc.balanceOf(address(r)) != ghostIn[i] + ghostDonated[i] - ghostOut[i]) return false;
        }
        return true;
    }

    function propPotMatchesSales() public view returns (bool) {
        for (uint256 i; i < 2; i++) {
            Raffle r = raffles[i];
            IRaffle.Status s = r.status();
            if ((s == IRaffle.Status.Active || s == IRaffle.Status.Drawing) && r.unsettledPot() != r.grossSales()) {
                return false;
            }
            if (r.grossSales() != ghostIn[i]) return false;
        }
        return true;
    }

    function propRefundLiabilityMatchesLiveTickets() public view returns (bool) {
        for (uint256 i; i < 2; i++) {
            Raffle r = raffles[i];
            if (r.status() != IRaffle.Status.Refunding) continue;
            uint256 live;
            uint256 n = r.ticketCount();
            for (uint256 id = 1; id <= n; id++) {
                try r.ownerOf(id) returns (address) {
                    (uint128 f, uint128 l) = r.ticketRange(id);
                    live += (uint256(l) - f + 1) * PRICE;
                } catch { }
            }
            if (live != r.remainingRefundLiability()) return false;
        }
        return true;
    }

    function propRangesPartition() public view returns (bool) {
        for (uint256 i; i < 2; i++) {
            Raffle r = raffles[i];
            uint256 n = r.ticketCount();
            uint256 prev;
            for (uint256 id = 1; id <= n; id++) {
                (uint128 f, uint128 l) = r.ticketRange(id);
                if (f != prev + 1 || l < f) return false;
                prev = l;
            }
            if (prev != r.totalEntries()) return false;
        }
        return true;
    }

    function propOutcomeConsistent() public view returns (bool) {
        for (uint256 i; i < 2; i++) {
            Raffle r = raffles[i];
            IRaffle.Status s = r.status();
            if (s == IRaffle.Status.NftWon || s == IRaffle.Status.CashWon) {
                uint256 w = r.winningEntry();
                if (w == 0 || w > r.totalEntries()) return false;
                if ((s == IRaffle.Status.NftWon) != (r.totalEntries() >= r.reserveEntries())) return false;
                if (r.settlementComplete()) {
                    (uint128 f, uint128 l) = r.ticketRange(r.winningTicketId());
                    if (w < f || w > l) return false;
                }
            }
            if (s == IRaffle.Status.Refunding && (r.settlementComplete() || r.winnerRedeemed())) return false;
            if (r.winnerRedeemed() && !r.settlementComplete()) return false;
        }
        return true;
    }

    function propPrizeCustody() public view returns (bool) {
        for (uint256 i; i < 2; i++) {
            Raffle r = raffles[i];
            address o = prize.ownerOf(i + 1);
            if (!r.prizeClaimed()) {
                if (o != address(r)) return false;
            } else {
                if (r.status() == IRaffle.Status.NftWon) {
                    if (o != r.winnerRecipient()) return false;
                } else if (o != SPONSOR_RECIPIENT) {
                    return false;
                }
            }
        }
        return true;
    }

    function propSettlementTotals() public view returns (bool) {
        for (uint256 i; i < 2; i++) {
            if (!ghostSettled[i]) continue;
            Raffle r = raffles[i];
            uint256 pot = ghostPotAtSettle[i];
            uint256 totalAlloc = r.protocolFees() + ghostOutProtocol[i] + r.sponsorProceeds() + ghostOutSponsor[i]
                + r.winnerProceeds() + ghostOutWinner[i];
            if (totalAlloc != pot) return false;
        }
        return true;
    }

    function propNoFlags() public view returns (bool) {
        return !(payoutMismatch || crossRaffleLeak || illegalTransition || lateCallbackAccepted || earlyRefundAccepted
                || drawOutsideWindow || settleSplitWrong);
    }
}
