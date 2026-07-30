import { describe, expect, it } from "vitest";

import {
  calculatePurchaseAmounts,
  calculateResolutionAmounts,
} from "./economics.js";
import { formatQuoteAmount, parseQuoteAmount } from "./quote.js";

describe("protocol economics", () => {
  it("matches the 120-ticket threshold-met worked example", () => {
    const purchase = calculatePurchaseAmounts({
      ticketPrice: 1_000_000n,
      quantity: 120n,
      hasProvider: true,
    });
    expect(purchase).toEqual({
      grossAmount: 120_000_000n,
      protocolFee: 6_000_000n,
      providerFee: 6_000_000n,
      netContribution: 108_000_000n,
    });
    expect(calculateResolutionAmounts(purchase.netContribution, true)).toEqual({
      winnerCashAmount: 0n,
      sponsorCashAmount: 108_000_000n,
    });
  });

  it("matches the 80-ticket cash-fallback worked example", () => {
    const purchase = calculatePurchaseAmounts({
      ticketPrice: 1_000_000n,
      quantity: 80n,
      hasProvider: true,
    });
    expect(purchase.netContribution).toBe(72_000_000n);
    expect(calculateResolutionAmounts(purchase.netContribution, false)).toEqual(
      {
        winnerCashAmount: 57_600_000n,
        sponsorCashAmount: 14_400_000n,
      },
    );
  });

  it("charges no provider fee when no provider is supplied", () => {
    const purchase = calculatePurchaseAmounts({
      ticketPrice: 1_000_000n,
      quantity: 80n,
      hasProvider: false,
    });
    expect(purchase.protocolFee).toBe(4_000_000n);
    expect(purchase.providerFee).toBe(0n);
    expect(purchase.netContribution).toBe(76_000_000n);
  });

  it("assigns all 80/20 rounding remainder to the sponsor", () => {
    const resolution = calculateResolutionAmounts(7n, false);
    expect(resolution.winnerCashAmount).toBe(5n);
    expect(resolution.sponsorCashAmount).toBe(2n);
    expect(resolution.winnerCashAmount + resolution.sponsorCashAmount).toBe(7n);
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
