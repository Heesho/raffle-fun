import { Address, BigInt } from "@graphprotocol/graph-ts";

import {
  DrawRequested as DrawRequestedEvent,
  EmptyRaffleClosed,
  PrizeDeposited,
  QuoteClaimed as QuoteClaimedEvent,
  RaffleResolved,
  RefundsEnabled,
  RefundTicketsRedeemed,
  SponsorPrizeClaimed as SponsorPrizeClaimedEvent,
  TicketsPurchased,
  Transfer,
  WinningTicketRedeemed,
} from "../generated/templates/Raffle/Raffle";
import {
  DrawRequest,
  Protocol,
  Purchase,
  QuoteClaim,
  QuoteTokenStats,
  Raffle,
  RaffleTransfer,
  RefundEnable,
  RefundRedemption,
  Resolution,
  SponsorPrizeClaim,
  Ticket,
  WinningRedemption,
} from "../generated/schema";
import {
  eventId,
  getOrCreateAccount,
  getOrCreateAccountTokenStats,
  getOrCreateRaffleAccount,
  ticketId,
  updatePurchaseDayData,
  updateResolutionDayData,
  updateSettlementDayData,
} from "./helpers";

const ZERO_ADDRESS = Address.zero();
const ONE = BigInt.fromI32(1);

function statusName(value: i32): string {
  if (value == 3) return "NFT_WON";
  if (value == 4) return "CASH_WON";
  if (value == 5) return "REFUNDING";
  if (value == 6) return "CLOSED";
  if (value == 2) return "DRAWING";
  if (value == 1) return "ACTIVE";
  return "AWAITING_PRIZE";
}

export function handlePrizeDeposited(event: PrizeDeposited): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null) return;
  raffle.status = "ACTIVE";
  raffle.save();
}

export function handleTicketsPurchased(event: TicketsPurchased): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null || Purchase.load(eventId(event)) != null) return;

  const buyer = getOrCreateAccount(event.params.buyer);
  const recipient = getOrCreateAccount(event.params.recipient);
  const purchase = new Purchase(eventId(event));
  purchase.raffle = raffle.id;
  purchase.buyer = buyer.id;
  purchase.recipient = recipient.id;
  purchase.quantity = event.params.quantity;
  purchase.firstTicketId = event.params.firstTicketId;
  purchase.lastTicketId = event.params.lastTicketId;
  purchase.grossAmount = event.params.grossAmount;
  purchase.transactionHash = event.transaction.hash;
  purchase.blockNumber = event.block.number;
  purchase.timestamp = event.block.timestamp;
  purchase.logIndex = event.logIndex;
  purchase.save();

  raffle.totalTickets = raffle.totalTickets.plus(event.params.quantity);
  raffle.grossSales = raffle.grossSales.plus(event.params.grossAmount);
  raffle.unsettledPot = raffle.unsettledPot.plus(event.params.grossAmount);
  raffle.save();

  buyer.ticketsBought = buyer.ticketsBought.plus(event.params.quantity);
  buyer.save();
  const quoteToken = QuoteTokenStats.load(raffle.quoteTokenStats);
  if (quoteToken != null) {
    const buyerStats = getOrCreateAccountTokenStats(
      quoteToken,
      event.params.buyer,
    );
    buyerStats.grossSpent = buyerStats.grossSpent.plus(
      event.params.grossAmount,
    );
    buyerStats.save();
    quoteToken.grossVolume = quoteToken.grossVolume.plus(
      event.params.grossAmount,
    );
    quoteToken.save();
  }
  const participation = getOrCreateRaffleAccount(raffle, event.params.buyer);
  participation.ticketsBought = participation.ticketsBought.plus(
    event.params.quantity,
  );
  participation.grossSpent = participation.grossSpent.plus(
    event.params.grossAmount,
  );
  participation.save();

  const protocol = Protocol.load(raffle.protocol);
  if (protocol != null) {
    protocol.totalTickets = protocol.totalTickets.plus(event.params.quantity);
    protocol.save();
  }

  let current = event.params.firstTicketId;
  while (current.le(event.params.lastTicketId)) {
    const ticket = Ticket.load(ticketId(raffle.id, current));
    if (ticket != null) {
      ticket.purchase = purchase.id;
      ticket.save();
    }
    current = current.plus(ONE);
  }
  updatePurchaseDayData(
    raffle,
    event,
    event.params.quantity,
    event.params.grossAmount,
  );
}

export function handleTransfer(event: Transfer): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null || RaffleTransfer.load(eventId(event)) != null) return;
  const id = ticketId(raffle.id, event.params.tokenId);
  let ticket = Ticket.load(id);

  if (event.params.from != ZERO_ADDRESS) {
    const from = getOrCreateAccount(event.params.from);
    from.ticketsCurrentlyOwned = from.ticketsCurrentlyOwned.minus(ONE);
    from.save();
    const participation = getOrCreateRaffleAccount(raffle, event.params.from);
    participation.ticketsCurrentlyOwned =
      participation.ticketsCurrentlyOwned.minus(ONE);
    participation.save();
  }

  if (event.params.to != ZERO_ADDRESS) {
    const to = getOrCreateAccount(event.params.to);
    to.ticketsCurrentlyOwned = to.ticketsCurrentlyOwned.plus(ONE);
    to.save();
    const participation = getOrCreateRaffleAccount(raffle, event.params.to);
    participation.ticketsCurrentlyOwned =
      participation.ticketsCurrentlyOwned.plus(ONE);
    participation.save();
    if (ticket == null) {
      ticket = new Ticket(id);
      ticket.raffle = raffle.id;
      ticket.ticketId = event.params.tokenId;
      ticket.originalRecipient = to.id;
      ticket.winning = false;
      ticket.burned = false;
    }
    ticket.currentOwner = to.id;
    ticket.save();
  } else if (ticket != null) {
    ticket.currentOwner = null;
    ticket.burned = true;
    ticket.save();
  }

  if (ticket != null) {
    const transfer = new RaffleTransfer(eventId(event));
    transfer.raffle = raffle.id;
    transfer.ticket = ticket.id;
    if (event.params.from != ZERO_ADDRESS) transfer.from = event.params.from;
    if (event.params.to != ZERO_ADDRESS) transfer.to = event.params.to;
    transfer.transactionHash = event.transaction.hash;
    transfer.blockNumber = event.block.number;
    transfer.timestamp = event.block.timestamp;
    transfer.logIndex = event.logIndex;
    transfer.save();
  }
}

export function handleDrawRequested(event: DrawRequestedEvent): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null || DrawRequest.load(eventId(event)) != null) return;
  const requester = getOrCreateAccount(event.params.requester);
  const request = new DrawRequest(eventId(event));
  request.raffle = raffle.id;
  request.sequenceNumber = event.params.sequenceNumber;
  request.requester = requester.id;
  request.fee = event.params.fee;
  request.excessReturned = event.params.excessReturned;
  request.drawRequestedAt = event.params.drawRequestedAt;
  request.callbackDeadline = event.params.callbackDeadline;
  request.transactionHash = event.transaction.hash;
  request.blockNumber = event.block.number;
  request.timestamp = event.block.timestamp;
  request.logIndex = event.logIndex;
  request.save();

  raffle.status = "DRAWING";
  raffle.entropySequenceNumber = event.params.sequenceNumber;
  raffle.drawRequestedAt = event.params.drawRequestedAt;
  raffle.callbackDeadline = event.params.callbackDeadline;
  raffle.requestedTxHash = event.transaction.hash;
  raffle.requestedBlock = event.block.number;
  raffle.requestedTimestamp = event.block.timestamp;
  raffle.save();

  const protocol = Protocol.load(raffle.protocol);
  if (protocol != null) {
    protocol.activeCount = protocol.activeCount.minus(ONE);
    protocol.drawingCount = protocol.drawingCount.plus(ONE);
    protocol.save();
  }
}

export function handleRaffleResolved(event: RaffleResolved): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null || Resolution.load(eventId(event)) != null) return;
  const result = statusName(event.params.result);
  raffle.status = result;
  raffle.entropySequenceNumber = event.params.sequenceNumber;
  raffle.winningTicketId = event.params.winningTicketId;
  raffle.winnerCashLiability = event.params.winnerCashAmount;
  const nftResult = event.params.result == 3;
  if (!nftResult) {
    raffle.unsettledPot = BigInt.zero();
    raffle.totalClaimableQuote = raffle.totalClaimableQuote
      .plus(event.params.protocolFee)
      .plus(event.params.sponsorCashAmount);
    raffle.totalProtocolFees = raffle.totalProtocolFees.plus(
      event.params.protocolFee,
    );
  }
  raffle.resolvedTxHash = event.transaction.hash;
  raffle.resolvedBlock = event.block.number;
  raffle.resolvedTimestamp = event.block.timestamp;
  raffle.save();

  const winningTicket = Ticket.load(
    ticketId(raffle.id, event.params.winningTicketId),
  );
  if (winningTicket != null) {
    winningTicket.winning = true;
    winningTicket.save();
  }

  const resolution = new Resolution(eventId(event));
  resolution.raffle = raffle.id;
  resolution.sequenceNumber = event.params.sequenceNumber;
  resolution.winningTicketId = event.params.winningTicketId;
  resolution.result = result;
  resolution.protocolFee = event.params.protocolFee;
  resolution.winnerCashAmount = event.params.winnerCashAmount;
  resolution.sponsorCashAmount = event.params.sponsorCashAmount;
  resolution.transactionHash = event.transaction.hash;
  resolution.blockNumber = event.block.number;
  resolution.timestamp = event.block.timestamp;
  resolution.logIndex = event.logIndex;
  resolution.save();

  const protocol = Protocol.load(raffle.protocol);
  if (protocol != null) {
    protocol.drawingCount = protocol.drawingCount.minus(ONE);
    if (event.params.result == 3)
      protocol.nftWonCount = protocol.nftWonCount.plus(ONE);
    else protocol.cashWonCount = protocol.cashWonCount.plus(ONE);
    protocol.save();
  }
  const quoteToken = QuoteTokenStats.load(raffle.quoteTokenStats);
  const distributable = event.params.winnerCashAmount.plus(
    event.params.sponsorCashAmount,
  );
  if (quoteToken != null && !nftResult) {
    quoteToken.protocolFees = quoteToken.protocolFees.plus(
      event.params.protocolFee,
    );
    quoteToken.settledVolume = quoteToken.settledVolume.plus(distributable);
    quoteToken.save();
  }
  updateResolutionDayData(
    raffle,
    event,
    nftResult ? BigInt.zero() : event.params.protocolFee,
    nftResult ? BigInt.zero() : distributable,
  );
}

export function handleRefundsEnabled(event: RefundsEnabled): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null || RefundEnable.load(eventId(event)) != null) return;
  const previousStatus = raffle.status;
  const finalizer = getOrCreateAccount(event.params.finalizer);
  raffle.status = "REFUNDING";
  raffle.unsettledPot = BigInt.zero();
  raffle.remainingRefundLiability = event.params.remainingRefundLiability;
  raffle.resolvedTxHash = event.transaction.hash;
  raffle.resolvedBlock = event.block.number;
  raffle.resolvedTimestamp = event.block.timestamp;
  raffle.save();

  const enable = new RefundEnable(eventId(event));
  enable.raffle = raffle.id;
  enable.finalizer = finalizer.id;
  enable.requestWasAccepted = event.params.requestWasAccepted;
  enable.remainingRefundLiability = event.params.remainingRefundLiability;
  enable.transactionHash = event.transaction.hash;
  enable.blockNumber = event.block.number;
  enable.timestamp = event.block.timestamp;
  enable.logIndex = event.logIndex;
  enable.save();

  const protocol = Protocol.load(raffle.protocol);
  if (protocol != null) {
    if (previousStatus == "NFT_WON")
      protocol.nftWonCount = protocol.nftWonCount.minus(ONE);
    else if (event.params.requestWasAccepted)
      protocol.drawingCount = protocol.drawingCount.minus(ONE);
    else protocol.activeCount = protocol.activeCount.minus(ONE);
    protocol.refundingCount = protocol.refundingCount.plus(ONE);
    protocol.save();
  }
}

export function handleRefundTicketsRedeemed(
  event: RefundTicketsRedeemed,
): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null || RefundRedemption.load(eventId(event)) != null) return;
  const owner = getOrCreateAccount(event.params.owner);
  raffle.remainingRefundLiability = event.params.remainingRefundLiability;
  raffle.totalRefundRedeemed = raffle.totalRefundRedeemed.plus(
    event.params.amount,
  );
  raffle.save();

  const redemption = new RefundRedemption(eventId(event));
  redemption.raffle = raffle.id;
  redemption.owner = owner.id;
  redemption.destination = event.params.to;
  redemption.quantity = event.params.quantity;
  redemption.amount = event.params.amount;
  redemption.remainingRefundLiability = event.params.remainingRefundLiability;
  redemption.transactionHash = event.transaction.hash;
  redemption.blockNumber = event.block.number;
  redemption.timestamp = event.block.timestamp;
  redemption.logIndex = event.logIndex;
  redemption.save();

  const participation = getOrCreateRaffleAccount(raffle, event.params.owner);
  participation.refundsRedeemed = participation.refundsRedeemed.plus(
    event.params.amount,
  );
  participation.save();
  const quoteToken = QuoteTokenStats.load(raffle.quoteTokenStats);
  if (quoteToken != null) {
    quoteToken.refundedVolume = quoteToken.refundedVolume.plus(
      event.params.amount,
    );
    const stats = getOrCreateAccountTokenStats(quoteToken, event.params.owner);
    stats.refundsRedeemed = stats.refundsRedeemed.plus(event.params.amount);
    stats.save();
    quoteToken.save();
  }
}

export function handleWinningTicketRedeemed(
  event: WinningTicketRedeemed,
): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null || WinningRedemption.load(eventId(event)) != null) return;
  const owner = getOrCreateAccount(event.params.owner);
  raffle.winningTicketRedeemed = true;
  if (event.params.result == 3) {
    const protocolFee = raffle.grossSales
      .times(BigInt.fromI32(500))
      .div(BigInt.fromI32(10_000));
    const distributable = raffle.grossSales.minus(protocolFee);
    raffle.prizeClaimed = true;
    raffle.prizeDestination = event.params.to;
    raffle.prizeClaimedTxHash = event.transaction.hash;
    raffle.unsettledPot = BigInt.zero();
    raffle.totalClaimableQuote = raffle.totalClaimableQuote.plus(
      raffle.grossSales,
    );
    raffle.totalProtocolFees = raffle.totalProtocolFees.plus(protocolFee);
    const quoteToken = QuoteTokenStats.load(raffle.quoteTokenStats);
    if (quoteToken != null) {
      quoteToken.protocolFees = quoteToken.protocolFees.plus(protocolFee);
      quoteToken.settledVolume = quoteToken.settledVolume.plus(distributable);
      quoteToken.save();
    }
    updateSettlementDayData(raffle, event, protocolFee, distributable);
  } else {
    raffle.winnerCashLiability = BigInt.zero();
  }
  raffle.save();

  const redemption = new WinningRedemption(eventId(event));
  redemption.raffle = raffle.id;
  redemption.ticketId = event.params.ticketId;
  redemption.owner = owner.id;
  redemption.destination = event.params.to;
  redemption.result = statusName(event.params.result);
  redemption.cashAmount = event.params.cashAmount;
  redemption.transactionHash = event.transaction.hash;
  redemption.blockNumber = event.block.number;
  redemption.timestamp = event.block.timestamp;
  redemption.logIndex = event.logIndex;
  redemption.save();

  if (event.params.cashAmount.gt(BigInt.zero())) {
    const participation = getOrCreateRaffleAccount(raffle, event.params.owner);
    participation.winnerCashRedeemed = participation.winnerCashRedeemed.plus(
      event.params.cashAmount,
    );
    participation.save();
    const quoteToken = QuoteTokenStats.load(raffle.quoteTokenStats);
    if (quoteToken != null) {
      quoteToken.winnerCashRedeemed = quoteToken.winnerCashRedeemed.plus(
        event.params.cashAmount,
      );
      const stats = getOrCreateAccountTokenStats(
        quoteToken,
        event.params.owner,
      );
      stats.winnerCashRedeemed = stats.winnerCashRedeemed.plus(
        event.params.cashAmount,
      );
      stats.save();
      quoteToken.save();
    }
  }
}

export function handleQuoteClaimed(event: QuoteClaimedEvent): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null || QuoteClaim.load(eventId(event)) != null) return;
  const account = getOrCreateAccount(event.params.account);
  raffle.quoteClaimed = raffle.quoteClaimed.plus(event.params.amount);
  raffle.totalClaimableQuote = raffle.totalClaimableQuote.minus(
    event.params.amount,
  );
  raffle.save();

  const quoteToken = QuoteTokenStats.load(raffle.quoteTokenStats);
  if (quoteToken != null) {
    quoteToken.quoteClaimed = quoteToken.quoteClaimed.plus(event.params.amount);
    const stats = getOrCreateAccountTokenStats(
      quoteToken,
      event.params.account,
    );
    stats.quoteClaimed = stats.quoteClaimed.plus(event.params.amount);
    stats.save();
    quoteToken.save();
  }
  const participation = getOrCreateRaffleAccount(raffle, event.params.account);
  participation.quoteClaimed = participation.quoteClaimed.plus(
    event.params.amount,
  );
  participation.save();

  const claim = new QuoteClaim(eventId(event));
  claim.raffle = raffle.id;
  claim.account = account.id;
  claim.destination = event.params.to;
  claim.amount = event.params.amount;
  claim.transactionHash = event.transaction.hash;
  claim.blockNumber = event.block.number;
  claim.timestamp = event.block.timestamp;
  claim.logIndex = event.logIndex;
  claim.save();
}

export function handleSponsorPrizeClaimed(
  event: SponsorPrizeClaimedEvent,
): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null || SponsorPrizeClaim.load(eventId(event)) != null) return;
  const recipient = getOrCreateAccount(event.params.recipient);
  raffle.prizeClaimed = true;
  raffle.prizeDestination = event.params.to;
  raffle.prizeClaimedTxHash = event.transaction.hash;
  raffle.save();

  const claim = new SponsorPrizeClaim(eventId(event));
  claim.raffle = raffle.id;
  claim.recipient = recipient.id;
  claim.destination = event.params.to;
  claim.prizeToken = event.params.prizeToken;
  claim.prizeTokenId = event.params.prizeTokenId;
  claim.transactionHash = event.transaction.hash;
  claim.blockNumber = event.block.number;
  claim.timestamp = event.block.timestamp;
  claim.logIndex = event.logIndex;
  claim.save();
}

export function handleEmptyRaffleClosed(event: EmptyRaffleClosed): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null || raffle.status != "ACTIVE") return;
  raffle.status = "CLOSED";
  raffle.resolvedTxHash = event.transaction.hash;
  raffle.resolvedBlock = event.block.number;
  raffle.resolvedTimestamp = event.block.timestamp;
  raffle.save();

  const protocol = Protocol.load(raffle.protocol);
  if (protocol != null) {
    protocol.activeCount = protocol.activeCount.minus(ONE);
    protocol.closedCount = protocol.closedCount.plus(ONE);
    protocol.save();
  }
  updateResolutionDayData(raffle, event, BigInt.zero(), BigInt.zero());
}
