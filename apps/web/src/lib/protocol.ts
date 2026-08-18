import {
  deployments,
  getSupportedChain,
  isSupportedChainId,
  type DeploymentRecord,
  type SupportedChainId,
} from "@raffle-fun/config";

import { webEnv } from "./env";

export const configuredChainId = isSupportedChainId(webEnv.NEXT_PUBLIC_CHAIN_ID)
  ? webEnv.NEXT_PUBLIC_CHAIN_ID
  : 11_155_111;

export const configuredChain = getSupportedChain(
  configuredChainId as SupportedChainId,
);

export const protocolDeployment: DeploymentRecord | undefined =
  deployments[configuredChainId as SupportedChainId];

export const protocolIsConfigured = protocolDeployment !== undefined;

export function explorerAddressUrl(address: `0x${string}`): string {
  const baseUrl = configuredChain.blockExplorers?.default.url;
  return baseUrl === undefined ? "#" : `${baseUrl}/address/${address}`;
}

export function explorerTransactionUrl(hash: `0x${string}`): string {
  const baseUrl = configuredChain.blockExplorers?.default.url;
  return baseUrl === undefined ? "#" : `${baseUrl}/tx/${hash}`;
}
