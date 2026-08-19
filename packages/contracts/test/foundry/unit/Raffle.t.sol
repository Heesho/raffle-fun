// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";
import { MockVRFV2PlusWrapper } from "../../../src/mocks/MockVRFV2PlusWrapper.sol";

contract EighteenDecimalToken is ERC20 {
    constructor() ERC20("Wrong Decimals", "WRONG") { }
}

contract RevertingDecimalsToken {
    function decimals() external pure returns (uint8) {
        revert();
    }
}

contract NonERC721 {
    function supportsInterface(bytes4) external pure returns (bool) {
        return false;
    }
}

contract RejectReceiptReceiver { }

contract RevertingPrize is ERC721 {
    bool public transfersRevert;
    bool public transfersNoop;

    constructor() ERC721("Reverting Prize", "RPRIZE") { }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function setTransfersRevert(bool value) external {
        transfersRevert = value;
    }

    function setTransfersNoop(bool value) external {
        transfersNoop = value;
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (transfersRevert) revert("prize transfer failed");
        if (transfersNoop) return;
        super.transferFrom(from, to, tokenId);
    }
}

contract NoTransferPrize is ERC721 {
    constructor() ERC721("No Transfer Prize", "NO_TRANSFER") { }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function safeTransferFrom(address, address, uint256, bytes memory) public pure override { }
}

contract CallbackWithoutTransferPrize is ERC721 {
    constructor() ERC721("Callback Without Transfer", "FAKE_ESCROW") { }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        bytes4 selector = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data);
        require(selector == IERC721Receiver.onERC721Received.selector, "receiver rejected");
    }
}

contract CallbackSkippingPrize is ERC721 {
    constructor() ERC721("Callback Skipping Prize", "NO_CALLBACK") { }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory) public override {
        transferFrom(from, to, tokenId);
    }
}

contract RejectNativeRefund {
    function request(Raffle raffle) external payable {
        raffle.requestDraw{ value: msg.value }();
    }

    receive() external payable {
        revert("no native");
    }
}

contract RaffleTest is Test, IERC721Receiver {
    uint256 internal constant USDC = 1e6;
    uint32 internal constant CALLBACK_GAS_LIMIT = 300_000;
    uint16 internal constant REQUEST_CONFIRMATIONS = 30;

    address internal sponsor = makeAddr("sponsor");
    address internal buyer = makeAddr("buyer");
    address internal buyerTwo = makeAddr("buyerTwo");
    address internal treasury = makeAddr("treasury");
    address internal outsider = makeAddr("outsider");

    MockERC20 internal quote;
    MockERC721 internal prize;
    MockVRFV2PlusWrapper internal vrfWrapper;
    RaffleFactory internal factory;
    uint256 internal nextPrizeId = 1;

    function setUp() public {
        vm.warp(1_000_000);
        quote = new MockERC20();
        prize = new MockERC721();
        vrfWrapper = new MockVRFV2PlusWrapper();
        factory = new RaffleFactory(address(quote), address(vrfWrapper), treasury, address(this));

        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), true);
        quote.mint(buyer, 1_000_000 * USDC);
        quote.mint(buyerTwo, 1_000_000 * USDC);
        vm.deal(outsider, 100 ether);
    }

    function testFactoryAtomicallyEscrowsAndCapturesFixedConfiguration() public {
        Raffle raffle = _create(10);

        assertEq(factory.raffleCount(), 1);
        assertEq(factory.raffleById(1), address(raffle));
        assertEq(factory.idByRaffle(address(raffle)), 1);
        assertTrue(factory.isRaffle(address(raffle)));
        assertEq(address(factory.quoteToken()), address(quote));
        assertEq(factory.callbackGasLimit(), CALLBACK_GAS_LIMIT);
        assertEq(factory.requestConfirmations(), REQUEST_CONFIRMATIONS);

        assertEq(prize.ownerOf(raffle.prizeTokenId()), address(raffle));
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Active));
        assertEq(raffle.factory(), address(factory));
        assertEq(raffle.sponsor(), sponsor);
        assertEq(raffle.sponsorRecipient(), sponsor);
        assertEq(raffle.protocolTreasury(), treasury);
        assertEq(raffle.ENTRY_PRICE(), USDC);
        assertEq(raffle.requestConfirmations(), REQUEST_CONFIRMATIONS);
    }

    function testSponsorRecipientIsFixedForProceedsAndReturnedPrize() public {
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        IRaffleFactory.CreateRaffleParams memory params = IRaffleFactory.CreateRaffleParams({
            sponsorRecipient: buyerTwo,
            prizeToken: address(prize),
            prizeTokenId: tokenId,
            reserveEntries: 2,
            endTime: uint64(block.timestamp + 1 days)
        });
        vm.prank(sponsor);
        Raffle raffle = Raffle(payable(factory.createRaffle(params)));
        uint256 ticketId = _buy(raffle, buyer, 1);
        _resolve(raffle, 0);
        raffle.settleWinningTicket(ticketId);

        uint256 before = quote.balanceOf(buyerTwo);
        vm.prank(outsider);
        raffle.releaseSponsorProceeds();
        assertEq(quote.balanceOf(buyerTwo) - before, 150_000);

        vm.prank(outsider);
        raffle.releaseSponsorPrize();
        assertEq(prize.ownerOf(tokenId), buyerTwo);
        assertEq(raffle.sponsor(), sponsor);
        assertEq(raffle.sponsorRecipient(), buyerTwo);
    }

    function testFactoryCreatesCanonicalClonesWithIsolatedRangeState() public {
        Raffle first = _create(1);
        Raffle second = _create(2);
        address implementation = factory.raffleImplementation();
        bytes memory expectedRuntime =
            abi.encodePacked(hex"363d3d373d3d3d363d73", bytes20(implementation), hex"5af43d82803e903d91602b57fd5bf3");

        assertEq(address(first).code.length, 45);
        assertEq(address(first).code, expectedRuntime);
        assertEq(address(second).code, expectedRuntime);

        uint256 ticketId = _buy(first, buyer, 20);
        assertEq(ticketId, 1);
        _assertRange(first, ticketId, 1, 20);
        assertEq(first.totalEntries(), 20);
        assertEq(first.ticketCount(), 1);
        assertEq(second.totalEntries(), 0);
        assertEq(second.ticketCount(), 0);
    }

    function testImplementationAndCloneInitializationAreLocked() public {
        Raffle implementation = Raffle(payable(factory.raffleImplementation()));
        assertTrue(implementation.initialized());
        assertEq(uint256(implementation.status()), uint256(IRaffle.Status.Refunding));

        IRaffle.RaffleInitParams memory params = _directInitParams();
        vm.expectRevert(IRaffle.AlreadyInitialized.selector);
        implementation.initialize(params);

        Raffle unauthorized = Raffle(payable(Clones.clone(address(implementation))));
        vm.expectRevert(IRaffle.OnlyFactory.selector);
        unauthorized.initialize(params);

        vm.prank(address(factory));
        unauthorized.initialize(params);
        assertTrue(unauthorized.initialized());
        assertEq(uint256(unauthorized.status()), uint256(IRaffle.Status.AwaitingPrize));
        vm.prank(address(factory));
        vm.expectRevert(IRaffle.AlreadyInitialized.selector);
        unauthorized.initialize(params);
    }

    function testCloneInitializationRejectsZeroAndProtocolDestinations() public {
        Raffle clone = Raffle(payable(Clones.clone(factory.raffleImplementation())));
        IRaffle.RaffleInitParams memory params = _directInitParams();

        params.sponsor = address(0);
        _expectInitializationRevert(clone, params, IRaffle.ZeroAddress.selector);

        params = _directInitParams();
        params.sponsor = address(factory);
        _expectInitializationRevert(
            clone, params, abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(factory))
        );

        params = _directInitParams();
        params.sponsorRecipient = address(0);
        _expectInitializationRevert(clone, params, IRaffle.ZeroAddress.selector);

        params = _directInitParams();
        params.sponsorRecipient = address(quote);
        _expectInitializationRevert(
            clone, params, abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(quote))
        );

        params = _directInitParams();
        params.protocolTreasury = address(quote);
        _expectInitializationRevert(
            clone, params, abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(quote))
        );
    }

    function testCloneInitializationRejectsRegisteredRaffleSponsorAndTreasury() public {
        Raffle registeredRaffle = _create(1);
        Raffle clone = Raffle(payable(Clones.clone(factory.raffleImplementation())));
        IRaffle.RaffleInitParams memory params = _directInitParams();

        params.sponsor = address(registeredRaffle);
        _expectInitializationRevert(
            clone, params, abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(registeredRaffle))
        );

        params = _directInitParams();
        params.sponsorRecipient = address(registeredRaffle);
        _expectInitializationRevert(
            clone, params, abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(registeredRaffle))
        );

        params = _directInitParams();
        params.protocolTreasury = address(registeredRaffle);
        _expectInitializationRevert(
            clone, params, abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(registeredRaffle))
        );
    }

    function testFactoryConstructorAndCreationValidation() public {
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.NotContract.selector, address(0)));
        new RaffleFactory(address(0), address(vrfWrapper), treasury, address(this));
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.NotContract.selector, outsider));
        new RaffleFactory(outsider, address(vrfWrapper), treasury, address(this));
        vm.expectRevert(IRaffleFactory.ZeroAddress.selector);
        new RaffleFactory(address(quote), address(vrfWrapper), address(0), address(this));

        EighteenDecimalToken wrong = new EighteenDecimalToken();
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.InvalidQuoteTokenDecimals.selector, 18, 6));
        new RaffleFactory(address(wrong), address(vrfWrapper), treasury, address(this));

        RevertingDecimalsToken revertingDecimals = new RevertingDecimalsToken();
        vm.expectRevert(
            abi.encodeWithSelector(IRaffleFactory.UnsupportedQuoteToken.selector, address(revertingDecimals))
        );
        new RaffleFactory(address(revertingDecimals), address(vrfWrapper), treasury, address(this));

        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsafeProtocolDestination.selector, address(quote)));
        new RaffleFactory(address(quote), address(vrfWrapper), address(quote), address(this));

        IRaffleFactory.CreateRaffleParams memory params = _validParams(address(prize));
        params.sponsorRecipient = address(0);
        _expectCreateRevert(IRaffleFactory.ZeroAddress.selector, params);

        params = _validParams(address(prize));
        params.sponsorRecipient = address(factory);
        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsafeProtocolDestination.selector, address(factory)));
        factory.createRaffle(params);

        params = _validParams(address(prize));
        params.reserveEntries = 0;
        _expectCreateRevert(IRaffleFactory.ZeroReserveEntries.selector, params);

        params = _validParams(address(prize));
        params.endTime = uint64(block.timestamp);
        vm.prank(sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffleFactory.InvalidEndTime.selector, block.timestamp, block.timestamp)
        );
        factory.createRaffle(params);

        params = _validParams(address(prize));
        params.endTime = uint64(block.timestamp + 30 days + 1);
        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.SaleDurationTooLong.selector, 30 days + 1, 30 days));
        factory.createRaffle(params);

        NonERC721 nonErc721 = new NonERC721();
        params = _validParams(address(nonErc721));
        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsupportedPrizeToken.selector, address(nonErc721)));
        factory.createRaffle(params);

        params = _validParams(address(revertingDecimals));
        vm.prank(sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffleFactory.UnsupportedPrizeToken.selector, address(revertingDecimals))
        );
        factory.createRaffle(params);

        Raffle existing = _create(1);
        params = _validParams(address(existing));
        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsafeProtocolDestination.selector, address(existing)));
        factory.createRaffle(params);
    }

    function testFactoryAcceptsExactMaximumSaleDuration() public {
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        IRaffleFactory.CreateRaffleParams memory params = IRaffleFactory.CreateRaffleParams({
            sponsorRecipient: sponsor,
            prizeToken: address(prize),
            prizeTokenId: tokenId,
            reserveEntries: 1,
            endTime: uint64(block.timestamp + 30 days)
        });

        vm.prank(sponsor);
        Raffle raffle = Raffle(payable(factory.createRaffle(params)));

        assertEq(raffle.endTime(), block.timestamp + 30 days);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Active));
        assertEq(prize.ownerOf(tokenId), address(raffle));
    }

    function testFactoryRejectsPrizesThatDoNotEscrowAndActivateExactly() public {
        NoTransferPrize noTransfer = new NoTransferPrize();
        noTransfer.mint(sponsor, 1);
        vm.prank(sponsor);
        noTransfer.setApprovalForAll(address(factory), true);
        IRaffleFactory.CreateRaffleParams memory params = _validParams(address(noTransfer));
        params.prizeTokenId = 1;
        vm.prank(sponsor);
        vm.expectPartialRevert(IRaffleFactory.PrizeEscrowVerificationFailed.selector);
        factory.createRaffle(params);
        assertEq(noTransfer.ownerOf(1), sponsor);

        CallbackSkippingPrize noCallback = new CallbackSkippingPrize();
        noCallback.mint(sponsor, 1);
        vm.prank(sponsor);
        noCallback.setApprovalForAll(address(factory), true);
        params = _validParams(address(noCallback));
        params.prizeTokenId = 1;
        vm.prank(sponsor);
        vm.expectPartialRevert(IRaffleFactory.PrizeEscrowVerificationFailed.selector);
        factory.createRaffle(params);
        assertEq(noCallback.ownerOf(1), sponsor);

        CallbackWithoutTransferPrize fakeEscrow = new CallbackWithoutTransferPrize();
        fakeEscrow.mint(sponsor, 1);
        vm.prank(sponsor);
        fakeEscrow.setApprovalForAll(address(factory), true);
        params = _validParams(address(fakeEscrow));
        params.prizeTokenId = 1;
        vm.prank(sponsor);
        vm.expectPartialRevert(IRaffleFactory.PrizeEscrowVerificationFailed.selector);
        factory.createRaffle(params);
        assertEq(fakeEscrow.ownerOf(1), sponsor);
    }

    function testFactoryPauseAffectsOnlyFutureRaffles() public {
        Raffle existing = _create(1);
        factory.setCreationPaused(true);
        vm.prank(sponsor);
        vm.expectRevert(IRaffleFactory.CreationPaused.selector);
        factory.createRaffle(_validParams(address(prize)));

        _buy(existing, buyer, 1);
        assertEq(existing.totalEntries(), 1);
        vm.expectRevert(IRaffleFactory.OwnershipRenunciationDisabled.selector);
        factory.renounceOwnership();
    }

    function testPurchaseMintsOneSequentialTicketForAnyEntryCount() public {
        Raffle raffle = _create(100);
        _approve(buyer, raffle, type(uint256).max);

        vm.prank(buyer);
        uint256 firstTicket = raffle.buyEntries(buyer, 20);
        vm.prank(buyer);
        uint256 secondTicket = raffle.buyEntries(buyerTwo, 7);

        assertEq(firstTicket, 1);
        assertEq(secondTicket, 2);
        _assertRange(raffle, firstTicket, 1, 20);
        _assertRange(raffle, secondTicket, 21, 27);
        assertEq(raffle.balanceOf(buyer), 1);
        assertEq(raffle.balanceOf(buyerTwo), 1);
        assertEq(raffle.ticketCount(), 2);
        assertEq(raffle.totalEntries(), 27);
        assertEq(raffle.grossSales(), 27 * USDC);
        assertEq(raffle.unsettledPot(), 27 * USDC);
        assertEq(raffle.accountedQuoteBalance(), 27 * USDC);
    }

    function testPurchaseMaximumRangeAndOverflowAreAtomic() public {
        Raffle raffle = _create(type(uint128).max);
        uint256 amount = uint256(type(uint128).max) * USDC;
        quote.mint(buyer, amount);
        _approve(buyer, raffle, type(uint256).max);

        vm.prank(buyer);
        uint256 ticketId = raffle.buyEntries(buyer, type(uint128).max);
        assertEq(ticketId, 1);
        _assertRange(raffle, ticketId, 1, type(uint128).max);
        assertEq(raffle.totalEntries(), type(uint128).max);
        assertEq(raffle.ticketCount(), 1);

        uint256 buyerBefore = quote.balanceOf(buyer);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.TotalEntriesOverflow.selector, type(uint128).max, uint128(1)));
        raffle.buyEntries(buyer, 1);
        assertEq(quote.balanceOf(buyer), buyerBefore);
        assertEq(raffle.ticketCount(), 1);
    }

    function testPurchaseValidationAndReceiverRollbackAreAtomic() public {
        Raffle raffle = _create(10);
        _approve(buyer, raffle, type(uint256).max);

        vm.prank(buyer);
        vm.expectRevert(IRaffle.InvalidRecipient.selector);
        raffle.buyEntries(address(0), 1);
        vm.prank(buyer);
        vm.expectRevert(IRaffle.ZeroEntryCount.selector);
        raffle.buyEntries(buyer, 0);

        RejectReceiptReceiver rejecter = new RejectReceiptReceiver();
        uint256 buyerBefore = quote.balanceOf(buyer);
        vm.prank(buyer);
        vm.expectRevert();
        raffle.buyEntries(address(rejecter), 3);
        assertEq(quote.balanceOf(buyer), buyerBefore);
        assertEq(quote.balanceOf(address(raffle)), 0);
        assertEq(raffle.totalEntries(), 0);
        assertEq(raffle.ticketCount(), 0);
    }

    function testSaleEndsButTicketsStayTransferableUntilBurned() public {
        Raffle raffle = _create(2);
        uint256 firstTicket = _buy(raffle, buyer, 1);
        uint256 secondTicket = _buy(raffle, buyer, 1);

        vm.prank(buyer);
        raffle.transferFrom(buyer, buyerTwo, firstTicket);
        vm.prank(buyer);
        raffle.setApprovalForAll(outsider, true);

        vm.warp(raffle.endTime());
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.SaleEnded.selector, raffle.endTime(), block.timestamp));
        raffle.buyEntries(buyer, 1);

        vm.prank(buyerTwo);
        raffle.safeTransferFrom(buyerTwo, buyer, firstTicket);
        vm.prank(outsider);
        raffle.transferFrom(buyer, buyerTwo, secondTicket);

        uint256 requestId = _requestAtCurrentTime(raffle);
        vrfWrapper.fulfill(requestId, 0);
        vm.prank(buyer);
        raffle.transferFrom(buyer, buyerTwo, firstTicket);
        vm.prank(outsider);
        raffle.settleWinningTicket(firstTicket);
        vm.expectRevert();
        raffle.ownerOf(firstTicket);
    }

    function testDrawUsesFixedThirtyConfirmationsAndOneWord() public {
        Raffle raffle = _create(1);
        _buy(raffle, buyer, 1);

        vm.expectRevert(abi.encodeWithSelector(IRaffle.RaffleNotEnded.selector, raffle.endTime(), block.timestamp));
        raffle.requestDraw();

        uint256 requestId = _request(raffle);
        assertEq(vrfWrapper.gasLimitByRequest(requestId), CALLBACK_GAS_LIMIT);
        assertEq(vrfWrapper.confirmationsByRequest(requestId), REQUEST_CONFIRMATIONS);
        assertEq(vrfWrapper.wordCountByRequest(requestId), 1);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.Drawing));
    }

    function testMetadataPriceEstimateAndDrawFailureBoundaries() public {
        Raffle empty = _create(1);
        assertEq(empty.name(), "raffle.fun Ticket");
        assertEq(empty.symbol(), "RAFFLE");
        assertEq(empty.estimateVrfRequestPrice(37 gwei), vrfWrapper.fee());

        vm.warp(empty.endTime());
        vm.expectRevert(IRaffle.NoEntriesSold.selector);
        empty.requestDraw();
        vm.warp(empty.drawRequestDeadline());
        vm.expectRevert(IRaffle.NoEntriesSold.selector);
        empty.requestDraw();

        Raffle delayed = _create(1);
        _buy(delayed, buyer, 1);
        assertEq(delayed.drawRequestDeadline(), delayed.endTime() + 2 days);
        vm.warp(delayed.drawRequestDeadline());
        uint256 delayedFee = vrfWrapper.fee();
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.DrawRequestWindowExpired.selector, delayed.drawRequestDeadline(), block.timestamp
            )
        );
        delayed.requestDraw{ value: delayedFee }();
        assertEq(delayed.vrfRequestId(), 0);
        assertEq(uint256(delayed.status()), uint256(IRaffle.Status.Active));
        vm.warp(delayed.drawRequestDeadline() + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.DrawRequestWindowExpired.selector, delayed.drawRequestDeadline(), block.timestamp
            )
        );
        delayed.requestDraw{ value: delayedFee }();

        Raffle underfunded = _create(1);
        _buy(underfunded, buyer, 1);
        vm.warp(underfunded.endTime());
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InsufficientVrfFee.selector, vrfWrapper.fee(), 0));
        underfunded.requestDraw();
    }

    function testDrawForwardsExactDynamicFeeAndRefundsExcess() public {
        Raffle raffle = _create(1);
        _buy(raffle, buyer, 1);
        vm.warp(raffle.endTime());
        vrfWrapper.setFee(0.02 ether);

        uint256 beforeBalance = outsider.balance;
        vm.prank(outsider);
        raffle.requestDraw{ value: 0.03 ether }();
        assertEq(outsider.balance, beforeBalance - 0.02 ether);

        Raffle rejectRaffle = _create(1);
        _buy(rejectRaffle, buyer, 1);
        vm.warp(rejectRaffle.endTime());
        RejectNativeRefund rejecter = new RejectNativeRefund();
        vm.deal(address(rejecter), 0.03 ether);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NativeRefundFailed.selector, address(rejecter), 0.01 ether));
        rejecter.request{ value: 0.03 ether }(rejectRaffle);
        assertEq(uint256(rejectRaffle.status()), uint256(IRaffle.Status.Active));
    }

    function testCallbackStoresInclusiveWinningEntryAndSelectsReserveBoundary() public {
        Raffle cash = _create(11);
        _buy(cash, buyer, 10);
        _resolve(cash, type(uint256).max);
        assertEq(cash.winningEntry(), uint128((type(uint256).max % 10) + 1));
        assertEq(uint256(cash.status()), uint256(IRaffle.Status.CashWon));
        assertEq(cash.unsettledPot(), 10 * USDC);
        assertEq(cash.protocolFees(), 0);
        assertEq(cash.sponsorProceeds(), 0);

        Raffle nft = _create(10);
        _buy(nft, buyer, 10);
        _resolve(nft, 9);
        assertEq(nft.winningEntry(), 10);
        assertEq(uint256(nft.status()), uint256(IRaffle.Status.NftWon));
        assertEq(nft.unsettledPot(), 10 * USDC);
        assertEq(nft.protocolFees(), 0);
        assertEq(nft.sponsorProceeds(), 0);
    }

    function testNftSettlementIsPermissionlessToCurrentTicketOwnerAndProofIsExact() public {
        Raffle raffle = _create(6);
        uint256 firstReceipt = _buy(raffle, buyer, 2);
        uint256 winningReceipt = _buy(raffle, buyerTwo, 4);
        _resolve(raffle, 2);
        assertEq(raffle.winningEntry(), 3);

        vm.prank(outsider);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffle.TicketDoesNotContainWinningEntry.selector, firstReceipt, uint128(3))
        );
        raffle.settleWinningTicket(firstReceipt);

        vm.prank(outsider);
        raffle.settleWinningTicket(winningReceipt);
        assertEq(prize.ownerOf(raffle.prizeTokenId()), address(raffle));
        assertEq(raffle.winnerRecipient(), buyerTwo);
        assertFalse(raffle.prizeClaimed());
        assertEq(raffle.winningTicketId(), winningReceipt);
        assertEq(raffle.protocolFees(), 300_000);
        assertEq(raffle.sponsorProceeds(), 5_700_000);
        assertEq(raffle.unsettledPot(), 0);

        vm.prank(outsider);
        raffle.releaseWinnerPrize();
        assertEq(prize.ownerOf(raffle.prizeTokenId()), buyerTwo);
        assertTrue(raffle.prizeClaimed());
    }

    function testNftSettlementSnapshotsCurrentTicketOwnerBeforeRelease() public {
        Raffle raffle = _create(1);
        uint256 receiptId = _buy(raffle, buyer, 1);
        _resolve(raffle, 0);

        vm.prank(buyer);
        raffle.transferFrom(buyer, buyerTwo, receiptId);
        vm.prank(outsider);
        raffle.settleWinningTicket(receiptId);
        assertEq(raffle.winnerRecipient(), buyerTwo);
        assertEq(prize.ownerOf(raffle.prizeTokenId()), address(raffle));
        vm.prank(outsider);
        raffle.releaseWinnerPrize();
        assertEq(prize.ownerOf(raffle.prizeTokenId()), buyerTwo);
    }

    function testPrizeDeliveryFailureBlocksOnlyWinnerPrizeAndNotSettlementOrCashClaims() public {
        RevertingPrize hostilePrize = new RevertingPrize();
        hostilePrize.mint(sponsor, 1);
        vm.prank(sponsor);
        hostilePrize.setApprovalForAll(address(factory), true);
        Raffle raffle = _createWithPrize(address(hostilePrize), 1, 1);
        uint256 receiptId = _buy(raffle, buyer, 1);
        _resolve(raffle, 0);
        hostilePrize.setTransfersRevert(true);

        vm.prank(outsider);
        raffle.settleWinningTicket(receiptId);
        vm.expectRevert();
        raffle.ownerOf(receiptId);
        assertEq(raffle.unsettledPot(), 0);
        assertEq(raffle.protocolFees(), 50_000);
        assertEq(raffle.sponsorProceeds(), 950_000);
        assertFalse(raffle.prizeClaimed());

        vm.expectRevert("prize transfer failed");
        raffle.releaseWinnerPrize();
        assertEq(raffle.protocolFees(), 50_000);
        assertEq(raffle.sponsorProceeds(), 950_000);

        uint256 sponsorBefore = quote.balanceOf(sponsor);
        uint256 treasuryBefore = quote.balanceOf(treasury);
        raffle.releaseSponsorProceeds();
        raffle.releaseProtocolFees();
        assertEq(quote.balanceOf(sponsor) - sponsorBefore, 950_000);
        assertEq(quote.balanceOf(treasury) - treasuryBefore, 50_000);

        vm.warp(block.timestamp + 365 days);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.NftWon));
        raffle.enableRefunds();

        hostilePrize.setTransfersRevert(false);
        raffle.releaseWinnerPrize();
        assertEq(hostilePrize.ownerOf(1), buyer);
    }

    function testNonCompliantPrizeCannotPassPostDeliveryVerification() public {
        RevertingPrize hostileNft = new RevertingPrize();
        hostileNft.mint(sponsor, 1);
        vm.prank(sponsor);
        hostileNft.setApprovalForAll(address(factory), true);
        Raffle nft = _createWithPrize(address(hostileNft), 1, 1);
        uint256 receiptId = _buy(nft, buyer, 1);
        _resolve(nft, 0);
        hostileNft.setTransfersNoop(true);

        vm.prank(outsider);
        nft.settleWinningTicket(receiptId);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.PrizeDeliveryVerificationFailed.selector, buyer));
        nft.releaseWinnerPrize();
        assertEq(hostileNft.ownerOf(1), address(nft));

        RevertingPrize hostileCash = new RevertingPrize();
        hostileCash.mint(sponsor, 2);
        vm.prank(sponsor);
        hostileCash.setApprovalForAll(address(factory), true);
        Raffle cash = _createWithPrize(address(hostileCash), 2, 2);
        _buy(cash, buyer, 1);
        _resolve(cash, 0);
        hostileCash.setTransfersNoop(true);

        vm.expectRevert(abi.encodeWithSelector(IRaffle.PrizeDeliveryVerificationFailed.selector, sponsor));
        cash.releaseSponsorPrize();
        assertEq(hostileCash.ownerOf(2), address(cash));
    }

    function testCashSettlementSnapshotsCurrentOwnerAndReleasesOnce() public {
        Raffle raffle = _create(2);
        uint256 receiptId = _buy(raffle, buyer, 1);
        _resolve(raffle, 0);

        assertEq(raffle.unsettledPot(), USDC);
        assertEq(raffle.protocolFees(), 0);
        assertEq(raffle.sponsorProceeds(), 0);
        vm.warp(block.timestamp + 365 days);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.CashWon));
        raffle.enableRefunds();

        uint256 before = quote.balanceOf(buyer);
        vm.prank(outsider);
        assertEq(raffle.settleWinningTicket(receiptId), 800_000);
        assertEq(quote.balanceOf(buyer) - before, 0);
        assertEq(raffle.winnerRecipient(), buyer);
        assertEq(raffle.winnerProceeds(), 800_000);
        assertEq(raffle.protocolFees(), 50_000);
        assertEq(raffle.sponsorProceeds(), 150_000);
        vm.expectRevert();
        raffle.ownerOf(receiptId);

        vm.prank(outsider);
        assertEq(raffle.releaseWinnerProceeds(), 800_000);
        assertEq(quote.balanceOf(buyer) - before, 800_000);
        assertEq(raffle.winnerProceeds(), 0);
        vm.expectRevert(IRaffle.NoWinnerProceeds.selector);
        raffle.releaseWinnerProceeds();

        Raffle transferred = _create(2);
        uint256 transferredReceipt = _buy(transferred, buyer, 1);
        _resolve(transferred, 0);
        vm.prank(buyer);
        transferred.transferFrom(buyer, buyerTwo, transferredReceipt);
        before = quote.balanceOf(buyerTwo);
        vm.prank(outsider);
        transferred.settleWinningTicket(transferredReceipt);
        assertEq(transferred.winnerRecipient(), buyerTwo);
        assertEq(quote.balanceOf(buyerTwo) - before, 0);
        vm.prank(outsider);
        transferred.releaseWinnerProceeds();
        assertEq(quote.balanceOf(buyerTwo) - before, 800_000);
    }

    function testCashSponsorPrizeRecoveryIsPermissionlessToFixedRecipient() public {
        Raffle unavailable = _create(1);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.SponsorPrizeUnavailable.selector, IRaffle.Status.Active));
        unavailable.releaseSponsorPrize();

        Raffle raffle = _create(2);
        _buy(raffle, buyer, 1);
        _resolve(raffle, 0);

        vm.prank(outsider);
        raffle.releaseSponsorPrize();
        assertEq(prize.ownerOf(raffle.prizeTokenId()), sponsor);
        assertEq(raffle.unsettledPot(), USDC);
        assertEq(raffle.sponsorProceeds(), 0);
        vm.expectRevert(IRaffle.PrizeAlreadyClaimed.selector);
        raffle.releaseSponsorPrize();
    }

    function testRegisteredRaffleCannotReceiveTicketsAndSettlementCannotBeRedirected() public {
        Raffle registeredDestination = _create(1);
        Raffle nftRaffle = _create(1);
        uint256 nftReceipt = _buy(nftRaffle, buyer, 1);

        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(registeredDestination))
        );
        nftRaffle.transferFrom(buyer, address(registeredDestination), nftReceipt);

        _resolve(nftRaffle, 0);
        vm.prank(outsider);
        nftRaffle.settleWinningTicket(nftReceipt);
        vm.prank(outsider);
        nftRaffle.releaseWinnerPrize();
        assertEq(prize.ownerOf(nftRaffle.prizeTokenId()), buyer);

        Raffle cashRaffle = _create(2);
        uint256 cashReceipt = _buy(cashRaffle, buyer, 1);
        _resolve(cashRaffle, 0);
        vm.prank(outsider);
        cashRaffle.settleWinningTicket(cashReceipt);
        vm.prank(outsider);
        cashRaffle.releaseSponsorPrize();
        assertEq(prize.ownerOf(cashRaffle.prizeTokenId()), sponsor);
    }

    function testFutureCanonicalCloneCanBrickOnlyItsOwnWinnerClaim() public {
        Raffle cash = _create(2);
        uint256 ticketId = _buy(cash, buyer, 1);
        _resolve(cash, 0);

        address futureClone = vm.computeCreateAddress(address(factory), factory.raffleCount() + 2);
        assertEq(futureClone.code.length, 0);
        assertFalse(factory.isRaffle(futureClone));

        vm.prank(buyer);
        cash.transferFrom(buyer, futureClone, ticketId);
        Raffle materializedClone = _create(1);
        assertEq(address(materializedClone), futureClone);
        assertTrue(factory.isRaffle(futureClone));

        cash.settleWinningTicket(ticketId);
        assertEq(cash.winnerRecipient(), futureClone);
        assertEq(cash.winnerProceeds(), 800_000);
        assertEq(cash.sponsorProceeds(), 150_000);
        assertEq(cash.protocolFees(), 50_000);
        assertEq(cash.accountedQuoteBalance(), USDC);

        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuoteDestination.selector, futureClone));
        cash.releaseWinnerProceeds();
        assertEq(cash.winnerProceeds(), 800_000);

        uint256 sponsorBefore = quote.balanceOf(sponsor);
        uint256 treasuryBefore = quote.balanceOf(treasury);
        cash.releaseSponsorProceeds();
        cash.releaseProtocolFees();
        assertEq(quote.balanceOf(sponsor) - sponsorBefore, 150_000);
        assertEq(quote.balanceOf(treasury) - treasuryBefore, 50_000);
        assertEq(cash.accountedQuoteBalance(), 800_000);
    }

    function testFixedProceedsArePermissionlesslyReleasedToConfiguredRecipients() public {
        Raffle cash = _create(2);
        uint256 ticketId = _buy(cash, buyer, 1);
        _resolve(cash, 0);
        cash.settleWinningTicket(ticketId);

        uint256 sponsorBefore = quote.balanceOf(sponsor);
        uint256 treasuryBefore = quote.balanceOf(treasury);
        uint256 winnerBefore = quote.balanceOf(buyer);
        vm.prank(outsider);
        assertEq(cash.releaseWinnerProceeds(), 800_000);
        vm.prank(outsider);
        assertEq(cash.releaseSponsorProceeds(), 150_000);
        vm.prank(outsider);
        assertEq(cash.releaseProtocolFees(), 50_000);
        assertEq(quote.balanceOf(buyer) - winnerBefore, 800_000);
        assertEq(quote.balanceOf(sponsor) - sponsorBefore, 150_000);
        assertEq(quote.balanceOf(treasury) - treasuryBefore, 50_000);
        vm.expectRevert(IRaffle.NoWinnerProceeds.selector);
        cash.releaseWinnerProceeds();
        vm.expectRevert(IRaffle.NoSponsorProceeds.selector);
        cash.releaseSponsorProceeds();
        vm.expectRevert(IRaffle.NoProtocolFees.selector);
        cash.releaseProtocolFees();

        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.CashWon));
        cash.buyEntries(buyer, 1);

        uint256 cashPrizeId = cash.prizeTokenId();
        vm.expectPartialRevert(IRaffle.UnexpectedPrize.selector);
        cash.onERC721Received(address(factory), sponsor, cashPrizeId, "");
    }

    function testSoldRaffleHasHardRequestAndCallbackRefundDeadlines() public {
        Raffle noRequest = _create(10);
        uint256 noRequestReceipt = _buy(noRequest, buyer, 3);
        uint256 requestDeadline = noRequest.drawRequestDeadline();
        vm.warp(requestDeadline - 1);
        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.RefundsNotAvailable.selector, requestDeadline, block.timestamp));
        noRequest.enableRefunds();
        vm.warp(requestDeadline);
        uint256 requestFee = vrfWrapper.fee();
        vm.expectRevert(
            abi.encodeWithSelector(IRaffle.DrawRequestWindowExpired.selector, requestDeadline, block.timestamp)
        );
        noRequest.requestDraw{ value: requestFee }();
        noRequest.enableRefunds();
        assertEq(uint256(noRequest.status()), uint256(IRaffle.Status.Refunding));
        assertEq(noRequest.unsettledPot(), 0);
        assertEq(noRequest.remainingRefundLiability(), 3 * USDC);
        assertEq(noRequest.winnerProceeds(), 0);
        assertEq(noRequest.sponsorProceeds(), 0);
        assertEq(noRequest.protocolFees(), 0);
        vm.prank(outsider);
        noRequest.releaseSponsorPrize();
        assertEq(prize.ownerOf(noRequest.prizeTokenId()), sponsor);
        vm.prank(buyer);
        noRequest.refundTickets(_single(noRequestReceipt));

        Raffle lastMomentRequest = _create(10);
        _buy(lastMomentRequest, buyer, 3);
        vm.warp(lastMomentRequest.drawRequestDeadline() - 1);
        uint256 lastMomentSequence = _requestAtCurrentTime(lastMomentRequest);
        assertEq(lastMomentRequest.drawRequestedAt(), lastMomentRequest.drawRequestDeadline() - 1);
        assertEq(lastMomentRequest.callbackDeadline(), block.timestamp + 2 days);
        vm.warp(lastMomentRequest.drawRequestDeadline());
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.RefundsNotAvailable.selector, lastMomentRequest.callbackDeadline(), block.timestamp
            )
        );
        lastMomentRequest.enableRefunds();
        vm.warp(lastMomentRequest.callbackDeadline() - 1);
        vrfWrapper.fulfill(lastMomentSequence, 0);
        assertEq(uint256(lastMomentRequest.status()), uint256(IRaffle.Status.CashWon));

        Raffle noCallback = _create(10);
        uint256 noCallbackReceipt = _buy(noCallback, buyer, 5);
        uint256 sequence = _request(noCallback);
        vm.warp(noCallback.callbackDeadline());
        noCallback.enableRefunds();
        vrfWrapper.fulfill(sequence, 0);
        assertEq(uint256(noCallback.status()), uint256(IRaffle.Status.Refunding));
        assertEq(noCallback.winningEntry(), 0);
        assertEq(noCallback.remainingRefundLiability(), 5 * USDC);
        vm.prank(buyer);
        noCallback.refundTickets(_single(noCallbackReceipt));
    }

    function testAcceptedDrawCannotRefundBeforeCallbackDeadlineAndValidNftOutcomeNeverRefunds() public {
        Raffle drawing = _create(1);
        _buy(drawing, buyer, 1);
        _request(drawing);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffle.RefundsNotAvailable.selector, drawing.callbackDeadline(), block.timestamp)
        );
        drawing.enableRefunds();

        Raffle nftWon = _create(1);
        _buy(nftWon, buyer, 1);
        _resolve(nftWon, 0);
        vm.warp(block.timestamp + 365 days);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.NftWon));
        nftWon.enableRefunds();
    }

    function testCallbackDeadlineIsHardAtEqualityRegardlessOfOrdering() public {
        Raffle callbackBeforeDeadline = _create(1);
        _buy(callbackBeforeDeadline, buyer, 1);
        uint256 beforeDeadlineSequence = _request(callbackBeforeDeadline);
        vm.warp(callbackBeforeDeadline.callbackDeadline() - 1);
        vrfWrapper.fulfill(beforeDeadlineSequence, 0);
        assertEq(uint256(callbackBeforeDeadline.status()), uint256(IRaffle.Status.NftWon));

        Raffle callbackAtDeadline = _create(1);
        _buy(callbackAtDeadline, buyer, 1);
        uint256 atDeadlineSequence = _request(callbackAtDeadline);
        vm.warp(callbackAtDeadline.callbackDeadline());
        vrfWrapper.fulfill(atDeadlineSequence, 0);
        assertEq(uint256(callbackAtDeadline.status()), uint256(IRaffle.Status.Drawing));
        assertEq(callbackAtDeadline.winningEntry(), 0);
        vm.warp(callbackAtDeadline.callbackDeadline() + 1);
        vrfWrapper.fulfill(atDeadlineSequence, 0);
        assertEq(uint256(callbackAtDeadline.status()), uint256(IRaffle.Status.Drawing));
        assertEq(callbackAtDeadline.winningEntry(), 0);
        callbackAtDeadline.enableRefunds();
        assertEq(uint256(callbackAtDeadline.status()), uint256(IRaffle.Status.Refunding));

        Raffle refundFirst = _create(1);
        _buy(refundFirst, buyer, 1);
        uint256 secondSequence = _request(refundFirst);
        vm.warp(refundFirst.callbackDeadline());
        refundFirst.enableRefunds();
        vrfWrapper.fulfill(secondSequence, 0);
        assertEq(refundFirst.winningEntry(), 0);
        assertEq(uint256(refundFirst.status()), uint256(IRaffle.Status.Refunding));
    }

    function testWeightedRefundBatchPaysExactRangesAndConsumesOnce() public {
        Raffle raffle = _create(100);
        uint256 first = _buy(raffle, buyer, 2);
        uint256 second = _buy(raffle, buyer, 7);
        _request(raffle);
        vm.warp(raffle.callbackDeadline());
        raffle.enableRefunds();

        uint256[] memory ids = new uint256[](2);
        ids[0] = first;
        ids[1] = second;
        uint256 before = quote.balanceOf(buyer);
        vm.prank(buyer);
        assertEq(raffle.refundTickets(ids), 9 * USDC);
        assertEq(quote.balanceOf(buyer) - before, 9 * USDC);
        assertEq(raffle.remainingRefundLiability(), 0);
        assertEq(raffle.balanceOf(buyer), 0);
        vm.expectRevert();
        raffle.ownerOf(first);
        vm.expectRevert();
        raffle.ownerOf(second);
        vm.prank(buyer);
        vm.expectRevert();
        raffle.refundTickets(ids);
    }

    function testRefundBatchValidationAndMixedOwnershipAreAtomic() public {
        Raffle raffle = _create(100);
        uint256 first = _buy(raffle, buyer, 2);
        uint256 second = _buy(raffle, buyerTwo, 3);
        _request(raffle);
        vm.warp(raffle.callbackDeadline());
        raffle.enableRefunds();

        uint256[] memory empty = new uint256[](0);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidTicketBatchSize.selector, 0, 100));
        raffle.refundTickets(empty);

        uint256[] memory oversized = new uint256[](101);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidTicketBatchSize.selector, 101, 100));
        raffle.refundTickets(oversized);

        uint256[] memory mixed = new uint256[](2);
        mixed[0] = first;
        mixed[1] = second;
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NotTicketOwner.selector, second, buyer, buyerTwo));
        raffle.refundTickets(mixed);
        assertEq(raffle.ownerOf(first), buyer);
        assertEq(raffle.ownerOf(second), buyerTwo);
        assertEq(raffle.remainingRefundLiability(), 5 * USDC);
    }

    function testEmptyRaffleUsesRefundingWithoutClosedState() public {
        Raffle sponsorCancelled = _create(1);
        vm.prank(sponsor);
        sponsorCancelled.enableRefunds();
        assertEq(uint256(sponsorCancelled.status()), uint256(IRaffle.Status.Refunding));
        assertEq(sponsorCancelled.remainingRefundLiability(), 0);
        vm.prank(outsider);
        sponsorCancelled.releaseSponsorPrize();

        Raffle anyoneAfterEnd = _create(1);
        vm.prank(outsider);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffle.RefundsNotAvailable.selector, anyoneAfterEnd.endTime(), block.timestamp)
        );
        anyoneAfterEnd.enableRefunds();
        vm.warp(anyoneAfterEnd.endTime());
        vm.prank(outsider);
        anyoneAfterEnd.enableRefunds();
        vm.prank(outsider);
        anyoneAfterEnd.releaseSponsorPrize();
    }

    function testWrongDuplicateMalformedAndUnauthorizedCallbacksAreHarmless() public {
        Raffle raffle = _create(2);
        _buy(raffle, buyer, 2);
        uint256 sequence = _request(raffle);

        uint256[] memory words = new uint256[](1);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffle.OnlyVRFWrapperCanFulfill.selector, address(this), address(vrfWrapper))
        );
        raffle.rawFulfillRandomWords(sequence, words);

        vrfWrapper.fulfillAs(sequence, sequence + 1, 99);
        assertEq(raffle.winningEntry(), 0);
        vrfWrapper.fulfill(sequence, 0);
        assertEq(raffle.winningEntry(), 1);
        vrfWrapper.fulfill(sequence, 1);
        assertEq(raffle.winningEntry(), 1);
    }

    function testDonationsAndForcedNativeDoNotAlterQuoteAccounting() public {
        Raffle raffle = _create(1);
        _buy(raffle, buyer, 1);
        quote.mint(address(raffle), 5 * USDC);
        assertEq(raffle.accountedQuoteBalance(), USDC);
        assertEq(quote.balanceOf(address(raffle)), 6 * USDC);

        vm.deal(outsider, 1);
        vm.prank(outsider);
        (bool success,) = address(raffle).call{ value: 1 }("");
        assertFalse(success);
        assertEq(raffle.accountedQuoteBalance(), USDC);
    }

    function testBothCallbackBranchesStayBelowGasBudget() public {
        Raffle nft = _create(1);
        _buy(nft, buyer, 1);
        _resolve(nft, 0);
        uint256 nftGas = vrfWrapper.lastCallbackGasUsed();

        Raffle cash = _create(2);
        _buy(cash, buyer, 1);
        _resolve(cash, 0);
        uint256 cashGas = vrfWrapper.lastCallbackGasUsed();

        emit log_named_uint("NFT callback gas", nftGas);
        emit log_named_uint("cash callback gas", cashGas);
        assertLt(nftGas, uint256(CALLBACK_GAS_LIMIT) * 80 / 100);
        assertLt(cashGas, uint256(CALLBACK_GAS_LIMIT) * 80 / 100);
    }

    function testCallbackGasDoesNotScaleWithReceiptCount() public {
        Raffle oneReceipt = _create(100);
        Raffle oneHundredReceipts = _create(100);
        _approve(buyer, oneReceipt, type(uint256).max);
        _approve(buyer, oneHundredReceipts, type(uint256).max);

        vm.prank(buyer);
        oneReceipt.buyEntries(buyer, 100);
        for (uint256 index; index < 100; ++index) {
            vm.prank(buyer);
            oneHundredReceipts.buyEntries(buyer, 1);
        }

        _resolve(oneReceipt, 99);
        uint256 oneReceiptGas = vrfWrapper.lastCallbackGasUsed();
        _resolve(oneHundredReceipts, 99);
        uint256 oneHundredReceiptGas = vrfWrapper.lastCallbackGasUsed();

        assertEq(oneReceipt.winningEntry(), oneHundredReceipts.winningEntry());
        assertLt(_absoluteDifference(oneReceiptGas, oneHundredReceiptGas), 5000);
    }

    function testPurchaseAndRefundGasDoNotScaleWithEntriesInsideReceipt() public {
        Raffle small = _create(type(uint128).max);
        Raffle large = _create(type(uint128).max);
        uint128 largeCount = 1_000_000_000;
        quote.mint(buyer, uint256(largeCount) * USDC);
        _approve(buyer, small, type(uint256).max);
        _approve(buyer, large, type(uint256).max);

        vm.prank(buyer);
        uint256 gasBefore = gasleft();
        uint256 smallId = small.buyEntries(buyer, 1);
        uint256 smallGas = gasBefore - gasleft();
        vm.prank(buyer);
        gasBefore = gasleft();
        uint256 largeId = large.buyEntries(buyer, largeCount);
        uint256 largeGas = gasBefore - gasleft();

        assertLt(smallGas, 300_000);
        assertLt(largeGas, 300_000);
        assertLt(_absoluteDifference(smallGas, largeGas), 30_000);

        _request(small);
        _request(large);
        vm.warp(small.callbackDeadline());
        small.enableRefunds();
        large.enableRefunds();
        vm.prank(buyer);
        gasBefore = gasleft();
        small.refundTickets(_single(smallId));
        smallGas = gasBefore - gasleft();
        vm.prank(buyer);
        gasBefore = gasleft();
        large.refundTickets(_single(largeId));
        largeGas = gasBefore - gasleft();
        assertLt(_absoluteDifference(smallGas, largeGas), 20_000);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _create(uint128 reserveEntries) internal returns (Raffle raffle) {
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        raffle = _createWithPrize(address(prize), tokenId, reserveEntries);
    }

    function _createWithPrize(address prizeToken, uint256 tokenId, uint128 reserveEntries)
        internal
        returns (Raffle raffle)
    {
        IRaffleFactory.CreateRaffleParams memory params = IRaffleFactory.CreateRaffleParams({
            sponsorRecipient: sponsor,
            prizeToken: prizeToken,
            prizeTokenId: tokenId,
            reserveEntries: reserveEntries,
            endTime: uint64(block.timestamp + 1 days)
        });
        vm.prank(sponsor);
        raffle = Raffle(payable(factory.createRaffle(params)));
    }

    function _validParams(address prizeToken) internal view returns (IRaffleFactory.CreateRaffleParams memory params) {
        params = IRaffleFactory.CreateRaffleParams({
            sponsorRecipient: sponsor,
            prizeToken: prizeToken,
            prizeTokenId: nextPrizeId,
            reserveEntries: 100,
            endTime: uint64(block.timestamp + 1 days)
        });
    }

    function _directInitParams() internal view returns (IRaffle.RaffleInitParams memory params) {
        params = IRaffle.RaffleInitParams({
            sponsor: sponsor,
            sponsorRecipient: sponsor,
            protocolTreasury: treasury,
            prizeToken: address(prize),
            prizeTokenId: 1,
            raffleId: 1,
            reserveEntries: 1,
            endTime: uint64(block.timestamp + 1 days)
        });
    }

    function _expectCreateRevert(bytes4 selector, IRaffleFactory.CreateRaffleParams memory params) internal {
        vm.prank(sponsor);
        vm.expectRevert(selector);
        factory.createRaffle(params);
    }

    function _expectInitializationRevert(Raffle raffle, IRaffle.RaffleInitParams memory params, bytes4 selector)
        internal
    {
        vm.prank(address(factory));
        vm.expectRevert(selector);
        raffle.initialize(params);
    }

    function _expectInitializationRevert(Raffle raffle, IRaffle.RaffleInitParams memory params, bytes memory reason)
        internal
    {
        vm.prank(address(factory));
        vm.expectRevert(reason);
        raffle.initialize(params);
    }

    function _approve(address account, Raffle raffle, uint256 amount) internal {
        vm.prank(account);
        quote.approve(address(raffle), amount);
    }

    function _buy(Raffle raffle, address account, uint128 entries) internal returns (uint256 receiptId) {
        _approve(account, raffle, type(uint256).max);
        vm.prank(account);
        receiptId = raffle.buyEntries(account, entries);
    }

    function _request(Raffle raffle) internal returns (uint256 requestId) {
        vm.warp(raffle.endTime());
        requestId = _requestAtCurrentTime(raffle);
    }

    function _requestAtCurrentTime(Raffle raffle) internal returns (uint256 requestId) {
        vm.prank(outsider);
        requestId = raffle.requestDraw{ value: raffle.getVrfRequestPrice() }();
    }

    function _resolve(Raffle raffle, uint256 randomWord) internal {
        uint256 requestId = _request(raffle);
        vrfWrapper.fulfill(requestId, randomWord);
    }

    function _assertRange(Raffle raffle, uint256 ticketId, uint128 first, uint128 last) internal view {
        (uint128 actualFirst, uint128 actualLast) = raffle.ticketRange(ticketId);
        assertEq(actualFirst, first);
        assertEq(actualLast, last);
    }

    function _single(uint256 receiptId) internal pure returns (uint256[] memory ids) {
        ids = new uint256[](1);
        ids[0] = receiptId;
    }

    function _absoluteDifference(uint256 left, uint256 right) internal pure returns (uint256 difference) {
        difference = left > right ? left - right : right - left;
    }
}
