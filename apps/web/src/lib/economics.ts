export const ENTRY_PRICE = 1_000_000n;
export const PROTOCOL_FEE_PERCENT = 5n;
export const CASH_WINNER_PERCENT_OF_GROSS = 80n;

export function distributablePot(grossPot: bigint): bigint {
  return grossPot - (grossPot * PROTOCOL_FEE_PERCENT) / 100n;
}

/** Below reserve, the winning ticket receives 80% of gross sales. */
export function cashToWinner(grossPot: bigint): bigint {
  return (grossPot * CASH_WINNER_PERCENT_OF_GROSS) / 100n;
}

/** Below reserve, the sponsor receives the exact remainder after winner and fee, plus the NFT. */
export function cashToSponsor(grossPot: bigint): bigint {
  const distributable = distributablePot(grossPot);
  return distributable - cashToWinner(grossPot);
}

export function entriesToReserve(total: bigint, reserve: bigint): bigint {
  return total >= reserve ? 0n : reserve - total;
}

export interface ReserveScale {
  /** Percent of the track filled by entries sold. */
  readonly fillPercent: number;
  /** Percent of the track at which the prize flips to the NFT. */
  readonly markerPercent: number;
  /** Percent of the track filled beyond the reserve, if oversold. */
  readonly overshootPercent: number;
  readonly met: boolean;
}

/**
 * Lays out the reserve track without converting uncapped entry counts to
 * JavaScript numbers. Only the final bounded basis-point ratios are converted.
 */
export function reserveScale(total: bigint, reserve: bigint): ReserveScale {
  if (reserve <= 0n) {
    return {
      fillPercent: total > 0n ? 100 : 0,
      markerPercent: 0,
      overshootPercent: 0,
      met: true,
    };
  }

  const reserveHeadroom = (reserve * 128n + 99n) / 100n;
  const salesHeadroom = (total * 108n + 99n) / 100n;
  const scale =
    reserveHeadroom > salesHeadroom ? reserveHeadroom : salesHeadroom;
  const percent = (value: bigint) =>
    Number((value * 10_000n) / (scale === 0n ? 1n : scale)) / 100;
  const markerPercent = Math.min(100, percent(reserve));
  const fillPercent = Math.min(100, percent(total));

  return {
    fillPercent,
    markerPercent,
    overshootPercent: Math.max(0, fillPercent - markerPercent),
    met: total >= reserve,
  };
}
