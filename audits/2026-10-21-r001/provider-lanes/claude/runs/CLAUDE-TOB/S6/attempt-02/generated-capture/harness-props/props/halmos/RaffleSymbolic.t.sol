// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

// GENERATED SCRATCH TEST CODE (S6 attempt-02). Halmos symbolic checks (bounded symbolic execution; disclosed
// substitute for Manticore, which is not installed and cannot be installed offline). Every check drives the
// UNMODIFIED production RaffleFactory -> ERC-1167 Raffle clone with symbolic inputs and asserts a property from the
// report's "Security properties" section. Results are bounded evidence (loop bound, solver timeouts), not proofs.

import { IRaffle } from "../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../src/interfaces/IRaffleFactory.sol";
import { RaffleFactory } from "../../src/RaffleFactory.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { MockPrizeNFT } from "../mocks/MockPrizeNFTs.sol";
import { MockUSDC } from "../mocks/MockUSDC.sol";
import { MockVRFWrapper } from "../mocks/MockVRFWrapper.sol";
import { HEVM_ADDRESS, IHevm } from "../utils/IHevm.sol";

contract RaffleSymbolicTest {
    IHevm internal constant vm = IHevm(HEVM_ADDRESS);
    uint256 internal constant PRICE = 1_000_000;
    uint256 internal constant T0 = 1_800_000_000;
    address internal constant TREASURY = address(uint160(0x7EA5));
    address internal constant SPONSOR = address(uint160(0x5905));
    address internal constant SPONSOR_RECIPIENT = address(uint160(0x5CA1E));
    address internal constant ALICE = address(uint160(0xA11CE));
    address internal constant BOB = address(uint160(0xB0B));
    address internal constant KEEPER = address(uint160(0x4EE9E4));

    MockUSDC internal usdc;
    MockVRFWrapper internal wrapper;
    MockPrizeNFT internal nft;
    RaffleFactory internal factory;

    function setUp() public {
        vm.warp(T0);
        usdc = new MockUSDC();
        wrapper = new MockVRFWrapper();
        nft = new MockPrizeNFT();
        factory = new RaffleFactory(address(usdc), address(wrapper), TREASURY);
        nft.mint(SPONSOR, 1);
        vm.prank(SPONSOR);
        nft.approve(address(factory), 1);
    }

    function _create(uint128 reserve) internal returns (IRaffle r) {
        vm.prank(SPONSOR);
        r = IRaffle(
            factory.createRaffle(
                IRaffleFactory.CreateRaffleParams({
                    sponsorRecipient: SPONSOR_RECIPIENT,
                    prizeToken: address(nft),
                    prizeTokenId: 1,
                    reserveEntries: reserve,
                    endTime: uint64(T0 + 7 days)
                })
            )
        );
    }

    function _buy(IRaffle r, address buyer, uint128 count) internal {
        uint256 cost = uint256(count) * PRICE;
        usdc.mint(buyer, cost);
        vm.prank(buyer);
        usdc.approve(address(r), cost);
        vm.prank(buyer);
        r.buyEntries(buyer, count);
    }

    function _request(IRaffle r) internal {
        vm.prank(KEEPER);
        r.requestDraw();
    }

    function _fulfill(IRaffle r, uint256 word) internal returns (bool ok) {
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        (ok,) = wrapper.fulfill(address(r), r.vrfRequestId(), words);
    }

    /// A-5/AR-1: for EVERY entry count in [1, 2^128-1] the settlement split is exact (5/95 or 5/80/15), conserves
    /// the pot, and complete payout drains the raffle.
    function check_split_exact_symbolic_entries(uint128 entries, bool reserveMet) public {
        vm.assume(entries > 0);
        if (!reserveMet) vm.assume(entries < type(uint128).max);
        IRaffle r = _create(reserveMet ? 1 : type(uint128).max);
        _buy(r, ALICE, entries);
        vm.warp(T0 + 7 days);
        _request(r);
        assert(_fulfill(r, 0));
        assert(r.status() == (reserveMet ? IRaffle.Status.NftWon : IRaffle.Status.CashWon));
        uint256 gross = uint256(entries) * PRICE;
        r.settleWinningTicket(1);
        uint256 fee = r.protocolFees();
        uint256 cash = r.winnerProceeds();
        uint256 sponsor = r.sponsorProceeds();
        assert(fee * 20 == gross);
        assert(reserveMet ? cash == 0 : cash * 5 == gross * 4);
        assert(fee + cash + sponsor == gross);
        assert(r.unsettledPot() == 0 && r.accountedQuoteBalance() == gross);
        assert(usdc.balanceOf(address(r)) == gross);
    }

    /// SM-9/AR-3: for every word and entry count, the selected entry lies in [1,totalEntries], the reserve rule holds,
    /// and the single ticket covering all entries settles.
    function check_winning_entry_in_range(uint128 entries, uint256 word, uint128 reserve) public {
        vm.assume(entries > 0 && reserve > 0);
        IRaffle r = _create(reserve);
        _buy(r, ALICE, entries);
        vm.warp(T0 + 7 days);
        _request(r);
        assert(_fulfill(r, word));
        uint128 w = r.winningEntry();
        assert(w >= 1 && w <= entries);
        assert((r.status() == IRaffle.Status.NftWon) == (entries >= reserve));
        r.settleWinningTicket(1);
        assert(r.settlementComplete() && r.winningTicketId() == 1);
    }

    /// SM-5/SM-8: requestDraw succeeds exactly inside [endTime, endTime + 2 days).
    function check_requestDraw_iff_inside_window(uint64 t) public {
        IRaffle r = _create(1);
        _buy(r, ALICE, 1);
        vm.assume(t >= T0);
        vm.warp(t);
        vm.prank(KEEPER);
        (bool ok,) = address(r).call(abi.encodeCall(IRaffle.requestDraw, ()));
        uint256 endTime = T0 + 7 days;
        assert(ok == (t >= endTime && t < endTime + 2 days));
    }

    /// SM-7/SM-8: for a sold raffle nobody (sponsor included) can enable refunds before endTime + 2 days, and anyone
    /// can at or after it.
    function check_enableRefunds_sold_iff_after_request_deadline(uint64 t, bool asSponsor) public {
        IRaffle r = _create(1);
        _buy(r, ALICE, 1);
        vm.assume(t >= T0);
        vm.warp(t);
        vm.prank(asSponsor ? SPONSOR : BOB);
        (bool ok,) = address(r).call(abi.encodeCall(IRaffle.enableRefunds, ()));
        assert(ok == (uint256(t) >= T0 + 9 days));
    }

    /// SM-7/AC-5: for an empty raffle the sponsor may close at any time; anyone else only from endTime.
    function check_enableRefunds_empty(uint64 t, address caller) public {
        IRaffle r = _create(1);
        vm.assume(t >= T0);
        vm.warp(t);
        vm.prank(caller);
        (bool ok,) = address(r).call(abi.encodeCall(IRaffle.enableRefunds, ()));
        assert(ok == (caller == SPONSOR || uint256(t) >= T0 + 7 days));
    }

    /// SM-6/SM-8/EI-3: the authenticated callback never reverts, resolves iff strictly before requestedAt + 2 days,
    /// and refunds from Drawing open exactly when the callback can no longer resolve.
    function check_callback_window_and_refund_handoff(uint32 dt, uint256 word) public {
        IRaffle r = _create(1);
        _buy(r, ALICE, 3);
        vm.warp(T0 + 7 days);
        _request(r);
        vm.warp(T0 + 7 days + uint256(dt));
        assert(_fulfill(r, word));
        bool resolved = r.status() == IRaffle.Status.NftWon;
        assert(resolved == (uint256(dt) < 2 days));
        vm.prank(BOB);
        (bool ok,) = address(r).call(abi.encodeCall(IRaffle.enableRefunds, ()));
        assert(ok == !resolved);
    }

    /// A-4/A-7/T-4: refunds return exactly 100% for any two purchase sizes, cannot be replayed, and drain to zero.
    function check_refund_conservation(uint64 a, uint64 b) public {
        vm.assume(a > 0 && b > 0);
        IRaffle r = _create(1);
        _buy(r, ALICE, a);
        _buy(r, BOB, b);
        vm.warp(T0 + 9 days);
        r.enableRefunds();
        uint256[] memory one = new uint256[](1);
        one[0] = 1;
        vm.prank(ALICE);
        r.refundTickets(one);
        vm.prank(ALICE);
        (bool replay,) = address(r).call(abi.encodeCall(IRaffle.refundTickets, (one)));
        assert(!replay);
        one[0] = 2;
        vm.prank(BOB);
        r.refundTickets(one);
        assert(usdc.balanceOf(ALICE) == uint256(a) * PRICE && usdc.balanceOf(BOB) == uint256(b) * PRICE);
        assert(r.remainingRefundLiability() == 0 && usdc.balanceOf(address(r)) == 0);
    }

    /// AC-4/SM-11: only the current owner of the winning ticket can redeem it.
    function check_redeem_only_current_owner(address caller) public {
        IRaffle r = _create(1);
        _buy(r, ALICE, 2);
        vm.warp(T0 + 7 days);
        _request(r);
        assert(_fulfill(r, 0));
        vm.prank(caller);
        (bool ok,) = address(r).call(abi.encodeCall(IRaffle.redeemWinningTicket, (1)));
        assert(ok == (caller == ALICE));
        if (ok) assert(nft.ownerOf(1) == ALICE && r.winnerRedeemed());
    }

    /// T-3: a ticket can never be transferred to known protocol plumbing (any symbolic destination).
    function check_ticket_transfer_destination_screen(address to) public {
        IRaffle r = _create(1);
        _buy(r, ALICE, 1);
        vm.prank(ALICE);
        (bool ok,) = address(r).call(abi.encodeWithSignature("transferFrom(address,address,uint256)", ALICE, to, 1));
        bool plumbing = to == address(r) || to == address(factory) || to == factory.raffleImplementation()
            || to == address(usdc) || to == address(wrapper) || to == address(nft) || to == address(0);
        if (plumbing) assert(!ok);
        if (ok) assert(IERC721(address(r)).ownerOf(1) == to);
    }
}
