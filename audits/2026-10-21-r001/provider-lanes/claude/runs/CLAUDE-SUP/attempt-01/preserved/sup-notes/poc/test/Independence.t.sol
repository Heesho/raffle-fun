// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Base } from "./Base.sol";
import { Raffle } from "raffle/Raffle.sol";
import { IRaffle } from "raffle/interfaces/IRaffle.sol";

/// Claim independence under per-recipient delivery failure (USDC blacklist on one party).
contract IndependenceTest is Base {
    function test_blacklistedSponsorRecipient_doesNotBlockOthers() public {
        Raffle r = _create(1, 100, uint64(T0 + 1 days));
        _buy(r, alice, 10);
        vm.warp(T0 + 1 days);
        _request(r);
        require(_fulfill(r, 2), "cb");
        _eq(_st(r), uint8(IRaffle.Status.CashWon), "cash");
        usdc.setBlacklisted(recipient, true);
        r.settleWinningTicket(1);
        vm.expectRevert(bytes("blacklisted"));
        r.releaseSponsorProceeds();
        _eq(r.releaseProtocolFees(), 500_000, "treasury independent");
        vm.prank(alice);
        _eq(r.redeemWinningTicket(1), 8_000_000, "winner independent");
        r.releaseSponsorPrize(); // NFT leg unaffected by USDC blacklist
        _eq(r.sponsorProceeds(), 1_500_000, "sponsor claim preserved for later");
        usdc.setBlacklisted(recipient, false);
        _eq(r.releaseSponsorProceeds(), 1_500_000, "claimable once unblocked");
    }

    function test_blacklistedHolder_canMoveTicketAndRefund() public {
        Raffle r = _create(1, 100, uint64(T0 + 1 days));
        _buy(r, alice, 4);
        _buy(r, bob, 1);
        vm.warp(T0 + 3 days);
        r.enableRefunds();
        usdc.setBlacklisted(alice, true);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        vm.prank(alice);
        vm.expectRevert(bytes("blacklisted"));
        r.refundTickets(ids);
        vm.prank(alice);
        r.transferFrom(alice, carol, 1);
        vm.prank(carol);
        _eq(r.refundTickets(ids), 4 * E, "refund via new holder");
        ids[0] = 2;
        vm.prank(bob);
        _eq(r.refundTickets(ids), E, "bob unaffected");
    }
}
