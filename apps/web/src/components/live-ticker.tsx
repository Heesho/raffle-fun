"use client";

import { useQuery } from "@tanstack/react-query";
import { CircleDollarSign, Dices, Gift, Ticket } from "lucide-react";
import Link from "next/link";
import { type Address } from "viem";

import { isDemoMode } from "@/lib/demo";
import { SANDBOX_USDC, toIndexedActivity } from "@/lib/sandbox/adapter";
import { useSandbox } from "@/lib/sandbox/store";
import { formatTokenAmount, shortAddress } from "@/lib/format";
import {
  fetchActivity,
  isSubgraphConfigured,
  type IndexedActivity,
} from "@/lib/subgraph";

/**
 * A scrolling strip of the newest protocol events, drawn as the brand board's
 * stacked notification pills. It is the clearest signal that something is
 * happening right now, so it sits directly above the raffle grid.
 */
const kinds = {
  PURCHASE: { label: "bought entries for", icon: Ticket },
  RESOLUTION: { label: "drew a winner", icon: Dices },
  QUOTE_CLAIM: { label: "claimed", icon: CircleDollarSign },
  PRIZE_CLAIM: { label: "claimed the NFT", icon: Gift },
} as const;

/**
 * The board's own pill pairings, in its own order: yellow on navy, navy on
 * pink, yellow on blue, pink on navy, yellow on near-black. Pills cycle by
 * position so a feed that is mostly purchases still reads as a colour stack
 * rather than one repeated hue. Every pairing is a deliberate one off the
 * board — none of them are tint-on-tint.
 */
const palette = [
  { background: "var(--pink)", color: "#ffffff" },
  { background: "var(--brand-navy)", color: "var(--yellow)" },
  { background: "var(--yellow)", color: "var(--brand-navy)" },
  { background: "var(--sky)", color: "var(--brand-navy)" },
  { background: "var(--brand-black)", color: "var(--yellow)" },
] as const;

export function LiveTicker() {
  const demo = isDemoMode();
  const configured = isSubgraphConfigured();
  const { sandbox } = useSandbox();
  const query = useQuery<readonly IndexedActivity[]>({
    queryKey: ["activity"],
    queryFn: fetchActivity,
    enabled: !demo && configured,
    refetchInterval: 20_000,
  });

  const source = demo
    ? sandbox === undefined
      ? []
      : toIndexedActivity(sandbox)
    : (query.data ?? []);
  const events = source.slice(0, 14);
  if (events.length === 0) return null;

  // Duplicated once so the marquee can loop seamlessly at -50%.
  const lane = [...events, ...events];

  return (
    <div className="marquee-viewport relative overflow-hidden py-1">
      <div
        className="marquee gap-2.5"
        style={{ ["--marquee-duration" as string]: `${events.length * 4.5}s` }}
      >
        {lane.map((event, index) => (
          <TickerPill
            event={event}
            key={`${event.id}-${index}`}
            newest={index === 0}
            tone={palette[(index % events.length) % palette.length]!}
          />
        ))}
      </div>
      {/* Soften both ends so pills fade instead of clipping. */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-y-0 left-0 w-16 bg-gradient-to-r from-[var(--paper)] to-transparent"
      />
      <div
        aria-hidden
        className="pointer-events-none absolute inset-y-0 right-0 w-16 bg-gradient-to-l from-[var(--paper)] to-transparent"
      />
    </div>
  );
}

function TickerPill({
  event,
  newest,
  tone,
}: {
  readonly event: IndexedActivity;
  readonly newest: boolean;
  readonly tone: (typeof palette)[number];
}) {
  const kind = kinds[event.kind];
  const Icon = kind.icon;
  const token = event.quoteToken === null ? undefined : SANDBOX_USDC;
  const amount =
    event.amount !== null && token !== undefined
      ? formatTokenAmount(BigInt(event.amount), token.decimals, token.symbol)
      : null;

  return (
    <Link
      className={`flex shrink-0 items-center gap-2 rounded-full px-4 py-2 text-[length:var(--text-xs)] font-semibold transition-transform hover:scale-[1.03] ${
        newest ? "pop-in" : ""
      }`}
      href={`/raffle/${event.raffle}`}
      style={{ background: tone.background, color: tone.color }}
    >
      <Icon aria-hidden size={13} />
      <span className="numeric opacity-75">
        {event.account ? shortAddress(event.account as Address) : "Someone"}
      </span>
      <span>{kind.label}</span>
      {amount ? <span className="numeric">{amount}</span> : null}
    </Link>
  );
}
