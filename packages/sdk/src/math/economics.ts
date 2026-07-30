export const BPS = 10_000n;
export const PROTOCOL_FEE_BPS = 500n;
export const CASH_WINNER_BPS = 8_000n;

export interface PurchaseAmounts {
  readonly grossAmount: bigint;
}

export interface ResolutionAmounts {
  readonly protocolFee: bigint;
  readonly distributablePot: bigint;
  readonly winnerCashAmount: bigint;
  readonly sponsorCashAmount: bigint;
}

export function calculatePurchaseAmounts({
  ticketPrice,
  quantity,
}: {
  readonly ticketPrice: bigint;
  readonly quantity: bigint;
}): PurchaseAmounts {
  if (ticketPrice <= 0n) throw new RangeError("ticketPrice must be positive");
  if (quantity <= 0n) throw new RangeError("quantity must be positive");

  return { grossAmount: ticketPrice * quantity };
}

export function calculateResolutionAmounts(
  grossPot: bigint,
  thresholdMet: boolean,
): ResolutionAmounts {
  if (grossPot < 0n) throw new RangeError("grossPot must not be negative");
  const protocolFee = (grossPot * PROTOCOL_FEE_BPS) / BPS;
  const distributablePot = grossPot - protocolFee;
  if (thresholdMet) {
    return {
      protocolFee,
      distributablePot,
      winnerCashAmount: 0n,
      sponsorCashAmount: distributablePot,
    };
  }

  const winnerCashAmount = (distributablePot * CASH_WINNER_BPS) / BPS;
  return {
    protocolFee,
    distributablePot,
    winnerCashAmount,
    sponsorCashAmount: distributablePot - winnerCashAmount,
  };
}

export function thresholdProgress(
  totalTickets: bigint,
  minimumTickets: bigint,
): bigint {
  if (minimumTickets <= 0n) {
    throw new RangeError("minimumTickets must be positive");
  }
  if (totalTickets < 0n) {
    throw new RangeError("totalTickets must not be negative");
  }
  return (totalTickets * 10_000n) / minimumTickets;
}
