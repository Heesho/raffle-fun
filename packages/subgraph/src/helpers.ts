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
    protocol.resolvedCount = BigInt.zero();
    protocol.cancelledCount = BigInt.zero();
    protocol.nftAwardedCount = BigInt.zero();
    protocol.cashFallbackCount = BigInt.zero();
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
    account.rafflesWon = BigInt.zero();
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
    stats.verified = false;
    stats.raffleCount = BigInt.zero();
    stats.grossVolume = BigInt.zero();
    stats.netPotVolume = BigInt.zero();
    stats.protocolFees = BigInt.zero();
    stats.providerFees = BigInt.zero();
    stats.quoteClaimed = BigInt.zero();
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
    stats.providerFeesEarned = BigInt.zero();
    stats.quoteClaimed = BigInt.zero();
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
    participation.providerFeesEarned = BigInt.zero();
    participation.won = false;
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

export function updateDayData(
  raffle: Raffle,
  event: ethereum.Event,
  tickets: BigInt,
  gross: BigInt,
  net: BigInt,
  protocolFee: BigInt,
  providerFee: BigInt,
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
    protocolDay.netContributions = BigInt.zero();
    protocolDay.protocolFees = BigInt.zero();
    protocolDay.providerFees = BigInt.zero();
    protocolDay.resolutions = BigInt.zero();
  }
  protocolDay.tickets = protocolDay.tickets.plus(tickets);
  protocolDay.grossVolume = protocolDay.grossVolume.plus(gross);
  protocolDay.netContributions = protocolDay.netContributions.plus(net);
  protocolDay.protocolFees = protocolDay.protocolFees.plus(protocolFee);
  protocolDay.providerFees = protocolDay.providerFees.plus(providerFee);
  protocolDay.save();

  const raffleDayId = raffle.id.toHexString() + "-" + day.toString();
  let raffleDay = RaffleDayData.load(raffleDayId);
  if (raffleDay == null) {
    raffleDay = new RaffleDayData(raffleDayId);
    raffleDay.raffle = raffle.id;
    raffleDay.dayStart = dayStart;
    raffleDay.tickets = BigInt.zero();
    raffleDay.grossVolume = BigInt.zero();
    raffleDay.netContributions = BigInt.zero();
  }
  raffleDay.tickets = raffleDay.tickets.plus(tickets);
  raffleDay.grossVolume = raffleDay.grossVolume.plus(gross);
  raffleDay.netContributions = raffleDay.netContributions.plus(net);
  raffleDay.save();
}

export function incrementResolutionDay(
  raffle: Raffle,
  event: ethereum.Event,
): void {
  const day = event.block.timestamp.div(SECONDS_PER_DAY);
  const id = raffle.quoteTokenStats + "-" + day.toString();
  let data = ProtocolDayData.load(id);
  if (data == null) {
    updateDayData(
      raffle,
      event,
      BigInt.zero(),
      BigInt.zero(),
      BigInt.zero(),
      BigInt.zero(),
      BigInt.zero(),
    );
    data = ProtocolDayData.load(id);
  }
  if (data != null) {
    data.resolutions = data.resolutions.plus(BigInt.fromI32(1));
    data.save();
  }
}
