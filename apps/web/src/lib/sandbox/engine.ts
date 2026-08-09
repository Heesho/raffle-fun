/** Offline model of the production bearer-ticket settlement. */

export const PROTOCOL_FEE_PERCENT = 5n;
export const CASH_WINNER_PERCENT = 80n;
export const MAX_TICKETS_PER_PURCHASE = 100;
export const MAX_REFUND_BATCH_SIZE = 100;
export const DRAW_REQUEST_GRACE_MS = 3 * 24 * 60 * 60 * 1_000;
export const CALLBACK_TIMEOUT_MS = 2 * 24 * 60 * 60 * 1_000;
export const ENTROPY_FEE = 1_500_000_000_000_000n;

export type SandboxStatus =
  "ACTIVE" | "DRAWING" | "NFT_WON" | "CASH_WON" | "REFUNDING" | "CLOSED";

export interface SandboxTicket {
  readonly id: number;
  readonly owner: string;
  readonly burned?: boolean;
}

export interface SandboxRaffle {
  readonly id: string;
  readonly factoryId: string;
  readonly sponsor: string;
  readonly sponsorPrizeRecoveryRecipient: string;
  readonly prizeToken: string;
  readonly prizeTokenId: string;
  readonly prizeCollection: string;
  readonly prizeName: string;
  readonly prizeImage: string;
  readonly prizePixelated?: boolean;
  readonly ticketPrice: bigint;
  readonly minimumTickets: number;
  readonly startTime: number;
  readonly endTime: number;
  readonly requestGraceDeadline: number;
  readonly status: SandboxStatus;
  readonly tickets: readonly SandboxTicket[];
  readonly grossSales: bigint;
  readonly unsettledPot: bigint;
  readonly remainingRefundLiability: bigint;
  readonly winnerCashLiability: bigint;
  readonly winningTicketId: number | null;
  readonly prizeClaimed: boolean;
  readonly claimableQuote: Readonly<Record<string, bigint>>;
  readonly drawRequestedAt: number | null;
  readonly drawRequestedBy: string | null;
  readonly callbackDeadline: number | null;
}

export interface SandboxWallet {
  readonly weth: bigint;
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
    | "QUOTE_CLAIM"
    | "PRIZE_CLAIM"
    | "CLOSED"
    | "REFUNDS_ENABLED"
    | "REFUND_REDEEMED"
    | "WINNING_REDEEMED";
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

export function thresholdMet(raffle: SandboxRaffle): boolean {
  return raffle.tickets.length >= raffle.minimumTickets;
}

export function ticketsOwnedBy(raffle: SandboxRaffle, account: string): number {
  const normalized = account.toLowerCase();
  return raffle.tickets.filter(
    (ticket) => !ticket.burned && ticket.owner.toLowerCase() === normalized,
  ).length;
}

export function isOpen(raffle: SandboxRaffle, now: number): boolean {
  return (
    raffle.status === "ACTIVE" &&
    now >= raffle.startTime &&
    now < raffle.endTime
  );
}

export function canRequestDraw(raffle: SandboxRaffle, now: number): boolean {
  return (
    raffle.status === "ACTIVE" &&
    raffle.tickets.length > 0 &&
    now >= raffle.endTime &&
    now < raffle.requestGraceDeadline
  );
}

export function canEnableRefunds(raffle: SandboxRaffle, now: number): boolean {
  if (raffle.tickets.length === 0) return false;
  if (raffle.status === "ACTIVE") return now >= raffle.requestGraceDeadline;
  return (
    raffle.status === "DRAWING" &&
    raffle.callbackDeadline !== null &&
    now >= raffle.callbackDeadline
  );
}

export function canCloseEmptyRaffle(
  raffle: SandboxRaffle,
  account: string,
  now: number,
): boolean {
  return (
    raffle.status === "ACTIVE" &&
    raffle.tickets.length === 0 &&
    (now >= raffle.endTime ||
      account.toLowerCase() === raffle.sponsor.toLowerCase())
  );
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

export function buyTickets(
  sandbox: Sandbox,
  raffleId: string,
  quantity: number,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (!Number.isInteger(quantity) || quantity < 1)
    fail("Choose at least one ticket.");
  if (quantity > MAX_TICKETS_PER_PURCHASE)
    fail("A purchase is capped at 100 tickets.");
  if (!isOpen(raffle, now)) fail("Ticket sales are not open.");
  const gross = raffle.ticketPrice * BigInt(quantity);
  if (sandbox.wallet.weth < gross)
    fail("Not enough WETH for that many tickets.");
  const firstId = raffle.tickets.length + 1;
  const minted = Array.from({ length: quantity }, (_, index) => ({
    id: firstId + index,
    owner: sandbox.player,
  }));
  return replace(
    sandbox,
    {
      ...raffle,
      tickets: [...raffle.tickets, ...minted],
      grossSales: raffle.grossSales + gross,
      unsettledPot: raffle.unsettledPot + gross,
    },
    {
      id: eventId(raffle.id, "PURCHASE", now),
      raffleId: raffle.id,
      kind: "PURCHASE",
      account: sandbox.player,
      amount: gross,
      at: now,
      detail: `${quantity} ticket${quantity === 1 ? "" : "s"}`,
    },
    { ...sandbox.wallet, weth: sandbox.wallet.weth - gross },
  );
}

export function requestDraw(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (!canRequestDraw(raffle, now)) fail("The draw is not available.");
  if (sandbox.wallet.eth < ENTROPY_FEE)
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
      amount: ENTROPY_FEE,
      at: now,
    },
    { ...sandbox.wallet, eth: sandbox.wallet.eth - ENTROPY_FEE },
  );
}

/** The callback selects a ticket and records liabilities; it transfers nothing. */
export function resolveDraw(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (raffle.status !== "DRAWING") fail("This raffle has no pending draw.");
  const { value, seed } = nextRandom(sandbox.seed);
  const winningTicketId = (value % raffle.tickets.length) + 1;
  const protocolFee = (raffle.unsettledPot * PROTOCOL_FEE_PERCENT) / 100n;
  const distributable = raffle.unsettledPot - protocolFee;
  const met = thresholdMet(raffle);
  const winnerCash = met ? 0n : (distributable * CASH_WINNER_PERCENT) / 100n;
  const sponsorCash = distributable - winnerCash;
  const claimable = { ...raffle.claimableQuote };
  claimable[raffle.sponsor] = (claimable[raffle.sponsor] ?? 0n) + sponsorCash;
  return replace(
    sandbox,
    {
      ...raffle,
      status: met ? "NFT_WON" : "CASH_WON",
      winningTicketId,
      unsettledPot: 0n,
      winnerCashLiability: winnerCash,
      claimableQuote: claimable,
    },
    {
      id: eventId(raffle.id, "RESOLVED", now),
      raffleId: raffle.id,
      kind: "RESOLVED",
      account: raffle.tickets[winningTicketId - 1]!.owner,
      amount: winnerCash === 0n ? null : winnerCash,
      at: now,
      detail: `ticket #${winningTicketId} won`,
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
  if (!canEnableRefunds(raffle, now))
    fail("The oracle deadline has not expired.");
  return replace(
    sandbox,
    {
      ...raffle,
      status: "REFUNDING",
      unsettledPot: 0n,
      remainingRefundLiability: raffle.grossSales,
    },
    {
      id: eventId(raffle.id, "REFUNDS_ENABLED", now),
      raffleId: raffle.id,
      kind: "REFUNDS_ENABLED",
      account: sandbox.player,
      amount: raffle.grossSales,
      at: now,
    },
  );
}

export function redeemRefundTickets(
  sandbox: Sandbox,
  raffleId: string,
  ticketIds: readonly number[],
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (raffle.status !== "REFUNDING") fail("This raffle is not refunding.");
  if (ticketIds.length < 1 || ticketIds.length > MAX_REFUND_BATCH_SIZE) {
    fail("Redeem between one and 100 ticket refunds.");
  }
  if (new Set(ticketIds).size !== ticketIds.length)
    fail("A ticket appears twice.");
  const selected = new Set(ticketIds);
  for (const ticketId of selected) {
    const ticket = raffle.tickets[ticketId - 1];
    if (ticket === undefined || ticket.burned)
      fail("Unknown or already burned ticket.");
    if (ticket.owner.toLowerCase() !== sandbox.player.toLowerCase()) {
      fail("Only the current ticket owner can redeem its refund.");
    }
  }
  const amount = raffle.ticketPrice * BigInt(ticketIds.length);
  const tickets = raffle.tickets.map((ticket) =>
    selected.has(ticket.id) ? { ...ticket, burned: true } : ticket,
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
    },
    { ...sandbox.wallet, weth: sandbox.wallet.weth + amount },
  );
}

export function closeEmptyRaffle(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (!canCloseEmptyRaffle(raffle, sandbox.player, now)) {
    fail("This account cannot close the empty raffle yet.");
  }
  return replace(
    sandbox,
    { ...raffle, status: "CLOSED" },
    {
      id: eventId(raffle.id, "CLOSED", now),
      raffleId: raffle.id,
      kind: "CLOSED",
      account: sandbox.player,
      amount: null,
      at: now,
    },
  );
}

export function redeemWinningTicket(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (raffle.status !== "NFT_WON" && raffle.status !== "CASH_WON") {
    fail("The winning prize is not available.");
  }
  if (raffle.winningTicketId === null) fail("No winning ticket was selected.");
  const ticket = raffle.tickets[raffle.winningTicketId - 1];
  if (ticket === undefined || ticket.burned)
    fail("The winning ticket was already redeemed.");
  if (ticket.owner.toLowerCase() !== sandbox.player.toLowerCase()) {
    fail("Only the current winning-ticket owner can redeem.");
  }
  const cashAmount = raffle.winnerCashLiability;
  const tickets = raffle.tickets.map((entry) =>
    entry.id === ticket.id ? { ...entry, burned: true } : entry,
  );
  const nftWon = raffle.status === "NFT_WON";
  return replace(
    sandbox,
    {
      ...raffle,
      tickets,
      winnerCashLiability: 0n,
      prizeClaimed: nftWon ? true : raffle.prizeClaimed,
    },
    {
      id: eventId(raffle.id, "WINNING_REDEEMED", now),
      raffleId: raffle.id,
      kind: "WINNING_REDEEMED",
      account: sandbox.player,
      amount: cashAmount === 0n ? null : cashAmount,
      at: now,
    },
    {
      ...sandbox.wallet,
      weth: sandbox.wallet.weth + cashAmount,
      nfts: nftWon ? [...sandbox.wallet.nfts, raffle.id] : sandbox.wallet.nfts,
    },
  );
}

export function claimSponsorPrize(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (
    raffle.sponsorPrizeRecoveryRecipient.toLowerCase() !==
    sandbox.player.toLowerCase()
  ) {
    fail("Only the fixed recovery recipient can claim the NFT.");
  }
  if (
    raffle.status !== "CASH_WON" &&
    raffle.status !== "REFUNDING" &&
    raffle.status !== "CLOSED"
  )
    fail("Sponsor NFT recovery is not available.");
  if (raffle.prizeClaimed) fail("The NFT has already been claimed.");
  return replace(
    sandbox,
    { ...raffle, prizeClaimed: true },
    {
      id: eventId(raffle.id, "PRIZE_CLAIM", now),
      raffleId: raffle.id,
      kind: "PRIZE_CLAIM",
      account: sandbox.player,
      amount: null,
      at: now,
    },
    { ...sandbox.wallet, nfts: [...sandbox.wallet.nfts, raffle.id] },
  );
}

export function claimQuote(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  const amount = raffle.claimableQuote[sandbox.player] ?? 0n;
  if (amount <= 0n) fail("There is nothing to claim here.");
  const claimableQuote = { ...raffle.claimableQuote };
  delete claimableQuote[sandbox.player];
  return replace(
    sandbox,
    { ...raffle, claimableQuote },
    {
      id: eventId(raffle.id, "QUOTE_CLAIM", now),
      raffleId: raffle.id,
      kind: "QUOTE_CLAIM",
      account: sandbox.player,
      amount,
      at: now,
    },
    { ...sandbox.wallet, weth: sandbox.wallet.weth + amount },
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
  const quantity = 1 + (Math.floor(value / 97) % 3);
  const gross = raffle.ticketPrice * BigInt(quantity);
  const firstId = raffle.tickets.length + 1;
  const tickets = [
    ...raffle.tickets,
    ...Array.from({ length: quantity }, (_, index) => ({
      id: firstId + index,
      owner: buyer,
    })),
  ];
  return replace(
    sandbox,
    {
      ...raffle,
      tickets,
      grossSales: raffle.grossSales + gross,
      unsettledPot: raffle.unsettledPot + gross,
    },
    {
      id: eventId(raffle.id, "PURCHASE", now),
      raffleId: raffle.id,
      kind: "PURCHASE",
      account: buyer,
      amount: gross,
      at: now,
    },
    sandbox.wallet,
    seed,
  );
}
