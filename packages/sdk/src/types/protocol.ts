export enum RaffleStatus {
  AwaitingPrize,
  Active,
  Drawing,
  NftWon,
  CashWon,
  Refunding,
  Closed,
}

export const raffleStatusLabels = {
  [RaffleStatus.AwaitingPrize]: "Awaiting prize",
  [RaffleStatus.Active]: "Active",
  [RaffleStatus.Drawing]: "Randomness pending",
  [RaffleStatus.NftWon]: "NFT won",
  [RaffleStatus.CashWon]: "Cash won",
  [RaffleStatus.Refunding]: "Refunding",
  [RaffleStatus.Closed]: "Closed",
} as const satisfies Record<RaffleStatus, string>;

export interface CreateRaffleParams {
  readonly prizeToken: `0x${string}`;
  readonly prizeTokenId: bigint;
  readonly sponsorPrizeRecoveryRecipient: `0x${string}`;
  readonly ticketPrice: bigint;
  readonly minimumTickets: bigint;
  readonly startTime: bigint;
  readonly endTime: bigint;
  readonly metadataURI: string;
}
