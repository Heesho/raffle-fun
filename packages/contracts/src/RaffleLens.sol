// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { IRaffle } from "./interfaces/IRaffle.sol";
import { IRaffleFactory } from "./interfaces/IRaffleFactory.sol";
import { IRaffleLens } from "./interfaces/IRaffleLens.sol";

/**
 * @title raffle.fun Canonical Raffle Lens
 * @author Heesho
 * @notice Aggregates bounded wallet reads without holding assets or changing protocol state.
 * @dev Registry authentication happens before raffle calls. Temporary Entropy fee-read failure is reported explicitly
 *      instead of making all other state unavailable.
 * @custom:version 2.0.0
 */
contract RaffleLens is IRaffleLens {
    uint256 public constant MAX_BATCH_SIZE = 64;
    IRaffleFactory public immutable factory;

    /**
     * @notice Creates a read-only lens for one canonical factory registry.
     */
    constructor(address factory_) {
        if (factory_ == address(0) || factory_.code.length == 0) revert InvalidFactory(factory_);
        factory = IRaffleFactory(factory_);
    }

    /// @inheritdoc IRaffleLens
    function getRaffleState(address raffle, address account)
        public
        view
        override
        returns (RaffleView memory raffleView)
    {
        if (!factory.isRaffle(raffle)) revert UnregisteredRaffle(raffle);
        IRaffle target = IRaffle(raffle);
        IRaffle.Status currentStatus = target.status();
        uint256 winningTicketId = target.winningTicketId();
        bool redeemed = target.winningTicketRedeemed();
        address winningOwner = address(0);
        if (winningTicketId != 0 && !redeemed) {
            winningOwner = IERC721(raffle).ownerOf(winningTicketId);
        }

        uint256 entropyFee = 0;
        bool entropyFeeAvailable = false;
        try target.getEntropyFee() returns (uint256 currentFee) {
            entropyFee = currentFee;
            entropyFeeAvailable = true;
        } catch { }

        raffleView.factoryId = factory.idByRaffle(raffle);
        raffleView.registered = true;
        raffleView.raffle = raffle;
        raffleView.status = currentStatus;
        raffleView.sponsor = target.sponsor();
        raffleView.sponsorPrizeRecoveryRecipient = target.sponsorPrizeRecoveryRecipient();
        raffleView.protocolTreasury = target.protocolTreasury();
        raffleView.quoteToken = address(target.quoteToken());
        raffleView.prizeToken = address(target.prizeToken());
        raffleView.prizeTokenId = target.prizeTokenId();
        raffleView.ticketPrice = target.ticketPrice();
        raffleView.minimumTickets = target.minimumTickets();
        raffleView.startTime = target.startTime();
        raffleView.endTime = target.endTime();
        raffleView.requestGraceDeadline = target.requestGraceDeadline();
        raffleView.drawRequestedAt = target.drawRequestedAt();
        raffleView.callbackDeadline = target.callbackDeadline();
        raffleView.entropySequenceNumber = target.entropySequenceNumber();
        raffleView.totalTickets = target.totalTickets();
        raffleView.grossSales = target.grossSales();
        raffleView.unsettledPot = target.unsettledPot();
        raffleView.remainingRefundLiability = target.remainingRefundLiability();
        raffleView.winnerCashLiability = target.winnerCashLiability();
        raffleView.totalClaimableQuote = target.totalClaimableQuote();
        raffleView.accountedQuoteBalance = target.accountedQuoteBalance();
        raffleView.winningTicketId = winningTicketId;
        raffleView.winningTicketOwner = winningOwner;
        raffleView.winningTicketRedeemed = redeemed;
        raffleView.prizeClaimed = target.prizeClaimed();
        raffleView.entropyFee = entropyFee;
        raffleView.entropyFeeAvailable = entropyFeeAvailable;
        raffleView.canBuy = currentStatus == IRaffle.Status.Active && block.timestamp >= raffleView.startTime
            && block.timestamp < raffleView.endTime;
        raffleView.canDraw = currentStatus == IRaffle.Status.Active && block.timestamp >= raffleView.endTime
            && block.timestamp < raffleView.requestGraceDeadline && raffleView.totalTickets != 0;
        if (currentStatus == IRaffle.Status.Active) {
            raffleView.canEnableRefunds =
                raffleView.totalTickets != 0 && block.timestamp >= raffleView.requestGraceDeadline;
        } else if (currentStatus == IRaffle.Status.Drawing) {
            raffleView.canEnableRefunds = block.timestamp >= raffleView.callbackDeadline;
        }

        if (account != address(0)) {
            raffleView.accountTicketBalance = IERC721(raffle).balanceOf(account);
            raffleView.accountQuoteClaim = target.claimableQuote(account);
            raffleView.accountOwnsWinningTicket = account == winningOwner;
            raffleView.accountIsPrizeRecoveryRecipient = account == raffleView.sponsorPrizeRecoveryRecipient;
            raffleView.canRedeemWinningTicket = raffleView.accountOwnsWinningTicket
                && (currentStatus == IRaffle.Status.NftWon || currentStatus == IRaffle.Status.CashWon);
            raffleView.canRedeemRefundTickets =
                currentStatus == IRaffle.Status.Refunding && raffleView.accountTicketBalance != 0;
            raffleView.canClaimQuote = raffleView.accountQuoteClaim != 0;
            bool sponsorPrizeAvailable = currentStatus == IRaffle.Status.CashWon
                || currentStatus == IRaffle.Status.Refunding || currentStatus == IRaffle.Status.Closed;
            raffleView.canClaimSponsorPrize =
                raffleView.accountIsPrizeRecoveryRecipient && sponsorPrizeAvailable && !raffleView.prizeClaimed;
        }
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
            raffleViews[index] = getRaffleState(raffles[index], account);
        }
    }
}
