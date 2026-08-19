import { BigInt } from "@graphprotocol/graph-ts";

import { RaffleCreated } from "../generated/RaffleFactory/RaffleFactory";
import { Raffle as RaffleTemplate } from "../generated/templates";
import { Raffle } from "../generated/schema";
import {
  getOrCreateAccount,
  getOrCreateProtocol,
  getOrCreateQuoteTokenStats,
} from "./helpers";

const ONE = BigInt.fromI32(1);
const ENTRY_PRICE = BigInt.fromI32(1_000_000);
const DRAW_REQUEST_TIMEOUT = BigInt.fromI32(172800);

export function handleRaffleCreated(event: RaffleCreated): void {
  if (Raffle.load(event.params.raffle) != null) return;

  const protocol = getOrCreateProtocol(event.address);
  protocol.raffleCount = protocol.raffleCount.plus(ONE);
  protocol.activeCount = protocol.activeCount.plus(ONE);
  protocol.save();

  const sponsor = getOrCreateAccount(event.params.sponsor);
  sponsor.rafflesSponsored = sponsor.rafflesSponsored.plus(ONE);
  sponsor.save();
  const sponsorRecipient = getOrCreateAccount(event.params.sponsorRecipient);
  const treasury = getOrCreateAccount(event.params.protocolTreasury);

  const quoteTokenStats = getOrCreateQuoteTokenStats(
    protocol,
    event.params.quoteToken,
  );
  quoteTokenStats.raffleCount = quoteTokenStats.raffleCount.plus(ONE);
  quoteTokenStats.save();

  const raffle = new Raffle(event.params.raffle);
  raffle.protocol = protocol.id;
  raffle.factoryId = event.params.raffleId;
  raffle.sponsor = sponsor.id;
  raffle.sponsorRecipient = sponsorRecipient.id;
  raffle.protocolTreasury = treasury.id;
  raffle.quoteToken = event.params.quoteToken;
  raffle.quoteTokenStats = quoteTokenStats.id;
  raffle.prizeToken = event.params.prizeToken;
  raffle.prizeTokenId = event.params.prizeTokenId;
  raffle.entryPrice = ENTRY_PRICE;
  raffle.reserveEntries = event.params.reserveEntries;
  raffle.endTime = event.params.endTime;
  raffle.drawRequestDeadline = event.params.endTime.plus(DRAW_REQUEST_TIMEOUT);
  // RaffleCreated is emitted only after the factory verifies prize escrow.
  raffle.status = "ACTIVE";
  raffle.totalEntries = BigInt.zero();
  raffle.ticketCount = BigInt.zero();
  raffle.grossSales = BigInt.zero();
  raffle.unsettledPot = BigInt.zero();
  raffle.remainingRefundLiability = BigInt.zero();
  raffle.winnerProceeds = BigInt.zero();
  raffle.sponsorProceeds = BigInt.zero();
  raffle.protocolFees = BigInt.zero();
  raffle.totalRefundRedeemed = BigInt.zero();
  raffle.totalProtocolFees = BigInt.zero();
  raffle.quoteClaimed = BigInt.zero();
  raffle.ignoredVrfCallbackCount = BigInt.zero();
  raffle.prizeClaimed = false;
  raffle.winningTicketSettled = false;
  raffle.winnerRedeemed = false;
  raffle.createdTxHash = event.transaction.hash;
  raffle.createdBlock = event.block.number;
  raffle.createdTimestamp = event.block.timestamp;
  raffle.save();

  RaffleTemplate.create(event.params.raffle);
}
