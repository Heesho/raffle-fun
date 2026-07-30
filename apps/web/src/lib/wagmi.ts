"use client";

import { createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";

import { supportedChains } from "@raffle-fun/config";

import { webEnv } from "./env";

const ANVIL_CHAIN_ID = 31_337;

/**
 * One transport per supported chain, derived from the chain list rather than
 * indexed positionally, so adding a network cannot silently leave it without
 * an RPC. The configured chain gets the operator's endpoint; the rest fall
 * back to viem's defaults.
 */
const transports = Object.fromEntries(
  supportedChains.map((chain) => [
    chain.id,
    http(
      webEnv.NEXT_PUBLIC_CHAIN_ID === chain.id
        ? webEnv.NEXT_PUBLIC_RPC_URL
        : chain.id === ANVIL_CHAIN_ID
          ? "http://127.0.0.1:8545"
          : undefined,
    ),
  ]),
);

export const wagmiConfig = createConfig({
  chains: supportedChains,
  connectors: [
    injected({
      shimDisconnect: true,
    }),
  ],
  multiInjectedProviderDiscovery: true,
  ssr: true,
  transports,
});

declare module "wagmi" {
  interface Register {
    config: typeof wagmiConfig;
  }
}
