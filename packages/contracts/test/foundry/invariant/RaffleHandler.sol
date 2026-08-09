// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";

import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockEntropyV2 } from "../../../src/mocks/MockEntropyV2.sol";

contract RaffleHandler is Test, IERC721Receiver {
    uint256 internal constant MAX_HANDLER_TICKETS = 500;

    MockERC20 public immutable quote;
    MockEntropyV2 public immutable entropy;
    address public immutable treasury;
    address public immutable recipientOne;
    address public immutable recipientTwo;
    address public immutable recipientThree;

    Raffle public raffle;
    bool public configured;

    uint256 public ghostGrossPaid;
    uint256 public ghostQuoteClaimed;
    uint256 public ghostRequestCount;
    uint256 public ghostResolutionCount;
    uint256 public ghostFailureCount;
    uint256 public ghostRefundCredited;
    uint256 public ghostPrizeClaims;
    bool public stateWentBackward;
    IRaffle.RaffleState public lastObservedState;
    address public resolvedWinner;
    IRaffle.RaffleOutcome public resolvedOutcome;

    constructor(
        MockERC20 quote_,
        MockEntropyV2 entropy_,
        address treasury_,
        address recipientOne_,
        address recipientTwo_,
        address recipientThree_
    ) {
        quote = quote_;
        entropy = entropy_;
        treasury = treasury_;
        recipientOne = recipientOne_;
        recipientTwo = recipientTwo_;
        recipientThree = recipientThree_;
    }

    function configure(Raffle raffle_) external {
        require(!configured, "configured");
        configured = true;
        raffle = raffle_;
        quote.approve(address(raffle_), type(uint256).max);
        lastObservedState = raffle_.state();
    }

    function buy(uint256 quantitySeed) external {
        if (!raffle.isOpen()) return;
        uint256 sold = raffle.totalTickets();
        if (sold >= MAX_HANDLER_TICKETS) return;
        uint256 remaining = MAX_HANDLER_TICKETS - sold;
        uint256 quantity = bound(quantitySeed, 1, remaining < 10 ? remaining : 10);
        uint256 grossBefore = raffle.grossSales();
        try raffle.buyTickets(address(this), quantity) {
            ghostGrossPaid += raffle.grossSales() - grossBefore;
        } catch { }
        _observe();
    }

    function transferTicket(uint256 ticketSeed, uint256 recipientSeed) external {
        uint256 sold = raffle.totalTickets();
        if (sold == 0 || raffle.state() == IRaffle.RaffleState.DrawRequested) return;
        uint256 ticketId = bound(ticketSeed, 1, sold);
        try raffle.ownerOf(ticketId) returns (address owner) {
            if (owner != address(this)) return;
            address to = _recipient(recipientSeed);
            try raffle.transferFrom(address(this), to, ticketId) { } catch { }
        } catch { }
        _observe();
    }

    function warpToEnd() external {
        if (block.timestamp < raffle.endTime()) vm.warp(raffle.endTime());
        _observe();
    }

    function warpToRequestGraceDeadline() external {
        if (block.timestamp < raffle.requestGraceDeadline()) vm.warp(raffle.requestGraceDeadline());
        _observe();
    }

    function warpToCallbackDeadline() external {
        uint256 deadline = raffle.callbackDeadline();
        if (deadline != 0 && block.timestamp < deadline) vm.warp(deadline);
        _observe();
    }

    function requestDraw() external {
        if (!raffle.canRequestDraw()) return;
        uint256 fee = raffle.getEntropyFee();
        vm.deal(address(this), address(this).balance + fee);
        try raffle.requestDraw{ value: fee }() {
            ++ghostRequestCount;
        } catch { }
        _observe();
    }

    function fulfill(bytes32 randomNumber) external {
        if (raffle.state() != IRaffle.RaffleState.DrawRequested) return;
        uint64 sequence = raffle.entropySequenceNumber();
        IRaffle.RaffleState beforeState = raffle.state();
        try entropy.fulfill(sequence, randomNumber) {
            if (beforeState == IRaffle.RaffleState.DrawRequested && raffle.state() == IRaffle.RaffleState.Resolved) {
                ++ghostResolutionCount;
                resolvedWinner = raffle.winner();
                resolvedOutcome = raffle.outcome();
            }
        } catch { }
        _observe();
    }

    function wrongSequence(bytes32 randomNumber) external {
        if (raffle.state() != IRaffle.RaffleState.DrawRequested) return;
        uint64 sequence = raffle.entropySequenceNumber();
        try entropy.fulfillAs(sequence, sequence + 1, randomNumber) { } catch { }
        _observe();
    }

    function duplicateCallback(bytes32 randomNumber) external {
        if (raffle.entropySequenceNumber() == 0) return;
        try entropy.fulfill(raffle.entropySequenceNumber(), randomNumber) { } catch { }
        _observe();
    }

    function finalizeUnrequestedDraw() external {
        if (!raffle.canFinalizeUnrequestedDraw()) return;
        try raffle.finalizeUnrequestedDraw() {
            ++ghostFailureCount;
        } catch { }
        _observe();
    }

    function finalizeTimedOutDraw() external {
        if (!raffle.canFinalizeTimedOutDraw()) return;
        try raffle.finalizeTimedOutDraw() {
            ++ghostFailureCount;
        } catch { }
        _observe();
    }

    function creditRefund(uint256 ticketSeed) external {
        uint256 sold = raffle.totalTickets();
        if (raffle.state() != IRaffle.RaffleState.Refunding || sold == 0) return;
        uint256 ticketId = bound(ticketSeed, 1, sold);
        if (raffle.isTicketRefundCredited(ticketId)) return;
        uint256[] memory ticketIds = new uint256[](1);
        ticketIds[0] = ticketId;
        try raffle.creditTicketRefunds(ticketIds) {
            ghostRefundCredited += raffle.ticketPrice();
        } catch { }
        _observe();
    }

    function claimQuote(uint256 accountSeed) external {
        address account = _claimAccount(accountSeed);
        uint256 accrued = raffle.claimableQuote(account);
        if (accrued == 0) return;
        try raffle.claimQuoteFor(account) returns (uint256 amount) {
            ghostQuoteClaimed += amount;
        } catch { }
        _observe();
    }

    function claimPrize() external {
        if (raffle.prizeClaimant() != address(this) || raffle.prizeClaimed()) return;
        bool beforeClaimed = raffle.prizeClaimed();
        try raffle.claimPrize(recipientOne) {
            if (!beforeClaimed && raffle.prizeClaimed()) ++ghostPrizeClaims;
        } catch { }
        _observe();
    }

    function cancelBeforeSales() external {
        if (raffle.state() != IRaffle.RaffleState.Active || raffle.totalTickets() != 0) return;
        try raffle.cancelBeforeSales() { } catch { }
        _observe();
    }

    function closeNoSales() external {
        if (
            raffle.state() != IRaffle.RaffleState.Active || raffle.totalTickets() != 0
                || block.timestamp < raffle.endTime()
        ) return;
        try raffle.closeNoSales() { } catch { }
        _observe();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _observe() internal {
        IRaffle.RaffleState current = raffle.state();
        if (uint256(current) < uint256(lastObservedState)) stateWentBackward = true;
        if (uint256(current) > uint256(lastObservedState)) lastObservedState = current;
    }

    function _recipient(uint256 seed) internal view returns (address) {
        uint256 index = seed % 3;
        if (index == 0) return recipientOne;
        if (index == 1) return recipientTwo;
        return recipientThree;
    }

    function _claimAccount(uint256 seed) internal view returns (address) {
        uint256 index = seed % 5;
        if (index == 0) return address(this);
        if (index == 1) return treasury;
        if (index == 2) return recipientOne;
        if (index == 3) return recipientTwo;
        return recipientThree;
    }
}
