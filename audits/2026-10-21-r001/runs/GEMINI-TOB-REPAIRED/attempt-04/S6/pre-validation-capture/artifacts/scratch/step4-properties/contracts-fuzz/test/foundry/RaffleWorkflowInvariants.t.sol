// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Raffle} from "../../src/Raffle.sol";
import {RaffleFactory} from "../../src/RaffleFactory.sol";
import {IRaffle} from "../../src/interfaces/IRaffle.sol";
import {IRaffleFactory} from "../../src/interfaces/IRaffleFactory.sol";
import {RaffleConstants} from "../../src/libraries/RaffleConstants.sol";
import {
    EchidnaMockUSDC,
    EchidnaMockPrizeNFT,
    EchidnaMockLink,
    EchidnaMockVRFWrapper,
    EchidnaActor,
    EchidnaRecipient,
    RaffleEchidnaTest
} from "../../src/echidna/RaffleEchidnaTest.sol";

interface Vm {
    function warp(uint256 newTimestamp) external;
    function deal(address who, uint256 newBalance) external;
    function prank(address msgSender) external;
    function expectRevert(bytes calldata revertData) external;
    function expectRevert(bytes4 revertSelector) external;
}

contract StatefulRaffleHandler is IERC721Receiver {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    RaffleEchidnaTest public immutable harness;

    constructor(RaffleEchidnaTest harness_) {
        harness = harness_;
    }

    function step_buy1(uint256 rawEntries) external {
        Raffle r = harness.openRaffle();
        if (r.status() != IRaffle.Status.Active || block.timestamp >= r.endTime()) return;
        harness.action_buyActor1(rawEntries);
    }

    function step_buy2(uint256 rawEntries) external {
        Raffle r = harness.openRaffle();
        if (r.status() != IRaffle.Status.Active || block.timestamp >= r.endTime()) return;
        harness.action_buyActor2(rawEntries);
    }

    function step_transfer(uint256 rawTicketId) external {
        Raffle r = harness.openRaffle();
        if (r.ticketCount() == 0) return;
        harness.action_transferTicket1To2(rawTicketId);
    }

    function step_warp(uint256 deltaSeed) external {
        uint256 delta = (deltaSeed % 3600) + 1;
        vm.warp(block.timestamp + delta);
    }

    function step_requestDraw() external {
        Raffle r = harness.openRaffle();
        if (r.status() != IRaffle.Status.Active) return;
        if (block.timestamp < r.endTime() || block.timestamp > r.drawRequestDeadline()) return;
        if (r.totalEntries() == 0) return;
        harness.action_requestDraw();
    }

    function step_fulfillDraw(uint256 randomWord) external {
        Raffle r = harness.openRaffle();
        if (r.status() != IRaffle.Status.Drawing) return;
        if (block.timestamp > r.callbackDeadline()) return;
        harness.action_fulfillDraw(randomWord);
    }

    function step_settleExact() external {
        harness.action_settleWinningTicketExact();
    }

    function step_redeemWinning() external {
        Raffle r = harness.openRaffle();
        if (r.winnerRedeemed()) return;
        harness.action_redeemWinningTicket();
    }

    function step_enableRefunds() external {
        Raffle r = harness.openRaffle();
        IRaffle.Status s = r.status();
        bool canRefund = (s == IRaffle.Status.Active &&
            ((block.timestamp >= r.endTime() && r.totalEntries() == 0) ||
                block.timestamp > r.drawRequestDeadline())) ||
            (s == IRaffle.Status.Drawing && block.timestamp > r.callbackDeadline());
        if (!canRefund) return;
        harness.action_enableRefunds();
    }

    function step_refundTicket(uint256 rawTicketId) external {
        Raffle r = harness.openRaffle();
        if (r.status() != IRaffle.Status.Refunding || r.remainingRefundLiability() == 0) return;
        uint256 count = r.ticketCount();
        if (count == 0) return;
        uint256 id = (rawTicketId % count) + 1;
        try r.ownerOf(id) returns (address) {
            harness.action_refundTicket(id - 1);
        } catch {}
    }

    function step_claimProceedsAndPrize() external {
        Raffle r = harness.openRaffle();
        if (r.sponsorProceeds() > 0) {
            harness.action_releaseSponsorProceeds();
        }
        if (r.protocolFees() > 0) {
            harness.action_releaseProtocolFees();
        }
        IRaffle.Status s = r.status();
        if (!r.prizeClaimed() && (s == IRaffle.Status.CashWon || s == IRaffle.Status.Refunding)) {
            harness.action_releaseSponsorPrize();
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract RaffleWorkflowInvariantsTest is IERC721Receiver {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    RaffleEchidnaTest public harness;
    StatefulRaffleHandler public handler;
    address[] private _targetedContracts;

    function setUp() public {
        vm.warp(1_700_000_000);
        harness = new RaffleEchidnaTest{value: 50 ether}();
        handler = new StatefulRaffleHandler(harness);
        _targetedContracts.push(address(handler));
    }

    function targetContracts() public view returns (address[] memory) {
        return _targetedContracts;
    }

    // --- Stateful Foundry Invariants ---

    function invariant_quoteSolvencyAndAccounting() public view {
        require(harness.echidna_quote_solvency(), "quote solvency violated");
        require(harness.echidna_entry_accounting(), "entry accounting violated");
        require(harness.echidna_settlement_conservation(), "settlement conservation violated");
        require(harness.echidna_refund_liability_conservation(), "refund liability conservation violated");
    }

    function invariant_ticketRangesAndStatusLifecycle() public view {
        require(harness.echidna_status_transitions_valid(), "status transition DAG violated");
        require(harness.echidna_ticket_ranges_contiguous(), "contiguous 1-indexed ticket ranges violated");
        require(harness.echidna_winning_ticket_bounds(), "winning ticket bounds violated");
        require(harness.echidna_prize_custody_consistency(), "prize custody consistency violated");
        require(harness.echidna_no_protocol_destination_holds_tickets(), "protocol destination held ticket");
        require(harness.echidna_factory_registry_bijection(), "factory registry bijection violated");
        require(harness.echidna_implementation_locked(), "implementation lock violated");
    }

    // --- Stateless Fuzz & Property Tests ---

    function testFuzz_nftWonSettlementAndClaims(
        uint128 rawEntries1,
        uint128 rawEntries2,
        uint256 randomWord
    ) public {
        uint128 entries1 = uint128((rawEntries1 % 200) + 2);
        uint128 entries2 = uint128((rawEntries2 % 200) + 2);
        Raffle r = harness.openRaffle(); // reserveEntries = 3, so entries1 + entries2 >= 4 >= 3 (NftWon)

        harness.actor1().buy(r, entries1, address(harness.actor1()));
        harness.actor2().buy(r, entries2, address(harness.actor2()));

        uint256 totalEntries = uint256(entries1) + uint256(entries2);
        uint256 gross = totalEntries * r.ENTRY_PRICE();
        require(r.grossSales() == gross && r.unsettledPot() == gross, "gross sales mismatch");

        vm.warp(r.endTime() + 1);
        harness.action_requestDraw();
        require(r.status() == IRaffle.Status.Drawing, "expected Drawing");

        harness.action_fulfillDraw(randomWord);
        require(r.status() == IRaffle.Status.NftWon, "expected NftWon");

        uint256 expectedWinningEntry = (randomWord % totalEntries) + 1;
        require(r.winningEntry() == expectedWinningEntry, "winningEntry formula mismatch");

        harness.action_settleWinningTicketExact();
        require(r.settlementComplete(), "settlement not completed");

        uint256 expectedFee = (gross * RaffleConstants.PROTOCOL_FEE_BPS) / RaffleConstants.BPS;
        uint256 expectedSponsor = gross - expectedFee;
        require(r.protocolFees() == expectedFee, "protocol fee mismatch");
        require(r.sponsorProceeds() == expectedSponsor, "sponsor proceeds mismatch");
        require(r.winnerProceeds() == 0, "winner cash proceeds must be 0 in NftWon");

        harness.action_redeemWinningTicket();
        harness.action_releaseSponsorProceeds();
        harness.action_releaseProtocolFees();

        require(r.prizeClaimed() && r.winnerRedeemed(), "winner redemption flags not set");
        require(r.accountedQuoteBalance() == 0, "accounted quote balance not zero after claims");
        require(harness.usdc().balanceOf(address(r)) == 0, "raffle USDC balance not zero after claims");
        require(
            harness.prizeNft().ownerOf(1) == r.winnerRecipient(),
            "prize NFT not delivered to winnerRecipient"
        );
    }

    function testFuzz_cashWonSettlementAndClaims(
        uint128 rawEntries1,
        uint128 rawEntries2,
        uint256 randomWord
    ) public {
        uint128 entries1 = uint128((rawEntries1 % 10) + 1);
        uint128 entries2 = uint128((rawEntries2 % 10) + 1);
        Raffle r = harness.highReserveRaffle(); // reserveEntries = 50, totalEntries <= 20 < 50 (CashWon)

        harness.actor1().buy(r, entries1, address(harness.actor1()));
        harness.actor2().buy(r, entries2, address(harness.actor2()));

        uint256 totalEntries = uint256(entries1) + uint256(entries2);
        uint256 gross = totalEntries * r.ENTRY_PRICE();

        vm.warp(r.endTime() + 1);
        uint256 fee = harness.vrfWrapper().currentNativePrice();
        r.requestDraw{value: fee}();
        harness.vrfWrapper().fulfill(address(r), r.vrfRequestId(), randomWord);
        require(r.status() == IRaffle.Status.CashWon, "expected CashWon");

        uint256 winEntry = r.winningEntry();
        uint256 winTicket = winEntry <= entries1 ? 1 : 2;
        if (winTicket == 1) {
            harness.actor1().redeem(r, 1);
        } else {
            harness.actor2().redeem(r, 2);
        }

        uint256 expectedFee = (gross * RaffleConstants.PROTOCOL_FEE_BPS) / RaffleConstants.BPS;
        uint256 expectedWinner = (gross * RaffleConstants.CASH_WINNER_BPS) / RaffleConstants.BPS;
        uint256 expectedSponsor = gross - expectedFee - expectedWinner;

        require(r.protocolFees() == expectedFee, "protocol fee mismatch in CashWon");
        require(r.sponsorProceeds() == expectedSponsor, "sponsor proceeds mismatch in CashWon");
        require(r.winnerProceeds() == 0 && r.winnerRedeemed(), "winner cash not paid on redeem");

        r.releaseSponsorProceeds();
        r.releaseProtocolFees();
        r.releaseSponsorPrize();

        require(r.prizeClaimed(), "sponsor prize not marked claimed");
        require(harness.prizeNft().ownerOf(2) == address(harness.sponsorRecipient()), "sponsor did not receive prize back");
        require(r.accountedQuoteBalance() == 0 && harness.usdc().balanceOf(address(r)) == 0, "residual USDC after CashWon");
    }

    function testFuzz_refundPathsAndSponsorPrizeReclaim(uint128 rawEntries1, uint128 rawEntries2, bool callbackTimeout) public {
        uint128 entries1 = uint128((rawEntries1 % 25) + 1);
        uint128 entries2 = uint128((rawEntries2 % 25) + 1);
        Raffle r = harness.openRaffle();

        harness.actor1().buy(r, entries1, address(harness.actor1()));
        harness.actor2().buy(r, entries2, address(harness.actor2()));

        if (callbackTimeout) {
            vm.warp(r.endTime() + 1);
            harness.action_requestDraw();
            vm.warp(r.callbackDeadline() + 1);
        } else {
            vm.warp(r.drawRequestDeadline() + 1);
        }

        r.enableRefunds();
        require(r.status() == IRaffle.Status.Refunding, "expected Refunding");
        require(r.remainingRefundLiability() == r.grossSales(), "refund liability != grossSales");

        uint256[] memory t1 = new uint256[](1);
        t1[0] = 1;
        uint256[] memory t2 = new uint256[](1);
        t2[0] = 2;
        harness.actor1().refund(r, t1);
        harness.actor2().refund(r, t2);
        r.releaseSponsorPrize();

        require(r.remainingRefundLiability() == 0, "refund liability not zeroed");
        require(r.accountedQuoteBalance() == 0 && harness.usdc().balanceOf(address(r)) == 0, "residual USDC after refund");
        require(harness.prizeNft().ownerOf(1) == address(harness.sponsorRecipient()), "prize not returned on refund");
    }

    function test_protocolDestinationGuardsAndCallbackIgnore() public {
        Raffle r = harness.openRaffle();
        address act1 = address(harness.actor1());
        address fac = address(harness.factory());
        // Attempting to buy entries to a protocol destination (factory, raffle clone, quoteToken, vrfWrapper, prizeToken) must revert
        vm.prank(act1);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, fac));
        r.buyEntries(fac, 1);

        vm.prank(act1);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(r)));
        r.buyEntries(address(r), 1);

        // Unsolicited VRF callback while Active (not Drawing) must be ignored without reverting or mutating status
        harness.vrfWrapper().fulfill(address(r), 999, 42);
        require(r.status() == IRaffle.Status.Active, "unsolicited callback mutated status");
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
