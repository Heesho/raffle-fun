"use client";

import { erc20Abi, type Address } from "viem";
import { useReadContracts } from "wagmi";

export interface TokenMetadata {
  readonly symbol: string;
  readonly decimals: number | undefined;
}

export function useTokenMetadata(token: Address | undefined): TokenMetadata {
  const query = useReadContracts({
    allowFailure: true,
    contracts:
      token === undefined
        ? []
        : [
            { address: token, abi: erc20Abi, functionName: "symbol" },
            { address: token, abi: erc20Abi, functionName: "decimals" },
          ],
    query: { enabled: token !== undefined, staleTime: 300_000 },
  });
  const symbolResult = query.data?.[0];
  const decimalsResult = query.data?.[1];
  return {
    symbol:
      symbolResult?.status === "success" &&
      typeof symbolResult.result === "string"
        ? symbolResult.result.slice(0, 16)
        : "ERC20",
    decimals:
      decimalsResult?.status === "success" &&
      typeof decimalsResult.result === "number"
        ? decimalsResult.result
        : undefined,
  };
}
