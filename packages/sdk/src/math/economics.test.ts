import { describe, expect, it } from "vitest";

import {
  DRAW_CALLBACK_TIMEOUT_SECONDS,
  DRAW_REQUEST_TIMEOUT_SECONDS,
  ENTRY_PRICE,
  MAX_SALE_DURATION_SECONDS,
  MAX_UINT128,
  calculatePurchaseAmounts,
  calculateRefundAmounts,
  calculateResolutionAmounts,
  reserveProgress,
  ticketRangeContainsEntry,
} from "./economics.js";
import { formatQuoteAmount, parseQuoteAmount } from "./quote.js";

describe("protocol economics", () => {
  it("mirrors the fixed sale and draw timeout constants", () => {
    expect(MAX_SALE_DURATION_SECONDS).toBe(30n * 24n * 60n * 60n);
    expect(DRAW_REQUEST_TIMEOUT_SECONDS).toBe(2n * 24n * 60n * 60n);
    expect(DRAW_CALLBACK_TIMEOUT_SECONDS).toBe(2n * 24n * 60n * 60n);
  });

  it("uses the fixed one-dollar entry price", () => {
    expect(ENTRY_PRICE).toBe(1_000_000n);
    expect(calculatePurchaseAmounts({ entryCount: 120n })).toEqual({
      grossAmount: 120_000_000n,
    });
  });

  it("settles a reserve-met NFT result as 5 percent protocol and 95 percent sponsor", () => {
    expect(calculateResolutionAmounts(120_000_000n, true)).toEqual({
      protocolFee: 6_000_000n,
      distributablePot: 114_000_000n,
      winnerCashAmount: 0n,
      sponsorAmount: 114_000_000n,
    });
  });

  it("settles a below-reserve result as 80/5/15 of gross", () => {
    expect(calculateResolutionAmounts(80_000_000n, false)).toEqual({
      protocolFee: 4_000_000n,
      distributablePot: 76_000_000n,
      winnerCashAmount: 64_000_000n,
      sponsorAmount: 12_000_000n,
    });
  });

  it("calculates the fee once from aggregate gross sales", () => {
    const settlement = calculateResolutionAmounts(20n, true);
    expect(settlement.protocolFee).toBe(1n);
    expect(settlement.distributablePot).toBe(19n);
  });

  it("conserves gross sales exactly across partial ticket refunds", () => {
    expect(
      calculateRefundAmounts({
        totalEntries: 80n,
        redeemedEntries: 31n,
      }),
    ).toEqual({
      grossRefundLiability: 80_000_000n,
      redeemedRefunds: 31_000_000n,
      remainingRefundLiability: 49_000_000n,
      protocolFee: 0n,
    });
  });

  it("keeps uint128 entry values and progress in bigint space", () => {
    expect(() =>
      calculatePurchaseAmounts({ entryCount: MAX_UINT128 }),
    ).not.toThrow();
    expect(() =>
      calculatePurchaseAmounts({ entryCount: MAX_UINT128 + 1n }),
    ).toThrow(/uint128/);
    expect(reserveProgress(MAX_UINT128, MAX_UINT128)).toBe(10_000n);
  });

  it("checks an explicit ticket range without enumerating its entries", () => {
    const range = { firstEntry: 21n, lastEntry: 40n };
    expect(ticketRangeContainsEntry(range, 21n)).toBe(true);
    expect(ticketRangeContainsEntry(range, 40n)).toBe(true);
    expect(ticketRangeContainsEntry(range, 41n)).toBe(false);
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
