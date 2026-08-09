import { describe, expect, it } from "vitest";

import { validateRefundTicketIds } from "./actions.js";
import { ProtocolOwnedClaim } from "./types/protocol.js";

describe("ProtocolOwnedClaim", () => {
  it("matches the Solidity enum ordinals", () => {
    expect(ProtocolOwnedClaim.WinningTicket).toBe(0);
    expect(ProtocolOwnedClaim.RefundTickets).toBe(1);
    expect(ProtocolOwnedClaim.Quote).toBe(2);
    expect(ProtocolOwnedClaim.SponsorPrize).toBe(3);
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
