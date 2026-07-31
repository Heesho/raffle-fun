"use client";

import {
  ArrowUpRight,
  CircleDollarSign,
  Clock3,
  ExternalLink,
  Ticket,
  Trophy,
  Users,
} from "lucide-react";
import Link from "next/link";
import type { ReactNode } from "react";
import type { Address } from "viem";

import { PrizeArt } from "@/components/prize-art";
import { StatusPill, type StatusTone } from "@/components/status-pill";
import { ThresholdBar } from "@/components/threshold-bar";
import { useCountdown } from "@/hooks/use-countdown";
import {
  cashToSponsor,
  cashToWinner,
  ticketsToThreshold,
} from "@/lib/economics";
import { formatDateTime, formatTokenAmount, shortAddress } from "@/lib/format";
import { explorerAddressUrl } from "@/lib/protocol";

/** The shape both the live lens read and the demo fixtures normalize into. */
export interface RaffleViewModel {
  readonly address: Address;
  readonly factoryId: string;
  readonly sponsor: Address;
  readonly quoteToken: Address;
  readonly prizeToken: Address;
  readonly prizeTokenId: string;
  readonly prizeName?: string;
  readonly prizeCollection?: string;
  readonly ticketPrice: bigint;
  readonly minimumTickets: bigint;
  readonly totalTickets: bigint;
  readonly grossSales: bigint;
  readonly netPot: bigint;
  readonly startTime: bigint;
  readonly endTime: bigint;
  readonly stateLabel: string;
  readonly stateTone: StatusTone;
  readonly isActive: boolean;
  readonly outcomeLabel?: string;
  readonly winningTicketId?: bigint;
  readonly accountTicketBalance?: bigint;
  readonly prizeImage?: string;
  readonly prizePixelated?: boolean;
}

export interface TokenDisplay {
  readonly symbol: string;
  readonly decimals: number | undefined;
}

export function RaffleLayout({
  view,
  token,
  banner,
  aside,
  footnote,
}: {
  readonly view: RaffleViewModel;
  readonly token: TokenDisplay;
  readonly banner?: ReactNode;
  readonly aside: ReactNode;
  readonly footnote?: ReactNode;
}) {
  const thresholdMet = view.totalTickets >= view.minimumTickets;
  const remaining = ticketsToThreshold(view.totalTickets, view.minimumTickets);
  const thresholdTarget = view.ticketPrice * view.minimumTickets;
  const winnerCash = cashToWinner(view.netPot);
  const sponsorCash = cashToSponsor(view.netPot);
  const countdown = useCountdown(view.endTime);
  const amount = (value: bigint) =>
    formatTokenAmount(value, token.decimals, token.symbol);

  return (
    <>
      {/* The title block sits on the deep indigo field so a raffle page opens
          with the brand, the same way every other page does. */}
      <section className="panel panel-ink">
        <div className="page-shell py-8 md:py-10">
          <Link
            className="inline-flex items-center gap-1.5 text-[length:var(--text-sm)] font-medium text-white/70 transition-colors hover:text-white"
            href="/"
          >
            ← All raffles
          </Link>

          <div className="mt-4 flex flex-wrap items-start justify-between gap-4">
            <div className="min-w-0">
              <p className="eyebrow">
                {view.prizeCollection ?? `Raffle #${view.factoryId}`}
              </p>
              <h1 className="mt-2 text-[length:var(--text-4xl)] text-white">
                {view.prizeName ?? `NFT #${view.prizeTokenId}`}
              </h1>
            </div>
            <StatusPill pulse={view.isActive} tone={view.stateTone}>
              {view.stateLabel}
            </StatusPill>
          </div>
        </div>
      </section>

      <div className="page-shell py-10 md:py-12">
        {banner ? <div className="mb-6">{banner}</div> : null}

        <div className="grid gap-7 lg:grid-cols-[1fr_23rem]">
        <div className="space-y-6">
          <section className="card overflow-hidden">
            <PrizeArt
              className="aspect-[16/10] w-full"
              fit="contain"
              imageUrl={view.prizeImage}
              pixelated={view.prizePixelated}
              seed={`${view.prizeToken}-${view.prizeTokenId}`}
            />
            <div className="grid gap-3 p-5 sm:grid-cols-2 lg:grid-cols-4">
              <Metric
                icon={<CircleDollarSign size={16} />}
                label="Ticket price"
                value={amount(view.ticketPrice)}
              />
              <Metric
                icon={<Users size={16} />}
                label="Tickets sold"
                value={view.totalTickets.toString()}
              />
              <Metric
                icon={<Clock3 size={16} />}
                label={view.isActive ? "Time left" : "Sale"}
                value={
                  view.isActive
                    ? countdown === ""
                      ? "—"
                      : countdown
                    : "Closed"
                }
              />
              <Metric
                icon={<Ticket size={16} />}
                label="Your tickets"
                value={(view.accountTicketBalance ?? 0n).toString()}
              />
            </div>
          </section>

          <section className="card p-6 md:p-7">
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div>
                <p className="eyebrow">
                  {view.outcomeLabel ? "Final result" : "If the sale ended now"}
                </p>
                <h2 className="mt-2 text-2xl md:text-3xl">
                  {thresholdMet
                    ? "The winner takes the NFT"
                    : `The winner takes ${amount(winnerCash)}`}
                </h2>
                <p className="mt-2 text-sm leading-6 text-[var(--ink-2)]">
                  {thresholdMet
                    ? `The threshold is met, so the sponsor claims the ${amount(view.netPot)} net pot instead of the NFT.`
                    : `${remaining.toString()} more ticket${remaining === 1n ? "" : "s"} flips the prize from the cash pot to the NFT.`}
                </p>
              </div>
            </div>

            <div className="mt-7">
              <ThresholdBar
                minimum={view.minimumTickets}
                size="lg"
                total={view.totalTickets}
              />
              <div className="mt-2.5 flex items-center justify-between text-[length:var(--text-xs)]">
                <span className="numeric font-semibold text-[var(--ink)]">
                  {view.totalTickets.toString()} sold
                </span>
                <span className="text-[var(--ink-3)]">
                  {thresholdMet
                    ? `NFT unlocked · ${(view.totalTickets - view.minimumTickets).toString()} past the threshold`
                    : `NFT at ${view.minimumTickets.toString()} · ${remaining.toString()} to the flip`}
                </span>
              </div>
            </div>

            <div className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <Stat label="Cash pot (winner 80%)" value={amount(winnerCash)} />
              <Stat label="Sponsor 20%" value={amount(sponsorCash)} />
              <Stat label="Net pot" value={amount(view.netPot)} />
              <Stat label="Gross target" value={amount(thresholdTarget)} />
            </div>
            <p className="mt-4 text-xs leading-5 text-[var(--ink-3)]">
              These figures reflect {amount(view.grossSales)} of gross sales so
              far. They move with every ticket and are not a guarantee while the
              sale is open.
            </p>
          </section>

          <section>
            <p className="eyebrow">Settlement branches</p>
            <h2 className="mt-2 text-2xl md:text-3xl">
              What the winner receives
            </h2>
            <div className="mt-5 grid gap-4 md:grid-cols-2">
              <OutcomePanel
                active={thresholdMet && view.outcomeLabel === undefined}
                headline={`at ${view.minimumTickets.toString()}+ tickets`}
                icon={<Trophy aria-hidden size={19} />}
                label="At or above threshold"
                text="The sponsor claims the full net pot. Protocol and any provider claims remain payable."
                tint="var(--yellow-wash)"
                title="Winner claims the NFT"
              />
              <OutcomePanel
                active={!thresholdMet && view.outcomeLabel === undefined}
                headline={`${amount(winnerCash)} today`}
                icon={<CircleDollarSign aria-hidden size={19} />}
                label={`Below ${view.minimumTickets.toString()} tickets`}
                text="The sponsor reclaims the NFT and receives the remaining 20% of the net pot."
                tint="var(--sky-wash)"
                title="Winner claims 80% cash"
              />
            </div>
            {view.outcomeLabel ? (
              <p className="mt-4 rounded-2xl bg-[var(--sky-wash)] p-4 text-sm font-extrabold text-[#1c5fa8]">
                Settled: {view.outcomeLabel}
                {view.winningTicketId !== undefined && view.winningTicketId > 0n
                  ? ` · Ticket #${view.winningTicketId.toString()} won`
                  : ""}
              </p>
            ) : null}
          </section>

          <section className="card p-6 md:p-7">
            <p className="eyebrow">Chain-authoritative details</p>
            <dl className="mt-5 grid gap-4 text-sm sm:grid-cols-2">
              <Detail
                href={explorerAddressUrl(view.address)}
                label="Raffle contract"
                value={shortAddress(view.address)}
              />
              <Detail
                href={explorerAddressUrl(view.sponsor)}
                label="Sponsor"
                value={shortAddress(view.sponsor)}
              />
              <Detail
                href={explorerAddressUrl(view.prizeToken)}
                label="Prize contract"
                value={shortAddress(view.prizeToken)}
              />
              <Detail
                href={explorerAddressUrl(view.quoteToken)}
                label="Payment token"
                value={`${token.symbol} · ${shortAddress(view.quoteToken)}`}
              />
              <Detail label="Starts" value={formatDateTime(view.startTime)} />
              <Detail label="Ends" value={formatDateTime(view.endTime)} />
            </dl>
          </section>
        </div>

          <aside
            className="space-y-5 lg:sticky lg:top-24 lg:self-start"
            id="raffle-action"
          >
            {aside}
            {footnote}
          </aside>
        </div>

        {/* On phones the purchase panel sits far below the fold, so the price
            and entry point stay pinned. */}
        {view.isActive ? (
          <div className="fixed inset-x-0 bottom-0 z-30 border-t border-[var(--line)] bg-[color-mix(in_srgb,var(--paper)_92%,transparent)] px-4 py-3 backdrop-blur-xl lg:hidden">
            <div className="flex items-center justify-between gap-4">
              <div>
                <p className="eyebrow">Ticket</p>
                <p className="figure mt-0.5">{amount(view.ticketPrice)}</p>
              </div>
              <a className="btn btn-primary" href="#raffle-action">
                Buy tickets
              </a>
            </div>
          </div>
        ) : null}
      </div>
    </>
  );
}

function Metric({
  icon,
  label,
  value,
}: {
  readonly icon: ReactNode;
  readonly label: string;
  readonly value: string;
}) {
  return (
    <div className="rounded-2xl bg-[var(--paper-sunk)] p-4">
      <p className="flex items-center gap-1.5 text-xs font-bold text-[var(--ink-2)]">
        {icon} {label}
      </p>
      <p className="numeric mt-1.5 font-extrabold">{value}</p>
    </div>
  );
}

function Stat({
  label,
  value,
}: {
  readonly label: string;
  readonly value: string;
}) {
  return (
    <div className="rounded-2xl bg-[var(--paper-sunk)] p-4">
      <dt className="text-xs font-bold text-[var(--ink-2)]">{label}</dt>
      <dd className="numeric mt-1 font-extrabold">{value}</dd>
    </div>
  );
}

function OutcomePanel({
  icon,
  label,
  title,
  text,
  tint,
  active,
  headline,
}: {
  readonly icon: ReactNode;
  readonly label: string;
  readonly title: string;
  readonly text: string;
  readonly tint: string;
  readonly active: boolean;
  readonly headline: string;
}) {
  return (
    <div
      className={`rounded-3xl border p-6 transition-colors ${
        active
          ? "border-transparent"
          : "border-[var(--line)] bg-[var(--paper-raised)]"
      }`}
      style={active ? { background: tint } : undefined}
    >
      <div className="flex items-center justify-between">
        <span className="grid size-10 place-items-center rounded-full bg-white/70 text-[var(--ink)]">
          {icon}
        </span>
        {active ? (
          <span className="chip bg-white/70 text-[var(--ink-2)]">
            On track
          </span>
        ) : null}
      </div>
      <p className="eyebrow mt-5">{label}</p>
      <h3 className="mt-2 text-xl">{title}</h3>
      <p className="numeric mt-1 text-sm font-extrabold text-[var(--ink-2)]">
        {headline}
      </p>
      <p className="mt-2.5 text-sm leading-6 text-[var(--ink-2)]">{text}</p>
    </div>
  );
}

function Detail({
  label,
  value,
  href,
}: {
  readonly label: string;
  readonly value: string;
  readonly href?: string;
}) {
  return (
    <div>
      <dt className="text-xs font-bold text-[var(--ink-2)]">{label}</dt>
      <dd className="numeric mt-1 font-extrabold">
        {href ? (
          <a
            className="inline-flex items-center gap-1 hover:text-[var(--pink)] hover:underline"
            href={href}
            rel="noreferrer"
            target="_blank"
          >
            {value} <ExternalLink aria-hidden size={13} />
          </a>
        ) : (
          value
        )}
      </dd>
    </div>
  );
}

export function InvalidState({
  title,
  detail,
}: {
  readonly title: string;
  readonly detail: string;
}) {
  return (
    <div className="page-shell py-20">
      <div className="card mx-auto max-w-xl p-10 text-center">
        <h1 className="text-3xl">{title}</h1>
        <p className="mt-4 text-sm leading-6 text-[var(--ink-2)]">
          {detail}
        </p>
        <Link className="btn btn-ink mt-7" href="/">
          Back to discover <ArrowUpRight aria-hidden size={16} />
        </Link>
      </div>
    </div>
  );
}
