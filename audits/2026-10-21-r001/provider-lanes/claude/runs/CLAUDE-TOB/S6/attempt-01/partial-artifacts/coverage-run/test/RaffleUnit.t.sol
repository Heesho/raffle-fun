// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { VRFV2PlusWrapperConsumerBase } from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Raffle } from "raffle/Raffle.sol";
import { RaffleFactory } from "raffle/RaffleFactory.sol";
import { IRaffle } from "raffle/interfaces/IRaffle.sol";
import { IRaffleFactory } from "raffle/interfaces/IRaffleFactory.sol";

import { MockPrizeNFT } from "../src/mocks/MockPrizeNFT.sol";
import { MockUSDC } from "../src/mocks/MockUSDC.sol";
import { MockVRFV2PlusWrapper } from "../src/mocks/MockVRFV2PlusWrapper.sol";
import { EthRejecter, FixedPriceMarket, ForceSender, ReentrantPrizeNFT, ReentrantRecipient } from "./Helpers.sol";
import { TestBase } from "./Vm.sol";

abstract contract Fixture is TestBase {
    MockUSDC internal usdc;
    MockVRFV2PlusWrapper internal wrapper;
    MockPrizeNFT internal nft;
    RaffleFactory internal factory;

    address internal constant TREASURY = address(0x7EA5);
    address internal sponsor = address(0x5905);
    address internal sponsorRecipient = address(0x5EC1);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal carol = address(0xCA201);
    uint256 internal prizeSeq;

    function setUp() public virtual {
        vm.warp(1_700_000_000);
        usdc = new MockUSDC();
        wrapper = new MockVRFV2PlusWrapper();
        nft = new MockPrizeNFT();
        factory = new RaffleFactory(address(usdc), address(wrapper), TREASURY);
        vm.deal(address(this), 100 ether);
    }

    receive() external payable { }

    function _bound(uint256 x, uint256 lo, uint256 hi) internal pure returns (uint256) {
        return lo + (x % (hi - lo + 1));
    }

    function _create(address sponsor_, address recipient_, uint128 reserve, uint256 duration) internal returns (Raffle r) {
        return _createWith(nft, sponsor_, recipient_, reserve, duration);
    }

    function _createWith(MockPrizeNFT prize, address sponsor_, address recipient_, uint128 reserve, uint256 duration)
        internal
        returns (Raffle r)
    {
        uint256 id = ++prizeSeq;
        prize.mint(sponsor_, id);
        vm.prank(sponsor_);
        prize.approve(address(factory), id);
        vm.prank(sponsor_);
        r = Raffle(
            payable(
                factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: recipient_,
                        prizeToken: address(prize),
                        prizeTokenId: id,
                        reserveEntries: reserve,
                        endTime: uint64(block.timestamp + duration)
                    })
                )
            )
        );
    }

    function _buy(Raffle r, address buyer, address recipient, uint128 n) internal returns (uint256 id) {
        usdc.mint(buyer, uint256(n) * 1e6);
        vm.prank(buyer);
        usdc.approve(address(r), type(uint256).max);
        vm.prank(buyer);
        id = r.buyEntries(recipient, n);
    }

    function _request(Raffle r) internal returns (uint256) {
        return r.requestDraw{ value: wrapper.priceNative() }();
    }

    function _fulfill(uint256 requestId, uint256 word) internal returns (bool ok, uint256 gasUsed) {
        uint256[] memory w = new uint256[](1);
        w[0] = word;
        return wrapper.fulfill(requestId, w);
    }

    function _winningTicket(Raffle r) internal view returns (uint256) {
        uint128 w = r.winningEntry();
        for (uint256 id = 1; id <= r.ticketCount(); ++id) {
            (uint128 f, uint128 l) = r.ticketRange(id);
            if (w >= f && w <= l) return id;
        }
        return 0;
    }

    /// @dev CREATE address for nonce in [1,0x7f].
    function _createAddr(address deployer, uint256 nonce) internal pure returns (address) {
        require(nonce > 0 && nonce < 0x80, "nonce range");
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(uint8(nonce)))))));
    }
}

/// ===================================================================================================================
/// A. Lifecycle timing conformance with DESIGN.md
/// ===================================================================================================================
contract A_TimingTest is Fixture {
    function test_A1_saleEndsExclusivelyAtEndTime() public {
        Raffle r = _create(sponsor, sponsorRecipient, 5, 1 days);
        uint256 end = r.endTime();
        vm.warp(end - 1);
        _buy(r, alice, alice, 1);
        vm.warp(end);
        usdc.mint(alice, 1e6);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.SaleEnded.selector, end, end));
        vm.prank(alice);
        r.buyEntries(alice, 1);
    }

    function test_A2_requestWindowIsHalfOpen_endTime_to_endPlus2Days() public {
        Raffle r1 = _create(sponsor, sponsorRecipient, 5, 1 days);
        Raffle r2 = _create(sponsor, sponsorRecipient, 5, 1 days);
        Raffle r3 = _create(sponsor, sponsorRecipient, 5, 1 days);
        _buy(r1, alice, alice, 1);
        _buy(r2, alice, alice, 1);
        _buy(r3, alice, alice, 1);
        uint256 end = r1.endTime();
        vm.warp(end - 1);
        uint256 price = wrapper.priceNative();
        vm.expectRevert(abi.encodeWithSelector(IRaffle.RaffleNotEnded.selector, end, end - 1));
        r1.requestDraw{ value: price }();
        vm.warp(end);
        _request(r1); // first instant of the window
        vm.warp(end + 2 days - 1);
        _request(r2); // last instant of the window
        vm.warp(end + 2 days);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.DrawRequestWindowExpired.selector, end + 2 days, end + 2 days));
        r3.requestDraw{ value: price }();
        assertTrue(r1.status() == IRaffle.Status.Drawing && r2.status() == IRaffle.Status.Drawing, "drawing");
    }

    function test_A3_refundsOpenExactlyAtRequestDeadline() public {
        Raffle r = _create(sponsor, sponsorRecipient, 5, 1 days);
        _buy(r, alice, alice, 3);
        uint256 deadline = uint256(r.endTime()) + 2 days;
        vm.warp(deadline - 1);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.RefundsNotAvailable.selector, deadline, deadline - 1));
        r.enableRefunds();
        vm.warp(deadline);
        r.enableRefunds();
        assertEq(r.remainingRefundLiability(), 3e6, "liability");
    }

    function test_A4_callbackAcceptedStrictlyBeforeCallbackDeadline() public {
        Raffle a = _create(sponsor, sponsorRecipient, 1, 1 days);
        Raffle b = _create(sponsor, sponsorRecipient, 1, 1 days);
        _buy(a, alice, alice, 2);
        _buy(b, alice, alice, 2);
        vm.warp(a.endTime());
        uint256 ida = _request(a);
        uint256 idb = _request(b);
        uint256 cbDeadline = block.timestamp + 2 days;
        vm.warp(cbDeadline - 1);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.RefundsNotAvailable.selector, cbDeadline, cbDeadline - 1));
        b.enableRefunds();
        (bool ok,) = _fulfill(ida, 7);
        assertTrue(ok && a.status() == IRaffle.Status.NftWon, "accepted at deadline-1");
        vm.warp(cbDeadline);
        (ok,) = _fulfill(idb, 7);
        assertTrue(ok && b.status() == IRaffle.Status.Drawing && b.winningEntry() == 0, "ignored at deadline");
        b.enableRefunds();
        assertTrue(b.status() == IRaffle.Status.Refunding, "refunds at deadline");
    }
}

/// ===================================================================================================================
/// B. Economics: exact splits, refunds, conservation
/// ===================================================================================================================
contract B_EconomicsTest is Fixture {
    function testFuzz_B1_settlementSplitsAreExactAndLossless(uint256 entriesSeed, bool reserveMet, uint256 word) public {
        uint128 n = uint128(_bound(entriesSeed, 1, 1e12));
        Raffle r = _create(sponsor, sponsorRecipient, reserveMet ? n : n + 1, 1 days);
        _buy(r, alice, bob, n);
        vm.warp(r.endTime());
        _fulfill(_request(r), word);
        uint256 gross = uint256(n) * 1e6;
        IRaffle.Status st = r.status();
        assertTrue(st == (reserveMet ? IRaffle.Status.NftWon : IRaffle.Status.CashWon), "outcome");
        uint256 cash = r.settleWinningTicket(1);
        assertEq(r.protocolFees(), gross / 20, "5% fee");
        if (reserveMet) {
            assertEq(cash, 0, "no cash");
            assertEq(r.sponsorProceeds(), gross * 19 / 20, "95% sponsor");
        } else {
            assertEq(cash, gross * 4 / 5, "80% winner");
            assertEq(r.sponsorProceeds(), gross * 3 / 20, "15% sponsor");
        }
        assertEq(r.protocolFees() + r.sponsorProceeds() + r.winnerProceeds(), gross, "lossless");
        r.releaseProtocolFees();
        r.releaseSponsorProceeds();
        vm.prank(bob);
        r.redeemWinningTicket(1);
        if (!reserveMet) r.releaseSponsorPrize();
        assertEq(usdc.balanceOf(address(r)), 0, "no dust left");
        assertEq(usdc.balanceOf(TREASURY) + usdc.balanceOf(sponsorRecipient) + usdc.balanceOf(bob), gross, "conservation");
        address prizeOwner = nft.ownerOf(r.prizeTokenId());
        assertEq(prizeOwner, reserveMet ? bob : sponsorRecipient, "prize destination");
    }

    function testFuzz_B2_refundPaysExactlyPerEntryAndReturnsPrize(uint256 a, uint256 b, uint256 c) public {
        Raffle r = _create(sponsor, sponsorRecipient, 1_000, 1 days);
        uint256 t1 = _buy(r, alice, alice, uint128(_bound(a, 1, 1e9)));
        uint256 t2 = _buy(r, bob, alice, uint128(_bound(b, 1, 1e9)));
        uint256 t3 = _buy(r, carol, carol, uint128(_bound(c, 1, 1e9)));
        vm.warp(uint256(r.endTime()) + 2 days);
        r.enableRefunds();
        uint256[] memory ids = new uint256[](2);
        ids[0] = t1;
        ids[1] = t2;
        vm.prank(alice);
        uint256 paid = r.refundTickets(ids);
        assertEq(paid, (_bound(a, 1, 1e9) + _bound(b, 1, 1e9)) * 1e6, "alice refund");
        ids = new uint256[](1);
        ids[0] = t3;
        vm.prank(carol);
        r.refundTickets(ids);
        assertEq(r.remainingRefundLiability(), 0, "liability cleared");
        assertEq(usdc.balanceOf(address(r)), 0, "no residue");
        r.releaseSponsorPrize();
        assertEq(nft.ownerOf(r.prizeTokenId()), sponsorRecipient, "prize returned");
    }

    function test_B3_entryCountOverflowGuardAndMaxRaffleStillSettles() public {
        Raffle r = _create(sponsor, sponsorRecipient, type(uint128).max, 1 days);
        _buy(r, alice, alice, type(uint128).max);
        usdc.mint(bob, 1e6);
        vm.prank(bob);
        usdc.approve(address(r), 1e6);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.TotalEntriesOverflow.selector, type(uint128).max, uint128(1)));
        vm.prank(bob);
        r.buyEntries(bob, 1);
        vm.warp(r.endTime());
        _fulfill(_request(r), type(uint256).max);
        assertTrue(r.status() == IRaffle.Status.NftWon, "reserve met at max");
        r.settleWinningTicket(1);
        assertEq(r.protocolFees() + r.sponsorProceeds(), uint256(type(uint128).max) * 1e6, "lossless at max");
    }

    function test_B4_refundBatchBoundsDuplicatesAndForeignTickets() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1_000, 1 days);
        uint256 mine = _buy(r, alice, alice, 1);
        uint256 theirs = _buy(r, bob, bob, 1);
        vm.warp(uint256(r.endTime()) + 2 days);
        r.enableRefunds();
        uint256[] memory empty = new uint256[](0);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidTicketBatchSize.selector, 0, 100));
        vm.prank(alice);
        r.refundTickets(empty);
        uint256[] memory big = new uint256[](101);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidTicketBatchSize.selector, 101, 100));
        vm.prank(alice);
        r.refundTickets(big);
        uint256[] memory dup = new uint256[](2);
        dup[0] = mine;
        dup[1] = mine;
        vm.expectRevert();
        vm.prank(alice);
        r.refundTickets(dup);
        uint256[] memory foreign = new uint256[](1);
        foreign[0] = theirs;
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NotTicketOwner.selector, theirs, alice, bob));
        vm.prank(alice);
        r.refundTickets(foreign);
    }
}

/// ===================================================================================================================
/// C. Chainlink VRF integration
/// ===================================================================================================================
contract C_VrfTest is Fixture {
    function test_C1_synchronousCallbackDuringRequestIsIgnored() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        _buy(r, alice, alice, 3);
        vm.warp(r.endTime());
        wrapper.setSyncCallback(true);
        uint256 id = _request(r);
        assertTrue(r.status() == IRaffle.Status.Drawing && r.winningEntry() == 0, "sync callback ignored");
        _fulfill(id, 5);
        assertTrue(r.status() == IRaffle.Status.NftWon && r.winningEntry() == 3, "real callback resolves");
    }

    function test_C2_wrongIdWrongLengthReplayAreIgnoredWithoutReverting() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        _buy(r, alice, alice, 3);
        vm.warp(r.endTime());
        uint256 id = _request(r);
        uint256[] memory none = new uint256[](0);
        uint256[] memory two = new uint256[](2);
        uint256[] memory one = new uint256[](1);
        assertTrue(wrapper.fulfillRaw(address(r), id + 1, one), "wrong id no revert");
        assertTrue(wrapper.fulfillRaw(address(r), id, none), "0 words no revert");
        assertTrue(wrapper.fulfillRaw(address(r), id, two), "2 words no revert");
        assertTrue(r.status() == IRaffle.Status.Drawing, "still drawing");
        _fulfill(id, 1);
        uint128 w = r.winningEntry();
        one[0] = 2;
        assertTrue(wrapper.fulfillRaw(address(r), id, one), "replay no revert");
        assertTrue(r.winningEntry() == w, "replay ignored");
    }

    function test_C3_onlyWrapperCanDeliverRandomness() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        uint256[] memory one = new uint256[](1);
        vm.expectRevert(
            abi.encodeWithSelector(VRFV2PlusWrapperConsumerBase.OnlyVRFWrapperCanFulfill.selector, alice, address(wrapper))
        );
        vm.prank(alice);
        r.rawFulfillRandomWords(1, one);
    }

    function test_C4_callbackGasIsFarBelowLimit() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        _buy(r, alice, alice, 3);
        vm.warp(r.endTime());
        (bool ok, uint256 gasUsed) = _fulfill(_request(r), 123);
        assertTrue(ok, "callback ok");
        assertTrue(gasUsed < 100_000, "callback gas < 100k of 300k limit");
        emit log_named_uint("fulfillRandomWords gas (incl. call overhead)", gasUsed);
    }

    event log_named_uint(string key, uint256 val);

    function test_C5_excessFeeRefundedAndRefundFailureRevertsWholeRequest() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        _buy(r, alice, alice, 1);
        vm.warp(r.endTime());
        EthRejecter rej = new EthRejecter();
        uint256 price = wrapper.priceNative();
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NativeRefundFailed.selector, address(rej), 1));
        rej.callRequestDraw{ value: price + 1 }(IRaffle(address(r)));
        assertTrue(r.status() == IRaffle.Status.Active, "state rolled back");
        rej.callRequestDraw{ value: price }(IRaffle(address(r))); // exact fee: no refund needed
        assertTrue(r.status() == IRaffle.Status.Drawing && address(r).balance == 0, "drawing, no ETH retained");
    }

    function test_C6_insufficientFeeReverts() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        _buy(r, alice, alice, 1);
        vm.warp(r.endTime());
        uint256 price = wrapper.priceNative();
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InsufficientVrfFee.selector, price, price - 1));
        r.requestDraw{ value: price - 1 }();
    }
}

/// ===================================================================================================================
/// D. Redemption, delivery atomicity, independent claims
/// ===================================================================================================================
contract D_RedemptionTest is Fixture {
    function test_D1_onlyCurrentOwnerRedeems() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        _buy(r, alice, alice, 4);
        vm.prank(alice);
        r.setApprovalForAll(carol, true);
        vm.warp(r.endTime());
        _fulfill(_request(r), 0);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NotTicketOwner.selector, 1, carol, alice));
        vm.prank(carol); // approved operator is not enough
        r.redeemWinningTicket(1);
        vm.prank(alice);
        r.transferFrom(alice, bob, 1); // bearer claim moves after resolution
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NotTicketOwner.selector, 1, alice, bob));
        vm.prank(alice);
        r.redeemWinningTicket(1);
        vm.prank(bob);
        r.redeemWinningTicket(1);
        assertEq(nft.ownerOf(r.prizeTokenId()), bob, "current owner got NFT");
    }

    function test_D2_deliveryFailureRevertsBurnAndInlineSettlement() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        _buy(r, alice, alice, 4);
        vm.warp(r.endTime());
        _fulfill(_request(r), 0);
        nft.setFrozen(true);
        vm.expectRevert(bytes("PRZ: frozen"));
        vm.prank(alice);
        r.redeemWinningTicket(1);
        assertEq(r.ownerOf(1), alice, "ticket not burned");
        assertTrue(!r.settlementComplete() && !r.winnerRedeemed() && !r.prizeClaimed(), "no partial effects");
    }

    function test_D3_sponsorAndTreasuryClaimIndependently_blocklistedSponsorRecipient() public {
        Raffle r = _create(sponsor, sponsorRecipient, 10, 1 days);
        _buy(r, alice, alice, 4);
        vm.warp(r.endTime());
        _fulfill(_request(r), 0);
        r.settleWinningTicket(1);
        usdc.setBlocked(sponsorRecipient, true);
        vm.expectRevert(bytes("USDC: blocked"));
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        vm.prank(alice);
        r.redeemWinningTicket(1);
        assertEq(usdc.balanceOf(TREASURY), 200_000, "treasury paid");
        assertEq(usdc.balanceOf(alice), 3_200_000, "winner paid");
        assertEq(r.sponsorProceeds(), 600_000, "sponsor share still escrowed");
    }

    function test_D4_settlementWithNonWinningOrNonexistentTicketReverts() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        _buy(r, alice, alice, 2); // ticket 1: entries 1-2
        _buy(r, bob, bob, 3); // ticket 2: entries 3-5
        vm.warp(r.endTime());
        _fulfill(_request(r), 3); // 3 % 5 + 1 = 4 -> ticket 2
        vm.expectRevert(abi.encodeWithSelector(IRaffle.TicketDoesNotContainWinningEntry.selector, 1, uint128(4)));
        r.settleWinningTicket(1);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.TicketDoesNotContainWinningEntry.selector, 99, uint128(4)));
        r.settleWinningTicket(99);
        r.settleWinningTicket(2);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.WinningTicketMismatch.selector, 1, 2));
        vm.prank(alice);
        r.redeemWinningTicket(1);
    }
}

/// ===================================================================================================================
/// E. Access control, initialization, factory validation
/// ===================================================================================================================
contract E_AccessTest is Fixture {
    function test_E1_implementationIsLockedAndInert() public {
        Raffle impl = Raffle(payable(factory.raffleImplementation()));
        assertTrue(impl.initialized() && impl.status() == IRaffle.Status.Refunding, "locked");
        IRaffle.RaffleInitParams memory p;
        vm.expectRevert(IRaffle.AlreadyInitialized.selector);
        vm.prank(address(factory));
        impl.initialize(p);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.Refunding));
        impl.buyEntries(alice, 1);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.Refunding));
        impl.enableRefunds();
        vm.expectRevert();
        impl.releaseSponsorPrize(); // prizeToken == address(0): call to non-contract reverts
    }

    function test_E2_cloneCannotBeReinitialized() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        IRaffle.RaffleInitParams memory p;
        vm.expectRevert(IRaffle.AlreadyInitialized.selector);
        vm.prank(address(factory));
        r.initialize(p);
    }

    function test_E3_factoryRejectsInvalidOrProtocolParameters() public {
        uint256 id = 777;
        nft.mint(sponsor, id);
        vm.prank(sponsor);
        nft.approve(address(factory), id);
        IRaffleFactory.CreateRaffleParams memory p = IRaffleFactory.CreateRaffleParams({
            sponsorRecipient: sponsorRecipient,
            prizeToken: address(nft),
            prizeTokenId: id,
            reserveEntries: 1,
            endTime: uint64(block.timestamp)
        });
        vm.startPrank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.InvalidEndTime.selector, block.timestamp, block.timestamp));
        factory.createRaffle(p);
        p.endTime = uint64(block.timestamp + 30 days + 1);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.SaleDurationTooLong.selector, 30 days + 1, 30 days));
        factory.createRaffle(p);
        p.endTime = uint64(block.timestamp + 1 days);
        p.reserveEntries = 0;
        vm.expectRevert(IRaffleFactory.ZeroReserveEntries.selector);
        factory.createRaffle(p);
        p.reserveEntries = 1;
        p.prizeToken = address(usdc);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsafeProtocolDestination.selector, address(usdc)));
        factory.createRaffle(p);
        p.prizeToken = address(nft);
        p.sponsorRecipient = address(factory);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsafeProtocolDestination.selector, address(factory)));
        factory.createRaffle(p);
        p.sponsorRecipient = address(0);
        vm.expectRevert(IRaffleFactory.ZeroAddress.selector);
        factory.createRaffle(p);
        p.sponsorRecipient = sponsorRecipient;
        p.prizeToken = address(0xdead);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.NotContract.selector, address(0xdead)));
        factory.createRaffle(p);
        vm.stopPrank();
    }

    function test_E4_ticketsCannotBeSentToProtocolPlumbing() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        Raffle other = _create(sponsor, sponsorRecipient, 1, 1 days);
        _buy(r, alice, alice, 1);
        address[6] memory bad =
            [address(r), address(other), address(factory), address(usdc), address(wrapper), factory.raffleImplementation()];
        for (uint256 i; i < bad.length; ++i) {
            vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, bad[i]));
            vm.prank(alice);
            r.transferFrom(alice, bad[i], 1);
        }
    }
}

/// ===================================================================================================================
/// F. Reentrancy by untrusted ticket recipients and prize contracts
/// ===================================================================================================================
contract F_ReentrancyTest is Fixture {
    function test_F1_ticketRecipientCannotReenterAnyGuardedEntryPoint() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        ReentrantRecipient rr = new ReentrantRecipient();
        rr.arm(IRaffle(address(r)));
        _buy(r, alice, address(rr), 2);
        assertEq(rr.errorCount(), 9, "nine attempts");
        for (uint256 i; i < 9; ++i) {
            assertTrue(rr.errors(i) == ReentrancyGuard.ReentrancyGuardReentrantCall.selector, "blocked by guard");
        }
    }

    function test_F2_maliciousPrizeCannotReenterDuringDelivery() public {
        ReentrantPrizeNFT evil = new ReentrantPrizeNFT();
        Raffle r = _createWith(evil, sponsor, sponsorRecipient, 1, 1 days);
        _buy(r, alice, alice, 2);
        vm.warp(r.endTime());
        _fulfill(_request(r), 0);
        evil.armHook(IRaffle(address(r)));
        vm.prank(alice);
        r.redeemWinningTicket(1);
        assertEq(evil.errorCount(), 5, "five attempts");
        for (uint256 i; i < 5; ++i) {
            assertTrue(evil.errors(i) == ReentrancyGuard.ReentrancyGuardReentrantCall.selector, "blocked by guard");
        }
        assertEq(evil.ownerOf(r.prizeTokenId()), alice, "delivered");
    }
}

/// ===================================================================================================================
/// G. Proofs of concept for manual-review findings
/// ===================================================================================================================
contract G_FindingsTest is Fixture {
    /// TOB-S6-1: destination screening is time-of-check and skips code-less addresses. A sponsor recipient set to the
    /// factory's next CREATE address passes validation; once a raffle is deployed there, releaseSponsorPrize moves the
    /// prize NFT INTO that other raffle clone (no runtime re-check) and sponsor quote proceeds become permanently
    /// unclaimable (runtime re-check reverts forever because the recipient is immutable).
    function test_G1_PoC_futureCloneSponsorRecipient_movesPrizeIntoAnotherClone() public {
        uint64 n = vm.getNonce(address(factory));
        address futureB = _createAddr(address(factory), n + 1);
        Raffle a = _create(sponsor, futureB, 10, 1 days); // validation passes: futureB has no code yet
        Raffle b = _create(bob, address(0xB0B5EC), 1, 1 days);
        assertEq(address(b), futureB, "B deployed at A.sponsorRecipient");
        assertTrue(factory.isRaffle(futureB), "registered raffle clone");
        _buy(a, alice, alice, 4); // reserve 10 missed -> CashWon
        vm.warp(a.endTime());
        _fulfill(_request(a), 0);
        a.settleWinningTicket(1);
        a.releaseSponsorPrize(); // succeeds: no runtime protocol-destination check on the NFT path
        assertEq(nft.ownerOf(a.prizeTokenId()), address(b), "prize NFT now held by raffle clone B");
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuoteDestination.selector, futureB));
        a.releaseSponsorProceeds(); // 15% sponsor share can never be released
        assertEq(a.sponsorProceeds(), 600_000, "sponsor share stranded in A");
        assertTrue(b.prizeTokenId() != a.prizeTokenId(), "B has no accounting/rescue path for A's NFT");
    }

    /// TOB-S6-1 (ticket variant): a ticket minted to the next clone address passes the mint-time screen; after the clone is
    /// deployed the winning ticket is owned by a raffle and can never be redeemed, while sponsor/treasury are paid.
    function test_G2_PoC_ticketMintedToFutureCloneAddressIsStranded() public {
        uint64 n = vm.getNonce(address(factory));
        Raffle a = _create(sponsor, sponsorRecipient, 1, 1 days);
        address futureB = _createAddr(address(factory), n + 1);
        _buy(a, alice, futureB, 1); // accepted: code-less recipient, registry not queried
        Raffle b = _create(bob, address(0xB0B5EC), 1, 1 days);
        assertEq(address(b), futureB, "clone deployed at ticket owner address");
        assertEq(a.ownerOf(1), address(b), "winning ticket owned by a raffle clone");
        usdc.mint(alice, 1e6);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, futureB));
        vm.prank(alice);
        a.buyEntries(futureB, 1); // the same recipient is now rejected: the check is time-of-check only
        vm.warp(a.endTime());
        _fulfill(_request(a), 0);
        a.settleWinningTicket(1);
        a.releaseSponsorProceeds();
        a.releaseProtocolFees();
        assertEq(nft.ownerOf(a.prizeTokenId()), address(a), "NFT can only leave via redeem by raffle B (impossible)");
    }

    /// TOB-S6-2: the winning entry is a pure function of the random word, which is public before the callback lands,
    /// and tickets stay transferable in Drawing. A searcher can buy a listed winning ticket ahead of fulfillment.
    function test_G3_PoC_vrfRevealFrontRun_buysListedWinningTicketBeforeCallback() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        _buy(r, alice, alice, 10); // ticket 1: entries 1-10
        _buy(r, bob, bob, 10); // ticket 2: entries 11-20
        vm.warp(r.endTime());
        uint256 requestId = _request(r);
        FixedPriceMarket market = new FixedPriceMarket();
        vm.prank(alice);
        r.setApprovalForAll(address(market), true);
        vm.prank(alice);
        market.list(IERC721(address(r)), 1, 0.5 ether); // alice lists her ticket while the draw is pending
        uint256 word = 4; // value carried by the pending fulfillment transaction
        uint128 winningEntry = uint128(word % r.totalEntries() + 1); // = 5 -> ticket 1
        (uint128 f, uint128 l) = r.ticketRange(1);
        assertTrue(winningEntry >= f && winningEntry <= l, "searcher identifies listed winner");
        address searcher = address(0x5EA2C4);
        vm.deal(searcher, 1 ether);
        vm.prank(searcher);
        market.buy{ value: 0.5 ether }(IERC721(address(r)), 1); // ordered before the callback
        _fulfill(requestId, word);
        vm.prank(searcher);
        r.redeemWinningTicket(1);
        assertEq(nft.ownerOf(r.prizeTokenId()), searcher, "searcher wins the prize for 0.5 ETH");
    }

    /// TOB-S6-3: sponsor proceeds in NftWon are not conditioned on prize delivery. If the (untrusted) prize collection
    /// freezes transfers after resolution, the sponsor and treasury are paid while the winner receives nothing.
    function test_G4_PoC_frozenPrizeCollection_sponsorPaidWinnerUnpaid() public {
        Raffle r = _create(sponsor, sponsorRecipient, 5, 1 days);
        _buy(r, alice, alice, 50);
        vm.warp(r.endTime());
        _fulfill(_request(r), 0);
        assertTrue(r.status() == IRaffle.Status.NftWon, "reserve met");
        nft.setFrozen(true); // collection admin (possibly the sponsor) blocks transfers
        r.settleWinningTicket(1);
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        assertEq(usdc.balanceOf(sponsorRecipient), 47_500_000, "sponsor received 95%");
        vm.expectRevert(bytes("PRZ: frozen"));
        vm.prank(alice);
        r.redeemWinningTicket(1);
        assertEq(usdc.balanceOf(address(r)), 0, "no funds left for any fallback");
    }

    /// TOB-S6-4: undocumented-in-DESIGN sponsor cancellation of an empty raffle before endTime, and refunds for empty
    /// raffles open at endTime rather than at the draw-request deadline.
    function test_G5_PoC_emptyRaffleCancellationPaths() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 10 days);
        vm.prank(sponsor);
        r.enableRefunds(); // nine+ days before the sale ends
        assertTrue(r.status() == IRaffle.Status.Refunding, "sponsor cancelled");
        usdc.mint(alice, 1e6);
        vm.prank(alice);
        usdc.approve(address(r), 1e6);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.Refunding));
        vm.prank(alice);
        r.buyEntries(alice, 1); // a pending first purchase is pre-empted
        r.releaseSponsorPrize();
        Raffle s = _create(sponsor, sponsorRecipient, 1, 1 days);
        vm.warp(s.endTime());
        vm.prank(carol);
        s.enableRefunds(); // anyone, at endTime (not endTime + 2 days)
        assertTrue(s.status() == IRaffle.Status.Refunding, "empty raffle closed at endTime");
    }

    /// TOB-S6-5: value forced into a raffle (SELFDESTRUCT ETH, direct USDC, unsafe NFT transfers) is unrecoverable.
    function test_G6_forcedValueIsStranded() public {
        Raffle r = _create(sponsor, sponsorRecipient, 1, 1 days);
        ForceSender fs = new ForceSender{ value: 1 ether }();
        fs.boom(payable(address(r)));
        usdc.mint(address(r), 5e6);
        nft.mint(alice, 4242);
        vm.prank(alice);
        nft.transferFrom(alice, address(r), 4242);
        assertEq(address(r).balance, 1 ether, "ETH stuck");
        assertEq(usdc.balanceOf(address(r)) - r.accountedQuoteBalance(), 5e6, "USDC outside accounting");
        assertEq(nft.ownerOf(4242), address(r), "NFT stuck");
        (bool ok, bytes memory ret) = address(r).call{ value: 1 }("");
        assertTrue(!ok && bytes4(ret) == Raffle.DirectNativeTransfer.selector, "direct ETH rejected");
    }
}
