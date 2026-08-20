import assert from "node:assert/strict";
import path from "node:path";
import { describe, it } from "node:test";

import { keccak256, type Address, type Hex, type PublicClient } from "viem";

import {
  validateDeploymentOnchain,
  type DeploymentValidationEvidence,
} from "../../../scripts/deployment-validation.js";
import { loadDeploymentBuildEvidence } from "../../../scripts/deployment-build-evidence.js";
import type { DeploymentRecord } from "../../../scripts/deployment-record.js";

const candidate: DeploymentRecord = {
  chainId: 1,
  networkName: "mainnet",
  deployedAt: "2026-08-13T00:00:00.000Z",
  validationBlock: 1,
  validationBlockHash:
    "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  deploymentTransactions: {
    raffleFactory: {
      hash: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      blockNumber: 1,
    },
  },
  runtimeCodeHashes: {
    quoteToken: keccak256("0x01"),
    vrfWrapper: keccak256("0x01"),
    raffleFactory: keccak256("0x01"),
    raffleImplementation: keccak256("0x01"),
  },
  deployer: "0x1111111111111111111111111111111111111111",
  quoteToken: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  vrfWrapper: "0x02aae1A04f9828517b3007f83f6181900CaD910c",
  raffleFactory: "0x3333333333333333333333333333333333333333",
  raffleImplementation: "0x6666666666666666666666666666666666666666",
  protocolTreasury: "0x5555555555555555555555555555555555555555",
  callbackGasLimit: 300_000,
  requestConfirmations: 30,
  sourceCommit: "9999999999999999999999999999999999999999",
  verificationStatus: "verified",
};

interface ClientOverrides {
  readonly decimals?: number;
  readonly paused?: boolean;
  readonly raffleImplementation?: Address;
  readonly implementationEntryPrice?: bigint;
  readonly implementationInitialized?: boolean;
  readonly implementationStatus?: number;
  readonly implementationLinkToken?: Address;
  readonly wrapperConfigured?: boolean;
  readonly wrapperDisabled?: boolean;
  readonly minimumConfirmations?: number;
  readonly maximumCallbackGas?: number;
  readonly wrapperGasOverhead?: number;
  readonly validationBlockHash?: `0x${string}`;
  readonly runtimeCode?: `0x${string}`;
  readonly transactionInput?: Hex;
  readonly codeLess?: readonly Address[];
}

const coordinator = "0x9999999999999999999999999999999999999999";
const link = "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const linkNativeFeed = "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
const factoryDeploymentData = "0x1234";
const releaseEvidence: DeploymentValidationEvidence = {
  sourceCommit: candidate.sourceCommit,
  factoryDeploymentData,
  expectedRuntimeCodeHashes: {
    raffleFactory: candidate.runtimeCodeHashes.raffleFactory as Hex,
    raffleImplementation: candidate.runtimeCodeHashes
      .raffleImplementation as Hex,
  },
  async verifyPublishedSource() {},
};

describe("deployment validation", () => {
  it("accepts an ownerless six-decimal mainnet deployment", async () => {
    await validateDeploymentOnchain(fakeClient(), candidate, releaseEvidence);
  });

  it("rejects incompatible or paused quote-token state", async () => {
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({ decimals: 18 }),
        candidate,
        releaseEvidence,
      ),
      /canonical USDC decimals 6/,
    );
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({ paused: true }),
        candidate,
        releaseEvidence,
      ),
      /quote token is paused/,
    );
  });

  it("rejects an EOA mainnet treasury", async () => {
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({ codeLess: [candidate.protocolTreasury as Address] }),
        candidate,
        releaseEvidence,
      ),
      /protocolTreasury must be a reviewed contract wallet/,
    );
  });

  it("rejects a missing or mismatched raffle implementation", async () => {
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({ codeLess: [candidate.raffleImplementation as Address] }),
        candidate,
        releaseEvidence,
      ),
      /raffleImplementation has no runtime bytecode/,
    );
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({
          raffleImplementation: "0x7777777777777777777777777777777777777777",
        }),
        candidate,
        releaseEvidence,
      ),
      /factory.raffleImplementation/,
    );
  });

  it("rejects an unlocked raffle implementation", async () => {
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({ implementationInitialized: false }),
        candidate,
        releaseEvidence,
      ),
      /not permanently initialized in its locked Refunding state/,
    );
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({ implementationStatus: 1 }),
        candidate,
        releaseEvidence,
      ),
      /not permanently initialized in its locked Refunding state/,
    );
  });

  it("rejects a noncanonical implementation entry price", async () => {
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({ implementationEntryPrice: 2_000_000n }),
        candidate,
        releaseEvidence,
      ),
      /ENTRY_PRICE.*one six-decimal quote token/,
    );
  });

  it("pins the finalized validation block and every recorded runtime hash", async () => {
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({
          validationBlockHash:
            "0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
        }),
        candidate,
        releaseEvidence,
      ),
      /validation block hash/,
    );
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({ runtimeCode: "0x02" }),
        candidate,
        releaseEvidence,
      ),
      /runtime hash/,
    );
  });

  it("rejects disabled or incompatible live Chainlink configuration", async () => {
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({ wrapperDisabled: true }),
        candidate,
        releaseEvidence,
      ),
      /not configured and enabled/,
    );
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({ minimumConfirmations: 31 }),
        candidate,
        releaseEvidence,
      ),
      /outside the live Chainlink range/,
    );
    await validateDeploymentOnchain(
      fakeClient({ maximumCallbackGas: 318_162 }),
      candidate,
      releaseEvidence,
    );
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({ maximumCallbackGas: 318_161 }),
        candidate,
        releaseEvidence,
      ),
      /EIP-150 overhead.*exceeds coordinator maximum/,
    );
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({
          implementationLinkToken: "0xcccccccccccccccccccccccccccccccccccccccc",
        }),
        candidate,
        releaseEvidence,
      ),
      /implementation.getLinkToken/,
    );
  });

  it("binds the record, deployment input, and runtime to the clean local build", async () => {
    await assert.rejects(
      validateDeploymentOnchain(fakeClient(), candidate, {
        ...releaseEvidence,
        sourceCommit: "8888888888888888888888888888888888888888",
      }),
      /does not match the clean local release commit/,
    );
    await assert.rejects(
      validateDeploymentOnchain(
        fakeClient({ transactionInput: "0xdead" }),
        candidate,
        releaseEvidence,
      ),
      /exact locally compiled creation data/,
    );
    await assert.rejects(
      validateDeploymentOnchain(fakeClient(), candidate, {
        ...releaseEvidence,
        expectedRuntimeCodeHashes: {
          ...releaseEvidence.expectedRuntimeCodeHashes,
          raffleFactory: keccak256("0x02"),
        },
      }),
      /freshly compiled local release artifact/,
    );
  });

  it("requires independent published source for both contracts", async () => {
    const verified: string[] = [];
    await validateDeploymentOnchain(fakeClient(), candidate, {
      ...releaseEvidence,
      async verifyPublishedSource(_chainId, address, contractName) {
        verified.push(`${address}:${contractName}`);
      },
    });
    assert.deepEqual(verified.sort(), [
      `${candidate.raffleFactory}:RaffleFactory`,
      `${candidate.raffleImplementation}:Raffle`,
    ]);

    await assert.rejects(
      validateDeploymentOnchain(fakeClient(), candidate, {
        ...releaseEvidence,
        async verifyPublishedSource() {
          throw new Error("not an exact published match");
        },
      }),
      /not an exact published match/,
    );
  });

  it("materializes candidate-specific runtime hashes from the pinned Hardhat build info", async () => {
    const repositoryRoot = path.resolve(import.meta.dirname, "../../../../..");
    const evidence = await loadDeploymentBuildEvidence(
      repositoryRoot,
      candidate,
      link,
      candidate.sourceCommit,
      async () => {},
    );
    const alternateLinkEvidence = await loadDeploymentBuildEvidence(
      repositoryRoot,
      candidate,
      "0xcccccccccccccccccccccccccccccccccccccccc",
      candidate.sourceCommit,
      async () => {},
    );

    assert.equal(evidence.sourceCommit, candidate.sourceCommit);
    assert.ok(evidence.factoryDeploymentData.length > 1_000);
    assert.notEqual(
      evidence.expectedRuntimeCodeHashes.raffleFactory,
      candidate.runtimeCodeHashes.raffleFactory,
    );
    assert.notEqual(
      evidence.expectedRuntimeCodeHashes.raffleImplementation,
      candidate.runtimeCodeHashes.raffleImplementation,
    );
    assert.notEqual(
      evidence.expectedRuntimeCodeHashes.raffleImplementation,
      alternateLinkEvidence.expectedRuntimeCodeHashes.raffleImplementation,
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
    async getBlock() {
      return {
        number: 1n,
        hash: overrides.validationBlockHash ?? candidate.validationBlockHash,
      };
    },
    async getCode({ address }: { address: Address }) {
      return codeLess.has(address.toLowerCase())
        ? "0x"
        : (overrides.runtimeCode ?? "0x01");
    },
    async getTransactionReceipt({ hash }: { hash: `0x${string}` }) {
      return {
        status: "success",
        contractAddress: candidate.raffleFactory,
        blockNumber: 1n,
      };
    },
    async getTransaction() {
      return {
        from: candidate.deployer,
        to: null,
        input: overrides.transactionInput ?? factoryDeploymentData,
      };
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
      if (address === candidate.vrfWrapper) {
        if (functionName === "s_configured") {
          return overrides.wrapperConfigured ?? true;
        }
        if (functionName === "s_disabled") {
          return overrides.wrapperDisabled ?? false;
        }
        if (functionName === "s_vrfCoordinator") return coordinator;
        if (functionName === "link") return link;
        if (functionName === "linkNativeFeed") return linkNativeFeed;
        if (functionName === "getConfig") {
          return [
            1n,
            1,
            1,
            0,
            overrides.wrapperGasOverhead ?? 13_400,
            90_000,
            112_000,
            435,
            24,
            20,
            "0x0101010101010101010101010101010101010101010101010101010101010101",
            10,
          ];
        }
        if (functionName === "estimateRequestPriceNative") return 1n;
      }
      if (address === coordinator && functionName === "s_config") {
        return [
          overrides.minimumConfirmations ?? 3,
          overrides.maximumCallbackGas ?? 2_500_000,
          false,
          3600,
          37_185,
          0,
          0,
          24,
          20,
        ];
      }
      if (address === candidate.raffleImplementation) {
        if (functionName === "factory") return candidate.raffleFactory;
        if (functionName === "initialized") {
          return overrides.implementationInitialized ?? true;
        }
        if (functionName === "ENTRY_PRICE") {
          return overrides.implementationEntryPrice ?? 1_000_000n;
        }
        if (functionName === "status") {
          return overrides.implementationStatus ?? 5;
        }
        if (functionName === "getLinkToken") {
          return overrides.implementationLinkToken ?? link;
        }
      }
      switch (functionName) {
        case "quoteToken":
          return candidate.quoteToken;
        case "vrfWrapper":
          return candidate.vrfWrapper;
        case "callbackGasLimit":
          return candidate.callbackGasLimit;
        case "requestConfirmations":
          return candidate.requestConfirmations;
        case "raffleImplementation":
          return (
            overrides.raffleImplementation ?? candidate.raffleImplementation
          );
        case "protocolTreasury":
          return candidate.protocolTreasury;
        default:
          throw new Error(`unexpected read: ${String(functionName)}`);
      }
    },
  } as unknown as PublicClient;
}
