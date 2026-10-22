// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IRaffle } from "raffle/interfaces/IRaffle.sol";
import { IRaffleFactory } from "raffle/interfaces/IRaffleFactory.sol";
import { Raffle } from "raffle/Raffle.sol";
import { RaffleFactory } from "raffle/RaffleFactory.sol";

import { FactoryDeployer } from "./FactoryDeployer.sol";
import { Actor } from "./mocks/Actor.sol";
import { MockPrizeNFT } from "./mocks/MockPrizeNFT.sol";
import { MockUSDC } from "./mocks/MockUSDC.sol";
import { MockVRFV2PlusWrapper } from "./mocks/MockVRFV2PlusWrapper.sol";

interface IHevm {
    function warp(uint256) external;
}

/// @notice Stateful fuzzing handler shared by Echidna (property mode) and Foundry (invariant mode).
/// @dev Every action computes the outcome the specification (DESIGN.md + IRaffle natspec) predicts, executes it through
///      an Actor, and records a violation on any mismatch or wrong post-state. `checkInvariants` holds the global
///      properties. Violations are recorded instead of asserted so that Foundry's fail_on_revert=false cannot hide them.
contract RaffleHandler {
    IHevm internal constant HEVM = IHevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    uint256 internal constant PRICE = 1_000_000;
    uint256 internal constant MAX_RAFFLES = 3;
    uint256 internal constant MAX_TICKETS = 24;
    uint256 internal constant N_ACTORS = 4;
    address public constant TREASURY = address(0x7EA5);

    MockUSDC public usdc;
    MockVRFV2PlusWrapper public wrapper;
    MockPrizeNFT public nft;
    RaffleFactory public factory;
    Actor[] public actors;
    Raffle[] public raffles;
    uint256 public nextPrizeId;

    struct Ghost {
        uint256 bought;
        uint256 paidOut;
        uint256 donated;
        uint256 feeAtSettle;
        uint256 sponsorAtSettle;
        uint256 winnerAtSettle;
    }

    mapping(address => Ghost) public ghost;
    mapping(address => uint256[]) internal _tickets;
    mapping(address => mapping(uint256 => bool)) public burned;
    mapping(address => uint256) public sponsorActorOf;

    uint256 public violations;
    string public lastViolation;
    mapping(bytes32 => uint256) public hits;

    event Violation(string why);

    constructor(MockUSDC usdc_, MockVRFV2PlusWrapper wrapper_, MockPrizeNFT nft_, FactoryDeployer deployer_) payable {
        usdc = usdc_;
        wrapper = wrapper_;
        nft = nft_;
        factory = deployer_.deploy(address(usdc), address(wrapper), TREASURY);
        for (uint256 i; i < N_ACTORS; ++i) {
            actors.push(new Actor());
        }
        _createRaffle(0, 5, 3 days);
        require(raffles.length == 1, "seed raffle");
    }

    receive() external payable { }

    // ------------------------------------------------------------------ helpers

    function _bound(uint256 x, uint256 lo, uint256 hi) internal pure returns (uint256) {
        if (hi <= lo) return lo;
        return lo + (x % (hi - lo + 1));
    }

    function _fail(string memory why) internal {
        ++violations;
        lastViolation = why;
        emit Violation(why);
    }

    function _raffle(uint256 seed) internal view returns (Raffle) {
        return raffles[seed % raffles.length];
    }

    function _actor(uint256 seed) internal view returns (Actor) {
        return actors[seed % N_ACTORS];
    }

    function _ownerOrZero(Raffle r, uint256 id) internal view returns (address) {
        try r.ownerOf(id) returns (address o) {
            return o;
        } catch {
            return address(0);
        }
    }

    function _winningTicket(Raffle r) internal view returns (uint256) {
        uint128 w = r.winningEntry();
        uint256[] storage ts = _tickets[address(r)];
        for (uint256 i; i < ts.length; ++i) {
            (uint128 f, uint128 l) = r.ticketRange(ts[i]);
            if (w != 0 && w >= f && w <= l) return ts[i];
        }
        return 0;
    }

    function _anyTicketId(Raffle r, uint256 seed) internal view returns (uint256) {
        // includes id 0 and one past the last minted id
        return _bound(seed, 0, uint256(r.ticketCount()) + 1);
    }

    function _isProtocol(address a) internal view returns (bool) {
        return a == address(factory) || a == address(usdc) || a == address(wrapper) || a == address(nft)
            || a == factory.raffleImplementation() || factory.isRaffle(a);
    }

    function _usdcMovable(address from, address to) internal view returns (bool) {
        return !usdc.paused() && !usdc.blocked(from) && !usdc.blocked(to);
    }

    function _resolved(IRaffle.Status st) internal pure returns (bool) {
        return st == IRaffle.Status.NftWon || st == IRaffle.Status.CashWon;
    }

    // ------------------------------------------------------------------ environment actions

    function warp(uint256 dtSeed) public {
        HEVM.warp(block.timestamp + _bound(dtSeed, 1, 3 days));
    }

    function donate(uint256 raffleSeed, uint256 amountSeed) public {
        Raffle r = _raffle(raffleSeed);
        uint256 amount = _bound(amountSeed, 1, 5e6);
        usdc.mint(address(r), amount);
        ghost[address(r)].donated += amount;
    }

    /// @dev Biased so the failure mode is active ~25% of the time (keeps deep success paths reachable).
    function toggleNftFrozen(uint256 seed) public {
        nft.setFrozen(seed % 4 == 0);
    }

    function toggleUsdcPaused(uint256 seed) public {
        usdc.setPaused(seed % 4 == 0);
    }

    function setVrfPrice(uint256 seed) public {
        wrapper.setPrice(_bound(seed, 0, 0.05 ether));
    }

    // ------------------------------------------------------------------ factory

    function createRaffle(uint256 sponsorSeed, uint256 reserveSeed, uint256 durationSeed) public {
        if (raffles.length >= MAX_RAFFLES) return;
        _createRaffle(sponsorSeed % N_ACTORS, uint128(_bound(reserveSeed, 0, 30)), _bound(durationSeed, 0, 31 days));
    }

    function _createRaffle(uint256 sponsorIdx, uint128 reserve, uint256 duration) internal {
        Actor sponsor = actors[sponsorIdx];
        uint256 prizeId = ++nextPrizeId;
        nft.mint(address(sponsor), prizeId);
        sponsor.exec(address(nft), abi.encodeCall(nft.approve, (address(factory), prizeId)));
        IRaffleFactory.CreateRaffleParams memory p = IRaffleFactory.CreateRaffleParams({
            sponsorRecipient: address(uint160(0x5000 + raffles.length + 1)),
            prizeToken: address(nft),
            prizeTokenId: prizeId,
            reserveEntries: reserve,
            endTime: uint64(block.timestamp + duration)
        });
        bool expectOk = duration > 0 && duration <= 30 days && reserve > 0 && !nft.frozen();
        (bool ok, bytes memory ret) = sponsor.exec(address(factory), abi.encodeCall(factory.createRaffle, (p)));
        if (ok != expectOk) _fail("createRaffle: outcome mismatch");
        if (!ok) return;
        Raffle r = Raffle(payable(abi.decode(ret, (address))));
        raffles.push(r);
        sponsorActorOf[address(r)] = sponsorIdx;
        if (r.status() != IRaffle.Status.Active) _fail("createRaffle: not Active");
        if (nft.ownerOf(prizeId) != address(r)) _fail("createRaffle: prize not escrowed");
        if (!factory.isRaffle(address(r))) _fail("createRaffle: not registered");
        if (r.sponsor() != address(sponsor) || r.protocolTreasury() != TREASURY) _fail("createRaffle: config");
        ++hits["createRaffle"];
    }

    // ------------------------------------------------------------------ raffle actions

    struct BuySnap {
        uint128 count;
        uint128 totalBefore;
        uint128 countBefore;
        uint256 cost;
        uint256 balBefore;
        bool expectOk;
    }

    function buy(uint256 raffleSeed, uint256 buyerSeed, uint256 recipientSeed, uint256 countSeed) public {
        Raffle r = _raffle(raffleSeed);
        if (_tickets[address(r)].length >= MAX_TICKETS) return;
        Actor buyer = _actor(buyerSeed);
        address recipient = address(_actor(recipientSeed));
        BuySnap memory s;
        s.count = uint128(_bound(countSeed, 1, 20));
        s.cost = uint256(s.count) * PRICE;
        usdc.mint(address(buyer), s.cost);
        buyer.exec(address(usdc), abi.encodeCall(usdc.approve, (address(r), s.cost)));
        s.totalBefore = r.totalEntries();
        s.countBefore = r.ticketCount();
        s.balBefore = usdc.balanceOf(address(r));
        s.expectOk = r.status() == IRaffle.Status.Active && block.timestamp < r.endTime()
            && _usdcMovable(address(buyer), address(r));
        (bool ok, bytes memory ret) = buyer.exec(address(r), abi.encodeCall(r.buyEntries, (recipient, s.count)));
        if (ok != s.expectOk) _fail("buy: outcome mismatch");
        if (!ok) return;
        _afterBuy(r, recipient, s, abi.decode(ret, (uint256)));
    }

    function _afterBuy(Raffle r, address recipient, BuySnap memory s, uint256 ticketId) internal {
        _tickets[address(r)].push(ticketId);
        ghost[address(r)].bought += s.cost;
        (uint128 first, uint128 last) = r.ticketRange(ticketId);
        if (ticketId != uint256(s.countBefore) + 1) _fail("buy: ticket id not sequential");
        if (first != s.totalBefore + 1 || last != s.totalBefore + s.count) _fail("buy: wrong range");
        if (r.ownerOf(ticketId) != recipient) _fail("buy: wrong owner");
        if (usdc.balanceOf(address(r)) != s.balBefore + s.cost) _fail("buy: wrong payment");
        ++hits["buy"];
    }

    function transferTicket(uint256 raffleSeed, uint256 ticketSeed, uint256 toSeed) public {
        Raffle r = _raffle(raffleSeed);
        uint256[] storage ts = _tickets[address(r)];
        if (ts.length == 0) return;
        uint256 id = ts[ticketSeed % ts.length];
        if (burned[address(r)][id]) return;
        address owner = r.ownerOf(id);
        (bool ok,) = Actor(payable(owner)).exec(address(r), abi.encodeCall(r.transferFrom, (owner, address(_actor(toSeed)), id)));
        if (!ok) _fail("transfer: bearer ticket not transferable");
        ++hits["transfer"];
    }

    function transferTicketToProtocol(uint256 raffleSeed, uint256 ticketSeed, uint256 destSeed) public {
        Raffle r = _raffle(raffleSeed);
        uint256[] storage ts = _tickets[address(r)];
        if (ts.length == 0) return;
        uint256 id = ts[ticketSeed % ts.length];
        if (burned[address(r)][id]) return;
        address owner = r.ownerOf(id);
        address[7] memory dests = [
            address(r),
            address(factory),
            address(usdc),
            address(wrapper),
            address(nft),
            factory.raffleImplementation(),
            address(raffles[destSeed % raffles.length])
        ];
        address dest = dests[destSeed % 7];
        (bool ok,) = Actor(payable(owner)).exec(address(r), abi.encodeCall(r.transferFrom, (owner, dest, id)));
        if (ok) _fail("transfer: ticket reached a protocol destination");
    }

    function requestDraw(uint256 raffleSeed, uint256 callerSeed, uint256 extraSeed) public {
        Raffle r = _raffle(raffleSeed);
        Actor caller = _actor(callerSeed);
        uint256 fee = wrapper.priceNative();
        uint256 extra = _bound(extraSeed, 0, 1 ether);
        if (address(this).balance < fee + extra) return;
        uint256 end = r.endTime();
        bool expectOk = r.status() == IRaffle.Status.Active && block.timestamp >= end && block.timestamp < end + 2 days
            && r.totalEntries() > 0;
        uint256 callerEthBefore = address(caller).balance;
        (bool ok, bytes memory ret) = caller.exec{ value: fee + extra }(address(r), abi.encodeCall(r.requestDraw, ()));
        uint256 callerEthAfter = address(caller).balance;
        caller.sweep(payable(address(this)));
        if (ok != expectOk) _fail("requestDraw: outcome mismatch");
        if (!ok) return;
        uint256 requestId = abi.decode(ret, (uint256));
        if (r.status() != IRaffle.Status.Drawing) _fail("requestDraw: not Drawing");
        if (r.vrfRequestId() != requestId || wrapper.lastRequestId() != requestId) _fail("requestDraw: request id");
        if (r.drawRequestedAt() != block.timestamp) _fail("requestDraw: drawRequestedAt");
        if (r.callbackDeadline() != block.timestamp + 2 days) _fail("requestDraw: callback deadline");
        if (callerEthAfter != callerEthBefore + extra) _fail("requestDraw: excess not refunded");
        if (address(r).balance != 0) _fail("requestDraw: raffle retained ETH");
        ++hits["requestDraw"];
    }

    function underpaidRequestDraw(uint256 raffleSeed, uint256 callerSeed) public {
        Raffle r = _raffle(raffleSeed);
        uint256 fee = wrapper.priceNative();
        if (fee == 0) return;
        if (address(this).balance < fee) return;
        Actor caller = _actor(callerSeed);
        (bool ok,) = caller.exec{ value: fee - 1 }(address(r), abi.encodeCall(r.requestDraw, ()));
        caller.sweep(payable(address(this)));
        if (ok) _fail("requestDraw: accepted with insufficient fee");
    }

    function fulfill(uint256 raffleSeed, uint256 word) public {
        Raffle r = _raffle(raffleSeed);
        uint256 requestId = r.vrfRequestId();
        if (requestId == 0 || wrapper.consumerOf(requestId) == address(0)) return;
        IRaffle.Status st = r.status();
        uint128 entryBefore = r.winningEntry();
        bool expectResolve =
            st == IRaffle.Status.Drawing && block.timestamp < uint256(r.drawRequestedAt()) + 2 days;
        uint128 total = r.totalEntries();
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        (bool ok,) = wrapper.fulfill(requestId, words);
        if (!ok) _fail("fulfill: consumer callback reverted");
        if (expectResolve) {
            IRaffle.Status want = total >= r.reserveEntries() ? IRaffle.Status.NftWon : IRaffle.Status.CashWon;
            if (r.status() != want) _fail("fulfill: wrong result");
            if (r.winningEntry() != uint128(word % total + 1)) _fail("fulfill: wrong winning entry");
            if (r.resolvedAt() != block.timestamp) _fail("fulfill: resolvedAt");
            ++hits[want == IRaffle.Status.NftWon ? bytes32("resolveNft") : bytes32("resolveCash")];
        } else {
            if (r.status() != st || r.winningEntry() != entryBefore) _fail("fulfill: ignored callback changed state");
            ++hits["fulfillIgnored"];
        }
    }

    function fulfillWrong(uint256 raffleSeed, uint256 word, uint256 mode) public {
        Raffle r = _raffle(raffleSeed);
        uint256 requestId = r.vrfRequestId();
        IRaffle.Status st = r.status();
        uint128 entryBefore = r.winningEntry();
        uint256[] memory words;
        uint256 m = mode % 4;
        if (m == 0) {
            words = new uint256[](1);
            words[0] = word;
            requestId = requestId + 1 + (word % 7);
        } else if (m == 1) {
            words = new uint256[](0);
        } else if (m == 2) {
            words = new uint256[](2);
            words[0] = word;
            words[1] = ~word;
        } else {
            if (st == IRaffle.Status.Drawing) return;
            words = new uint256[](1);
            words[0] = word;
        }
        bool ok = wrapper.fulfillRaw(address(r), requestId, words);
        if (!ok) _fail("fulfillWrong: consumer callback reverted");
        if (r.status() != st || r.winningEntry() != entryBefore) _fail("fulfillWrong: invalid callback changed state");
        ++hits["fulfillWrong"];
    }

    function enableRefunds(uint256 raffleSeed, uint256 callerSeed, bool asSponsor) public {
        Raffle r = _raffle(raffleSeed);
        Actor caller = asSponsor ? actors[sponsorActorOf[address(r)]] : _actor(callerSeed);
        IRaffle.Status st = r.status();
        bool isSponsor = address(caller) == r.sponsor();
        bool empty = r.totalEntries() == 0;
        bool expectOk;
        if (st == IRaffle.Status.Active) {
            expectOk = empty ? (isSponsor || block.timestamp >= r.endTime()) : block.timestamp >= uint256(r.endTime()) + 2 days;
        } else if (st == IRaffle.Status.Drawing) {
            expectOk = block.timestamp >= uint256(r.drawRequestedAt()) + 2 days;
        }
        uint256 pot = r.unsettledPot();
        (bool ok,) = caller.exec(address(r), abi.encodeCall(r.enableRefunds, ()));
        if (ok != expectOk) _fail("enableRefunds: outcome mismatch");
        if (!ok) return;
        if (r.status() != IRaffle.Status.Refunding) _fail("enableRefunds: not Refunding");
        if (r.remainingRefundLiability() != pot || r.unsettledPot() != 0) _fail("enableRefunds: liability");
        if (st == IRaffle.Status.Active && empty && isSponsor && block.timestamp < r.endTime()) ++hits["sponsorEarlyCancel"];
        if (st == IRaffle.Status.Active && !empty) ++hits["refundsFromActiveTimeout"];
        ++hits[st == IRaffle.Status.Drawing ? bytes32("refundsAfterDrawing") : bytes32("refundsFromActive")];
    }

    function settle(uint256 raffleSeed, uint256 callerSeed, uint256 ticketSeed, bool useWinner) public {
        Raffle r = _raffle(raffleSeed);
        uint256 id = useWinner ? _winningTicket(r) : _anyTicketId(r, ticketSeed);
        IRaffle.Status st = r.status();
        (uint128 f, uint128 l) = r.ticketRange(id);
        uint128 w = r.winningEntry();
        bool expectOk = _resolved(st) && !r.settlementComplete() && w != 0 && w >= f && w <= l;
        uint256 pot = r.unsettledPot();
        (bool ok, bytes memory ret) = _actor(callerSeed).exec(address(r), abi.encodeCall(r.settleWinningTicket, (id)));
        if (ok != expectOk) _fail("settle: outcome mismatch");
        if (!ok) return;
        uint256 cash = abi.decode(ret, (uint256));
        _checkSettlement(r, st, pot, id, cash);
        if (r.winnerProceeds() != cash) _fail("settle: winnerProceeds storage");
        ++hits["settle"];
    }

    function _checkSettlement(Raffle r, IRaffle.Status st, uint256 pot, uint256 id, uint256 cash) internal {
        uint256 fee = pot * 500 / 10_000;
        uint256 expCash = st == IRaffle.Status.CashWon ? pot * 8000 / 10_000 : 0;
        uint256 expSponsor = pot - fee - expCash;
        if (cash != expCash) _fail("settle: cash allocation");
        if (r.protocolFees() != fee) _fail("settle: protocol fee");
        if (r.sponsorProceeds() != expSponsor) _fail("settle: sponsor allocation");
        // DESIGN.md: NftWon -> 95% sponsor / 5% treasury; CashWon -> 80% winner / 15% sponsor / 5% treasury, no loss.
        if (pot != ghost[address(r)].bought || pot % PRICE != 0) _fail("settle: pot != gross sales");
        if (fee * 20 != pot) _fail("settle: fee is not exactly 5%");
        if (st == IRaffle.Status.NftWon && expSponsor * 20 != pot * 19) _fail("settle: sponsor not exactly 95%");
        if (st == IRaffle.Status.CashWon && (expCash * 10 != pot * 8 || expSponsor * 20 != pot * 3)) {
            _fail("settle: cash split not exactly 80/15/5");
        }
        if (r.unsettledPot() != 0 || !r.settlementComplete() || r.winningTicketId() != id) _fail("settle: state");
        Ghost storage gh = ghost[address(r)];
        gh.feeAtSettle = fee;
        gh.sponsorAtSettle = expSponsor;
        gh.winnerAtSettle = expCash;
    }

    struct RedeemSnap {
        uint256 id;
        address owner;
        IRaffle.Status st;
        bool settledBefore;
        bool expectOk;
        uint256 pot;
        uint256 callerUsdcBefore;
    }

    function redeem(uint256 raffleSeed, uint256 callerSeed, uint256 ticketSeed, bool useWinner, bool useOwner) public {
        Raffle r = _raffle(raffleSeed);
        RedeemSnap memory s;
        s.id = useWinner ? _winningTicket(r) : _anyTicketId(r, ticketSeed);
        s.owner = _ownerOrZero(r, s.id);
        Actor caller = useOwner && s.owner != address(0) ? Actor(payable(s.owner)) : _actor(callerSeed);
        s.st = r.status();
        s.settledBefore = r.settlementComplete();
        s.expectOk = _expectRedeemOk(r, s, address(caller));
        s.pot = r.unsettledPot();
        s.callerUsdcBefore = usdc.balanceOf(address(caller));
        (bool ok, bytes memory ret) = caller.exec(address(r), abi.encodeCall(r.redeemWinningTicket, (s.id)));
        if (ok != s.expectOk) _fail("redeem: outcome mismatch");
        if (!ok) return;
        _afterRedeem(r, s, address(caller), abi.decode(ret, (uint256)));
    }

    function _expectRedeemOk(Raffle r, RedeemSnap memory s, address caller) internal view returns (bool) {
        (uint128 f, uint128 l) = r.ticketRange(s.id);
        uint128 w = r.winningEntry();
        bool idOk = s.settledBefore ? s.id == r.winningTicketId() : (w != 0 && w >= f && w <= l);
        bool deliverable = s.st == IRaffle.Status.NftWon ? !nft.frozen() : _usdcMovable(address(r), caller);
        return _resolved(s.st) && !r.winnerRedeemed() && idOk && s.owner == caller && deliverable;
    }

    function _afterRedeem(Raffle r, RedeemSnap memory s, address caller, uint256 cash) internal {
        burned[address(r)][s.id] = true;
        Ghost storage gh = ghost[address(r)];
        if (!s.settledBefore) {
            uint256 fee = s.pot * 500 / 10_000;
            uint256 expCash = s.st == IRaffle.Status.CashWon ? s.pot * 8000 / 10_000 : 0;
            gh.feeAtSettle = fee;
            gh.winnerAtSettle = expCash;
            gh.sponsorAtSettle = s.pot - fee - expCash;
            if (r.protocolFees() != fee || r.sponsorProceeds() != s.pot - fee - expCash) _fail("redeem: inline settlement");
        }
        if (!r.winnerRedeemed() || r.winnerRecipient() != caller) _fail("redeem: redemption state");
        if (_ownerOrZero(r, s.id) != address(0)) _fail("redeem: ticket not burned");
        if (s.st == IRaffle.Status.NftWon) {
            if (cash != 0 || nft.ownerOf(r.prizeTokenId()) != caller || !r.prizeClaimed()) _fail("redeem: NFT delivery");
            ++hits["redeemNft"];
        } else {
            if (cash != gh.winnerAtSettle || usdc.balanceOf(caller) != s.callerUsdcBefore + cash) _fail("redeem: cash delivery");
            if (r.winnerProceeds() != 0) _fail("redeem: winnerProceeds not cleared");
            gh.paidOut += cash;
            ++hits["redeemCash"];
        }
    }

    function refund(uint256 raffleSeed, uint256 callerSeed, uint256 maxSeed, bool addNonexistent) public {
        Raffle r = _raffle(raffleSeed);
        Actor caller = _actor(callerSeed);
        // Usually act as the owner of some live ticket so the success path is explored; sometimes a random actor.
        if (callerSeed % 4 != 0) {
            uint256[] storage ts = _tickets[address(r)];
            for (uint256 k; k < ts.length; ++k) {
                uint256 t = ts[(callerSeed % ts.length + k) % ts.length]; // modulo first: no overflow on max seeds
                if (!burned[address(r)][t]) {
                    caller = Actor(payable(r.ownerOf(t)));
                    break;
                }
            }
        }
        addNonexistent = addNonexistent && maxSeed % 8 == 0;
        (uint256[] memory sel, uint256 entries) = _selectOwned(r, address(caller), _bound(maxSeed, 1, 6), addNonexistent);
        bool expectOk = r.status() == IRaffle.Status.Refunding && sel.length > 0 && !addNonexistent
            && _usdcMovable(address(r), address(caller));
        uint256 liabilityBefore = r.remainingRefundLiability();
        uint256 balBefore = usdc.balanceOf(address(caller));
        (bool ok, bytes memory ret) = caller.exec(address(r), abi.encodeCall(r.refundTickets, (sel)));
        if (ok != expectOk) _fail("refund: outcome mismatch");
        if (!ok) return;
        uint256 amount = abi.decode(ret, (uint256));
        if (amount != entries * PRICE) _fail("refund: amount != entries * price");
        if (r.remainingRefundLiability() != liabilityBefore - amount) _fail("refund: liability");
        if (usdc.balanceOf(address(caller)) != balBefore + amount) _fail("refund: payment");
        for (uint256 i; i < sel.length; ++i) {
            burned[address(r)][sel[i]] = true;
        }
        ghost[address(r)].paidOut += amount;
        ++hits["refund"];
    }

    function _selectOwned(Raffle r, address caller, uint256 maxN, bool addNonexistent)
        internal
        view
        returns (uint256[] memory sel, uint256 entries)
    {
        uint256[] storage ts = _tickets[address(r)];
        sel = new uint256[](maxN + 1);
        uint256 n;
        for (uint256 i; i < ts.length && n < maxN; ++i) {
            if (burned[address(r)][ts[i]] || r.ownerOf(ts[i]) != caller) continue;
            (uint128 f, uint128 l) = r.ticketRange(ts[i]);
            sel[n++] = ts[i];
            entries += uint256(l - f + 1);
        }
        if (addNonexistent) sel[n++] = type(uint256).max;
        assembly ("memory-safe") {
            mstore(sel, n)
        }
    }

    function refundDuplicate(uint256 raffleSeed, uint256 callerSeed) public {
        Raffle r = _raffle(raffleSeed);
        Actor caller = _actor(callerSeed);
        uint256[] storage ts = _tickets[address(r)];
        for (uint256 i; i < ts.length; ++i) {
            if (burned[address(r)][ts[i]] || r.ownerOf(ts[i]) != address(caller)) continue;
            uint256[] memory sel = new uint256[](2);
            sel[0] = ts[i];
            sel[1] = ts[i];
            (bool ok,) = caller.exec(address(r), abi.encodeCall(r.refundTickets, (sel)));
            if (ok) _fail("refund: duplicate ticket id accepted");
            return;
        }
    }

    function releaseSponsorProceeds(uint256 raffleSeed, uint256 callerSeed) public {
        Raffle r = _raffle(raffleSeed);
        uint256 amount = r.sponsorProceeds();
        address recipient = r.sponsorRecipient();
        bool expectOk = amount > 0 && _usdcMovable(address(r), recipient);
        uint256 before = usdc.balanceOf(recipient);
        (bool ok,) = _actor(callerSeed).exec(address(r), abi.encodeCall(r.releaseSponsorProceeds, ()));
        if (ok != expectOk) _fail("releaseSponsorProceeds: outcome mismatch");
        if (!ok) return;
        if (usdc.balanceOf(recipient) != before + amount || r.sponsorProceeds() != 0) _fail("releaseSponsorProceeds: payment");
        ghost[address(r)].paidOut += amount;
        ++hits["releaseSponsor"];
    }

    function releaseProtocolFees(uint256 raffleSeed, uint256 callerSeed) public {
        Raffle r = _raffle(raffleSeed);
        uint256 amount = r.protocolFees();
        bool expectOk = amount > 0 && _usdcMovable(address(r), TREASURY);
        uint256 before = usdc.balanceOf(TREASURY);
        (bool ok,) = _actor(callerSeed).exec(address(r), abi.encodeCall(r.releaseProtocolFees, ()));
        if (ok != expectOk) _fail("releaseProtocolFees: outcome mismatch");
        if (!ok) return;
        if (usdc.balanceOf(TREASURY) != before + amount || r.protocolFees() != 0) _fail("releaseProtocolFees: payment");
        ghost[address(r)].paidOut += amount;
        ++hits["releaseFees"];
    }

    function releaseSponsorPrize(uint256 raffleSeed, uint256 callerSeed) public {
        Raffle r = _raffle(raffleSeed);
        IRaffle.Status st = r.status();
        bool expectOk = (st == IRaffle.Status.CashWon || st == IRaffle.Status.Refunding) && !r.prizeClaimed() && !nft.frozen();
        (bool ok,) = _actor(callerSeed).exec(address(r), abi.encodeCall(r.releaseSponsorPrize, ()));
        if (ok != expectOk) _fail("releaseSponsorPrize: outcome mismatch");
        if (!ok) return;
        if (nft.ownerOf(r.prizeTokenId()) != r.sponsorRecipient() || !r.prizeClaimed()) _fail("releaseSponsorPrize: delivery");
        ++hits["releasePrize"];
    }

    function reinitialize(uint256 raffleSeed, uint256 callerSeed) public {
        Raffle r = _raffle(raffleSeed);
        IRaffle.RaffleInitParams memory p = IRaffle.RaffleInitParams({
            sponsor: address(_actor(callerSeed)),
            sponsorRecipient: address(_actor(callerSeed)),
            protocolTreasury: address(_actor(callerSeed)),
            prizeToken: address(nft),
            prizeTokenId: 1,
            raffleId: 99,
            reserveEntries: 1,
            endTime: uint64(block.timestamp + 1)
        });
        (bool ok,) = _actor(callerSeed).exec(address(r), abi.encodeCall(r.initialize, (p)));
        (bool ok2,) = _actor(callerSeed).exec(factory.raffleImplementation(), abi.encodeCall(r.initialize, (p)));
        if (ok || ok2) _fail("initialize: re-initialization accepted");
    }

    // ------------------------------------------------------------------ global invariants

    function checkInvariants() public view returns (bool, string memory) {
        Raffle impl = Raffle(payable(factory.raffleImplementation()));
        if (!impl.initialized() || impl.status() != IRaffle.Status.Refunding) return (false, "I10 implementation not locked");
        if (factory.raffleCount() != raffles.length) return (false, "I12 registry count");
        for (uint256 i; i < raffles.length; ++i) {
            (bool ok, string memory why) = _checkRaffle(raffles[i], i + 1);
            if (!ok) return (false, why);
        }
        return (true, "");
    }

    function _checkRaffle(Raffle r, uint256 id) internal view returns (bool, string memory) {
        Ghost memory gh = ghost[address(r)];
        if (factory.raffleById(id) != address(r) || factory.idByRaffle(address(r)) != id || !factory.isRaffle(address(r))) {
            return (false, "I12 registry mapping");
        }
        uint256 accounted = r.accountedQuoteBalance();
        if (usdc.balanceOf(address(r)) != accounted + gh.donated) return (false, "I1 quote balance != liabilities + donations");
        if (r.grossSales() != gh.bought) return (false, "I2 gross sales");
        if (gh.bought - gh.paidOut != accounted) return (false, "I3 flow conservation");
        if (address(r).balance != 0) return (false, "I9 raffle retained ETH");

        (bool ok, string memory why, uint256 unburnedValue, uint256 winners) = _checkTickets(r);
        if (!ok) return (false, why);

        IRaffle.Status st = r.status();
        if (st == IRaffle.Status.AwaitingPrize) return (false, "I4 registered raffle awaiting prize");
        if (st == IRaffle.Status.Active || st == IRaffle.Status.Drawing) {
            if (
                r.unsettledPot() != gh.bought || r.remainingRefundLiability() != 0 || r.winnerProceeds() != 0
                    || r.sponsorProceeds() != 0 || r.protocolFees() != 0 || r.settlementComplete() || r.prizeClaimed()
            ) return (false, "I4 open-sale buckets");
        } else if (st == IRaffle.Status.Refunding) {
            if (r.unsettledPot() != 0 || r.winnerProceeds() != 0 || r.sponsorProceeds() != 0 || r.protocolFees() != 0 || r.settlementComplete()) {
                return (false, "I4 refunding buckets");
            }
            if (r.remainingRefundLiability() != unburnedValue) return (false, "I7 refund liability != unrefunded tickets");
        } else {
            if (r.remainingRefundLiability() != 0) return (false, "I4 resolved refund liability");
            uint128 w = r.winningEntry();
            if (w == 0 || w > r.totalEntries()) return (false, "I6 winning entry out of range");
            if (winners != 1) return (false, "I6 not exactly one winning ticket");
            if ((st == IRaffle.Status.NftWon) != (r.totalEntries() >= r.reserveEntries())) return (false, "I6 reserve outcome");
            if (!r.settlementComplete()) {
                if (r.unsettledPot() != gh.bought || r.sponsorProceeds() != 0 || r.protocolFees() != 0 || r.winnerProceeds() != 0) {
                    return (false, "I4 resolved-unsettled buckets");
                }
                if (r.winnerRedeemed()) return (false, "I4 redeemed before settlement");
            } else {
                if (r.unsettledPot() != 0) return (false, "I4 settled pot");
                if (r.protocolFees() != 0 && r.protocolFees() != gh.feeAtSettle) return (false, "I5 fee bucket");
                if (r.sponsorProceeds() != 0 && r.sponsorProceeds() != gh.sponsorAtSettle) return (false, "I5 sponsor bucket");
                if (r.winnerProceeds() != 0 && (r.winnerProceeds() != gh.winnerAtSettle || r.winnerRedeemed())) return (false, "I5 winner bucket");
                if (st == IRaffle.Status.NftWon && gh.winnerAtSettle != 0) return (false, "I5 NftWon cash");
            }
        }

        address prizeOwner = nft.ownerOf(r.prizeTokenId());
        if (!r.prizeClaimed()) {
            if (prizeOwner != address(r)) return (false, "I8 prize left escrow without a claim");
        } else if (st == IRaffle.Status.NftWon) {
            if (prizeOwner != r.winnerRecipient()) return (false, "I8 NftWon prize not with winner");
        } else if (st == IRaffle.Status.CashWon || st == IRaffle.Status.Refunding) {
            if (prizeOwner != r.sponsorRecipient()) return (false, "I8 returned prize not with sponsor recipient");
        } else {
            return (false, "I8 prize claimed in non-terminal state");
        }
        return (true, "");
    }

    function _checkTickets(Raffle r) internal view returns (bool, string memory, uint256 unburnedValue, uint256 winners) {
        uint256[] storage ts = _tickets[address(r)];
        if (r.ticketCount() != ts.length) return (false, "I7 ticket count", 0, 0);
        uint256 expectFirst = 1;
        uint128 w = r.winningEntry();
        for (uint256 j; j < ts.length; ++j) {
            (uint128 f, uint128 l) = r.ticketRange(ts[j]);
            if (ts[j] != j + 1 || f != expectFirst || l < f) return (false, "I7 ranges not a contiguous partition", 0, 0);
            expectFirst = uint256(l) + 1;
            if (w != 0 && w >= f && w <= l) ++winners;
            address o = _ownerOrZero(r, ts[j]);
            if (burned[address(r)][ts[j]]) {
                if (o != address(0)) return (false, "I7 burned ticket still owned", 0, 0);
                continue;
            }
            if (o == address(0)) return (false, "I7 live ticket missing", 0, 0);
            if (_isProtocol(o)) return (false, "I11 ticket owned by protocol address", 0, 0);
            unburnedValue += uint256(l - f + 1) * PRICE;
        }
        if (expectFirst - 1 != r.totalEntries()) return (false, "I7 partition does not cover totalEntries", 0, 0);
        return (true, "", unburnedValue, winners);
    }

    function hit(string calldata key) external view returns (uint256) {
        return hits[bytes32(bytes(key))];
    }
}
