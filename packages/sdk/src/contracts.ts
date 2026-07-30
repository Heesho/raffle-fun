import type { Address } from "viem";

import { getDeployment, type SupportedChainId } from "@raffle-fun/config";

import {
  raffleAbi,
  raffleFactoryAbi,
  raffleLensAbi,
} from "./abis/generated.js";

export function getProtocolContracts(chainId: SupportedChainId) {
  const deployment = getDeployment(chainId);
  return {
    raffleFactory: {
      address: deployment.raffleFactory,
      abi: raffleFactoryAbi,
    },
    raffleLens: {
      address: deployment.raffleLens,
      abi: raffleLensAbi,
    },
  } as const;
}

export function getRaffleContract(address: Address) {
  return { address, abi: raffleAbi } as const;
}
