// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";
import { MockEntropyV2 } from "../../../src/mocks/MockEntropyV2.sol";

contract MultiActorRaffleHandler is Test {
    MockERC20 public immutable quote;
    MockERC721 public immutable prize;
    MockEntropyV2 public immutable entropy;
    RaffleFactory public immutable factory;
    Raffle public immutable raffle;

    address public immutable sponsor;
    address public immutable recovery;
    address public immutable treasury;
    address public immutable operator;
    address public immutable requester;
    address public immutable refundExecutor;
    address public immutable prizeReceiver;

    address[3] public buyers;
    address[3] public recipients;

    uint256 public ghostGrossPaid;
    uint256 public ghostQuotePaidOut;
    uint256 public ghostQuoteDonations;
    uint256 public ghostRequestCount;
    uint256 public ghostResolutionCount;
    uint256 public ghostFailureCount;
    uint256 public ghostPrizeClaims;
    bool public statusWentBackward;
    IRaffle.Status public highestStatus;

    constructor(
        MockERC20 quote_,
        MockERC721 prize_,
        MockEntropyV2 entropy_,
        RaffleFactory factory_,
        Raffle raffle_,
        address sponsor_,
        address recovery_,
        address treasury_
    ) {
        quote = quote_;
        prize = prize_;
        entropy = entropy_;
        factory = factory_;
        raffle = raffle_;
        sponsor = sponsor_;
        recovery = recovery_;
        treasury = treasury_;
        operator = address(0xA001);
        requester = address(0xA002);
        refundExecutor = address(0xA003);
        prizeReceiver = address(0xA004);
        buyers = [address(0xB001), address(0xB002), address(0xB003)];
        recipients = [address(0xC001), address(0xC002), address(0xC003)];
        highestStatus = raffle_.status();
    }

    function buy(uint256 buyerSeed, uint256 recipientSeed, uint256 quantitySeed) external {
        if (!_isOpen() || raffle.totalTickets() >= 100) return;
        address buyer = buyers[buyerSeed % buyers.length];
        address recipient = recipientSeed % 2 == 0 ? buyer : recipients[recipientSeed % recipients.length];
        uint256 remaining = 100 - raffle.totalTickets();
        uint256 quantity = bound(quantitySeed, 1, remaining < 10 ? remaining : 10);
        uint256 beforeGross = raffle.grossSales();
        vm.prank(buyer);
        try raffle.buyTickets(recipient, quantity) {
            ghostGrossPaid += raffle.grossSales() - beforeGross;
        } catch { }
        _observe();
    }

    function approveAndTransfer(uint256 ticketSeed, uint256 recipientSeed) external {
        if (raffle.totalTickets() == 0) return;
        uint256 ticketId = bound(ticketSeed, 1, raffle.totalTickets());
        try raffle.ownerOf(ticketId) returns (address owner) {
            address recipient = recipients[recipientSeed % recipients.length];
            vm.prank(owner);
            try raffle.approve(operator, ticketId) {
                vm.prank(operator);
                try raffle.transferFrom(owner, recipient, ticketId) { } catch { }
            } catch { }
        } catch { }
        _observe();
    }

    function attemptProtocolTransfer(uint256 ticketSeed, uint256 destinationSeed) external {
        if (raffle.totalTickets() == 0) return;
        uint256 ticketId = bound(ticketSeed, 1, raffle.totalTickets());
        address[5] memory destinations =
            [address(raffle), address(factory), address(quote), address(prize), address(entropy)];
        try raffle.ownerOf(ticketId) returns (address owner) {
            vm.prank(owner);
            try raffle.transferFrom(owner, destinations[destinationSeed % destinations.length], ticketId) { } catch { }
        } catch { }
        _observe();
    }

    function warpToEnd() external {
        if (block.timestamp < raffle.endTime()) vm.warp(raffle.endTime());
        _observe();
    }

    function warpToRequestDeadline() external {
        if (block.timestamp < raffle.requestGraceDeadline()) vm.warp(raffle.requestGraceDeadline());
        _observe();
    }

    function warpToCallbackDeadline() external {
        uint256 deadline = raffle.callbackDeadline();
        if (deadline != 0 && block.timestamp < deadline) vm.warp(deadline);
        _observe();
    }

    function requestDraw() external {
        if (!_canRequestDraw()) return;
        uint256 fee = raffle.getEntropyFee();
        vm.deal(requester, fee);
        vm.prank(requester);
        try raffle.requestDraw{ value: fee }() {
            ++ghostRequestCount;
        } catch { }
        _observe();
    }

    function fulfill(bytes32 randomNumber) external {
        if (raffle.status() != IRaffle.Status.Drawing) return;
        try entropy.fulfill(raffle.entropySequenceNumber(), randomNumber) {
            IRaffle.Status current = raffle.status();
            if (current == IRaffle.Status.NftWon || current == IRaffle.Status.CashWon) ++ghostResolutionCount;
        } catch { }
        _observe();
    }

    function wrongCallback(bytes32 randomNumber) external {
        if (raffle.status() != IRaffle.Status.Drawing) return;
        uint64 sequence = raffle.entropySequenceNumber();
        try entropy.fulfillAs(sequence, sequence + 1, randomNumber) { } catch { }
        _observe();
    }

    function enableRefunds() external {
        if (!_canEnableRefunds()) return;
        vm.prank(refundExecutor);
        try raffle.enableRefunds() {
            ++ghostFailureCount;
        } catch { }
        _observe();
    }

    function redeemRefund(uint256 ticketSeed) external {
        if (raffle.status() != IRaffle.Status.Refunding || raffle.totalTickets() == 0) return;
        uint256 start = bound(ticketSeed, 1, raffle.totalTickets());
        for (uint256 offset; offset < raffle.totalTickets(); ++offset) {
            uint256 ticketId = ((start - 1 + offset) % raffle.totalTickets()) + 1;
            try raffle.ownerOf(ticketId) returns (address owner) {
                uint256[] memory ids = new uint256[](1);
                ids[0] = ticketId;
                vm.prank(owner);
                try raffle.redeemRefundTickets(ids, owner) returns (uint256 amount) {
                    ghostQuotePaidOut += amount;
                } catch { }
                break;
            } catch { }
        }
        _observe();
    }

    function redeemWinner() external {
        IRaffle.Status current = raffle.status();
        if (current != IRaffle.Status.NftWon && current != IRaffle.Status.CashWon) return;
        uint256 ticketId = raffle.winningTicketId();
        try raffle.ownerOf(ticketId) returns (address owner) {
            vm.prank(owner);
            try raffle.redeemWinningTicket(prizeReceiver) returns (uint256 amount) {
                ghostQuotePaidOut += amount;
                if (current == IRaffle.Status.NftWon) ++ghostPrizeClaims;
            } catch { }
        } catch { }
        _observe();
    }

    function claimQuote(bool protocolClaim) external {
        address account = protocolClaim ? treasury : sponsor;
        if (raffle.claimableQuote(account) == 0) return;
        try raffle.claimQuoteFor(account) returns (uint256 amount) {
            ghostQuotePaidOut += amount;
        } catch { }
        _observe();
    }

    function claimSponsorPrize() external {
        IRaffle.Status current = raffle.status();
        if (
            raffle.prizeClaimed()
                || (
                    current != IRaffle.Status.CashWon && current != IRaffle.Status.Refunding
                        && current != IRaffle.Status.Closed
                )
        ) return;
        vm.prank(recovery);
        try raffle.claimSponsorPrize(prizeReceiver) {
            ++ghostPrizeClaims;
        } catch { }
        _observe();
    }

    function donateQuote(uint96 amountSeed) external {
        uint256 amount = bound(uint256(amountSeed), 1, 10e6);
        quote.mint(address(raffle), amount);
        ghostQuoteDonations += amount;
        _observe();
    }

    function closeEmpty(bool sponsorCalls) external {
        if (raffle.status() != IRaffle.Status.Active || raffle.totalTickets() != 0) return;
        vm.prank(sponsorCalls ? sponsor : refundExecutor);
        try raffle.closeEmptyRaffle() { } catch { }
        _observe();
    }

    function _isOpen() internal view returns (bool) {
        return raffle.status() == IRaffle.Status.Active && block.timestamp >= raffle.startTime()
            && block.timestamp < raffle.endTime();
    }

    function _canRequestDraw() internal view returns (bool) {
        return raffle.status() == IRaffle.Status.Active && raffle.totalTickets() != 0
            && block.timestamp >= raffle.endTime() && block.timestamp < raffle.requestGraceDeadline();
    }

    function _canEnableRefunds() internal view returns (bool) {
        IRaffle.Status current = raffle.status();
        return (
            current == IRaffle.Status.Active && raffle.totalTickets() != 0
                && block.timestamp >= raffle.requestGraceDeadline()
        ) || (current == IRaffle.Status.Drawing && block.timestamp >= raffle.callbackDeadline());
    }

    function _observe() internal {
        IRaffle.Status current = raffle.status();
        if (uint256(current) < uint256(highestStatus)) statusWentBackward = true;
        if (uint256(current) > uint256(highestStatus)) highestStatus = current;
    }
}
