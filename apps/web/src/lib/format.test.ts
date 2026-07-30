import { describe, expect, it } from "vitest";

import {
  formatCountdown,
  formatTokenAmount,
  percentOf,
  shortAddress,
} from "./format";

describe("web formatting", () => {
  it("shortens EVM addresses without losing identity edges", () => {
    expect(shortAddress("0x1234567890123456789012345678901234567890")).toBe(
      "0x1234…7890",
    );
  });

  it("bounds progress at 100 percent", () => {
    expect(percentOf(120n, 100n)).toBe(120);
    expect(percentOf(1n, 0n)).toBe(0);
  });

  it("labels elapsed countdowns as closed", () => {
    expect(formatCountdown(100n, 101_000)).toBe("Closed");
  });

  it("formats quote amounts with each token's own decimals", () => {
    expect(formatTokenAmount(1_234_500n, 6, "USDC")).toBe("1.2345 USDC");
    expect(formatTokenAmount(1_250_000_000_000_000_000n, 18, "WETH")).toBe(
      "1.25 WETH",
    );
  });

  it("shows raw units when token decimals cannot be read", () => {
    expect(formatTokenAmount(42n, undefined, "ERC20")).toBe(
      "42 raw units · ERC20",
    );
  });
});
