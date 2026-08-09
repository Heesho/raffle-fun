// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";
import { MockEntropyV2 } from "../../../src/mocks/MockEntropyV2.sol";

/// @notice Independent transition/accounting model plus an after-sequence permissionless liveness drain.
contract RaffleDifferentialTest is Test {
    uint256 internal constant PRICE = 1e6;
    uint256 internal constant THRESHOLD = 8;
    uint256 internal constant MAX_MODEL_TICKETS = 20;

    address internal sponsor = makeAddr("model-sponsor");
    address internal treasury = makeAddr("model-treasury");
    address internal actorA = makeAddr("model-a");
    address internal actorB = makeAddr("model-b");
    address internal requester = makeAddr("model-requester");

    MockERC20 internal quote;
    MockERC721 internal prize;
    MockEntropyV2 internal entropy;
    Raffle internal raffle;

    IRaffle.Status internal modelStatus;
    uint256 internal modelTotal;
    uint256 internal modelGross;
    uint256 internal modelUnsettled;
    uint256 internal modelRefund;
    uint256 internal modelWinnerCash;
    uint256 internal modelSponsorClaim;
    uint256 internal modelTreasuryClaim;
    uint256 internal modelWinningTicket;
    uint256 internal modelSurplus;
    bool internal modelPrizeClaimed;
    mapping(uint256 ticketId => address owner) internal modelOwner;

    function setUp() public {
        vm.warp(500_000);
        quote = new MockERC20();
        prize = new MockERC721();
        entropy = new MockEntropyV2();
        entropy.setFee(0);
        RaffleFactory factory = new RaffleFactory(address(quote), address(entropy), treasury, 300_000, address(this));

        prize.mint(sponsor, 1);
        vm.prank(sponsor);
        prize.approve(address(factory), 1);
        vm.prank(sponsor);
        raffle = Raffle(
            payable(
                factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        prizeToken: address(prize),
                        prizeTokenId: 1,
                        sponsorPrizeRecoveryRecipient: sponsor,
                        ticketPrice: PRICE,
                        minimumTickets: THRESHOLD,
                        startTime: block.timestamp,
                        endTime: block.timestamp + 100,
                        metadataURI: "ipfs://differential"
                    })
                )
            )
        );

        quote.mint(actorA, 1000 * PRICE);
        quote.mint(actorB, 1000 * PRICE);
        vm.prank(actorA);
        quote.approve(address(raffle), type(uint256).max);
        vm.prank(actorB);
        quote.approve(address(raffle), type(uint256).max);
        modelStatus = IRaffle.Status.Active;
    }

    function testFuzzDifferentialSequenceAndTerminalLiveness(bytes32 seed, uint8 stepSeed) public {
        uint256 steps = bound(uint256(stepSeed), 1, 32);
        for (uint256 index; index < steps; ++index) {
            uint256 random = uint256(keccak256(abi.encode(seed, index)));
            _act(random);
            _assertModel();
        }

        _finishAndDrain((uint256(seed) & 1) == 0, seed);
        _assertModel();
        assertEq(raffle.accountedQuoteBalance(), 0);
        assertEq(quote.balanceOf(address(raffle)), modelSurplus);
        assertTrue(raffle.prizeClaimed());
        assertNotEq(prize.ownerOf(1), address(raffle));
    }

    function _act(uint256 random) internal {
        uint256 action = random % 13;
        if (action == 0) _buy(random);
        else if (action == 1) _transfer(random);
        else if (action == 2) _warpEnd();
        else if (action == 3) _warpGrace();
        else if (action == 4) _request();
        else if (action == 5) _fulfill(bytes32(random));
        else if (action == 6) _enableRefunds();
        else if (action == 7) _redeemOneRefund(random);
        else if (action == 8) _redeemWinner();
        else if (action == 9) _claim((random & 1) == 0 ? sponsor : treasury);
        else if (action == 10) _claimSponsorPrize();
        else if (action == 11) _closeEmpty();
        else _donate(random);
    }

    function _buy(uint256 random) internal {
        if (
            modelStatus != IRaffle.Status.Active || block.timestamp < raffle.startTime()
                || block.timestamp >= raffle.endTime() || modelTotal >= MAX_MODEL_TICKETS
        ) return;
        uint256 quantity = (random % 3) + 1;
        if (modelTotal + quantity > MAX_MODEL_TICKETS) quantity = MAX_MODEL_TICKETS - modelTotal;
        address buyer = (random & 1) == 0 ? actorA : actorB;
        address recipient = (random & 2) == 0 ? actorA : actorB;
        vm.prank(buyer);
        raffle.buyTickets(recipient, quantity);
        for (uint256 ticketId = modelTotal + 1; ticketId <= modelTotal + quantity; ++ticketId) {
            modelOwner[ticketId] = recipient;
        }
        modelTotal += quantity;
        modelGross += PRICE * quantity;
        modelUnsettled += PRICE * quantity;
    }

    function _transfer(uint256 random) internal {
        if (modelTotal == 0) return;
        uint256 ticketId = (random % modelTotal) + 1;
        address owner = modelOwner[ticketId];
        if (owner == address(0)) return;
        address recipient = owner == actorA ? actorB : actorA;
        vm.prank(owner);
        raffle.transferFrom(owner, recipient, ticketId);
        modelOwner[ticketId] = recipient;
    }

    function _warpEnd() internal {
        if (block.timestamp < raffle.endTime()) vm.warp(raffle.endTime());
    }

    function _warpGrace() internal {
        if (block.timestamp < raffle.requestGraceDeadline()) vm.warp(raffle.requestGraceDeadline());
    }

    function _request() internal {
        if (
            modelStatus != IRaffle.Status.Active || modelTotal == 0 || block.timestamp < raffle.endTime()
                || block.timestamp >= raffle.requestGraceDeadline()
        ) return;
        vm.prank(requester);
        raffle.requestDraw();
        modelStatus = IRaffle.Status.Drawing;
    }

    function _fulfill(bytes32 randomNumber) internal {
        if (modelStatus != IRaffle.Status.Drawing) return;
        entropy.fulfill(raffle.entropySequenceNumber(), randomNumber);
        modelWinningTicket = (uint256(randomNumber) % modelTotal) + 1;
        uint256 fee = modelGross * 500 / 10_000;
        uint256 distributable = modelGross - fee;
        modelTreasuryClaim += fee;
        modelUnsettled = 0;
        if (modelTotal >= THRESHOLD) {
            modelStatus = IRaffle.Status.NftWon;
            modelSponsorClaim += distributable;
        } else {
            modelStatus = IRaffle.Status.CashWon;
            modelWinnerCash = distributable * 8000 / 10_000;
            modelSponsorClaim += distributable - modelWinnerCash;
        }
    }

    function _enableRefunds() internal {
        bool activeReady =
            modelStatus == IRaffle.Status.Active && modelTotal != 0 && block.timestamp >= raffle.requestGraceDeadline();
        bool drawingReady = modelStatus == IRaffle.Status.Drawing && block.timestamp >= raffle.callbackDeadline();
        if (!activeReady && !drawingReady) return;
        raffle.enableRefunds();
        modelStatus = IRaffle.Status.Refunding;
        modelRefund = modelUnsettled;
        modelUnsettled = 0;
    }

    function _redeemOneRefund(uint256 random) internal {
        if (modelStatus != IRaffle.Status.Refunding || modelTotal == 0) return;
        uint256 ticketId = (random % modelTotal) + 1;
        address owner = modelOwner[ticketId];
        if (owner == address(0)) return;
        uint256[] memory ids = new uint256[](1);
        ids[0] = ticketId;
        vm.prank(owner);
        raffle.redeemRefundTickets(ids, owner);
        modelOwner[ticketId] = address(0);
        modelRefund -= PRICE;
    }

    function _redeemWinner() internal {
        if (modelStatus != IRaffle.Status.NftWon && modelStatus != IRaffle.Status.CashWon) return;
        address owner = modelOwner[modelWinningTicket];
        if (owner == address(0)) return;
        vm.prank(owner);
        raffle.redeemWinningTicket(owner);
        modelOwner[modelWinningTicket] = address(0);
        if (modelStatus == IRaffle.Status.NftWon) modelPrizeClaimed = true;
        else modelWinnerCash = 0;
    }

    function _claim(address account) internal {
        uint256 amount = account == sponsor ? modelSponsorClaim : modelTreasuryClaim;
        if (amount == 0) return;
        raffle.claimQuoteFor(account);
        if (account == sponsor) modelSponsorClaim = 0;
        else modelTreasuryClaim = 0;
    }

    function _claimSponsorPrize() internal {
        if (
            modelPrizeClaimed
                || (
                    modelStatus != IRaffle.Status.CashWon && modelStatus != IRaffle.Status.Refunding
                        && modelStatus != IRaffle.Status.Closed
                )
        ) return;
        vm.prank(sponsor);
        raffle.claimSponsorPrize(sponsor);
        modelPrizeClaimed = true;
    }

    function _closeEmpty() internal {
        if (modelStatus != IRaffle.Status.Active || modelTotal != 0) return;
        vm.prank(sponsor);
        raffle.closeEmptyRaffle();
        modelStatus = IRaffle.Status.Closed;
    }

    function _donate(uint256 random) internal {
        uint256 amount = (random % PRICE) + 1;
        quote.mint(address(raffle), amount);
        modelSurplus += amount;
    }

    function _finishAndDrain(bool resolveIfPossible, bytes32 randomNumber) internal {
        if (modelStatus == IRaffle.Status.Active) {
            if (modelTotal == 0) {
                _closeEmpty();
            } else if (resolveIfPossible && block.timestamp < raffle.requestGraceDeadline()) {
                _warpEnd();
                _request();
                _fulfill(randomNumber);
            } else {
                _warpGrace();
                _enableRefunds();
            }
        } else if (modelStatus == IRaffle.Status.Drawing) {
            if (resolveIfPossible) {
                _fulfill(randomNumber);
            } else {
                vm.warp(raffle.callbackDeadline());
                _enableRefunds();
            }
        }

        if (modelStatus == IRaffle.Status.Refunding) _redeemAllRefunds(actorA, actorB);
        else _redeemWinner();
        _claim(sponsor);
        _claim(treasury);
        _claimSponsorPrize();
    }

    function _redeemAllRefunds(address first, address second) internal {
        uint256 firstCount;
        uint256 secondCount;
        for (uint256 ticketId = 1; ticketId <= modelTotal; ++ticketId) {
            if (modelOwner[ticketId] == first) ++firstCount;
            else if (modelOwner[ticketId] == second) ++secondCount;
        }
        uint256[] memory firstIds = new uint256[](firstCount);
        uint256[] memory secondIds = new uint256[](secondCount);
        uint256 firstIndex;
        uint256 secondIndex;
        for (uint256 ticketId = 1; ticketId <= modelTotal; ++ticketId) {
            if (modelOwner[ticketId] == first) firstIds[firstIndex++] = ticketId;
            else if (modelOwner[ticketId] == second) secondIds[secondIndex++] = ticketId;
        }
        if (firstCount != 0) {
            vm.prank(first);
            raffle.redeemRefundTickets(firstIds, first);
            modelRefund -= PRICE * firstCount;
        }
        if (secondCount != 0) {
            vm.prank(second);
            raffle.redeemRefundTickets(secondIds, second);
            modelRefund -= PRICE * secondCount;
        }
        for (uint256 ticketId = 1; ticketId <= modelTotal; ++ticketId) {
            modelOwner[ticketId] = address(0);
        }
    }

    function _assertModel() internal {
        assertEq(uint256(raffle.status()), uint256(modelStatus));
        assertEq(raffle.totalTickets(), modelTotal);
        assertEq(raffle.grossSales(), modelGross);
        assertEq(raffle.unsettledPot(), modelUnsettled);
        assertEq(raffle.remainingRefundLiability(), modelRefund);
        assertEq(raffle.winnerCashLiability(), modelWinnerCash);
        assertEq(raffle.claimableQuote(sponsor), modelSponsorClaim);
        assertEq(raffle.claimableQuote(treasury), modelTreasuryClaim);
        assertEq(raffle.totalClaimableQuote(), modelSponsorClaim + modelTreasuryClaim);
        assertEq(raffle.winningTicketId(), modelWinningTicket);
        assertEq(raffle.prizeClaimed(), modelPrizeClaimed);
        assertEq(
            raffle.accountedQuoteBalance(),
            modelUnsettled + modelRefund + modelWinnerCash + modelSponsorClaim + modelTreasuryClaim
        );
        assertEq(quote.balanceOf(address(raffle)), raffle.accountedQuoteBalance() + modelSurplus);
        if (!modelPrizeClaimed) assertEq(prize.ownerOf(1), address(raffle));
        for (uint256 ticketId = 1; ticketId <= modelTotal; ++ticketId) {
            address expectedOwner = modelOwner[ticketId];
            if (expectedOwner == address(0)) {
                try raffle.ownerOf(ticketId) returns (address) {
                    fail();
                } catch { }
            } else {
                assertEq(raffle.ownerOf(ticketId), expectedOwner);
            }
        }
    }
}
