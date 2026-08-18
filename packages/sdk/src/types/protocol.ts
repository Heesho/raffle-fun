import type { Address } from "viem";

export enum RaffleStatus {
  AwaitingPrize,
  Active,
  Drawing,
  NftWon,
  CashWon,
  Refunding,
}

export const raffleStatusLabels = {
  [RaffleStatus.AwaitingPrize]: "Awaiting prize",
  [RaffleStatus.Active]: "Active",
  [RaffleStatus.Drawing]: "Randomness pending",
  [RaffleStatus.NftWon]: "NFT won",
  [RaffleStatus.CashWon]: "Cash won",
  [RaffleStatus.Refunding]: "Refunding",
} as const satisfies Record<RaffleStatus, string>;

export interface CreateRaffleParams {
  readonly sponsorRecipient: Address;
  readonly prizeToken: Address;
  readonly prizeTokenId: bigint;
  readonly reserveEntries: bigint;
  readonly endTime: bigint;
}
