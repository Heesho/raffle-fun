export enum RaffleState {
  Uninitialized,
  AwaitingPrize,
  Active,
  DrawRequested,
  Resolved,
  Cancelled,
  Refunding,
}

export enum RaffleOutcome {
  None,
  NftAwarded,
  CashFallback,
  NoSales,
  CancelledBeforeSale,
  DrawNotRequested,
  DrawTimedOut,
}

export const raffleStateLabels = {
  [RaffleState.Uninitialized]: "Uninitialized",
  [RaffleState.AwaitingPrize]: "Awaiting prize",
  [RaffleState.Active]: "Active",
  [RaffleState.DrawRequested]: "Randomness pending",
  [RaffleState.Resolved]: "Resolved",
  [RaffleState.Cancelled]: "Cancelled",
  [RaffleState.Refunding]: "Refunding",
} as const satisfies Record<RaffleState, string>;

export const raffleOutcomeLabels = {
  [RaffleOutcome.None]: "Pending",
  [RaffleOutcome.NftAwarded]: "NFT awarded",
  [RaffleOutcome.CashFallback]: "Cash fallback",
  [RaffleOutcome.NoSales]: "No sales",
  [RaffleOutcome.CancelledBeforeSale]: "Cancelled before sale",
  [RaffleOutcome.DrawNotRequested]: "Draw not requested — refunds",
  [RaffleOutcome.DrawTimedOut]: "Oracle timeout — refunds",
} as const satisfies Record<RaffleOutcome, string>;

export interface CreateRaffleParams {
  readonly prizeToken: `0x${string}`;
  readonly prizeTokenId: bigint;
  readonly quoteToken: `0x${string}`;
  readonly sponsorPrizeRecoveryRecipient: `0x${string}`;
  readonly ticketPrice: bigint;
  readonly minimumTickets: bigint;
  readonly startTime: bigint;
  readonly endTime: bigint;
  readonly metadataURI: string;
}
