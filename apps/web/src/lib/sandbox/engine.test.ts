import { describe, expect, it } from "vitest";

import {
  buyTickets,
  cancelBeforeSales,
  claimPrize,
  claimQuote,
  closeNoSales,
  ENTROPY_FEE,
  requestDraw,
  resolveDraw,
  SandboxError,
  thresholdMet,
  type Sandbox,
  type SandboxRaffle,
} from "./engine";

const PLAYER = "0xplayer";
const SPONSOR = "0xsponsor";
const PRICE = 10n ** 16n; // 0.01 WETH

function raffle(overrides: Partial<SandboxRaffle> = {}): SandboxRaffle {
  return {
    id: "0xraffle",
    factoryId: "1",
    sponsor: SPONSOR,
    prizeToken: "0xprize",
    prizeTokenId: "7",
    prizeCollection: "Test Collection",
    prizeName: "Test #7",
    prizeImage: "/demo/test.png",
    ticketPrice: PRICE,
    minimumTickets: 10,
    startTime: 0,
    endTime: 1_000,
    state: "ACTIVE",
    outcome: "NONE",
    tickets: [],
    grossSales: 0n,
    unsettledPot: 0n,
    winningTicketId: null,
    winner: null,
    prizeClaimant: null,
    prizeClaimed: false,
    claimableQuote: {},
    drawRequestedAt: null,
    drawRequestedBy: null,
    ...overrides,
  };
}

function sandbox(overrides: Partial<Sandbox> = {}): Sandbox {
  return {
    player: PLAYER,
    wallet: { weth: 10n ** 18n, eth: 10n ** 17n, nfts: [] },
    raffles: [raffle()],
    log: [],
    seed: 12_345,
    ...overrides,
  };
}

describe("sandbox purchasing", () => {
  it("charges the advertised price and leaves the gross unsettled", () => {
    const next = buyTickets(sandbox(), "0xraffle", 4, 100);
    const updated = next.raffles[0]!;

    const gross = PRICE * 4n;
    expect(next.wallet.weth).toBe(10n ** 18n - gross);
    expect(updated.grossSales).toBe(gross);
    // The aggregate 5% fee is not allocated until resolution.
    expect(updated.unsettledPot).toBe(gross);
  });

  it("mints sequential ticket ids starting at one", () => {
    let state = buyTickets(sandbox(), "0xraffle", 2, 100);
    state = buyTickets(state, "0xraffle", 1, 120);
    expect(state.raffles[0]!.tickets.map((ticket) => ticket.id)).toEqual([
      1, 2, 3,
    ]);
  });

  it("refuses purchases outside the sale window", () => {
    expect(() => buyTickets(sandbox(), "0xraffle", 1, 1_000)).toThrow(
      SandboxError,
    );
  });

  it("refuses to spend more WETH than the player holds", () => {
    const poor = sandbox({
      wallet: { weth: PRICE, eth: 10n ** 17n, nfts: [] },
    });
    expect(() => buyTickets(poor, "0xraffle", 2, 100)).toThrow(SandboxError);
  });

  it("allows sales past the threshold", () => {
    const state = buyTickets(sandbox(), "0xraffle", 25, 100);
    expect(state.raffles[0]!.tickets).toHaveLength(25);
    expect(thresholdMet(state.raffles[0]!)).toBe(true);
  });
});

describe("sandbox settlement", () => {
  it("requires the sale to end before a draw and charges the entropy fee", () => {
    const sold = buyTickets(sandbox(), "0xraffle", 3, 100);
    expect(() => requestDraw(sold, "0xraffle", 500)).toThrow(SandboxError);

    const requested = requestDraw(sold, "0xraffle", 1_000);
    expect(requested.raffles[0]!.state).toBe("DRAW_REQUESTED");
    expect(requested.wallet.eth).toBe(10n ** 17n - ENTROPY_FEE);
  });

  it("awards the NFT to the winning ticket holder when the threshold is met", () => {
    let state = buyTickets(sandbox(), "0xraffle", 12, 100);
    state = requestDraw(state, "0xraffle", 1_000);
    state = resolveDraw(state, "0xraffle", 1_005);
    const settled = state.raffles[0]!;

    expect(settled.outcome).toBe("NFT_AWARDED");
    expect(settled.prizeClaimant).toBe(PLAYER);
    expect(settled.winningTicketId).toBeGreaterThanOrEqual(1);
    expect(settled.winningTicketId).toBeLessThanOrEqual(12);
    // Threshold met: the sponsor takes the distributable pot.
    expect(settled.claimableQuote[SPONSOR]).toBe(
      settled.grossSales - (settled.grossSales * 5n) / 100n,
    );
    expect(settled.claimableQuote[PLAYER]).toBeUndefined();
  });

  it("rounds one protocol fee against the aggregate pot", () => {
    let state = sandbox({
      raffles: [raffle({ ticketPrice: 10n, minimumTickets: 2 })],
    });
    state = buyTickets(state, "0xraffle", 1, 100);
    state = buyTickets(state, "0xraffle", 1, 200);
    state = requestDraw(state, "0xraffle", 1_000);
    state = resolveDraw(state, "0xraffle", 1_005);

    // Charging per purchase would round both fees to zero; settlement charges
    // floor(20 * 5 / 100) once and leaves 19 for the sponsor.
    expect(state.raffles[0]!.claimableQuote[SPONSOR]).toBe(19n);
  });

  it("splits cash 80/20 and returns the NFT to the sponsor below threshold", () => {
    let state = buyTickets(sandbox(), "0xraffle", 4, 100);
    state = requestDraw(state, "0xraffle", 1_000);
    state = resolveDraw(state, "0xraffle", 1_005);
    const settled = state.raffles[0]!;

    const pot = settled.grossSales - (settled.grossSales * 5n) / 100n;
    expect(settled.outcome).toBe("CASH_FALLBACK");
    expect(settled.prizeClaimant).toBe(SPONSOR);
    expect(settled.claimableQuote[PLAYER]).toBe((pot * 80n) / 100n);
    expect(settled.claimableQuote[SPONSOR]).toBe(pot - (pot * 80n) / 100n);
  });

  it("moves no assets during resolution", () => {
    let state = buyTickets(sandbox(), "0xraffle", 12, 100);
    const balanceBefore = state.wallet.weth;
    state = requestDraw(state, "0xraffle", 1_000);
    state = resolveDraw(state, "0xraffle", 1_005);

    // Only the entropy fee left the wallet; the prize is still unclaimed.
    expect(state.wallet.weth).toBe(balanceBefore);
    expect(state.wallet.nfts).toHaveLength(0);
    expect(state.raffles[0]!.prizeClaimed).toBe(false);
  });

  it("hands the prize over only when the claimant pulls it", () => {
    let state = buyTickets(sandbox(), "0xraffle", 12, 100);
    state = requestDraw(state, "0xraffle", 1_000);
    state = resolveDraw(state, "0xraffle", 1_005);
    state = claimPrize(state, "0xraffle", 1_010);

    expect(state.wallet.nfts).toEqual(["0xraffle"]);
    expect(() => claimPrize(state, "0xraffle", 1_020)).toThrow(SandboxError);
  });

  it("pays a cash claim once and only once", () => {
    let state = buyTickets(sandbox(), "0xraffle", 4, 100);
    state = requestDraw(state, "0xraffle", 1_000);
    state = resolveDraw(state, "0xraffle", 1_005);

    const owed = state.raffles[0]!.claimableQuote[PLAYER]!;
    const before = state.wallet.weth;
    state = claimQuote(state, "0xraffle", 1_010);

    expect(state.wallet.weth).toBe(before + owed);
    expect(() => claimQuote(state, "0xraffle", 1_020)).toThrow(SandboxError);
  });

  it("replays the same winner for the same seed", () => {
    const run = () => {
      let state = buyTickets(sandbox({ seed: 999 }), "0xraffle", 20, 100);
      state = requestDraw(state, "0xraffle", 1_000);
      return resolveDraw(state, "0xraffle", 1_005).raffles[0]!.winningTicketId;
    };
    expect(run()).toBe(run());
  });
});

describe("sandbox sponsor exit", () => {
  it("lets the sponsor cancel while zero tickets have sold", () => {
    const own = sandbox({
      player: SPONSOR,
      raffles: [raffle({ sponsor: SPONSOR })],
    });
    const cancelled = cancelBeforeSales(own, "0xraffle", 100);
    expect(cancelled.raffles[0]!.state).toBe("CANCELLED");
    expect(cancelled.raffles[0]!.prizeClaimant).toBe(SPONSOR);
  });

  it("locks the prize the moment a ticket sells", () => {
    let state = sandbox({ player: SPONSOR, raffles: [raffle()] });
    state = buyTickets(state, "0xraffle", 1, 100);
    expect(() => cancelBeforeSales(state, "0xraffle", 200)).toThrow(
      SandboxError,
    );
  });

  it("returns the prize through no-sales closure after the deadline", () => {
    const own = sandbox({ player: SPONSOR, raffles: [raffle()] });
    expect(() => closeNoSales(own, "0xraffle", 500)).toThrow(SandboxError);

    const closed = closeNoSales(own, "0xraffle", 1_000);
    expect(closed.raffles[0]!.outcome).toBe("NO_SALES");
    expect(closed.raffles[0]!.prizeClaimant).toBe(SPONSOR);
  });
});
