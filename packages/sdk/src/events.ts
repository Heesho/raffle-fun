import { decodeEventLog, type Hex } from "viem";

import { raffleAbi, raffleFactoryAbi } from "./abis/generated.js";

export interface EncodedLog {
  readonly data: Hex;
  readonly topics: [Hex, ...Hex[]];
}

export function decodeRaffleEvent(log: EncodedLog) {
  return decodeEventLog({
    abi: raffleAbi,
    data: log.data,
    topics: log.topics,
    strict: true,
  });
}

export function decodeFactoryEvent(log: EncodedLog) {
  return decodeEventLog({
    abi: raffleFactoryAbi,
    data: log.data,
    topics: log.topics,
    strict: true,
  });
}
