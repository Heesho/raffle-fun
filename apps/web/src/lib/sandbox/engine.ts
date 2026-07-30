/**
 * A playable, offline model of the raffle protocol.
 *
 * Every rule here mirrors `packages/contracts/src/Raffle.sol` so the sandbox
 * teaches the real mechanic rather than a convenient approximation:
 *
 *  - the advertised ticket price is the total paid; fees come out of it
 *  - tickets are sequential ids starting at 1, owned by their recipient
 *  - sales are uncapped and only bounded by `endTime`
 *  - the sponsor may cancel only while zero tickets have sold
 *  - settlement is two steps: request the draw, then the oracle callback
 *  - the callback moves no assets; it credits pull claims
 *
 * All amounts are bigint wei. No wallet, chain, or network is involved.
 */

export const PROTOCOL_FEE_PERCENT = 5n;
export const PROVIDER_FEE_PERCENT = 5n;
export const CASH_WINNER_PERCENT = 80n;
export const MAX_TICKETS_PER_PURCHASE = 100;

/** A stand-in for the Pyth Entropy fee, payable in native ETH. */
export const ENTROPY_FEE = 1_500_000_000_000_000n; // 0.0015 ETH

export type SandboxState =
  "ACTIVE" | "DRAW_REQUESTED" | "RESOLVED" | "CANCELLED";

export type SandboxOutcome =
  | "NONE"
  | "NFT_AWARDED"
  | "CASH_FALLBACK"
  | "NO_SALES"
  | "CANCELLED_BEFORE_SALE";

export interface SandboxTicket {
  readonly id: number;
  readonly owner: string;
}

export interface SandboxRaffle {
  readonly id: string;
  readonly factoryId: string;
  readonly sponsor: string;
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

  readonly state: SandboxState;
  readonly outcome: SandboxOutcome;
  readonly tickets: readonly SandboxTicket[];
  readonly grossSales: bigint;
  readonly netPot: bigint;

  readonly winningTicketId: number | null;
  readonly winner: string | null;
  /** Who may pull the ERC-721. Null until the raffle settles. */
  readonly prizeClaimant: string | null;
  readonly prizeClaimed: boolean;
  /** Pull-based quote-token claims, keyed by account. */
  readonly claimableQuote: Readonly<Record<string, bigint>>;
  /** Set when the draw is requested; the callback lands a moment later. */
  readonly drawRequestedAt: number | null;
  readonly drawRequestedBy: string | null;
}

export interface SandboxWallet {
  /** Fake WETH, the quote token for every sandbox raffle. */
  readonly weth: bigint;
  /** Fake native ETH, used only for the entropy fee. */
  readonly eth: bigint;
  /** Prize NFTs the player has successfully pulled. */
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
    | "CANCELLED"
    | "NO_SALES";
  readonly account: string;
  readonly amount: bigint | null;
  readonly at: number;
  readonly detail?: string;
}

export class SandboxError extends Error {}

function fail(message: string): never {
  throw new SandboxError(message);
}

/**
 * Deterministic PRNG so a given seed always replays the same draw.
 *
 * The reported value is the state's high bits: a linear congruential
 * generator's low bits have a very short period, so `value % smallNumber`
 * taken from the raw state cycles visibly (1, 2, 1, 2, …).
 */
export function nextRandom(seed: number): { value: number; seed: number } {
  const next = (Math.imul(seed, 1_664_525) + 1_013_904_223) >>> 0;
  return { value: next >>> 8, seed: next };
}

export function thresholdMet(raffle: SandboxRaffle): boolean {
  return raffle.tickets.length >= raffle.minimumTickets;
}

export function ticketsOwnedBy(raffle: SandboxRaffle, account: string): number {
  return raffle.tickets.filter(
    (ticket) => ticket.owner.toLowerCase() === account.toLowerCase(),
  ).length;
}

export function isOpen(raffle: SandboxRaffle, now: number): boolean {
  return (
    raffle.state === "ACTIVE" && now >= raffle.startTime && now < raffle.endTime
  );
}

export function canRequestDraw(raffle: SandboxRaffle, now: number): boolean {
  return (
    raffle.state === "ACTIVE" &&
    now >= raffle.endTime &&
    raffle.tickets.length > 0
  );
}

export function canCloseNoSales(raffle: SandboxRaffle, now: number): boolean {
  return (
    raffle.state === "ACTIVE" &&
    now >= raffle.endTime &&
    raffle.tickets.length === 0
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

/* ------------------------------------------------------------ purchasing */

export function buyTickets(
  sandbox: Sandbox,
  raffleId: string,
  quantity: number,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (!Number.isInteger(quantity) || quantity < 1) {
    fail("Choose at least one ticket.");
  }
  if (quantity > MAX_TICKETS_PER_PURCHASE) {
    fail(`A single purchase is capped at ${MAX_TICKETS_PER_PURCHASE} tickets.`);
  }
  if (raffle.state !== "ACTIVE") fail("This raffle is no longer selling.");
  if (now < raffle.startTime) fail("The sale has not started yet.");
  if (now >= raffle.endTime) fail("The sale has ended.");

  const gross = raffle.ticketPrice * BigInt(quantity);
  if (sandbox.wallet.weth < gross) {
    fail("Not enough WETH for that many tickets.");
  }

  // Fees are carved out of the advertised price, never added on top.
  const protocolFee = (gross * PROTOCOL_FEE_PERCENT) / 100n;
  const netContribution = gross - protocolFee;

  const firstId = raffle.tickets.length + 1;
  const minted: SandboxTicket[] = Array.from(
    { length: quantity },
    (_, index) => ({ id: firstId + index, owner: sandbox.player }),
  );

  const updated: SandboxRaffle = {
    ...raffle,
    tickets: [...raffle.tickets, ...minted],
    grossSales: raffle.grossSales + gross,
    netPot: raffle.netPot + netContribution,
  };

  return replace(
    sandbox,
    updated,
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

/* ------------------------------------------------------------ settlement */

export function requestDraw(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (raffle.state !== "ACTIVE") fail("The draw is not available.");
  if (now < raffle.endTime) fail("The sale has not ended yet.");
  if (raffle.tickets.length === 0) {
    fail("No tickets were sold, so there is nothing to draw.");
  }
  if (sandbox.wallet.eth < ENTROPY_FEE) {
    fail("Not enough ETH to cover the randomness fee.");
  }

  const updated: SandboxRaffle = {
    ...raffle,
    state: "DRAW_REQUESTED",
    drawRequestedAt: now,
    drawRequestedBy: sandbox.player,
  };

  return replace(
    sandbox,
    updated,
    {
      id: eventId(raffle.id, "DRAW_REQUESTED", now),
      raffleId: raffle.id,
      kind: "DRAW_REQUESTED",
      account: sandbox.player,
      amount: ENTROPY_FEE,
      at: now,
      detail: "randomness requested",
    },
    { ...sandbox.wallet, eth: sandbox.wallet.eth - ENTROPY_FEE },
  );
}

/**
 * The oracle callback.
 *
 * Selects the winning ticket, snapshots its current owner, picks the economic
 * branch, and credits pull claims. Like the contract, it transfers nothing.
 */
export function resolveDraw(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (raffle.state !== "DRAW_REQUESTED") {
    fail("This raffle has no pending draw.");
  }

  const { value, seed } = nextRandom(sandbox.seed);
  const winningTicketId = (value % raffle.tickets.length) + 1;
  const winner = raffle.tickets[winningTicketId - 1]!.owner;

  const pot = raffle.netPot;
  const met = thresholdMet(raffle);
  const claimable: Record<string, bigint> = { ...raffle.claimableQuote };
  const credit = (account: string, amount: bigint) => {
    if (amount <= 0n) return;
    claimable[account] = (claimable[account] ?? 0n) + amount;
  };

  let winnerCash = 0n;
  if (met) {
    // The winning ticket takes the NFT; the sponsor takes the whole pot.
    credit(raffle.sponsor, pot);
  } else {
    winnerCash = (pot * CASH_WINNER_PERCENT) / 100n;
    credit(winner, winnerCash);
    credit(raffle.sponsor, pot - winnerCash);
  }

  const updated: SandboxRaffle = {
    ...raffle,
    state: "RESOLVED",
    outcome: met ? "NFT_AWARDED" : "CASH_FALLBACK",
    winningTicketId,
    winner,
    prizeClaimant: met ? winner : raffle.sponsor,
    netPot: 0n,
    claimableQuote: claimable,
  };

  return replace(
    sandbox,
    updated,
    {
      id: eventId(raffle.id, "RESOLVED", now),
      raffleId: raffle.id,
      kind: "RESOLVED",
      account: winner,
      amount: met ? null : winnerCash,
      at: now,
      detail: `ticket #${winningTicketId} won`,
    },
    sandbox.wallet,
    seed,
  );
}

export function closeNoSales(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (!canCloseNoSales(raffle, now)) {
    fail("This raffle is not eligible for no-sales closure.");
  }
  const updated: SandboxRaffle = {
    ...raffle,
    state: "RESOLVED",
    outcome: "NO_SALES",
    prizeClaimant: raffle.sponsor,
  };
  return replace(sandbox, updated, {
    id: eventId(raffle.id, "NO_SALES", now),
    raffleId: raffle.id,
    kind: "NO_SALES",
    account: raffle.sponsor,
    amount: null,
    at: now,
    detail: "closed with no sales",
  });
}

export function cancelBeforeSales(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (raffle.state !== "ACTIVE") fail("This raffle cannot be cancelled.");
  if (raffle.sponsor.toLowerCase() !== sandbox.player.toLowerCase()) {
    fail("Only the sponsor can cancel a raffle.");
  }
  if (raffle.tickets.length !== 0) {
    fail("Tickets have already sold, so the prize is locked until settlement.");
  }
  const updated: SandboxRaffle = {
    ...raffle,
    state: "CANCELLED",
    outcome: "CANCELLED_BEFORE_SALE",
    prizeClaimant: raffle.sponsor,
  };
  return replace(sandbox, updated, {
    id: eventId(raffle.id, "CANCELLED", now),
    raffleId: raffle.id,
    kind: "CANCELLED",
    account: raffle.sponsor,
    amount: null,
    at: now,
    detail: "cancelled before any sale",
  });
}

/* ---------------------------------------------------------------- claims */

export function claimPrize(
  sandbox: Sandbox,
  raffleId: string,
  now: number,
): Sandbox {
  const raffle = requireRaffle(sandbox, raffleId);
  if (raffle.state !== "RESOLVED" && raffle.state !== "CANCELLED") {
    fail("This raffle has not settled yet.");
  }
  if (
    raffle.prizeClaimant === null ||
    raffle.prizeClaimant.toLowerCase() !== sandbox.player.toLowerCase()
  ) {
    fail("The prize belongs to someone else.");
  }
  if (raffle.prizeClaimed) fail("The prize has already been claimed.");

  const updated: SandboxRaffle = { ...raffle, prizeClaimed: true };
  return replace(
    sandbox,
    updated,
    {
      id: eventId(raffle.id, "PRIZE_CLAIM", now),
      raffleId: raffle.id,
      kind: "PRIZE_CLAIM",
      account: sandbox.player,
      amount: null,
      at: now,
      detail: raffle.prizeName,
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

  const remaining = { ...raffle.claimableQuote };
  delete remaining[sandbox.player];

  const updated: SandboxRaffle = { ...raffle, claimableQuote: remaining };
  return replace(
    sandbox,
    updated,
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

/* --------------------------------------------------------- ambient buyers */

/**
 * Another participant buys in.
 *
 * Keeps open raffles moving while the player watches, without touching the
 * player's wallet. Returns the sandbox unchanged when nothing is open.
 */
export function simulateOtherPurchase(
  sandbox: Sandbox,
  buyers: readonly string[],
  now: number,
): Sandbox {
  // The player's own raffle is left alone so the sponsor-cancel path, which
  // requires zero sales, stays demonstrable for the whole session.
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
  const protocolFee = (gross * PROTOCOL_FEE_PERCENT) / 100n;
  const firstId = raffle.tickets.length + 1;

  const updated: SandboxRaffle = {
    ...raffle,
    tickets: [
      ...raffle.tickets,
      ...Array.from({ length: quantity }, (_, index) => ({
        id: firstId + index,
        owner: buyer,
      })),
    ],
    grossSales: raffle.grossSales + gross,
    netPot: raffle.netPot + (gross - protocolFee),
  };

  return replace(
    sandbox,
    updated,
    {
      id: eventId(raffle.id, "PURCHASE", now),
      raffleId: raffle.id,
      kind: "PURCHASE",
      account: buyer,
      amount: gross,
      at: now,
      detail: `${quantity} ticket${quantity === 1 ? "" : "s"}`,
    },
    sandbox.wallet,
    seed,
  );
}
