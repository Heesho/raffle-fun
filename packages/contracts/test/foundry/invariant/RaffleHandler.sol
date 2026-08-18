// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { Test } from "forge-std/Test.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockVRFV2PlusWrapper } from "../../../src/mocks/MockVRFV2PlusWrapper.sol";

contract RaffleHandler is Test, IERC721Receiver {
    uint128 internal constant MAX_HANDLER_ENTRIES = 100;

    MockERC20 public immutable quote;
    MockVRFV2PlusWrapper public immutable vrfWrapper;
    address public immutable treasury;
    address public immutable alternateOwner = address(0xA11CE);

    Raffle public raffle;
    uint256[] public receiptIds;
    uint256 public ghostGrossPaid;
    uint256 public ghostQuotePaidOut;
    uint256 public ghostRefundPaidOut;
    uint256 public ghostProtocolPaidOut;
    uint256 public ghostSponsorPaidOut;
    uint256 public ghostWinnerPaidOut;
    uint256 public ghostDonations;
    uint256 public ghostRequestCount;
    uint256 public ghostResolutionCount;
    uint256 public ghostRefundEnableCount;
    uint256 public ghostWinnerRedemptions;
    bool public ghostCashResolved;
    bool public statusWentBackward;
    IRaffle.Status public highestStatus;

    constructor(MockERC20 quote_, MockVRFV2PlusWrapper vrfWrapper_, address treasury_) {
        quote = quote_;
        vrfWrapper = vrfWrapper_;
        treasury = treasury_;
    }

    function configure(Raffle raffle_) external {
        require(address(raffle) == address(0), "configured");
        raffle = raffle_;
        quote.approve(address(raffle_), type(uint256).max);
        vm.prank(alternateOwner);
        quote.approve(address(raffle_), type(uint256).max);
        highestStatus = raffle_.status();
    }

    function receiptIdAt(uint256 index) external view returns (uint256) {
        return receiptIds[index];
    }

    function receiptIdsLength() external view returns (uint256) {
        return receiptIds.length;
    }

    function buy(uint128 quantitySeed) external {
        if (raffle.status() != IRaffle.Status.Active || block.timestamp >= raffle.endTime()) return;
        uint128 sold = raffle.totalEntries();
        if (sold >= MAX_HANDLER_ENTRIES) return;
        uint128 remaining = MAX_HANDLER_ENTRIES - sold;
        uint128 quantity = uint128(bound(uint256(quantitySeed), 1, remaining < 10 ? remaining : 10));
        uint256 grossBefore = raffle.grossSales();
        try raffle.buyEntries(address(this), quantity) returns (uint256 receiptId) {
            receiptIds.push(receiptId);
            ghostGrossPaid += raffle.grossSales() - grossBefore;
        } catch { }
        _observe();
    }

    function transferBeforeOrAfterEnd(uint256 receiptSeed) external {
        if (receiptIds.length == 0) return;
        uint256 receiptId = receiptIds[receiptSeed % receiptIds.length];
        try raffle.ownerOf(receiptId) returns (address owner) {
            address to = owner == address(this) ? alternateOwner : address(this);
            vm.prank(owner);
            try raffle.transferFrom(owner, to, receiptId) { } catch { }
        } catch { }
        _observe();
    }

    function warpToEnd() external {
        if (block.timestamp < raffle.endTime()) vm.warp(raffle.endTime());
        _observe();
    }

    function warpToCallbackDeadline() external {
        uint256 deadline = raffle.callbackDeadline();
        if (deadline != 0 && block.timestamp < deadline) vm.warp(deadline);
        _observe();
    }

    function warpFarPastEnd() external {
        uint256 farFuture = uint256(raffle.endTime()) + 365 days;
        if (block.timestamp < farFuture) vm.warp(farFuture);
        _observe();
    }

    function requestDraw() external {
        if (
            raffle.status() != IRaffle.Status.Active || raffle.totalEntries() == 0 || block.timestamp < raffle.endTime()
        ) {
            return;
        }
        uint256 fee = raffle.getVrfRequestPrice();
        vm.deal(address(this), address(this).balance + fee);
        try raffle.requestDraw{ value: fee }() {
            ++ghostRequestCount;
        } catch { }
        _observe();
    }

    function fulfill(uint256 randomWord) external {
        if (raffle.status() != IRaffle.Status.Drawing) return;
        try vrfWrapper.fulfill(raffle.vrfRequestId(), randomWord) {
            ++ghostResolutionCount;
            if (raffle.status() == IRaffle.Status.CashWon) ghostCashResolved = true;
        } catch { }
        _observe();
    }

    function wrongCallback(uint256 randomWord) external {
        if (raffle.status() != IRaffle.Status.Drawing) return;
        try vrfWrapper.fulfillAs(raffle.vrfRequestId(), raffle.vrfRequestId() + 1, randomWord) { } catch { }
        _observe();
    }

    function enableRefunds() external {
        IRaffle.Status current = raffle.status();
        bool ready = current == IRaffle.Status.Active && raffle.totalEntries() == 0;
        ready = ready || (current == IRaffle.Status.Drawing && block.timestamp >= raffle.callbackDeadline());
        if (!ready) return;
        try raffle.enableRefunds() {
            ++ghostRefundEnableCount;
        } catch { }
        _observe();
    }

    function settleCandidateWinner(uint256 receiptSeed) external {
        IRaffle.Status current = raffle.status();
        if ((current != IRaffle.Status.NftWon && current != IRaffle.Status.CashWon) || receiptIds.length == 0) return;
        uint256 receiptId = receiptIds[receiptSeed % receiptIds.length];
        address owner;
        try raffle.ownerOf(receiptId) returns (address owner_) {
            owner = owner_;
        } catch {
            return;
        }
        try raffle.settleWinningTicket(receiptId) returns (uint256 amount) {
            ghostQuotePaidOut += amount;
            ghostWinnerPaidOut += amount;
            ++ghostWinnerRedemptions;
        } catch { }
        _observe();
    }

    function redeemRefund(uint256 receiptSeed) external {
        if (raffle.status() != IRaffle.Status.Refunding || receiptIds.length == 0) return;
        uint256 receiptId = receiptIds[receiptSeed % receiptIds.length];
        address owner;
        try raffle.ownerOf(receiptId) returns (address owner_) {
            owner = owner_;
        } catch {
            return;
        }
        uint256[] memory ids = new uint256[](1);
        ids[0] = receiptId;
        vm.prank(owner);
        try raffle.refundTickets(ids) returns (uint256 amount) {
            ghostQuotePaidOut += amount;
            ghostRefundPaidOut += amount;
        } catch { }
        _observe();
    }

    function releaseProceeds(bool protocolClaim) external {
        uint256 expected = protocolClaim ? raffle.protocolFees() : raffle.sponsorProceeds();
        if (expected == 0) return;
        if (protocolClaim) {
            try raffle.releaseProtocolFees() returns (uint256 amount) {
                ghostQuotePaidOut += amount;
                ghostProtocolPaidOut += amount;
            } catch { }
        } else {
            try raffle.releaseSponsorProceeds() returns (uint256 amount) {
                ghostQuotePaidOut += amount;
                ghostSponsorPaidOut += amount;
            } catch { }
        }
        _observe();
    }

    function releaseSponsorPrize() external {
        IRaffle.Status current = raffle.status();
        if (raffle.prizeClaimed() || (current != IRaffle.Status.CashWon && current != IRaffle.Status.Refunding)) {
            return;
        }
        try raffle.releaseSponsorPrize() { } catch { }
        _observe();
    }

    function donate(uint64 amountSeed) external {
        uint256 amount = bound(uint256(amountSeed), 1, 10 * 1e6);
        quote.mint(address(raffle), amount);
        ghostDonations += amount;
        _observe();
    }

    function _observe() internal {
        IRaffle.Status current = raffle.status();
        if (uint256(current) < uint256(highestStatus)) statusWentBackward = true;
        if (uint256(current) > uint256(highestStatus)) highestStatus = current;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
