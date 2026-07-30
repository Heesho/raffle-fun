"use client";

import { useQuery } from "@tanstack/react-query";
import { Search, SlidersHorizontal, Sparkles } from "lucide-react";
import { useMemo, useState } from "react";

import { RaffleCard } from "@/components/raffle-card";
import { fetchRaffles, isSubgraphConfigured } from "@/lib/subgraph";

const filters = [
  "ALL",
  "ACTIVE",
  "DRAW_REQUESTED",
  "RESOLVED",
  "CANCELLED",
] as const;

export function RaffleDirectory() {
  const [filter, setFilter] = useState<(typeof filters)[number]>("ALL");
  const [search, setSearch] = useState("");
  const configured = isSubgraphConfigured();
  const query = useQuery({
    queryKey: ["raffles"],
    queryFn: fetchRaffles,
    enabled: configured,
  });

  const raffles = useMemo(() => {
    const value = search.trim().toLowerCase();
    return (query.data ?? []).filter((raffle) => {
      const matchesState = filter === "ALL" || raffle.state === filter;
      const matchesSearch =
        value === "" ||
        [
          raffle.id,
          raffle.sponsor,
          raffle.quoteToken,
          raffle.prizeToken,
          raffle.prizeTokenId,
        ].some((field) => field.toLowerCase().includes(value));
      return raffle.quoteTokenVerified && matchesState && matchesSearch;
    });
  }, [filter, query.data, search]);

  return (
    <section className="page-shell py-16" aria-labelledby="raffles-heading">
      <div className="flex flex-col justify-between gap-6 lg:flex-row lg:items-end">
        <div>
          <p className="eyebrow">Live protocol</p>
          <h2
            id="raffles-heading"
            className="mt-2 text-4xl font-bold md:text-5xl"
          >
            Find your ticket
          </h2>
          <p className="mt-3 max-w-xl text-sm leading-6 text-[#56506a]">
            Browse active draws, races nearing their threshold, and recently
            settled outcomes using currently verified payment tokens. Known
            unverified raffles remain available by direct link.
          </p>
        </div>
        <div className="flex flex-col gap-3 sm:flex-row">
          <label className="relative">
            <span className="sr-only">Search raffles</span>
            <Search
              aria-hidden
              className="absolute left-3 top-1/2 -translate-y-1/2 text-[#56506a]"
              size={17}
            />
            <input
              className="input min-w-72 !pl-10"
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Address, sponsor, prize, payment token"
              type="search"
              value={search}
            />
          </label>
          <label className="relative">
            <span className="sr-only">Filter by state</span>
            <SlidersHorizontal
              aria-hidden
              className="absolute left-3 top-1/2 -translate-y-1/2 text-[#56506a]"
              size={17}
            />
            <select
              className="input !pl-10 !pr-9 font-bold"
              onChange={(event) =>
                setFilter(event.target.value as (typeof filters)[number])
              }
              value={filter}
            >
              {filters.map((value) => (
                <option key={value} value={value}>
                  {value === "ALL"
                    ? "All states"
                    : value.replaceAll("_", " ").toLowerCase()}
                </option>
              ))}
            </select>
          </label>
        </div>
      </div>

      {query.isPending && configured ? (
        <div
          className="mt-10 grid gap-6 md:grid-cols-2 lg:grid-cols-3"
          aria-label="Loading raffles"
        >
          {[0, 1, 2].map((value) => (
            <div
              className="ticket-card h-[31rem] animate-pulse bg-white/55"
              key={value}
            />
          ))}
        </div>
      ) : null}

      {query.isError ? (
        <div className="ticket-card mt-10 p-8" role="alert">
          <p className="font-black">The index could not be reached.</p>
          <p className="mt-2 text-sm text-[#56506a]">
            Onchain state remains authoritative. Try again or open a known
            raffle address directly.
          </p>
          <button
            className="btn btn-ghost mt-5"
            onClick={() => query.refetch()}
          >
            Retry index
          </button>
        </div>
      ) : null}

      {!query.isPending && !query.isError && raffles.length === 0 ? (
        <div className="ticket-card mt-10 grid min-h-72 place-items-center p-8 text-center">
          <div>
            <span className="mx-auto grid size-14 place-items-center rounded-2xl bg-[#ffdc55]">
              <Sparkles aria-hidden />
            </span>
            <h3 className="mt-5 text-2xl font-bold">
              {configured
                ? "No raffles match this view"
                : "The index is not connected yet"}
            </h3>
            <p className="mx-auto mt-2 max-w-lg text-sm leading-6 text-[#56506a]">
              {configured
                ? "Clear the search or choose another lifecycle state."
                : "Configure a deployed network and its subgraph endpoint to surface real protocol data. No sample activity is substituted."}
            </p>
          </div>
        </div>
      ) : null}

      {raffles.length > 0 ? (
        <div className="mt-10 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {raffles.map((raffle) => (
            <RaffleCard key={raffle.id} raffle={raffle} />
          ))}
        </div>
      ) : null}
    </section>
  );
}
