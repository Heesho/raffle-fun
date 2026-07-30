import type { Chain } from "viem";
import { base, baseSepolia, foundry, mainnet, sepolia } from "viem/chains";

/**
 * Supported networks.
 *
 * The tuple is annotated as `Chain[]` rather than inferred with `as const`:
 * each viem chain carries a large structural type, and letting TypeScript
 * infer a five-member union of them — then propagate it through wagmi's config
 * generics — exhausts the compiler's heap. The ids are declared separately so
 * `SupportedChainId` stays a precise literal union.
 */
export const supportedChains: readonly [Chain, ...Chain[]] = [
  mainnet,
  sepolia,
  base,
  baseSepolia,
  foundry,
];

export const productionChains: readonly [Chain, ...Chain[]] = [mainnet, base];

export type SupportedChainId = 1 | 11_155_111 | 8_453 | 84_532 | 31_337;

const supportedChainIds: readonly SupportedChainId[] = [
  1, 11_155_111, 8_453, 84_532, 31_337,
];

export const defaultChain = mainnet;

export const defaultDevelopmentChain = sepolia;

export function isSupportedChainId(
  chainId: number,
): chainId is SupportedChainId {
  return supportedChainIds.includes(chainId as SupportedChainId);
}

export function getSupportedChain(chainId: SupportedChainId): Chain {
  const chain = supportedChains.find((candidate) => candidate.id === chainId);
  if (chain === undefined) {
    throw new Error(`Unsupported chain ID: ${chainId}`);
  }
  return chain;
}
