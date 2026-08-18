"use client";

import { useQuery } from "@tanstack/react-query";
import {
  ArrowUpRight,
  CircleDollarSign,
  Dices,
  Gift,
  PlugZap,
  Ticket,
} from "lucide-react";
import Link from "next/link";
import { type Address } from "viem";

import { useTokenMetadata } from "@/hooks/use-token-metadata";
import { isDemoMode } from "@/lib/demo";
import { SANDBOX_USDC, toIndexedActivity } from "@/lib/sandbox/adapter";
import { useSandbox } from "@/lib/sandbox/store";
import { formatDateTime, formatTokenAmount, shortAddress } from "@/lib/format";
import { explorerTransactionUrl } from "@/lib/protocol";
import {
  fetchActivity,
  isSubgraphConfigured,
  type IndexedActivity,
} from "@/lib/subgraph";

const activityMeta = {
  PURCHASE: {
    label: "Entries purchased",
    icon: Ticket,
    tint: "var(--pink-wash)",
    ink: "var(--pink-deep)",
  },
  RESOLUTION: {
    label: "Raffle resolved",
    icon: Dices,
    tint: "var(--sky-wash)",
    ink: "#1c5fa8",
  },
  QUOTE_CLAIM: {
    label: "Payout claimed",
    icon: CircleDollarSign,
    tint: "var(--grass-wash)",
    ink: "#0d6b45",
  },
  PRIZE_CLAIM: {
    label: "NFT prize claimed",
    icon: Gift,
    tint: "var(--yellow-wash)",
    ink: "var(--amber-ink)",
  },
} as const;

export function ActivityFeed() {
  const demo = isDemoMode();
  const configured = isSubgraphConfigured();
  const { sandbox } = useSandbox();
  const query = useQuery<readonly IndexedActivity[]>({
    queryKey: ["activity"],
    queryFn: fetchActivity,
    enabled: !demo && configured,
    refetchInterval: 20_000,
  });

  const events = demo
    ? sandbox === undefined
      ? []
      : toIndexedActivity(sandbox)
    : (query.data ?? []);

  if (!demo && !configured) {
    return (
      <Notice
        title="No index is connected"
        text="Set NEXT_PUBLIC_SUBGRAPH_URL to stream real purchases, resolutions, and claims. No sample events are inserted."
      />
    );
  }

  if (!demo && query.isPending) {
    return (
      <div className="card mt-10 divide-y divide-[var(--line)]" role="status">
        <span className="sr-only">Loading protocol events</span>
        {[0, 1, 2, 3, 4].map((value) => (
          <div className="flex items-center gap-4 p-5" key={value}>
            <div className="skeleton size-11 shrink-0 rounded-xl" />
            <div className="flex-1">
              <div className="skeleton h-4 w-40 rounded-full" />
              <div className="skeleton mt-2 h-3 w-64 rounded-full" />
            </div>
          </div>
        ))}
      </div>
    );
  }

  if (!demo && query.isError) {
    return (
      <Notice
        action={
          <button className="btn btn-outline" onClick={() => query.refetch()}>
            Retry
          </button>
        }
        title="The index could not be reached"
        text="Activity is a convenience view; contract state and transaction receipts remain authoritative."
      />
    );
  }

  if (events.length === 0) {
    return (
      <Notice
        title="No activity yet"
        text="Protocol events appear here as soon as the first raffle is bought, drawn, or claimed."
      />
    );
  }

  return (
    <ol className="card mt-10 divide-y divide-[var(--line)] overflow-hidden">
      {events.map((activity) => (
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
  const onchainMetadata = useTokenMetadata(
    token?.toLowerCase() === SANDBOX_USDC.address
      ? undefined
      : (token ?? undefined),
  );
  const tokenMetadata =
    token?.toLowerCase() === SANDBOX_USDC.address
      ? SANDBOX_USDC
      : onchainMetadata;
  const meta = activityMeta[activity.kind];
  const Icon = meta.icon;

  return (
    <li className="flex flex-wrap items-center gap-4 p-5 transition-colors hover:bg-[var(--paper-sunk)]">
      <span
        aria-hidden
        className="grid size-11 shrink-0 place-items-center rounded-xl"
        style={{ background: meta.tint, color: meta.ink }}
      >
        <Icon size={19} />
      </span>

      <div className="min-w-0 flex-1">
        <p className="font-extrabold">{meta.label}</p>
        <p className="mt-0.5 truncate text-xs font-semibold text-[var(--ink-2)]">
          <span className="numeric">
            {activity.account
              ? shortAddress(activity.account as `0x${string}`)
              : "Protocol"}
          </span>
          {" · "}
          <Link
            className="numeric font-bold hover:text-[var(--pink)] hover:underline"
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

      <div className="flex items-center gap-3">
        <time className="numeric text-xs font-bold text-[var(--ink-3)]">
          {formatDateTime(BigInt(activity.timestamp))}
        </time>
        <a
          aria-label="Open transaction in explorer"
          className="grid size-9 place-items-center rounded-full border border-[var(--line-strong)] text-[var(--ink-2)] transition-colors hover:border-[var(--ink)] hover:text-[var(--ink)]"
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

function Notice({
  title,
  text,
  action,
}: {
  readonly title: string;
  readonly text: string;
  readonly action?: React.ReactNode;
}) {
  return (
    <div className="card mt-10 grid place-items-center px-6 py-16 text-center">
      <div className="max-w-md">
        <span className="mx-auto grid size-12 place-items-center rounded-2xl bg-[var(--sky-wash)] text-[#1c5fa8]">
          <PlugZap aria-hidden size={22} />
        </span>
        <h2 className="mt-5 text-2xl">{title}</h2>
        <p className="mt-2 text-sm leading-6 text-[var(--ink-2)]">{text}</p>
        {action ? <div className="mt-6">{action}</div> : null}
      </div>
    </div>
  );
}
