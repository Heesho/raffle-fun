/** Offline model of the production entry-ticket settlement. */

export const ENTRY_PRICE = 1_000_000n;
export const PROTOCOL_FEE_PERCENT = 5n;
export const CASH_WINNER_PERCENT_OF_GROSS = 80n;
export const MAX_UINT128 = (1n << 128n) - 1n;
export const MAX_REFUND_TICKET_BATCH_SIZE = 100;
export const DRAW_REQUEST_TIMEOUT_MS = 2 * 24 * 60 * 60 * 1_000;
export const CALLBACK_TIMEOUT_MS = 2 * 24 * 60 * 60 * 1_000;
export const VRF_FEE = 1_500_000_000_000_000n;

export type SandboxStatus =
  "ACTIVE" | "DRAWING" | "NFT_WON" | "CASH_WON" | "REFUNDING";

export interface SandboxTicket {
  readonly id: bigint;
  readonly owner: string;
  readonly firstEntry: bigint;
  readonly lastEntry: bigint;
  readonly burned?: boolean;
}

export interface SandboxRaffle {
  readonly id: string;
  readonly factoryId: string;
  readonly sponsor: string;
  readonly sponsorRecipient: string;
  readonly protocolTreasury: string;
  readonly prizeToken: string;
  readonly prizeTokenId: string;
  readonly prizeCollection: string;
  readonly prizeName: string;
  readonly prizeImage: string;
  readonly prizePixelated?: boolean;
  readonly reserveEntries: bigint;
  readonly endTime: number;
  readonly status: SandboxStatus;
  readonly tickets: readonly SandboxTicket[];
  readonly totalEntries: bigint;
  readonly grossSales: bigint;
  readonly unsettledPot: bigint;
  readonly remainingRefundLiability: bigint;
  readonly winnerRecipient: string | null;
  readonly winnerProceeds: bigint;
  readonly sponsorProceeds: bigint;
  readonly protocolFees: bigint;
  readonly winningEntry: bigint | null;
  readonly winningTicketId: bigint | null;
  readonly prizeClaimed: boolean;
  readonly drawRequestedAt: number | null;
  readonly drawRequestedBy: string | null;
  readonly callbackDeadline: number | null;
  readonly resolvedAt: number | null;
}

export interface SandboxWallet {
  readonly usdc: bigint;
  readonly eth: bigint;
  readonly nfts: readonly string[];
}

export interface Sandbox {
  readonly player: string;
  readonly wallet: SandboxWallet;
  readonly raffles: readonly SandboxRaffle[];
  readonly log: readonly SandboxEvent[];
  readonly seed: number;
}

export interface SandboxEvent {
  readonly id: string;
  readonly raffleId: string;
  readonly kind:
    | "PURCHASE"
    | "DRAW_REQUESTED"
    | "RESOLVED"
    | "SPONSOR_PROCEEDS_RELEASED"
    | "PROTOCOL_FEES_RELEASED"
    | "WINNER_PROCEEDS_RELEASED"
    | "WINNER_PRIZE_RELEASED"
    | "SPONSOR_PRIZE_RELEASED"
    | "REFUNDS_ENABLED"
    | "REFUND_REDEEMED"
    | "WINNING_SETTLED";
  readonly account: string;
  readonly amount: bigint | null;
  readonly at: number;
  readonly detail?: string;
}

export class SandboxError extends Error {}

function fail(message: string): never {
  throw new SandboxError(message);
}

export function nextRandom(seed: number): { value: number; seed: number } {
  const next = (Math.imul(seed, 1_664_525) + 1_013_904_223) >>> 0;
  return { value: next >>> 8, seed: next };
}

export function ticketEntryCount(ticket: SandboxTicket): bigint {
  return ticket.lastEntry - ticket.firstEntry + 1n;
}

export function ticketContainingEntry(
  raffle: SandboxRaffle,
  entry: bigint,
): SandboxTicket | undefined {
  return raffle.tickets.find(
    (ticket) =>
      !ticket.burned && entry >= ticket.firstEntry && entry <= ticket.lastEntry,
  );
}

export function reserveMet(raffle: SandboxRaffle): boolean {
  return raffle.totalEntries >= raffle.reserveEntries;
}

export function entriesOwnedBy(raffle: SandboxRaffle, account: string): bigint {
  const normalized = account.toLowerCase();
  return raffle.tickets.reduce(
    (total, ticket) =>
      !ticket.burned && ticket.owner.toLowerCase() === normalized
        ? total + ticketEntryCount(ticket)
        : total,
    0n,
  );
}

export function ticketsOwnedBy(
  raffle: SandboxRaffle,
  account: string,
): readonly SandboxTicket[] {
  const normalized = account.toLowerCase();
  return raffle.tickets.filter(
    (ticket) => !ticket.burned && ticket.owner.toLowerCase() === normalized,
  );
}

export function isOpen(raffle: SandboxRaffle, now: number): boolean {
  return raffle.status === "ACTIVE" && now < raffle.endTime;
}

export function drawRequestDeadline(raffle: SandboxRaffle): number {
  return raffle.endTime + DRAW_REQUEST_TIMEOUT_MS;
}

export function canRequestDraw(raffle: SandboxRaffle, now: number): boolean {
  return (
    raffle.status === "ACTIVE" &&
    raffle.totalEntries > 0n &&
    now >= raffle.endTime &&
    now < drawRequestDeadline(raffle)
  );
}

export function canEnableRefunds(
  raffle: SandboxRaffle,
  account: string,
  now: number,
): boolean {
  if (raffle.status === "ACTIVE") {
    if (raffle.totalEntries === 0n) {
      return (
        now >= raffle.endTime ||
        account.toLowerCase() === raffle.sponsor.toLowerCase()
      );
    }
    return now >= drawRequestDeadline(raffle);
  }
  if (raffle.status === "DRAWING" && raffle.callbackDeadline !== null) {
    return now >= raffle.callbackDeadline;
  }
  return false;
}

function replace(
  sandbox: Sandbox,
  raffle: SandboxRaffle,
  event: SandboxEvent,
  wallet: SandboxWallet = sandbox.wallet,
  seed: number = sandbox.seed,
): Sandbox {
  return {
    ...sandbox,
    seed,
    wallet,
    raffles: sandbox.raffles.map((entry) =>
      entry.id === raffle.id ? raffle : entry,
    ),
    log: [event, ...sandbox.log].slice(0, 60),
  };
}

function eventId(raffle: string, kind: string, at: number): string {
  return `${raffle}-${kind}-${at}-${Math.round(Math.random() * 1e6)}`;
}

export function buyEntries(
  sandbox: Sandbox,
  raffleId: string,
  entryCount: bigint,
  now: number,
  owner: string = sandbox.player,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (entryCount <= 0n) fail("Choose at least one entry.");
  if (entryCount > MAX_UINT128 - raffle.totalEntries) {
    fail("That purchase exceeds the uint128 entry range.");
  }
  if (!isOpen(raffle, now)) fail("Entry sales are not open.");
  const gross = ENTRY_PRICE * entryCount;
  if (owner === sandbox.player && sandbox.wallet.usdc < gross) {
    fail("Not enough USDC for that many entries.");
  }

  const firstEntry = raffle.totalEntries + 1n;
  const lastEntry = raffle.totalEntries + entryCount;
  const ticket: SandboxTicket = {
    id: BigInt(raffle.tickets.length + 1),
    owner,
    firstEntry,
    lastEntry,
  };
  return replace(
    sandbox,
    {
      ...raffle,
      tickets: [...raffle.tickets, ticket],
      totalEntries: lastEntry,
      grossSales: lastEntry * ENTRY_PRICE,
      unsettledPot: raffle.unsettledPot + gross,
    },
    {
      id: eventId(raffle.id, "PURCHASE", now),
      raffleId: raffle.id,
      kind: "PURCHASE",
      account: owner,
      amount: gross,
      at: now,
      detail: `${entryCount.toString()} entr${entryCount === 1n ? "y" : "ies"} in one ticket`,
    },
    owner === sandbox.player
      ? { ...sandbox.wallet, usdc: sandbox.wallet.usdc - gross }
      : sandbox.wallet,
  );
}

export function requestDraw(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (!canRequestDraw(raffle, now)) fail("The draw is not available.");
  if (sandbox.wallet.eth < VRF_FEE)
    fail("Not enough ETH for the randomness fee.");
  return replace(
    sandbox,
    {
      ...raffle,
      status: "DRAWING",
      drawRequestedAt: now,
      drawRequestedBy: sandbox.player,
      callbackDeadline: now + CALLBACK_TIMEOUT_MS,
    },
    {
      id: eventId(raffle.id, "DRAW_REQUESTED", now),
      raffleId: raffle.id,
      kind: "DRAW_REQUESTED",
      account: sandbox.player,
      amount: VRF_FEE,
      at: now,
    },
    { ...sandbox.wallet, eth: sandbox.wallet.eth - VRF_FEE },
  );
}

/** The callback selects one entry only; it never searches tickets or allocates payouts. */
export function resolveDraw(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (raffle.status !== "DRAWING") fail("This raffle has no pending draw.");
  if (raffle.callbackDeadline !== null && now >= raffle.callbackDeadline) {
    return sandbox;
  }
  const { value, seed } = nextRandom(sandbox.seed);
  const winningEntry = (BigInt(value) % raffle.totalEntries) + 1n;
  const met = reserveMet(raffle);
  return replace(
    sandbox,
    {
      ...raffle,
      status: met ? "NFT_WON" : "CASH_WON",
      winningEntry,
      resolvedAt: now,
    },
    {
      id: eventId(raffle.id, "RESOLVED", now),
      raffleId: raffle.id,
      kind: "RESOLVED",
      // Resolution deliberately mirrors the callback: record the entry only.
      // Ticket range and ownership are checked later during settlement.
      account: raffle.id,
      amount: null,
      at: now,
      detail: `entry #${winningEntry.toString()} won`,
    },
    sandbox.wallet,
    seed,
  );
}

export function enableRefunds(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (!canEnableRefunds(raffle, sandbox.player, now)) {
    fail("Refunds are not available for this raffle.");
  }
  const refundLiability = raffle.unsettledPot;
  return replace(
    sandbox,
    {
      ...raffle,
      status: "REFUNDING",
      unsettledPot: 0n,
      remainingRefundLiability: refundLiability,
    },
    {
      id: eventId(raffle.id, "REFUNDS_ENABLED", now),
      raffleId: raffle.id,
      kind: "REFUNDS_ENABLED",
      account: sandbox.player,
      amount: refundLiability,
      at: now,
    },
  );
}

export function refundTickets(
  sandbox: Sandbox,
  raffleId: string,
  ticketIds: readonly bigint[],
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (raffle.status !== "REFUNDING") fail("This raffle is not refunding.");
  if (ticketIds.length < 1 || ticketIds.length > MAX_REFUND_TICKET_BATCH_SIZE) {
    fail("Claim between one and 100 purchase tickets.");
  }
  if (new Set(ticketIds.map(String)).size !== ticketIds.length) {
    fail("A ticket appears twice.");
  }

  const selected = new Set(ticketIds.map(String));
  let redeemedEntries = 0n;
  for (const ticketId of ticketIds) {
    const ticket = raffle.tickets.find((entry) => entry.id === ticketId);
    if (ticket === undefined || ticket.burned)
      fail("Unknown or already burned ticket.");
    if (ticket.owner.toLowerCase() !== sandbox.player.toLowerCase()) {
      fail("Only the current ticket owner can claim its refund.");
    }
    redeemedEntries += ticketEntryCount(ticket);
  }
  const amount = ENTRY_PRICE * redeemedEntries;
  const tickets = raffle.tickets.map((ticket) =>
    selected.has(ticket.id.toString()) ? { ...ticket, burned: true } : ticket,
  );
  return replace(
    sandbox,
    {
      ...raffle,
      tickets,
      remainingRefundLiability: raffle.remainingRefundLiability - amount,
    },
    {
      id: eventId(raffle.id, "REFUND_REDEEMED", now),
      raffleId: raffle.id,
      kind: "REFUND_REDEEMED",
      account: sandbox.player,
      amount,
      at: now,
      detail: `${ticketIds.length} ticket${ticketIds.length === 1 ? "" : "s"} · ${redeemedEntries.toString()} entries`,
    },
    { ...sandbox.wallet, usdc: sandbox.wallet.usdc + amount },
  );
}

export function settleWinningTicket(
  sandbox: Sandbox,
  raffleId: string,
  ticketId: bigint,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (raffle.status !== "NFT_WON" && raffle.status !== "CASH_WON") {
    fail("The winning prize is not available.");
  }
  if (raffle.winningEntry === null) fail("No winning entry was selected.");
  const ticket = raffle.tickets.find((entry) => entry.id === ticketId);
  if (ticket === undefined || ticket.burned)
    fail("The winning ticket was already claimed or does not exist.");
  if (
    raffle.winningEntry < ticket.firstEntry ||
    raffle.winningEntry > ticket.lastEntry
  ) {
    fail("That ticket does not contain the winning entry.");
  }
  const nftWon = raffle.status === "NFT_WON";
  const gross = raffle.unsettledPot;
  const protocolFee = (gross * PROTOCOL_FEE_PERCENT) / 100n;
  const cashAmount = nftWon
    ? 0n
    : (gross * CASH_WINNER_PERCENT_OF_GROSS) / 100n;
  const sponsorAmount = gross - protocolFee - cashAmount;
  const tickets = raffle.tickets.map((entry) =>
    entry.id === ticket.id ? { ...entry, burned: true } : entry,
  );
  return replace(
    sandbox,
    {
      ...raffle,
      tickets,
      winningTicketId: ticket.id,
      winnerRecipient: ticket.owner,
      winnerProceeds: cashAmount,
      unsettledPot: 0n,
      sponsorProceeds: sponsorAmount,
      protocolFees: protocolFee,
    },
    {
      id: eventId(raffle.id, "WINNING_SETTLED", now),
      raffleId: raffle.id,
      kind: "WINNING_SETTLED",
      account: ticket.owner,
      amount: cashAmount === 0n ? null : cashAmount,
      at: now,
      detail: `ticket ${ticket.id.toString()}`,
    },
    sandbox.wallet,
  );
}

export function releaseWinnerProceeds(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  const amount = raffle.winnerProceeds;
  const recipient = raffle.winnerRecipient;
  if (amount <= 0n || recipient === null) {
    fail("There are no winner proceeds to release.");
  }
  return replace(
    sandbox,
    { ...raffle, winnerProceeds: 0n },
    {
      id: eventId(raffle.id, "WINNER_PROCEEDS_RELEASED", now),
      raffleId: raffle.id,
      kind: "WINNER_PROCEEDS_RELEASED",
      account: recipient,
      amount,
      at: now,
    },
    recipient.toLowerCase() === sandbox.player.toLowerCase()
      ? { ...sandbox.wallet, usdc: sandbox.wallet.usdc + amount }
      : sandbox.wallet,
  );
}

export function releaseWinnerPrize(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  const recipient = raffle.winnerRecipient;
  if (raffle.status !== "NFT_WON" || recipient === null) {
    fail("The winner NFT is not available.");
  }
  if (raffle.prizeClaimed) fail("The NFT has already been claimed.");
  return replace(
    sandbox,
    { ...raffle, prizeClaimed: true },
    {
      id: eventId(raffle.id, "WINNER_PRIZE_RELEASED", now),
      raffleId: raffle.id,
      kind: "WINNER_PRIZE_RELEASED",
      account: recipient,
      amount: null,
      at: now,
    },
    recipient.toLowerCase() === sandbox.player.toLowerCase()
      ? { ...sandbox.wallet, nfts: [...sandbox.wallet.nfts, raffle.id] }
      : sandbox.wallet,
  );
}

export function releaseSponsorPrize(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (raffle.status !== "CASH_WON" && raffle.status !== "REFUNDING") {
    fail("Sponsor NFT recovery is not available.");
  }
  if (raffle.prizeClaimed) fail("The NFT has already been claimed.");
  return replace(
    sandbox,
    { ...raffle, prizeClaimed: true },
    {
      id: eventId(raffle.id, "PRIZE_CLAIM", now),
      raffleId: raffle.id,
      kind: "SPONSOR_PRIZE_RELEASED",
      account: raffle.sponsorRecipient,
      amount: null,
      at: now,
    },
    raffle.sponsorRecipient.toLowerCase() === sandbox.player.toLowerCase()
      ? { ...sandbox.wallet, nfts: [...sandbox.wallet.nfts, raffle.id] }
      : sandbox.wallet,
  );
}

export function releaseSponsorProceeds(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  const amount = raffle.sponsorProceeds;
  if (amount <= 0n) fail("There are no sponsor proceeds to release.");
  return replace(
    sandbox,
    { ...raffle, sponsorProceeds: 0n },
    {
      id: eventId(raffle.id, "SPONSOR_PROCEEDS_RELEASED", now),
      raffleId: raffle.id,
      kind: "SPONSOR_PROCEEDS_RELEASED",
      account: raffle.sponsorRecipient,
      amount,
      at: now,
    },
    raffle.sponsorRecipient.toLowerCase() === sandbox.player.toLowerCase()
      ? { ...sandbox.wallet, usdc: sandbox.wallet.usdc + amount }
      : sandbox.wallet,
  );
}

export function releaseProtocolFees(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  const amount = raffle.protocolFees;
  if (amount <= 0n) fail("There are no protocol fees to release.");
  return replace(
    sandbox,
    { ...raffle, protocolFees: 0n },
    {
      id: eventId(raffle.id, "PROTOCOL_FEES_RELEASED", now),
      raffleId: raffle.id,
      kind: "PROTOCOL_FEES_RELEASED",
      account: raffle.protocolTreasury,
      amount,
      at: now,
    },
    raffle.protocolTreasury.toLowerCase() === sandbox.player.toLowerCase()
      ? { ...sandbox.wallet, usdc: sandbox.wallet.usdc + amount }
      : sandbox.wallet,
  );
}

function requireRaffle(sandbox: Sandbox, raffleId: string): SandboxRaffle {
  const raffle = sandbox.raffles.find((entry) => entry.id === raffleId);
  if (raffle === undefined) fail("Unknown raffle.");
  return raffle;
}

export function simulateOtherPurchase(
  sandbox: Sandbox,
  buyers: readonly string[],
  now: number,
): Sandbox {
  const open = sandbox.raffles.filter(
    (raffle) =>
      isOpen(raffle, now) &&
      raffle.sponsor.toLowerCase() !== sandbox.player.toLowerCase(),
  );
  if (open.length === 0) return sandbox;
  const { value, seed } = nextRandom(sandbox.seed);
  const raffle = open[value % open.length]!;
  const buyer = buyers[Math.floor(value / open.length) % buyers.length]!;
  const entryCount = BigInt(1 + (Math.floor(value / 97) % 20));
  return {
    ...buyEntries({ ...sandbox, seed }, raffle.id, entryCount, now, buyer),
    seed,
  };
}
