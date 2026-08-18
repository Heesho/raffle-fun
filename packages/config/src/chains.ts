import { foundry, mainnet, sepolia } from "viem/chains";

export const supportedChains = [sepolia, mainnet, foundry] as const;

export const productionChains = [sepolia, mainnet] as const;

export type SupportedChainId = (typeof supportedChains)[number]["id"];

export const defaultDevelopmentChain = sepolia;

export function isSupportedChainId(
  chainId: number,
): chainId is SupportedChainId {
  return supportedChains.some((chain) => chain.id === chainId);
}

export function getSupportedChain(chainId: SupportedChainId) {
  const chain = supportedChains.find((candidate) => candidate.id === chainId);
  if (chain === undefined) {
    throw new Error(`Unsupported chain ID: ${chainId}`);
  }
  return chain;
}
