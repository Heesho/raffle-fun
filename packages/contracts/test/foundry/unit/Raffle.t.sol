// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { RaffleLens } from "../../../src/RaffleLens.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { IRaffleLens } from "../../../src/interfaces/IRaffleLens.sol";
import { FeeOnTransferERC20 } from "../../../src/mocks/FeeOnTransferERC20.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";
import { MockEntropyV2 } from "../../../src/mocks/MockEntropyV2.sol";

contract NonERC721 {
    function supportsInterface(bytes4) external pure returns (bool) {
        return false;
    }
}

contract RejectNativeReceiver {
    receive() external payable {
        revert();
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
    Raffle internal implementation;
    RaffleFactory internal factory;
    RaffleLens internal lens;

    uint256 internal nextPrizeId = 1;

    function setUp() public {
        vm.warp(1_000_000);
        quote = new MockERC20();
        prize = new MockERC721();
        entropy = new MockEntropyV2();
        implementation = new Raffle();
        factory = new RaffleFactory(
            address(implementation),
            _quoteTokens(address(quote)),
            address(entropy),
            treasury,
            CALLBACK_GAS_LIMIT,
            address(this)
        );
        lens = new RaffleLens(address(factory));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), true);
        quote.mint(buyer, 1_000_000 * USDC);
        quote.mint(buyerTwo, 1_000_000 * USDC);
        vm.deal(outsider, 100 ether);
    }

    function testImplementationIsLocked() public {
        IRaffle.InitializeParams memory params;
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(params);
    }

    function testFactoryCreationInitializesRegistryAndEscrowsExactPrize() public {
        uint256 tokenId = nextPrizeId++;
        uint256 predicted =
            uint256(uint160(factory.predictRaffleAddress(1, sponsor, address(quote), address(prize), tokenId)));

        Raffle raffle = _createRaffle(tokenId, USDC, 100, block.timestamp, block.timestamp + 1 days);

        assertEq(address(raffle), address(uint160(predicted)));
        assertEq(factory.raffleCount(), 1);
        assertEq(factory.raffleById(1), address(raffle));
        assertEq(factory.idByRaffle(address(raffle)), 1);
        assertTrue(factory.isRaffle(address(raffle)));
        assertEq(prize.ownerOf(tokenId), address(raffle));
        assertEq(uint256(raffle.state()), uint256(IRaffle.RaffleState.Active));
        assertEq(raffle.sponsor(), sponsor);
        assertEq(raffle.protocolTreasury(), treasury);
        assertEq(address(raffle.quoteToken()), address(quote));
        assertEq(factory.verifiedQuoteTokenCount(), 1);
        assertEq(factory.verifiedQuoteTokenAt(0), address(quote));
        assertTrue(factory.isVerifiedQuoteToken(address(quote)));
    }

    function testFactoryConstructorRejectsInvalidDependenciesAndConfiguration() public {
        vm.expectRevert(IRaffleFactory.ZeroAddress.selector);
        new RaffleFactory(
            address(0), _quoteTokens(address(quote)), address(entropy), treasury, CALLBACK_GAS_LIMIT, address(this)
        );

        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.NotContract.selector, outsider));
        new RaffleFactory(
            outsider, _quoteTokens(address(quote)), address(entropy), treasury, CALLBACK_GAS_LIMIT, address(this)
        );

        vm.expectRevert(IRaffleFactory.ZeroAddress.selector);
        new RaffleFactory(
            address(implementation),
            _quoteTokens(address(quote)),
            address(entropy),
            address(0),
            CALLBACK_GAS_LIMIT,
            address(this)
        );

        vm.expectRevert(IRaffleFactory.ZeroCallbackGasLimit.selector);
        new RaffleFactory(
            address(implementation), _quoteTokens(address(quote)), address(entropy), treasury, 0, address(this)
        );

        address[] memory noQuoteTokens = new address[](0);
        vm.expectRevert(IRaffleFactory.NoInitialVerifiedQuoteTokens.selector);
        new RaffleFactory(
            address(implementation), noQuoteTokens, address(entropy), treasury, CALLBACK_GAS_LIMIT, address(this)
        );

        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.NotContract.selector, outsider));
        new RaffleFactory(
            address(implementation),
            _quoteTokens(outsider),
            address(entropy),
            treasury,
            CALLBACK_GAS_LIMIT,
            address(this)
        );
    }

    function testFactoryAdminAndCreationValidationBranches() public {
        IRaffleFactory.CreateRaffleParams memory params = _validCreateParams(address(prize));

        factory.setProtocolTreasury(buyerTwo);
        assertEq(factory.protocolTreasury(), buyerTwo);
        vm.expectRevert(IRaffleFactory.ZeroAddress.selector);
        factory.setProtocolTreasury(address(0));

        MockERC20 secondQuote = new MockERC20();
        factory.setQuoteTokenVerification(address(secondQuote), true);
        assertTrue(factory.isVerifiedQuoteToken(address(secondQuote)));
        assertEq(factory.verifiedQuoteTokenCount(), 2);
        assertEq(factory.verifiedQuoteTokenAt(1), address(secondQuote));
        vm.expectRevert(
            abi.encodeWithSelector(IRaffleFactory.QuoteTokenVerificationUnchanged.selector, address(secondQuote), true)
        );
        factory.setQuoteTokenVerification(address(secondQuote), true);
        factory.setQuoteTokenVerification(address(secondQuote), false);
        assertFalse(factory.isVerifiedQuoteToken(address(secondQuote)));
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.NotContract.selector, outsider));
        factory.setQuoteTokenVerification(outsider, true);

        factory.setCreationPaused(true);
        assertTrue(factory.creationPaused());
        vm.prank(sponsor);
        vm.expectRevert(IRaffleFactory.CreationPaused.selector);
        factory.createRaffle(params);
        factory.setCreationPaused(false);

        params.startTime = block.timestamp - 1;
        vm.prank(sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffleFactory.StartTimeInPast.selector, block.timestamp - 1, block.timestamp)
        );
        factory.createRaffle(params);

        params.startTime = block.timestamp;
        params.endTime = block.timestamp;
        vm.prank(sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffleFactory.InvalidEndTime.selector, block.timestamp, block.timestamp)
        );
        factory.createRaffle(params);

        params = _validCreateParams(address(prize));
        params.quoteToken = outsider;
        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.NotContract.selector, outsider));
        factory.createRaffle(params);

        params.quoteToken = address(0);
        vm.prank(sponsor);
        vm.expectRevert(IRaffleFactory.ZeroAddress.selector);
        factory.createRaffle(params);

        params = _validCreateParams(address(prize));
        params.ticketPrice = 0;
        vm.prank(sponsor);
        vm.expectRevert(IRaffleFactory.ZeroTicketPrice.selector);
        factory.createRaffle(params);

        params = _validCreateParams(address(prize));
        params.minimumTickets = 0;
        vm.prank(sponsor);
        vm.expectRevert(IRaffleFactory.ZeroMinimumTickets.selector);
        factory.createRaffle(params);

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

        params = _validCreateParams(outsider);
        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.NotContract.selector, outsider));
        factory.createRaffle(params);
    }

    function testAnyContractQuoteTokenCanCreateWhileVerificationOnlyControlsDiscovery() public {
        MockERC20 secondQuote = new MockERC20();
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        IRaffleFactory.CreateRaffleParams memory params = _validCreateParams(address(prize));
        params.prizeTokenId = tokenId;
        params.quoteToken = address(secondQuote);

        vm.prank(sponsor);
        Raffle raffle = Raffle(payable(factory.createRaffle(params)));
        assertFalse(factory.isVerifiedQuoteToken(address(secondQuote)));

        factory.setQuoteTokenVerification(address(secondQuote), true);
        factory.setQuoteTokenVerification(address(secondQuote), false);

        assertEq(address(raffle.quoteToken()), address(secondQuote));
        secondQuote.mint(buyer, USDC);
        vm.prank(buyer);
        secondQuote.approve(address(raffle), USDC);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);
        assertEq(secondQuote.balanceOf(address(raffle)), USDC);

        uint256 unverifiedTokenId = nextPrizeId++;
        prize.mint(sponsor, unverifiedTokenId);
        params.prizeTokenId = unverifiedTokenId;
        vm.prank(sponsor);
        Raffle unverifiedRaffle = Raffle(payable(factory.createRaffle(params)));

        assertEq(address(unverifiedRaffle.quoteToken()), address(secondQuote));
        assertEq(factory.verifiedQuoteTokenCount(), 2);
    }

    function testQuoteTokenVerificationRegistryHasExplicitUniqueTokenBound() public {
        for (uint256 i = 1; i < factory.MAX_VERIFIED_QUOTE_TOKENS(); ++i) {
            factory.setQuoteTokenVerification(address(new NonERC721()), true);
        }
        NonERC721 extraToken = new NonERC721();
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.TooManyVerifiedQuoteTokens.selector, 32));
        factory.setQuoteTokenVerification(address(extraToken), true);
    }

    function testCloneInitializationRejectsUnauthorizedAndZeroAddressConfiguration() public {
        Raffle unauthorizedClone = Raffle(payable(Clones.clone(address(implementation))));
        IRaffle.InitializeParams memory params = _validInitializeParams(address(unauthorizedClone));
        params.factory = outsider;
        vm.expectRevert(IRaffle.OnlyFactory.selector);
        unauthorizedClone.initialize(params);

        Raffle zeroAddressClone = Raffle(payable(Clones.clone(address(implementation))));
        params = _validInitializeParams(address(zeroAddressClone));
        params.sponsor = address(0);
        vm.expectRevert(IRaffle.ZeroAddress.selector);
        zeroAddressClone.initialize(params);
    }

    function testRejectsUnrelatedPrizeSafeTransfer() public {
        Raffle raffle = _createDefaultRaffle(100);
        uint256 unrelatedTokenId = nextPrizeId++;
        prize.mint(sponsor, unrelatedTokenId);

        vm.prank(sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffle.UnexpectedPrize.selector, address(prize), unrelatedTokenId, sponsor, sponsor)
        );
        prize.safeTransferFrom(sponsor, address(raffle), unrelatedTokenId);
    }

    function testSaleBeforeStartRevertsAndAtStartSucceeds() public {
        uint256 start = block.timestamp + 100;
        Raffle raffle = _createRaffle(nextPrizeId++, USDC, 100, start, start + 1 days);
        _approveQuote(buyer, raffle);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.SaleNotStarted.selector, start, block.timestamp));
        raffle.buyTickets(buyer, 1);

        vm.warp(start);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);
        assertEq(raffle.ownerOf(1), buyer);
    }

    function testSaleImmediatelyBeforeEndSucceedsButAtAndAfterEndReverts() public {
        Raffle raffle = _createDefaultRaffle(100);
        _approveQuote(buyer, raffle);

        vm.warp(raffle.endTime() - 1);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);

        vm.warp(raffle.endTime());
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.SaleEnded.selector, raffle.endTime(), block.timestamp));
        raffle.buyTickets(buyer, 1);

        vm.warp(raffle.endTime() + 1);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.SaleEnded.selector, raffle.endTime(), block.timestamp));
        raffle.buyTickets(buyer, 1);
    }

    function testPurchaseValidationAndContiguousTicketIds() public {
        Raffle raffle = _createDefaultRaffle(100);
        _approveQuote(buyer, raffle);

        vm.startPrank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuantity.selector, 0, 100));
        raffle.buyTickets(buyer, 0);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuantity.selector, 101, 100));
        raffle.buyTickets(buyer, 101);
        vm.expectRevert(IRaffle.InvalidRecipient.selector);
        raffle.buyTickets(address(0), 1);

        (uint256 first, uint256 last) = raffle.buyTickets(buyer, 3);
        vm.stopPrank();

        assertEq(first, 1);
        assertEq(last, 3);
        assertEq(raffle.totalTickets(), 3);
        assertEq(raffle.ownerOf(1), buyer);
        assertEq(raffle.ownerOf(2), buyer);
        assertEq(raffle.ownerOf(3), buyer);
    }

    function testGrossPurchaseOverflowIsRejectedBeforeTokenInteraction() public {
        Raffle raffle = _createRaffle(nextPrizeId++, type(uint256).max, 1, block.timestamp, block.timestamp + 1 days);

        vm.prank(buyer);
        vm.expectRevert(IRaffle.GrossAmountOverflow.selector);
        raffle.buyTickets(buyer, 2);
    }

    function testPurchaseAccumulatesGrossWithoutAllocatingFeeBeforeResolution() public {
        Raffle raffle = _createDefaultRaffle(100);
        _approveQuote(buyer, raffle);

        vm.prank(buyer);
        raffle.buyTickets(buyer, 10);

        assertEq(raffle.grossSales(), 10 * USDC);
        assertEq(raffle.claimableQuote(treasury), 0);
        assertEq(raffle.totalClaimableQuote(), 0);
        assertEq(raffle.unsettledPot(), 10 * USDC);
        assertEq(raffle.accountedQuoteBalance(), 10 * USDC);
        assertEq(quote.balanceOf(address(raffle)), 10 * USDC);
    }

    function testSettlementFeeUsesAggregateGrossInsteadOfPerPurchaseRounding() public {
        Raffle raffle = _createRaffle(nextPrizeId++, 10, 2, block.timestamp, block.timestamp + 1 days);
        _approveQuote(buyer, raffle);

        vm.startPrank(buyer);
        raffle.buyTickets(buyer, 1);
        raffle.buyTickets(buyer, 1);
        vm.stopPrank();
        _resolve(raffle, bytes32(0));

        assertEq(raffle.grossSales(), 20);
        assertEq(raffle.claimableQuote(treasury), 1);
        assertEq(raffle.claimableQuote(sponsor), 19);
    }

    function testExactThresholdUsesNftAwardedOutcomeAndWorkedExample() public {
        Raffle raffle = _createDefaultRaffle(100);
        _approveQuote(buyer, raffle);

        vm.startPrank(buyer);
        raffle.buyTickets(buyer, 100);
        vm.stopPrank();
        _resolve(raffle, bytes32(uint256(99)));

        assertEq(uint256(raffle.outcome()), uint256(IRaffle.RaffleOutcome.NftAwarded));
        assertEq(raffle.winningTicketId(), 100);
        assertEq(raffle.winner(), buyer);
        assertEq(raffle.prizeClaimant(), buyer);
        assertEq(raffle.claimableQuote(treasury), 5 * USDC);
        assertEq(raffle.claimableQuote(sponsor), 95 * USDC);
        assertEq(raffle.unsettledPot(), 0);
        assertEq(raffle.accountedQuoteBalance(), 100 * USDC);
    }

    function testThresholdDoesNotCapSalesBeforeFixedEndTime() public {
        Raffle raffle = _createDefaultRaffle(100);
        _approveQuote(buyer, raffle);

        vm.startPrank(buyer);
        raffle.buyTickets(buyer, 100);
        assertTrue(raffle.isThresholdMet());
        assertTrue(raffle.isOpen());
        raffle.buyTickets(buyer, 20);
        vm.stopPrank();
        _resolve(raffle, bytes32(0));

        assertEq(raffle.grossSales(), 120 * USDC);
        assertEq(raffle.totalTickets(), 120);
        assertEq(raffle.claimableQuote(treasury), 6 * USDC);
        assertEq(raffle.claimableQuote(sponsor), 114 * USDC);
    }

    function testThresholdMissedWorkedExampleAllocatesExactEightyTwentyDistributableSplit() public {
        Raffle raffle = _createDefaultRaffle(100);
        _approveQuote(buyer, raffle);

        vm.prank(buyer);
        raffle.buyTickets(buyer, 80);
        _resolve(raffle, bytes32(0));

        assertEq(uint256(raffle.outcome()), uint256(IRaffle.RaffleOutcome.CashFallback));
        assertEq(raffle.grossSales(), 80 * USDC);
        assertEq(raffle.claimableQuote(treasury), 4 * USDC);
        assertEq(raffle.claimableQuote(buyer), 60_800_000);
        assertEq(raffle.claimableQuote(sponsor), 15_200_000);
        assertEq(raffle.prizeClaimant(), sponsor);
        assertEq(raffle.accountedQuoteBalance(), 80 * USDC);
    }

    function testOneTicketRaffleAlwaysSelectsTicketOne() public {
        Raffle raffle = _createDefaultRaffle(1);
        _approveQuote(buyer, raffle);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);

        _resolve(raffle, bytes32(type(uint256).max));
        assertEq(raffle.winningTicketId(), 1);
        assertEq(raffle.winner(), buyer);
    }

    function testLastTicketCanWin() public {
        Raffle raffle = _createDefaultRaffle(10);
        _approveQuote(buyer, raffle);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 10);

        _resolve(raffle, bytes32(uint256(9)));
        assertEq(raffle.winningTicketId(), 10);
    }

    function testCallbackGasHasAtLeastTwentyPercentSafetyMargin() public {
        Raffle raffle = _createDefaultRaffle(100);
        _approveQuote(buyer, raffle);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);

        _resolve(raffle, bytes32(0));
        uint256 measuredGas = entropy.lastCallbackGasUsed();
        assertLt(measuredGas, uint256(CALLBACK_GAS_LIMIT) * 80 / 100);
    }

    function testSponsorCancellationBeforeSalesAndPrizeClaim() public {
        Raffle raffle = _createDefaultRaffle(100);
        uint256 tokenId = raffle.prizeTokenId();

        vm.prank(sponsor);
        raffle.cancelBeforeSales();
        assertEq(uint256(raffle.state()), uint256(IRaffle.RaffleState.Cancelled));
        assertEq(uint256(raffle.outcome()), uint256(IRaffle.RaffleOutcome.CancelledBeforeSale));

        vm.prank(sponsor);
        raffle.claimPrize(sponsor);
        assertEq(prize.ownerOf(tokenId), sponsor);

        vm.prank(sponsor);
        vm.expectRevert(IRaffle.PrizeAlreadyClaimed.selector);
        raffle.claimPrize(sponsor);
    }

    function testCancellationClosingAndPrizeClaimFailureBranches() public {
        Raffle raffle = _createDefaultRaffle(100);

        vm.prank(outsider);
        vm.expectRevert(IRaffle.OnlySponsor.selector);
        raffle.cancelBeforeSales();

        vm.expectRevert(abi.encodeWithSelector(IRaffle.RaffleNotEnded.selector, raffle.endTime(), block.timestamp));
        raffle.closeNoSales();

        vm.prank(sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.InvalidState.selector, IRaffle.RaffleState.Resolved, IRaffle.RaffleState.Active
            )
        );
        raffle.claimPrize(sponsor);

        vm.prank(sponsor);
        raffle.cancelBeforeSales();
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NotPrizeClaimant.selector, outsider, sponsor));
        raffle.claimPrize(outsider);
        vm.prank(sponsor);
        vm.expectRevert(IRaffle.ZeroAddress.selector);
        raffle.claimPrize(address(0));

        Raffle soldRaffle = _createDefaultRaffle(100);
        _approveQuote(buyer, soldRaffle);
        vm.prank(buyer);
        soldRaffle.buyTickets(buyer, 1);
        vm.warp(soldRaffle.endTime());
        vm.expectRevert(abi.encodeWithSelector(IRaffle.TicketsWereSold.selector, 1));
        soldRaffle.closeNoSales();
    }

    function testSponsorCannotCancelAfterOneSale() public {
        Raffle raffle = _createDefaultRaffle(100);
        _approveQuote(buyer, raffle);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);

        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.TicketsAlreadySold.selector, 1));
        raffle.cancelBeforeSales();
    }

    function testAnyoneCanCloseNoSalesAfterEnd() public {
        Raffle raffle = _createDefaultRaffle(100);
        vm.warp(raffle.endTime());

        vm.prank(outsider);
        raffle.closeNoSales();
        assertEq(uint256(raffle.outcome()), uint256(IRaffle.RaffleOutcome.NoSales));
        assertEq(raffle.prizeClaimant(), sponsor);
        assertEq(raffle.accountedQuoteBalance(), 0);
    }

    function testDrawRequirementsAndDuplicateRequest() public {
        Raffle raffle = _createDefaultRaffle(100);
        _approveQuote(buyer, raffle);
        uint256 fee = entropy.fee();

        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.RaffleNotEnded.selector, raffle.endTime(), block.timestamp));
        raffle.requestDraw{ value: fee }();

        vm.warp(raffle.endTime());
        vm.prank(outsider);
        vm.expectRevert(IRaffle.NoTicketsSold.selector);
        raffle.requestDraw{ value: fee }();

        vm.warp(raffle.startTime());
        Raffle soldRaffle = _createRaffle(nextPrizeId++, USDC, 100, block.timestamp, block.timestamp + 1 days);
        _approveQuote(buyer, soldRaffle);
        vm.prank(buyer);
        soldRaffle.buyTickets(buyer, 1);
        vm.warp(soldRaffle.endTime());

        vm.prank(outsider);
        soldRaffle.requestDraw{ value: fee }();
        vm.prank(outsider);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.InvalidState.selector, IRaffle.RaffleState.Active, IRaffle.RaffleState.DrawRequested
            )
        );
        soldRaffle.requestDraw{ value: fee }();
    }

    function testInsufficientEntropyFeeAndNativeClaimFailureBranches() public {
        Raffle raffle = _createDefaultRaffle(1);
        _approveQuote(buyer, raffle);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);
        vm.warp(raffle.endTime());
        uint256 fee = raffle.getEntropyFee();

        vm.expectRevert(abi.encodeWithSelector(IRaffle.InsufficientEntropyFee.selector, fee, fee - 1));
        raffle.requestDraw{ value: fee - 1 }();

        vm.expectRevert(IRaffle.ZeroAddress.selector);
        raffle.claimNative(payable(address(0)));
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NoNativeClaim.selector, address(this)));
        raffle.claimNative(payable(address(this)));

        vm.deal(address(this), fee + 1 ether);
        raffle.requestDraw{ value: fee + 1 ether }();
        RejectNativeReceiver rejectingReceiver = new RejectNativeReceiver();
        vm.expectRevert(
            abi.encodeWithSelector(IRaffle.NativeTransferFailed.selector, address(rejectingReceiver), 1 ether)
        );
        raffle.claimNative(payable(address(rejectingReceiver)));
    }

    function testWrongSequenceIgnoredAndDuplicateCallbackCannotChangeResult() public {
        Raffle raffle = _createDefaultRaffle(2);
        _approveQuote(buyer, raffle);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 2);
        uint64 sequence = _request(raffle);

        entropy.fulfillAs(sequence, sequence + 1, bytes32(uint256(1)));
        assertEq(uint256(raffle.state()), uint256(IRaffle.RaffleState.DrawRequested));
        assertEq(raffle.winningTicketId(), 0);

        entropy.fulfill(sequence, bytes32(0));
        assertEq(raffle.winningTicketId(), 1);
        entropy.fulfill(sequence, bytes32(uint256(1)));
        assertEq(raffle.winningTicketId(), 1);
        assertEq(raffle.winner(), buyer);
    }

    function testWinningOwnerSnapshotSurvivesPostResolutionTicketTransfer() public {
        Raffle raffle = _createDefaultRaffle(1);
        _approveQuote(buyer, raffle);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);
        uint64 sequence = _request(raffle);

        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.InvalidState.selector, IRaffle.RaffleState.Active, IRaffle.RaffleState.DrawRequested
            )
        );
        raffle.transferFrom(buyer, buyerTwo, 1);

        entropy.fulfill(sequence, bytes32(0));
        assertEq(raffle.winner(), buyer);
        vm.prank(buyer);
        raffle.transferFrom(buyer, buyerTwo, 1);
        assertEq(raffle.ownerOf(1), buyerTwo);
        assertEq(raffle.winner(), buyer);
        assertEq(raffle.prizeClaimant(), buyer);
    }

    function testQuoteClaimsArePullBasedAndSingleUse() public {
        Raffle raffle = _createDefaultRaffle(100);
        _approveQuote(buyer, raffle);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 80);
        _resolve(raffle, bytes32(0));

        uint256 destinationBefore = quote.balanceOf(buyerTwo);
        vm.prank(buyer);
        uint256 amount = raffle.claimQuote(buyerTwo);
        assertEq(amount, 60_800_000);
        assertEq(quote.balanceOf(buyerTwo) - destinationBefore, amount);
        assertEq(raffle.claimableQuote(buyer), 0);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NoQuoteClaim.selector, buyer));
        raffle.claimQuote(buyer);

        uint256 treasuryBefore = quote.balanceOf(treasury);
        vm.prank(outsider);
        raffle.claimQuoteFor(treasury);
        assertEq(quote.balanceOf(treasury) - treasuryBefore, 4 * USDC);
    }

    function testQuoteDestinationTokenMetadataAndDirectNativeFailureBranches() public {
        Raffle raffle = _createDefaultRaffle(100);
        _approveQuote(buyer, raffle);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);

        vm.prank(outsider);
        vm.expectRevert(IRaffle.ZeroAddress.selector);
        raffle.claimQuote(address(0));

        assertEq(raffle.tokenURI(1), "ipfs://raffle");
        assertFalse(raffle.isThresholdMet());
        assertTrue(raffle.isOpen());
        assertFalse(raffle.canRequestDraw());

        vm.prank(outsider);
        (bool success, bytes memory reason) = address(raffle).call{ value: 1 }("");
        assertFalse(success);
        assertEq(bytes4(reason), Raffle.DirectNativeTransfer.selector);
    }

    function testExcessEntropyFeeUsesPullRefund() public {
        Raffle raffle = _createDefaultRaffle(1);
        _approveQuote(buyer, raffle);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);
        vm.warp(raffle.endTime());
        uint256 fee = raffle.getEntropyFee();

        vm.prank(outsider);
        raffle.requestDraw{ value: fee + 2 ether }();
        assertEq(raffle.claimableNative(outsider), 2 ether);

        uint256 beforeBalance = buyerTwo.balance;
        vm.prank(outsider);
        raffle.claimNative(payable(buyerTwo));
        assertEq(buyerTwo.balance - beforeBalance, 2 ether);
        assertEq(raffle.claimableNative(outsider), 0);
    }

    function testDirectQuoteDonationIsSurplusNotImplicitSettlement() public {
        Raffle raffle = _createDefaultRaffle(100);
        quote.mint(address(raffle), 7 * USDC);

        assertEq(raffle.accountedQuoteBalance(), 0);
        assertEq(raffle.unaccountedQuoteSurplus(), 7 * USDC);
        assertEq(uint256(raffle.state()), uint256(IRaffle.RaffleState.Active));
    }

    function testFeeOnTransferQuoteTokenIsRejected() public {
        FeeOnTransferERC20 feeToken = new FeeOnTransferERC20();
        Raffle feeImplementation = new Raffle();
        RaffleFactory feeFactory = new RaffleFactory(
            address(feeImplementation),
            _quoteTokens(address(feeToken)),
            address(entropy),
            treasury,
            CALLBACK_GAS_LIMIT,
            address(this)
        );

        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        prize.setApprovalForAll(address(feeFactory), true);
        vm.prank(sponsor);
        address raffleAddress = feeFactory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prize),
                prizeTokenId: tokenId,
                quoteToken: address(feeToken),
                ticketPrice: USDC,
                minimumTickets: 100,
                startTime: block.timestamp,
                endTime: block.timestamp + 1 days,
                metadataURI: "ipfs://raffle"
            })
        );

        feeToken.mint(buyer, 10 * USDC);
        vm.prank(buyer);
        feeToken.approve(raffleAddress, type(uint256).max);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsupportedQuoteToken.selector, USDC, 990_000));
        Raffle(payable(raffleAddress)).buyTickets(buyer, 1);
    }

    function testLensRejectsFakeRaffleAndReturnsLiveActionState() public {
        vm.expectRevert(abi.encodeWithSelector(IRaffleLens.UnregisteredRaffle.selector, outsider));
        lens.getRaffleState(outsider, buyer);

        Raffle raffle = _createDefaultRaffle(100);
        _approveQuote(buyer, raffle);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 2);

        IRaffleLens.RaffleView memory view_ = lens.getRaffleState(address(raffle), buyer);
        assertEq(view_.factoryId, raffle.raffleId());
        assertTrue(view_.registered);
        assertEq(view_.accountTicketBalance, 2);
        assertTrue(view_.canBuy);
        assertFalse(view_.canDraw);
    }

    function testLensConstructorAndBoundedBatchBranches() public {
        vm.expectRevert(abi.encodeWithSelector(IRaffleLens.InvalidFactory.selector, address(0)));
        new RaffleLens(address(0));
        vm.expectRevert(abi.encodeWithSelector(IRaffleLens.InvalidFactory.selector, outsider));
        new RaffleLens(outsider);

        address[] memory tooMany = new address[](101);
        vm.expectRevert(abi.encodeWithSelector(IRaffleLens.BatchTooLarge.selector, 101, 100));
        lens.getRaffleStates(tooMany, buyer);

        Raffle raffle = _createDefaultRaffle(100);
        address[] memory raffles = new address[](1);
        raffles[0] = address(raffle);
        IRaffleLens.RaffleView[] memory views = lens.getRaffleStates(raffles, address(0));
        assertEq(views.length, 1);
        assertEq(views[0].raffle, address(raffle));
        assertEq(views[0].accountTicketBalance, 0);
    }

    function testHighThresholdHasNoArbitraryCap() public {
        Raffle raffle = _createDefaultRaffle(type(uint256).max);
        assertEq(raffle.minimumTickets(), type(uint256).max);
    }

    function testOddsUseOneEighteenPrecision() public {
        Raffle raffle = _createDefaultRaffle(100);
        _approveQuote(buyer, raffle);
        _approveQuote(buyerTwo, raffle);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 3);
        vm.prank(buyerTwo);
        raffle.buyTickets(buyerTwo, 1);
        assertEq(raffle.oddsFor(buyer), 0.75e18);
        assertEq(raffle.oddsFor(buyerTwo), 0.25e18);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _createDefaultRaffle(uint256 minimumTickets) internal returns (Raffle raffle) {
        raffle = _createRaffle(nextPrizeId++, USDC, minimumTickets, block.timestamp, block.timestamp + 1 days);
    }

    function _createRaffle(uint256 tokenId, uint256 price, uint256 minimumTickets, uint256 start, uint256 end)
        internal
        returns (Raffle raffle)
    {
        prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        address raffleAddress = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prize),
                prizeTokenId: tokenId,
                quoteToken: address(quote),
                ticketPrice: price,
                minimumTickets: minimumTickets,
                startTime: start,
                endTime: end,
                metadataURI: "ipfs://raffle"
            })
        );
        raffle = Raffle(payable(raffleAddress));
    }

    function _validCreateParams(address prizeToken)
        internal
        view
        returns (IRaffleFactory.CreateRaffleParams memory params)
    {
        params = IRaffleFactory.CreateRaffleParams({
            prizeToken: prizeToken,
            prizeTokenId: nextPrizeId,
            quoteToken: address(quote),
            ticketPrice: USDC,
            minimumTickets: 1,
            startTime: block.timestamp,
            endTime: block.timestamp + 1 days,
            metadataURI: "ipfs://raffle"
        });
    }

    function _validInitializeParams(address raffleAddress)
        internal
        view
        returns (IRaffle.InitializeParams memory params)
    {
        params = IRaffle.InitializeParams({
            factory: address(this),
            sponsor: sponsor,
            protocolTreasury: treasury,
            quoteToken: address(quote),
            entropy: address(entropy),
            prizeToken: address(prize),
            prizeTokenId: nextPrizeId,
            raffleId: 999,
            ticketPrice: USDC,
            minimumTickets: 1,
            startTime: block.timestamp,
            endTime: block.timestamp + 1 days,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            name: "Coverage Ticket",
            symbol: "COV",
            metadataURI: string.concat("ipfs://raffle/", vm.toString(raffleAddress))
        });
    }

    function _approveQuote(address account, Raffle raffle) internal {
        vm.prank(account);
        quote.approve(address(raffle), type(uint256).max);
    }

    function _quoteTokens(address quoteToken_) internal pure returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = quoteToken_;
    }

    function _request(Raffle raffle) internal returns (uint64 sequence) {
        vm.warp(raffle.endTime());
        vm.prank(outsider);
        sequence = raffle.requestDraw{ value: raffle.getEntropyFee() }();
    }

    function _resolve(Raffle raffle, bytes32 randomNumber) internal {
        uint64 sequence = _request(raffle);
        entropy.fulfill(sequence, randomNumber);
    }
}
