import type { Address, Hex } from "viem";

import type { SupportedChainId } from "./chains.js";

export interface DeploymentRecord {
  readonly chainId: SupportedChainId;
  readonly networkName: string;
  readonly deployedAt: string;
  readonly deploymentBlock: bigint;
  readonly deployer: Address;
  readonly finalFactoryOwner: Address;
  readonly quoteToken: Address;
  readonly entropy: Address;
  readonly raffleFactory: Address;
  readonly raffleLens: Address;
  readonly protocolTreasury: Address;
  readonly callbackGasLimit: number;
  readonly sourceCommit: Hex;
  readonly verificationStatus: "unverified" | "partial" | "verified";
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
