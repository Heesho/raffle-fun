/** The winner's share of the net pot when the ticket threshold is missed. */
export const WINNER_CASH_SHARE_PERCENT = 80n;

export function cashToWinner(netPot: bigint): bigint {
  return (netPot * WINNER_CASH_SHARE_PERCENT) / 100n;
}

export function cashToSponsor(netPot: bigint): bigint {
  return netPot - cashToWinner(netPot);
}

export function ticketsToThreshold(total: bigint, minimum: bigint): bigint {
  return total >= minimum ? 0n : minimum - total;
}

export interface ThresholdScale {
  /** Percent of the track filled by tickets sold. */
  readonly fillPercent: number;
  /** Percent of the track at which the prize flips to the NFT. */
  readonly markerPercent: number;
  /** Percent of the track filled beyond the threshold, if oversold. */
  readonly overshootPercent: number;
  readonly met: boolean;
}

/**
 * Lays out the threshold track.
 *
 * Sales are uncapped, so the track always keeps headroom past the threshold.
 * Scaling to `max(sold, minimum)` instead would pin the flip point to the
 * right edge in every under-sold raffle — exactly the case where a buyer most
 * needs to see how far away it is — and make an exactly-met raffle read as an
 * ordinary full bar.
 */
export function thresholdScale(total: bigint, minimum: bigint): ThresholdScale {
  const sold = Number(total);
  const target = Number(minimum);
  if (target <= 0) {
    return {
      fillPercent: sold > 0 ? 100 : 0,
      markerPercent: 0,
      overshootPercent: 0,
      met: true,
    };
  }

  // Headroom keeps the marker around 78% of the track when under-sold, and
  // grows once sales run past it so the overshoot stays visible.
  const scale = Math.max(target * 1.28, sold * 1.08);
  const clamp = (value: number) => Math.min(100, Math.max(0, value));
  const markerPercent = clamp((target / scale) * 100);
  const fillPercent = clamp((sold / scale) * 100);

  return {
    fillPercent,
    markerPercent,
    overshootPercent: Math.max(0, fillPercent - markerPercent),
    met: total >= minimum,
  };
}
