import type { IndexedActivity, IndexedRaffle } from "@/lib/subgraph";

import {
  drawRequestDeadline,
  ENTRY_PRICE,
  type Sandbox,
  type SandboxEvent,
  type SandboxRaffle,
} from "./engine";

/** The sandbox mirrors the production factory's fixed six-decimal USDC. */
export const SANDBOX_USDC = {
  address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
  symbol: "USDC",
  decimals: 6,
} as const;

/**
 * Presents a sandbox raffle in the same shape as an indexed one, so cards,
 * the directory and the activity feed stay a single implementation.
 */
export function toIndexedRaffle(raffle: SandboxRaffle): IndexedRaffle {
  return {
    id: raffle.id,
    factoryId: raffle.factoryId,
    sponsor: raffle.sponsor,
    quoteToken: SANDBOX_USDC.address,
    quoteTokenVerified: true,
    prizeToken: raffle.prizeToken,
    prizeTokenId: raffle.prizeTokenId,
    prizeCollection: raffle.prizeCollection,
    prizeName: raffle.prizeName,
    prizeImage: raffle.prizeImage,
    prizePixelated: raffle.prizePixelated,
    entryPrice: ENTRY_PRICE.toString(),
    reserveEntries: raffle.reserveEntries.toString(),
    endTime: String(Math.floor(raffle.endTime / 1000)),
    drawRequestDeadline: String(Math.floor(drawRequestDeadline(raffle) / 1000)),
    callbackDeadline:
      raffle.callbackDeadline === null
        ? null
        : String(Math.floor(raffle.callbackDeadline / 1000)),
    state: raffle.status,
    outcome:
      raffle.status === "NFT_WON" || raffle.status === "CASH_WON"
        ? raffle.status
        : "NONE",
    totalEntries: raffle.totalEntries.toString(),
    ticketCount: raffle.tickets.length.toString(),
    grossSales: raffle.grossSales.toString(),
    unsettledPot: raffle.unsettledPot.toString(),
    remainingRefundLiability: raffle.remainingRefundLiability.toString(),
    winningEntry: raffle.winningEntry?.toString() ?? null,
    winningTicketId: raffle.winningTicketId?.toString() ?? null,
  };
}

const activityKinds: Record<
  SandboxEvent["kind"],
  IndexedActivity["kind"] | undefined
> = {
  PURCHASE: "PURCHASE",
  RESOLVED: "RESOLUTION",
  SPONSOR_PROCEEDS_RELEASED: "QUOTE_CLAIM",
  PROTOCOL_FEES_RELEASED: "QUOTE_CLAIM",
  WINNING_REDEEMED: undefined,
  SPONSOR_PRIZE_RELEASED: "PRIZE_CLAIM",
  DRAW_REQUESTED: undefined,
  REFUNDS_ENABLED: undefined,
  REFUND_REDEEMED: "QUOTE_CLAIM",
  WINNING_SETTLED: undefined,
};

export function toIndexedActivity(
  sandbox: Sandbox,
): readonly IndexedActivity[] {
  return sandbox.log.flatMap((event) => {
    const kind =
      event.kind === "WINNING_REDEEMED"
        ? event.amount === null
          ? "PRIZE_CLAIM"
          : "QUOTE_CLAIM"
        : activityKinds[event.kind];
    if (kind === undefined) return [];
    const amount = event.kind === "RESOLVED" ? null : event.amount;
    return [
      {
        id: event.id,
        kind,
        raffle: event.raffleId,
        account: event.kind === "RESOLVED" ? null : event.account,
        amount: amount === null ? null : amount.toString(),
        quoteToken: amount === null ? null : SANDBOX_USDC.address,
        timestamp: String(Math.floor(event.at / 1000)),
        transactionHash: `0x${event.id
          .replace(/[^a-f0-9]/gi, "")
          .padEnd(64, "0")
          .slice(0, 64)}`,
      },
    ];
  });
}
