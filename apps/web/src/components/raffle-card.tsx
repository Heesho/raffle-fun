"use client";

import { ShieldAlert } from "lucide-react";
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
  const unsettledPot = BigInt(raffle.unsettledPot);
  const settlementGross =
    unsettledPot === 0n ? BigInt(raffle.grossSales) : unsettledPot;
  const pot = cashToWinner(settlementGross);
  const address = raffle.id as `0x${string}`;
  const tokenMetadata = useTokenMetadata(raffle.quoteToken as `0x${string}`);
  const countdown = useCountdown(BigInt(raffle.endTime));
  const isActive = raffle.state === "ACTIVE";
  const stateLabel = raffle.state.replaceAll("_", " ").toLowerCase();
  const flashing = useChangeFlash(raffle.totalTickets);
  const now = useNow();
  const secondsLeft =
    now === undefined ? undefined : Number(raffle.endTime) - now;
  const closed = secondsLeft !== undefined && secondsLeft <= 0;
  const urgent =
    isActive && !closed && (secondsLeft ?? Infinity) < URGENT_SECONDS;

  return (
    <article className="card card-link flex flex-col overflow-hidden">
      <div className="relative">
        <PrizeArt
          className="aspect-[4/3] w-full"
          imageUrl={raffle.prizeImage}
          pixelated={raffle.prizePixelated}
          seed={`${raffle.prizeToken}-${raffle.prizeTokenId}`}
        />
        {/* One status marker, not a stack of competing pills. Urgency is
            carried by the countdown below, where the buyer is already
            looking for it. */}
        <div className="absolute inset-x-3 top-3 flex items-start justify-between gap-2">
          <StatusPill
            pulse={isActive && !closed}
            tone={stateTones[raffle.state] ?? "neutral"}
          >
            {stateLabel}
          </StatusPill>
          {!raffle.quoteTokenVerified ? (
            <span className="chip bg-[var(--amber-wash)] text-[var(--amber-ink)] shadow-[var(--shadow-xs)]">
              <ShieldAlert aria-hidden size={12} /> Unverified
            </span>
          ) : null}
        </div>
      </div>

      <div className="flex flex-1 flex-col p-4">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="eyebrow truncate">
              {raffle.prizeCollection ??
                shortAddress(raffle.prizeToken as `0x${string}`)}
            </p>
            <h3 className="mt-1 truncate text-[length:var(--text-lg)]">
              {raffle.prizeName ?? `Token #${raffle.prizeTokenId}`}
            </h3>
          </div>
          <div className="shrink-0 text-right">
            <p className="eyebrow">Ticket</p>
            <p className="figure mt-1 text-[length:var(--text-lg)]">
              {formatTokenAmount(
                BigInt(raffle.ticketPrice),
                tokenMetadata.decimals,
                tokenMetadata.symbol,
              )}
            </p>
          </div>
        </div>

        <div className="mt-4">
          <div className="mb-1.5 flex items-baseline justify-between gap-3 text-[length:var(--text-xs)]">
            <span className="font-semibold text-[var(--ink-2)]">
              <CountUp
                className={flashing ? "text-[var(--pink-ink)]" : ""}
                value={Number(raffle.totalTickets)}
              />{" "}
              sold
            </span>
            <span className="text-[var(--ink-3)]">
              {thresholdMet
                ? "NFT unlocked"
                : `NFT at ${minimum.toString()} · ${remaining.toString()} to go`}
            </span>
          </div>
          <ThresholdBar minimum={minimum} total={total} />
        </div>

        {/* The two facts that decide whether to buy: what the pot pays right
            now, and how long there is to act. */}
        <div className="mt-4 flex items-end justify-between gap-3 border-t border-[var(--line)] pt-3">
          <div className="min-w-0">
            <p className="eyebrow">Cash pot</p>
            <p className="figure mt-0.5 truncate text-[length:var(--text-base)]">
              {formatTokenAmount(
                pot,
                tokenMetadata.decimals,
                tokenMetadata.symbol,
              )}
            </p>
          </div>
          <div className="min-w-0 text-right">
            <p className="eyebrow">
              {isActive ? (closed ? "Sale" : "Closes in") : "Outcome"}
            </p>
            <p
              className={`figure mt-0.5 truncate text-[length:var(--text-base)] ${
                urgent ? "text-[var(--pink-ink)]" : ""
              }`}
            >
              {isActive
                ? countdown === ""
                  ? "—"
                  : countdown
                : raffle.outcome === "NONE"
                  ? stateLabel
                  : raffle.outcome.replaceAll("_", " ").toLowerCase()}
            </p>
          </div>
        </div>

        {isActive && !closed ? (
          <p className="mt-3 text-[length:var(--text-xs)] text-[var(--ink-3)]">
            One ticket ≈{" "}
            <span className="numeric font-semibold text-[var(--ink-2)]">
              1 in {(total + 1n).toString()}
            </span>{" "}
            odds
          </p>
        ) : null}

        {/* Hot pink, as the board draws its "Buy Raffle" pill. `mt-auto` pins
            the button to the bottom so a row of cards lines up. */}
        <div className="mt-auto pt-4">
          <Link
            className={`btn w-full ${
              isActive && !closed ? "btn-primary" : "btn-outline"
            }`}
            href={`/raffle/${address}`}
          >
            {/* A raffle stays ACTIVE after its sale window shuts, until
                someone pays for randomness — so "Buy tickets" would be a lie
                for the gap in between. */}
            {isActive && closed
              ? "Awaiting the draw"
              : (ctaLabels[raffle.state] ?? "View raffle")}
          </Link>
        </div>
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
      <div className="p-4">
        <div className="skeleton h-3 w-24 rounded-full" />
        <div className="skeleton mt-2.5 h-5 w-40 rounded-full" />
        <div className="skeleton mt-5 h-2 w-full rounded-full" />
        <div className="skeleton mt-6 h-11 w-full rounded-full" />
      </div>
    </div>
  );
}
