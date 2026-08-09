import { describe, expect, it } from "vitest";

import {
  buyTickets,
  claimSponsorPrize,
  closeEmptyRaffle,
  enableRefunds,
  ENTROPY_FEE,
  redeemRefundTickets,
  redeemWinningTicket,
  requestDraw,
  resolveDraw,
  SandboxError,
  thresholdMet,
  type Sandbox,
  type SandboxRaffle,
} from "./engine";

const PLAYER = "0xplayer";
const SPONSOR = "0xsponsor";
const PRICE = 10n ** 16n;

function raffle(overrides: Partial<SandboxRaffle> = {}): SandboxRaffle {
  return {
    id: "0xraffle",
    factoryId: "1",
    sponsor: SPONSOR,
    sponsorPrizeRecoveryRecipient: SPONSOR,
    prizeToken: "0xprize",
    prizeTokenId: "7",
    prizeCollection: "Test Collection",
    prizeName: "Test #7",
    prizeImage: "/demo/test.png",
    ticketPrice: PRICE,
    minimumTickets: 10,
    startTime: 0,
    endTime: 1_000,
    requestGraceDeadline: 2_000,
    status: "ACTIVE",
    tickets: [],
    grossSales: 0n,
    unsettledPot: 0n,
    remainingRefundLiability: 0n,
    winnerCashLiability: 0n,
    winningTicketId: null,
    prizeClaimed: false,
    claimableQuote: {},
    drawRequestedAt: null,
    drawRequestedBy: null,
    callbackDeadline: null,
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

describe("sandbox bearer settlement", () => {
  it("charges gross price and mints sequential tickets", () => {
    let state = buyTickets(sandbox(), "0xraffle", 2, 100);
    state = buyTickets(state, "0xraffle", 1, 120);
    expect(state.raffles[0]!.tickets.map((ticket) => ticket.id)).toEqual([
      1, 2, 3,
    ]);
    expect(state.raffles[0]!.unsettledPot).toBe(PRICE * 3n);
  });

  it("charges the entropy fee and records only liabilities in the callback", () => {
    let state = buyTickets(sandbox(), "0xraffle", 4, 100);
    state = requestDraw(state, "0xraffle", 1_000);
    expect(state.wallet.eth).toBe(10n ** 17n - ENTROPY_FEE);
    const wethBefore = state.wallet.weth;
    state = resolveDraw(state, "0xraffle", 1_005);
    expect(state.raffles[0]!.status).toBe("CASH_WON");
    expect(state.wallet.weth).toBe(wethBefore);
    expect(state.wallet.nfts).toHaveLength(0);
  });

  it("charges 5% in the cash branch and pays cash only when the ticket burns", () => {
    let state = buyTickets(sandbox(), "0xraffle", 4, 100);
    state = requestDraw(state, "0xraffle", 1_000);
    state = resolveDraw(state, "0xraffle", 1_005);
    const settled = state.raffles[0]!;
    const distributable = settled.grossSales - (settled.grossSales * 5n) / 100n;
    expect(settled.winnerCashLiability).toBe((distributable * 80n) / 100n);
    expect(settled.claimableQuote[SPONSOR]).toBe(
      distributable - settled.winnerCashLiability,
    );
    const before = state.wallet.weth;
    state = redeemWinningTicket(state, "0xraffle", 1_010);
    expect(state.wallet.weth).toBe(before + (distributable * 80n) / 100n);
    expect(state.raffles[0]!.winnerCashLiability).toBe(0n);
    expect(() => redeemWinningTicket(state, "0xraffle", 1_020)).toThrow(
      SandboxError,
    );
  });

  it("burns a threshold winner ticket for the NFT", () => {
    let state = buyTickets(sandbox(), "0xraffle", 12, 100);
    expect(thresholdMet(state.raffles[0]!)).toBe(true);
    state = requestDraw(state, "0xraffle", 1_000);
    state = resolveDraw(state, "0xraffle", 1_005);
    expect(state.raffles[0]!.status).toBe("NFT_WON");
    state = redeemWinningTicket(state, "0xraffle", 1_010);
    expect(state.wallet.nfts).toEqual(["0xraffle"]);
    expect(state.raffles[0]!.prizeClaimed).toBe(true);
  });

  it("uses one deadline function and burns refundable tickets for exact value", () => {
    let state = buyTickets(sandbox(), "0xraffle", 3, 100);
    expect(() => enableRefunds(state, "0xraffle", 1_999)).toThrow(SandboxError);
    state = enableRefunds(state, "0xraffle", 2_000);
    expect(state.raffles[0]!.remainingRefundLiability).toBe(PRICE * 3n);
    const before = state.wallet.weth;
    state = redeemRefundTickets(state, "0xraffle", [1, 3], 2_001);
    expect(state.wallet.weth).toBe(before + PRICE * 2n);
    expect(state.raffles[0]!.remainingRefundLiability).toBe(PRICE);
    expect(() => redeemRefundTickets(state, "0xraffle", [1], 2_002)).toThrow(
      SandboxError,
    );
  });

  it("lets the fixed recovery recipient reclaim the NFT after cash settlement", () => {
    let state = sandbox({
      raffles: [raffle({ sponsorPrizeRecoveryRecipient: PLAYER })],
    });
    state = buyTickets(state, "0xraffle", 2, 100);
    state = requestDraw(state, "0xraffle", 1_000);
    state = resolveDraw(state, "0xraffle", 1_005);
    state = claimSponsorPrize(state, "0xraffle", 1_010);
    expect(state.wallet.nfts).toEqual(["0xraffle"]);
  });

  it("closes an empty raffle early for its sponsor", () => {
    const state = sandbox({ player: SPONSOR });
    const closed = closeEmptyRaffle(state, "0xraffle", 100);
    expect(closed.raffles[0]!.status).toBe("CLOSED");
  });
});
