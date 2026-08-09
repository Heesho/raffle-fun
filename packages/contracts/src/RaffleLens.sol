// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { IRaffle } from "./interfaces/IRaffle.sol";
import { IRaffleFactory } from "./interfaces/IRaffleFactory.sol";
import { IRaffleLens } from "./interfaces/IRaffleLens.sol";

/**
 * @title raffle.fun Canonical Raffle Lens
 * @author Heesho
 * @notice Aggregates lifecycle, deadline, liability, and wallet-action reads for factory-registered raffles.
 * @dev The immutable factory registry is checked before forwarding any read. Entropy fee failures are surfaced through
 *      `entropyFeeAvailable` so oracle unavailability cannot hide timeout recovery actions from wallets or monitors.
 * @custom:version 1.0.0
 */
contract RaffleLens is IRaffleLens {
    /// @notice Maximum canonical raffles read by one aggregate call.
    uint256 public constant MAX_BATCH_SIZE = 100;

    /// @notice Immutable factory used for registration checks and identifiers.
    IRaffleFactory public immutable factory;

    /// @notice Binds the lens to one deployed factory version.
    constructor(address factory_) {
        if (factory_ == address(0) || factory_.code.length == 0) revert InvalidFactory(factory_);
        factory = IRaffleFactory(factory_);
    }

    /// @inheritdoc IRaffleLens
    function getRaffleState(address raffle, address account)
        external
        view
        override
        returns (RaffleView memory raffleView)
    {
        raffleView = _getRaffleState(raffle, account);
    }

    /// @inheritdoc IRaffleLens
    function getRaffleStates(address[] calldata raffles, address account)
        external
        view
        override
        returns (RaffleView[] memory raffleViews)
    {
        uint256 length = raffles.length;
        if (length > MAX_BATCH_SIZE) revert BatchTooLarge(length, MAX_BATCH_SIZE);

        raffleViews = new RaffleView[](length);
        for (uint256 index; index < length; ++index) {
            raffleViews[index] = _getRaffleState(raffles[index], account);
        }
    }

    /// @dev Registration precedes every forwarded read, and field assignment avoids stack-heavy ABI struct literals.
    function _getRaffleState(address raffleAddress, address account) internal view returns (RaffleView memory view_) {
        if (!factory.isRaffle(raffleAddress)) revert UnregisteredRaffle(raffleAddress);
        IRaffle raffle = IRaffle(raffleAddress);

        IRaffle.RaffleState raffleState = raffle.state();
        address claimant = raffle.prizeClaimant();
        uint256 quoteClaim = account == address(0) ? 0 : raffle.claimableQuote(account);
        uint256 nativeClaim = account == address(0) ? 0 : raffle.claimableNative(account);

        view_.factoryId = factory.idByRaffle(raffleAddress);
        view_.registered = true;
        view_.raffle = raffleAddress;
        view_.state = raffleState;
        view_.outcome = raffle.outcome();
        view_.sponsor = raffle.sponsor();
        view_.sponsorPrizeRecoveryRecipient = raffle.sponsorPrizeRecoveryRecipient();
        view_.protocolTreasury = raffle.protocolTreasury();
        view_.prizeClaimant = claimant;
        view_.quoteToken = address(raffle.quoteToken());
        view_.prizeToken = address(raffle.prizeToken());
        view_.prizeTokenId = raffle.prizeTokenId();
        view_.ticketPrice = raffle.ticketPrice();
        view_.minimumTickets = raffle.minimumTickets();
        view_.startTime = raffle.startTime();
        view_.endTime = raffle.endTime();
        view_.requestGraceDeadline = raffle.requestGraceDeadline();
        view_.drawRequestedAt = raffle.drawRequestedAt();
        view_.callbackDeadline = raffle.callbackDeadline();
        view_.entropySequenceNumber = raffle.entropySequenceNumber();
        view_.totalTickets = raffle.totalTickets();
        view_.grossSales = raffle.grossSales();
        view_.unsettledPot = raffle.unsettledPot();
        view_.uncreditedRefundLiability = raffle.uncreditedRefundLiability();
        view_.totalClaimableQuote = raffle.totalClaimableQuote();
        view_.totalClaimableNative = raffle.totalClaimableNative();
        view_.accountedQuoteBalance = raffle.accountedQuoteBalance();
        view_.accountedNativeBalance = raffle.accountedNativeBalance();
        view_.winningTicketId = raffle.winningTicketId();
        view_.winner = raffle.winner();
        view_.accountTicketBalance = account == address(0) ? 0 : IERC721(raffleAddress).balanceOf(account);
        view_.accountQuoteClaim = quoteClaim;
        view_.accountNativeClaim = nativeClaim;
        view_.accountIsPrizeClaimant = account != address(0) && account == claimant;
        view_.canBuy = raffle.isOpen();
        view_.canDraw = raffle.canRequestDraw();
        view_.canFinalizeUnrequestedDraw = raffle.canFinalizeUnrequestedDraw();
        view_.canFinalizeTimedOutDraw = raffle.canFinalizeTimedOutDraw();
        view_.canClaimQuote = quoteClaim != 0;
        view_.canClaimNative = nativeClaim != 0;
        view_.canClaimPrize = view_.accountIsPrizeClaimant && !raffle.prizeClaimed()
            && (
                raffleState == IRaffle.RaffleState.Resolved || raffleState == IRaffle.RaffleState.Cancelled
                    || raffleState == IRaffle.RaffleState.Refunding
            );

        try raffle.getEntropyFee() returns (uint256 fee) {
            view_.entropyFee = fee;
            view_.entropyFeeAvailable = true;
        } catch {
            view_.entropyFeeAvailable = false;
        }
    }
}
