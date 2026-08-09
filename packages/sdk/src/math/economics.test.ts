import { describe, expect, it } from "vitest";

import {
  calculatePurchaseAmounts,
  calculateRefundAmounts,
  calculateResolutionAmounts,
} from "./economics.js";
import { formatQuoteAmount, parseQuoteAmount } from "./quote.js";

describe("protocol economics", () => {
  it("matches the 120-ticket threshold-met worked example", () => {
    const purchase = calculatePurchaseAmounts({
      ticketPrice: 1_000_000n,
      quantity: 120n,
    });
    expect(purchase).toEqual({ grossAmount: 120_000_000n });
    expect(calculateResolutionAmounts(purchase.grossAmount, true)).toEqual({
      protocolFee: 6_000_000n,
      distributablePot: 114_000_000n,
      winnerCashAmount: 0n,
      sponsorCashAmount: 114_000_000n,
    });
  });

  it("matches the 80-ticket cash-fallback worked example", () => {
    const purchase = calculatePurchaseAmounts({
      ticketPrice: 1_000_000n,
      quantity: 80n,
    });
    expect(calculateResolutionAmounts(purchase.grossAmount, false)).toEqual({
      protocolFee: 4_000_000n,
      distributablePot: 76_000_000n,
      winnerCashAmount: 60_800_000n,
      sponsorCashAmount: 15_200_000n,
    });
  });

  it("calculates the fee once from aggregate gross sales", () => {
    const settlement = calculateResolutionAmounts(20n, true);
    expect(settlement.protocolFee).toBe(1n);
    expect(settlement.distributablePot).toBe(19n);
  });

  it("assigns all 80/20 rounding remainder to the sponsor", () => {
    const resolution = calculateResolutionAmounts(8n, false);
    expect(resolution.protocolFee).toBe(0n);
    expect(resolution.distributablePot).toBe(8n);
    expect(resolution.winnerCashAmount).toBe(6n);
    expect(resolution.sponsorCashAmount).toBe(2n);
    expect(resolution.winnerCashAmount + resolution.sponsorCashAmount).toBe(8n);
  });

  it("conserves gross sales exactly across partial ticket-burn refunds", () => {
    expect(
      calculateRefundAmounts({
        ticketPrice: 1_000_000n,
        totalTickets: 80n,
        redeemedTickets: 31n,
      }),
    ).toEqual({
      grossRefundLiability: 80_000_000n,
      redeemedRefunds: 31_000_000n,
      remainingRefundLiability: 49_000_000n,
      protocolFee: 0n,
    });
  });

  it("parses and formats quote units without floating point", () => {
    expect(parseQuoteAmount("57.60", 6)).toBe(57_600_000n);
    expect(formatQuoteAmount(57_600_000n, 6)).toBe("57.6");
    expect(parseQuoteAmount("1.25", 18)).toBe(1_250_000_000_000_000_000n);
    expect(formatQuoteAmount(1_250_000_000_000_000_000n, 18)).toBe("1.25");
    expect(() => parseQuoteAmount("1.0000001", 6)).toThrow(/more than 6/);
    expect(() => parseQuoteAmount("1e6", 6)).toThrow(/plain/);
  });
});
