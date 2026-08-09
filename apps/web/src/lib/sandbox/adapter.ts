import type { IndexedActivity, IndexedRaffle } from "@/lib/subgraph";

import type { Sandbox, SandboxEvent, SandboxRaffle } from "./engine";

/** The sandbox quote token. Every sandbox raffle is priced in WETH. */
export const SANDBOX_WETH = {
  address: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
  symbol: "WETH",
  decimals: 18,
} as const;

const outcomeLabels: Record<string, string> = {
  NONE: "NONE",
  NFT_AWARDED: "PRIZE_TO_WINNER",
  CASH_FALLBACK: "CASH_TO_WINNER",
  NO_SALES: "NO_SALES",
  CANCELLED_BEFORE_SALE: "CANCELLED",
  DRAW_NOT_REQUESTED: "DRAW_NOT_REQUESTED",
  DRAW_TIMED_OUT: "DRAW_TIMED_OUT",
};

/**
 * Presents a sandbox raffle in the same shape as an indexed one, so cards,
 * the directory and the activity feed stay a single implementation.
 */
export function toIndexedRaffle(raffle: SandboxRaffle): IndexedRaffle {
  return {
    id: raffle.id,
    factoryId: raffle.factoryId,
    sponsor: raffle.sponsor,
    quoteToken: SANDBOX_WETH.address,
    quoteTokenVerified: true,
    prizeToken: raffle.prizeToken,
    prizeTokenId: raffle.prizeTokenId,
    prizeCollection: raffle.prizeCollection,
    prizeName: raffle.prizeName,
    prizeImage: raffle.prizeImage,
    prizePixelated: raffle.prizePixelated,
    metadataURI: "",
    ticketPrice: raffle.ticketPrice.toString(),
    minimumTickets: String(raffle.minimumTickets),
    startTime: String(Math.floor(raffle.startTime / 1000)),
    endTime: String(Math.floor(raffle.endTime / 1000)),
    state: raffle.state,
    outcome: outcomeLabels[raffle.outcome] ?? "NONE",
    totalTickets: String(raffle.tickets.length),
    grossSales: raffle.grossSales.toString(),
    unsettledPot: raffle.unsettledPot.toString(),
    winner: raffle.winner,
  };
}

const activityKinds: Record<
  SandboxEvent["kind"],
  IndexedActivity["kind"] | undefined
> = {
  PURCHASE: "PURCHASE",
  RESOLVED: "RESOLUTION",
  QUOTE_CLAIM: "QUOTE_CLAIM",
  PRIZE_CLAIM: "PRIZE_CLAIM",
  DRAW_REQUESTED: undefined,
  CANCELLED: undefined,
  NO_SALES: undefined,
  DRAW_FAILURE: undefined,
  REFUND_CREDIT: undefined,
};

export function toIndexedActivity(
  sandbox: Sandbox,
): readonly IndexedActivity[] {
  return sandbox.log.flatMap((event) => {
    const kind = activityKinds[event.kind];
    if (kind === undefined) return [];
    return [
      {
        id: event.id,
        kind,
        raffle: event.raffleId,
        account: event.account,
        amount: event.amount === null ? null : event.amount.toString(),
        quoteToken: event.amount === null ? null : SANDBOX_WETH.address,
        timestamp: String(Math.floor(event.at / 1000)),
        transactionHash: `0x${event.id
          .replace(/[^a-f0-9]/gi, "")
          .padEnd(64, "0")
          .slice(0, 64)}`,
      },
    ];
  });
}
