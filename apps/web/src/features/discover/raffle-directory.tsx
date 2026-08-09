"use client";

import { useQuery } from "@tanstack/react-query";
import { Flame, PlugZap, Search, Ticket, X } from "lucide-react";
import Link from "next/link";
import { useMemo, useState } from "react";

import { CountUp } from "@/components/count-up";
import { LiveTicker } from "@/components/live-ticker";
import { RaffleCard, RaffleCardSkeleton } from "@/components/raffle-card";
import { useNow } from "@/hooks/use-now";
import { isDemoMode } from "@/lib/demo";
import { toIndexedRaffle } from "@/lib/sandbox/adapter";
import { useSandbox } from "@/lib/sandbox/store";
import { ticketsToThreshold } from "@/lib/economics";
import { fetchRaffles, isSubgraphConfigured } from "@/lib/subgraph";
import type { IndexedRaffle } from "@/lib/subgraph";

const filters = [
  { value: "ALL", label: "All" },
  { value: "ACTIVE", label: "Live" },
  { value: "DRAWING", label: "Drawing" },
  { value: "SETTLED", label: "Settled" },
  { value: "REFUNDING", label: "Refunding" },
  { value: "CLOSED", label: "Closed" },
] as const;

const sorts = [
  { value: "ENDING", label: "Ending soonest" },
  { value: "CLOSEST", label: "Closest to the NFT" },
  { value: "NEWEST", label: "Newest" },
  { value: "POPULAR", label: "Most tickets sold" },
] as const;

type Filter = (typeof filters)[number]["value"];
type Sort = (typeof sorts)[number]["value"];

export function RaffleDirectory() {
  const [filter, setFilter] = useState<Filter>("ALL");
  const [sort, setSort] = useState<Sort>("ENDING");
  const [search, setSearch] = useState("");
  const demo = isDemoMode();
  const configured = isSubgraphConfigured();

  const query = useQuery<readonly IndexedRaffle[]>({
    queryKey: ["raffles"],
    queryFn: fetchRaffles,
    enabled: !demo && configured,
    refetchInterval: 15_000,
  });

  const sandboxRaffles = useSandboxRaffles();

  const all = useMemo(() => {
    const source = demo ? sandboxRaffles : (query.data ?? []);
    return source.filter((raffle) => raffle.quoteTokenVerified);
  }, [demo, query.data, sandboxRaffles]);

  const raffles = useMemo(() => {
    const value = search.trim().toLowerCase();
    const matched = all.filter((raffle) => {
      const matchesState =
        filter === "ALL" ||
        raffle.state === filter ||
        (filter === "SETTLED" &&
          (raffle.state === "NFT_WON" || raffle.state === "CASH_WON"));
      const matchesSearch =
        value === "" ||
        [
          raffle.id,
          raffle.sponsor,
          raffle.quoteToken,
          raffle.prizeToken,
          raffle.prizeTokenId,
          raffle.prizeName ?? "",
          raffle.prizeCollection ?? "",
        ].some((field) => field.toLowerCase().includes(value));
      return matchesState && matchesSearch;
    });

    const rank = (raffle: IndexedRaffle) =>
      raffle.state === "ACTIVE" ? 0 : raffle.state === "DRAWING" ? 1 : 2;

    return [...matched].sort((a, b) => {
      // Open raffles always lead; a settled one is not "ending soonest".
      if (rank(a) !== rank(b)) return rank(a) - rank(b);
      if (sort === "ENDING") return Number(a.endTime) - Number(b.endTime);
      if (sort === "NEWEST") return Number(b.factoryId) - Number(a.factoryId);
      if (sort === "POPULAR") {
        return Number(b.totalTickets) - Number(a.totalTickets);
      }
      const left = ticketsToThreshold(
        BigInt(a.totalTickets),
        BigInt(a.minimumTickets),
      );
      const right = ticketsToThreshold(
        BigInt(b.totalTickets),
        BigInt(b.minimumTickets),
      );
      return Number(left) - Number(right);
    });
  }, [all, filter, search, sort]);

  const counts = useMemo(() => {
    const map = new Map<string, number>();
    for (const raffle of all) {
      map.set(raffle.state, (map.get(raffle.state) ?? 0) + 1);
    }
    return map;
  }, [all]);

  const now = useNow();
  const stats = useMemo(() => {
    return {
      live: all.filter((raffle) => raffle.state === "ACTIVE").length,
      tickets: all.reduce(
        (sum, raffle) => sum + Number(raffle.totalTickets),
        0,
      ),
      endingToday:
        now === undefined
          ? 0
          : all.filter(
              (raffle) =>
                raffle.state === "ACTIVE" &&
                Number(raffle.endTime) - now < 86_400,
            ).length,
    };
  }, [all, now]);

  const loading = demo
    ? sandboxRaffles.length === 0
    : configured && query.isPending;
  const unconfigured = !demo && !configured;

  return (
    <section
      className="page-shell scroll-mt-24 pb-16 pt-10"
      aria-labelledby="raffles-heading"
    >
      {!loading && all.length > 0 ? (
        <div className="mb-8">
          <LiveTicker />
        </div>
      ) : null}

      <div className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <p className="eyebrow">Live protocol</p>
          <h2
            id="raffles-heading"
            className="mt-2 text-[length:var(--text-3xl)]"
          >
            Find your ticket
          </h2>
          {all.length > 0 ? (
            <p className="mt-3 flex flex-wrap items-center gap-x-2 gap-y-1 text-[length:var(--text-sm)] text-[var(--ink-3)]">
              <span className="inline-flex items-center gap-1.5">
                <span className="relative flex size-1.5">
                  <span className="absolute inline-flex size-full animate-ping rounded-full bg-[var(--grass)] opacity-70" />
                  <span className="relative inline-flex size-1.5 rounded-full bg-[var(--grass)]" />
                </span>
                <span className="numeric font-semibold text-[var(--ink)]">
                  {stats.live}
                </span>{" "}
                live now
              </span>
              <span aria-hidden>·</span>
              <span>
                <CountUp
                  className="font-semibold text-[var(--ink)]"
                  value={stats.tickets}
                />{" "}
                tickets sold
              </span>
              {stats.endingToday > 0 ? (
                <>
                  <span aria-hidden>·</span>
                  <span className="inline-flex items-center gap-1 text-[var(--pink-ink)]">
                    <Flame aria-hidden size={13} />
                    <span className="numeric font-semibold">
                      {stats.endingToday}
                    </span>{" "}
                    ending today
                  </span>
                </>
              ) : null}
            </p>
          ) : null}
        </div>

        <div className="flex w-full flex-col gap-3 sm:flex-row lg:w-auto">
          <label className="relative w-full sm:w-64">
            <span className="sr-only">Search raffles</span>
            <Search
              aria-hidden
              className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-[var(--ink-3)]"
              size={17}
            />
            <input
              className="input !pl-11 !pr-10"
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Prize, collection, address"
              type="search"
              value={search}
            />
            {search !== "" ? (
              <button
                aria-label="Clear search"
                className="absolute right-2.5 top-1/2 grid size-7 -translate-y-1/2 place-items-center rounded-full text-[var(--ink-3)] hover:bg-[var(--paper-sunk)] hover:text-[var(--ink)]"
                onClick={() => setSearch("")}
                type="button"
              >
                <X aria-hidden size={15} />
              </button>
            ) : null}
          </label>
          <label className="sm:w-52">
            <span className="sr-only">Sort raffles</span>
            <select
              className="select"
              onChange={(event) => setSort(event.target.value as Sort)}
              value={sort}
            >
              {sorts.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </label>
        </div>
      </div>

      <div
        className="mt-6 flex flex-wrap gap-1.5"
        role="group"
        aria-label="Filter by raffle state"
      >
        {filters.map((option) => {
          const selected = filter === option.value;
          const count =
            option.value === "ALL"
              ? all.length
              : (counts.get(option.value) ?? 0);
          return (
            <button
              aria-pressed={selected}
              className={`chip ${
                selected
                  ? "bg-[var(--ink)] text-white"
                  : "border-[var(--line-strong)] bg-[var(--paper-raised)] text-[var(--ink-2)] hover:border-[var(--line-heavy)] hover:bg-[var(--paper-sunk)]"
              }`}
              key={option.value}
              onClick={() => setFilter(option.value)}
              type="button"
            >
              {option.label}
              <span
                className={`numeric ${selected ? "text-white/55" : "text-[var(--ink-3)]"}`}
              >
                {count}
              </span>
            </button>
          );
        })}
      </div>

      {loading ? (
        <div
          className="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-3"
          aria-label="Loading raffles"
          role="status"
        >
          {[0, 1, 2].map((value) => (
            <RaffleCardSkeleton key={value} />
          ))}
        </div>
      ) : null}

      {!demo && query.isError ? (
        <EmptyState
          action={
            <button className="btn btn-outline" onClick={() => query.refetch()}>
              Retry index
            </button>
          }
          icon={<PlugZap aria-hidden size={22} />}
          text="Onchain state remains authoritative. Try again, or open a known raffle address directly."
          title="The index could not be reached"
        />
      ) : null}

      {unconfigured ? (
        <EmptyState
          icon={<PlugZap aria-hidden size={22} />}
          text="Set NEXT_PUBLIC_SUBGRAPH_URL to index real protocol data, or set NEXT_PUBLIC_DEMO_MODE=on to preview the interface with sample raffles."
          title="No index is connected"
        />
      ) : null}

      {!loading && !query.isError && !unconfigured && raffles.length === 0 ? (
        <EmptyState
          action={
            all.length > 0 ? (
              <button
                className="btn btn-outline"
                onClick={() => {
                  setFilter("ALL");
                  setSearch("");
                }}
                type="button"
              >
                Clear filters
              </button>
            ) : (
              <Link className="btn btn-primary" href="/create">
                Sponsor the first raffle
              </Link>
            )
          }
          icon={<Ticket aria-hidden size={22} />}
          text={
            all.length > 0
              ? "Nothing matches this search and state combination yet."
              : "No raffles have been created on this network so far."
          }
          title={all.length > 0 ? "No raffles match" : "No raffles yet"}
        />
      ) : null}

      {raffles.length > 0 ? (
        <div className="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {raffles.map((raffle) => (
            <RaffleCard key={raffle.id} raffle={raffle} />
          ))}
        </div>
      ) : null}
    </section>
  );
}

/** Sandbox raffles, presented in the indexed shape the grid already renders. */
function useSandboxRaffles(): readonly IndexedRaffle[] {
  const { sandbox } = useSandbox();
  return useMemo(
    () => (sandbox?.raffles ?? []).map(toIndexedRaffle),
    [sandbox],
  );
}

function EmptyState({
  icon,
  title,
  text,
  action,
}: {
  readonly icon: React.ReactNode;
  readonly title: string;
  readonly text: string;
  readonly action?: React.ReactNode;
}) {
  return (
    <div className="card mt-8 grid place-items-center px-6 py-16 text-center">
      <div className="max-w-md">
        <span className="mx-auto grid size-12 place-items-center rounded-2xl bg-[var(--yellow-wash)] text-[var(--amber-ink)]">
          {icon}
        </span>
        <h3 className="mt-5 text-2xl">{title}</h3>
        <p className="mt-2 text-sm leading-6 text-[var(--ink-2)]">{text}</p>
        {action ? <div className="mt-6">{action}</div> : null}
      </div>
    </div>
  );
}
