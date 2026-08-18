// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { AdversarialOutboundERC20 } from "../../../src/mocks/AdversarialOutboundERC20.sol";
import { FalseERC20 } from "../../../src/mocks/FalseERC20.sol";
import { FeeOnTransferERC20 } from "../../../src/mocks/FeeOnTransferERC20.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";
import { MockVRFV2PlusWrapper } from "../../../src/mocks/MockVRFV2PlusWrapper.sol";
import { ReentrantERC20 } from "../../../src/mocks/ReentrantERC20.sol";
import { ReentrantPrizeERC721 } from "../../../src/mocks/ReentrantPrizeERC721.sol";
import { ReentrantTicketReceiver } from "../../../src/mocks/ReentrantTicketReceiver.sol";

contract BonusERC20 is ERC20 {
    bool public bonusEnabled;

    constructor() ERC20("Bonus USDC", "BUSDC") { }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setBonusEnabled(bool value) external {
        bonusEnabled = value;
    }

    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        if (bonusEnabled && from != address(0) && to != address(0)) _mint(to, value / 100);
    }
}

contract RaffleSecurityTest is Test {
    uint256 internal constant USDC = 1e6;
    bytes4 internal constant REENTRANCY_ERROR = bytes4(keccak256("ReentrancyGuardReentrantCall()"));

    address internal sponsor = makeAddr("security-sponsor");
    address internal buyer = makeAddr("security-buyer");
    address internal treasury = makeAddr("security-treasury");
    address internal outsider = makeAddr("security-outsider");

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
        vm.deal(outsider, 100 ether);
    }

    function testReentrantReceiptReceiverCannotNestPurchase() public {
        Raffle raffle = _create(factory, address(prize), 10);
        ReentrantTicketReceiver receiver = new ReentrantTicketReceiver();
        receiver.configure(raffle, true);
        quote.mint(address(receiver), 2 * USDC);
        receiver.approveQuote(quote);

        receiver.buyTicket();

        assertTrue(receiver.reentryBlocked());
        assertEq(raffle.totalEntries(), 1);
        assertEq(raffle.ticketCount(), 1);
        assertEq(raffle.balanceOf(address(receiver)), 1);
        assertEq(raffle.grossSales(), USDC);
    }

    function testReentrantQuoteTokenCannotNestInboundPurchase() public {
        ReentrantERC20 hostile = new ReentrantERC20();
        RaffleFactory hostileFactory = _factoryWithQuote(address(hostile));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(hostileFactory), true);
        Raffle raffle = _create(hostileFactory, address(prize), 2);

        hostile.mint(buyer, USDC);
        vm.prank(buyer);
        hostile.approve(address(raffle), USDC);
        hostile.arm(address(raffle));
        vm.prank(buyer);
        raffle.buyEntries(buyer, 1);

        assertTrue(hostile.reentryBlocked());
        assertEq(raffle.totalEntries(), 1);
        assertEq(hostile.balanceOf(address(raffle)), USDC);
    }

    function testReentrantQuoteTokenCannotNestOutboundSettlement() public {
        ReentrantERC20 hostile = new ReentrantERC20();
        RaffleFactory hostileFactory = _factoryWithQuote(address(hostile));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(hostileFactory), true);
        Raffle raffle = _create(hostileFactory, address(prize), 2);

        hostile.mint(buyer, USDC);
        vm.prank(buyer);
        hostile.approve(address(raffle), USDC);
        vm.prank(buyer);
        uint256 receiptId = raffle.buyEntries(buyer, 1);
        _resolve(raffle, 0);

        hostile.armOutbound(address(raffle));
        vm.prank(buyer);
        raffle.settleWinningTicket(receiptId);
        assertTrue(hostile.reentryBlocked());
        assertEq(raffle.unsettledPot(), 0);
    }

    function testFalseReturningAndFeeOnTransferQuotesCannotCreateReceipts() public {
        FalseERC20 falseQuote = new FalseERC20();
        RaffleFactory falseFactory =
            new RaffleFactory(address(falseQuote), address(vrfWrapper), treasury, address(this));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(falseFactory), true);
        Raffle falseRaffle = _create(falseFactory, address(prize), 1);
        falseQuote.mint(buyer, USDC);
        vm.prank(buyer);
        falseQuote.approve(address(falseRaffle), USDC);
        vm.prank(buyer);
        vm.expectRevert();
        falseRaffle.buyEntries(buyer, 1);
        assertEq(falseRaffle.totalEntries(), 0);

        FeeOnTransferERC20 feeQuote = new FeeOnTransferERC20();
        RaffleFactory feeFactory = new RaffleFactory(address(feeQuote), address(vrfWrapper), treasury, address(this));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(feeFactory), true);
        Raffle feeRaffle = _create(feeFactory, address(prize), 1);
        feeQuote.mint(buyer, USDC);
        vm.prank(buyer);
        feeQuote.approve(address(feeRaffle), USDC);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsupportedQuoteToken.selector, USDC, 990_000));
        feeRaffle.buyEntries(buyer, 1);
        assertEq(feeRaffle.totalEntries(), 0);
        assertEq(feeRaffle.accountedQuoteBalance(), 0);
    }

    function testOverCreditQuoteCannotSpoofGrossAccounting() public {
        BonusERC20 bonus = new BonusERC20();
        RaffleFactory bonusFactory = new RaffleFactory(address(bonus), address(vrfWrapper), treasury, address(this));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(bonusFactory), true);
        Raffle raffle = _create(bonusFactory, address(prize), 1);
        bonus.mint(buyer, USDC);
        bonus.setBonusEnabled(true);
        vm.prank(buyer);
        bonus.approve(address(raffle), USDC);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsupportedQuoteToken.selector, USDC, 1_010_000));
        raffle.buyEntries(buyer, 1);
        assertEq(raffle.totalEntries(), 0);
        assertEq(bonus.balanceOf(address(raffle)), 0);
        assertEq(bonus.balanceOf(buyer), USDC);
    }

    function testNonExactOutboundTokenCannotConsumeWinnerLiability() public {
        AdversarialOutboundERC20 hostile = new AdversarialOutboundERC20();
        RaffleFactory hostileFactory = _factoryWithQuote(address(hostile));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(hostileFactory), true);
        Raffle raffle = _create(hostileFactory, address(prize), 2);
        hostile.mint(buyer, USDC);
        vm.prank(buyer);
        hostile.approve(address(raffle), USDC);
        vm.prank(buyer);
        uint256 receiptId = raffle.buyEntries(buyer, 1);
        _resolve(raffle, 0);

        hostile.setTransferMode(AdversarialOutboundERC20.TransferMode.RecipientFee);
        vm.prank(buyer);
        vm.expectRevert();
        raffle.settleWinningTicket(receiptId);
        assertEq(raffle.ownerOf(receiptId), buyer);
        assertEq(raffle.unsettledPot(), USDC);
        assertEq(raffle.sponsorProceeds(), 0);
        assertEq(raffle.protocolFees(), 0);
        assertEq(hostile.balanceOf(address(raffle)), USDC);

        hostile.setTransferMode(AdversarialOutboundERC20.TransferMode.Exact);
        vm.prank(buyer);
        raffle.settleWinningTicket(receiptId);
        assertEq(raffle.unsettledPot(), 0);
    }

    function testFactoryReentrancyDuringPrizeEscrowIsBlockedAtomically() public {
        ReentrantPrizeERC721 hostilePrize = new ReentrantPrizeERC721();
        hostilePrize.mint(sponsor, 1);
        vm.prank(sponsor);
        hostilePrize.setApprovalForAll(address(factory), true);
        hostilePrize.arm(factory, 2);

        vm.prank(sponsor);
        Raffle raffle = Raffle(
            payable(factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: sponsor,
                        prizeToken: address(hostilePrize),
                        prizeTokenId: 1,
                        reserveEntries: 1,
                        endTime: uint64(block.timestamp + 1 days)
                    })
                ))
        );

        assertTrue(hostilePrize.reentryBlocked());
        assertEq(factory.raffleCount(), 1);
        assertEq(hostilePrize.ownerOf(1), address(raffle));
        assertEq(hostilePrize.ownerOf(2), address(hostilePrize));
    }

    function testPrizeCannotReenterDuringWinnerTransfer() public {
        ReentrantPrizeERC721 hostilePrize = new ReentrantPrizeERC721();
        uint256 tokenId = nextPrizeId;
        hostilePrize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        hostilePrize.setApprovalForAll(address(factory), true);
        Raffle raffle = _create(factory, address(hostilePrize), 1);
        uint256 receiptId = _buy(raffle, 1);
        _resolve(raffle, 0);

        hostilePrize.armWinnerTransfer(IRaffle(address(raffle)), receiptId, buyer);
        vm.prank(outsider);
        raffle.settleWinningTicket(receiptId);

        assertTrue(hostilePrize.reentryBlocked());
        assertEq(hostilePrize.reentryAttempts(), 1);
        assertEq(hostilePrize.reentryBlocks(), 1);
        assertEq(hostilePrize.reentrySelector(), REENTRANCY_ERROR);
        assertEq(hostilePrize.ownerOf(tokenId), buyer);
        assertTrue(raffle.prizeClaimed());
        assertEq(raffle.winningTicketId(), receiptId);
        assertEq(raffle.balanceOf(buyer), 0);
        assertEq(raffle.unsettledPot(), 0);
        assertEq(raffle.protocolFees(), 50_000);
        assertEq(raffle.sponsorProceeds(), 950_000);
        assertEq(raffle.accountedQuoteBalance(), USDC);
    }

    function testPrizeCannotReenterDuringSponsorSafeTransfer() public {
        ReentrantPrizeERC721 hostilePrize = new ReentrantPrizeERC721();
        uint256 tokenId = nextPrizeId;
        hostilePrize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        hostilePrize.setApprovalForAll(address(factory), true);
        Raffle raffle = _create(factory, address(hostilePrize), 2);
        uint256 receiptId = _buy(raffle, 1);
        _resolve(raffle, 0);

        hostilePrize.armSponsorSafeTransfer(IRaffle(address(raffle)), receiptId, buyer);
        vm.prank(outsider);
        raffle.releaseSponsorPrize();

        assertTrue(hostilePrize.reentryBlocked());
        assertEq(hostilePrize.reentryAttempts(), 1);
        assertEq(hostilePrize.reentryBlocks(), 1);
        assertEq(hostilePrize.reentrySelector(), REENTRANCY_ERROR);
        assertEq(hostilePrize.ownerOf(tokenId), sponsor);
        assertTrue(raffle.prizeClaimed());
        assertEq(raffle.ownerOf(receiptId), buyer);
        assertEq(raffle.unsettledPot(), USDC);
        assertEq(raffle.protocolFees(), 0);
        assertEq(raffle.sponsorProceeds(), 0);
        assertEq(raffle.accountedQuoteBalance(), USDC);

        vm.prank(buyer);
        raffle.settleWinningTicket(receiptId);
        assertEq(raffle.unsettledPot(), 0);
        assertEq(raffle.accountedQuoteBalance(), 200_000);
    }

    function testProtocolDestinationsCannotReceiveReceiptsOrPayouts() public {
        Raffle raffle = _create(factory, address(prize), 1);
        vm.prank(buyer);
        quote.approve(address(raffle), 2 * USDC);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(factory)));
        raffle.buyEntries(address(factory), 1);
        assertEq(raffle.totalEntries(), 0);
        assertEq(quote.balanceOf(address(raffle)), 0);

        vm.prank(buyer);
        uint256 receiptId = raffle.buyEntries(buyer, 1);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(raffle)));
        raffle.transferFrom(buyer, address(raffle), receiptId);

        _resolve(raffle, 0);
        vm.prank(outsider);
        raffle.settleWinningTicket(receiptId);
        assertEq(prize.ownerOf(raffle.prizeTokenId()), buyer);
    }

    function testCallbackMakesNoQuoteOrPrizeExternalTransfers() public {
        Raffle nft = _create(factory, address(prize), 1);
        uint256 nftReceipt = _buy(nft, 1);
        uint256 quoteBefore = quote.balanceOf(address(nft));
        _resolve(nft, 0);
        assertEq(quote.balanceOf(address(nft)), quoteBefore);
        assertEq(prize.ownerOf(nft.prizeTokenId()), address(nft));
        assertEq(nft.ownerOf(nftReceipt), buyer);

        Raffle cash = _create(factory, address(prize), 2);
        uint256 cashReceipt = _buy(cash, 1);
        quoteBefore = quote.balanceOf(address(cash));
        _resolve(cash, 0);
        assertEq(quote.balanceOf(address(cash)), quoteBefore);
        assertEq(prize.ownerOf(cash.prizeTokenId()), address(cash));
        assertEq(cash.ownerOf(cashReceipt), buyer);
    }

    function testOutboundClaimFailureRestoresClaimAndAccounting() public {
        AdversarialOutboundERC20 hostile = new AdversarialOutboundERC20();
        RaffleFactory hostileFactory = _factoryWithQuote(address(hostile));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(hostileFactory), true);
        Raffle raffle = _create(hostileFactory, address(prize), 2);
        hostile.mint(buyer, USDC);
        vm.prank(buyer);
        hostile.approve(address(raffle), USDC);
        vm.prank(buyer);
        uint256 receiptId = raffle.buyEntries(buyer, 1);
        _resolve(raffle, 0);
        raffle.settleWinningTicket(receiptId);
        uint256 treasuryClaim = raffle.protocolFees();

        hostile.setTransferMode(AdversarialOutboundERC20.TransferMode.SenderTax);
        vm.expectRevert();
        raffle.releaseProtocolFees();
        assertEq(raffle.protocolFees(), treasuryClaim);
        assertEq(raffle.accountedQuoteBalance(), 200_000);
    }

    function _create(RaffleFactory selectedFactory, address prizeAddress, uint128 reserve)
        internal
        returns (Raffle raffle)
    {
        uint256 tokenId = nextPrizeId++;
        if (prizeAddress == address(prize)) prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        raffle = Raffle(
            payable(selectedFactory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        sponsorRecipient: sponsor,
                        prizeToken: prizeAddress,
                        prizeTokenId: tokenId,
                        reserveEntries: reserve,
                        endTime: uint64(block.timestamp + 1 days)
                    })
                ))
        );
    }

    function _factoryWithQuote(address selectedQuote) internal returns (RaffleFactory) {
        return new RaffleFactory(selectedQuote, address(vrfWrapper), treasury, address(this));
    }

    function _buy(Raffle raffle, uint128 entries) internal returns (uint256 receiptId) {
        vm.prank(buyer);
        quote.approve(address(raffle), type(uint256).max);
        vm.prank(buyer);
        receiptId = raffle.buyEntries(buyer, entries);
    }

    function _resolve(Raffle raffle, uint256 randomWord) internal {
        vm.warp(raffle.endTime());
        vm.prank(outsider);
        uint256 requestId = raffle.requestDraw{ value: raffle.getVrfRequestPrice() }();
        vrfWrapper.fulfill(requestId, randomWord);
    }
}
