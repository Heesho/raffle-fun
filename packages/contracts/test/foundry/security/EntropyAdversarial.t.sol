// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { AdversarialEntropyV2 } from "../../../src/mocks/AdversarialEntropyV2.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";

contract EntropyAdversarialTest is Test {
    address internal sponsor = makeAddr("entropy-sponsor");
    address internal buyer = makeAddr("entropy-buyer");
    address internal treasury = makeAddr("entropy-treasury");

    MockERC20 internal quote;
    MockERC721 internal prize;
    AdversarialEntropyV2 internal entropy;
    RaffleFactory internal factory;
    uint256 internal nextPrizeId = 1;

    function setUp() public {
        vm.warp(100_000);
        quote = new MockERC20();
        prize = new MockERC721();
        entropy = new AdversarialEntropyV2();
        factory = new RaffleFactory(address(quote), address(entropy), treasury, 300_000, address(this));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), true);
    }

    function testFeeReadAndRequestFailuresRollBackToActive() public {
        Raffle raffle = _soldRaffle();
        vm.warp(raffle.endTime());

        entropy.configureFailures(true, false, true, false);
        vm.expectRevert(AdversarialEntropyV2.FeeReadFailed.selector);
        raffle.requestDraw();
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Active));
        assertEq(raffle.drawRequestedAt(), 0);

        entropy.configureFailures(false, true, true, false);
        uint256 fee = raffle.getEntropyFee();
        vm.expectRevert(AdversarialEntropyV2.RequestFailed.selector);
        raffle.requestDraw{ value: fee }();
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Active));
        assertEq(raffle.drawRequestedAt(), 0);
    }

    function testQuotedFeeCanBeZeroOrBecomeInsufficientWithoutConsumingRequest() public {
        Raffle raffle = _soldRaffle();
        vm.warp(raffle.endTime());

        entropy.configureFees(0, 0);
        uint64 sequence = raffle.requestDraw();
        assertEq(sequence, 1);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Drawing));

        Raffle staleQuote = _soldRaffle();
        vm.warp(staleQuote.endTime());
        entropy.configureFees(1, type(uint128).max);
        vm.expectRevert(
            abi.encodeWithSelector(AdversarialEntropyV2.InsufficientFee.selector, type(uint128).max, uint256(1))
        );
        staleQuote.requestDraw{ value: 1 }();
        assertEq(uint256(staleQuote.status()), uint256(IRaffle.Status.Active));
    }

    function testSynchronousDuplicateAndWrongCallbacksCannotResolveInFlightRequest() public {
        Raffle raffle = _soldRaffle();
        vm.warp(raffle.endTime());
        entropy.configureSynchronousCallbacks(2, 0, bytes32(0));
        entropy.configureFailures(false, false, true, true);

        uint64 sequence = raffle.requestDraw{ value: raffle.getEntropyFee() }();
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Drawing));
        assertEq(raffle.winningTicketId(), 0);
        assertFalse(entropy.lastReentrySucceeded());

        entropy.fulfillAs(address(raffle), sequence + 1, bytes32(0));
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Drawing));
        entropy.fulfill(sequence, bytes32(0));
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.NftWon));
        uint256 winningTicket = raffle.winningTicketId();
        entropy.fulfill(sequence, bytes32(uint256(999)));
        assertEq(raffle.winningTicketId(), winningTicket);
    }

    function testZeroAndRepeatedSequencesRemainSingleRaffleScoped() public {
        entropy.configureSequence(7, true);
        Raffle first = _soldRaffle();
        Raffle second = _soldRaffle();
        vm.warp(first.endTime());
        uint64 firstSequence = first.requestDraw{ value: first.getEntropyFee() }();
        uint64 secondSequence = second.requestDraw{ value: second.getEntropyFee() }();
        assertEq(firstSequence, 7);
        assertEq(secondSequence, 7);
        entropy.fulfillAs(address(first), 7, bytes32(0));
        entropy.fulfillAs(address(second), 7, bytes32(0));
        assertEq(uint256(first.status()), uint256(IRaffle.Status.NftWon));
        assertEq(uint256(second.status()), uint256(IRaffle.Status.NftWon));

        entropy.configureSequence(0, true);
        Raffle zeroSequence = _soldRaffle();
        vm.warp(zeroSequence.endTime());
        uint64 actual = zeroSequence.requestDraw{ value: zeroSequence.getEntropyFee() }();
        assertEq(actual, 0);
        entropy.fulfillAs(address(zeroSequence), 0, bytes32(0));
        assertEq(uint256(zeroSequence.status()), uint256(IRaffle.Status.NftWon));
    }

    function testSuccessfulRequestWithoutPersistenceStillHasBoundedRefundRecovery() public {
        Raffle raffle = _soldRaffle();
        vm.warp(raffle.endTime());
        entropy.configureFailures(false, false, false, false);
        uint64 sequence = raffle.requestDraw{ value: raffle.getEntropyFee() }();
        vm.expectRevert(abi.encodeWithSelector(AdversarialEntropyV2.UnknownSequence.selector, sequence));
        entropy.fulfill(sequence, bytes32(0));

        vm.warp(raffle.callbackDeadline());
        raffle.enableRefunds();
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Refunding));
        entropy.fulfillAs(address(raffle), sequence, bytes32(0));
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Refunding));
    }

    function _soldRaffle() internal returns (Raffle raffle) {
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        raffle = Raffle(
            payable(
                factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        prizeToken: address(prize),
                        prizeTokenId: tokenId,
                        sponsorPrizeRecoveryRecipient: sponsor,
                        ticketPrice: 1e6,
                        minimumTickets: 1,
                        startTime: block.timestamp,
                        endTime: block.timestamp + 1 days,
                        metadataURI: "ipfs://adversarial-entropy"
                    })
                )
            )
        );
        quote.mint(buyer, 1e6);
        vm.startPrank(buyer);
        quote.approve(address(raffle), 1e6);
        raffle.buyTickets(buyer, 1);
        vm.stopPrank();
    }
}
