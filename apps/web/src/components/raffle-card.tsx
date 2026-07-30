"use client";

import { ArrowUpRight, Clock3, Gem, ShieldAlert, Ticket } from "lucide-react";
import Link from "next/link";

import { StatusPill } from "@/components/status-pill";
import { useTokenMetadata } from "@/hooks/use-token-metadata";
import {
  formatCountdown,
  formatTokenAmount,
  percentOf,
  shortAddress,
} from "@/lib/format";
import type { IndexedRaffle } from "@/lib/subgraph";

function stateTone(
  state: string,
): "active" | "resolved" | "warning" | "neutral" {
  if (state === "ACTIVE") return "active";
  if (state === "RESOLVED") return "resolved";
  if (state === "DRAW_REQUESTED") return "warning";
  return "neutral";
}

export function RaffleCard({ raffle }: { readonly raffle: IndexedRaffle }) {
  const total = BigInt(raffle.totalTickets);
  const minimum = BigInt(raffle.minimumTickets);
  const progress = percentOf(total, minimum);
  const address = raffle.id as `0x${string}`;
  const quoteToken = raffle.quoteToken as `0x${string}`;
  const tokenMetadata = useTokenMetadata(quoteToken);

  return (
    <article className="ticket-card overflow-hidden">
      <div className="relative grid aspect-[16/10] place-items-center overflow-hidden bg-[#1726a3] text-white">
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_30%_20%,rgba(215,255,95,.42),transparent_36%),radial-gradient(circle_at_70%_80%,rgba(255,114,92,.34),transparent_32%)]" />
        <div className="relative grid size-24 rotate-6 place-items-center rounded-[2rem] border border-white/30 bg-white/10 shadow-2xl backdrop-blur">
          <Gem aria-hidden size={42} strokeWidth={1.5} />
        </div>
        <div className="absolute left-4 top-4">
          <StatusPill tone={stateTone(raffle.state)}>
            {raffle.state.replaceAll("_", " ").toLowerCase()}
          </StatusPill>
        </div>
        {!raffle.quoteTokenVerified ? (
          <p className="absolute right-4 top-4 flex items-center gap-1 rounded-full bg-amber-100 px-3 py-1 text-xs font-black text-amber-950">
            <ShieldAlert aria-hidden size={13} /> Unverified token
          </p>
        ) : null}
        <p className="absolute bottom-4 right-4 rounded-full bg-black/35 px-3 py-1 text-xs font-bold backdrop-blur">
          Token #{raffle.prizeTokenId}
        </p>
      </div>

      <div className="perforated p-5 pb-6">
        <div className="flex items-start justify-between gap-4">
          <div>
            <p className="eyebrow">Prize contract</p>
            <h3 className="mt-1 text-2xl font-bold">
              {shortAddress(raffle.prizeToken as `0x${string}`)}
            </h3>
          </div>
          <Link
            aria-label={`Open raffle ${raffle.factoryId}`}
            className="grid size-10 shrink-0 place-items-center rounded-full border border-black hover:bg-[#ffdc55]"
            href={`/raffle/${address}`}
          >
            <ArrowUpRight aria-hidden size={18} />
          </Link>
        </div>

        <div className="mt-5 grid grid-cols-2 gap-3">
          <div className="rounded-xl bg-black/[0.045] p-3">
            <p className="flex items-center gap-1.5 text-xs font-bold text-[#56506a]">
              <Ticket aria-hidden size={14} /> Ticket
            </p>
            <p className="numeric mt-1 text-sm font-black">
              {formatTokenAmount(
                BigInt(raffle.ticketPrice),
                tokenMetadata.decimals,
                tokenMetadata.symbol,
              )}
            </p>
          </div>
          <div className="rounded-xl bg-black/[0.045] p-3">
            <p className="flex items-center gap-1.5 text-xs font-bold text-[#56506a]">
              <Clock3 aria-hidden size={14} /> Time left
            </p>
            <p className="numeric mt-1 text-sm font-black">
              {raffle.state === "ACTIVE"
                ? formatCountdown(BigInt(raffle.endTime))
                : raffle.outcome.replaceAll("_", " ").toLowerCase()}
            </p>
          </div>
        </div>

        <div className="mt-5">
          <div className="mb-2 flex items-end justify-between gap-3">
            <p className="text-xs font-bold text-[#56506a]">NFT threshold</p>
            <p className="numeric text-xs font-black">
              {total.toString()} / {minimum.toString()} tickets
            </p>
          </div>
          <div className="h-2 overflow-hidden rounded-full bg-black/10">
            <div
              className="h-full rounded-full bg-[#ef2ab2]"
              style={{ width: `${progress}%` }}
            />
          </div>
        </div>
      </div>
    </article>
  );
}
