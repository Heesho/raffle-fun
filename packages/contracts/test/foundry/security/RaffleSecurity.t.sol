// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Test } from "forge-std/Test.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { AdversarialOutboundERC20 } from "../../../src/mocks/AdversarialOutboundERC20.sol";
import { FalseERC20 } from "../../../src/mocks/FalseERC20.sol";
import { FeeOnTransferERC20 } from "../../../src/mocks/FeeOnTransferERC20.sol";
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
        (, Raffle raffle) = _createWithQuote(address(token), USDC, 1);
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

    function testRegressionFutureRaffleCanRecoverTicketsTransferredBeforeItsDeployment() public {
        Raffle nftTarget = _createDefaultRaffle(1);
        Raffle cashTarget = _createDefaultRaffle(2);
        Raffle refundTarget = _createDefaultRaffle(2);
        quote.mint(buyer, 3 * USDC);
        vm.startPrank(buyer);
        quote.approve(address(nftTarget), USDC);
        quote.approve(address(cashTarget), USDC);
        quote.approve(address(refundTarget), USDC);
        nftTarget.buyTickets(buyer, 1);
        cashTarget.buyTickets(buyer, 1);
        refundTarget.buyTickets(buyer, 1);
        vm.stopPrank();

        address predictedHolder = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));
        vm.startPrank(buyer);
        nftTarget.transferFrom(buyer, predictedHolder, 1);
        cashTarget.transferFrom(buyer, predictedHolder, 1);
        refundTarget.transferFrom(buyer, predictedHolder, 1);
        vm.stopPrank();
        Raffle protocolHolder = _createDefaultRaffle(1);
        assertEq(address(protocolHolder), predictedHolder);

        _resolve(nftTarget);
        _resolve(cashTarget);
        vm.warp(refundTarget.requestGraceDeadline());
        refundTarget.enableRefunds();

        uint256 cashLiability = cashTarget.winnerCashLiability();
        uint256 sponsorBefore = quote.balanceOf(sponsor);
        uint256[] memory winning = new uint256[](0);
        uint256 nftAmount = protocolHolder.recoverProtocolOwnedClaim(
            address(nftTarget), IRaffle.ProtocolOwnedClaim.WinningTicket, winning
        );
        uint256 cashAmount = protocolHolder.recoverProtocolOwnedClaim(
            address(cashTarget), IRaffle.ProtocolOwnedClaim.WinningTicket, winning
        );
        uint256[] memory refundable = new uint256[](1);
        refundable[0] = 1;
        uint256 refundAmount = protocolHolder.recoverProtocolOwnedClaim(
            address(refundTarget), IRaffle.ProtocolOwnedClaim.RefundTickets, refundable
        );

        assertEq(nftAmount, 0);
        assertEq(cashAmount, cashLiability);
        assertEq(refundAmount, USDC);
        assertEq(prize.ownerOf(nftTarget.prizeTokenId()), sponsor);
        assertEq(quote.balanceOf(sponsor) - sponsorBefore, cashLiability + USDC);
        assertTrue(nftTarget.winningTicketRedeemed());
        assertTrue(cashTarget.winningTicketRedeemed());
        assertEq(refundTarget.remainingRefundLiability(), 0);
    }

    function testRegressionFutureRaffleCanRecoverFixedClaims() public {
        uint256 nextFactoryNonce = vm.getNonce(address(factory));
        address predictedHolder = vm.computeCreateAddress(address(factory), nextFactoryNonce + 2);

        uint256 recoveryPrizeId = nextPrizeId++;
        prize.mint(sponsor, recoveryPrizeId);
        vm.prank(sponsor);
        Raffle prizeTarget = Raffle(
            payable(
                factory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        prizeToken: address(prize),
                        prizeTokenId: recoveryPrizeId,
                        sponsorPrizeRecoveryRecipient: predictedHolder,
                        ticketPrice: USDC,
                        minimumTickets: 1,
                        startTime: block.timestamp,
                        endTime: block.timestamp + 1 days,
                        metadataURI: "ipfs://future-fixed-prize"
                    })
                )
            )
        );

        factory.setProtocolTreasury(predictedHolder);
        Raffle feeTarget = _createDefaultRaffle(1);
        factory.setProtocolTreasury(treasury);
        Raffle protocolHolder = _createDefaultRaffle(1);
        assertEq(address(protocolHolder), predictedHolder);

        vm.prank(sponsor);
        prizeTarget.closeEmptyRaffle();
        quote.mint(buyer, USDC);
        vm.startPrank(buyer);
        quote.approve(address(feeTarget), USDC);
        feeTarget.buyTickets(buyer, 1);
        vm.stopPrank();
        _resolve(feeTarget);

        uint256 protocolFee = feeTarget.claimableQuote(predictedHolder);
        assertGt(protocolFee, 0);
        uint256 sponsorBefore = quote.balanceOf(sponsor);
        uint256[] memory noTicketIds = new uint256[](0);
        protocolHolder.recoverProtocolOwnedClaim(
            address(prizeTarget), IRaffle.ProtocolOwnedClaim.SponsorPrize, noTicketIds
        );
        protocolHolder.recoverProtocolOwnedClaim(address(feeTarget), IRaffle.ProtocolOwnedClaim.Quote, noTicketIds);

        assertEq(prize.ownerOf(recoveryPrizeId), sponsor);
        assertEq(quote.balanceOf(sponsor) - sponsorBefore, protocolFee);
        assertEq(feeTarget.claimableQuote(predictedHolder), 0);
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
            payable(
                selectedFactory.createRaffle(
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
                )
            )
        );
    }

    function _resolve(Raffle raffle) internal {
        vm.warp(raffle.endTime());
        vm.prank(requester);
        uint64 sequence = raffle.requestDraw{ value: raffle.getEntropyFee() }();
        entropy.fulfill(sequence, bytes32(0));
    }
}
