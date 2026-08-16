// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { Test } from "forge-std/Test.sol";

import { Raffle } from "../../../src/Raffle.sol";
import { RaffleFactory } from "../../../src/RaffleFactory.sol";
import { IRaffle } from "../../../src/interfaces/IRaffle.sol";
import { IRaffleFactory } from "../../../src/interfaces/IRaffleFactory.sol";
import { MockERC20 } from "../../../src/mocks/MockERC20.sol";
import { MockERC721 } from "../../../src/mocks/MockERC721.sol";
import { MockEntropyV2 } from "../../../src/mocks/MockEntropyV2.sol";

contract RollbackTicketReceiver is IERC721Receiver {
    Raffle public raffle;
    address public escape;
    uint256 public callbacks;

    function configure(Raffle raffle_, address escape_) external {
        raffle = raffle_;
        escape = escape_;
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata) external returns (bytes4) {
        ++callbacks;
        if (tokenId == 1) raffle.transferFrom(address(this), escape, tokenId);
        if (tokenId == 2) revert("reject second mint");
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract ForceNative {
    constructor() payable { }

    function force(address payable target) external {
        selfdestruct(target);
    }
}

contract AdversarialBonusERC20 is ERC20 {
    enum TransferMode {
        Exact,
        RecipientBonus,
        SenderRebate
    }

    TransferMode public transferMode;

    constructor() ERC20("Adversarial Bonus Token", "ABONUS") { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setTransferMode(TransferMode mode) external {
        transferMode = mode;
    }

    function _update(address from, address to, uint256 value) internal override {
        TransferMode mode = transferMode;
        if (from == address(0) || to == address(0) || mode == TransferMode.Exact) {
            super._update(from, to, value);
            return;
        }

        uint256 bonus = value / 100;
        super._update(from, to, value);
        if (bonus == 0) return;
        if (mode == TransferMode.RecipientBonus) super._update(address(0), to, bonus);
        else super._update(address(0), from, bonus);
    }
}

contract RaffleExtremeTest is Test {
    uint256 internal constant USDC = 1e6;

    address internal sponsor = makeAddr("extreme-sponsor");
    address internal buyer = makeAddr("extreme-buyer");
    address internal buyerTwo = makeAddr("extreme-buyer-two");
    address internal operator = makeAddr("extreme-operator");
    address internal treasury = makeAddr("extreme-treasury");
    address internal outsider = makeAddr("extreme-outsider");

    MockERC20 internal quote;
    MockERC721 internal prize;
    MockEntropyV2 internal entropy;
    RaffleFactory internal factory;
    uint256 internal nextPrizeId = 1;

    function setUp() public {
        vm.warp(1_000_000);
        quote = new MockERC20();
        prize = new MockERC721();
        entropy = new MockEntropyV2();
        factory = new RaffleFactory(address(quote), address(entropy), treasury, 300_000, address(this));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(factory), true);
        quote.mint(buyer, 1_000_000 * USDC);
        quote.mint(buyerTwo, 1_000_000 * USDC);
        vm.deal(address(this), 100 ether);
    }

    function testCallbackDeadlineIsFirstIncludedTransitionNotAutomaticExpiry() public {
        Raffle callbackFirst = _create(factory, 1);
        _buy(callbackFirst, buyer, 1);
        uint64 callbackFirstSequence = _request(callbackFirst);
        vm.warp(callbackFirst.callbackDeadline());
        entropy.fulfill(callbackFirstSequence, bytes32(0));
        assertEq(uint256(callbackFirst.status()), uint256(IRaffle.Status.NftWon));
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.RefundsNotAvailable.selector, callbackFirst.nftRedemptionDeadline(), block.timestamp
            )
        );
        callbackFirst.enableRefunds();

        Raffle timeoutFirst = _create(factory, 1);
        _buy(timeoutFirst, buyer, 1);
        uint64 timeoutFirstSequence = _request(timeoutFirst);
        vm.warp(timeoutFirst.callbackDeadline());
        timeoutFirst.enableRefunds();
        entropy.fulfill(timeoutFirstSequence, bytes32(0));
        assertEq(uint256(timeoutFirst.status()), uint256(IRaffle.Status.Refunding));
        assertEq(timeoutFirst.winningTicketId(), 0);
        assertEq(timeoutFirst.remainingRefundLiability(), USDC);

        Raffle lateCallback = _create(factory, 1);
        _buy(lateCallback, buyer, 1);
        uint64 lateSequence = _request(lateCallback);
        vm.warp(lateCallback.callbackDeadline() + 365 days);
        entropy.fulfill(lateSequence, bytes32(0));
        assertEq(uint256(lateCallback.status()), uint256(IRaffle.Status.NftWon));
        assertEq(lateCallback.resolvedAt(), block.timestamp);
    }

    function testNftDeadlineIsFirstIncludedTransitionNotAutomaticExpiry() public {
        Raffle winnerFirst = _create(factory, 1);
        _buy(winnerFirst, buyer, 1);
        _resolve(winnerFirst, bytes32(0));
        vm.warp(winnerFirst.nftRedemptionDeadline());
        vm.prank(buyer);
        winnerFirst.redeemWinningTicket(buyer);
        assertTrue(winnerFirst.prizeClaimed());
        assertEq(prize.ownerOf(winnerFirst.prizeTokenId()), buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.NftWon));
        winnerFirst.enableRefunds();

        Raffle refundFirst = _create(factory, 1);
        _buy(refundFirst, buyer, 1);
        _resolve(refundFirst, bytes32(0));
        vm.warp(refundFirst.nftRedemptionDeadline());
        refundFirst.enableRefunds();
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.InvalidStatus.selector, IRaffle.Status.Refunding));
        refundFirst.redeemWinningTicket(buyer);
        assertEq(refundFirst.remainingRefundLiability(), USDC);
        assertEq(prize.ownerOf(refundFirst.prizeTokenId()), address(refundFirst));

        Raffle lateWinner = _create(factory, 1);
        _buy(lateWinner, buyer, 1);
        _resolve(lateWinner, bytes32(0));
        vm.warp(lateWinner.nftRedemptionDeadline() + 365 days);
        vm.prank(buyer);
        lateWinner.redeemWinningTicket(buyerTwo);
        assertTrue(lateWinner.prizeClaimed());
        assertEq(prize.ownerOf(lateWinner.prizeTokenId()), buyerTwo);
    }

    function testRefundEventsDistinguishMissingRequestFromAcceptedDrawAndNftTimeout() public {
        Raffle requestMissing = _create(factory, 2);
        _buy(requestMissing, buyer, 1);
        vm.warp(requestMissing.requestGraceDeadline());
        vm.expectEmit(true, true, false, true, address(requestMissing));
        emit IRaffle.RefundsEnabled(outsider, false, USDC);
        vm.prank(outsider);
        requestMissing.enableRefunds();

        Raffle callbackMissing = _create(factory, 2);
        _buy(callbackMissing, buyer, 1);
        _request(callbackMissing);
        vm.warp(callbackMissing.callbackDeadline());
        vm.expectEmit(true, true, false, true, address(callbackMissing));
        emit IRaffle.RefundsEnabled(outsider, true, USDC);
        vm.prank(outsider);
        callbackMissing.enableRefunds();

        Raffle nftUnclaimed = _create(factory, 1);
        _buy(nftUnclaimed, buyer, 1);
        _resolve(nftUnclaimed, bytes32(0));
        vm.warp(nftUnclaimed.nftRedemptionDeadline());
        vm.expectEmit(true, true, false, true, address(nftUnclaimed));
        emit IRaffle.RefundsEnabled(outsider, true, USDC);
        vm.prank(outsider);
        nftUnclaimed.enableRefunds();
    }

    function testMultiMintReceiverFailureRollsBackPaymentMintsAndNestedTransfer() public {
        Raffle raffle = _create(factory, 10);
        RollbackTicketReceiver receiver = new RollbackTicketReceiver();
        receiver.configure(raffle, outsider);
        vm.prank(buyer);
        quote.approve(address(raffle), 3 * USDC);
        uint256 buyerBefore = quote.balanceOf(buyer);

        vm.prank(buyer);
        vm.expectRevert("reject second mint");
        raffle.buyTickets(address(receiver), 3);

        assertEq(quote.balanceOf(buyer), buyerBefore);
        assertEq(quote.balanceOf(address(raffle)), 0);
        assertEq(raffle.totalTickets(), 0);
        assertEq(raffle.grossSales(), 0);
        assertEq(raffle.unsettledPot(), 0);
        assertEq(receiver.callbacks(), 0);
        assertEq(raffle.balanceOf(address(receiver)), 0);
        assertEq(raffle.balanceOf(outsider), 0);
        vm.expectRevert();
        raffle.ownerOf(1);
    }

    function testDuplicateAndMixedOwnerRefundBatchesAreFullyAtomic() public {
        Raffle raffle = _create(factory, 10);
        _buy(raffle, buyer, 2);
        _buy(raffle, buyerTwo, 1);
        vm.warp(raffle.requestGraceDeadline());
        raffle.enableRefunds();
        uint256 liabilityBefore = raffle.remainingRefundLiability();
        uint256 raffleBalanceBefore = quote.balanceOf(address(raffle));

        uint256[] memory duplicate = new uint256[](2);
        duplicate[0] = 1;
        duplicate[1] = 1;
        vm.prank(buyer);
        vm.expectRevert();
        raffle.redeemRefundTickets(duplicate, buyer);
        assertEq(raffle.ownerOf(1), buyer);
        assertEq(raffle.remainingRefundLiability(), liabilityBefore);
        assertEq(quote.balanceOf(address(raffle)), raffleBalanceBefore);

        uint256[] memory mixedOwners = new uint256[](2);
        mixedOwners[0] = 1;
        mixedOwners[1] = 3;
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.NotTicketOwner.selector, 3, buyer, buyerTwo));
        raffle.redeemRefundTickets(mixedOwners, buyer);
        assertEq(raffle.ownerOf(1), buyer);
        assertEq(raffle.ownerOf(3), buyerTwo);
        assertEq(raffle.remainingRefundLiability(), liabilityBefore);
        assertEq(quote.balanceOf(address(raffle)), raffleBalanceBefore);
    }

    function testStaleOperatorApprovalsCannotMoveLockedTicketsButResumeForRefunds() public {
        Raffle raffle = _create(factory, 1);
        _buy(raffle, buyer, 3);
        vm.prank(buyer);
        raffle.setApprovalForAll(operator, true);
        uint64 sequence = _request(raffle);

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.TicketTransferLocked.selector, 1, IRaffle.Status.Drawing));
        raffle.transferFrom(buyer, buyerTwo, 1);
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.TicketTransferLocked.selector, 2, IRaffle.Status.Drawing));
        raffle.safeTransferFrom(buyer, buyerTwo, 2);

        entropy.fulfill(sequence, bytes32(0));
        assertEq(raffle.winningTicketId(), 1);
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.TicketTransferLocked.selector, 1, IRaffle.Status.NftWon));
        raffle.transferFrom(buyer, buyerTwo, 1);
        vm.prank(operator);
        raffle.transferFrom(buyer, buyerTwo, 2);
        assertEq(raffle.ownerOf(2), buyerTwo);

        vm.warp(raffle.nftRedemptionDeadline());
        raffle.enableRefunds();
        vm.prank(operator);
        raffle.transferFrom(buyer, buyerTwo, 1);
        assertEq(raffle.ownerOf(1), buyerTwo);
    }

    function testOverCreditAndSenderRebateTokensCannotSpoofExactAccounting() public {
        AdversarialBonusERC20 bonusQuote = new AdversarialBonusERC20();
        RaffleFactory bonusFactory =
            new RaffleFactory(address(bonusQuote), address(entropy), treasury, 300_000, address(this));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(bonusFactory), true);
        Raffle raffle = _create(bonusFactory, 2);
        bonusQuote.mint(buyer, USDC);
        vm.prank(buyer);
        bonusQuote.approve(address(raffle), type(uint256).max);

        bonusQuote.setTransferMode(AdversarialBonusERC20.TransferMode.RecipientBonus);
        vm.prank(buyer);
        vm.expectRevert(abi.encodeWithSelector(IRaffle.UnsupportedQuoteToken.selector, USDC, 1_010_000));
        raffle.buyTickets(buyer, 1);
        assertEq(raffle.totalTickets(), 0);
        assertEq(bonusQuote.balanceOf(address(raffle)), 0);
        assertEq(bonusQuote.balanceOf(buyer), USDC);

        bonusQuote.setTransferMode(AdversarialBonusERC20.TransferMode.Exact);
        vm.prank(buyer);
        raffle.buyTickets(buyer, 1);
        _resolve(raffle, bytes32(0));
        uint256 winnerAmount = raffle.winnerCashLiability();

        bonusQuote.setTransferMode(AdversarialBonusERC20.TransferMode.RecipientBonus);
        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.UnsupportedQuoteTokenTransfer.selector,
                winnerAmount,
                winnerAmount,
                winnerAmount + winnerAmount / 100
            )
        );
        raffle.redeemWinningTicket(buyer);
        assertEq(raffle.ownerOf(1), buyer);
        assertEq(raffle.winnerCashLiability(), winnerAmount);

        bonusQuote.setTransferMode(AdversarialBonusERC20.TransferMode.Exact);
        vm.prank(buyer);
        raffle.redeemWinningTicket(buyer);
        uint256 sponsorClaim = raffle.claimableQuote(sponsor);
        bonusQuote.setTransferMode(AdversarialBonusERC20.TransferMode.SenderRebate);
        vm.prank(sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRaffle.UnsupportedQuoteTokenTransfer.selector,
                sponsorClaim,
                sponsorClaim - sponsorClaim / 100,
                sponsorClaim
            )
        );
        raffle.claimQuote(sponsor);
        assertEq(raffle.claimableQuote(sponsor), sponsorClaim);
    }

    function testForcedNativeCurrencyNeverEntersQuoteAccountingOrDrawFees() public {
        Raffle raffle = _create(factory, 1);
        _buy(raffle, buyer, 1);
        uint256 quoteLiability = raffle.accountedQuoteBalance();

        (bool directSuccess,) = address(raffle).call{ value: 1 }("");
        assertFalse(directSuccess);
        ForceNative force = new ForceNative{ value: 3 ether }();
        force.force(payable(address(raffle)));
        assertEq(address(raffle).balance, 3 ether);
        assertEq(raffle.accountedQuoteBalance(), quoteLiability);

        uint64 sequence = _request(raffle);
        assertEq(address(raffle).balance, 3 ether);
        entropy.fulfill(sequence, bytes32(0));
        vm.prank(buyer);
        raffle.redeemWinningTicket(buyer);
        vm.prank(treasury);
        raffle.claimQuote(treasury);
        vm.prank(sponsor);
        raffle.claimQuote(sponsor);
        assertEq(raffle.accountedQuoteBalance(), 0);
        assertEq(address(raffle).balance, 3 ether);
    }

    function testAliasedSponsorTreasuryBuyerAndWinnerConserveAllQuote() public {
        RaffleFactory aliasedFactory =
            new RaffleFactory(address(quote), address(entropy), sponsor, 300_000, address(this));
        vm.prank(sponsor);
        prize.setApprovalForAll(address(aliasedFactory), true);

        Raffle nftRaffle = _create(aliasedFactory, 1);
        _buy(nftRaffle, sponsor, 1);
        _resolve(nftRaffle, bytes32(0));
        vm.prank(sponsor);
        nftRaffle.redeemWinningTicket(buyer);
        assertEq(nftRaffle.claimableQuote(sponsor), USDC);
        nftRaffle.claimQuoteFor(sponsor);
        assertEq(nftRaffle.accountedQuoteBalance(), 0);

        Raffle cashRaffle = _create(aliasedFactory, 2);
        _buy(cashRaffle, sponsor, 1);
        _resolve(cashRaffle, bytes32(0));
        assertEq(cashRaffle.claimableQuote(sponsor), 240_000);
        assertEq(cashRaffle.winnerCashLiability(), 760_000);
        vm.prank(sponsor);
        cashRaffle.redeemWinningTicket(sponsor);
        cashRaffle.claimQuoteFor(sponsor);
        assertEq(cashRaffle.accountedQuoteBalance(), 0);
        assertEq(quote.balanceOf(address(cashRaffle)), 0);
    }

    function testThreeRafflesInterleaveWithoutCrossingTicketsPrizesOrLiabilities() public {
        Raffle nftRaffle = _create(factory, 2);
        Raffle cashRaffle = _create(factory, 5);
        Raffle refundRaffle = _create(factory, 100);
        _buy(nftRaffle, buyer, 2);
        _buy(cashRaffle, buyerTwo, 3);
        _buy(refundRaffle, buyer, 4);
        assertEq(nftRaffle.ownerOf(1), buyer);
        assertEq(cashRaffle.ownerOf(1), buyerTwo);
        assertEq(refundRaffle.ownerOf(1), buyer);

        uint64 nftSequence = _request(nftRaffle);
        uint64 cashSequence = _request(cashRaffle);
        assertNotEq(nftSequence, cashSequence);
        entropy.fulfill(cashSequence, bytes32(uint256(2)));
        entropy.fulfill(nftSequence, bytes32(uint256(1)));
        vm.warp(refundRaffle.requestGraceDeadline());
        refundRaffle.enableRefunds();

        Raffle[3] memory raffles = [nftRaffle, cashRaffle, refundRaffle];
        for (uint256 index; index < raffles.length; ++index) {
            assertEq(quote.balanceOf(address(raffles[index])), raffles[index].accountedQuoteBalance());
            assertEq(factory.raffleById(raffles[index].raffleId()), address(raffles[index]));
            assertTrue(factory.isRaffle(address(raffles[index])));
        }

        vm.prank(buyer);
        nftRaffle.redeemWinningTicket(buyer);
        nftRaffle.claimQuoteFor(treasury);
        nftRaffle.claimQuoteFor(sponsor);

        vm.prank(buyerTwo);
        cashRaffle.redeemWinningTicket(buyerTwo);
        cashRaffle.claimQuoteFor(treasury);
        cashRaffle.claimQuoteFor(sponsor);
        vm.prank(sponsor);
        cashRaffle.claimSponsorPrize(sponsor);

        uint256[] memory refundIds = new uint256[](4);
        for (uint256 index; index < refundIds.length; ++index) {
            refundIds[index] = index + 1;
        }
        vm.prank(buyer);
        refundRaffle.redeemRefundTickets(refundIds, buyer);
        vm.prank(sponsor);
        refundRaffle.claimSponsorPrize(sponsor);

        for (uint256 index; index < raffles.length; ++index) {
            assertEq(raffles[index].accountedQuoteBalance(), 0);
            assertEq(quote.balanceOf(address(raffles[index])), 0);
            assertTrue(raffles[index].prizeClaimed());
        }
    }

    function testSameFactoryNestedRaffleTicketPrizeRevertsAtomically() public {
        Raffle inner = _create(factory, 2);
        _buy(inner, sponsor, 1);
        vm.prank(sponsor);
        inner.approve(address(factory), 1);
        uint256 raffleCountBefore = factory.raffleCount();

        vm.prank(sponsor);
        vm.expectPartialRevert(IRaffle.UnsafeProtocolDestination.selector);
        factory.createRaffle(
            IRaffleFactory.CreateRaffleParams({
                prizeToken: address(inner),
                prizeTokenId: 1,
                sponsorPrizeRecoveryRecipient: sponsor,
                ticketPrice: USDC,
                minimumTickets: 1,
                startTime: block.timestamp,
                endTime: block.timestamp + 1 days,
                metadataURI: "ipfs://same-factory-nested"
            })
        );

        assertEq(factory.raffleCount(), raffleCountBefore);
        assertEq(inner.ownerOf(1), sponsor);
    }

    function testCrossFactoryNestedWinnerLockPreservesBuyerRefundButCanStrandPrize() public {
        Raffle inner = _create(factory, 2);
        _buy(inner, sponsor, 1);

        RaffleFactory outerFactory =
            new RaffleFactory(address(quote), address(entropy), treasury, 300_000, address(this));
        vm.prank(sponsor);
        inner.approve(address(outerFactory), 1);
        vm.prank(sponsor);
        Raffle outer = Raffle(
            payable(outerFactory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        prizeToken: address(inner),
                        prizeTokenId: 1,
                        sponsorPrizeRecoveryRecipient: sponsor,
                        ticketPrice: USDC,
                        minimumTickets: 1,
                        startTime: block.timestamp,
                        endTime: block.timestamp + 1 days,
                        metadataURI: "ipfs://cross-factory-nested"
                    })
                ))
        );
        assertEq(inner.ownerOf(1), address(outer));
        _buy(outer, buyer, 1);

        uint64 innerSequence = _request(inner);
        uint64 outerSequence = _request(outer);
        entropy.fulfill(outerSequence, bytes32(0));
        assertEq(uint256(inner.status()), uint256(IRaffle.Status.Drawing));
        assertEq(uint256(outer.status()), uint256(IRaffle.Status.NftWon));

        vm.prank(buyer);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffle.TicketTransferLocked.selector, 1, IRaffle.Status.Drawing)
        );
        outer.redeemWinningTicket(buyer);
        assertEq(outer.ownerOf(1), buyer);
        assertEq(inner.ownerOf(1), address(outer));
        assertEq(outer.unsettledPot(), USDC);

        vm.warp(outer.nftRedemptionDeadline());
        outer.enableRefunds();
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256 buyerBefore = quote.balanceOf(buyer);
        vm.prank(buyer);
        outer.redeemRefundTickets(ids, buyer);
        assertEq(quote.balanceOf(buyer) - buyerBefore, USDC);
        assertEq(outer.accountedQuoteBalance(), 0);

        vm.prank(sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffle.TicketTransferLocked.selector, 1, IRaffle.Status.Drawing)
        );
        outer.claimSponsorPrize(sponsor);

        entropy.fulfill(innerSequence, bytes32(0));
        assertEq(uint256(inner.status()), uint256(IRaffle.Status.CashWon));
        vm.prank(sponsor);
        vm.expectRevert(
            abi.encodeWithSelector(IRaffle.TicketTransferLocked.selector, 1, IRaffle.Status.CashWon)
        );
        outer.claimSponsorPrize(sponsor);
        assertEq(inner.ownerOf(1), address(outer));
        assertFalse(outer.prizeClaimed());
    }

    function _create(RaffleFactory selectedFactory, uint256 minimumTickets) internal returns (Raffle raffle) {
        uint256 tokenId = nextPrizeId++;
        prize.mint(sponsor, tokenId);
        vm.prank(sponsor);
        raffle = Raffle(
            payable(selectedFactory.createRaffle(
                    IRaffleFactory.CreateRaffleParams({
                        prizeToken: address(prize),
                        prizeTokenId: tokenId,
                        sponsorPrizeRecoveryRecipient: sponsor,
                        ticketPrice: USDC,
                        minimumTickets: minimumTickets,
                        startTime: block.timestamp,
                        endTime: block.timestamp + 1 days,
                        metadataURI: "ipfs://extreme"
                    })
                ))
        );
    }

    function _buy(Raffle raffle, address account, uint256 quantity) internal {
        quote.mint(account, quantity * USDC);
        vm.prank(account);
        quote.approve(address(raffle), type(uint256).max);
        vm.prank(account);
        raffle.buyTickets(account, quantity);
    }

    function _request(Raffle raffle) internal returns (uint64 sequence) {
        vm.warp(raffle.endTime());
        uint256 fee = raffle.getEntropyFee();
        vm.deal(outsider, fee);
        vm.prank(outsider);
        sequence = raffle.requestDraw{ value: fee }();
    }

    function _resolve(Raffle raffle, bytes32 randomNumber) internal {
        uint64 sequence = _request(raffle);
        entropy.fulfill(sequence, randomNumber);
    }
}
