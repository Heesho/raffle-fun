import type { Address } from "viem";

import { getDeployment, type SupportedChainId } from "@raffle-fun/config";

import { raffleAbi, raffleFactoryAbi } from "./abis/generated.js";

export function getProtocolContracts(chainId: SupportedChainId) {
  const deployment = getDeployment(chainId);
  return {
    raffleFactory: {
      address: deployment.raffleFactory,
      abi: raffleFactoryAbi,
    },
  } as const;
}

export function getRaffleContract(address: Address) {
  return { address, abi: raffleAbi } as const;
}
