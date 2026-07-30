"use client";

import { Flame, ShieldAlert, Trophy } from "lucide-react";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";

import { CountUp } from "@/components/count-up";
import { PrizeArt } from "@/components/prize-art";
import { StatusPill, type StatusTone } from "@/components/status-pill";
import { ThresholdBar } from "@/components/threshold-bar";
import { useCountdown } from "@/hooks/use-countdown";
import { useNow } from "@/hooks/use-now";
import { useTokenMetadata } from "@/hooks/use-token-metadata";
import { cashToWinner, ticketsToThreshold } from "@/lib/economics";
import { formatTokenAmount, shortAddress } from "@/lib/format";
import type { IndexedRaffle } from "@/lib/subgraph";

const stateTones: Record<string, StatusTone> = {
  ACTIVE: "active",
  DRAW_REQUESTED: "warning",
  RESOLVED: "resolved",
  CANCELLED: "neutral",
};

const ctaLabels: Record<string, string> = {
  ACTIVE: "Buy tickets",
  DRAW_REQUESTED: "Watch the draw",
  RESOLVED: "See the result",
  CANCELLED: "View raffle",
};

/** Under an hour left reads as urgent. */
const URGENT_SECONDS = 3_600;

export function RaffleCard({ raffle }: { readonly raffle: IndexedRaffle }) {
  const total = BigInt(raffle.totalTickets);
  const minimum = BigInt(raffle.minimumTickets);
  const thresholdMet = total >= minimum;
  const remaining = ticketsToThreshold(total, minimum);
  const pot = cashToWinner(BigInt(raffle.netPot));
  const address = raffle.id as `0x${string}`;
  const tokenMetadata = useTokenMetadata(raffle.quoteToken as `0x${string}`);
  const countdown = useCountdown(BigInt(raffle.endTime));
  const isActive = raffle.state === "ACTIVE";
  const stateLabel = raffle.state.replaceAll("_", " ").toLowerCase();
  const flashing = useChangeFlash(raffle.totalTickets);
  const now = useNow();
  const urgent =
    isActive &&
    now !== undefined &&
    Number(raffle.endTime) - now < URGENT_SECONDS;

  return (
    <article
      className={`card card-link flex flex-col overflow-hidden ${flashing ? "flash" : ""}`}
    >
      <div className="relative">
        <PrizeArt
          className="aspect-[4/3] w-full"
          imageUrl={raffle.prizeImage}
          pixelated={raffle.prizePixelated}
          seed={`${raffle.prizeToken}-${raffle.prizeTokenId}`}
        />
        <div className="absolute left-3 top-3 flex flex-wrap gap-2">
          <StatusPill
            pulse={isActive}
            tone={stateTones[raffle.state] ?? "neutral"}
          >
            {stateLabel}
          </StatusPill>
          {urgent ? (
            <span className="chip bg-[var(--pink)] text-white">
              <Flame aria-hidden size={13} /> Ending soon
            </span>
          ) : null}
        </div>
        {!raffle.quoteTokenVerified ? (
          <span className="chip absolute right-3 top-3 bg-[var(--amber-wash)] text-[var(--amber-ink)]">
            <ShieldAlert aria-hidden size={13} /> Unverified token
          </span>
        ) : null}
      </div>

      <div className="flex flex-1 flex-col p-5">
        <div className="flex items-start justify-between gap-4">
          <div className="min-w-0">
            <p className="eyebrow truncate">
              {raffle.prizeCollection ??
                shortAddress(raffle.prizeToken as `0x${string}`)}
            </p>
            <h3 className="mt-1 truncate text-xl font-extrabold">
              {raffle.prizeName ?? `Token #${raffle.prizeTokenId}`}
            </h3>
          </div>
          <div className="shrink-0 text-right">
            <p className="eyebrow">Ticket</p>
            <p className="numeric mt-1 text-xl font-extrabold text-[var(--pink)]">
              {formatTokenAmount(
                BigInt(raffle.ticketPrice),
                tokenMetadata.decimals,
                tokenMetadata.symbol,
              )}
            </p>
          </div>
        </div>

        <div className="mt-5">
          <ThresholdBar minimum={minimum} total={total} />
          <div className="mt-2.5 flex items-center justify-between gap-3 text-xs font-bold">
            <span className="text-[var(--ink-soft)]">
              <CountUp value={Number(raffle.totalTickets)} /> /{" "}
              {minimum.toString()} tickets
            </span>
            <span
              className="numeric"
              style={{
                color: urgent ? "var(--pink)" : "var(--ink-soft)",
              }}
            >
              {isActive
                ? countdown === ""
                  ? "—"
                  : `${countdown} left`
                : raffle.outcome === "NONE"
                  ? stateLabel
                  : raffle.outcome.replaceAll("_", " ").toLowerCase()}
            </span>
          </div>
        </div>

        {/* What the winner takes home right now, and the flip point. */}
        <div className="mt-4 grid grid-cols-2 gap-px overflow-hidden rounded-2xl bg-[var(--line)]">
          <div className="bg-[var(--paper-sunk)] p-3">
            <p className="text-[0.68rem] font-extrabold uppercase tracking-wider text-[var(--ink-faint)]">
              Cash pot
            </p>
            <p className="numeric mt-1 truncate text-sm font-extrabold">
              {formatTokenAmount(
                pot,
                tokenMetadata.decimals,
                tokenMetadata.symbol,
              )}
            </p>
          </div>
          <div
            className="p-3"
            style={{
              background: thresholdMet
                ? "var(--grass-wash)"
                : "var(--paper-sunk)",
            }}
          >
            <p className="text-[0.68rem] font-extrabold uppercase tracking-wider text-[var(--ink-faint)]">
              NFT branch
            </p>
            <p
              className="numeric mt-1 flex items-center gap-1 truncate text-sm font-extrabold"
              style={{ color: thresholdMet ? "#0d6b45" : undefined }}
            >
              {thresholdMet ? (
                <>
                  <Trophy aria-hidden size={13} /> Unlocked
                </>
              ) : (
                `${remaining.toString()} to go`
              )}
            </p>
          </div>
        </div>

        {isActive ? (
          <p className="mt-3 text-center text-xs font-bold text-[var(--ink-faint)]">
            One ticket ≈{" "}
            <span className="numeric text-[var(--ink)]">
              1 in {(total + 1n).toString()}
            </span>{" "}
            odds
          </p>
        ) : null}

        <Link
          className={`btn mt-4 w-full ${isActive ? "btn-primary" : "btn-outline"}`}
          href={`/raffle/${address}`}
        >
          {ctaLabels[raffle.state] ?? "View raffle"}
        </Link>
      </div>
    </article>
  );
}

/** True for a moment after `value` changes, to highlight a live update. */
function useChangeFlash(value: string): boolean {
  const [flashing, setFlashing] = useState(false);
  const previous = useRef(value);

  useEffect(() => {
    if (previous.current === value) return;
    previous.current = value;
    setFlashing(true);
    const timer = setTimeout(() => setFlashing(false), 900);
    return () => clearTimeout(timer);
  }, [value]);

  return flashing;
}

export function RaffleCardSkeleton() {
  return (
    <div className="card overflow-hidden" aria-hidden>
      <div className="skeleton aspect-[4/3] w-full" />
      <div className="p-5">
        <div className="skeleton h-4 w-24 rounded-full" />
        <div className="skeleton mt-3 h-6 w-40 rounded-full" />
        <div className="skeleton mt-6 h-2.5 w-full rounded-full" />
        <div className="skeleton mt-6 h-11 w-full rounded-full" />
      </div>
    </div>
  );
}
