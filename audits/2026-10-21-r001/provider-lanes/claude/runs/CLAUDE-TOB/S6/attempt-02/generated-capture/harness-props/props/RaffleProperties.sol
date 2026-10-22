// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

// GENERATED SCRATCH TEST CODE (S6 attempt-02). Stateful property harness for Echidna (property + assertion modes) and
// Medusa. It deploys the UNMODIFIED production RaffleFactory (which deploys the Raffle implementation) and drives real
// ERC-1167 clones through every lifecycle path with distinct Actor users, a mock canonical USDC, a mock VRF v2.5
// wrapper and an honest ERC-721 prize. Each action computes the outcome the specification predicts BEFORE the call and
// checks it afterwards (success/revert agreement + postconditions). Global invariants are exposed as echidna_*.
// Property IDs refer to the "Security properties" section of TOB-S6-secure-workflow-guide.md.

import { IRaffle } from "../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../src/interfaces/IRaffleFactory.sol";
import { RaffleFactory } from "../src/RaffleFactory.sol";

import { Actor } from "./Actor.sol";
import { MockPrizeNFT } from "./mocks/MockPrizeNFTs.sol";
import { MockUSDC } from "./mocks/MockUSDC.sol";
import { MockVRFWrapper } from "./mocks/MockVRFWrapper.sol";
import { HEVM_ADDRESS, IHevm } from "./utils/IHevm.sol";

contract RafflePropertiesHarness {
    IHevm internal constant HEVM = IHevm(HEVM_ADDRESS);

    uint256 internal constant PRICE = 1_000_000;
    uint256 internal constant N_ACTORS = 4;
    uint256 internal constant MAX_RAFFLES = 2;
    address internal constant SPONSOR_RECIPIENT = address(0x000000000000000000000000000000000005cA1e);
    address internal constant TREASURY = address(0x0000000000000000000000000000000000007EA5);

    MockUSDC public usdc;
    MockVRFWrapper public wrapper;
    MockPrizeNFT public prize;
    RaffleFactory public factory;
    address public implementation;
    Actor[N_ACTORS] public actors;

    address[] public raffles;
    mapping(address raffle => uint256 tokenId) public prizeIdOf;
    mapping(address raffle => uint256 amount) public donated;
    mapping(address raffle => uint8 status) public lastStatus;
    mapping(address raffle => bool seen) public settledSeen;
    uint256 public nextPrizeId;

    // ---- violation flags (property mode reads them; assertion mode asserts immediately) ----
    uint256 public violations;
    string public firstViolation;

    event Violation(string id, address raffle);
    event Note(string what, uint256 a, uint256 b);

    constructor() payable {
        usdc = new MockUSDC();
        wrapper = new MockVRFWrapper();
        prize = new MockPrizeNFT();
        factory = new RaffleFactory(address(usdc), address(wrapper), TREASURY);
        implementation = factory.raffleImplementation();
        for (uint256 i; i < N_ACTORS; ++i) {
            actors[i] = new Actor();
        }
    }

    receive() external payable { }

    // =====================================================================================================
    // helpers
    // =====================================================================================================

    function _check(bool ok, string memory id, address raffle) internal virtual {
        if (!ok) {
            if (violations == 0) firstViolation = id;
            violations += 1;
            emit Violation(id, raffle);
        }
    }

    function _raffle(uint8 seed) internal view returns (IRaffle r, bool exists) {
        if (raffles.length == 0) return (IRaffle(address(0)), false);
        return (IRaffle(raffles[seed % raffles.length]), true);
    }

    /// @dev 3 in 4 times prefer a raffle currently in `preferred` (search bias only; any raffle may still be chosen).
    function _pick(uint8 seed, IRaffle.Status preferred) internal view returns (IRaffle r, bool exists) {
        if (raffles.length == 0) return (IRaffle(address(0)), false);
        if (seed % 4 != 0) {
            for (uint256 i; i < raffles.length; ++i) {
                IRaffle c = IRaffle(raffles[(uint256(seed) + i) % raffles.length]);
                if (c.status() == preferred) return (c, true);
            }
        }
        return (IRaffle(raffles[seed % raffles.length]), true);
    }

    function _actor(uint8 seed) internal view returns (Actor) {
        return actors[seed % N_ACTORS];
    }

    function _ownerOrZero(IRaffle r, uint256 ticketId) internal view returns (address owner) {
        try IERC721View(address(r)).ownerOf(ticketId) returns (address o) {
            owner = o;
        } catch {
            owner = address(0);
        }
    }

    function _winningTicket(IRaffle r) internal view returns (uint256) {
        uint256 w = r.winningEntry();
        uint256 n = r.ticketCount();
        for (uint256 i = 1; i <= n; ++i) {
            (uint128 f, uint128 l) = r.ticketRange(i);
            if (w >= f && w <= l) return i;
        }
        return 0;
    }

    function _isProtocolAddress(address a) internal view returns (bool) {
        if (a == address(factory) || a == implementation || a == address(usdc) || a == address(wrapper)) return true;
        if (a == address(prize)) return true;
        for (uint256 i; i < raffles.length; ++i) {
            if (a == raffles[i]) return true;
        }
        return false;
    }

    function _allowedTransition(uint8 a, uint8 b) internal pure returns (bool) {
        if (a == b) return true;
        IRaffle.Status s = IRaffle.Status(a);
        IRaffle.Status t = IRaffle.Status(b);
        if (s == IRaffle.Status.AwaitingPrize) return t == IRaffle.Status.Active;
        if (s == IRaffle.Status.Active) return t == IRaffle.Status.Drawing || t == IRaffle.Status.Refunding;
        if (s == IRaffle.Status.Drawing) {
            return t == IRaffle.Status.NftWon || t == IRaffle.Status.CashWon || t == IRaffle.Status.Refunding;
        }
        return false; // NftWon, CashWon, Refunding are terminal
    }

    function _afterAction() internal {
        for (uint256 i; i < raffles.length; ++i) {
            IRaffle r = IRaffle(raffles[i]);
            uint8 now_ = uint8(r.status());
            _check(_allowedTransition(lastStatus[address(r)], now_), "SM-1 illegal status transition", address(r));
            lastStatus[address(r)] = now_;
        }
    }

    function _call(Actor a, address target, uint256 value, bytes memory data) internal returns (bool ok) {
        (ok,) = a.exec{ value: value }(target, data);
    }

    // =====================================================================================================
    // actions
    // =====================================================================================================

    /// @notice Creates up to two raffles with fuzzed sponsor, reserve (1..40 entries) and duration (1s..30d).
    function createRaffle(uint8 sponsorSeed, uint128 reserveSeed, uint32 durationSeed) public {
        if (raffles.length >= MAX_RAFFLES) return;
        Actor sponsor = _actor(sponsorSeed);
        uint128 reserve = uint128(1 + (reserveSeed % 40));
        uint64 endTime = uint64(block.timestamp + 1 + (durationSeed % 30 days));
        uint256 tokenId = ++nextPrizeId;
        prize.mint(address(sponsor), tokenId);
        _call(sponsor, address(prize), 0, abi.encodeWithSignature("approve(address,uint256)", address(factory), tokenId));
        IRaffleFactory.CreateRaffleParams memory p = IRaffleFactory.CreateRaffleParams({
            sponsorRecipient: SPONSOR_RECIPIENT,
            prizeToken: address(prize),
            prizeTokenId: tokenId,
            reserveEntries: reserve,
            endTime: endTime
        });
        uint256 countBefore = factory.raffleCount();
        (bool ok, bytes memory ret) = sponsor.exec(address(factory), abi.encodeCall(IRaffleFactory.createRaffle, (p)));
        _check(ok, "AC-6 valid createRaffle must succeed", address(0));
        if (!ok) return;
        address r = abi.decode(ret, (address));
        raffles.push(r);
        prizeIdOf[r] = tokenId;
        lastStatus[r] = uint8(IRaffle(r).status());
        _check(IRaffle(r).status() == IRaffle.Status.Active, "SM-3 created raffle must be Active", r);
        _check(prize.ownerOf(tokenId) == r, "SM-3 prize escrowed atomically", r);
        _check(factory.isRaffle(r) && factory.raffleById(countBefore + 1) == r, "registry", r);
        _check(factory.idByRaffle(r) == countBefore + 1 && IRaffle(r).raffleId() == countBefore + 1, "raffleId", r);
        _check(IRaffle(r).sponsor() == address(sponsor) && IRaffle(r).protocolTreasury() == TREASURY, "config", r);
        _check(IRaffle(r).initialized(), "SM-2 initialized", r);
        _afterAction();
    }

    function _buy(IRaffle r, Actor buyer, Actor recipient, uint128 count) internal {
        uint256 cost = uint256(count) * PRICE;
        usdc.mint(address(buyer), cost);
        _call(buyer, address(usdc), 0, abi.encodeWithSignature("approve(address,uint256)", address(r), cost));
        uint128 total = r.totalEntries();
        uint128 tickets = r.ticketCount();
        uint256 pot = r.unsettledPot();
        bool expected = r.status() == IRaffle.Status.Active && block.timestamp < r.endTime()
            && count <= type(uint128).max - total;
        bool ok = _call(buyer, address(r), 0, abi.encodeCall(IRaffle.buyEntries, (address(recipient), count)));
        _check(ok == expected, "SM-4 buyEntries outcome", address(r));
        if (ok) {
            (uint128 f, uint128 l) = r.ticketRange(uint256(tickets) + 1);
            _check(r.ticketCount() == tickets + 1, "T-1 ticketCount++", address(r));
            _check(f == total + 1 && l == total + count, "T-1 contiguous range", address(r));
            _check(r.totalEntries() == total + count, "T-1 totalEntries", address(r));
            _check(r.unsettledPot() == pot + cost, "A-3 pot += cost", address(r));
            _check(_ownerOrZero(r, uint256(tickets) + 1) == address(recipient), "T ticket minted to recipient", address(r));
        }
        _afterAction();
    }

    /// @notice Normal purchase: 1..25 entries for any actor as recipient.
    function buy(uint8 raffleSeed, uint8 buyerSeed, uint8 recipientSeed, uint128 countSeed) public {
        (IRaffle r, bool ok) = _raffle(raffleSeed);
        if (!ok) return;
        _buy(r, _actor(buyerSeed), _actor(recipientSeed), uint128(1 + (countSeed % 25)));
    }

    /// @notice Arithmetic stress purchase: any positive uint128 entry count (funded exactly); exercises AR-1 and
    ///         TotalEntriesOverflow once totals approach uint128.max.
    function buyHuge(uint8 raffleSeed, uint8 buyerSeed, uint128 count) public {
        (IRaffle r, bool ok) = _raffle(raffleSeed);
        if (!ok || count == 0) return;
        _buy(r, _actor(buyerSeed), _actor(buyerSeed), count);
    }

    function requestDraw(uint8 raffleSeed, uint8 callerSeed, uint64 extraSeed) public {
        (IRaffle r, bool exists) = _pick(raffleSeed, IRaffle.Status.Active);
        if (!exists) return;
        Actor caller = _actor(callerSeed);
        uint256 fee = wrapper.fee();
        uint256 value = _drawValue(fee, extraSeed);
        bool expected = _drawExpected(r, value, fee);
        uint256 callerBefore = address(caller).balance;
        uint256 requestsBefore = wrapper.requestCount();
        bool ok = _call(caller, address(r), value, abi.encodeCall(IRaffle.requestDraw, ()));
        _check(ok == expected, "SM-5 requestDraw outcome", address(r));
        if (ok) {
            _checkRequestRecorded(r, fee, requestsBefore);
            _check(address(caller).balance == callerBefore + (value - fee), "EI-4 excess refunded", address(r));
        } else {
            // Actor.exec is payable and does not bubble the inner revert, so the forwarded ETH stays with the actor.
            _check(address(caller).balance == callerBefore + value, "no ETH lost on revert", address(r));
        }
        _afterAction();
    }

    function _drawValue(uint256 fee, uint64 extraSeed) internal view returns (uint256 value) {
        value = fee + (extraSeed % 1 ether);
        if (address(this).balance < value) value = address(this).balance < fee ? address(this).balance : fee;
    }

    function _drawExpected(IRaffle r, uint256 value, uint256 fee) internal view returns (bool) {
        uint256 endTime = r.endTime();
        return r.status() == IRaffle.Status.Active && block.timestamp >= endTime && r.totalEntries() > 0
            && block.timestamp < endTime + 2 days && value >= fee;
    }

    function _checkRequestRecorded(IRaffle r, uint256 fee, uint256 requestsBefore) internal {
        uint256 id = wrapper.lastRequestId();
        _check(r.status() == IRaffle.Status.Drawing, "SM-5 Drawing", address(r));
        _check(r.vrfRequestId() == id, "SM-5 request id recorded", address(r));
        _check(r.drawRequestedAt() == block.timestamp, "SM-5 drawRequestedAt", address(r));
        _check(address(r).balance == 0, "EI-4 no ETH retained", address(r));
        _check(wrapper.requestCount() == requestsBefore + 1, "SM-5 single request", address(r));
        _checkVrfParams(id, address(r), fee);
        if (wrapper.syncCallback()) {
            _check(r.winningEntry() == 0, "SM-6 synchronous callback ignored", address(r));
            _check(wrapper.lastSyncCallbackSucceeded(), "EI-3 in-flight callback did not revert", address(r));
        }
    }

    function _checkVrfParams(uint256 id, address raffle, uint256 fee) internal {
        (address consumer, uint32 gasLimit, uint16 confirmations, uint32 numWords, uint256 paid) = wrapper.requests(id);
        _check(consumer == raffle, "SM-5 consumer", raffle);
        _check(gasLimit == 300_000 && confirmations == 30 && numWords == 1 && paid == fee, "EI VRF params", raffle);
    }

    /// @notice mode%8: 0-4 correct id + 1 word; 5 wrong id; 6 zero words; 7 two words (mapped to modes 0..3).
    function fulfill(uint8 raffleSeed, uint256 word, uint8 mode) public {
        (IRaffle r, bool exists) = _pick(raffleSeed, IRaffle.Status.Drawing);
        if (!exists) return;
        FulfillCtx memory c;
        c.mode = mode % 8 < 5 ? 0 : (mode % 8) - 4;
        c.id = r.vrfRequestId();
        if (c.mode == 1) c.id = c.id + 1 + (word % 7);
        uint256[] memory words = new uint256[](c.mode == 2 ? 0 : (c.mode == 3 ? 2 : 1));
        if (words.length > 0) words[0] = word;
        if (words.length > 1) words[1] = ~word;
        c.before = r.status();
        c.total = r.totalEntries();
        c.expected = c.before == IRaffle.Status.Drawing && c.mode == 0 && block.timestamp < r.callbackDeadline()
            && c.id == r.vrfRequestId();
        c.winBefore = r.winningEntry();
        (bool ok, uint256 gasUsed) = wrapper.fulfill(address(r), c.id, words);
        _check(ok, "EI-3 authenticated callback never reverts", address(r));
        _check(gasUsed < 120_000, "EI-3 callback gas well under 300k", address(r));
        if (c.expected) {
            _checkResolved(r, word, c.total);
        } else {
            _check(r.status() == c.before && r.winningEntry() == c.winBefore, "SM-6 ignored callback is a no-op", address(r));
        }
        _afterAction();
    }

    struct FulfillCtx {
        uint8 mode;
        uint256 id;
        IRaffle.Status before;
        uint128 total;
        bool expected;
        uint128 winBefore;
    }

    function _checkResolved(IRaffle r, uint256 word, uint128 total) internal {
        IRaffle.Status s = r.status();
        uint128 w = r.winningEntry();
        _check(s == IRaffle.Status.NftWon || s == IRaffle.Status.CashWon, "SM-9 resolved", address(r));
        _check(w == uint128((word % uint256(total)) + 1) && w >= 1 && w <= total, "SM-9/AR-3 winningEntry", address(r));
        _check((s == IRaffle.Status.NftWon) == (total >= r.reserveEntries()), "SM-9 reserve rule", address(r));
        _check(r.resolvedAt() == block.timestamp, "SM-9 resolvedAt", address(r));
    }

    function enableRefunds(uint8 raffleSeed, uint8 callerSeed, bool asSponsor) public {
        (IRaffle r, bool exists) = _raffle(raffleSeed);
        if (!exists) return;
        Actor caller = asSponsor ? Actor(payable(r.sponsor())) : _actor(callerSeed);
        IRaffle.Status s = r.status();
        bool expected;
        if (s == IRaffle.Status.Active) {
            if (r.totalEntries() == 0) {
                expected = address(caller) == r.sponsor() || block.timestamp >= r.endTime();
            } else {
                expected = block.timestamp >= uint256(r.endTime()) + 2 days;
            }
        } else if (s == IRaffle.Status.Drawing) {
            expected = block.timestamp >= uint256(r.drawRequestedAt()) + 2 days;
        }
        uint256 pot = r.unsettledPot();
        bool ok = _call(caller, address(r), 0, abi.encodeCall(IRaffle.enableRefunds, ()));
        _check(ok == expected, "SM-7 enableRefunds outcome", address(r));
        if (ok) {
            _check(r.status() == IRaffle.Status.Refunding, "SM-7 Refunding", address(r));
            _check(r.remainingRefundLiability() == pot && r.unsettledPot() == 0, "A-4 liability = pot", address(r));
        }
        _afterAction();
    }

    function settle(uint8 raffleSeed, uint256 ticketSeed, bool smart) public {
        (IRaffle r, bool exists) = _pick(raffleSeed, raffleSeed % 2 == 0 ? IRaffle.Status.NftWon : IRaffle.Status.CashWon);
        if (!exists) return;
        uint256 id = smart ? _winningTicket(r) : ticketSeed % (uint256(r.ticketCount()) + 2);
        IRaffle.Status s = r.status();
        bool expected = (s == IRaffle.Status.NftWon || s == IRaffle.Status.CashWon) && !r.settlementComplete()
            && _rangeContainsWinner(r, id);
        uint256 gross = r.unsettledPot();
        bool ok = _call(_actor(uint8(ticketSeed)), address(r), 0, abi.encodeCall(IRaffle.settleWinningTicket, (id)));
        _check(ok == expected, "SM-10 settle outcome", address(r));
        if (ok) _checkSplit(r, s, gross, id, false);
        _afterAction();
    }

    function _rangeContainsWinner(IRaffle r, uint256 id) internal view returns (bool) {
        (uint128 f, uint128 l) = r.ticketRange(id);
        uint128 w = r.winningEntry();
        return w >= f && w <= l;
    }

    /// @param cashPaidOut True when settlement ran inside redeemWinningTicket(CashWon): the cash claim has already been
    ///        delivered (and zeroed); its amount is verified separately against the caller's USDC balance delta.
    function _checkSplit(IRaffle r, IRaffle.Status s, uint256 gross, uint256 id, bool cashPaidOut) internal {
        uint256 fee = gross * 500 / 10_000;
        uint256 cash = s == IRaffle.Status.CashWon ? gross * 8000 / 10_000 : 0;
        _check(gross == r.grossSales(), "A-6 pot equals gross sales at settlement", address(r));
        _check(r.protocolFees() == fee, "A-5 protocol fee floor(5%)", address(r));
        _check(r.winnerProceeds() == (cashPaidOut ? 0 : cash), "A-5 cash floor(80%) or 0", address(r));
        _check(r.sponsorProceeds() == gross - fee - cash, "A-5 sponsor remainder", address(r));
        _check(fee + cash + (gross - fee - cash) == gross && r.unsettledPot() == 0, "A-5 exact split", address(r));
        _check(r.settlementComplete() && r.winningTicketId() == id, "SM-10 recorded", address(r));
        settledSeen[address(r)] = true;
    }

    function redeem(uint8 raffleSeed, uint8 callerSeed, uint256 ticketSeed, bool smart) public {
        (IRaffle r, bool exists) = _pick(raffleSeed, raffleSeed % 2 == 0 ? IRaffle.Status.NftWon : IRaffle.Status.CashWon);
        if (!exists) return;
        RedeemCtx memory c;
        c.id = smart ? _winningTicket(r) : ticketSeed % (uint256(r.ticketCount()) + 2);
        c.owner = _ownerOrZero(r, c.id);
        c.caller = smart && c.owner != address(0) && _isActor(c.owner) ? Actor(payable(c.owner)) : _actor(callerSeed);
        c.status = r.status();
        c.settled = r.settlementComplete();
        c.gross = r.unsettledPot();
        c.expected = _redeemExpected(r, c);
        c.balBefore = usdc.balanceOf(address(c.caller));
        bool ok = _call(c.caller, address(r), 0, abi.encodeCall(IRaffle.redeemWinningTicket, (c.id)));
        _check(ok == c.expected, "SM-11 redeem outcome", address(r));
        if (ok) _checkRedeemed(r, c);
        _afterAction();
    }

    struct RedeemCtx {
        uint256 id;
        address owner;
        Actor caller;
        IRaffle.Status status;
        bool settled;
        uint256 gross;
        uint256 expectedCash;
        bool expected;
        uint256 balBefore;
    }

    function _redeemExpected(IRaffle r, RedeemCtx memory c) internal view returns (bool expected) {
        bool won = c.status == IRaffle.Status.NftWon || c.status == IRaffle.Status.CashWon;
        expected = !r.winnerRedeemed() && won
            && (c.settled ? c.id == r.winningTicketId() : _rangeContainsWinner(r, c.id)) && c.owner != address(0)
            && c.owner == address(c.caller) && (c.status == IRaffle.Status.NftWon ? !r.prizeClaimed() : true);
        if (c.status == IRaffle.Status.CashWon) {
            c.expectedCash = c.settled ? r.winnerProceeds() : c.gross * 8000 / 10_000;
            if (c.expectedCash == 0) expected = false;
        }
    }

    function _checkRedeemed(IRaffle r, RedeemCtx memory c) internal {
        if (!c.settled) _checkSplit(r, c.status, c.gross, c.id, c.status == IRaffle.Status.CashWon);
        _check(r.winnerRedeemed() && r.winnerRecipient() == address(c.caller), "SM-11 recorded", address(r));
        _check(_ownerOrZero(r, c.id) == address(0), "SM-11 ticket burned", address(r));
        if (c.status == IRaffle.Status.NftWon) {
            _check(prize.ownerOf(prizeIdOf[address(r)]) == address(c.caller) && r.prizeClaimed(), "EI-2 NFT delivered", address(r));
        } else {
            _check(usdc.balanceOf(address(c.caller)) == c.balBefore + c.expectedCash, "EI-2 cash delivered", address(r));
            _check(r.winnerProceeds() == 0, "A cash claim zeroed", address(r));
        }
    }

    function _isActor(address a) internal view returns (bool) {
        for (uint256 i; i < N_ACTORS; ++i) {
            if (address(actors[i]) == a) return true;
        }
        return false;
    }

    /// @notice Refund up to `howMany` of the caller's tickets; optionally inject a duplicate, foreign or nonexistent ID.
    function refund(uint8 raffleSeed, uint8 callerSeed, uint8 howMany, uint8 corruption) public {
        (IRaffle r, bool exists) = _pick(raffleSeed, IRaffle.Status.Refunding);
        if (!exists) return;
        Actor caller = _actor(callerSeed);
        (uint256[] memory ids, uint256 entries, bool clean) = _refundBatch(r, address(caller), howMany, corruption);
        bool expected = r.status() == IRaffle.Status.Refunding && ids.length > 0 && ids.length <= 100 && clean;
        uint256 liability = r.remainingRefundLiability();
        uint256 balBefore = usdc.balanceOf(address(caller));
        bool ok = _call(caller, address(r), 0, abi.encodeCall(IRaffle.refundTickets, (ids)));
        _check(ok == expected, "A-7 refund outcome", address(r));
        if (ok) {
            _check(usdc.balanceOf(address(caller)) == balBefore + entries * PRICE, "A-7 refund amount", address(r));
            _check(r.remainingRefundLiability() == liability - entries * PRICE, "A-7 liability decrement", address(r));
            for (uint256 i; i < ids.length; ++i) {
                _check(_ownerOrZero(r, ids[i]) == address(0), "T-4 refunded tickets burned", address(r));
            }
        }
        _afterAction();
    }

    function _refundBatch(IRaffle r, address caller, uint8 howMany, uint8 corruption)
        internal
        view
        returns (uint256[] memory ids, uint256 entries, bool clean)
    {
        uint256 n = r.ticketCount();
        uint256 want = 1 + (uint256(howMany) % 8);
        uint256[] memory tmp = new uint256[](want + 1);
        uint256 k;
        for (uint256 i = 1; i <= n && k < want; ++i) {
            if (_ownerOrZero(r, i) == caller) {
                tmp[k++] = i;
                (uint128 f, uint128 l) = r.ticketRange(i);
                entries += uint256(l) - uint256(f) + 1;
            }
        }
        clean = true;
        corruption = corruption % 4;
        if (corruption == 1 && k > 0) {
            tmp[k++] = tmp[0]; // duplicate
            clean = false;
        } else if (corruption == 2) {
            for (uint256 i = 1; i <= n; ++i) {
                address o = _ownerOrZero(r, i);
                if (o != address(0) && o != caller) {
                    tmp[k++] = i; // foreign-owned
                    clean = false;
                    break;
                }
            }
        } else if (corruption == 3) {
            tmp[k++] = n + 1; // nonexistent
            clean = false;
        }
        ids = new uint256[](k);
        for (uint256 i; i < k; ++i) {
            ids[i] = tmp[i];
        }
    }

    function releaseSponsorProceeds(uint8 raffleSeed, uint8 callerSeed) public {
        (IRaffle r, bool exists) = _pick(raffleSeed, raffleSeed % 2 == 0 ? IRaffle.Status.NftWon : IRaffle.Status.CashWon);
        if (!exists) return;
        uint256 amount = r.sponsorProceeds();
        uint256 before = usdc.balanceOf(SPONSOR_RECIPIENT);
        bool ok = _call(_actor(callerSeed), address(r), 0, abi.encodeCall(IRaffle.releaseSponsorProceeds, ()));
        _check(ok == (amount > 0), "release sponsor outcome", address(r));
        if (ok) _check(usdc.balanceOf(SPONSOR_RECIPIENT) == before + amount && r.sponsorProceeds() == 0, "A-8 sponsor paid", address(r));
        _afterAction();
    }

    function releaseProtocolFees(uint8 raffleSeed, uint8 callerSeed) public {
        (IRaffle r, bool exists) = _pick(raffleSeed, raffleSeed % 2 == 0 ? IRaffle.Status.NftWon : IRaffle.Status.CashWon);
        if (!exists) return;
        uint256 amount = r.protocolFees();
        uint256 before = usdc.balanceOf(TREASURY);
        bool ok = _call(_actor(callerSeed), address(r), 0, abi.encodeCall(IRaffle.releaseProtocolFees, ()));
        _check(ok == (amount > 0), "release fees outcome", address(r));
        if (ok) _check(usdc.balanceOf(TREASURY) == before + amount && r.protocolFees() == 0, "A-8 treasury paid", address(r));
        _afterAction();
    }

    function releaseSponsorPrize(uint8 raffleSeed, uint8 callerSeed) public {
        (IRaffle r, bool exists) = _pick(raffleSeed, raffleSeed % 2 == 0 ? IRaffle.Status.CashWon : IRaffle.Status.Refunding);
        if (!exists) return;
        IRaffle.Status s = r.status();
        bool expected = (s == IRaffle.Status.CashWon || s == IRaffle.Status.Refunding) && !r.prizeClaimed();
        bool ok = _call(_actor(callerSeed), address(r), 0, abi.encodeCall(IRaffle.releaseSponsorPrize, ()));
        _check(ok == expected, "SM-12 releaseSponsorPrize outcome", address(r));
        if (ok) _check(prize.ownerOf(prizeIdOf[address(r)]) == SPONSOR_RECIPIENT, "SM-12 prize returned", address(r));
        _afterAction();
    }

    /// @notice destMode 0: another actor (must succeed for the owner); 1..6: protocol destinations (must revert).
    function transferTicket(uint8 raffleSeed, uint256 ticketSeed, uint8 toSeed, uint8 destMode) public {
        (IRaffle r, bool exists) = _raffle(raffleSeed);
        if (!exists) return;
        uint256 id = 1 + ticketSeed % (uint256(r.ticketCount()) + 1);
        address owner = _ownerOrZero(r, id);
        if (owner == address(0) || !_isActor(owner)) return;
        destMode = destMode % 7;
        address to;
        if (destMode == 0) to = address(_actor(toSeed));
        else if (destMode == 1) to = address(r);
        else if (destMode == 2) to = address(factory);
        else if (destMode == 3) to = implementation;
        else if (destMode == 4) to = address(usdc);
        else if (destMode == 5) to = address(wrapper);
        else to = raffles.length > 1 ? raffles[(raffleSeed + 1) % raffles.length] : address(prize);
        bool expected = !_isProtocolAddress(to);
        bool ok = _call(Actor(payable(owner)), address(r), 0,
            abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", owner, to, id));
        _check(ok == expected, "T-3 ticket transfer destination screening", address(r));
        if (ok) _check(_ownerOrZero(r, id) == to, "bearer transfer", address(r));
        _afterAction();
    }

    /// @notice Search shortcut: jump to a point inside the draw window, request, then deliver one authenticated word.
    ///         Every step runs through the same checked actions (expected-outcome + postconditions).
    function fastDrawAndResolve(uint8 raffleSeed, uint8 callerSeed, uint256 word, uint32 offset) public {
        (IRaffle r, bool exists) = _pick(raffleSeed, IRaffle.Status.Active);
        if (!exists || r.status() != IRaffle.Status.Active || r.totalEntries() == 0) return;
        uint256 target = uint256(r.endTime()) + (uint256(offset) % 2 days);
        if (target > block.timestamp) HEVM.warp(target);
        uint256 before = wrapper.requestCount();
        requestDraw(raffleSeed, callerSeed, 0);
        if (wrapper.requestCount() == before + 1) fulfill(raffleSeed, word, 0);
    }

    function warp(uint32 delta) public {
        HEVM.warp(block.timestamp + (uint256(delta) % 3 days));
        _afterAction();
    }

    function warpToBoundary(uint8 raffleSeed, uint8 which, int8 offset) public {
        (IRaffle r, bool exists) = _raffle(raffleSeed);
        if (!exists) return;
        uint256 target;
        which = which % 3;
        if (which == 0) target = r.endTime();
        else if (which == 1) target = r.drawRequestDeadline();
        else target = r.callbackDeadline();
        int256 t = int256(target) + int256(offset % 3);
        if (t > int256(block.timestamp)) HEVM.warp(uint256(t));
        _afterAction();
    }

    function setVrfFee(uint64 newFee) public {
        wrapper.setFee(uint256(newFee) % 0.05 ether);
    }

    function toggleSyncCallback() public {
        wrapper.setSyncCallback(!wrapper.syncCallback());
    }

    function donate(uint8 raffleSeed, uint32 amount) public {
        (IRaffle r, bool exists) = _raffle(raffleSeed);
        if (!exists || amount == 0) return;
        usdc.mint(address(this), amount);
        usdc.transfer(address(r), amount);
        donated[address(r)] += amount;
        _afterAction();
    }

    // ---- adversarial attempts that must always fail ----

    function attackInitialize(uint8 raffleSeed, uint8 callerSeed, bool targetImplementation) public {
        address target = implementation;
        if (!targetImplementation) {
            (IRaffle r, bool exists) = _raffle(raffleSeed);
            if (!exists) return;
            target = address(r);
        }
        IRaffle.RaffleInitParams memory p = IRaffle.RaffleInitParams({
            sponsor: address(_actor(callerSeed)),
            sponsorRecipient: address(_actor(callerSeed)),
            protocolTreasury: address(_actor(callerSeed)),
            prizeToken: address(prize),
            prizeTokenId: 999_999,
            raffleId: 77,
            reserveEntries: 1,
            endTime: uint64(block.timestamp + 1)
        });
        bool ok = _call(_actor(callerSeed), target, 0, abi.encodeCall(IRaffle.initialize, (p)));
        _check(!ok, "AC-1/SM-2 re-initialization or non-factory init succeeded", target);
        _afterAction();
    }

    function attackDirectFulfill(uint8 raffleSeed, uint8 callerSeed, uint256 word) public {
        (IRaffle r, bool exists) = _raffle(raffleSeed);
        if (!exists) return;
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        bool ok = _call(_actor(callerSeed), address(r), 0,
            abi.encodeWithSignature("rawFulfillRandomWords(uint256,uint256[])", r.vrfRequestId(), words));
        _check(!ok, "AC-2 non-wrapper fulfillment succeeded", address(r));
        _afterAction();
    }

    function attackSpoofPrizeHook(uint8 raffleSeed, uint8 callerSeed) public {
        (IRaffle r, bool exists) = _raffle(raffleSeed);
        if (!exists) return;
        bool ok = _call(_actor(callerSeed), address(r), 0, abi.encodeWithSignature(
            "onERC721Received(address,address,uint256,bytes)", address(factory), r.sponsor(), prizeIdOf[address(r)], ""));
        _check(!ok, "AC-3 spoofed prize hook accepted", address(r));
        _afterAction();
    }

    function attackDirectEth(uint8 raffleSeed, uint64 amount) public {
        (IRaffle r, bool exists) = _raffle(raffleSeed);
        if (!exists || amount == 0 || address(this).balance < amount) return;
        (bool ok,) = address(r).call{ value: amount }("");
        _check(!ok, "EI-4 direct ETH accepted", address(r));
        _afterAction();
    }

    // =====================================================================================================
    // global invariants (property mode)
    // =====================================================================================================

    function echidna_no_action_violations() public view returns (bool) {
        return violations == 0;
    }

    /// A-1/A-2: exact solvency and conservation per raffle (donations stay outside accounting, never paid out).
    function echidna_solvency_and_conservation() public view returns (bool) {
        for (uint256 i; i < raffles.length; ++i) {
            IRaffle r = IRaffle(raffles[i]);
            uint256 accounted = r.accountedQuoteBalance();
            if (usdc.balanceOf(address(r)) != accounted + donated[address(r)]) return false;
            if (usdc.totalSentBy(address(r)) + accounted != r.grossSales()) return false;
            if (usdc.totalReceivedBy(address(r)) != r.grossSales() + donated[address(r)]) return false;
        }
        return true;
    }

    /// A-3/A-4/A-6 + SM: per-status bucket shape.
    function echidna_status_bucket_shape() public view returns (bool) {
        for (uint256 i; i < raffles.length; ++i) {
            IRaffle r = IRaffle(raffles[i]);
            IRaffle.Status s = r.status();
            uint256 gross = r.grossSales();
            if (s == IRaffle.Status.AwaitingPrize) return false;
            if (s == IRaffle.Status.Active || s == IRaffle.Status.Drawing) {
                if (r.unsettledPot() != gross || r.remainingRefundLiability() != 0 || r.winnerProceeds() != 0
                    || r.sponsorProceeds() != 0 || r.protocolFees() != 0 || r.settlementComplete()
                    || r.winningEntry() != 0) return false;
                if (s == IRaffle.Status.Active && (r.vrfRequestId() != 0 || r.drawRequestedAt() != 0)) return false;
            } else if (s == IRaffle.Status.Refunding) {
                if (r.unsettledPot() != 0 || r.winnerProceeds() != 0 || r.sponsorProceeds() != 0
                    || r.protocolFees() != 0 || r.settlementComplete()) return false;
            } else {
                if (r.remainingRefundLiability() != 0) return false;
                if (!r.settlementComplete() && r.unsettledPot() != gross) return false;
                if (r.settlementComplete() && r.unsettledPot() != 0) return false;
                if (s == IRaffle.Status.NftWon && r.winnerProceeds() != 0) return false;
                if (r.winnerRedeemed() && !r.settlementComplete()) return false;
            }
        }
        return true;
    }

    /// T-1/T-2/T-5: ticket ranges partition [1,totalEntries] in order.
    function echidna_ticket_ranges_partition() public view returns (bool) {
        for (uint256 i; i < raffles.length; ++i) {
            IRaffle r = IRaffle(raffles[i]);
            uint256 n = r.ticketCount();
            uint256 expectedFirst = 1;
            for (uint256 t = 1; t <= n; ++t) {
                (uint128 f, uint128 l) = r.ticketRange(t);
                if (f != expectedFirst || l < f) return false;
                expectedFirst = uint256(l) + 1;
            }
            if (expectedFirst - 1 != r.totalEntries()) return false;
            (uint128 f0, uint128 l0) = r.ticketRange(n + 1);
            if (f0 != 0 || l0 != 0) return false;
        }
        return true;
    }

    /// A-4: in Refunding, liability equals the full price of every live (unburned) ticket.
    function echidna_refund_liability_matches_live_tickets() public view returns (bool) {
        for (uint256 i; i < raffles.length; ++i) {
            IRaffle r = IRaffle(raffles[i]);
            if (r.status() != IRaffle.Status.Refunding) continue;
            uint256 live;
            uint256 n = r.ticketCount();
            for (uint256 t = 1; t <= n; ++t) {
                if (_ownerOrZero(r, t) != address(0)) {
                    (uint128 f, uint128 l) = r.ticketRange(t);
                    live += uint256(l) - uint256(f) + 1;
                }
            }
            if (r.remainingRefundLiability() != live * PRICE) return false;
        }
        return true;
    }

    /// SM-12/EI-2: prize custody follows the lifecycle exactly.
    function echidna_prize_custody() public view returns (bool) {
        for (uint256 i; i < raffles.length; ++i) {
            IRaffle r = IRaffle(raffles[i]);
            address holder = prize.ownerOf(prizeIdOf[address(r)]);
            if (!r.prizeClaimed()) {
                if (holder != address(r)) return false;
            } else if (r.status() == IRaffle.Status.NftWon) {
                if (holder != r.winnerRecipient() || !r.winnerRedeemed()) return false;
            } else if (r.status() == IRaffle.Status.CashWon || r.status() == IRaffle.Status.Refunding) {
                if (holder != SPONSOR_RECIPIENT) return false;
            } else {
                return false;
            }
        }
        return true;
    }

    /// SM-9: resolution outcome well-formed.
    function echidna_resolution_well_formed() public view returns (bool) {
        for (uint256 i; i < raffles.length; ++i) {
            IRaffle r = IRaffle(raffles[i]);
            IRaffle.Status s = r.status();
            if (s == IRaffle.Status.NftWon || s == IRaffle.Status.CashWon) {
                uint128 w = r.winningEntry();
                if (w == 0 || w > r.totalEntries()) return false;
                if ((s == IRaffle.Status.NftWon) != (r.totalEntries() >= r.reserveEntries())) return false;
                if (r.resolvedAt() == 0 || r.drawRequestedAt() == 0) return false;
                if (r.resolvedAt() >= uint256(r.drawRequestedAt()) + 2 days) return false;
            }
        }
        return true;
    }

    /// T-3: no live ticket is owned by protocol plumbing.
    function echidna_no_ticket_owned_by_protocol() public view returns (bool) {
        for (uint256 i; i < raffles.length; ++i) {
            IRaffle r = IRaffle(raffles[i]);
            uint256 n = r.ticketCount();
            for (uint256 t = 1; t <= n; ++t) {
                address o = _ownerOrZero(r, t);
                if (o != address(0) && _isProtocolAddress(o)) return false;
            }
        }
        return true;
    }

    /// EI-4 + SM-2: no ETH retained; implementation stays inert and locked.
    function echidna_no_eth_and_inert_implementation() public view returns (bool) {
        for (uint256 i; i < raffles.length; ++i) {
            if (raffles[i].balance != 0) return false;
        }
        IRaffle impl = IRaffle(implementation);
        return impl.initialized() && impl.status() == IRaffle.Status.Refunding && impl.ticketCount() == 0
            && implementation.balance == 0;
    }
}

interface IERC721View {
    function ownerOf(uint256 tokenId) external view returns (address);
}

/// @notice Assertion-mode variant: identical actions, but every expectation failure is an immediate assert(false).
contract RaffleAssertionHarness is RafflePropertiesHarness {
    /// @dev Explicitly payable: a derived contract without its own constructor gets a non-payable default one, which
    ///      rejects the fuzzer's initial balance (first assertion-campaign launch failed to deploy for this reason).
    constructor() payable { }

    function _check(bool ok, string memory id, address raffle) internal override {
        if (!ok) {
            emit Violation(id, raffle);
            assert(false);
        }
    }
}
