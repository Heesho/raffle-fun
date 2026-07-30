"use client";

import { createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";

import { supportedChains } from "@raffle-fun/config";

import { webEnv } from "./env";

export const wagmiConfig = createConfig({
  chains: supportedChains,
  connectors: [
    injected({
      shimDisconnect: true,
    }),
  ],
  multiInjectedProviderDiscovery: true,
  ssr: true,
  transports: {
    [supportedChains[0].id]: http(
      webEnv.NEXT_PUBLIC_CHAIN_ID === supportedChains[0].id
        ? webEnv.NEXT_PUBLIC_RPC_URL
        : undefined,
    ),
    [supportedChains[1].id]: http(
      webEnv.NEXT_PUBLIC_CHAIN_ID === supportedChains[1].id
        ? webEnv.NEXT_PUBLIC_RPC_URL
        : undefined,
    ),
    [supportedChains[2].id]: http(
      webEnv.NEXT_PUBLIC_CHAIN_ID === supportedChains[2].id
        ? webEnv.NEXT_PUBLIC_RPC_URL
        : "http://127.0.0.1:8545",
    ),
  },
});

declare module "wagmi" {
  interface Register {
    config: typeof wagmiConfig;
  }
}
