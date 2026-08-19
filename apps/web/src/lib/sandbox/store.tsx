"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  useSyncExternalStore,
  type ReactNode,
} from "react";

import {
  buyEntries as applyBuy,
  redeemWinningTicket as applyRedeemWinningTicket,
  releaseSponsorPrize as applyReleaseSponsorPrize,
  releaseSponsorProceeds as applyReleaseSponsorProceeds,
  releaseProtocolFees as applyReleaseProtocolFees,
  enableRefunds as applyEnableRefunds,
  refundTickets as applyRefundTickets,
  settleWinningTicket as applySettleWinningTicket,
  requestDraw as applyRequestDraw,
  resolveDraw,
  SandboxError,
  simulateOtherPurchase,
  type Sandbox,
  type SandboxRaffle,
} from "./engine";
import { createSandbox } from "./seed";

const STORAGE_KEY = "raffle-fun.sandbox.tickets-v3";

/** How long the stand-in oracle takes to deliver randomness. */
export const ORACLE_DELAY_MS = 4_000;

/** How often another participant buys in, to keep open raffles moving. */
const AMBIENT_INTERVAL_MS = 9_000;

const AMBIENT_BUYERS = [
  "0x6f13c98a025bd47e1a06c83f92b5d740e26a1c93",
  "0x2a74e08c15b93d6f0a8c25e71b4d930f6a1c85e2",
  "0x8d02a71c46e95b38f0c1a7d24e69b350f8a2c17d",
  "0x0e97b25a13c86d40f7a2c95e18b3d704f6c2a89b",
  "0x5c81f07a29d64b13e0a7c85f92b1d640e37c9a52",
];

/* --------------------------------------------------------- serialisation */

function serialise(sandbox: Sandbox): string {
  return JSON.stringify(sandbox, (_key, value) =>
    typeof value === "bigint" ? `${value.toString()}n` : value,
  );
}

function deserialise(raw: string): Sandbox {
  return JSON.parse(raw, (_key, value) =>
    typeof value === "string" && /^\d+n$/.test(value)
      ? BigInt(value.slice(0, -1))
      : value,
  ) as Sandbox;
}

/* ------------------------------------------------------- external store */

/**
 * The sandbox lives outside React.
 *
 * It is seeded from `localStorage` and the current time, neither of which
 * exists during server rendering, so it is exposed through
 * `useSyncExternalStore` with an undefined server snapshot. That keeps the
 * first client render identical to the server HTML instead of hydrating
 * through a setState-in-effect.
 */
let current: Sandbox | undefined;
const listeners = new Set<() => void>();

function emit() {
  listeners.forEach((listener) => listener());
}

function load(): Sandbox {
  const stored = localStorage.getItem(STORAGE_KEY);
  if (stored !== null) {
    try {
      return deserialise(stored);
    } catch {
      // A corrupt or outdated payload just starts a fresh sandbox.
    }
  }
  return createSandbox(Date.now());
}

function subscribe(listener: () => void): () => void {
  if (current === undefined) {
    current = load();
  }
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function getSnapshot(): Sandbox | undefined {
  return current;
}

function getServerSnapshot(): undefined {
  return undefined;
}

function commit(next: Sandbox): void {
  current = next;
  try {
    localStorage.setItem(STORAGE_KEY, serialise(next));
  } catch {
    // A full or unavailable store must not break the session.
  }
  emit();
}

/* ----------------------------------------------------------------- react */

interface SandboxContextValue {
  readonly sandbox: Sandbox | undefined;
  readonly error: string | undefined;
  readonly clearError: () => void;
  readonly buyEntries: (raffleId: string, entryCount: bigint) => void;
  readonly requestDraw: (raffleId: string) => void;
  readonly enableRefunds: (raffleId: string) => void;
  readonly refundTickets: (
    raffleId: string,
    ticketIds: readonly bigint[],
  ) => void;
  readonly settleWinningTicket: (raffleId: string, ticketId: bigint) => void;
  readonly redeemWinningTicket: (raffleId: string, ticketId: bigint) => void;
  readonly releaseSponsorPrize: (raffleId: string) => void;
  readonly releaseSponsorProceeds: (raffleId: string) => void;
  readonly releaseProtocolFees: (raffleId: string) => void;
  readonly skipToEnd: (raffleId: string) => void;
  readonly reset: () => void;
}

const SandboxContext = createContext<SandboxContextValue | undefined>(
  undefined,
);

export function SandboxProvider({
  children,
}: {
  readonly children: ReactNode;
}) {
  const sandbox = useSyncExternalStore(
    subscribe,
    getSnapshot,
    getServerSnapshot,
  );
  const [error, setError] = useState<string>();
  // Scheduled oracle callbacks, keyed by raffle, so a pending draw is never
  // scheduled twice and can be cancelled if it resolves another way.
  const pending = useRef(new Map<string, ReturnType<typeof setTimeout>>());

  const run = useCallback((mutate: (state: Sandbox) => Sandbox) => {
    if (current === undefined) return;
    try {
      const next = mutate(current);
      setError(undefined);
      if (next !== current) commit(next);
    } catch (thrown) {
      setError(
        thrown instanceof SandboxError
          ? thrown.message
          : "Something went wrong in the sandbox.",
      );
    }
  }, []);

  // The stand-in Chainlink callback: any raffle with a pending request resolves a
  // few seconds later, mirroring the real request/callback split.
  //
  // Timers deliberately survive re-renders. Cancelling them in this effect's
  // cleanup would let any unrelated state change — an ambient purchase, say —
  // kill a scheduled callback that the `pending` guard then refuses to
  // reschedule, stranding the raffle in DRAWING forever.
  useEffect(() => {
    if (sandbox === undefined) return;

    for (const raffle of sandbox.raffles) {
      if (raffle.status !== "DRAWING") {
        const existing = pending.current.get(raffle.id);
        if (existing !== undefined) {
          clearTimeout(existing);
          pending.current.delete(raffle.id);
        }
        continue;
      }
      if (pending.current.has(raffle.id)) continue;

      const elapsed = Date.now() - (raffle.drawRequestedAt ?? Date.now());
      const timer = setTimeout(
        () => {
          pending.current.delete(raffle.id);
          run((state) => {
            const target = state.raffles.find(
              (entry) => entry.id === raffle.id,
            );
            if (target?.status !== "DRAWING") return state;
            return resolveDraw(state, raffle.id, Date.now());
          });
        },
        Math.max(0, ORACLE_DELAY_MS - elapsed),
      );
      pending.current.set(raffle.id, timer);
    }
  }, [run, sandbox]);

  // Only a genuine unmount tears the scheduled callbacks down.
  useEffect(() => {
    const scheduled = pending.current;
    return () => {
      scheduled.forEach(clearTimeout);
      scheduled.clear();
    };
  }, []);

  // Other participants keep buying, so open raffles visibly move.
  useEffect(() => {
    const timer = setInterval(() => {
      run((state) => simulateOtherPurchase(state, AMBIENT_BUYERS, Date.now()));
    }, AMBIENT_INTERVAL_MS);
    return () => clearInterval(timer);
  }, [run]);

  const value = useMemo<SandboxContextValue>(
    () => ({
      sandbox,
      error,
      clearError: () => setError(undefined),
      buyEntries: (raffleId, entryCount) =>
        run((state) => applyBuy(state, raffleId, entryCount, Date.now())),
      requestDraw: (raffleId) =>
        run((state) => applyRequestDraw(state, raffleId, Date.now())),
      enableRefunds: (raffleId) =>
        run((state) => applyEnableRefunds(state, raffleId, Date.now())),
      refundTickets: (raffleId, ticketIds) =>
        run((state) =>
          applyRefundTickets(state, raffleId, ticketIds, Date.now()),
        ),
      settleWinningTicket: (raffleId, ticketId) =>
        run((state) =>
          applySettleWinningTicket(state, raffleId, ticketId, Date.now()),
        ),
      redeemWinningTicket: (raffleId, ticketId) =>
        run((state) =>
          applyRedeemWinningTicket(state, raffleId, ticketId, Date.now()),
        ),
      releaseSponsorPrize: (raffleId) =>
        run((state) => applyReleaseSponsorPrize(state, raffleId, Date.now())),
      releaseSponsorProceeds: (raffleId) =>
        run((state) =>
          applyReleaseSponsorProceeds(state, raffleId, Date.now()),
        ),
      releaseProtocolFees: (raffleId) =>
        run((state) => applyReleaseProtocolFees(state, raffleId, Date.now())),
      // Pulls a sale deadline into the past so settlement can be demonstrated
      // without waiting out the clock.
      skipToEnd: (raffleId) =>
        run((state) => ({
          ...state,
          raffles: state.raffles.map((raffle) =>
            raffle.id === raffleId && raffle.status === "ACTIVE"
              ? { ...raffle, endTime: Date.now() - 1_000 }
              : raffle,
          ),
        })),
      reset: () => {
        pending.current.clear();
        setError(undefined);
        commit(createSandbox(Date.now()));
      },
    }),
    [error, run, sandbox],
  );

  return (
    <SandboxContext.Provider value={value}>{children}</SandboxContext.Provider>
  );
}

export function useSandbox(): SandboxContextValue {
  const value = useContext(SandboxContext);
  if (value === undefined) {
    throw new Error("useSandbox must be used inside a SandboxProvider.");
  }
  return value;
}

export function useSandboxRaffle(raffleId: string): SandboxRaffle | undefined {
  const { sandbox } = useSandbox();
  return sandbox?.raffles.find(
    (raffle) => raffle.id.toLowerCase() === raffleId.toLowerCase(),
  );
}
