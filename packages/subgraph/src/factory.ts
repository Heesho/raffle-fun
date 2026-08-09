import { BigInt } from "@graphprotocol/graph-ts";

import { RaffleCreated } from "../generated/RaffleFactory/RaffleFactory";
import { Raffle as RaffleTemplate } from "../generated/templates";
import { Raffle } from "../generated/schema";
import {
  getOrCreateAccount,
  getOrCreateProtocol,
  getOrCreateQuoteTokenStats,
} from "./helpers";

export function handleRaffleCreated(event: RaffleCreated): void {
  if (Raffle.load(event.params.raffle) != null) return;
  const protocol = getOrCreateProtocol(event.address);
  protocol.raffleCount = protocol.raffleCount.plus(BigInt.fromI32(1));
  protocol.activeCount = protocol.activeCount.plus(BigInt.fromI32(1));
  protocol.save();

  const sponsor = getOrCreateAccount(event.params.sponsor);
  sponsor.rafflesSponsored = sponsor.rafflesSponsored.plus(BigInt.fromI32(1));
  sponsor.save();
  getOrCreateAccount(event.params.sponsorPrizeRecoveryRecipient);
  getOrCreateAccount(event.params.protocolTreasury);
  const quoteTokenStats = getOrCreateQuoteTokenStats(
    protocol,
    event.params.quoteToken,
  );
  quoteTokenStats.raffleCount = quoteTokenStats.raffleCount.plus(
    BigInt.fromI32(1),
  );
  quoteTokenStats.save();

  const raffle = new Raffle(event.params.raffle);
  raffle.protocol = protocol.id;
  raffle.factoryId = event.params.raffleId;
  raffle.sponsor = sponsor.id;
  raffle.sponsorPrizeRecoveryRecipient =
    event.params.sponsorPrizeRecoveryRecipient;
  raffle.protocolTreasury = event.params.protocolTreasury;
  raffle.quoteToken = event.params.quoteToken;
  raffle.quoteTokenStats = quoteTokenStats.id;
  raffle.prizeToken = event.params.prizeToken;
  raffle.prizeTokenId = event.params.prizeTokenId;
  raffle.metadataURI = event.params.metadataURI;
  raffle.ticketPrice = event.params.ticketPrice;
  raffle.minimumTickets = event.params.minimumTickets;
  raffle.startTime = event.params.startTime;
  raffle.endTime = event.params.endTime;
  raffle.requestGraceDeadline = event.params.requestGraceDeadline;
  raffle.status = "AWAITING_PRIZE";
  raffle.totalTickets = BigInt.zero();
  raffle.grossSales = BigInt.zero();
  raffle.unsettledPot = BigInt.zero();
  raffle.remainingRefundLiability = BigInt.zero();
  raffle.winnerCashLiability = BigInt.zero();
  raffle.totalClaimableQuote = BigInt.zero();
  raffle.totalRefundRedeemed = BigInt.zero();
  raffle.totalProtocolFees = BigInt.zero();
  raffle.quoteClaimed = BigInt.zero();
  raffle.prizeClaimed = false;
  raffle.winningTicketRedeemed = false;
  raffle.createdTxHash = event.transaction.hash;
  raffle.createdBlock = event.block.number;
  raffle.createdTimestamp = event.block.timestamp;
  raffle.save();

  RaffleTemplate.create(event.params.raffle);
}
