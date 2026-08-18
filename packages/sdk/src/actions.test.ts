import { describe, expect, it } from "vitest";

import {
  requestDraw,
  validateCreateRaffleParams,
  validateEntryCount,
  validateRefundTicketIds,
  type ActionContext,
} from "./actions.js";
import { MAX_UINT128, MAX_UINT64 } from "./math/economics.js";

const account = "0x1111111111111111111111111111111111111111";
const raffle = "0x2222222222222222222222222222222222222222";
const prizeToken = "0x3333333333333333333333333333333333333333";
const sponsorRecipient = "0x4444444444444444444444444444444444444444";

describe("validateEntryCount", () => {
  it("accepts the full uint128 range and rejects malformed counts before RPC", () => {
    expect(() => validateEntryCount(1n)).not.toThrow();
    expect(() => validateEntryCount(MAX_UINT128)).not.toThrow();
    expect(() => validateEntryCount(0n)).toThrow("between 1 and uint128 max");
    expect(() => validateEntryCount(MAX_UINT128 + 1n)).toThrow(
      "between 1 and uint128 max",
    );
  });
});

describe("validateCreateRaffleParams", () => {
  it("keeps reserve entries and the deadline in their exact ABI widths", () => {
    expect(() =>
      validateCreateRaffleParams({
        sponsorRecipient,
        prizeToken,
        prizeTokenId: 0n,
        reserveEntries: MAX_UINT128,
        endTime: MAX_UINT64,
      }),
    ).not.toThrow();
    expect(() =>
      validateCreateRaffleParams({
        sponsorRecipient,
        prizeToken,
        prizeTokenId: 0n,
        reserveEntries: MAX_UINT128 + 1n,
        endTime: MAX_UINT64,
      }),
    ).toThrow(/uint128/);
    expect(() =>
      validateCreateRaffleParams({
        sponsorRecipient,
        prizeToken,
        prizeTokenId: 0n,
        reserveEntries: 1n,
        endTime: MAX_UINT64 + 1n,
      }),
    ).toThrow(/uint64/);
  });
});

describe("validateRefundTicketIds", () => {
  it("accepts a unique bounded batch of sequential ticket IDs", () => {
    expect(() => validateRefundTicketIds([1n, 2n])).not.toThrow();
  });

  it("rejects duplicate ticket IDs before RPC simulation", () => {
    const duplicate = 7n;
    expect(() => validateRefundTicketIds([duplicate, duplicate])).toThrow(
      `duplicate refund ticket ID: ${duplicate.toString()}`,
    );
  });

  it("rejects empty, malformed, and oversized batches", () => {
    expect(() => validateRefundTicketIds([])).toThrow(
      "between 1 and 100 tickets",
    );
    expect(() => validateRefundTicketIds([0n])).toThrow(/positive uint256/);
    expect(() =>
      validateRefundTicketIds(
        Array.from({ length: 101 }, (_, index) => BigInt(index + 1)),
      ),
    ).toThrow("between 1 and 100 tickets");
  });
});

describe("requestDraw", () => {
  it("quotes at the same EIP-1559 max fee used for simulation", async () => {
    const calls: Array<{ readonly method: string; readonly value: unknown }> =
      [];
    const context = {
      account,
      publicClient: {
        chain: undefined,
        async estimateFeesPerGas(parameters: unknown) {
          calls.push({ method: "estimateFeesPerGas", value: parameters });
          return { maxFeePerGas: 42n, maxPriorityFeePerGas: 2n };
        },
        async readContract(parameters: unknown) {
          calls.push({ method: "readContract", value: parameters });
          return 123n;
        },
        async simulateContract(parameters: unknown) {
          calls.push({ method: "simulateContract", value: parameters });
          return { request: { marker: "simulated" } };
        },
      },
      walletClient: {
        async writeContract(request: unknown) {
          calls.push({ method: "writeContract", value: request });
          return "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        },
      },
    } as unknown as ActionContext;

    await expect(requestDraw(context, raffle)).resolves.toMatch(/^0x[a]+$/);
    expect(calls[1]).toMatchObject({
      method: "readContract",
      value: {
        functionName: "estimateVrfRequestPrice",
        args: [42n],
      },
    });
    expect(calls[2]).toMatchObject({
      method: "simulateContract",
      value: {
        functionName: "requestDraw",
        value: 123n,
        maxFeePerGas: 42n,
      },
    });
  });
});
