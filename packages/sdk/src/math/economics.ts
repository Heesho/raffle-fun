export const BPS = 10_000n;
export const PROTOCOL_FEE_BPS = 500n;
export const PROVIDER_FEE_BPS = 500n;
export const CASH_WINNER_BPS = 8_000n;

export interface PurchaseAmounts {
  readonly grossAmount: bigint;
  readonly protocolFee: bigint;
  readonly providerFee: bigint;
  readonly netContribution: bigint;
}

export interface ResolutionAmounts {
  readonly winnerCashAmount: bigint;
  readonly sponsorCashAmount: bigint;
}

export function calculatePurchaseAmounts({
  ticketPrice,
  quantity,
  hasProvider,
}: {
  readonly ticketPrice: bigint;
  readonly quantity: bigint;
  readonly hasProvider: boolean;
}): PurchaseAmounts {
  if (ticketPrice <= 0n) throw new RangeError("ticketPrice must be positive");
  if (quantity <= 0n) throw new RangeError("quantity must be positive");

  const grossAmount = ticketPrice * quantity;
  const protocolFee = (grossAmount * PROTOCOL_FEE_BPS) / BPS;
  const providerFee = hasProvider ? (grossAmount * PROVIDER_FEE_BPS) / BPS : 0n;
  return {
    grossAmount,
    protocolFee,
    providerFee,
    netContribution: grossAmount - protocolFee - providerFee,
  };
}

export function calculateResolutionAmounts(
  netPot: bigint,
  thresholdMet: boolean,
): ResolutionAmounts {
  if (netPot < 0n) throw new RangeError("netPot must not be negative");
  if (thresholdMet) {
    return { winnerCashAmount: 0n, sponsorCashAmount: netPot };
  }

  const winnerCashAmount = (netPot * CASH_WINNER_BPS) / BPS;
  return {
    winnerCashAmount,
    sponsorCashAmount: netPot - winnerCashAmount,
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
