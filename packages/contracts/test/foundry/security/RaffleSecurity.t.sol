// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test } from "forge-std/Test.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { FalseERC20 } from "../../../src/mocks/FalseERC20.sol";
import { ForceNative } from "../../../src/mocks/ForceNative.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";
import { MockEntropyV2 } from "../../../src/mocks/MockEntropyV2.sol";
import { ReentrantERC20 } from "../../../src/mocks/ReentrantERC20.sol";
import { ReentrantPrizeERC721 } from "../../../src/mocks/ReentrantPrizeERC721.sol";
import { ReentrantTicketReceiver } from "../../../src/mocks/ReentrantTicketReceiver.sol";

contract RaffleSecurityTest is Test {
    uint256 internal constant USDC = 1e6;

    address internal sponsor = makeAddr("sponsor");
    address internal buyer = makeAddr("buyer");
    address internal treasury = makeAddr("treasury");
    address internal requester = makeAddr("requester");

    MockERC20 internal quote;
    MockERC721 internal prize;
    MockEntropyV2 internal entropy;
    RaffleFactory internal factory;
    uint256 internal nextPrizeId = 1;

    function setUp() public {
        vm.warp(50_000);
        quote = new MockERC20();
        prize = new MockERC721();
        entropy = new MockEntropyV2();
        Raffle implementation = new Raffle();
        factory = new RaffleFactory(
            address(implementation), _quoteTokens(address(quote)), address(entropy), treasury, 300_000, address(this)
        );
        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), true);
        vm.deal(requester, 100 ether);
    }

    function testReentrantReceiverDuringTicketMintIsBlocked() public {
        Raffle raffle = _createDefaultRaffle(2);
        ReentrantTicketReceiver receiver = new ReentrantTicketReceiver();
        quote.mint(address(receiver), 2 * USDC);
        receiver.configure(raffle, true, false);
        receiver.approveQuote(quote);

        receiver.buyTicket();

        assertTrue(receiver.reentryBlocked());
        assertEq(raffle.totalTickets(), 1);
        assertEq(raffle.ownerOf(1), address(receiver));
        assertEq(raffle.grossSales(), USDC);
    }

    function testReentrantReceiverDuringPrizeClaimIsBlocked() public {
        Raffle raffle = _createDefaultRaffle(1);
        ReentrantTicketReceiver receiver = new ReentrantTicketReceiver();
        quote.mint(address(receiver), USDC);
        receiver.configure(raffle, false, false);
        receiver.approveQuote(quote);
        receiver.buyTicket();
        _resolve(raffle);

        receiver.configure(raffle, false, true);
        receiver.executePrizeClaim();

        assertTrue(receiver.reentryBlocked());
        assertTrue(raffle.prizeClaimed());
        assertEq(prize.ownerOf(raffle.prizeTokenId()), address(receiver));
    }

    function testReentrantQuoteTokenCannotNestPurchase() public {
        ReentrantERC20 reentrantQuote = new ReentrantERC20();
        (RaffleFactory customFactory, Raffle raffle) = _createWithQuote(address(reentrantQuote), USDC, 2);
        assertEq(customFactory.raffleCount(), 1);

        reentrantQuote.mint(buyer, USDC);
        vm.prank(buyer);
        reentrantQuote.approve(address(raffle), type(uint256).max);
        reentrantQuote.arm(address(raffle));

        vm.prank(buyer);
        raffle.buyTickets(buyer, 1, address(0));

        assertTrue(reentrantQuote.reentryBlocked());
        assertEq(raffle.totalTickets(), 1);
        assertEq(raffle.accountedQuoteBalance(), USDC);
    }

    function testFalseReturningQuoteTokenIsRejected() public {
        FalseERC20 falseQuote = new FalseERC20();
        (, Raffle raffle) = _createWithQuote(address(falseQuote), USDC, 2);
        falseQuote.mint(buyer, USDC);
        vm.prank(buyer);
        falseQuote.approve(address(raffle), USDC);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(falseQuote)));
        raffle.buyTickets(buyer, 1, address(0));
    }

    function testForcedNativeCurrencyCannotChangeStateOrCreateRefund() public {
        Raffle raffle = _createDefaultRaffle(2);
        vm.deal(address(this), 1 ether);
        ForceNative force = new ForceNative{ value: 1 ether }();

        force.force(payable(address(raffle)));

        assertEq(address(raffle).balance, 1 ether);
        assertEq(raffle.claimableNative(address(this)), 0);
        assertEq(uint256(raffle.state()), uint256(IRaffle.RaffleState.Active));
        assertEq(raffle.accountedQuoteBalance(), 0);
    }

    function testFactoryReentrancyDuringPrizeDepositIsBlockedWithoutBreakingOuterCreation() public {
        ReentrantPrizeERC721 maliciousPrize = new ReentrantPrizeERC721();
        uint256 outerTokenId = 1;
        uint256 nestedTokenId = 2;
        maliciousPrize.mint(sponsor, outerTokenId);
        maliciousPrize.arm(factory, nestedTokenId);
        vm.prank(sponsor);
        maliciousPrize.setApprovalForAll(address(factory), true);

        vm.prank(sponsor);
        address raffleAddress = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(maliciousPrize),
                prizeTokenId: outerTokenId,
                quoteToken: address(quote),
                ticketPrice: USDC,
                minimumTickets: 1,
                startTime: block.timestamp,
                endTime: block.timestamp + 1 days,
                metadataURI: "ipfs://outer"
            })
        );

        assertTrue(maliciousPrize.reentryBlocked());
        assertEq(factory.raffleCount(), 1);
        assertEq(maliciousPrize.ownerOf(outerTokenId), raffleAddress);
        assertEq(maliciousPrize.ownerOf(nestedTokenId), address(maliciousPrize));
    }

    function _createDefaultRaffle(uint256 minimumTickets) internal returns (Raffle raffle) {
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        address raffleAddress = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prize),
                prizeTokenId: tokenId,
                quoteToken: address(quote),
                ticketPrice: USDC,
                minimumTickets: minimumTickets,
                startTime: block.timestamp,
                endTime: block.timestamp + 1 days,
                metadataURI: "ipfs://security"
            })
        );
        raffle = Raffle(payable(raffleAddress));
    }

    function _createWithQuote(address quoteAddress, uint256 price, uint256 minimumTickets)
        internal
        returns (RaffleFactory customFactory, Raffle raffle)
    {
        Raffle implementation = new Raffle();
        address entropyAddress = address(entropy);
        address owner = address(this);
        customFactory = new RaffleFactory(
            address(implementation), _quoteTokens(quoteAddress), entropyAddress, treasury, 300_000, owner
        );
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        prize.setApprovalForAll(address(customFactory), true);
        vm.prank(sponsor);
        address raffleAddress = customFactory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prize),
                prizeTokenId: tokenId,
                quoteToken: quoteAddress,
                ticketPrice: price,
                minimumTickets: minimumTickets,
                startTime: block.timestamp,
                endTime: block.timestamp + 1 days,
                metadataURI: "ipfs://custom"
            })
        );
        raffle = Raffle(payable(raffleAddress));
    }

    function _resolve(Raffle raffle) internal {
        vm.warp(raffle.endTime());
        vm.prank(requester);
        uint64 sequence = raffle.requestDraw{ value: raffle.getEntropyFee() }();
        entropy.fulfill(sequence, bytes32(0));
    }

    function _quoteTokens(address quoteToken_) internal pure returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = quoteToken_;
    }
}
