import { describe, expect, it } from "vitest";

import {
  validatePurchaseQuantity,
  validateRefundTicketIds,
} from "./actions.js";

describe("validatePurchaseQuantity", () => {
  it("accepts the onchain range and rejects malformed quantities before RPC", () => {
    expect(() => validatePurchaseQuantity(1n)).not.toThrow();
    expect(() => validatePurchaseQuantity(100n)).not.toThrow();
    expect(() => validatePurchaseQuantity(0n)).toThrow("between 1 and 100");
    expect(() => validatePurchaseQuantity(101n)).toThrow("between 1 and 100");
  });
});

describe("validateRefundTicketIds", () => {
  it("accepts a unique bounded positive batch", () => {
    expect(() => validateRefundTicketIds([1n, 2n, 100n])).not.toThrow();
  });

  it("rejects duplicate ticket IDs before RPC simulation", () => {
    expect(() => validateRefundTicketIds([7n, 7n])).toThrow(
      "duplicate refund ticket ID: 7",
    );
  });

  it("rejects empty, zero, and oversized batches", () => {
    expect(() => validateRefundTicketIds([])).toThrow("between 1 and 100");
    expect(() => validateRefundTicketIds([0n])).toThrow("must be positive");
    expect(() =>
      validateRefundTicketIds(
        Array.from({ length: 101 }, (_, i) => BigInt(i + 1)),
      ),
    ).toThrow("between 1 and 100");
  });
});
