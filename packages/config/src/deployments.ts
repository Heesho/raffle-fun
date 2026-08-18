import type { Address, Hex } from "viem";

import type { SupportedChainId } from "./chains.js";

/** Bare 40-character Git commit SHA; deployment schema validation enforces the shape. */
export type GitCommitSha = string;

export interface DeploymentRecord {
  readonly chainId: SupportedChainId;
  readonly networkName: "mainnet" | "sepolia";
  readonly deployedAt: string;
  readonly validationBlock: bigint;
  readonly validationBlockHash: Hex;
  readonly deploymentTransactions: {
    readonly raffleFactory: {
      readonly hash: Hex;
      readonly blockNumber: bigint;
    };
  };
  readonly runtimeCodeHashes: {
    readonly quoteToken: Hex;
    readonly vrfWrapper: Hex;
    readonly raffleFactory: Hex;
    readonly raffleImplementation: Hex;
  };
  readonly deployer: Address;
  readonly finalFactoryOwner: Address;
  readonly quoteToken: Address;
  readonly vrfWrapper: Address;
  readonly raffleFactory: Address;
  readonly raffleImplementation: Address;
  readonly protocolTreasury: Address;
  readonly callbackGasLimit: 300_000;
  readonly requestConfirmations: 30;
  readonly sourceCommit: GitCommitSha;
  readonly verificationStatus: "verified";
}

export const deployments: Readonly<
  Partial<Record<SupportedChainId, DeploymentRecord>>
> = {};

export function getDeployment(chainId: SupportedChainId): DeploymentRecord {
  const deployment = deployments[chainId];
  if (deployment === undefined) {
    throw new Error(
      `Raffle Fun is not deployed on chain ${chainId}; no placeholder address is available.`,
    );
  }
  return deployment;
}

export function hasDeployment(chainId: SupportedChainId): boolean {
  return deployments[chainId] !== undefined;
}

type Assert<T extends true> = T;
type BareGitShaFixture = Assert<
  "9999999999999999999999999999999999999999" extends DeploymentRecord["sourceCommit"]
    ? true
    : false
>;
