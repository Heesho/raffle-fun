import { Address, BigInt, Bytes, ethereum } from "@graphprotocol/graph-ts";

import {
  Account,
  AccountTokenStats,
  Protocol,
  ProtocolDayData,
  QuoteTokenStats,
  Raffle,
  RaffleAccount,
  RaffleDayData,
} from "../generated/schema";

const SECONDS_PER_DAY = BigInt.fromI32(86_400);

export function getOrCreateProtocol(factory: Address): Protocol {
  let protocol = Protocol.load(factory);
  if (protocol == null) {
    protocol = new Protocol(factory);
    protocol.raffleCount = BigInt.zero();
    protocol.activeCount = BigInt.zero();
    protocol.drawingCount = BigInt.zero();
    protocol.nftWonCount = BigInt.zero();
    protocol.cashWonCount = BigInt.zero();
    protocol.refundingCount = BigInt.zero();
    protocol.closedCount = BigInt.zero();
    protocol.totalTickets = BigInt.zero();
    protocol.save();
  }
  return protocol;
}

export function getOrCreateAccount(address: Address): Account {
  let account = Account.load(address);
  if (account == null) {
    account = new Account(address);
    account.ticketsBought = BigInt.zero();
    account.ticketsCurrentlyOwned = BigInt.zero();
    account.rafflesSponsored = BigInt.zero();
    account.save();
  }
  return account;
}

export function quoteTokenStatsId(protocol: Bytes, token: Bytes): string {
  return protocol.toHexString() + "-" + token.toHexString();
}

export function getOrCreateQuoteTokenStats(
  protocol: Protocol,
  token: Address,
): QuoteTokenStats {
  const id = quoteTokenStatsId(protocol.id, token);
  let stats = QuoteTokenStats.load(id);
  if (stats == null) {
    stats = new QuoteTokenStats(id);
    stats.protocol = protocol.id;
    stats.token = token;
    stats.raffleCount = BigInt.zero();
    stats.grossVolume = BigInt.zero();
    stats.settledVolume = BigInt.zero();
    stats.protocolFees = BigInt.zero();
    stats.quoteClaimed = BigInt.zero();
    stats.refundedVolume = BigInt.zero();
    stats.winnerCashRedeemed = BigInt.zero();
    stats.save();
  }
  return stats;
}

export function getOrCreateAccountTokenStats(
  quoteToken: QuoteTokenStats,
  account: Address,
): AccountTokenStats {
  const id = quoteToken.id + "-" + account.toHexString();
  let stats = AccountTokenStats.load(id);
  if (stats == null) {
    stats = new AccountTokenStats(id);
    stats.account = account;
    stats.quoteToken = quoteToken.id;
    stats.grossSpent = BigInt.zero();
    stats.quoteClaimed = BigInt.zero();
    stats.refundsRedeemed = BigInt.zero();
    stats.winnerCashRedeemed = BigInt.zero();
    stats.save();
  }
  return stats;
}

export function getOrCreateRaffleAccount(
  raffle: Raffle,
  address: Address,
): RaffleAccount {
  const id = raffle.id.toHexString() + "-" + address.toHexString();
  let participation = RaffleAccount.load(id);
  if (participation == null) {
    participation = new RaffleAccount(id);
    participation.raffle = raffle.id;
    participation.account = address;
    participation.ticketsBought = BigInt.zero();
    participation.ticketsCurrentlyOwned = BigInt.zero();
    participation.grossSpent = BigInt.zero();
    participation.quoteClaimed = BigInt.zero();
    participation.refundsRedeemed = BigInt.zero();
    participation.winnerCashRedeemed = BigInt.zero();
    participation.save();
  }
  return participation;
}

export function eventId(event: ethereum.Event): string {
  return event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
}

export function ticketId(raffle: Bytes, tokenId: BigInt): string {
  return raffle.toHexString() + "-" + tokenId.toString();
}

export function updatePurchaseDayData(
  raffle: Raffle,
  event: ethereum.Event,
  tickets: BigInt,
  gross: BigInt,
): void {
  const day = event.block.timestamp.div(SECONDS_PER_DAY);
  const dayStart = day.times(SECONDS_PER_DAY);
  const protocolId = raffle.protocol;
  const protocolDayId = raffle.quoteTokenStats + "-" + day.toString();
  let protocolDay = ProtocolDayData.load(protocolDayId);
  if (protocolDay == null) {
    protocolDay = new ProtocolDayData(protocolDayId);
    protocolDay.protocol = protocolId;
    protocolDay.quoteToken = raffle.quoteTokenStats;
    protocolDay.dayStart = dayStart;
    protocolDay.tickets = BigInt.zero();
    protocolDay.grossVolume = BigInt.zero();
    protocolDay.settledVolume = BigInt.zero();
    protocolDay.protocolFees = BigInt.zero();
    protocolDay.resolutions = BigInt.zero();
  }
  protocolDay.tickets = protocolDay.tickets.plus(tickets);
  protocolDay.grossVolume = protocolDay.grossVolume.plus(gross);
  protocolDay.save();

  const raffleDayId = raffle.id.toHexString() + "-" + day.toString();
  let raffleDay = RaffleDayData.load(raffleDayId);
  if (raffleDay == null) {
    raffleDay = new RaffleDayData(raffleDayId);
    raffleDay.raffle = raffle.id;
    raffleDay.dayStart = dayStart;
    raffleDay.tickets = BigInt.zero();
    raffleDay.grossVolume = BigInt.zero();
  }
  raffleDay.tickets = raffleDay.tickets.plus(tickets);
  raffleDay.grossVolume = raffleDay.grossVolume.plus(gross);
  raffleDay.save();
}

export function updateResolutionDayData(
  raffle: Raffle,
  event: ethereum.Event,
  protocolFee: BigInt,
  distributablePot: BigInt,
): void {
  const day = event.block.timestamp.div(SECONDS_PER_DAY);
  const id = raffle.quoteTokenStats + "-" + day.toString();
  let data = ProtocolDayData.load(id);
  if (data == null) {
    updatePurchaseDayData(raffle, event, BigInt.zero(), BigInt.zero());
    data = ProtocolDayData.load(id);
  }
  if (data != null) {
    data.protocolFees = data.protocolFees.plus(protocolFee);
    data.settledVolume = data.settledVolume.plus(distributablePot);
    data.resolutions = data.resolutions.plus(BigInt.fromI32(1));
    data.save();
  }
}

export function updateSettlementDayData(
  raffle: Raffle,
  event: ethereum.Event,
  protocolFee: BigInt,
  distributablePot: BigInt,
): void {
  const day = event.block.timestamp.div(SECONDS_PER_DAY);
  const id = raffle.quoteTokenStats + "-" + day.toString();
  let data = ProtocolDayData.load(id);
  if (data == null) {
    updatePurchaseDayData(raffle, event, BigInt.zero(), BigInt.zero());
    data = ProtocolDayData.load(id);
  }
  if (data != null) {
    data.protocolFees = data.protocolFees.plus(protocolFee);
    data.settledVolume = data.settledVolume.plus(distributablePot);
    data.save();
  }
}
