// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Test} from "forge-std/Test.sol";

import {Raffle} from "../../../src/Raffle.sol";
import {IRaffle} from "../../../src/interfaces/IRaffle.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {MockEntropyV2} from "../../../src/mocks/MockEntropyV2.sol";

contract RaffleHandler is Test, IERC721Receiver {
    uint256 internal constant MAX_HANDLER_TICKETS = 100;

    MockERC20 public immutable quote;
    MockEntropyV2 public immutable entropy;
    address public immutable treasury;

    Raffle public raffle;
    bool public configured;
    uint256 public ghostGrossPaid;
    uint256 public ghostQuotePaidOut;
    uint256 public ghostProtocolPaidOut;
    uint256 public ghostRequestCount;
    uint256 public ghostResolutionCount;
    uint256 public ghostRefundEnableCount;
    uint256 public ghostWinningTicketRedemptions;
    uint256 public ghostRefundTicketRedemptions;
    uint256 public ghostSponsorPrizeClaims;
    bool public statusWentBackward;
    IRaffle.Status public lastObservedStatus;

    constructor(MockERC20 quote_, MockEntropyV2 entropy_, address treasury_) {
        quote = quote_;
        entropy = entropy_;
        treasury = treasury_;
    }

    function configure(Raffle raffle_) external {
        require(!configured, "configured");
        configured = true;
        raffle = raffle_;
        quote.approve(address(raffle_), type(uint256).max);
        lastObservedStatus = raffle_.status();
    }

    function buy(uint256 quantitySeed) external {
        if (!_isOpen()) return;
        uint256 sold = raffle.totalTickets();
        if (sold >= MAX_HANDLER_TICKETS) return;
        uint256 remaining = MAX_HANDLER_TICKETS - sold;
        uint256 quantity = bound(quantitySeed, 1, remaining < 10 ? remaining : 10);
        uint256 grossBefore = raffle.grossSales();
        try raffle.buyTickets(address(this), quantity) {
            ghostGrossPaid += raffle.grossSales() - grossBefore;
        } catch {}
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

    function warpToNftRedemptionDeadline() external {
        uint256 deadline = raffle.nftRedemptionDeadline();
        if (deadline != 0 && block.timestamp < deadline) vm.warp(deadline);
        _observe();
    }

    function requestDraw() external {
        if (!_canRequestDraw()) return;
        uint256 fee = raffle.getEntropyFee();
        vm.deal(address(this), address(this).balance + fee);
        try raffle.requestDraw{value: fee}() {
            ++ghostRequestCount;
        } catch {}
        _observe();
    }

    function fulfill(bytes32 randomNumber) external {
        if (raffle.status() != IRaffle.Status.Drawing) return;
        try entropy.fulfill(raffle.entropySequenceNumber(), randomNumber) {
            IRaffle.Status current = raffle.status();
            if (current == IRaffle.Status.NftWon || current == IRaffle.Status.CashWon) ++ghostResolutionCount;
        } catch {}
        _observe();
    }

    function wrongSequence(bytes32 randomNumber) external {
        if (raffle.status() != IRaffle.Status.Drawing) return;
        uint64 sequence = raffle.entropySequenceNumber();
        try entropy.fulfillAs(sequence, sequence + 1, randomNumber) {} catch {}
        _observe();
    }

    function enableRefunds() external {
        if (!_canEnableRefunds()) return;
        try raffle.enableRefunds() {
            ++ghostRefundEnableCount;
        } catch {}
        _observe();
    }

    function redeemRefundTicket(uint256 ticketSeed) external {
        if (raffle.status() != IRaffle.Status.Refunding || raffle.totalTickets() == 0) return;
        uint256 ticketId = bound(ticketSeed, 1, raffle.totalTickets());
        try raffle.ownerOf(ticketId) returns (address owner) {
            if (owner != address(this)) return;
            uint256[] memory ids = new uint256[](1);
            ids[0] = ticketId;
            try raffle.redeemRefundTickets(ids, address(this)) returns (uint256 amount) {
                ghostQuotePaidOut += amount;
                ++ghostRefundTicketRedemptions;
            } catch {}
        } catch {}
        _observe();
    }

    function redeemWinningTicket() external {
        IRaffle.Status current = raffle.status();
        if (current != IRaffle.Status.NftWon && current != IRaffle.Status.CashWon) return;
        uint256 ticketId = raffle.winningTicketId();
        try raffle.ownerOf(ticketId) returns (address owner) {
            if (owner != address(this)) return;
            try raffle.redeemWinningTicket(address(this)) returns (uint256 cashAmount) {
                ghostQuotePaidOut += cashAmount;
                ++ghostWinningTicketRedemptions;
            } catch {}
        } catch {}
        _observe();
    }

    function claimQuote(bool protocolClaim) external {
        address account = protocolClaim ? treasury : address(this);
        uint256 amount = raffle.claimableQuote(account);
        if (amount == 0) return;
        try raffle.claimQuoteFor(account) returns (uint256 paid) {
            ghostQuotePaidOut += paid;
            if (protocolClaim) ghostProtocolPaidOut += paid;
        } catch {}
        _observe();
    }

    function claimSponsorPrize() external {
        IRaffle.Status current = raffle.status();
        if (
            raffle.prizeClaimed()
                || (current != IRaffle.Status.CashWon
                    && current != IRaffle.Status.Refunding
                    && current != IRaffle.Status.Closed)
        ) return;
        try raffle.claimSponsorPrize(address(this)) {
            ++ghostSponsorPrizeClaims;
        } catch {}
        _observe();
    }

    function closeEmptyRaffle() external {
        if (raffle.status() != IRaffle.Status.Active || raffle.totalTickets() != 0) return;
        try raffle.closeEmptyRaffle() {} catch {}
        _observe();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _observe() internal {
        IRaffle.Status current = raffle.status();
        if (uint256(current) < uint256(lastObservedStatus)) statusWentBackward = true;
        if (uint256(current) > uint256(lastObservedStatus)) lastObservedStatus = current;
    }

    function _isOpen() internal view returns (bool) {
        return raffle.status() == IRaffle.Status.Active && block.timestamp >= raffle.startTime()
            && block.timestamp < raffle.endTime();
    }

    function _canRequestDraw() internal view returns (bool) {
        return raffle.status() == IRaffle.Status.Active && block.timestamp >= raffle.endTime()
            && block.timestamp < raffle.requestGraceDeadline() && raffle.totalTickets() != 0;
    }

    function _canEnableRefunds() internal view returns (bool) {
        IRaffle.Status current = raffle.status();
        return (current == IRaffle.Status.Active
                && raffle.totalTickets() != 0
                && block.timestamp >= raffle.requestGraceDeadline())
            || (current == IRaffle.Status.Drawing && block.timestamp >= raffle.callbackDeadline())
            || (current == IRaffle.Status.NftWon
                && !raffle.prizeClaimed()
                && block.timestamp >= raffle.nftRedemptionDeadline());
    }
}
