"use client";

import { useQuery } from "@tanstack/react-query";
import {
  ArrowUpRight,
  CircleDollarSign,
  Dices,
  Gift,
  LoaderCircle,
  Ticket,
} from "lucide-react";
import Link from "next/link";
import { type Address } from "viem";

import { useTokenMetadata } from "@/hooks/use-token-metadata";
import { formatDateTime, formatTokenAmount, shortAddress } from "@/lib/format";
import { explorerTransactionUrl } from "@/lib/protocol";
import {
  fetchActivity,
  isSubgraphConfigured,
  type IndexedActivity,
} from "@/lib/subgraph";

const activityLabels = {
  PURCHASE: "Tickets purchased",
  RESOLUTION: "Raffle resolved",
  QUOTE_CLAIM: "Quote payout claimed",
  PRIZE_CLAIM: "NFT prize claimed",
} as const;

function ActivityIcon({ kind }: { readonly kind: IndexedActivity["kind"] }) {
  const icons = {
    PURCHASE: Ticket,
    RESOLUTION: Dices,
    QUOTE_CLAIM: CircleDollarSign,
    PRIZE_CLAIM: Gift,
  };
  const Icon = icons[kind];
  return <Icon aria-hidden size={19} />;
}

export function ActivityFeed() {
  const configured = isSubgraphConfigured();
  const query = useQuery({
    queryKey: ["activity"],
    queryFn: fetchActivity,
    enabled: configured,
    refetchInterval: 20_000,
  });

  if (query.isPending && configured) {
    return (
      <div className="mt-10 flex items-center gap-2 font-bold" role="status">
        <LoaderCircle aria-hidden className="animate-spin" /> Loading protocol
        events…
      </div>
    );
  }

  if (query.isError) {
    return (
      <div className="ticket-card mt-10 p-8" role="alert">
        <h2 className="text-2xl font-bold">The index could not be reached</h2>
        <p className="mt-2 text-sm text-[#56506a]">
          Activity is a convenience view; contract state and transaction
          receipts remain authoritative.
        </p>
        <button className="btn btn-ghost mt-5" onClick={() => query.refetch()}>
          Retry
        </button>
      </div>
    );
  }

  if (!query.data?.length) {
    return (
      <div className="ticket-card mt-10 p-10 text-center">
        <Dices aria-hidden className="mx-auto" />
        <h2 className="mt-4 text-2xl font-bold">
          {configured
            ? "No activity indexed yet"
            : "Activity index not connected"}
        </h2>
        <p className="mx-auto mt-2 max-w-xl text-sm leading-6 text-[#56506a]">
          {configured
            ? "Real protocol events will appear here after the first raffle interaction."
            : "Configure a deployed subgraph endpoint to show real purchases, resolutions, and claims. No sample events are inserted."}
        </p>
      </div>
    );
  }

  return (
    <ol className="ticket-card mt-10 divide-y divide-black/10 overflow-hidden">
      {query.data.map((activity) => (
        <ActivityRow
          activity={activity}
          key={`${activity.kind}-${activity.id}`}
        />
      ))}
    </ol>
  );
}

function ActivityRow({ activity }: { readonly activity: IndexedActivity }) {
  const token = activity.quoteToken as Address | null;
  const tokenMetadata = useTokenMetadata(token ?? undefined);
  return (
    <li className="grid gap-4 p-5 sm:grid-cols-[2.75rem_1fr_auto] sm:items-center">
      <span className="grid size-11 place-items-center rounded-xl bg-[#ffdc55]">
        <ActivityIcon kind={activity.kind} />
      </span>
      <div>
        <p className="font-black">{activityLabels[activity.kind]}</p>
        <p className="mt-1 text-xs text-[#56506a]">
          {activity.account
            ? shortAddress(activity.account as `0x${string}`)
            : "Protocol"}{" "}
          ·{" "}
          <Link
            className="font-bold hover:underline"
            href={`/raffle/${activity.raffle}`}
          >
            {shortAddress(activity.raffle as `0x${string}`)}
          </Link>
          {activity.amount && token
            ? ` · ${formatTokenAmount(
                BigInt(activity.amount),
                tokenMetadata.decimals,
                tokenMetadata.symbol,
              )}`
            : ""}
        </p>
      </div>
      <div className="flex items-center gap-3 sm:text-right">
        <time className="numeric text-xs font-bold text-[#56506a]">
          {formatDateTime(BigInt(activity.timestamp))}
        </time>
        <a
          aria-label="Open transaction in explorer"
          className="grid size-9 place-items-center rounded-full border border-black/15 hover:bg-[#ffdc55]"
          href={explorerTransactionUrl(
            activity.transactionHash as `0x${string}`,
          )}
          rel="noreferrer"
          target="_blank"
        >
          <ArrowUpRight aria-hidden size={15} />
        </a>
      </div>
    </li>
  );
}
