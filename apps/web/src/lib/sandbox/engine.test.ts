import { describe, expect, it } from "vitest";

import {
  buyEntries,
  releaseWinnerPrize,
  releaseWinnerProceeds,
  releaseSponsorPrize,
  enableRefunds,
  DRAW_REQUEST_TIMEOUT_MS,
  ENTRY_PRICE,
  ticketContainingEntry,
  refundTickets,
  settleWinningTicket,
  requestDraw,
  resolveDraw,
  SandboxError,
  reserveMet,
  VRF_FEE,
  type Sandbox,
  type SandboxRaffle,
} from "./engine";

const PLAYER = "0xplayer";
const SPONSOR = "0xsponsor";
const TREASURY = "0xtreasury";

function raffle(overrides: Partial<SandboxRaffle> = {}): SandboxRaffle {
  return {
    id: "0xraffle",
    factoryId: "1",
    sponsor: SPONSOR,
    sponsorRecipient: SPONSOR,
    protocolTreasury: TREASURY,
    prizeToken: "0xprize",
    prizeTokenId: "7",
    prizeCollection: "Test Collection",
    prizeName: "Test #7",
    prizeImage: "/demo/test.png",
    reserveEntries: 10n,
    endTime: 1_000,
    status: "ACTIVE",
    tickets: [],
    totalEntries: 0n,
    grossSales: 0n,
    unsettledPot: 0n,
    remainingRefundLiability: 0n,
    winnerRecipient: null,
    winnerProceeds: 0n,
    sponsorProceeds: 0n,
    protocolFees: 0n,
    winningEntry: null,
    winningTicketId: null,
    prizeClaimed: false,
    drawRequestedAt: null,
    drawRequestedBy: null,
    callbackDeadline: null,
    resolvedAt: null,
    ...overrides,
  };
}

function sandbox(overrides: Partial<Sandbox> = {}): Sandbox {
  return {
    player: PLAYER,
    wallet: { usdc: 1_000_000n * ENTRY_PRICE, eth: 10n ** 17n, nfts: [] },
    raffles: [raffle()],
    log: [],
    seed: 12_345,
    ...overrides,
  };
}

describe("sandbox sequential-ticket settlement", () => {
  it("mints one sequential ticket for an arbitrarily large entry purchase", () => {
    const count = 1_000_000n;
    const state = buyEntries(sandbox(), "0xraffle", count, 100);
    const created = state.raffles[0]!;
    expect(created.tickets).toHaveLength(1);
    expect(created.tickets[0]!.id).toBe(1n);
    expect(created.tickets[0]).toMatchObject({
      firstEntry: 1n,
      lastEntry: count,
    });
    expect(created.totalEntries).toBe(count);
    expect(created.unsettledPot).toBe(ENTRY_PRICE * count);
  });

  it("charges the VRF fee and stores only a winning entry in the callback", () => {
    let state = buyEntries(sandbox(), "0xraffle", 4n, 100);
    state = requestDraw(state, "0xraffle", 1_000);
    expect(state.wallet.eth).toBe(10n ** 17n - VRF_FEE);
    const usdcBefore = state.wallet.usdc;
    state = resolveDraw(state, "0xraffle", 1_005);
    expect(state.raffles[0]!.status).toBe("CASH_WON");
    expect(state.raffles[0]!.winningEntry).not.toBeNull();
    expect(state.raffles[0]!.winningTicketId).toBeNull();
    expect(state.wallet.usdc).toBe(usdcBefore);
  });

  it("closes draw requests and opens sold-raffle refunds at the request deadline", () => {
    const sold = buyEntries(sandbox(), "0xraffle", 4n, 100);
    const deadline = sold.raffles[0]!.endTime + DRAW_REQUEST_TIMEOUT_MS;

    expect(() => enableRefunds(sold, "0xraffle", deadline - 1)).toThrow(
      SandboxError,
    );
    expect(() => requestDraw(sold, "0xraffle", deadline)).toThrow(SandboxError);

    const refunding = enableRefunds(sold, "0xraffle", deadline);
    expect(refunding.raffles[0]!.status).toBe("REFUNDING");
    expect(refunding.raffles[0]!.remainingRefundLiability).toBe(
      4n * ENTRY_PRICE,
    );

    const lastMoment = requestDraw(sold, "0xraffle", deadline - 1);
    expect(lastMoment.raffles[0]!.status).toBe("DRAWING");
  });

  it("ignores callbacks at the hard callback deadline", () => {
    let state = buyEntries(sandbox(), "0xraffle", 4n, 100);
    state = requestDraw(state, "0xraffle", 1_000);
    const deadline = state.raffles[0]!.callbackDeadline!;

    const ignored = resolveDraw(state, "0xraffle", deadline);
    expect(ignored).toBe(state);
    expect(ignored.raffles[0]!.status).toBe("DRAWING");
    expect(ignored.raffles[0]!.winningEntry).toBeNull();

    state = enableRefunds(ignored, "0xraffle", deadline);
    expect(state.raffles[0]!.status).toBe("REFUNDING");
  });

  it("splits cash as 80/5/15 of gross", () => {
    let state = buyEntries(sandbox(), "0xraffle", 4n, 100);
    state = requestDraw(state, "0xraffle", 1_000);
    state = resolveDraw(state, "0xraffle", 1_005);
    const resolved = state.raffles[0]!;
    const fee = (resolved.grossSales * 5n) / 100n;
    const distributable = resolved.grossSales - fee;
    const winnerCash = (resolved.grossSales * 80n) / 100n;
    const sponsorCash = distributable - winnerCash;
    expect(resolved.unsettledPot).toBe(resolved.grossSales);
    expect(resolved.sponsorProceeds).toBe(0n);
    expect(resolved.protocolFees).toBe(0n);

    const ticket = ticketContainingEntry(resolved, resolved.winningEntry!)!;
    const before = state.wallet.usdc;
    state = settleWinningTicket(state, "0xraffle", ticket.id, 1_010);
    expect(state.wallet.usdc).toBe(before);
    expect(state.raffles[0]!.winnerRecipient).toBe(PLAYER);
    expect(state.raffles[0]!.winnerProceeds).toBe(winnerCash);
    expect(state.raffles[0]!.sponsorProceeds).toBe(sponsorCash);
    expect(state.raffles[0]!.protocolFees).toBe(fee);
    state = releaseWinnerProceeds(state, "0xraffle", 1_011);
    expect(state.wallet.usdc).toBe(before + winnerCash);
    expect(state.raffles[0]!.winnerProceeds).toBe(0n);
  });

  it("settles an NFT win and only then credits sponsor proceeds", () => {
    let state = buyEntries(sandbox(), "0xraffle", 12n, 100);
    expect(reserveMet(state.raffles[0]!)).toBe(true);
    state = requestDraw(state, "0xraffle", 1_000);
    state = resolveDraw(state, "0xraffle", 1_005);
    const resolved = state.raffles[0]!;
    expect(resolved.status).toBe("NFT_WON");
    expect(resolved.sponsorProceeds).toBe(0n);
    const ticket = ticketContainingEntry(resolved, resolved.winningEntry!)!;
    state = settleWinningTicket(state, "0xraffle", ticket.id, 1_010);
    expect(state.wallet.nfts).toEqual([]);
    expect(state.raffles[0]!.winnerRecipient).toBe(PLAYER);
    state = releaseWinnerPrize(state, "0xraffle", 1_011);
    expect(state.wallet.nfts).toEqual(["0xraffle"]);
    expect(state.raffles[0]!.sponsorProceeds).toBe(
      (ENTRY_PRICE * 12n * 95n) / 100n,
    );
  });

  it("never opens refunds after a valid NFT callback", () => {
    let state = buyEntries(sandbox(), "0xraffle", 12n, 100);
    state = requestDraw(state, "0xraffle", 1_000);
    state = resolveDraw(state, "0xraffle", 1_005);
    expect(() => enableRefunds(state, "0xraffle", 10 ** 15)).toThrow(
      SandboxError,
    );
  });

  it("refunds every entry in each supplied ticket range", () => {
    let state = buyEntries(sandbox(), "0xraffle", 3n, 100);
    state = buyEntries(state, "0xraffle", 7n, 200);
    state = requestDraw(state, "0xraffle", 1_000);
    state = enableRefunds(
      state,
      "0xraffle",
      state.raffles[0]!.callbackDeadline!,
    );
    const firstTicket = state.raffles[0]!.tickets[0]!;
    const before = state.wallet.usdc;
    state = refundTickets(state, "0xraffle", [firstTicket.id], 2_001);
    expect(state.wallet.usdc).toBe(before + ENTRY_PRICE * 3n);
    expect(state.raffles[0]!.remainingRefundLiability).toBe(ENTRY_PRICE * 7n);
  });

  it("lets anyone release the sponsor NFT to the fixed recipient", () => {
    let state = sandbox({ player: SPONSOR });
    state = buyEntries(state, "0xraffle", 2n, 100);
    state = requestDraw(state, "0xraffle", 1_000);
    state = resolveDraw(state, "0xraffle", 1_005);
    state = releaseSponsorPrize(state, "0xraffle", 1_010);
    expect(state.wallet.nfts).toEqual(["0xraffle"]);
  });

  it("puts an empty sponsor-finalized raffle directly into refunding", () => {
    const state = sandbox({ player: SPONSOR });
    const finalized = enableRefunds(state, "0xraffle", 100);
    expect(finalized.raffles[0]!.status).toBe("REFUNDING");
    expect(finalized.raffles[0]!.remainingRefundLiability).toBe(0n);
  });
});
