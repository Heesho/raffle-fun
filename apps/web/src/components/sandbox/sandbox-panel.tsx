"use client";

import {
  Check,
  CircleDollarSign,
  Dices,
  FastForward,
  Gift,
  LoaderCircle,
  Minus,
  Plus,
  ShoppingBag,
  Trophy,
  Undo2,
} from "lucide-react";
import { useState } from "react";

import { useNowMs } from "@/hooks/use-now";
import { formatTokenAmount } from "@/lib/format";
import { SANDBOX_WETH } from "@/lib/sandbox/adapter";
import {
  canCloseEmptyRaffle,
  canEnableRefunds,
  canRequestDraw,
  ENTROPY_FEE,
  isOpen,
  MAX_TICKETS_PER_PURCHASE,
  ticketsOwnedBy,
  thresholdMet,
  type SandboxRaffle,
} from "@/lib/sandbox/engine";
import { useSandbox } from "@/lib/sandbox/store";

const amount = (value: bigint) =>
  formatTokenAmount(value, SANDBOX_WETH.decimals, SANDBOX_WETH.symbol);

export function SandboxPanel({ raffle }: { readonly raffle: SandboxRaffle }) {
  const { sandbox, error, clearError, ...actions } = useSandbox();
  const now = useNowMs();
  if (sandbox === undefined || now === undefined) return null;
  const open = isOpen(raffle, now);
  const mine = ticketsOwnedBy(raffle, sandbox.player);
  const owed = raffle.claimableQuote[sandbox.player] ?? 0n;

  return (
    <>
      {open ? (
        <BuyPanel raffle={raffle} mine={mine} />
      ) : (
        <SettlePanel raffle={raffle} mine={mine} now={now} owed={owed} />
      )}

      {open ? (
        <button
          className="btn btn-ghost w-full text-[var(--ink-3)]"
          onClick={() => actions.skipToEnd(raffle.id)}
          type="button"
        >
          <FastForward aria-hidden size={15} /> Skip ahead to the close
        </button>
      ) : null}

      {error ? (
        <p
          className="rounded-2xl bg-[var(--danger-wash)] p-4 text-sm font-bold text-[var(--danger)]"
          onAnimationEnd={clearError}
          role="alert"
        >
          {error}
        </p>
      ) : null}
    </>
  );
}

function BuyPanel({
  raffle,
  mine,
}: {
  readonly raffle: SandboxRaffle;
  readonly mine: number;
}) {
  const { sandbox, buyTickets } = useSandbox();
  const [quantity, setQuantity] = useState(1);
  if (sandbox === undefined) return null;
  const gross = raffle.ticketPrice * BigInt(quantity);
  const projectedFee = ((raffle.unsettledPot + gross) * 5n) / 100n;
  const sold = raffle.tickets.length;
  const oddsAfter = ((mine + quantity) / (sold + quantity)) * 100;
  const affordable = sandbox.wallet.weth >= gross;

  return (
    <section className="card p-6">
      <p className="eyebrow">Your action</p>
      <h2 className="mt-2 text-2xl">Get tickets</h2>
      <div className="mt-5">
        <span className="field-label" id="sandbox-quantity">
          Quantity
        </span>
        <div className="flex items-center gap-2">
          <button
            aria-label="One fewer ticket"
            className="btn btn-outline !size-12 !min-h-0 shrink-0 !p-0"
            disabled={quantity <= 1}
            onClick={() => setQuantity((value) => Math.max(1, value - 1))}
            type="button"
          >
            <Minus aria-hidden size={18} />
          </button>
          <input
            aria-labelledby="sandbox-quantity"
            className="input numeric !h-12 text-center !text-lg !font-extrabold"
            inputMode="numeric"
            onChange={(event) => {
              const next = Number.parseInt(event.target.value, 10);
              setQuantity(
                Number.isNaN(next)
                  ? 1
                  : Math.min(MAX_TICKETS_PER_PURCHASE, Math.max(1, next)),
              );
            }}
            type="number"
            value={quantity}
          />
          <button
            aria-label="One more ticket"
            className="btn btn-outline !size-12 !min-h-0 shrink-0 !p-0"
            disabled={quantity >= MAX_TICKETS_PER_PURCHASE}
            onClick={() =>
              setQuantity((value) =>
                Math.min(MAX_TICKETS_PER_PURCHASE, value + 1),
              )
            }
            type="button"
          >
            <Plus aria-hidden size={18} />
          </button>
        </div>
      </div>
      <dl className="mt-5 space-y-2 text-sm">
        <Row label="Total paid" strong value={amount(gross)} />
        <Row label="Projected 5% fee" value={amount(projectedFee)} />
        <Row label="Your odds after" value={`${oddsAfter.toFixed(1)}%`} />
      </dl>
      <div className="perforation my-5" />
      <button
        className="btn btn-primary w-full"
        disabled={!affordable}
        onClick={() => buyTickets(raffle.id, quantity)}
        type="button"
      >
        <ShoppingBag aria-hidden size={17} />
        {affordable
          ? `Buy ${quantity} ticket${quantity === 1 ? "" : "s"}`
          : "Not enough WETH"}
      </button>
    </section>
  );
}

function SettlePanel({
  raffle,
  mine,
  owed,
  now,
}: {
  readonly raffle: SandboxRaffle;
  readonly mine: number;
  readonly owed: bigint;
  readonly now: number;
}) {
  const {
    sandbox,
    requestDraw,
    closeEmptyRaffle,
    enableRefunds,
    redeemRefundTickets,
    redeemWinningTicket,
    claimSponsorPrize,
    claimQuote,
  } = useSandbox();
  if (sandbox === undefined) return null;

  const drawing = raffle.status === "DRAWING";
  const refunding = raffle.status === "REFUNDING";
  const successful =
    raffle.status === "NFT_WON" || raffle.status === "CASH_WON";
  const winningTicket =
    raffle.winningTicketId === null
      ? undefined
      : raffle.tickets[raffle.winningTicketId - 1];
  const ownsWinning =
    winningTicket !== undefined &&
    !winningTicket.burned &&
    winningTicket.owner.toLowerCase() === sandbox.player.toLowerCase();
  const recoveryRecipient =
    raffle.sponsorPrizeRecoveryRecipient.toLowerCase() ===
    sandbox.player.toLowerCase();
  const sponsorPrizeAvailable =
    recoveryRecipient &&
    !raffle.prizeClaimed &&
    (raffle.status === "CASH_WON" || refunding || raffle.status === "CLOSED");
  const refundableMine = refunding ? mine : 0;

  return (
    <section className="card p-6">
      <p className="eyebrow">Settlement</p>

      {canRequestDraw(raffle, now) ? (
        <>
          <h2 className="mt-2 text-2xl">The sale has closed</h2>
          <p className="mt-3 text-sm leading-6 text-[var(--ink-2)]">
            Anyone can pay Pyth Entropy&apos;s live fee and request the single
            draw.
          </p>
          <dl className="mt-4 space-y-2 text-sm">
            <Row label="Tickets" value={raffle.tickets.length.toString()} />
            <Row label="Your tickets" value={mine.toString()} />
            <Row
              label="Randomness fee"
              value={formatTokenAmount(ENTROPY_FEE, 18, "ETH")}
            />
            <Row
              label="Branch if drawn now"
              strong
              value={
                thresholdMet(raffle)
                  ? "NFT to winning bearer"
                  : "80% cash to winning bearer"
              }
            />
          </dl>
          <button
            className="btn btn-primary mt-5 w-full"
            onClick={() => requestDraw(raffle.id)}
            type="button"
          >
            <Dices aria-hidden size={17} /> Request the draw
          </button>
        </>
      ) : null}

      {canCloseEmptyRaffle(raffle, sandbox.player, now) ? (
        <button
          className="btn btn-outline mt-5 w-full"
          onClick={() => closeEmptyRaffle(raffle.id)}
          type="button"
        >
          <Check aria-hidden size={17} /> Close empty raffle
        </button>
      ) : null}

      {drawing ? (
        <>
          <h2 className="mt-2 text-2xl">Waiting on Pyth Entropy</h2>
          <p className="mt-3 flex items-center gap-2 text-sm font-bold">
            <LoaderCircle aria-hidden className="animate-spin" size={17} />
            The callback only selects a ticket and records liabilities.
          </p>
        </>
      ) : null}

      {canEnableRefunds(raffle, now) ? (
        <button
          className="btn btn-outline mt-5 w-full"
          onClick={() => enableRefunds(raffle.id)}
          type="button"
        >
          <Undo2 aria-hidden size={17} /> Enable ticket-burn refunds
        </button>
      ) : null}

      {successful ? (
        <>
          <h2 className="mt-2 text-2xl">
            {ownsWinning
              ? "Your ticket won!"
              : `Ticket #${raffle.winningTicketId} won`}
          </h2>
          <div className="mt-4 rounded-2xl bg-[var(--paper-sunk)] p-4 text-sm">
            <p className="flex items-center gap-2 font-bold">
              <Trophy aria-hidden size={16} /> Current bearer:{" "}
              {winningTicket?.owner.slice(0, 8)}…
            </p>
            <p className="mt-2 text-[var(--ink-2)]">
              The ticket stays transferable until its current owner burns it for
              the {raffle.status === "NFT_WON" ? "NFT" : "cash award"}.
            </p>
          </div>
        </>
      ) : null}

      {refunding ? (
        <>
          <h2 className="mt-2 text-2xl">Refunds are open</h2>
          <p className="mt-3 text-sm leading-6 text-[var(--ink-2)]">
            Each current bearer burns a ticket for exactly{" "}
            {amount(raffle.ticketPrice)}.
          </p>
        </>
      ) : null}

      <div className="mt-5 grid gap-2">
        {ownsWinning ? (
          <button
            className="btn btn-primary w-full"
            onClick={() => redeemWinningTicket(raffle.id)}
            type="button"
          >
            <Gift aria-hidden size={17} /> Burn winning ticket &amp; redeem
          </button>
        ) : null}
        {refundableMine > 0 ? (
          <button
            className="btn btn-primary w-full"
            onClick={() => redeemRefundTickets(raffle.id)}
            type="button"
          >
            <CircleDollarSign aria-hidden size={17} /> Burn {refundableMine}{" "}
            ticket{refundableMine === 1 ? "" : "s"} &amp; refund
          </button>
        ) : null}
        {sponsorPrizeAvailable ? (
          <button
            className="btn btn-primary w-full"
            onClick={() => claimSponsorPrize(raffle.id)}
            type="button"
          >
            <Gift aria-hidden size={17} /> Recover sponsor NFT
          </button>
        ) : null}
        {owed > 0n ? (
          <button
            className="btn btn-primary w-full"
            onClick={() => claimQuote(raffle.id)}
            type="button"
          >
            <CircleDollarSign aria-hidden size={17} /> Claim {amount(owed)}
          </button>
        ) : null}
      </div>
    </section>
  );
}

function Row({
  label,
  value,
  strong = false,
}: {
  readonly label: string;
  readonly value: string;
  readonly strong?: boolean;
}) {
  return (
    <div className="flex items-center justify-between gap-4">
      <dt className={strong ? "font-extrabold" : "text-[var(--ink-2)]"}>
        {label}
      </dt>
      <dd className={`numeric ${strong ? "font-extrabold" : "font-bold"}`}>
        {value}
      </dd>
    </div>
  );
}
