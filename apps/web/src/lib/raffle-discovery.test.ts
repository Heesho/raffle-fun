import { describe, expect, it } from "vitest";

import type { IndexedRaffle } from "./subgraph";
import { activeRafflePhase } from "./raffle-discovery";

const END_TIME = 1_000;
const DRAW_REQUEST_DEADLINE = END_TIME + 2 * 24 * 60 * 60;

function raffle(overrides: Partial<IndexedRaffle> = {}): IndexedRaffle {
  return {
    id: "0xraffle",
    factoryId: "1",
    sponsor: "0xsponsor",
    quoteToken: "0xquote",
    quoteTokenVerified: true,
    prizeToken: "0xprize",
    prizeTokenId: "1",
    entryPrice: "1000000",
    reserveEntries: "10",
    endTime: String(END_TIME),
    drawRequestDeadline: String(DRAW_REQUEST_DEADLINE),
    callbackDeadline: null,
    state: "ACTIVE",
    outcome: "NONE",
    totalEntries: "3",
    ticketCount: "1",
    grossSales: "3000000",
    unsettledPot: "3000000",
    remainingRefundLiability: "0",
    winningEntry: null,
    winningTicketId: null,
    ...overrides,
  };
}

describe("active raffle discovery phase", () => {
  it("separates open sales from the draw-request window", () => {
    expect(activeRafflePhase(raffle(), END_TIME - 1)).toBe("LIVE");
    expect(activeRafflePhase(raffle(), END_TIME)).toBe("AWAITING_DRAW");
    expect(activeRafflePhase(raffle(), DRAW_REQUEST_DEADLINE - 1)).toBe(
      "AWAITING_DRAW",
    );
  });

  it("marks sold ACTIVE raffles refund-ready at the hard deadline", () => {
    expect(activeRafflePhase(raffle(), DRAW_REQUEST_DEADLINE)).toBe(
      "REFUND_READY",
    );
    expect(activeRafflePhase(raffle(), DRAW_REQUEST_DEADLINE + 1)).toBe(
      "REFUND_READY",
    );
  });

  it("keeps the unchanged empty-raffle end-time refund behavior", () => {
    const empty = raffle({ totalEntries: "0", unsettledPot: "0" });
    expect(activeRafflePhase(empty, END_TIME - 1)).toBe("LIVE");
    expect(activeRafflePhase(empty, END_TIME)).toBe("REFUND_READY");
  });

  it("marks Drawing raffles refund-ready exactly at the callback deadline", () => {
    const callbackDeadline = DRAW_REQUEST_DEADLINE + 500;
    const drawing = raffle({
      state: "DRAWING",
      callbackDeadline: String(callbackDeadline),
    });
    expect(activeRafflePhase(drawing, callbackDeadline - 1)).toBe(undefined);
    expect(activeRafflePhase(drawing, callbackDeadline)).toBe("REFUND_READY");
    expect(activeRafflePhase(drawing, callbackDeadline + 1)).toBe(
      "REFUND_READY",
    );
  });

  it("defers time labels until hydration and ignores terminal states", () => {
    expect(activeRafflePhase(raffle(), undefined)).toBe("PENDING_TIME");
    expect(activeRafflePhase(raffle({ state: "DRAWING" }), undefined)).toBe(
      "PENDING_TIME",
    );
    expect(activeRafflePhase(raffle({ state: "NFT_WON" }), END_TIME)).toBe(
      undefined,
    );
  });
});
