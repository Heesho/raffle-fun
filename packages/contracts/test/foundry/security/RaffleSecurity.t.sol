// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Test} from "forge-std/Test.sol";

import {Raffle} from "../../../src/Raffle.sol";
import {RaffleFactory} from "../../../src/RaffleFactory.sol";
import {IRaffle} from "../../../src/interfaces/IRaffle.sol";
import {IRaffleFactory} from "../../../src/interfaces/IRaffleFactory.sol";
import {AdversarialOutboundERC20} from "../../../src/mocks/AdversarialOutboundERC20.sol";
import {FalseERC20} from "../../../src/mocks/FalseERC20.sol";
import {FeeOnTransferERC20} from "../../../src/mocks/FeeOnTransferERC20.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {MockERC721} from "../../../src/mocks/MockERC721.sol";
import {MockEntropyV2} from "../../../src/mocks/MockEntropyV2.sol";
import {ReentrantERC20} from "../../../src/mocks/ReentrantERC20.sol";
import {ReentrantPrizeERC721} from "../../../src/mocks/ReentrantPrizeERC721.sol";
import {ReentrantTicketReceiver} from "../../../src/mocks/ReentrantTicketReceiver.sol";

contract PausablePrizeERC721 is ERC721 {
    bool public transfersPaused;

    constructor() ERC721("Pausable Prize", "PPRIZE") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function setTransfersPaused(bool paused) external {
        transfersPaused = paused;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        require(!transfersPaused, "paused");
        super.safeTransferFrom(from, to, tokenId, data);
    }
}

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
        factory = new RaffleFactory(address(quote), address(entropy), treasury, 300_000, address(this));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), true);
        vm.deal(requester, 100 ether);
    }

    function testReentrantReceiverCannotNestTicketPurchase() public {
        Raffle raffle = _createDefaultRaffle(2);
        ReentrantTicketReceiver receiver = new ReentrantTicketReceiver();
        quote.mint(address(receiver), 2 * USDC);
        receiver.configure(raffle, true, false);
        receiver.approveQuote(quote);

        receiver.buyTicket();

        assertTrue(receiver.reentryBlocked());
        assertEq(raffle.totalTickets(), 1);
        assertEq(raffle.ownerOf(1), address(receiver));
    }

    function testWinningTicketBurnPrecedesSafePrizeTransferAndBlocksReentry() public {
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
        vm.expectRevert();
        raffle.ownerOf(1);
    }

    function testReentrantQuoteTokenCannotNestPurchase() public {
        ReentrantERC20 reentrantQuote = new ReentrantERC20();
        (, Raffle raffle) = _createWithQuote(address(reentrantQuote), USDC, 2);
        reentrantQuote.mint(buyer, USDC);
        vm.prank(buyer);
        reentrantQuote.approve(address(raffle), type(uint256).max);
        reentrantQuote.arm(address(raffle));

        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);

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
        raffle.buyTickets(buyer, 1);
    }

    function testFeeOnTransferQuoteTokenIsRejectedWithoutCreatingLiability() public {
        FeeOnTransferERC20 taxedQuote = new FeeOnTransferERC20();
        (, Raffle raffle) = _createWithQuote(address(taxedQuote), USDC, 2);
        taxedQuote.mint(buyer, USDC);
        vm.prank(buyer);
        taxedQuote.approve(address(raffle), USDC);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsupportedQuoteToken.selector, USDC, 990_000));
        raffle.buyTickets(buyer, 1);
        assertEq(raffle.accountedQuoteBalance(), 0);
        assertEq(taxedQuote.balanceOf(address(raffle)), 0);
    }

    function testFactoryReentrancyDuringPrizeDepositIsBlockedAtomically() public {
        ReentrantPrizeERC721 maliciousPrize = new ReentrantPrizeERC721();
        maliciousPrize.mint(sponsor, 1);
        maliciousPrize.arm(factory, 2);
        vm.prank(sponsor);
        maliciousPrize.setApprovalForAll(address(factory), true);

        vm.prank(sponsor);
        address raffleAddress = factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(maliciousPrize),
                prizeTokenId: 1,
                sponsorPrizeRecoveryRecipient: address(0),
                ticketPrice: USDC,
                minimumTickets: 1,
                startTime: block.timestamp,
                endTime: block.timestamp + 1 days,
                metadataURI: "ipfs://outer"
            })
        );

        assertTrue(maliciousPrize.reentryBlocked());
        assertEq(factory.raffleCount(), 1);
        assertEq(maliciousPrize.ownerOf(1), raffleAddress);
        assertEq(maliciousPrize.ownerOf(2), address(maliciousPrize));
    }

    function testNonExactOutboundTokenCannotDestroyQuoteLiabilities() public {
        AdversarialOutboundERC20 token = new AdversarialOutboundERC20();
        (, Raffle raffle) = _createWithQuote(address(token), USDC, 2);
        token.mint(buyer, USDC);
        vm.prank(buyer);
        token.approve(address(raffle), USDC);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);
        _resolve(raffle);

        uint256 sponsorClaim = raffle.claimableQuote(sponsor);
        uint256 fee = sponsorClaim / 100;
        token.setTransferMode(AdversarialOutboundERC20.TransferMode.RecipientFee);
        vm.prank(sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.UnsupportedQuoteTokenTransfer.selector, sponsorClaim, sponsorClaim, sponsorClaim - fee
            )
        );
        raffle.claimQuote(sponsor);
        assertEq(raffle.claimableQuote(sponsor), sponsorClaim);

        token.mint(address(raffle), fee);
        token.setTransferMode(AdversarialOutboundERC20.TransferMode.SenderTax);
        vm.prank(sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.UnsupportedQuoteTokenTransfer.selector, sponsorClaim, sponsorClaim + fee, sponsorClaim
            )
        );
        raffle.claimQuote(sponsor);
        assertEq(raffle.claimableQuote(sponsor), sponsorClaim);
    }

    function testRegressionUnsafeTransferCannotAssignWinningCredentialToRaffle() public {
        Raffle raffle = _createDefaultRaffle(1);
        quote.mint(buyer, USDC);
        vm.prank(buyer);
        quote.approve(address(raffle), USDC);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(raffle)));
        raffle.transferFrom(buyer, address(raffle), 1);
        _resolve(raffle);

        assertEq(raffle.ownerOf(1), buyer);
        assertEq(uint256(raffle.status()), uint256(IRaffle.Status.NftWon));
        assertEq(prize.ownerOf(raffle.prizeTokenId()), address(raffle));

        vm.prank(buyer);
        raffle.redeemWinningTicket(buyer);
        assertTrue(raffle.prizeClaimed());
        assertEq(prize.ownerOf(raffle.prizeTokenId()), buyer);
    }

    function testRegressionPredictedRaffleCannotBeItsOwnRecoveryRecipient() public {
        address predictedRaffle = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);

        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, predictedRaffle));
        factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prize),
                prizeTokenId: tokenId,
                sponsorPrizeRecoveryRecipient: predictedRaffle,
                ticketPrice: USDC,
                minimumTickets: 1,
                startTime: block.timestamp,
                endTime: block.timestamp + 1 days,
                metadataURI: "ipfs://self-recovery"
            })
        );

        assertEq(factory.raffleCount(), 0);
        assertEq(prize.ownerOf(tokenId), sponsor);
    }

    function testRegressionPredictedRaffleCannotBeItsOwnTreasury() public {
        address predictedRaffle = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));
        factory.setProtocolTreasury(predictedRaffle);
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);

        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, predictedRaffle));
        factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prize),
                prizeTokenId: tokenId,
                sponsorPrizeRecoveryRecipient: sponsor,
                ticketPrice: USDC,
                minimumTickets: 1,
                startTime: block.timestamp,
                endTime: block.timestamp + 1 days,
                metadataURI: "ipfs://self-treasury"
            })
        );

        assertEq(factory.raffleCount(), 0);
        assertEq(prize.ownerOf(tokenId), sponsor);
    }

    function testRegressionTicketsRejectKnownProtocolDestinations() public {
        Raffle raffle = _createDefaultRaffle(2);
        Raffle sibling = _createDefaultRaffle(2);
        quote.mint(buyer, USDC);
        vm.prank(buyer);
        quote.approve(address(raffle), USDC);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);

        address[6] memory destinations =
            [address(raffle), address(factory), address(quote), address(prize), address(entropy), address(sibling)];
        for (uint256 index; index < destinations.length; ++index) {
            vm.prank(buyer);
            vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, destinations[index]));
            raffle.transferFrom(buyer, destinations[index], 1);
            assertEq(raffle.ownerOf(1), buyer);
        }

        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(factory)));
        raffle.safeTransferFrom(buyer, address(factory), 1);

        vm.prank(buyer);
        raffle.transferFrom(buyer, sponsor, 1);
        assertEq(raffle.ownerOf(1), sponsor);
    }

    function testRegressionQuotePayoutsRejectKnownProtocolDestinations() public {
        Raffle raffle = _createDefaultRaffle(2);
        Raffle sibling = _createDefaultRaffle(2);
        quote.mint(buyer, USDC);
        vm.startPrank(buyer);
        quote.approve(address(raffle), USDC);
        raffle.buyTickets(buyer, 1);
        vm.stopPrank();
        _resolve(raffle);

        uint256 winnerLiability = raffle.winnerCashLiability();
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuoteDestination.selector, address(sibling)));
        raffle.redeemWinningTicket(address(sibling));
        assertEq(raffle.ownerOf(1), buyer);
        assertEq(raffle.winnerCashLiability(), winnerLiability);

        uint256 sponsorClaim = raffle.claimableQuote(sponsor);
        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidQuoteDestination.selector, address(sibling)));
        raffle.claimQuote(address(sibling));
        assertEq(raffle.claimableQuote(sponsor), sponsorClaim);
        assertEq(quote.balanceOf(address(sibling)), 0);
    }

    function testRegressionBrokenPrizeCannotReleaseProceedsAndFallsBackToRefunds() public {
        PausablePrizeERC721 pausablePrize = new PausablePrizeERC721();
        pausablePrize.mint(sponsor, 1);
        vm.prank(sponsor);
        pausablePrize.setApprovalForAll(address(factory), true);
        vm.prank(sponsor);
        Raffle raffle = Raffle(
            payable(factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        prizeToken: address(pausablePrize),
                        prizeTokenId: 1,
                        sponsorPrizeRecoveryRecipient: sponsor,
                        ticketPrice: USDC,
                        minimumTickets: 1,
                        startTime: block.timestamp,
                        endTime: block.timestamp + 1 days,
                        metadataURI: "ipfs://pausable-prize"
                    })
                ))
        );
        quote.mint(buyer, USDC);
        vm.startPrank(buyer);
        quote.approve(address(raffle), USDC);
        raffle.buyTickets(buyer, 1);
        vm.stopPrank();
        _resolve(raffle);
        pausablePrize.setTransfersPaused(true);

        vm.prank(buyer);
        vm.expectRevert("paused");
        raffle.redeemWinningTicket(buyer);
        assertEq(raffle.unsettledPot(), USDC);
        assertEq(raffle.claimableQuote(sponsor), 0);
        assertEq(raffle.claimableQuote(treasury), 0);
        assertEq(raffle.ownerOf(1), buyer);

        vm.warp(raffle.nftRedemptionDeadline());
        raffle.enableRefunds();
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256 buyerBefore = quote.balanceOf(buyer);
        vm.prank(buyer);
        raffle.redeemRefundTickets(ids, buyer);
        assertEq(quote.balanceOf(buyer), buyerBefore + USDC);
    }

    function testRegressionFactoryRejectsKnownProtocolFixedClaimants() public {
        Raffle existing = _createDefaultRaffle(1);

        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsafeProtocolDestination.selector, address(existing)));
        factory.setProtocolTreasury(address(existing));

        vm.expectRevert(abi.encodeWithSelector(IRaffleFactory.UnsafeProtocolDestination.selector, address(factory)));
        factory.setProtocolTreasury(address(factory));

        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsafeProtocolDestination.selector, address(factory)));
        factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(prize),
                prizeTokenId: tokenId,
                sponsorPrizeRecoveryRecipient: address(factory),
                ticketPrice: USDC,
                minimumTickets: 1,
                startTime: block.timestamp,
                endTime: block.timestamp + 1 days,
                metadataURI: "ipfs://factory-recovery"
            })
        );
    }

    function testRegressionCapturedFutureRaffleCannotExerciseRemovedRecoveryPath() public {
        Raffle target = _createDefaultRaffle(2);
        quote.mint(buyer, USDC);
        vm.startPrank(buyer);
        quote.approve(address(target), USDC);
        target.buyTickets(buyer, 1);
        address predictedHolder = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));
        target.transferFrom(buyer, predictedHolder, 1);
        vm.stopPrank();

        address attacker = address(0xA11CE);
        uint256 attackerPrizeId = nextPrizeId++;
        prize.mint(attacker, attackerPrizeId);
        vm.prank(attacker);
        prize.setApprovalForAll(address(factory), true);
        vm.prank(attacker);
        Raffle capturedHolder = Raffle(
            payable(factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        prizeToken: address(prize),
                        prizeTokenId: attackerPrizeId,
                        sponsorPrizeRecoveryRecipient: attacker,
                        ticketPrice: USDC,
                        minimumTickets: 1,
                        startTime: block.timestamp,
                        endTime: block.timestamp + 1 days,
                        metadataURI: "ipfs://captured-holder"
                    })
                ))
        );
        assertEq(address(capturedHolder), predictedHolder);
        vm.warp(target.requestGraceDeadline());
        target.enableRefunds();

        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        (bool success,) = address(capturedHolder)
            .call(
                abi.encodeWithSignature(
                    "recoverProtocolOwnedClaim(address,uint8,uint256[])", address(target), uint8(1), ids
                )
            );

        assertFalse(success);
        assertEq(target.ownerOf(1), predictedHolder);
        assertEq(target.remainingRefundLiability(), USDC);
    }

    function _createDefaultRaffle(uint256 minimumTickets) internal returns (Raffle raffle) {
        raffle = _create(factory, address(prize), USDC, minimumTickets);
    }

    function _createWithQuote(address quoteAddress, uint256 price, uint256 minimumTickets)
        internal
        returns (RaffleFactory customFactory, Raffle raffle)
    {
        customFactory = new RaffleFactory(quoteAddress, address(entropy), treasury, 300_000, address(this));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(customFactory), true);
        raffle = _create(customFactory, address(prize), price, minimumTickets);
    }

    function _create(RaffleFactory selectedFactory, address prizeAddress, uint256 price, uint256 minimumTickets)
        internal
        returns (Raffle raffle)
    {
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        raffle = Raffle(
            payable(selectedFactory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        prizeToken: prizeAddress,
                        prizeTokenId: tokenId,
                        sponsorPrizeRecoveryRecipient: address(0),
                        ticketPrice: price,
                        minimumTickets: minimumTickets,
                        startTime: block.timestamp,
                        endTime: block.timestamp + 1 days,
                        metadataURI: "ipfs://security"
                    })
                ))
        );
    }

    function _resolve(Raffle raffle) internal {
        vm.warp(raffle.endTime());
        vm.prank(requester);
        uint64 sequence = raffle.requestDraw{value: raffle.getEntropyFee()}();
        entropy.fulfill(sequence, bytes32(0));
    }
}
