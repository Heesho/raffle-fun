// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {Raffle} from "../../../src/Raffle.sol";
import {RaffleFactory} from "../../../src/RaffleFactory.sol";
import {RaffleLens} from "../../../src/RaffleLens.sol";
import {IRaffle} from "../../../src/interfaces/IRaffle.sol";
import {IRaffleFactory} from "../../../src/interfaces/IRaffleFactory.sol";
import {IRaffleLens} from "../../../src/interfaces/IRaffleLens.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {MockERC721} from "../../../src/mocks/MockERC721.sol";
import {MockEntropyV2} from "../../../src/mocks/MockEntropyV2.sol";

contract NonERC721 {
    function supportsInterface(bytes4) external pure returns (bool) {
        return false;
    }
}

contract RevertingERC165 {
    function supportsInterface(bytes4) external pure returns (bool) {
        revert();
    }
}

contract VerificationPrize {
    address public owner;
    bool public immutable activatesRaffle;

    constructor(address owner_, bool activatesRaffle_) {
        owner = owner_;
        activatesRaffle = activatesRaffle_;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721).interfaceId;
    }

    function ownerOf(uint256) external view returns (address) {
        return owner;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        require(from == owner, "owner");
        if (activatesRaffle) {
            IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, "");
        } else {
            owner = to;
        }
    }
}

contract RejectPrizeReceiver {}

contract RejectNativeRequester {
    function request(Raffle raffle) external payable {
        raffle.requestDraw{value: msg.value}();
    }

    receive() external payable {
        revert();
    }
}

contract ReturnDataNativeRequester {
    function request(Raffle raffle) external payable {
        raffle.requestDraw{value: msg.value}();
    }

    receive() external payable {
        assembly ("memory-safe") {
            return(0, 0x10000)
        }
    }
}

contract RaffleTest is Test, IERC721Receiver {
    uint256 internal constant USDC = 1e6;
    uint32 internal constant CALLBACK_GAS_LIMIT = 300_000;

    address internal sponsor = makeAddr("sponsor");
    address internal buyer = makeAddr("buyer");
    address internal buyerTwo = makeAddr("buyerTwo");
    address internal treasury = makeAddr("treasury");
    address internal outsider = makeAddr("outsider");

    MockERC20 internal quote;
    MockERC721 internal prize;
    MockEntropyV2 internal entropy;
    RaffleFactory internal factory;
    RaffleLens internal lens;
    uint256 internal nextPrizeId = 1;

    function setUp() public {
        vm.warp(1_000_000);
        quote = new MockERC20();
        prize = new MockERC721();
        entropy = new MockEntropyV2();
        factory = new RaffleFactory(address(quote), address(entropy), treasury, CALLBACK_GAS_LIMIT, address(this));
        lens = new RaffleLens(address(factory));

        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), true);
        quote.mint(buyer, 1_000_000 * USDC);
        quote.mint(buyerTwo, 1_000_000 * USDC);
        vm.deal(outsider, 100 ether);
    }

    function testFactoryConstructorDeploysAndEscrowsAtomically() public {
        Raffle raffle = _createDefaultRaffle(100);

        assertEq(factory.raffleCount(), 1);
        assertEq(factory.raffleById(1), address(raffle));
        assertEq(factory.idByRaffle(address(raffle)), 1);
        assertTrue(factory.isRaffle(address(raffle)));
        assertEq(address(factory.quoteToken()), address(quote));
        assertEq(prize.ownerOf(raffle.prizeTokenId()), address(raffle));
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Active));
        assertEq(raffle.factory(), address(factory));
        assertEq(raffle.sponsor(), sponsor);
        assertEq(raffle.protocolTreasury(), treasury);
        assertEq(address(raffle.quoteToken()), address(quote));
    }

    function testRaffleConstructorAuthenticatesConfiguredFactory() public {
        IRaffle.RaffleParams memory params = _directParams();
        params.factory = outsider;
        vm.expectRevert(IRaffle.OnlyFactory.selector);
        new Raffle(params);

        params.factory = address(this);
        params.sponsor = address(0);
        vm.expectRevert(IRaffle.ZeroAddress.selector);
        new Raffle(params);

        params = _directParams();
        params.entropy = address(0);
        vm.expectRevert(IRaffle.ZeroAddress.selector);
        new Raffle(params);
    }

    function testFactoryConstructorAndCreationValidation() public {
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.NotContract.selector, address(0)));
        new RaffleFactory(address(0), address(entropy), treasury, CALLBACK_GAS_LIMIT, address(this));

        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.NotContract.selector, outsider));
        new RaffleFactory(outsider, address(entropy), treasury, CALLBACK_GAS_LIMIT, address(this));

        vm.expectRevert(IRaffleFactory.ZeroAddress.selector);
        new RaffleFactory(address(quote), address(entropy), address(0), CALLBACK_GAS_LIMIT, address(this));

        vm.expectRevert(IRaffleFactory.ZeroCallbackGasLimit.selector);
        new RaffleFactory(address(quote), address(entropy), treasury, 0, address(this));

        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsafeProtocolDestination.selector, address(quote)));
        new RaffleFactory(address(quote), address(entropy), address(quote), CALLBACK_GAS_LIMIT, address(this));

        vm.expectRevert(abi.encodeWithSelector(IRaffleLens.InvalidFactory.selector, address(0)));
        new RaffleLens(address(0));
        vm.expectRevert(abi.encodeWithSelector(IRaffleLens.InvalidFactory.selector, outsider));
        new RaffleLens(outsider);

        IRaffleFactory.CreateRaffleParams memory params = _validCreateParams(address(prize));
        params.ticketPrice = 0;
        _expectCreateRevert(IRaffleFactory.ZeroTicketPrice.selector, params);
        params = _validCreateParams(address(prize));
        params.minimumTickets = 0;
        _expectCreateRevert(IRaffleFactory.ZeroMinimumTickets.selector, params);

        uint256 exactMetadataTokenId = nextPrizeId++;
        prize.mint(sponsor, exactMetadataTokenId);
        params = _validCreateParams(address(prize));
        params.prizeTokenId = exactMetadataTokenId;
        params.metadataURI = new string(2048);
        vm.prank(sponsor);
        Raffle exactMetadata = Raffle(payable(factory.createRaffle(params)));
        assertEq(bytes(exactMetadata.raffleMetadataURI()).length, 2048);

        params = _validCreateParams(address(prize));
        params.metadataURI = new string(2049);
        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.MetadataURITooLong.selector, 2049, 2048));
        factory.createRaffle(params);

        NonERC721 nonErc721 = new NonERC721();
        params = _validCreateParams(address(nonErc721));
        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsupportedPrizeToken.selector, address(nonErc721)));
        factory.createRaffle(params);

        RevertingERC165 revertingErc165 = new RevertingERC165();
        params = _validCreateParams(address(revertingErc165));
        vm.prank(sponsor);
        address revertingToken = address(revertingErc165);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsupportedPrizeToken.selector, revertingToken));
        factory.createRaffle(params);
    }

    function testFactoryEnforcesBoundedSchedulingAndFutureOnlyAdministration() public {
        IRaffleFactory.CreateRaffleParams memory params = _validCreateParams(address(prize));
        params.startTime = block.timestamp - 1;
        vm.prank(sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffleFactory.StartTimeInPast.selector, block.timestamp - 1, block.timestamp)
        );
        factory.createRaffle(params);

        uint256 exactStartTokenId = nextPrizeId++;
        prize.mint(sponsor, exactStartTokenId);
        params = _validCreateParams(address(prize));
        params.prizeTokenId = exactStartTokenId;
        params.startTime = block.timestamp + 7 days;
        params.endTime = params.startTime + 1 days;
        vm.prank(sponsor);
        Raffle exactStart = Raffle(payable(factory.createRaffle(params)));
        assertEq(exactStart.startTime(), block.timestamp + 7 days);

        params = _validCreateParams(address(prize));
        params.startTime = block.timestamp + 7 days + 1;
        params.endTime = params.startTime + 1 days;
        vm.prank(sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffleFactory.StartTimeTooDistant.selector, params.startTime, block.timestamp + 7 days
            )
        );
        factory.createRaffle(params);

        uint256 exactDurationTokenId = nextPrizeId++;
        prize.mint(sponsor, exactDurationTokenId);
        params = _validCreateParams(address(prize));
        params.prizeTokenId = exactDurationTokenId;
        params.startTime = block.timestamp;
        params.endTime = params.startTime + 30 days;
        vm.prank(sponsor);
        Raffle exactDuration = Raffle(payable(factory.createRaffle(params)));
        assertEq(exactDuration.endTime() - exactDuration.startTime(), 30 days);

        params = _validCreateParams(address(prize));
        params.endTime = params.startTime;
        vm.prank(sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffleFactory.InvalidEndTime.selector, params.startTime, params.endTime)
        );
        factory.createRaffle(params);

        params = _validCreateParams(address(prize));
        params.endTime = params.startTime + 30 days + 1;
        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.SaleDurationTooLong.selector, 30 days + 1, 30 days));
        factory.createRaffle(params);

        Raffle existing = _createDefaultRaffle(1);
        factory.setProtocolTreasury(buyerTwo);
        assertEq(existing.protocolTreasury(), treasury);
        vm.expectRevert(IRaffleFactory.ZeroAddress.selector);
        factory.setProtocolTreasury(address(0));
        factory.setCreationPaused(true);
        vm.expectRevert(IRaffleFactory.CreationPaused.selector);
        vm.prank(sponsor);
        factory.createRaffle(_validCreateParams(address(prize)));
        factory.setCreationPaused(false);

        vm.expectRevert(IRaffleFactory.OwnershipRenunciationDisabled.selector);
        factory.renounceOwnership();
        assertEq(factory.owner(), address(this));
    }

    function testFactoryRejectsIncompleteEscrowVerification() public {
        VerificationPrize fakeOwnership = new VerificationPrize(sponsor, true);
        IRaffleFactory.CreateRaffleParams memory params = _validCreateParams(address(fakeOwnership));
        params.prizeTokenId = 77;
        vm.prank(sponsor);
        vm.expectPartialRevert(IRaffleFactory.PrizeEscrowVerificationFailed.selector);
        factory.createRaffle(params);

        VerificationPrize skippedReceiver = new VerificationPrize(sponsor, false);
        params = _validCreateParams(address(skippedReceiver));
        params.prizeTokenId = 88;
        vm.prank(sponsor);
        vm.expectPartialRevert(IRaffleFactory.PrizeEscrowVerificationFailed.selector);
        factory.createRaffle(params);
        assertEq(factory.raffleCount(), 0);
    }

    function testPrizeTransferFailureRevertsDeploymentAndRegistry() public {
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), false);
        IRaffleFactory.CreateRaffleParams memory params = _validCreateParams(address(prize));
        params.prizeTokenId = tokenId;

        vm.prank(sponsor);
        vm.expectRevert();
        factory.createRaffle(params);

        assertEq(factory.raffleCount(), 0);
        assertEq(prize.ownerOf(tokenId), sponsor);
    }

    function testPurchasesMintSequentialTransferableBearerTickets() public {
        Raffle raffle = _createDefaultRaffle(3);
        _approveQuote(buyer, raffle);

        vm.prank(buyer);
        (uint256 first, uint256 last) = raffle.buyTickets(buyer, 3);
        assertEq(first, 1);
        assertEq(last, 3);
        assertEq(raffle.grossSales(), 3 * USDC);
        assertEq(raffle.accountedQuoteBalance(), 3 * USDC);

        vm.prank(buyer);
        raffle.transferFrom(buyer, buyerTwo, 2);
        assertEq(raffle.ownerOf(2), buyerTwo);

        vm.warp(raffle.endTime());
        vm.prank(outsider);
        raffle.requestDraw{value: raffle.getEntropyFee()}();
        vm.prank(buyerTwo);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.TicketTransferLocked.selector, 2, IRaffle.Status.Drawing));
        raffle.transferFrom(buyerTwo, buyer, 2);
        assertEq(raffle.ownerOf(2), buyerTwo);
    }

    function testRegressionSeparatePurchasesContinueSequentialTicketIds() public {
        Raffle raffle = _createDefaultRaffle(4);
        _approveQuote(buyer, raffle);
        _approveQuote(buyerTwo, raffle);

        vm.prank(buyer);
        (uint256 firstOne, uint256 lastOne) = raffle.buyTickets(buyer, 2);
        vm.prank(buyerTwo);
        (uint256 firstTwo, uint256 lastTwo) = raffle.buyTickets(buyerTwo, 2);

        assertEq(firstOne, 1);
        assertEq(lastOne, 2);
        assertEq(firstTwo, 3);
        assertEq(lastTwo, 4);
        assertEq(raffle.ownerOf(3), buyerTwo);
        assertEq(raffle.ownerOf(4), buyerTwo);
        assertEq(raffle.totalTickets(), 4);
        assertEq(raffle.grossSales(), 4 * USDC);
    }

    function testPurchaseAndCloseValidationBranches() public {
        uint256 futureTokenId = nextPrizeId++;
        prize.mint(sponsor, futureTokenId);
        IRaffleFactory.CreateRaffleParams memory params = _validCreateParams(address(prize));
        params.prizeTokenId = futureTokenId;
        params.startTime = block.timestamp + 1;
        params.endTime = params.startTime + 1 days;
        vm.prank(sponsor);
        Raffle future = Raffle(payable(factory.createRaffle(params)));
        _approveQuote(buyer, future);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.SaleNotStarted.selector, future.startTime(), block.timestamp));
        future.buyTickets(buyer, 1);

        Raffle raffle = _createDefaultRaffle(1);
        _approveQuote(buyer, raffle);
        vm.prank(buyer);
        vm.expectRevert(IRaffle.InvalidRecipient.selector);
        raffle.buyTickets(address(0), 1);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuantity.selector, 0, 100));
        raffle.buyTickets(buyer, 0);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuantity.selector, 101, 100));
        raffle.buyTickets(buyer, 101);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.TicketsWereSold.selector, 1));
        raffle.closeEmptyRaffle();
        vm.warp(raffle.endTime());
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.SaleEnded.selector, raffle.endTime(), block.timestamp));
        raffle.buyTickets(buyer, 1);

        uint256 overflowTokenId = nextPrizeId++;
        prize.mint(sponsor, overflowTokenId);
        params = _validCreateParams(address(prize));
        params.prizeTokenId = overflowTokenId;
        params.ticketPrice = type(uint256).max;
        params.startTime = block.timestamp;
        params.endTime = block.timestamp + 1 days;
        vm.prank(sponsor);
        Raffle overflowRaffle = Raffle(payable(factory.createRaffle(params)));
        vm.prank(buyer);
        vm.expectRevert(IRaffle.GrossAmountOverflow.selector);
        overflowRaffle.buyTickets(buyer, 2);
    }

    function testDrawRequestValidationBranches() public {
        Raffle beforeEnd = _createDefaultRaffle(1);
        _buy(beforeEnd, buyer, 1);
        uint256 beforeEndFee = beforeEnd.getEntropyFee();
        vm.expectRevert(abi.encodeWithSelector(IRaffle.RaffleNotEnded.selector, beforeEnd.endTime(), block.timestamp));
        beforeEnd.requestDraw{value: beforeEndFee}();

        Raffle empty = _createDefaultRaffle(1);
        vm.warp(empty.endTime());
        uint256 emptyFee = empty.getEntropyFee();
        vm.expectRevert(IRaffle.NoTicketsSold.selector);
        empty.requestDraw{value: emptyFee}();
        vm.warp(empty.requestGraceDeadline());
        vm.expectRevert(IRaffle.NoTicketsSold.selector);
        empty.enableRefunds();

        Raffle expired = _createDefaultRaffle(1);
        _buy(expired, buyer, 1);
        vm.warp(expired.requestGraceDeadline());
        uint256 expiredFee = expired.getEntropyFee();
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.DrawRequestWindowExpired.selector, expired.requestGraceDeadline(), block.timestamp
            )
        );
        expired.requestDraw{value: expiredFee}();
    }

    function testEmptyRaffleClosesEarlyForSponsorAndAfterEndForAnyone() public {
        Raffle early = _createDefaultRaffle(1);
        vm.prank(outsider);
        vm.expectRevert(IRaffle.OnlySponsor.selector);
        early.closeEmptyRaffle();

        vm.prank(sponsor);
        early.closeEmptyRaffle();
        assertEq(uint256(early.status()), uint256(IRaffle.Status.Closed));
        vm.prank(sponsor);
        early.claimSponsorPrize(sponsor);
        assertEq(prize.ownerOf(early.prizeTokenId()), sponsor);

        Raffle ended = _createDefaultRaffle(1);
        vm.warp(ended.endTime());
        vm.prank(outsider);
        ended.closeEmptyRaffle();
        assertEq(uint256(ended.status()), uint256(IRaffle.Status.Closed));
    }

    function testEntropyDynamicFeeForwardsExactAndImmediatelyReturnsExcess() public {
        Raffle raffle = _createDefaultRaffle(1);
        _buy(raffle, buyer, 1);
        vm.warp(raffle.endTime());
        uint256 fee = raffle.getEntropyFee();

        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InsufficientEntropyFee.selector, fee, fee - 1));
        raffle.requestDraw{value: fee - 1}();

        uint256 balanceBefore = outsider.balance;
        vm.prank(outsider);
        uint64 sequence = raffle.requestDraw{value: fee + 1 ether}();
        assertEq(outsider.balance, balanceBefore - fee);
        assertEq(address(raffle).balance, 0);
        assertEq(entropy.consumerBySequence(sequence), address(raffle));
        assertEq(entropy.gasLimitBySequence(sequence), CALLBACK_GAS_LIMIT);
    }

    function testRejectedImmediateNativeRefundRevertsEntireEntropyRequest() public {
        Raffle raffle = _createDefaultRaffle(1);
        _buy(raffle, buyer, 1);
        vm.warp(raffle.endTime());
        RejectNativeRequester requester = new RejectNativeRequester();
        vm.deal(address(requester), 2 ether);
        uint256 fee = raffle.getEntropyFee();

        vm.expectRevert(abi.encodeWithSelector(IRaffle.NativeRefundFailed.selector, address(requester), 1));
        requester.request{value: fee + 1}(raffle);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Active));
        assertEq(entropy.latestSequenceNumber(), 0);
    }

    function testImmediateNativeRefundIgnoresOversizedReturnData() public {
        Raffle raffle = _createDefaultRaffle(1);
        _buy(raffle, buyer, 1);
        vm.warp(raffle.endTime());
        ReturnDataNativeRequester requester = new ReturnDataNativeRequester();
        vm.deal(address(requester), 2 ether);

        requester.request{value: raffle.getEntropyFee() + 1}(raffle);

        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Drawing));
        assertEq(address(raffle).balance, 0);
    }

    function testOneFunctionEnablesNoRequestAndCallbackTimeoutRefunds() public {
        Raffle unrequested = _createDefaultRaffle(2);
        _buy(unrequested, buyer, 2);
        vm.warp(unrequested.requestGraceDeadline() - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.RefundsNotAvailable.selector,
                unrequested.requestGraceDeadline(),
                unrequested.requestGraceDeadline() - 1
            )
        );
        unrequested.enableRefunds();
        vm.warp(unrequested.requestGraceDeadline());
        unrequested.enableRefunds();
        assertEq(uint256(unrequested.status()), uint256(IRaffle.Status.Refunding));
        assertEq(unrequested.remainingRefundLiability(), 2 * USDC);

        Raffle timedOut = _createDefaultRaffle(1);
        _buy(timedOut, buyer, 1);
        uint64 sequence = _request(timedOut);
        vm.warp(timedOut.callbackDeadline() - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.RefundsNotAvailable.selector, timedOut.callbackDeadline(), timedOut.callbackDeadline() - 1
            )
        );
        timedOut.enableRefunds();
        vm.warp(timedOut.callbackDeadline());
        timedOut.enableRefunds();
        assertEq(uint256(timedOut.status()), uint256(IRaffle.Status.Refunding));
        entropy.fulfill(sequence, bytes32(0));
        assertEq(uint256(timedOut.status()), uint256(IRaffle.Status.Refunding));

        Raffle callbackWins = _createDefaultRaffle(1);
        _buy(callbackWins, buyer, 1);
        uint64 callbackWinsSequence = _request(callbackWins);
        vm.warp(callbackWins.callbackDeadline() - 1);
        entropy.fulfill(callbackWinsSequence, bytes32(0));
        assertEq(uint256(callbackWins.status()), uint256(IRaffle.Status.NftWon));
        vm.warp(callbackWins.callbackDeadline());
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.RefundsNotAvailable.selector, callbackWins.nftRedemptionDeadline(), block.timestamp
            )
        );
        callbackWins.enableRefunds();
    }

    function testEnableRefundsRejectsResolvedAndTerminalStatuses() public {
        Raffle cashWon = _createDefaultRaffle(2);
        _buy(cashWon, buyer, 1);
        _resolve(cashWon, bytes32(0));
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.CashWon));
        cashWon.enableRefunds();

        Raffle claimedNft = _createDefaultRaffle(1);
        _buy(claimedNft, buyer, 1);
        _resolve(claimedNft, bytes32(0));
        vm.prank(buyer);
        claimedNft.redeemWinningTicket(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.NftWon));
        claimedNft.enableRefunds();

        Raffle refunding = _createDefaultRaffle(2);
        _buy(refunding, buyer, 1);
        vm.warp(refunding.requestGraceDeadline());
        refunding.enableRefunds();
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.Refunding));
        refunding.enableRefunds();

        Raffle closed = _createDefaultRaffle(1);
        vm.prank(sponsor);
        closed.closeEmptyRaffle();
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.Closed));
        closed.enableRefunds();
    }

    function testRefundTicketsRemainTransferableAndBurnForExactRefund() public {
        Raffle raffle = _createDefaultRaffle(3);
        _buy(raffle, buyer, 3);
        vm.warp(raffle.requestGraceDeadline());
        raffle.enableRefunds();

        vm.prank(buyer);
        raffle.transferFrom(buyer, buyerTwo, 2);
        assertEq(raffle.ownerOf(2), buyerTwo);

        uint256 buyerBefore = quote.balanceOf(buyer);
        uint256[] memory buyerIds = new uint256[](2);
        buyerIds[0] = 1;
        buyerIds[1] = 3;
        vm.prank(buyer);
        raffle.redeemRefundTickets(buyerIds, buyer);
        assertEq(quote.balanceOf(buyer), buyerBefore + 2 * USDC);
        assertEq(raffle.remainingRefundLiability(), USDC);

        uint256[] memory buyerTwoIds = new uint256[](1);
        buyerTwoIds[0] = 2;
        vm.prank(buyerTwo);
        raffle.redeemRefundTickets(buyerTwoIds, buyerTwo);
        assertEq(raffle.remainingRefundLiability(), 0);
        assertEq(raffle.accountedQuoteBalance(), 0);

        vm.expectRevert();
        raffle.ownerOf(1);
        vm.prank(buyer);
        vm.expectRevert();
        raffle.redeemRefundTickets(buyerIds, buyer);
    }

    function testRefundRedemptionRequiresActualOwnerAndBoundedBatch() public {
        Raffle raffle = _createDefaultRaffle(2);
        _buy(raffle, buyer, 2);
        vm.warp(raffle.requestGraceDeadline());
        raffle.enableRefunds();

        uint256[] memory one = new uint256[](1);
        one[0] = 1;
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NotTicketOwner.selector, 1, outsider, buyer));
        raffle.redeemRefundTickets(one, outsider);

        uint256[] memory empty = new uint256[](0);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuantity.selector, 0, 100));
        raffle.redeemRefundTickets(empty, buyer);

        uint256[] memory tooMany = new uint256[](101);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuantity.selector, 101, 100));
        raffle.redeemRefundTickets(tooMany, buyer);
    }

    function testNftWinnerBurnsBearerTicketAndProtocolReceivesFivePercent() public {
        Raffle raffle = _createDefaultRaffle(2);
        _buy(raffle, buyer, 2);
        vm.prank(buyer);
        raffle.transferFrom(buyer, buyerTwo, 2);

        uint64 sequence = _request(raffle);
        vm.expectEmit(true, true, true, true, address(raffle));
        emit IRaffle.RaffleResolved(sequence, 2, IRaffle.Status.NftWon, 100_000, 0, 1_900_000);
        entropy.fulfill(sequence, bytes32(uint256(1)));

        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.NftWon));
        assertEq(raffle.winningTicketId(), 2);
        assertEq(raffle.claimableQuote(treasury), 0);
        assertEq(raffle.claimableQuote(sponsor), 0);
        assertEq(raffle.unsettledPot(), 2 * USDC);

        vm.prank(buyerTwo);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.TicketTransferLocked.selector, 2, IRaffle.Status.NftWon));
        raffle.transferFrom(buyerTwo, buyer, 2);
        vm.prank(buyerTwo);
        raffle.redeemWinningTicket(buyerTwo);
        assertEq(prize.ownerOf(raffle.prizeTokenId()), buyerTwo);
        assertTrue(raffle.winningTicketRedeemed());
        assertEq(raffle.claimableQuote(treasury), 100_000);
        assertEq(raffle.claimableQuote(sponsor), 1_900_000);
        assertEq(raffle.unsettledPot(), 0);

        vm.prank(treasury);
        raffle.claimQuote(treasury);
        vm.prank(sponsor);
        raffle.claimQuote(sponsor);
        assertEq(raffle.accountedQuoteBalance(), 0);
    }

    function testUnredeemedNftResultFallsBackToFullTicketRefunds() public {
        Raffle raffle = _createDefaultRaffle(1);
        _buy(raffle, buyer, 1);
        _resolve(raffle, bytes32(0));

        assertEq(raffle.nftRedemptionDeadline(), raffle.resolvedAt() + 30 days);
        vm.warp(raffle.nftRedemptionDeadline() - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.RefundsNotAvailable.selector, raffle.nftRedemptionDeadline(), block.timestamp
            )
        );
        raffle.enableRefunds();

        vm.warp(raffle.nftRedemptionDeadline());
        raffle.enableRefunds();
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Refunding));
        assertEq(raffle.remainingRefundLiability(), USDC);
        assertEq(raffle.claimableQuote(treasury), 0);
        assertEq(raffle.claimableQuote(sponsor), 0);

        vm.prank(buyer);
        raffle.transferFrom(buyer, buyerTwo, 1);
        uint256[] memory ticketIds = new uint256[](1);
        ticketIds[0] = 1;
        vm.prank(buyerTwo);
        raffle.redeemRefundTickets(ticketIds, buyerTwo);
        assertEq(raffle.remainingRefundLiability(), 0);
    }

    function testCashWinnerBurnsBearerTicketAndFeeStillApplies() public {
        Raffle raffle = _createDefaultRaffle(100);
        _buy(raffle, buyer, 80);
        _resolve(raffle, bytes32(0));

        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.CashWon));
        assertEq(raffle.claimableQuote(treasury), 4 * USDC);
        assertEq(raffle.winnerCashLiability(), 60_800_000);
        assertEq(raffle.claimableQuote(sponsor), 15_200_000);
        assertEq(raffle.accountedQuoteBalance(), 80 * USDC);

        uint256 buyerBefore = quote.balanceOf(buyer);
        vm.prank(buyer);
        raffle.redeemWinningTicket(buyer);
        assertEq(quote.balanceOf(buyer), buyerBefore + 60_800_000);
        assertEq(raffle.winnerCashLiability(), 0);

        vm.prank(sponsor);
        raffle.claimSponsorPrize(sponsor);
        assertEq(prize.ownerOf(raffle.prizeTokenId()), sponsor);
    }

    function testSponsorPrizeRecoveryExistsOnlyForCashRefundAndClosed() public {
        Raffle nftWon = _createDefaultRaffle(1);
        _buy(nftWon, buyer, 1);
        _resolve(nftWon, bytes32(0));
        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.SponsorPrizeUnavailable.selector, IRaffle.Status.NftWon));
        nftWon.claimSponsorPrize(sponsor);

        Raffle refunding = _createDefaultRaffle(2);
        _buy(refunding, buyer, 1);
        vm.warp(refunding.requestGraceDeadline());
        refunding.enableRefunds();
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.OnlyPrizeRecoveryRecipient.selector, outsider, sponsor));
        refunding.claimSponsorPrize(outsider);
        vm.prank(sponsor);
        refunding.claimSponsorPrize(sponsor);
        assertEq(prize.ownerOf(refunding.prizeTokenId()), sponsor);
    }

    function testBearerSettlementAndQuoteClaimValidationBranches() public {
        Raffle active = _createDefaultRaffle(1);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.Active));
        active.redeemWinningTicket(buyer);

        _buy(active, buyer, 1);
        _resolve(active, bytes32(0));
        vm.prank(buyer);
        vm.expectRevert(IRaffle.ZeroAddress.selector);
        active.redeemWinningTicket(address(0));
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NotTicketOwner.selector, 1, outsider, buyer));
        active.redeemWinningTicket(outsider);
        vm.prank(buyer);
        active.redeemWinningTicket(buyer);

        vm.prank(sponsor);
        vm.expectRevert(IRaffle.ZeroAddress.selector);
        active.claimQuote(address(0));
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NoQuoteClaim.selector, outsider));
        active.claimQuoteFor(outsider);
        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuoteDestination.selector, address(active)));
        active.claimQuote(address(active));
        assertGt(active.claimableQuote(sponsor), 0);

        Raffle refunding = _createDefaultRaffle(2);
        _buy(refunding, buyer, 1);
        vm.warp(refunding.requestGraceDeadline());
        refunding.enableRefunds();
        uint256[] memory ticketIds = new uint256[](1);
        ticketIds[0] = 1;
        vm.prank(buyer);
        vm.expectRevert(IRaffle.ZeroAddress.selector);
        refunding.redeemRefundTickets(ticketIds, address(0));

        Raffle closed = _createDefaultRaffle(1);
        vm.prank(sponsor);
        closed.closeEmptyRaffle();
        vm.prank(sponsor);
        vm.expectRevert(IRaffle.ZeroAddress.selector);
        closed.claimSponsorPrize(address(0));
        vm.prank(sponsor);
        closed.claimSponsorPrize(sponsor);
        vm.prank(sponsor);
        vm.expectRevert(IRaffle.PrizeAlreadyClaimed.selector);
        closed.claimSponsorPrize(sponsor);
    }

    function testViewsMetadataUnexpectedPrizeAndNativeRejection() public {
        Raffle raffle = _createDefaultRaffle(2);
        assertLt(raffle.totalTickets(), raffle.minimumTickets());
        _buy(raffle, buyer, 2);
        assertGe(raffle.totalTickets(), raffle.minimumTickets());
        assertEq(raffle.balanceOf(buyer), raffle.totalTickets());
        assertEq(raffle.balanceOf(outsider), 0);
        assertEq(raffle.tokenURI(1), "ipfs://raffle");
        vm.expectRevert();
        raffle.tokenURI(3);

        uint256 prizeId = raffle.prizeTokenId();
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnexpectedPrize.selector, outsider, prizeId, sponsor, outsider));
        raffle.onERC721Received(outsider, sponsor, prizeId, "");

        vm.deal(outsider, 1);
        vm.prank(outsider);
        (bool success, bytes memory result) = address(raffle).call{value: 1}("");
        assertFalse(success);
        assertEq(bytes4(result), Raffle.DirectNativeTransfer.selector);
    }

    function testRejectedWinningAndSponsorPrizeDestinationsPreserveClaims() public {
        RejectPrizeReceiver rejecter = new RejectPrizeReceiver();
        Raffle nftWon = _createDefaultRaffle(1);
        _buy(nftWon, buyer, 1);
        _resolve(nftWon, bytes32(0));
        vm.prank(buyer);
        vm.expectRevert();
        nftWon.redeemWinningTicket(address(rejecter));
        assertEq(nftWon.ownerOf(1), buyer);
        assertFalse(nftWon.prizeClaimed());

        Raffle closed = _createDefaultRaffle(1);
        vm.prank(sponsor);
        closed.closeEmptyRaffle();
        vm.prank(sponsor);
        vm.expectRevert();
        closed.claimSponsorPrize(address(rejecter));
        assertFalse(closed.prizeClaimed());
    }

    function testWrongDuplicateAndLateCallbacksAreHarmless() public {
        Raffle raffle = _createDefaultRaffle(1);
        _buy(raffle, buyer, 1);
        uint64 sequence = _request(raffle);
        entropy.fulfillAs(sequence, sequence + 1, bytes32(0));
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Drawing));
        entropy.fulfill(sequence, bytes32(0));
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.NftWon));
        entropy.fulfill(sequence, bytes32(uint256(123)));
        assertEq(raffle.winningTicketId(), 1);
    }

    function testLensReportsBearerActionsAndHandlesEntropyFeeFailure() public {
        Raffle raffle = _createDefaultRaffle(100);
        _buy(raffle, buyer, 1);
        _resolve(raffle, bytes32(0));

        IRaffleLens.RaffleView memory viewData = lens.getRaffleState(address(raffle), buyer);
        assertEq(uint256(viewData.status), uint256(IRaffle.Status.CashWon));
        assertEq(viewData.winningTicketOwner, buyer);
        assertTrue(viewData.accountOwnsWinningTicket);
        assertTrue(viewData.canRedeemWinningTicket);
        assertEq(viewData.winnerCashLiability, 760_000);

        entropy.setFeeReadReverts(true);
        viewData = lens.getRaffleState(address(raffle), address(0));
        assertFalse(viewData.entropyFeeAvailable);
        address[] memory oneRaffle = new address[](1);
        oneRaffle[0] = address(raffle);
        IRaffleLens.RaffleView[] memory batch = lens.getRaffleStates(oneRaffle, buyer);
        assertEq(batch.length, 1);
        assertEq(batch[0].raffle, address(raffle));

        vm.expectRevert(abi.encodeWithSelector(IRaffleLens.UnregisteredRaffle.selector, outsider));
        lens.getRaffleState(outsider, buyer);
        address[] memory oversized = new address[](65);
        vm.expectRevert(abi.encodeWithSelector(IRaffleLens.BatchTooLarge.selector, 65, 64));
        lens.getRaffleStates(oversized, buyer);

        entropy.setFeeReadReverts(false);
        Raffle drawing = _createDefaultRaffle(2);
        _buy(drawing, buyer, 1);
        _request(drawing);
        viewData = lens.getRaffleState(address(drawing), buyer);
        assertFalse(viewData.canEnableRefunds);
        vm.warp(drawing.callbackDeadline());
        viewData = lens.getRaffleState(address(drawing), buyer);
        assertTrue(viewData.canEnableRefunds);
        assertEq(viewData.nftRedemptionDeadline, 0);
    }

    function testLensExactSaleAndRequestGraceBoundariesMatchRaffle() public {
        Raffle raffle = _createDefaultRaffle(1);
        IRaffleLens.RaffleView memory viewData = lens.getRaffleState(address(raffle), buyer);
        assertTrue(viewData.canBuy);

        _buy(raffle, buyer, 1);
        vm.warp(raffle.endTime());
        viewData = lens.getRaffleState(address(raffle), buyer);
        assertFalse(viewData.canBuy);
        assertTrue(viewData.canDraw);

        vm.warp(raffle.requestGraceDeadline());
        viewData = lens.getRaffleState(address(raffle), buyer);
        assertFalse(viewData.canDraw);
        assertTrue(viewData.canEnableRefunds);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.DrawRequestWindowExpired.selector, raffle.requestGraceDeadline(), block.timestamp
            )
        );
        raffle.requestDraw();
    }

    function testDirectDonationDoesNotAlterLiabilities() public {
        Raffle raffle = _createDefaultRaffle(1);
        _buy(raffle, buyer, 1);
        quote.mint(address(raffle), 5 * USDC);
        assertEq(raffle.accountedQuoteBalance(), USDC);
        assertEq(quote.balanceOf(address(raffle)) - raffle.accountedQuoteBalance(), 5 * USDC);
        assertGe(quote.balanceOf(address(raffle)), raffle.accountedQuoteBalance());
    }

    function testGasBoundedPurchaseRefundAndLensBatches() public {
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        IRaffleFactory.CreateRaffleParams memory params = _validCreateParams(address(prize));
        params.prizeTokenId = tokenId;
        params.minimumTickets = 101;
        vm.prank(sponsor);
        uint256 gasBefore = gasleft();
        Raffle eoaRaffle = Raffle(payable(factory.createRaffle(params)));
        emit log_named_uint("factory raffle creation gas", gasBefore - gasleft());

        _approveQuote(buyer, eoaRaffle);
        vm.prank(buyer);
        gasBefore = gasleft();
        eoaRaffle.buyTickets(buyer, 100);
        uint256 eoaPurchaseGas = gasBefore - gasleft();
        emit log_named_uint("100 ticket EOA purchase gas", eoaPurchaseGas);
        assertLt(eoaPurchaseGas, 16_777_216);

        Raffle receiverRaffle = _createDefaultRaffle(101);
        _approveQuote(buyer, receiverRaffle);
        vm.prank(buyer);
        gasBefore = gasleft();
        receiverRaffle.buyTickets(address(this), 100);
        uint256 receiverPurchaseGas = gasBefore - gasleft();
        emit log_named_uint("100 ticket receiver purchase gas", receiverPurchaseGas);
        assertLt(receiverPurchaseGas, 16_777_216);

        vm.warp(eoaRaffle.requestGraceDeadline());
        gasBefore = gasleft();
        eoaRaffle.enableRefunds();
        emit log_named_uint("missing request refund finalization gas", gasBefore - gasleft());

        uint256[] memory ticketIds = new uint256[](100);
        for (uint256 index; index < ticketIds.length; ++index) {
            ticketIds[index] = index + 1;
        }
        vm.prank(buyer);
        gasBefore = gasleft();
        eoaRaffle.redeemRefundTickets(ticketIds, buyer);
        uint256 refundBatchGas = gasBefore - gasleft();
        emit log_named_uint("100 ticket refund redemption gas", refundBatchGas);
        assertLt(refundBatchGas, 16_777_216);

        address[] memory batch = new address[](64);
        for (uint256 index; index < batch.length; ++index) {
            batch[index] = address(receiverRaffle);
        }
        gasBefore = gasleft();
        lens.getRaffleStates(batch, buyer);
        emit log_named_uint("64 raffle lens read gas", gasBefore - gasleft());
    }

    function testGasBoundedSettlementAndClaims() public {
        Raffle raffle = _createDefaultRaffle(1);
        _buy(raffle, buyer, 1);
        vm.warp(raffle.endTime());
        vm.prank(outsider);
        uint256 gasBefore = gasleft();
        uint64 sequence = raffle.requestDraw{value: raffle.getEntropyFee()}();
        emit log_named_uint("draw request gas", gasBefore - gasleft());

        gasBefore = gasleft();
        entropy.fulfill(sequence, bytes32(0));
        emit log_named_uint("oracle fulfillment transaction gas", gasBefore - gasleft());

        vm.prank(buyer);
        gasBefore = gasleft();
        raffle.redeemWinningTicket(buyer);
        emit log_named_uint("winning NFT redemption gas", gasBefore - gasleft());

        vm.prank(treasury);
        gasBefore = gasleft();
        raffle.claimQuote(treasury);
        emit log_named_uint("quote claim gas", gasBefore - gasleft());

        vm.prank(sponsor);
        gasBefore = gasleft();
        raffle.claimQuote(sponsor);
        emit log_named_uint("sponsor quote claim gas", gasBefore - gasleft());

        Raffle timeout = _createDefaultRaffle(2);
        _buy(timeout, buyer, 1);
        _request(timeout);
        vm.warp(timeout.callbackDeadline());
        gasBefore = gasleft();
        timeout.enableRefunds();
        emit log_named_uint("callback timeout refund finalization gas", gasBefore - gasleft());

        vm.prank(sponsor);
        gasBefore = gasleft();
        timeout.claimSponsorPrize(sponsor);
        emit log_named_uint("sponsor prize recovery gas", gasBefore - gasleft());
    }

    function testGasFactorySingleLensRefundCashAndClaimFor() public {
        uint256 gasBefore = gasleft();
        new RaffleFactory(address(quote), address(entropy), treasury, CALLBACK_GAS_LIMIT, address(this));
        emit log_named_uint("factory construction gas", gasBefore - gasleft());

        Raffle refunding = _createDefaultRaffle(2);
        _buy(refunding, buyer, 1);
        gasBefore = gasleft();
        lens.getRaffleState(address(refunding), buyer);
        emit log_named_uint("single raffle lens read gas", gasBefore - gasleft());

        vm.warp(refunding.requestGraceDeadline());
        refunding.enableRefunds();
        uint256[] memory ticketIds = new uint256[](1);
        ticketIds[0] = 1;
        vm.prank(buyer);
        gasBefore = gasleft();
        refunding.redeemRefundTickets(ticketIds, buyer);
        emit log_named_uint("one ticket refund redemption gas", gasBefore - gasleft());

        Raffle cash = _createDefaultRaffle(2);
        _buy(cash, buyer, 1);
        _resolve(cash, bytes32(0));
        vm.prank(buyer);
        gasBefore = gasleft();
        cash.redeemWinningTicket(buyer);
        emit log_named_uint("winning cash redemption gas", gasBefore - gasleft());

        gasBefore = gasleft();
        cash.claimQuoteFor(treasury);
        emit log_named_uint("fixed destination claim-for gas", gasBefore - gasleft());
    }

    function testCallbackGasHasSafetyMargin() public {
        Raffle raffle = _createDefaultRaffle(1);
        _buy(raffle, buyer, 1);
        _resolve(raffle, bytes32(0));
        emit log_named_uint("callback gas used", entropy.lastCallbackGasUsed());
        assertLt(entropy.lastCallbackGasUsed(), uint256(CALLBACK_GAS_LIMIT) * 80 / 100);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4 selector) {
        selector = IERC721Receiver.onERC721Received.selector;
    }

    function _createDefaultRaffle(uint256 minimumTickets) internal returns (Raffle raffle) {
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        IRaffleFactory.CreateRaffleParams memory params = _validCreateParams(address(prize));
        params.prizeTokenId = tokenId;
        params.minimumTickets = minimumTickets;
        vm.prank(sponsor);
        raffle = Raffle(payable(factory.createRaffle(params)));
    }

    function _validCreateParams(address prizeToken)
        internal
        view
        returns (IRaffleFactory.CreateRaffleParams memory params)
    {
        params = IRaffleFactory.CreateRaffleParams({
            prizeToken: prizeToken,
            prizeTokenId: nextPrizeId,
            sponsorPrizeRecoveryRecipient: address(0),
            ticketPrice: USDC,
            minimumTickets: 100,
            startTime: block.timestamp,
            endTime: block.timestamp + 1 days,
            metadataURI: "ipfs://raffle"
        });
    }

    function _directParams() internal view returns (IRaffle.RaffleParams memory params) {
        params = IRaffle.RaffleParams({
            factory: address(this),
            sponsor: sponsor,
            sponsorPrizeRecoveryRecipient: sponsor,
            protocolTreasury: treasury,
            quoteToken: address(quote),
            entropy: address(entropy),
            prizeToken: address(prize),
            prizeTokenId: 1,
            raffleId: 1,
            ticketPrice: USDC,
            minimumTickets: 1,
            startTime: block.timestamp,
            endTime: block.timestamp + 1 days,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            metadataURI: "ipfs://raffle"
        });
    }

    function _expectCreateRevert(bytes4 selector, IRaffleFactory.CreateRaffleParams memory params) internal {
        vm.prank(sponsor);
        vm.expectRevert(selector);
        factory.createRaffle(params);
    }

    function _approveQuote(address account, Raffle raffle) internal {
        vm.prank(account);
        quote.approve(address(raffle), type(uint256).max);
    }

    function _buy(Raffle raffle, address account, uint256 quantity) internal {
        _approveQuote(account, raffle);
        vm.prank(account);
        raffle.buyTickets(account, quantity);
    }

    function _request(Raffle raffle) internal returns (uint64 sequence) {
        vm.warp(raffle.endTime());
        vm.prank(outsider);
        sequence = raffle.requestDraw{value: raffle.getEntropyFee()}();
    }

    function _resolve(Raffle raffle, bytes32 random) internal {
        uint64 sequence = _request(raffle);
        entropy.fulfill(sequence, random);
    }
}
