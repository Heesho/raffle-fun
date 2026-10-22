// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Base } from "./Base.sol";
import { RaffleFactory } from "raffle/RaffleFactory.sol";
import { Raffle } from "raffle/Raffle.sol";
import { IRaffle } from "raffle/interfaces/IRaffle.sol";
import { IRaffleFactory } from "raffle/interfaces/IRaffleFactory.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { MockNFT, ReceiverWallet } from "../src/Mocks.sol";

/// Deterministic window-edge, split, atomicity, VRF-filtering and isolation checks.
contract LifecycleTest is Base {
    // ------------------------------------------------------------ window edges (DESIGN timing)

    function test_edges_sale_request_activeRefund() public {
        uint64 end = uint64(T0 + 1 days);
        Raffle r = _create(1, 5, end);

        vm.warp(end - 1);
        _buy(r, alice, 2); // last purchasable second

        vm.warp(end);
        usdc.mint(bob, E);
        vm.prank(bob);
        usdc.approve(address(r), E);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.SaleEnded.selector, end, end));
        r.buyEntries(bob, 1);

        vm.warp(end - 1);
        vm.deal(keeper, 1 ether);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.RaffleNotEnded.selector, end, end - 1));
        r.requestDraw{ value: 0.01 ether }();

        uint256 dl = uint256(end) + 2 days;
        vm.warp(dl);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.DrawRequestWindowExpired.selector, dl, dl));
        r.requestDraw{ value: 0.01 ether }();

        vm.warp(dl - 1);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.RefundsNotAvailable.selector, dl, dl - 1));
        r.enableRefunds();

        vm.warp(dl);
        r.enableRefunds(); // opens exactly at end + 2 days
        _eq(_st(r), uint8(IRaffle.Status.Refunding), "refunding at dl");
        _eq(r.remainingRefundLiability(), 2 * E, "liability");
    }

    function test_edges_lastRequestSecond_and_callbackWindow() public {
        uint64 end = uint64(T0 + 1 days);
        Raffle r = _create(1, 5, end);
        _buy(r, alice, 3);
        uint256 reqT = uint256(end) + 2 days - 1; // last second of [end, end+2d)
        vm.warp(reqT);
        _request(r);
        _eq(_st(r), uint8(IRaffle.Status.Drawing), "drawing");
        uint256 cbDl = reqT + 2 days;
        _eq(r.callbackDeadline(), cbDl, "cb deadline");

        vm.warp(cbDl - 1);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.RefundsNotAvailable.selector, cbDl, cbDl - 1));
        r.enableRefunds();
        require(_fulfill(r, 7), "callback call failed");
        _eq(_st(r), uint8(IRaffle.Status.CashWon), "resolved at cbDl-1 (3 < reserve 5)");
        _eq(r.winningEntry(), 7 % 3 + 1, "winning entry");
    }

    function test_edges_callbackAtDeadlineIgnored_thenRefunds() public {
        uint64 end = uint64(T0 + 1 days);
        Raffle r = _create(1, 5, end);
        _buy(r, alice, 3);
        vm.warp(end);
        _request(r);
        uint256 cbDl = uint256(end) + 2 days;
        vm.warp(cbDl);
        require(_fulfill(r, 7), "callback must not revert");
        _eq(_st(r), uint8(IRaffle.Status.Drawing), "late callback ignored");
        r.enableRefunds();
        _eq(_st(r), uint8(IRaffle.Status.Refunding), "refunding at cbDl");
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        vm.prank(alice);
        _eq(r.refundTickets(ids), 3 * E, "full refund");
        r.releaseSponsorPrize();
        require(nft.ownerOf(1) == recipient, "prize returned");
    }

    function test_edges_emptyRaffle() public {
        uint64 end = uint64(T0 + 1 days);
        Raffle r = _create(1, 5, end);
        vm.warp(end - 1);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.RefundsNotAvailable.selector, uint256(end), end - 1));
        r.enableRefunds(); // stranger before end
        vm.warp(end);
        vm.deal(keeper, 1 ether);
        vm.prank(keeper);
        vm.expectRevert(IRaffle.NoEntriesSold.selector);
        r.requestDraw{ value: 0.01 ether }();
        r.enableRefunds(); // stranger at end
        r.releaseSponsorPrize();
        require(nft.ownerOf(1) == recipient, "returned");

        Raffle r2 = _create(2, 5, uint64(T0 + 10 days));
        vm.prank(sponsor);
        r2.enableRefunds(); // sponsor early close of an empty raffle
        _eq(_st(r2), uint8(IRaffle.Status.Refunding), "sponsor closed");
    }

    // ------------------------------------------------------------ splits

    function _runToResult(uint128 nAlice, uint128 nBob, uint128 reserve, uint256 word)
        internal
        returns (Raffle r)
    {
        uint64 end = uint64(block.timestamp + 1 days);
        r = _create(uint256(keccak256(abi.encode(nAlice, nBob, reserve, word, block.timestamp))), reserve, end);
        if (nAlice != 0) _buy(r, alice, nAlice);
        if (nBob != 0) _buy(r, bob, nBob);
        vm.warp(end);
        _request(r);
        require(_fulfill(r, word), "cb");
    }

    function testFuzz_splitExactness(uint128 nAlice, uint128 nBob, uint128 reserve, uint256 word) public {
        nAlice = uint128(1 + (nAlice % 5_000_000));
        nBob = uint128(nBob % 5_000_000);
        reserve = uint128(1 + (reserve % 10_000_000));
        Raffle r = _runToResult(nAlice, nBob, reserve, word);
        uint256 gross = uint256(nAlice + nBob) * E;
        bool nftWon = (nAlice + nBob) >= reserve;
        _eq(_st(r), nftWon ? uint8(IRaffle.Status.NftWon) : uint8(IRaffle.Status.CashWon), "result");
        uint256 winTicket = r.winningEntry() <= nAlice ? 1 : 2;
        r.settleWinningTicket(winTicket);
        _eq(r.protocolFees(), gross * 500 / 10_000, "fee floor");
        if (nftWon) {
            _eq(r.sponsorProceeds(), gross - gross * 500 / 10_000, "sponsor 95");
            _eq(r.winnerProceeds(), 0, "no cash");
        } else {
            _eq(r.winnerProceeds(), gross * 8000 / 10_000, "winner 80");
            _eq(r.sponsorProceeds(), gross - gross * 500 / 10_000 - gross * 8000 / 10_000, "sponsor 15");
        }
        _eq(r.winnerProceeds() + r.sponsorProceeds() + r.protocolFees(), gross, "no loss");
        _eq(usdc.balanceOf(address(r)), r.accountedQuoteBalance(), "solvent");
        // because gross is a multiple of 1e6, no rounding ever occurs (5% = n*50_000, 80% = n*800_000)
        _eq((gross * 500) % 10_000, 0, "no fee remainder");
    }

    // ------------------------------------------------------------ redemption atomicity

    function test_redeem_deliveryFailureRevertsEverything() public {
        Raffle r = _runToResult(4, 0, 2, 3); // alice holds the single ticket, NftWon
        _eq(_st(r), uint8(IRaffle.Status.NftWon), "nft won");
        uint256 prizeId = r.prizeTokenId();
        nft.setPaused(true);
        vm.prank(alice);
        vm.expectRevert(bytes("paused"));
        r.redeemWinningTicket(1);
        require(!r.settlementComplete() && !r.winnerRedeemed() && !r.prizeClaimed(), "state reverted");
        require(r.ownerOf(1) == alice, "ticket intact");
        // settlement (storage-only) and sponsor/treasury exits are unaffected by the broken prize
        r.settleWinningTicket(1);
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        _eq(usdc.balanceOf(recipient), 4 * E * 95 / 100, "sponsor paid");
        _eq(usdc.balanceOf(treasury), 4 * E * 5 / 100, "treasury paid");
        nft.setPaused(false);
        // bearer semantics: transfer the winning ticket, old owner can no longer redeem
        vm.prank(alice);
        r.transferFrom(alice, carol, 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NotTicketOwner.selector, 1, alice, carol));
        r.redeemWinningTicket(1);
        vm.prank(carol);
        r.redeemWinningTicket(1);
        require(nft.ownerOf(prizeId) == carol, "carol has prize");
        _eq(usdc.balanceOf(address(r)), 0, "drained");
    }

    function test_redeem_cash_and_prizeReturn() public {
        Raffle r = _runToResult(3, 2, 100, 4); // entry 5 -> bob's ticket 2, CashWon
        _eq(_st(r), uint8(IRaffle.Status.CashWon), "cash won");
        _eq(r.winningEntry(), 5, "entry 5");
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.TicketDoesNotContainWinningEntry.selector, 1, uint128(5)));
        r.redeemWinningTicket(1);
        vm.prank(bob);
        _eq(r.redeemWinningTicket(2), 4 * E, "80% of 5");
        r.releaseSponsorPrize();
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        _eq(usdc.balanceOf(recipient), 75 * E / 100, "15%");
        _eq(usdc.balanceOf(treasury), 25 * E / 100, "5%");
        _eq(usdc.balanceOf(address(r)), 0, "drained");
        vm.expectRevert(IRaffle.PrizeAlreadyClaimed.selector);
        r.releaseSponsorPrize();
        vm.prank(bob);
        vm.expectRevert(IRaffle.WinningTicketAlreadyRedeemed.selector);
        r.redeemWinningTicket(2);
    }

    function test_nftWon_sponsorCannotTakePrize() public {
        Raffle r = _runToResult(2, 0, 1, 0);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.SponsorPrizeUnavailable.selector, IRaffle.Status.NftWon));
        r.releaseSponsorPrize();
    }

    // ------------------------------------------------------------ refunds

    function test_refund_batchRules() public {
        uint64 end = uint64(T0 + 1 days);
        Raffle r = _create(1, 5, end);
        _buy(r, alice, 2); // 1
        _buy(r, bob, 3); // 2
        _buy(r, alice, 4); // 3
        vm.warp(uint256(end) + 2 days);
        r.enableRefunds();
        uint256[] memory dup = new uint256[](2);
        dup[0] = 1;
        dup[1] = 1;
        vm.prank(alice);
        vm.expectRevert(); // ERC721NonexistentToken on second occurrence
        r.refundTickets(dup);
        uint256[] memory foreign = new uint256[](2);
        foreign[0] = 1;
        foreign[1] = 2;
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NotTicketOwner.selector, 2, alice, bob));
        r.refundTickets(foreign);
        uint256[] memory none = new uint256[](0);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidTicketBatchSize.selector, 0, 100));
        r.refundTickets(none);
        uint256[] memory mine = new uint256[](2);
        mine[0] = 3;
        mine[1] = 1;
        vm.prank(alice);
        _eq(r.refundTickets(mine), 6 * E, "alice 6");
        _eq(r.remainingRefundLiability(), 3 * E, "bob left");
        uint256[] memory b = new uint256[](1);
        b[0] = 2;
        vm.prank(bob);
        _eq(r.refundTickets(b), 3 * E, "bob 3");
        _eq(usdc.balanceOf(address(r)), 0, "drained");
    }

    // ------------------------------------------------------------ VRF callback filtering

    function test_vrf_syncCallbackIgnored_and_filters() public {
        wrapper.setSyncCallback(true);
        uint64 end = uint64(T0 + 1 days);
        Raffle r = _create(1, 5, end);
        _buy(r, alice, 3);
        vm.warp(end);
        uint256 id = _request(r);
        require(wrapper.lastCallbackSuccess(), "sync callback executed w/o revert");
        _eq(_st(r), uint8(IRaffle.Status.Drawing), "in-flight callback ignored");
        _eq(r.vrfRequestId(), id, "id persisted");
        // the mock deleted nothing for the sync path; re-authenticated paths:
        uint256[] memory two = new uint256[](2);
        require(wrapper.rawCall(address(r), id, two), "len2 ok");
        _eq(_st(r), uint8(IRaffle.Status.Drawing), "len2 ignored");
        uint256[] memory one = new uint256[](1);
        require(wrapper.rawCall(address(r), id + 1, one), "wrong id ok");
        _eq(_st(r), uint8(IRaffle.Status.Drawing), "wrong id ignored");
        // non-wrapper caller
        vm.expectRevert();
        r.rawFulfillRandomWords(id, one);
        // real fulfilment + gas measurement
        require(_fulfill(r, 5), "cb");
        _eq(_st(r), uint8(IRaffle.Status.CashWon), "resolved");
        require(wrapper.lastCallbackGasUsed() < 100_000, "callback well under 300k");
        // duplicate after resolution is ignored, not reverted
        one[0] = 0;
        require(wrapper.rawCall(address(r), id, one), "dup ok");
        _eq(r.winningEntry(), 5 % 3 + 1, "unchanged");
    }

    function test_vrf_feeExcessRefund_and_insufficient() public {
        uint64 end = uint64(T0 + 1 days);
        Raffle r = _create(1, 5, end);
        _buy(r, alice, 1);
        vm.warp(end);
        vm.txGasPrice(30 gwei);
        uint256 fee = r.getVrfRequestPrice();
        vm.deal(keeper, 10 ether);
        vm.prank(keeper);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InsufficientVrfFee.selector, fee, fee - 1));
        r.requestDraw{ value: fee - 1 }();
        vm.prank(keeper);
        r.requestDraw{ value: 3 ether }();
        _eq(keeper.balance, 10 ether - fee, "excess returned");
        _eq(address(r).balance, 0, "no native retained");
        vm.txGasPrice(0);
    }

    // ------------------------------------------------------------ isolation / binding

    function test_isolation_crossClone() public {
        Raffle a = _create(1, 5, uint64(T0 + 1 days));
        Raffle b = _create(2, 5, uint64(T0 + 1 days));
        _buy(a, alice, 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(b)));
        a.transferFrom(alice, address(b), 1);
        address impl = factory.raffleImplementation();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, impl));
        a.transferFrom(alice, impl, 1);
        // a raffle's ticket can never be a prize of this factory
        vm.prank(alice);
        a.approve(address(factory), 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsafeProtocolDestination.selector, address(a)));
        factory.createRaffle(_params(recipient, address(a), 1, 1, uint64(T0 + 1 days)));
        // tickets cannot be minted to protocol plumbing
        usdc.mint(alice, E);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(usdc)));
        a.buyEntries(address(usdc), 1);
    }

    function test_binding_implementationAndRogueClone() public {
        Raffle impl = Raffle(payable(factory.raffleImplementation()));
        require(impl.initialized(), "impl locked");
        IRaffle.RaffleInitParams memory p = IRaffle.RaffleInitParams({
            sponsor: alice,
            sponsorRecipient: alice,
            protocolTreasury: alice,
            prizeToken: address(nft),
            prizeTokenId: 1,
            raffleId: 1,
            reserveEntries: 1,
            endTime: uint64(T0 + 1 days)
        });
        vm.prank(address(factory));
        vm.expectRevert(IRaffle.AlreadyInitialized.selector);
        impl.initialize(p);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.Refunding));
        impl.redeemWinningTicket(1);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.Refunding));
        impl.enableRefunds();
    }

    function test_binding_rogueClone() public {
        address rogue = Clones.clone(factory.raffleImplementation());
        IRaffle.RaffleInitParams memory p = IRaffle.RaffleInitParams({
            sponsor: alice,
            sponsorRecipient: alice,
            protocolTreasury: alice,
            prizeToken: address(nft),
            prizeTokenId: 1,
            raffleId: 1,
            reserveEntries: 1,
            endTime: uint64(T0 + 1 days)
        });
        vm.expectRevert(IRaffle.OnlyFactory.selector);
        IRaffle(rogue).initialize(p);
        require(!factory.isRaffle(rogue), "unregistered");
        // the implementation's release path cannot move anything (prizeToken == 0 -> extcodesize revert)
        Raffle impl = Raffle(payable(factory.raffleImplementation()));
        vm.expectRevert();
        impl.releaseSponsorPrize();
    }

    // ------------------------------------------------------------ contract ticket recipient / reentrancy

    function test_contractRecipient_callbackCannotReenter() public {
        ReentrantRecipient rr = new ReentrantRecipient();
        uint64 end = uint64(T0 + 1 days);
        Raffle r = _create(1, 5, end);
        rr.setTarget(r);
        usdc.mint(alice, 2 * E);
        vm.prank(alice);
        usdc.approve(address(r), type(uint256).max);
        vm.prank(alice);
        r.buyEntries(address(rr), 2);
        require(rr.reenterBlocked(), "nonReentrant held during _safeMint callback");
        require(r.ownerOf(1) == address(rr), "minted");
    }

    // ------------------------------------------------------------ gas vs EIP-7825 (2^24) per-tx cap

    function test_gas_bounds() public {
        uint256 g = gasleft();
        new RaffleFactory(address(usdc), address(wrapper), treasury);
        uint256 deployGas = g - gasleft();
        require(deployGas < 16_777_216, "factory deploy under tx cap");

        nft.mint(sponsor, 99);
        vm.prank(sponsor);
        nft.approve(address(factory), 99);
        vm.prank(sponsor);
        g = gasleft();
        Raffle r = Raffle(payable(factory.createRaffle(_params(recipient, address(nft), 99, 5, uint64(T0 + 1 days)))));
        uint256 createGas = g - gasleft();

        for (uint256 i; i < 100; ++i) {
            _buy(r, alice, 1);
        }
        vm.warp(T0 + 3 days + 1);
        r.enableRefunds();
        uint256[] memory ids = new uint256[](100);
        for (uint256 i; i < 100; ++i) {
            ids[i] = i + 1;
        }
        vm.prank(alice);
        g = gasleft();
        r.refundTickets(ids);
        uint256 refundGas = g - gasleft();
        require(refundGas < 16_777_216, "refund batch under tx cap");
        emit GasReport(deployGas, createGas, refundGas);
    }

    event GasReport(uint256 factoryDeploy, uint256 createRaffle, uint256 refund100);
}

contract ReentrantRecipient {
    Raffle internal target;
    bool public reenterBlocked;

    function setTarget(Raffle r) external {
        target = r;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        try target.enableRefunds() {
            reenterBlocked = false;
        } catch (bytes memory reason) {
            reenterBlocked = bytes4(reason) == bytes4(keccak256("ReentrancyGuardReentrantCall()"));
        }
        return this.onERC721Received.selector;
    }
}
