import { Address, BigInt } from "@graphprotocol/graph-ts";

import {
  DrawRequested as DrawRequestedEvent,
  NoSalesClosed,
  PrizeClaimed as PrizeClaimedEvent,
  PrizeDeposited,
  QuoteClaimed as QuoteClaimedEvent,
  RaffleCancelled,
  RaffleResolved,
  TicketsPurchased,
  Transfer,
} from "../generated/templates/Raffle/Raffle";
import {
  DrawRequest,
  PrizeClaim,
  Protocol,
  Purchase,
  QuoteTokenStats,
  QuoteClaim,
  Raffle,
  RaffleTransfer,
  Resolution,
  Ticket,
} from "../generated/schema";
import {
  eventId,
  getOrCreateAccount,
  getOrCreateAccountTokenStats,
  getOrCreateProtocol,
  getOrCreateRaffleAccount,
  ticketId,
  updatePurchaseDayData,
  updateResolutionDayData,
} from "./helpers";

const ZERO_ADDRESS = Address.zero();

export function handlePrizeDeposited(event: PrizeDeposited): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null) return;
  raffle.state = "ACTIVE";
  raffle.save();
}

export function handleTicketsPurchased(event: TicketsPurchased): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null) return;
  if (Purchase.load(eventId(event)) != null) return;

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
    const buyerTokenStats = getOrCreateAccountTokenStats(
      quoteToken,
      event.params.buyer,
    );
    buyerTokenStats.grossSpent = buyerTokenStats.grossSpent.plus(
      event.params.grossAmount,
    );
    buyerTokenStats.save();
  }
  const buyerParticipation = getOrCreateRaffleAccount(
    raffle,
    event.params.buyer,
  );
  buyerParticipation.ticketsBought = buyerParticipation.ticketsBought.plus(
    event.params.quantity,
  );
  buyerParticipation.grossSpent = buyerParticipation.grossSpent.plus(
    event.params.grossAmount,
  );
  buyerParticipation.save();

  const protocol = Protocol.load(raffle.protocol);
  if (protocol != null) {
    protocol.totalTickets = protocol.totalTickets.plus(event.params.quantity);
    protocol.save();
  }
  if (quoteToken != null) {
    quoteToken.grossVolume = quoteToken.grossVolume.plus(
      event.params.grossAmount,
    );
    quoteToken.save();
  }

  let current = event.params.firstTicketId;
  while (current.le(event.params.lastTicketId)) {
    const ticket = Ticket.load(ticketId(raffle.id, current));
    if (ticket != null) {
      ticket.purchase = purchase.id;
      ticket.save();
    }
    current = current.plus(BigInt.fromI32(1));
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
  if (raffle == null) return;
  if (RaffleTransfer.load(eventId(event)) != null) return;
  const id = ticketId(raffle.id, event.params.tokenId);
  let ticket = Ticket.load(id);

  if (event.params.from != ZERO_ADDRESS) {
    const from = getOrCreateAccount(event.params.from);
    from.ticketsCurrentlyOwned = from.ticketsCurrentlyOwned.minus(
      BigInt.fromI32(1),
    );
    from.save();
    const fromParticipation = getOrCreateRaffleAccount(
      raffle,
      event.params.from,
    );
    fromParticipation.ticketsCurrentlyOwned =
      fromParticipation.ticketsCurrentlyOwned.minus(BigInt.fromI32(1));
    fromParticipation.save();
  }

  if (event.params.to != ZERO_ADDRESS) {
    const to = getOrCreateAccount(event.params.to);
    to.ticketsCurrentlyOwned = to.ticketsCurrentlyOwned.plus(BigInt.fromI32(1));
    to.save();
    const toParticipation = getOrCreateRaffleAccount(raffle, event.params.to);
    toParticipation.ticketsCurrentlyOwned =
      toParticipation.ticketsCurrentlyOwned.plus(BigInt.fromI32(1));
    toParticipation.save();

    if (ticket == null) {
      ticket = new Ticket(id);
      ticket.raffle = raffle.id;
      ticket.ticketId = event.params.tokenId;
      ticket.originalRecipient = to.id;
      ticket.winning = false;
    }
    ticket.currentOwner = to.id;
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
  if (raffle == null) return;
  if (DrawRequest.load(eventId(event)) != null) return;
  const requester = getOrCreateAccount(event.params.requester);
  const request = new DrawRequest(eventId(event));
  request.raffle = raffle.id;
  request.sequenceNumber = event.params.sequenceNumber;
  request.requester = requester.id;
  request.fee = event.params.fee;
  request.excessCredited = event.params.excessCredited;
  request.transactionHash = event.transaction.hash;
  request.blockNumber = event.block.number;
  request.timestamp = event.block.timestamp;
  request.logIndex = event.logIndex;
  request.save();

  raffle.state = "DRAW_REQUESTED";
  raffle.entropySequenceNumber = event.params.sequenceNumber;
  raffle.requestedTxHash = event.transaction.hash;
  raffle.requestedBlock = event.block.number;
  raffle.requestedTimestamp = event.block.timestamp;
  raffle.save();
}

export function handleRaffleResolved(event: RaffleResolved): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null) return;
  if (Resolution.load(eventId(event)) != null) return;
  const winner = getOrCreateAccount(event.params.winner);
  const claimant = getOrCreateAccount(event.params.prizeClaimant);
  const outcome = event.params.outcome == 1 ? "NFT_AWARDED" : "CASH_FALLBACK";

  raffle.state = "RESOLVED";
  raffle.outcome = outcome;
  raffle.entropySequenceNumber = event.params.sequenceNumber;
  raffle.winningTicketId = event.params.winningTicketId;
  raffle.winner = winner.id;
  raffle.prizeClaimant = claimant.id;
  raffle.unsettledPot = BigInt.zero();
  raffle.totalProtocolFees = raffle.totalProtocolFees.plus(
    event.params.protocolFee,
  );
  raffle.resolvedTxHash = event.transaction.hash;
  raffle.resolvedBlock = event.block.number;
  raffle.resolvedTimestamp = event.block.timestamp;
  raffle.save();

  winner.rafflesWon = winner.rafflesWon.plus(BigInt.fromI32(1));
  winner.save();
  const winnerParticipation = getOrCreateRaffleAccount(
    raffle,
    event.params.winner,
  );
  winnerParticipation.won = true;
  winnerParticipation.save();

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
  resolution.winner = winner.id;
  resolution.outcome = outcome;
  resolution.prizeClaimant = claimant.id;
  resolution.protocolFee = event.params.protocolFee;
  resolution.distributablePot = event.params.winnerCashAmount.plus(
    event.params.sponsorCashAmount,
  );
  resolution.winnerCashAmount = event.params.winnerCashAmount;
  resolution.sponsorCashAmount = event.params.sponsorCashAmount;
  resolution.transactionHash = event.transaction.hash;
  resolution.blockNumber = event.block.number;
  resolution.timestamp = event.block.timestamp;
  resolution.logIndex = event.logIndex;
  resolution.save();

  const protocol = Protocol.load(raffle.protocol);
  if (protocol != null) {
    protocol.activeCount = protocol.activeCount.minus(BigInt.fromI32(1));
    protocol.resolvedCount = protocol.resolvedCount.plus(BigInt.fromI32(1));
    if (event.params.outcome == 1) {
      protocol.nftAwardedCount = protocol.nftAwardedCount.plus(
        BigInt.fromI32(1),
      );
    } else {
      protocol.cashFallbackCount = protocol.cashFallbackCount.plus(
        BigInt.fromI32(1),
      );
    }
    protocol.save();
  }
  const quoteToken = QuoteTokenStats.load(raffle.quoteTokenStats);
  const distributablePot = event.params.winnerCashAmount.plus(
    event.params.sponsorCashAmount,
  );
  if (quoteToken != null) {
    quoteToken.protocolFees = quoteToken.protocolFees.plus(
      event.params.protocolFee,
    );
    quoteToken.settledVolume = quoteToken.settledVolume.plus(distributablePot);
    quoteToken.save();
  }
  updateResolutionDayData(
    raffle,
    event,
    event.params.protocolFee,
    distributablePot,
  );
}

export function handleQuoteClaimed(event: QuoteClaimedEvent): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null) return;
  if (QuoteClaim.load(eventId(event)) != null) return;
  const account = getOrCreateAccount(event.params.account);
  const quoteToken = QuoteTokenStats.load(raffle.quoteTokenStats);
  if (quoteToken != null) {
    const accountTokenStats = getOrCreateAccountTokenStats(
      quoteToken,
      event.params.account,
    );
    accountTokenStats.quoteClaimed = accountTokenStats.quoteClaimed.plus(
      event.params.amount,
    );
    accountTokenStats.save();
  }
  const participation = getOrCreateRaffleAccount(raffle, event.params.account);
  participation.quoteClaimed = participation.quoteClaimed.plus(
    event.params.amount,
  );
  participation.save();

  raffle.quoteClaimed = raffle.quoteClaimed.plus(event.params.amount);
  raffle.save();
  if (quoteToken != null) {
    quoteToken.quoteClaimed = quoteToken.quoteClaimed.plus(event.params.amount);
    quoteToken.save();
  }

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

export function handlePrizeClaimed(event: PrizeClaimedEvent): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null) return;
  if (PrizeClaim.load(eventId(event)) != null) return;
  const claimant = getOrCreateAccount(event.params.claimant);
  raffle.prizeClaimed = true;
  raffle.prizeDestination = event.params.to;
  raffle.prizeClaimedTxHash = event.transaction.hash;
  raffle.save();

  const claim = new PrizeClaim(eventId(event));
  claim.raffle = raffle.id;
  claim.claimant = claimant.id;
  claim.destination = event.params.to;
  claim.prizeToken = event.params.prizeToken;
  claim.prizeTokenId = event.params.prizeTokenId;
  claim.transactionHash = event.transaction.hash;
  claim.blockNumber = event.block.number;
  claim.timestamp = event.block.timestamp;
  claim.logIndex = event.logIndex;
  claim.save();
}

export function handleRaffleCancelled(event: RaffleCancelled): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null) return;
  if (raffle.outcome != "NONE") return;
  raffle.state = "CANCELLED";
  raffle.outcome = "CANCELLED_BEFORE_SALE";
  raffle.prizeClaimant = event.params.sponsor;
  raffle.save();

  const protocol = getOrCreateProtocol(Address.fromBytes(raffle.protocol));
  protocol.activeCount = protocol.activeCount.minus(BigInt.fromI32(1));
  protocol.cancelledCount = protocol.cancelledCount.plus(BigInt.fromI32(1));
  protocol.save();
}

export function handleNoSalesClosed(event: NoSalesClosed): void {
  const raffle = Raffle.load(event.address);
  if (raffle == null) return;
  if (raffle.outcome != "NONE") return;
  raffle.state = "RESOLVED";
  raffle.outcome = "NO_SALES";
  raffle.prizeClaimant = event.params.sponsor;
  raffle.resolvedTxHash = event.transaction.hash;
  raffle.resolvedBlock = event.block.number;
  raffle.resolvedTimestamp = event.block.timestamp;
  raffle.save();

  const protocol = getOrCreateProtocol(Address.fromBytes(raffle.protocol));
  protocol.activeCount = protocol.activeCount.minus(BigInt.fromI32(1));
  protocol.resolvedCount = protocol.resolvedCount.plus(BigInt.fromI32(1));
  protocol.save();
  updateResolutionDayData(raffle, event, BigInt.zero(), BigInt.zero());
}
