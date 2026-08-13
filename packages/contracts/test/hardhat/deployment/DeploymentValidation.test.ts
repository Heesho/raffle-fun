import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { zeroAddress, type Address, type PublicClient } from "viem";

import { validateDeploymentOnchain } from "../../../scripts/deployment-validation.js";
import type { DeploymentRecord } from "../../../scripts/deployment-record.js";

const candidate: DeploymentRecord = {
  chainId: 8_453,
  networkName: "base",
  deployedAt: "2026-08-13T00:00:00.000Z",
  deploymentBlock: 1,
  deployer: "0x1111111111111111111111111111111111111111",
  finalFactoryOwner: "0x2222222222222222222222222222222222222222",
  quoteToken: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
  entropy: "0x6e7d74fA7d5C90FeF9F0512987605a6D546181bB",
  raffleFactory: "0x3333333333333333333333333333333333333333",
  raffleLens: "0x4444444444444444444444444444444444444444",
  protocolTreasury: "0x5555555555555555555555555555555555555555",
  callbackGasLimit: 300_000,
  sourceCommit: "9999999999999999999999999999999999999999",
  verificationStatus: "verified",
};

interface ClientOverrides {
  readonly owner?: Address;
  readonly pendingOwner?: Address;
  readonly decimals?: number;
  readonly paused?: boolean;
  readonly codeLess?: readonly Address[];
}

describe("deployment validation", () => {
  it("accepts only a completed, unpaused, six-decimal mainnet deployment", async () => {
    await validateDeploymentOnchain(fakeClient(), candidate);
  });

  it("rejects a pending ownership handoff", async () => {
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({
          owner: candidate.deployer as Address,
          pendingOwner: candidate.finalFactoryOwner as Address,
        }),
        candidate,
      ),
      /ownership has not been accepted/,
    );
  });

  it("rejects incompatible or paused quote-token state", async () => {
    await assert.rejects(
      validateDeploymentOnchain(fakeClient({ decimals: 18 }), candidate),
      /canonical USDC decimals 6/,
    );
    await assert.rejects(
      validateDeploymentOnchain(fakeClient({ paused: true }), candidate),
      /quote token is paused/,
    );
  });

  it("rejects an EOA mainnet treasury", async () => {
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({ codeLess: [candidate.protocolTreasury as Address] }),
        candidate,
      ),
      /protocolTreasury must be a reviewed contract wallet/,
    );
  });
});

function fakeClient(overrides: ClientOverrides = {}): PublicClient {
  const codeLess = new Set(
    (overrides.codeLess ?? []).map((address) => address.toLowerCase()),
  );
  return {
    async getChainId() {
      return candidate.chainId;
    },
    async getBlockNumber() {
      return 1n;
    },
    async getCode({ address }: { address: Address }) {
      return codeLess.has(address.toLowerCase()) ? "0x" : "0x01";
    },
    async readContract({
      address,
      functionName,
    }: {
      address: Address;
      functionName: string;
    }) {
      if (address === candidate.quoteToken) {
        if (functionName === "decimals") return overrides.decimals ?? 6;
        if (functionName === "paused") return overrides.paused ?? false;
      }
      if (address === candidate.raffleLens && functionName === "factory") {
        return candidate.raffleFactory;
      }
      switch (functionName) {
        case "quoteToken":
          return candidate.quoteToken;
        case "entropy":
          return candidate.entropy;
        case "callbackGasLimit":
          return candidate.callbackGasLimit;
        case "protocolTreasury":
          return candidate.protocolTreasury;
        case "owner":
          return overrides.owner ?? candidate.finalFactoryOwner;
        case "pendingOwner":
          return overrides.pendingOwner ?? zeroAddress;
        default:
          throw new Error(`unexpected read: ${String(functionName)}`);
      }
    },
  } as unknown as PublicClient;
}
