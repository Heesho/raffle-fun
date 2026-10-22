// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

// GENERATED SCRATCH TEST CODE (S6 attempt-02). Deterministic Foundry scenarios + bounded fuzz tests against the
// UNMODIFIED production RaffleFactory/Raffle (ERC-1167 clones). forge-std is not among the provided inputs, so a local
// cheatcode interface and require()-based assertions are used. Scenario names map to report sections:
//   lifecycle/timing      -> Step 4 properties SM-*, A-*, EI-*
//   calls-loop trace      -> Step 1 triage of Slither calls-loop (runtime evidence)
//   S6-F* demonstrations  -> Step 5 manual-review findings

import { IRaffle } from "../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../src/interfaces/IRaffleFactory.sol";
import { RaffleFactory } from "../../src/RaffleFactory.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { LyingPrizeNFT, MockPrizeNFT, PausablePrizeNFT } from "../mocks/MockPrizeNFTs.sol";
import { MockUSDC } from "../mocks/MockUSDC.sol";
import { MockVRFWrapper } from "../mocks/MockVRFWrapper.sol";

interface Vm {
    function warp(uint256) external;
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function deal(address, uint256) external;
    function expectRevert() external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
    function expectCall(address callee, bytes calldata data, uint64 count) external;
    function snapshotState() external returns (uint256);
    function revertToState(uint256) external returns (bool);
    function getNonce(address) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
    function assume(bool) external;
}

contract RaffleScenarioBase {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    uint256 internal constant PRICE = 1_000_000;

    address internal constant TREASURY = address(uint160(0x7EA5));
    address internal constant SPONSOR = address(uint160(0x5905));
    address internal constant SPONSOR_RECIPIENT = address(uint160(0x5CA1E));
    address internal constant ALICE = address(uint160(0xA11CE));
    address internal constant BOB = address(uint160(0xB0B));
    address internal constant CAROL = address(uint160(0xCA401));
    address internal constant SEARCHER = address(uint160(0x5EA4C4));
    address internal constant KEEPER = address(uint160(0x4EE9E4));

    MockUSDC internal usdc;
    MockVRFWrapper internal wrapper;
    MockPrizeNFT internal nft;
    RaffleFactory internal factory;

    event log_named_uint(string key, uint256 val);
    event log_named_address(string key, address val);
    event log_string(string val);

    function setUp() public virtual {
        vm.warp(1_800_000_000);
        usdc = new MockUSDC();
        wrapper = new MockVRFWrapper();
        nft = new MockPrizeNFT();
        factory = new RaffleFactory(address(usdc), address(wrapper), TREASURY);
    }

    function _eq(uint256 a, uint256 b, string memory what) internal pure {
        if (a != b) revert(string.concat(what, ": got ", _u(a), " want ", _u(b)));
    }

    function _u(uint256 v) internal pure returns (string memory s) {
        if (v == 0) return "0";
        bytes memory b;
        while (v != 0) {
            b = abi.encodePacked(bytes1(uint8(48 + v % 10)), b);
            v /= 10;
        }
        s = string(b);
    }

    function _create(address prizeToken, uint256 tokenId, uint128 reserve, uint64 duration, address recipient)
        internal
        returns (IRaffle r)
    {
        vm.startPrank(SPONSOR);
        IERC721(prizeToken).approve(address(factory), tokenId);
        r = IRaffle(
            factory.createRaffle(
                IRaffleFactory.CreateRaffleParams({
                    sponsorRecipient: recipient,
                    prizeToken: prizeToken,
                    prizeTokenId: tokenId,
                    reserveEntries: reserve,
                    endTime: uint64(block.timestamp) + duration
                })
            )
        );
        vm.stopPrank();
    }

    function _newRaffle(uint128 reserve) internal returns (IRaffle r, uint256 tokenId) {
        tokenId = 1000 + factory.raffleCount();
        nft.mint(SPONSOR, tokenId);
        r = _create(address(nft), tokenId, reserve, 7 days, SPONSOR_RECIPIENT);
    }

    function _buy(IRaffle r, address buyer, uint128 count) internal returns (uint256 ticketId) {
        uint256 cost = uint256(count) * PRICE;
        usdc.mint(buyer, cost);
        vm.startPrank(buyer);
        usdc.approve(address(r), cost);
        ticketId = r.buyEntries(buyer, count);
        vm.stopPrank();
    }

    function _drawAndResolve(IRaffle r, uint256 word) internal {
        vm.warp(r.endTime());
        vm.deal(KEEPER, 1 ether);
        vm.prank(KEEPER);
        r.requestDraw{ value: wrapper.fee() }();
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        (bool ok,) = wrapper.fulfill(address(r), r.vrfRequestId(), words);
        require(ok, "callback reverted");
    }

    function _winningTicket(IRaffle r) internal view returns (uint256) {
        uint256 w = r.winningEntry();
        for (uint256 i = 1; i <= r.ticketCount(); ++i) {
            (uint128 f, uint128 l) = r.ticketRange(i);
            if (w >= f && w <= l) return i;
        }
        return 0;
    }
}

contract RaffleLifecycleTest is RaffleScenarioBase {
    function test_nftWon_fullLifecycle_bearerTransfer_and_exactSplit() public {
        (IRaffle r, uint256 tokenId) = _newRaffle(3);
        _buy(r, ALICE, 2); // entries 1-2
        _buy(r, BOB, 1); // entry 3
        _buy(r, CAROL, 2); // entries 4-5
        wrapper.setFee(0.01 ether);
        vm.warp(r.endTime());
        vm.deal(KEEPER, 1 ether);
        vm.prank(KEEPER);
        r.requestDraw{ value: 0.3 ether }();
        _eq(KEEPER.balance, 1 ether - 0.01 ether, "excess VRF fee refunded");
        _eq(address(r).balance, 0, "no ETH retained");
        uint256[] memory words = new uint256[](1);
        words[0] = 2; // entry 3 -> BOB's ticket #2
        wrapper.fulfill(address(r), r.vrfRequestId(), words);
        require(r.status() == IRaffle.Status.NftWon, "NftWon");
        _eq(r.winningEntry(), 3, "winning entry");
        vm.prank(KEEPER);
        r.settleWinningTicket(2); // permissionless settlement
        _eq(r.protocolFees(), 250_000, "5% fee");
        _eq(r.sponsorProceeds(), 4_750_000, "95% sponsor");
        _eq(r.winnerProceeds(), 0, "no cash in NftWon");
        vm.prank(BOB);
        IERC721(address(r)).transferFrom(BOB, CAROL, 2); // bearer claim moves after settlement
        vm.prank(BOB);
        vm.expectRevert();
        r.redeemWinningTicket(2);
        vm.prank(CAROL);
        r.redeemWinningTicket(2);
        require(nft.ownerOf(tokenId) == CAROL && r.winnerRecipient() == CAROL, "prize to current owner");
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        _eq(usdc.balanceOf(SPONSOR_RECIPIENT), 4_750_000, "sponsor paid");
        _eq(usdc.balanceOf(TREASURY), 250_000, "treasury paid");
        _eq(usdc.balanceOf(address(r)), 0, "raffle drained exactly");
        _eq(r.accountedQuoteBalance(), 0, "no liabilities left");
    }

    function test_cashWon_fullLifecycle_redeemSettles_and_prizeReturns() public {
        (IRaffle r, uint256 tokenId) = _newRaffle(10);
        _buy(r, ALICE, 3);
        _buy(r, BOB, 4);
        _drawAndResolve(r, 5); // entry 6 -> BOB
        require(r.status() == IRaffle.Status.CashWon, "CashWon");
        uint256 w = _winningTicket(r);
        _eq(w, 2, "winning ticket");
        vm.prank(BOB);
        uint256 cash = r.redeemWinningTicket(w); // settles + pays atomically
        _eq(cash, 5_600_000, "80% cash");
        _eq(usdc.balanceOf(BOB), 5_600_000, "cash delivered");
        _eq(r.sponsorProceeds(), 1_050_000, "15% sponsor");
        _eq(r.protocolFees(), 350_000, "5% fee");
        r.releaseSponsorPrize();
        require(nft.ownerOf(tokenId) == SPONSOR_RECIPIENT, "prize returned");
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        _eq(usdc.balanceOf(address(r)), 0, "drained");
    }

    function test_refundPath_requestWindowLapses_exactBoundaries() public {
        (IRaffle r, uint256 tokenId) = _newRaffle(2);
        uint256 t1 = _buy(r, ALICE, 3);
        uint256 t2 = _buy(r, BOB, 1);
        uint256 deadline = r.drawRequestDeadline();
        vm.warp(deadline - 1);
        vm.expectRevert();
        r.enableRefunds(); // RefundsNotAvailable one second early
        vm.warp(deadline);
        vm.expectRevert();
        r.requestDraw(); // DrawRequestWindowExpired exactly at deadline
        r.enableRefunds();
        require(r.status() == IRaffle.Status.Refunding, "Refunding");
        _eq(r.remainingRefundLiability(), 4_000_000, "liability = pot");
        uint256[] memory ids = new uint256[](1);
        ids[0] = t1;
        vm.prank(BOB);
        vm.expectRevert();
        r.refundTickets(ids); // foreign ticket
        vm.prank(ALICE);
        r.refundTickets(ids);
        ids[0] = t2;
        vm.prank(BOB);
        r.refundTickets(ids);
        _eq(usdc.balanceOf(ALICE), 3_000_000, "alice refunded 100%");
        _eq(usdc.balanceOf(BOB), 1_000_000, "bob refunded 100%");
        r.releaseSponsorPrize();
        require(nft.ownerOf(tokenId) == SPONSOR_RECIPIENT, "prize returned");
        _eq(usdc.balanceOf(address(r)), 0, "drained");
    }

    function test_timingWindows_disjoint_at_every_boundary() public {
        (IRaffle r,) = _newRaffle(1);
        _buy(r, ALICE, 1);
        uint256 endTime = r.endTime();
        uint256 snap = vm.snapshotState();
        vm.warp(endTime - 1);
        vm.expectRevert();
        r.requestDraw(); // RaffleNotEnded
        vm.revertToState(snap);
        vm.warp(endTime);
        r.requestDraw(); // window opens exactly at endTime
        vm.revertToState(snap);
        vm.warp(endTime + 2 days - 1);
        r.requestDraw(); // last second inside the window
        uint256 cbDeadline = r.callbackDeadline();
        _eq(cbDeadline, endTime + 4 days - 1, "callback deadline");
        uint256 snap2 = vm.snapshotState();
        vm.warp(cbDeadline - 1);
        vm.expectRevert();
        r.enableRefunds(); // not yet
        uint256[] memory words = new uint256[](1);
        words[0] = 0;
        wrapper.fulfill(address(r), r.vrfRequestId(), words);
        require(r.status() == IRaffle.Status.NftWon, "accepted strictly before deadline");
        vm.revertToState(snap2);
        vm.warp(cbDeadline);
        (bool ok,) = wrapper.fulfill(address(r), r.vrfRequestId(), words);
        require(ok && r.status() == IRaffle.Status.Drawing, "late callback ignored without revert");
        r.enableRefunds();
        require(r.status() == IRaffle.Status.Refunding, "refunds open at callback deadline");
    }

    function test_vrf_unexpected_inputs_never_revert_and_never_resolve() public {
        (IRaffle r,) = _newRaffle(1);
        _buy(r, ALICE, 5);
        vm.warp(r.endTime());
        r.requestDraw();
        uint256 id = r.vrfRequestId();
        uint256[] memory none = new uint256[](0);
        uint256[] memory two = new uint256[](2);
        uint256[] memory one = new uint256[](1);
        (bool a,) = wrapper.fulfill(address(r), id + 1, one);
        (bool b,) = wrapper.fulfill(address(r), id, none);
        (bool c,) = wrapper.fulfill(address(r), id, two);
        require(a && b && c, "callbacks must not revert");
        require(r.status() == IRaffle.Status.Drawing && r.winningEntry() == 0, "ignored");
        (bool d,) = wrapper.fulfill(address(r), id, one);
        require(d && r.status() == IRaffle.Status.NftWon, "valid word resolves");
        (bool e,) = wrapper.fulfill(address(r), id, one);
        require(e && r.winningEntry() == 1, "duplicate ignored");
        vm.prank(ALICE);
        (bool direct,) =
            address(r).call(abi.encodeWithSignature("rawFulfillRandomWords(uint256,uint256[])", id, one));
        require(!direct, "only the wrapper may fulfill");
    }

    function test_syncCallback_inFlightGuard_then_asyncResolution() public {
        (IRaffle r,) = _newRaffle(1);
        _buy(r, ALICE, 2);
        wrapper.setSyncCallback(true);
        vm.warp(r.endTime());
        r.requestDraw();
        require(wrapper.lastSyncCallbackSucceeded(), "sync callback did not revert");
        require(r.status() == IRaffle.Status.Drawing && r.winningEntry() == 0, "in-flight callback ignored");
        uint256[] memory one = new uint256[](1);
        one[0] = 1;
        wrapper.fulfill(address(r), r.vrfRequestId(), one);
        _eq(r.winningEntry(), 2, "later async callback resolves");
    }

    function test_emptyRaffle_sponsorCancel_only_while_no_entries() public {
        (IRaffle r,) = _newRaffle(5);
        uint256 snap = vm.snapshotState();
        vm.prank(SPONSOR);
        r.enableRefunds(); // sponsor may close an empty raffle immediately
        require(r.status() == IRaffle.Status.Refunding, "closed");
        vm.revertToState(snap);
        _buy(r, ALICE, 1); // a first buyer lands before the sponsor's cancel
        vm.prank(SPONSOR);
        vm.expectRevert();
        r.enableRefunds(); // now locked until drawRequestDeadline
        vm.prank(ALICE);
        vm.expectRevert();
        r.enableRefunds();
    }

    function test_implementation_is_locked_and_inert() public {
        IRaffle impl = IRaffle(factory.raffleImplementation());
        require(impl.initialized() && impl.status() == IRaffle.Status.Refunding, "locked");
        IRaffle.RaffleInitParams memory p = IRaffle.RaffleInitParams({
            sponsor: ALICE,
            sponsorRecipient: ALICE,
            protocolTreasury: ALICE,
            prizeToken: address(nft),
            prizeTokenId: 1,
            raffleId: 1,
            reserveEntries: 1,
            endTime: uint64(block.timestamp + 1)
        });
        vm.prank(address(factory));
        vm.expectRevert(IRaffle.AlreadyInitialized.selector);
        impl.initialize(p);
        vm.expectRevert();
        impl.releaseSponsorPrize(); // prizeToken == address(0): high-level call to a codeless address reverts
        vm.expectRevert();
        impl.enableRefunds();
    }
}

contract RaffleSlitherTriageEvidenceTest is RaffleScenarioBase {
    /// Slither calls-loop flagged refundTickets -> _burn -> _update -> _isProtocolDestination (factory calls).
    /// Runtime evidence: burns pass to == address(0) and short-circuit the screen, so the factory registry is queried
    /// exactly once per refund transaction (by _transferQuote after the loop), independent of batch size.
    function test_callsLoop_isFalsePositive_registryQueriedOncePerRefundTx() public {
        (IRaffle r,) = _newRaffle(1);
        address holder = address(new TicketHolder()); // contract caller => isRaffle(msg.sender) is queried once
        uint256[] memory ids = new uint256[](6);
        for (uint256 i; i < 6; ++i) {
            usdc.mint(holder, PRICE);
            TicketHolder(holder).approveAndBuy(usdc, r, 1);
            ids[i] = i + 1;
        }
        vm.warp(r.endTime());
        vm.prank(SPONSOR);
        vm.expectRevert();
        r.enableRefunds(); // entries sold: sponsor has no early-close right
        vm.warp(r.drawRequestDeadline());
        r.enableRefunds();
        vm.expectCall(address(factory), abi.encodeWithSelector(IRaffleFactory.isRaffle.selector), 1);
        vm.expectCall(address(factory), abi.encodeWithSelector(IRaffleFactory.raffleImplementation.selector), 1);
        TicketHolder(holder).refund(r, ids);
        _eq(usdc.balanceOf(holder), 6 * PRICE, "batch refunded");
    }
}

contract TicketHolder {
    function approveAndBuy(MockUSDC usdc, IRaffle r, uint128 count) external {
        usdc.approve(address(r), uint256(count) * 1_000_000);
        r.buyEntries(address(this), count);
    }

    function refund(IRaffle r, uint256[] calldata ids) external {
        r.refundTickets(ids);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract RaffleFindingDemonstrationsTest is RaffleScenarioBase {
    /// S6-F1: tickets stay transferable while a VRF fulfillment is pending. Anyone who sees the pending fulfillment
    /// (its proof determines the word) can compute the winning entry and buy that ticket off a standing order first.
    function test_F1_ticketsTradeableWhileDrawing_pendingWordDeterminesWinner() public {
        (IRaffle r, uint256 tokenId) = _newRaffle(4);
        _buy(r, ALICE, 2); // ticket 1: entries 1-2
        _buy(r, BOB, 3); // ticket 2: entries 3-5
        vm.warp(r.endTime());
        r.requestDraw();
        require(r.status() == IRaffle.Status.Drawing, "Drawing");
        uint256 pendingWord = 7; // visible in the coordinator fulfillment tx before inclusion
        uint256 predictedEntry = pendingWord % r.totalEntries() + 1; // = 3 -> ticket 2 (BOB)
        _eq(predictedEntry, 3, "predicted");
        // A standing marketplace order by BOB is filled by the searcher before the fulfillment lands.
        usdc.mint(SEARCHER, 1_000_000);
        vm.prank(SEARCHER);
        usdc.transfer(BOB, 1_000_000); // BOB's asking price, oblivious to the pending result
        vm.prank(BOB);
        IERC721(address(r)).transferFrom(BOB, SEARCHER, 2); // transfer allowed in Drawing
        uint256[] memory words = new uint256[](1);
        words[0] = pendingWord;
        wrapper.fulfill(address(r), r.vrfRequestId(), words);
        _eq(r.winningEntry(), predictedEntry, "outcome matches pre-inclusion prediction");
        vm.prank(SEARCHER);
        r.redeemWinningTicket(2);
        require(nft.ownerOf(tokenId) == SEARCHER, "searcher captured the prize for 1 USDC");
    }

    /// S6-F2: sponsor proceeds are independent of prize deliverability. A sponsor-controlled (pausable/admin)
    /// collection lets the sponsor collect 95% of the pot while the winner can never redeem, then reclaim the NFT.
    function test_F2_sponsorControlledPrize_collectsProceeds_while_winnerCannotRedeem() public {
        vm.prank(SPONSOR);
        PausablePrizeNFT ppn = new PausablePrizeNFT();
        ppn.mint(SPONSOR, 1);
        IRaffle r = _create(address(ppn), 1, 2, 7 days, SPONSOR_RECIPIENT);
        _buy(r, ALICE, 50);
        _buy(r, BOB, 50);
        _drawAndResolve(r, 10); // entry 11 -> ALICE ticket 1; reserve met -> NftWon
        require(r.status() == IRaffle.Status.NftWon, "NftWon");
        vm.prank(SPONSOR);
        ppn.setPaused(true);
        vm.prank(ALICE);
        vm.expectRevert(); // prize transfer reverts -> whole redemption reverts
        r.redeemWinningTicket(1);
        r.settleWinningTicket(1); // anyone can settle without delivery
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        _eq(usdc.balanceOf(SPONSOR_RECIPIENT), 95_000_000, "sponsor paid 95% without delivering");
        vm.prank(SPONSOR);
        ppn.adminTransfer(address(r), SPONSOR, 1);
        require(ppn.ownerOf(1) == SPONSOR, "sponsor also took the NFT back");
        _eq(usdc.balanceOf(address(r)), 0, "buyers' 100 USDC fully distributed; winner received nothing");
    }

    /// S6-F3: escrow verification trusts the prize contract. A dishonest ERC-721 can activate a raffle with no
    /// token custody (onERC721Received is invoked with the expected tuple and ownerOf lies).
    function test_F3_dishonestPrize_activatesRaffle_without_custody() public {
        LyingPrizeNFT lie = new LyingPrizeNFT();
        lie.mint(SPONSOR, 7);
        vm.startPrank(SPONSOR);
        IRaffle r = IRaffle(
            factory.createRaffle(
                IRaffleFactory.CreateRaffleParams({
                    sponsorRecipient: SPONSOR_RECIPIENT,
                    prizeToken: address(lie),
                    prizeTokenId: 7,
                    reserveEntries: 1,
                    endTime: uint64(block.timestamp + 1 days)
                })
            )
        );
        vm.stopPrank();
        require(r.status() == IRaffle.Status.Active, "activated");
        require(lie.ownerOf(7) == address(r) && lie.realOwner(7) == SPONSOR, "no real custody");
    }

    /// S6-F4: init-time destination screening queries the registry only for addresses with code, so a sponsor can
    /// name the factory's NEXT clone address (predictable CREATE nonce) as sponsorRecipient. After that clone exists,
    /// releaseSponsorPrize moves the NFT into another raffle clone (stranded), contrary to DESIGN.md's "never move
    /// assets between raffle clones"; USDC proceeds to the same address are blocked by the runtime screen (stuck).
    function test_F4_futureCloneAsSponsorRecipient_movesPrizeIntoAnotherClone() public {
        address nextClone = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)) + 1);
        nft.mint(SPONSOR, 41);
        IRaffle r1 = _create(address(nft), 41, 1, 7 days, nextClone); // passes: nextClone has no code yet
        (IRaffle r2,) = _newRaffle(1);
        require(address(r2) == nextClone && factory.isRaffle(nextClone), "recipient is now a registered clone");
        vm.prank(SPONSOR);
        r1.enableRefunds(); // empty raffle, sponsor closes
        r1.releaseSponsorPrize(); // transferFrom into r2: no runtime screen on the NFT path
        require(nft.ownerOf(41) == address(r2), "prize stranded inside another raffle clone");
    }

    /// S6-F4 (USDC side): same misconfiguration makes sponsor proceeds permanently unclaimable.
    function test_F4b_futureCloneAsSponsorRecipient_usdcProceedsStuck() public {
        address nextClone = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)) + 1);
        nft.mint(SPONSOR, 42);
        IRaffle r1 = _create(address(nft), 42, 1, 7 days, nextClone);
        _newRaffle(1);
        _buy(r1, ALICE, 10);
        _drawAndResolve(r1, 0);
        vm.prank(ALICE);
        r1.redeemWinningTicket(1);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuoteDestination.selector, nextClone));
        r1.releaseSponsorProceeds();
        _eq(r1.sponsorProceeds(), 9_500_000, "sponsor proceeds stuck forever");
        r1.releaseProtocolFees(); // treasury claim remains independent
    }

    /// Bearer-claim liveness: a USDC-blocklisted winner can move the ticket to a clean address and redeem there,
    /// while a blocklisted immutable sponsorRecipient strands only its own claim.
    function test_blocklistedParties_liveness() public {
        (IRaffle r,) = _newRaffle(100);
        _buy(r, ALICE, 4);
        _drawAndResolve(r, 0); // CashWon (reserve not met), ALICE wins
        usdc.setBlocklisted(ALICE, true);
        vm.prank(ALICE);
        vm.expectRevert();
        r.redeemWinningTicket(1);
        vm.prank(ALICE);
        IERC721(address(r)).transferFrom(ALICE, CAROL, 1);
        vm.prank(CAROL);
        r.redeemWinningTicket(1);
        _eq(usdc.balanceOf(CAROL), 3_200_000, "cash via clean address");
        usdc.setBlocklisted(SPONSOR_RECIPIENT, true);
        vm.expectRevert();
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        _eq(usdc.balanceOf(TREASURY), 200_000, "treasury unaffected");
    }

    function test_factory_rejects_protocol_plumbing_and_bad_params() public {
        nft.mint(SPONSOR, 9);
        address impl = factory.raffleImplementation();
        address[5] memory badPrize = [address(usdc), address(wrapper), address(factory), impl, ALICE];
        for (uint256 i; i < badPrize.length; ++i) {
            vm.prank(SPONSOR);
            vm.expectRevert();
            factory.createRaffle(IRaffleFactory.CreateRaffleParams(SPONSOR_RECIPIENT, badPrize[i], 9, 1, uint64(block.timestamp + 1)));
        }
        address[4] memory badRecipient = [address(nft), address(factory), impl, address(usdc)];
        for (uint256 i; i < badRecipient.length; ++i) {
            vm.prank(SPONSOR);
            vm.expectRevert();
            factory.createRaffle(IRaffleFactory.CreateRaffleParams(badRecipient[i], address(nft), 9, 1, uint64(block.timestamp + 1)));
        }
        vm.startPrank(SPONSOR);
        nft.approve(address(factory), 9);
        vm.expectRevert(IRaffleFactory.ZeroReserveEntries.selector);
        factory.createRaffle(IRaffleFactory.CreateRaffleParams(SPONSOR_RECIPIENT, address(nft), 9, 0, uint64(block.timestamp + 1)));
        vm.expectRevert();
        factory.createRaffle(IRaffleFactory.CreateRaffleParams(SPONSOR_RECIPIENT, address(nft), 9, 1, uint64(block.timestamp)));
        vm.expectRevert();
        factory.createRaffle(IRaffleFactory.CreateRaffleParams(SPONSOR_RECIPIENT, address(nft), 9, 1, uint64(block.timestamp + 30 days + 1)));
        address r = factory.createRaffle(IRaffleFactory.CreateRaffleParams(SPONSOR_RECIPIENT, address(nft), 9, 1, uint64(block.timestamp + 30 days)));
        vm.stopPrank();
        nft.mint(SPONSOR, 10);
        vm.prank(SPONSOR);
        vm.expectRevert();
        factory.createRaffle(IRaffleFactory.CreateRaffleParams(r, address(nft), 10, 1, uint64(block.timestamp + 1)));
        nft.mint(ALICE, 11);
        vm.prank(ALICE);
        nft.approve(address(factory), 11);
        vm.prank(BOB); // cannot raffle someone else's approved NFT: transfer is always from msg.sender
        vm.expectRevert();
        factory.createRaffle(IRaffleFactory.CreateRaffleParams(SPONSOR_RECIPIENT, address(nft), 11, 1, uint64(block.timestamp + 1)));
    }
}

contract RaffleArithmeticFuzzTest is RaffleScenarioBase {
    /// AR-1/A-5 over the whole uint128 entry domain in one ticket: no overflow, exact 5/95 or 5/80/15 split, and
    /// complete payout leaves zero balance and zero liabilities.
    function testFuzz_settlementSplitExact_fullDomain(uint128 entries, bool reserveMet, uint256 word) public {
        vm.assume(entries > 0);
        nft.mint(SPONSOR, 5);
        IRaffle r = _create(address(nft), 5, reserveMet ? 1 : type(uint128).max, 7 days, SPONSOR_RECIPIENT);
        if (!reserveMet && entries == type(uint128).max) return; // reserve would be met exactly
        _buy(r, ALICE, entries);
        _drawAndResolve(r, word);
        uint256 gross = uint256(entries) * PRICE;
        vm.prank(ALICE);
        uint256 cash = r.redeemWinningTicket(1);
        uint256 fee = gross * 500 / 10_000;
        _eq(r.protocolFees(), fee, "fee");
        _eq(cash, reserveMet ? 0 : gross * 8000 / 10_000, "cash");
        _eq(r.sponsorProceeds(), gross - fee - cash, "sponsor");
        _eq(fee + cash + r.sponsorProceeds(), gross, "exact");
        _eq(fee * 20, gross, "5% exact for 1e6-unit entries");
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        _eq(usdc.balanceOf(address(r)), 0, "drained");
    }

    /// A-4/A-7: arbitrary ticket mixes are refunded at exactly 100% and the liability reaches zero.
    function testFuzz_refundConservation(uint8 n, uint64 seed) public {
        uint256 count = 1 + uint256(n) % 12;
        (IRaffle r,) = _newRaffle(1);
        address[3] memory who = [ALICE, BOB, CAROL];
        uint256 paid;
        for (uint256 i; i < count; ++i) {
            uint128 k = uint128(1 + uint256(keccak256(abi.encode(seed, i))) % 1_000_000);
            _buy(r, who[i % 3], k);
            paid += uint256(k) * PRICE;
        }
        vm.warp(r.drawRequestDeadline());
        r.enableRefunds();
        for (uint256 j; j < 3; ++j) {
            uint256 m;
            for (uint256 i = j; i < count; i += 3) m++;
            if (m == 0) continue;
            uint256[] memory ids = new uint256[](m);
            uint256 x;
            for (uint256 i = j; i < count; i += 3) ids[x++] = i + 1;
            vm.prank(who[j]);
            r.refundTickets(ids);
        }
        _eq(usdc.balanceOf(ALICE) + usdc.balanceOf(BOB) + usdc.balanceOf(CAROL), paid, "100% refunded");
        _eq(r.remainingRefundLiability(), 0, "liability zero");
        _eq(usdc.balanceOf(address(r)), 0, "drained");
    }
}
