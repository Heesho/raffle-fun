export const BPS = 10_000n;
export const PROTOCOL_FEE_BPS = 500n;
export const CASH_WINNER_BPS = 8_000n;
export const ENTRY_PRICE = 1_000_000n;
export const MAX_UINT128 = (1n << 128n) - 1n;
export const MAX_UINT64 = (1n << 64n) - 1n;
export const MAX_REFUND_TICKET_BATCH_SIZE = 100n;
export const MAX_SALE_DURATION_SECONDS = 30n * 24n * 60n * 60n;
export const DRAW_CALLBACK_TIMEOUT_SECONDS = 2n * 24n * 60n * 60n;

export interface PurchaseAmounts {
  readonly grossAmount: bigint;
}

/** Quote-token settlement created when the winning ticket is settled. */
export interface ResolutionAmounts {
  readonly protocolFee: bigint;
  readonly distributablePot: bigint;
  readonly winnerCashAmount: bigint;
  readonly sponsorAmount: bigint;
}

export interface RefundAmounts {
  readonly grossRefundLiability: bigint;
  readonly redeemedRefunds: bigint;
  readonly remainingRefundLiability: bigint;
  readonly protocolFee: 0n;
}

export interface TicketRange {
  readonly firstEntry: bigint;
  readonly lastEntry: bigint;
  readonly entryCount: bigint;
}

export function calculatePurchaseAmounts({
  entryCount,
}: {
  readonly entryCount: bigint;
}): PurchaseAmounts {
  validateEntryCount(entryCount);
  return { grossAmount: ENTRY_PRICE * entryCount };
}

/**
 * Calculates eventual settlement. For an NFT result the fee and sponsor amount
 * are allocated only when the winning ticket is successfully settled.
 */
export function calculateResolutionAmounts(
  grossPot: bigint,
  reserveMet: boolean,
): ResolutionAmounts {
  if (grossPot < 0n) throw new RangeError("grossPot must not be negative");
  const protocolFee = (grossPot * PROTOCOL_FEE_BPS) / BPS;
  const distributablePot = grossPot - protocolFee;
  const winnerCashAmount = reserveMet ? 0n : (grossPot * CASH_WINNER_BPS) / BPS;
  return {
    protocolFee,
    distributablePot,
    winnerCashAmount,
    sponsorAmount: reserveMet
      ? distributablePot
      : distributablePot - winnerCashAmount,
  };
}

export function calculateRefundAmounts({
  totalEntries,
  redeemedEntries = 0n,
}: {
  readonly totalEntries: bigint;
  readonly redeemedEntries?: bigint;
}): RefundAmounts {
  if (totalEntries < 0n || totalEntries > MAX_UINT128) {
    throw new RangeError("totalEntries must fit uint128");
  }
  if (redeemedEntries < 0n || redeemedEntries > totalEntries) {
    throw new RangeError("redeemedEntries must be within the sold entry range");
  }

  const grossRefundLiability = ENTRY_PRICE * totalEntries;
  const redeemedRefunds = ENTRY_PRICE * redeemedEntries;
  return {
    grossRefundLiability,
    redeemedRefunds,
    remainingRefundLiability: grossRefundLiability - redeemedRefunds,
    protocolFee: 0n,
  };
}

export function reserveProgress(
  totalEntries: bigint,
  reserveEntries: bigint,
): bigint {
  if (reserveEntries <= 0n || reserveEntries > MAX_UINT128) {
    throw new RangeError("reserveEntries must be between 1 and uint128 max");
  }
  if (totalEntries < 0n || totalEntries > MAX_UINT128) {
    throw new RangeError("totalEntries must fit uint128");
  }
  return (totalEntries * BPS) / reserveEntries;
}

/** Checks a range returned by `Raffle.ticketRange(ticketId)` without enumeration. */
export function ticketRangeContainsEntry(
  range: Pick<TicketRange, "firstEntry" | "lastEntry">,
  entry: bigint,
): boolean {
  if (entry <= 0n || entry > MAX_UINT128) return false;
  validateTicketRange(range);
  return entry >= range.firstEntry && entry <= range.lastEntry;
}

export function validateTicketRange(
  range: Pick<TicketRange, "firstEntry" | "lastEntry">,
): void {
  if (
    range.firstEntry <= 0n ||
    range.firstEntry > MAX_UINT128 ||
    range.lastEntry < range.firstEntry ||
    range.lastEntry > MAX_UINT128
  ) {
    throw new RangeError("ticket range must be an inclusive uint128 range");
  }
}

export function validateTicketId(ticketId: bigint): void {
  if (ticketId <= 0n || ticketId > (1n << 256n) - 1n) {
    throw new RangeError("ticketId must be a positive uint256");
  }
}

export function validateEntryCount(entryCount: bigint): void {
  if (entryCount <= 0n || entryCount > MAX_UINT128) {
    throw new RangeError("entryCount must be between 1 and uint128 max");
  }
}
