export const BPS = 10_000n;
export const PROTOCOL_FEE_BPS = 500n;
export const CASH_WINNER_BPS = 8_000n;
export const MAX_TICKETS_PER_PURCHASE = 100n;
export const MAX_REFUND_REDEMPTION_BATCH_SIZE = 100n;
export const MAX_START_DELAY_SECONDS = 7n * 24n * 60n * 60n;
export const MAX_SALE_DURATION_SECONDS = 30n * 24n * 60n * 60n;
export const DRAW_REQUEST_GRACE_SECONDS = 3n * 24n * 60n * 60n;
export const DRAW_CALLBACK_TIMEOUT_SECONDS = 2n * 24n * 60n * 60n;

export interface PurchaseAmounts {
  readonly grossAmount: bigint;
}

export interface ResolutionAmounts {
  readonly protocolFee: bigint;
  readonly distributablePot: bigint;
  readonly winnerCashAmount: bigint;
  readonly sponsorCashAmount: bigint;
}

export interface RefundAmounts {
  readonly grossRefundLiability: bigint;
  readonly redeemedRefunds: bigint;
  readonly remainingRefundLiability: bigint;
  readonly protocolFee: 0n;
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

export function calculateRefundAmounts({
  ticketPrice,
  totalTickets,
  redeemedTickets = 0n,
}: {
  readonly ticketPrice: bigint;
  readonly totalTickets: bigint;
  readonly redeemedTickets?: bigint;
}): RefundAmounts {
  if (ticketPrice <= 0n) throw new RangeError("ticketPrice must be positive");
  if (totalTickets < 0n) {
    throw new RangeError("totalTickets must not be negative");
  }
  if (redeemedTickets < 0n || redeemedTickets > totalTickets) {
    throw new RangeError(
      "redeemedTickets must be within the sold ticket range",
    );
  }

  const grossRefundLiability = ticketPrice * totalTickets;
  const redeemedRefunds = ticketPrice * redeemedTickets;
  return {
    grossRefundLiability,
    redeemedRefunds,
    remainingRefundLiability: grossRefundLiability - redeemedRefunds,
    protocolFee: 0n,
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
