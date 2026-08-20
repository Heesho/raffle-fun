// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { AdversarialVRFV2PlusWrapper } from "../../../src/mocks/AdversarialVRFV2PlusWrapper.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";

contract VrfAdversarialTest is Test {
    address internal sponsor = makeAddr("vrf-sponsor");
    address internal buyer = makeAddr("vrf-buyer");
    address internal treasury = makeAddr("vrf-treasury");

    MockERC20 internal quote;
    MockERC721 internal prize;
    AdversarialVRFV2PlusWrapper internal wrapper;
    RaffleFactory internal factory;
    uint256 internal nextPrizeId = 1;

    function setUp() public {
        vm.warp(100_000);
        quote = new MockERC20();
        prize = new MockERC721();
        wrapper = new AdversarialVRFV2PlusWrapper();
        factory = new RaffleFactory(address(quote), address(wrapper), treasury);
        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), true);
        quote.mint(buyer, 100 * 1e6);
        vm.deal(address(this), 100 ether);
    }

    function testFeeReadAndRequestFailuresRollBackToActiveThenRefundAtDeadline() public {
        Raffle raffle = _preparedRaffle();
        uint256 requestDeadline = raffle.drawRequestDeadline();
        vm.warp(requestDeadline - 1);

        wrapper.configureFailures(true, false, true, false);
        vm.expectRevert(AdversarialVRFV2PlusWrapper.FeeReadFailed.selector);
        raffle.requestDraw();
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Active));
        assertEq(raffle.drawRequestedAt(), 0);

        wrapper.configureFailures(false, true, true, false);
        uint256 fee = wrapper.quotedFee();
        vm.expectRevert(AdversarialVRFV2PlusWrapper.RequestFailed.selector);
        raffle.requestDraw{ value: fee }();
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Active));
        assertEq(raffle.drawRequestedAt(), 0);
        assertEq(raffle.vrfRequestId(), 0);

        vm.warp(requestDeadline);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffle.DrawRequestWindowExpired.selector, requestDeadline, block.timestamp)
        );
        raffle.requestDraw{ value: fee }();

        raffle.enableRefunds();
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Refunding));
        assertEq(raffle.unsettledPot(), 0);
        assertEq(raffle.remainingRefundLiability(), 1e6);
    }

    function testQuotedFeeCanChangeWithoutConsumingRequest() public {
        Raffle raffle = _preparedRaffle();
        vm.warp(raffle.endTime());
        wrapper.configureFees(0, 1 ether);

        vm.expectRevert(abi.encodeWithSelector(AdversarialVRFV2PlusWrapper.InsufficientFee.selector, 1 ether, 0));
        raffle.requestDraw();
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Active));

        wrapper.configureFees(1 ether, 1 ether);
        raffle.requestDraw{ value: 1 ether }();
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Drawing));
        assertEq(wrapper.lastGasLimit(), 300_000);
        assertEq(wrapper.lastConfirmations(), 30);
        assertEq(wrapper.lastNumWords(), 1);
    }

    function testOfficialHelperCannotUseForcedNativeToSubsidizeQuoteDrift() public {
        Raffle raffle = _preparedRaffle();
        vm.warp(raffle.endTime());
        wrapper.configureQuoteDrift(0.1 ether, 1 ether, 1 ether);
        vm.deal(address(raffle), 1 ether);

        vm.expectRevert(abi.encodeWithSelector(IRaffle.InsufficientVrfFee.selector, 1 ether, 0.1 ether));
        raffle.requestDraw{ value: 0.1 ether }();

        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Active));
        assertEq(address(raffle).balance, 1 ether);
        assertEq(wrapper.nextRequestId(), 0);
        assertEq(address(wrapper).balance, 0);
    }

    function testOfficialHelperRefundsAgainstActualLowerPrice() public {
        Raffle raffle = _preparedRaffle();
        vm.warp(raffle.endTime());
        wrapper.configureQuoteDrift(1 ether, 0.4 ether, 0.4 ether);
        address requester = makeAddr("drift-requester");
        vm.deal(requester, 2 ether);
        uint256 balanceBefore = requester.balance;

        vm.prank(requester);
        raffle.requestDraw{ value: 1 ether }();

        assertEq(requester.balance, balanceBefore - 0.4 ether);
        assertEq(address(wrapper).balance, 0.4 ether);
        assertEq(address(raffle).balance, 0);
    }

    function testSynchronousWrongDuplicateAndValidCallbacksCannotResolveInFlightRequest() public {
        Raffle raffle = _preparedRaffle();
        vm.warp(raffle.endTime());
        wrapper.configureSynchronousCallbacks(3, 0, 77, false);

        uint256 requestId = raffle.requestDraw{ value: raffle.getVrfRequestPrice() }();
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Drawing));
        assertEq(raffle.winningEntry(), 0);

        wrapper.fulfill(requestId, 0);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.NftWon));
        assertEq(raffle.winningEntry(), 1);
        wrapper.fulfillAs(address(raffle), requestId + 1, 99);
        assertEq(raffle.winningEntry(), 1);
    }

    function testZeroRequestIdDoesNotMatchUntilRequestReturns() public {
        Raffle raffle = _preparedRaffle();
        vm.warp(raffle.endTime());
        wrapper.configureRequestId(0, true);
        wrapper.configureSynchronousCallbacks(1, 0, 0, false);

        assertEq(raffle.requestDraw{ value: raffle.getVrfRequestPrice() }(), 0);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Drawing));
        assertEq(raffle.winningEntry(), 0);

        wrapper.fulfillAs(address(raffle), 0, 0);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.NftWon));
        assertEq(raffle.winningEntry(), 1);
    }

    function testRepeatedRequestIdsRemainRaffleScoped() public {
        Raffle first = _preparedRaffle();
        Raffle second = _preparedRaffle();
        wrapper.configureRequestId(7, true);
        vm.warp(first.endTime());

        assertEq(first.requestDraw{ value: first.getVrfRequestPrice() }(), 7);
        assertEq(second.requestDraw{ value: second.getVrfRequestPrice() }(), 7);
        wrapper.fulfillAs(address(first), 7, 0);
        assertEq(uint256(first.status()), uint256(IRaffle.Status.NftWon));
        assertEq(uint256(second.status()), uint256(IRaffle.Status.Drawing));
        wrapper.fulfillAs(address(second), 7, 0);
        assertEq(uint256(second.status()), uint256(IRaffle.Status.NftWon));
    }

    function testNonPersistedRequestStillHasBoundedFullRefundRecovery() public {
        Raffle raffle = _preparedRaffle();
        vm.warp(raffle.endTime());
        wrapper.configureFailures(false, false, false, false);
        raffle.requestDraw{ value: raffle.getVrfRequestPrice() }();

        vm.warp(raffle.callbackDeadline());
        raffle.enableRefunds();
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Refunding));
        assertEq(raffle.remainingRefundLiability(), 1e6);
    }

    function testAuthenticatedValidCallbackAtDeadlineIsIgnoredBeforeRefunds() public {
        Raffle raffle = _preparedRaffle();
        vm.warp(raffle.endTime());
        uint256 requestId = raffle.requestDraw{ value: raffle.getVrfRequestPrice() }();

        vm.warp(raffle.callbackDeadline());
        wrapper.fulfill(requestId, 0);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Drawing));
        assertEq(raffle.winningEntry(), 0);
        assertEq(raffle.resolvedAt(), 0);
        assertEq(raffle.unsettledPot(), 1e6);

        raffle.enableRefunds();
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Refunding));
        assertEq(raffle.unsettledPot(), 0);
        assertEq(raffle.remainingRefundLiability(), 1e6);
    }

    function testMalformedAndWrongCallbacksAreIgnoredUntilOneValidWordArrives() public {
        Raffle raffle = _preparedRaffle();
        vm.warp(raffle.endTime());
        uint256 requestId = raffle.requestDraw{ value: raffle.getVrfRequestPrice() }();

        wrapper.fulfillEmpty(address(raffle), requestId);
        wrapper.fulfillAs(address(raffle), requestId + 1, 0);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Drawing));
        assertEq(raffle.winningEntry(), 0);

        wrapper.fulfillAs(address(raffle), requestId, 0);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.NftWon));
        assertEq(raffle.winningEntry(), 1);
    }

    function testWrapperRequestReentryIsRejected() public {
        Raffle raffle = _preparedRaffle();
        vm.warp(raffle.endTime());
        wrapper.configureFailures(false, false, true, true);

        raffle.requestDraw{ value: raffle.getVrfRequestPrice() }();
        assertFalse(wrapper.lastReentrySucceeded());
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Drawing));
    }

    function _preparedRaffle() internal returns (Raffle raffle) {
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        raffle = Raffle(
            payable(factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: sponsor,
                        prizeToken: address(prize),
                        prizeTokenId: tokenId,
                        reserveEntries: 1,
                        endTime: uint64(block.timestamp + 1 days)
                    })
                ))
        );
        vm.prank(buyer);
        quote.approve(address(raffle), 1e6);
        vm.prank(buyer);
        raffle.buyEntries(buyer, 1);
    }
}
