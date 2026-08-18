"use client";

import { erc20Abi, type Address } from "viem";
import { useReadContracts } from "wagmi";

import { isDemoMode } from "@/lib/demo";
import { SANDBOX_USDC } from "@/lib/sandbox/adapter";

export interface TokenMetadata {
  readonly symbol: string;
  readonly decimals: number | undefined;
}

export function useTokenMetadata(token: Address | undefined): TokenMetadata {
  const demo =
    isDemoMode() && token?.toLowerCase() === SANDBOX_USDC.address
      ? SANDBOX_USDC
      : undefined;
  const query = useReadContracts({
    allowFailure: true,
    contracts:
      token === undefined || demo !== undefined
        ? []
        : [
            { address: token, abi: erc20Abi, functionName: "symbol" },
            { address: token, abi: erc20Abi, functionName: "decimals" },
          ],
    query: {
      enabled: token !== undefined && demo === undefined,
      staleTime: 300_000,
    },
  });
  if (demo !== undefined) {
    return { symbol: demo.symbol, decimals: demo.decimals };
  }
  const symbolResult = query.data?.[0];
  const decimalsResult = query.data?.[1];
  return {
    symbol:
      symbolResult?.status === "success" &&
      typeof symbolResult.result === "string"
        ? symbolResult.result.slice(0, 16)
        : "USDC",
    decimals:
      decimalsResult?.status === "success" &&
      typeof decimalsResult.result === "number"
        ? decimalsResult.result
        : 6,
  };
}
