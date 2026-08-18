import { Address, BigInt, ethereum } from "@graphprotocol/graph-ts";

import {
  DrawRequested as DrawRequestedEvent,
  ProtocolFeesReleased,
  RaffleResolved,
  SponsorProceedsReleased,
  TicketPurchased,
  TicketsRefunded,
  RefundsEnabled,
  SponsorPrizeReleased,
  Transfer,
  VrfCallbackIgnored,
  WinningTicketSettled,
} from "../generated/templates/Raffle/Raffle";
import {
  DrawRequest,
  IgnoredVrfCallback,
  Protocol,
  Purchase,
  ProceedsRelease,
  QuoteTokenStats,
  Raffle,
  RaffleTransfer,
  Ticket,
  RefundEnable,
  RefundRedemption,
  Resolution,
  SponsorPrizeRelease,
  WinningSettlement,
} from "../generated/schema";
import {
  eventId,
  getOrCreateAccount,
  getOrCreateAccountTokenStats,
  getOrCreateRaffleAccount,
  ticketEntityId,
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
  if (value == 2) return "DRAWING";
  if (value == 1) return "ACTIVE";
  return "AWAITING_PRIZE";
}

export function handleTicketPurchased(event: TicketPurchased): void {
  const raffle = Raffle.load(event.address);
  const purchaseId = eventId(event);
  if (raffle == null || Purchase.load(purchaseId) != null) return;

  const buyer = getOrCreateAccount(event.params.buyer);
  const recipient = getOrCreateAccount(event.params.recipient);
  const id = ticketEntityId(raffle.id, event.params.ticketId);
  let ticket = Ticket.load(id);
  if (ticket == null) {
    // Transfer is emitted before TicketPurchased, but keep the mapping robust
    // to partial historical replays without enumerating any entry.
    ticket = new Ticket(id);
    ticket.raffle = raffle.id;
    ticket.ticketId = event.params.ticketId;
    ticket.originalRecipient = recipient.id;
    ticket.currentOwner = recipient.id;
    ticket.winning = false;
    ticket.burned = false;
  }

  const purchase = new Purchase(purchaseId);
  purchase.raffle = raffle.id;
  purchase.ticket = ticket.id;
  purchase.buyer = buyer.id;
  purchase.recipient = recipient.id;
  purchase.entryCount = event.params.entryCount;
  purchase.firstEntry = event.params.firstEntry;
  purchase.lastEntry = event.params.lastEntry;
  purchase.grossAmount = event.params.grossAmount;
  purchase.transactionHash = event.transaction.hash;
  purchase.blockNumber = event.block.number;
  purchase.timestamp = event.block.timestamp;
  purchase.logIndex = event.logIndex;
  purchase.save();

  ticket.firstEntry = event.params.firstEntry;
  ticket.lastEntry = event.params.lastEntry;
  ticket.entryCount = event.params.entryCount;
  ticket.purchase = purchase.id;
  ticket.save();

  raffle.totalEntries = raffle.totalEntries.plus(event.params.entryCount);
  raffle.ticketCount = raffle.ticketCount.plus(ONE);
  raffle.grossSales = raffle.grossSales.plus(event.params.grossAmount);
  raffle.unsettledPot = raffle.unsettledPot.plus(event.params.grossAmount);
  raffle.save();

  buyer.entriesBought = buyer.entriesBought.plus(event.params.entryCount);
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
  participation.entriesBought = participation.entriesBought.plus(
    event.params.entryCount,
  );
  participation.grossSpent = participation.grossSpent.plus(
    event.params.grossAmount,
  );
  participation.save();

  const protocol = Protocol.load(raffle.protocol);
  if (protocol != null) {
    protocol.totalEntries = protocol.totalEntries.plus(event.params.entryCount);
    protocol.save();
  }

  updatePurchaseDayData(
    raffle,
    event,
    event.params.entryCount,
    event.params.grossAmount,
  );
}

export function handleTransfer(event: Transfer): void {
  const raffle = Raffle.load(event.address);
  const transferId = eventId(event);
  if (raffle == null || RaffleTransfer.load(transferId) != null) return;

  const id = ticketEntityId(raffle.id, event.params.tokenId);
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
    const transfer = new RaffleTransfer(transferId);
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
  const requestEntityId = eventId(event);
  if (raffle == null || DrawRequest.load(requestEntityId) != null) return;

  const requester = getOrCreateAccount(event.params.requester);
  const request = new DrawRequest(requestEntityId);
  request.raffle = raffle.id;
  request.requestId = event.params.requestId;
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
  raffle.vrfRequestId = event.params.requestId;
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

export function handleVrfCallbackIgnored(event: VrfCallbackIgnored): void {
  const raffle = Raffle.load(event.address);
  const callbackId = eventId(event);
  if (raffle == null || IgnoredVrfCallback.load(callbackId) != null) return;

  const callback = new IgnoredVrfCallback(callbackId);
  callback.raffle = raffle.id;
  callback.receivedRequestId = event.params.receivedRequestId;
  callback.expectedRequestId = event.params.expectedRequestId;
  callback.status = statusName(event.params.status);
  callback.transactionHash = event.transaction.hash;
  callback.blockNumber = event.block.number;
  callback.timestamp = event.block.timestamp;
  callback.logIndex = event.logIndex;
  callback.save();

  raffle.ignoredVrfCallbackCount = raffle.ignoredVrfCallbackCount.plus(ONE);
  raffle.save();
}

export function handleRaffleResolved(event: RaffleResolved): void {
  const raffle = Raffle.load(event.address);
  const resolutionId = eventId(event);
  if (raffle == null || Resolution.load(resolutionId) != null) return;

  const result = statusName(event.params.result);
  const nftResult = event.params.result == 3;
  raffle.status = result;
  raffle.vrfRequestId = event.params.requestId;
  raffle.winningEntry = event.params.winningEntry;
  raffle.resolvedTxHash = event.transaction.hash;
  raffle.resolvedBlock = event.block.number;
  raffle.resolvedTimestamp = event.block.timestamp;
  raffle.save();

  const resolution = new Resolution(resolutionId);
  resolution.raffle = raffle.id;
  resolution.requestId = event.params.requestId;
  resolution.winningEntry = event.params.winningEntry;
  resolution.result = result;
  resolution.transactionHash = event.transaction.hash;
  resolution.blockNumber = event.block.number;
  resolution.timestamp = event.block.timestamp;
  resolution.logIndex = event.logIndex;
  resolution.save();

  const protocol = Protocol.load(raffle.protocol);
  if (protocol != null) {
    protocol.drawingCount = protocol.drawingCount.minus(ONE);
    if (nftResult) {
      protocol.nftWonCount = protocol.nftWonCount.plus(ONE);
    } else {
      protocol.cashWonCount = protocol.cashWonCount.plus(ONE);
    }
    protocol.save();
  }

  updateResolutionDayData(raffle, event, BigInt.zero(), BigInt.zero());
}

export function handleRefundsEnabled(event: RefundsEnabled): void {
  const raffle = Raffle.load(event.address);
  const enableId = eventId(event);
  if (raffle == null || RefundEnable.load(enableId) != null) return;

  const previousStatus = raffle.status;
  const finalizer = getOrCreateAccount(event.params.finalizer);
  raffle.status = "REFUNDING";
  raffle.unsettledPot = BigInt.zero();
  raffle.remainingRefundLiability = event.params.remainingRefundLiability;
  raffle.resolvedTxHash = event.transaction.hash;
  raffle.resolvedBlock = event.block.number;
  raffle.resolvedTimestamp = event.block.timestamp;
  raffle.save();

  const enable = new RefundEnable(enableId);
  enable.raffle = raffle.id;
  enable.finalizer = finalizer.id;
  enable.remainingRefundLiability = event.params.remainingRefundLiability;
  enable.transactionHash = event.transaction.hash;
  enable.blockNumber = event.block.number;
  enable.timestamp = event.block.timestamp;
  enable.logIndex = event.logIndex;
  enable.save();

  const protocol = Protocol.load(raffle.protocol);
  if (protocol != null) {
    if (previousStatus == "DRAWING") {
      protocol.drawingCount = protocol.drawingCount.minus(ONE);
    } else if (previousStatus == "ACTIVE") {
      protocol.activeCount = protocol.activeCount.minus(ONE);
    }
    protocol.refundingCount = protocol.refundingCount.plus(ONE);
    protocol.save();
  }
}

export function handleTicketsRefunded(event: TicketsRefunded): void {
  const raffle = Raffle.load(event.address);
  const redemptionId = eventId(event);
  if (raffle == null || RefundRedemption.load(redemptionId) != null) return;

  const owner = getOrCreateAccount(event.params.owner);
  raffle.remainingRefundLiability = event.params.remainingRefundLiability;
  raffle.totalRefundRedeemed = raffle.totalRefundRedeemed.plus(
    event.params.amount,
  );
  raffle.save();

  const redemption = new RefundRedemption(redemptionId);
  redemption.raffle = raffle.id;
  redemption.owner = owner.id;
  redemption.ticketQuantity = event.params.ticketQuantity;
  redemption.entryQuantity = event.params.entryQuantity;
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

export function handleWinningTicketSettled(event: WinningTicketSettled): void {
  const raffle = Raffle.load(event.address);
  const settlementId = eventId(event);
  if (raffle == null || WinningSettlement.load(settlementId) != null) return;

  const winner = getOrCreateAccount(event.params.winner);
  raffle.winningTicketId = event.params.ticketId;
  raffle.winningTicketSettled = true;
  raffle.unsettledPot = BigInt.zero();
  raffle.sponsorProceeds = raffle.sponsorProceeds.plus(
    event.params.sponsorAmount,
  );
  raffle.protocolFees = raffle.protocolFees.plus(event.params.protocolFee);
  raffle.totalProtocolFees = raffle.totalProtocolFees.plus(
    event.params.protocolFee,
  );
  if (event.params.result == 3) {
    raffle.prizeClaimed = true;
    raffle.prizeDestination = event.params.winner;
    raffle.prizeClaimedTxHash = event.transaction.hash;
  }
  raffle.save();

  const ticket = Ticket.load(ticketEntityId(raffle.id, event.params.ticketId));
  if (ticket != null) {
    ticket.winning = true;
    ticket.save();
  }

  const settlement = new WinningSettlement(settlementId);
  settlement.raffle = raffle.id;
  settlement.ticketId = event.params.ticketId;
  settlement.winner = winner.id;
  settlement.result = statusName(event.params.result);
  settlement.cashAmount = event.params.cashAmount;
  settlement.protocolFee = event.params.protocolFee;
  settlement.sponsorAmount = event.params.sponsorAmount;
  settlement.transactionHash = event.transaction.hash;
  settlement.blockNumber = event.block.number;
  settlement.timestamp = event.block.timestamp;
  settlement.logIndex = event.logIndex;
  settlement.save();

  const quoteToken = QuoteTokenStats.load(raffle.quoteTokenStats);
  if (quoteToken != null) {
    quoteToken.protocolFees = quoteToken.protocolFees.plus(
      event.params.protocolFee,
    );
    quoteToken.settledVolume = quoteToken.settledVolume
      .plus(event.params.cashAmount)
      .plus(event.params.sponsorAmount);
    if (event.params.cashAmount.gt(BigInt.zero())) {
      quoteToken.winnerCashRedeemed = quoteToken.winnerCashRedeemed.plus(
        event.params.cashAmount,
      );
      const stats = getOrCreateAccountTokenStats(
        quoteToken,
        event.params.winner,
      );
      stats.winnerCashRedeemed = stats.winnerCashRedeemed.plus(
        event.params.cashAmount,
      );
      stats.save();
    }
    quoteToken.save();
  }

  if (event.params.cashAmount.gt(BigInt.zero())) {
    const participation = getOrCreateRaffleAccount(raffle, event.params.winner);
    participation.winnerCashRedeemed = participation.winnerCashRedeemed.plus(
      event.params.cashAmount,
    );
    participation.save();
  }

  updateSettlementDayData(
    raffle,
    event,
    event.params.protocolFee,
    event.params.cashAmount.plus(event.params.sponsorAmount),
  );
}

function recordProceedsRelease(
  raffle: Raffle,
  id: string,
  callerAddress: Address,
  recipientAddress: Address,
  amount: BigInt,
  kind: string,
  event: ethereum.Event,
): void {
  const caller = getOrCreateAccount(callerAddress);
  const recipient = getOrCreateAccount(recipientAddress);
  raffle.quoteClaimed = raffle.quoteClaimed.plus(amount);
  if (kind == "SPONSOR")
    raffle.sponsorProceeds = raffle.sponsorProceeds.minus(amount);
  else raffle.protocolFees = raffle.protocolFees.minus(amount);
  raffle.save();

  const quoteToken = QuoteTokenStats.load(raffle.quoteTokenStats);
  if (quoteToken != null) {
    quoteToken.quoteClaimed = quoteToken.quoteClaimed.plus(amount);
    const stats = getOrCreateAccountTokenStats(quoteToken, recipientAddress);
    stats.quoteClaimed = stats.quoteClaimed.plus(amount);
    stats.save();
    quoteToken.save();
  }

  const participation = getOrCreateRaffleAccount(raffle, recipientAddress);
  participation.quoteClaimed = participation.quoteClaimed.plus(amount);
  participation.save();

  const release = new ProceedsRelease(id);
  release.raffle = raffle.id;
  release.caller = caller.id;
  release.recipient = recipient.id;
  release.kind = kind;
  release.amount = amount;
  release.transactionHash = event.transaction.hash;
  release.blockNumber = event.block.number;
  release.timestamp = event.block.timestamp;
  release.logIndex = event.logIndex;
  release.save();
}

export function handleSponsorProceedsReleased(
  event: SponsorProceedsReleased,
): void {
  const raffle = Raffle.load(event.address);
  const id = eventId(event);
  if (raffle == null || ProceedsRelease.load(id) != null) return;
  recordProceedsRelease(
    raffle,
    id,
    event.params.caller,
    event.params.recipient,
    event.params.amount,
    "SPONSOR",
    event,
  );
}

export function handleProtocolFeesReleased(event: ProtocolFeesReleased): void {
  const raffle = Raffle.load(event.address);
  const id = eventId(event);
  if (raffle == null || ProceedsRelease.load(id) != null) return;
  recordProceedsRelease(
    raffle,
    id,
    event.params.caller,
    event.params.treasury,
    event.params.amount,
    "PROTOCOL",
    event,
  );
}

export function handleSponsorPrizeReleased(event: SponsorPrizeReleased): void {
  const raffle = Raffle.load(event.address);
  const releaseId = eventId(event);
  if (raffle == null || SponsorPrizeRelease.load(releaseId) != null) return;

  const caller = getOrCreateAccount(event.params.caller);
  const recipient = getOrCreateAccount(event.params.recipient);
  raffle.prizeClaimed = true;
  raffle.prizeDestination = event.params.recipient;
  raffle.prizeClaimedTxHash = event.transaction.hash;
  raffle.save();

  const release = new SponsorPrizeRelease(releaseId);
  release.raffle = raffle.id;
  release.caller = caller.id;
  release.recipient = recipient.id;
  release.prizeToken = event.params.prizeToken;
  release.prizeTokenId = event.params.prizeTokenId;
  release.transactionHash = event.transaction.hash;
  release.blockNumber = event.block.number;
  release.timestamp = event.block.timestamp;
  release.logIndex = event.logIndex;
  release.save();
}
