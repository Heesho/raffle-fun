// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Base } from "./Base.sol";
import { RaffleFactory } from "raffle/RaffleFactory.sol";
import { Raffle } from "raffle/Raffle.sol";
import { IRaffle } from "raffle/interfaces/IRaffle.sol";
import { IRaffleFactory } from "raffle/interfaces/IRaffleFactory.sol";
import { StickyApprovalNFT } from "../src/Mocks.sol";

/// Proof sketches for the SUP-REPORT findings / risks. Each test PASSES when the described behaviour occurs.
contract FindingsTest is Base {
    // SUP-01: creation-time screens only; sponsorRecipient may later become a registered clone.
    // releaseSponsorPrize has no destination screen -> prize moves INTO another clone (DESIGN: never move
    // assets between clones). releaseSponsorProceeds IS screened -> sponsor USDC becomes permanently unclaimable.
    function test_SUP01_counterfactualCloneRecipient() public {
        uint64 nonce = vm.getNonce(address(factory));
        address predictedA = _computeCreateAddress(address(factory), nonce);
        address predictedB = _computeCreateAddress(address(factory), nonce + 1);
        require(predictedB.code.length == 0, "B not deployed yet");

        // Sponsor of A sets sponsorRecipient to the next-next factory CREATE address. All screens pass.
        Raffle a = _createFor(sponsor, predictedB, 11, 100, uint64(T0 + 1 days));
        require(address(a) == predictedA, "A address");

        // Any later createRaffle (here by an unrelated sponsor) deploys clone B at that address.
        Raffle b = _createFor(alice, alice, 12, 1, uint64(T0 + 1 days));
        require(address(b) == predictedB && factory.isRaffle(predictedB), "B registered at A.sponsorRecipient");

        // A: one buyer, reserve missed -> CashWon, settle.
        _buy(a, bob, 10);
        vm.warp(T0 + 1 days);
        _request(a);
        require(_fulfill(a, 3), "cb");
        _eq(_st(a), uint8(IRaffle.Status.CashWon), "cash won");
        a.settleWinningTicket(1);
        _eq(a.sponsorProceeds(), 1_500_000, "15% allocated");

        // Sponsor USDC: permanently blocked (recipient is immutable, screen now true forever).
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuoteDestination.selector, predictedB));
        a.releaseSponsorProceeds();

        // Prize NFT: NOT screened -> delivered into clone B.
        a.releaseSponsorPrize();
        require(nft.ownerOf(11) == address(b), "prize of A now held by clone B");
        // B can never move token 11 (it only ever transfers its own prizeTokenId 12); no rescue path exists.
        _eq(b.prizeTokenId(), 12, "B prize id");
        // B's own accounting is untouched (isolation of B's liabilities holds; asset is simply stranded).
        _eq(usdc.balanceOf(address(b)), b.accountedQuoteBalance(), "B solvent");
        // Other A participants unaffected: winner and treasury exit normally.
        vm.prank(bob);
        _eq(a.redeemWinningTicket(1), 8_000_000, "winner 80%");
        _eq(a.releaseProtocolFees(), 500_000, "treasury 5%");
        _eq(usdc.balanceOf(address(a)), 1_500_000, "only sponsor share stranded in A");
    }

    // SUP-01b: the same counterfactual trap applies to ticket holders (self-inflicted): a ticket minted to a
    // future clone address is owned by that clone forever; if it wins, the prize/cash is stranded.
    function test_SUP01b_ticketToFutureClone() public {
        Raffle a = _create(21, 1, uint64(T0 + 1 days));
        address predicted = _computeCreateAddress(address(factory), vm.getNonce(address(factory)));
        usdc.mint(bob, 5 * E);
        vm.prank(bob);
        usdc.approve(address(a), type(uint256).max);
        vm.prank(bob);
        a.buyEntries(predicted, 5); // no code yet -> screen passes
        Raffle c = _createFor(alice, alice, 22, 1, uint64(T0 + 1 days));
        require(address(c) == predicted && a.ownerOf(1) == address(c), "clone owns ticket");
        vm.warp(T0 + 1 days);
        _request(a);
        require(_fulfill(a, 0), "cb");
        _eq(_st(a), uint8(IRaffle.Status.NftWon), "nft won");
        a.settleWinningTicket(1); // sponsor/treasury exits still work
        require(a.sponsorProceeds() == 4_750_000 && a.protocolFees() == 250_000, "allocs");
        // the winner (clone c) has no code path to call redeemWinningTicket: prize stranded in A forever.
    }

    // SUP-02: deployment misconfiguration - treasury == first clone address permanently bricks createRaffle.
    function test_SUP02_treasuryEqualsFutureClone_bricksFactory() public {
        address futureFactory = _computeCreateAddress(address(this), vm.getNonce(address(this)));
        address firstClone = _computeCreateAddress(futureFactory, 2); // nonce 1 = implementation
        RaffleFactory f = new RaffleFactory(address(usdc), address(wrapper), firstClone);
        require(address(f) == futureFactory, "factory address");
        nft.mint(sponsor, 31);
        vm.prank(sponsor);
        nft.setApprovalForAll(address(f), true);
        for (uint256 i; i < 3; ++i) {
            vm.prank(sponsor);
            vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, firstClone));
            f.createRaffle(_params(recipient, address(nft), 31, 1, uint64(T0 + 1 days)));
        }
        _eq(f.raffleCount(), 0, "nonce never advances: every attempt targets the same clone address");
    }

    // SUP-03 (integration / trust boundary): escrow verification is ownerOf-only. A prize whose approvals survive
    // transfer (non-compliant ERC-721) lets the sponsor's accomplice pull the prize out of an Active raffle.
    // Buyers still pay; reserve met -> NftWon; sponsor collects 95%; winner's redemption reverts forever.
    function test_SUP03_nonCompliantPrize_escapesEscrow() public {
        StickyApprovalNFT p = new StickyApprovalNFT();
        address accomplice = vm.addr(0xBAD);
        p.mint(sponsor, 5);
        vm.prank(sponsor);
        p.approve(accomplice, 5);
        vm.prank(sponsor);
        p.setApprovalForAll(address(factory), true);
        vm.prank(sponsor);
        Raffle r = Raffle(payable(factory.createRaffle(_params(recipient, address(p), 5, 3, uint64(T0 + 1 days)))));
        require(p.ownerOf(5) == address(r) && p.getApproved(5) == accomplice, "escrowed, approval retained");

        vm.prank(accomplice);
        p.transferFrom(address(r), accomplice, 5); // prize leaves escrow while Active
        _buy(r, alice, 10);
        vm.warp(T0 + 1 days);
        _request(r);
        require(_fulfill(r, 1), "cb");
        _eq(_st(r), uint8(IRaffle.Status.NftWon), "nft won");
        vm.prank(alice);
        vm.expectRevert(bytes("wrong from"));
        r.redeemWinningTicket(1);
        r.settleWinningTicket(1);
        _eq(r.releaseSponsorProceeds(), 9_500_000, "sponsor paid 95% for an absent prize");
        // No fallback exists: NftWon is terminal; refunds are unreachable.
    }
}
