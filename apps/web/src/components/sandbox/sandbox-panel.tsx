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
  canCloseNoSales,
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

/**
 * Every step of the real lifecycle, in order: buy, request the draw, wait for
 * the callback, then pull what you are owed. Only the step that is currently
 * possible is offered.
 */
export function SandboxPanel({ raffle }: { readonly raffle: SandboxRaffle }) {
  const { sandbox, error, clearError, ...actions } = useSandbox();
  const now = useNowMs();

  // Nothing time-dependent can be judged before the clock is available.
  if (sandbox === undefined || now === undefined) return null;

  const open = isOpen(raffle, now);
  const mine = ticketsOwnedBy(raffle, sandbox.player);
  const owed = raffle.claimableQuote[sandbox.player] ?? 0n;
  const isSponsor =
    raffle.sponsor.toLowerCase() === sandbox.player.toLowerCase();
  const isPrizeClaimant =
    raffle.prizeClaimant?.toLowerCase() === sandbox.player.toLowerCase();

  return (
    <>
      {open ? (
        <BuyPanel raffle={raffle} mine={mine} />
      ) : (
        <SettlePanel
          mine={mine}
          now={now}
          owed={owed}
          isPrizeClaimant={isPrizeClaimant}
          raffle={raffle}
        />
      )}

      {isSponsor && raffle.state === "ACTIVE" ? (
        <section className="card p-6">
          <p className="eyebrow">Sponsor controls</p>
          <h2 className="mt-2 text-xl">Your escrowed prize</h2>
          <p className="mt-3 text-sm leading-6 text-[var(--ink-2)]">
            {raffle.tickets.length === 0
              ? "No tickets have sold, so you can still cancel and take the NFT back. The moment ticket #1 sells this disappears for good."
              : `${raffle.tickets.length} tickets have sold. The NFT is locked until settlement — it can only reach the winner or come back to you through a claim.`}
          </p>
          <button
            className="btn btn-outline mt-4 w-full"
            disabled={raffle.tickets.length !== 0}
            onClick={() => actions.cancelBeforeSales(raffle.id)}
            type="button"
          >
            <Undo2 aria-hidden size={17} /> Cancel &amp; reclaim NFT
          </button>
        </section>
      ) : null}

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
  const projectedProtocolFee = ((raffle.unsettledPot + gross) * 5n) / 100n;
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
        <div className="mt-2 flex gap-1.5">
          {[5, 10, 25].map((preset) => (
            <button
              className="chip bg-[var(--paper-sunk)] text-[var(--ink-2)] hover:text-[var(--ink)]"
              key={preset}
              onClick={() => setQuantity(preset)}
              type="button"
            >
              {preset}
            </button>
          ))}
        </div>
      </div>

      <dl className="mt-5 space-y-2 text-sm">
        <Row label="Total paid" strong value={amount(gross)} />
        <Row label="Added to unsettled pot" value={amount(gross)} />
        <Row
          label="Projected fee at resolution"
          value={amount(projectedProtocolFee)}
        />
        <Row
          label={
            mine > 0 ? `Your odds (${mine + quantity} tickets)` : "Your odds"
          }
          value={`${oddsAfter.toFixed(1)}%`}
        />
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

      {mine > 0 ? (
        <p className="mt-3 text-center text-xs font-bold text-[var(--ink-2)]">
          You hold {mine} of {sold} tickets
        </p>
      ) : null}
    </section>
  );
}

function SettlePanel({
  raffle,
  mine,
  owed,
  now,
  isPrizeClaimant,
}: {
  readonly raffle: SandboxRaffle;
  readonly mine: number;
  readonly owed: bigint;
  readonly now: number;
  readonly isPrizeClaimant: boolean;
}) {
  const { sandbox, requestDraw, closeNoSales, claimPrize, claimQuote } =
    useSandbox();
  if (sandbox === undefined) return null;

  const drawable = canRequestDraw(raffle, now);
  const closable = canCloseNoSales(raffle, now);
  const pending = raffle.state === "DRAW_REQUESTED";
  const settled = raffle.state === "RESOLVED" || raffle.state === "CANCELLED";
  const iWon = raffle.winner?.toLowerCase() === sandbox.player.toLowerCase();

  return (
    <section className="card p-6">
      <p className="eyebrow">
        {settled ? "Result" : pending ? "Drawing" : "Settlement"}
      </p>

      {drawable ? (
        <>
          <h2 className="mt-2 text-2xl">The sale has closed</h2>
          <p className="mt-3 text-sm leading-6 text-[var(--ink-2)]">
            Nothing happens on its own. Someone has to pay the randomness fee
            and ask the oracle for a number — that can be you, even if you hold
            no tickets.
          </p>
          <dl className="mt-4 space-y-2 text-sm">
            <Row
              label="Tickets in the draw"
              value={raffle.tickets.length.toString()}
            />
            <Row label="Your tickets" value={mine.toString()} />
            <Row
              label="Randomness fee"
              value={formatTokenAmount(ENTROPY_FEE, 18, "ETH")}
            />
            <Row
              label="Branch if drawn now"
              strong
              value={
                thresholdMet(raffle) ? "NFT to winner" : "80% cash to winner"
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

      {closable ? (
        <>
          <h2 className="mt-2 text-2xl">Closed with no sales</h2>
          <p className="mt-3 text-sm leading-6 text-[var(--ink-2)]">
            Not one ticket sold, so there is no draw to run. Anyone can close it
            and hand the NFT back to the sponsor.
          </p>
          <button
            className="btn btn-outline mt-5 w-full"
            onClick={() => closeNoSales(raffle.id)}
            type="button"
          >
            <Check aria-hidden size={17} /> Close and return the NFT
          </button>
        </>
      ) : null}

      {pending ? (
        <>
          <h2 className="mt-2 text-2xl">Waiting on the oracle</h2>
          <p className="mt-3 flex items-center gap-2 text-sm font-bold">
            <LoaderCircle aria-hidden className="animate-spin" size={17} />
            Pyth Entropy is delivering the random number…
          </p>
          <p className="mt-3 text-sm leading-6 text-[var(--ink-2)]">
            The callback picks ticket{" "}
            <span className="numeric font-bold">
              (random % {raffle.tickets.length}) + 1
            </span>
            , snapshots whoever owns it, and credits the payouts. It moves no
            assets — everything after this is a claim.
          </p>
        </>
      ) : null}

      {settled ? (
        <>
          <h2 className="mt-2 text-2xl">
            {raffle.outcome === "NO_SALES"
              ? "No tickets sold"
              : raffle.outcome === "CANCELLED_BEFORE_SALE"
                ? "Cancelled before any sale"
                : iWon
                  ? "You won!"
                  : `Ticket #${raffle.winningTicketId} won`}
          </h2>

          {raffle.winningTicketId !== null ? (
            <div
              className="mt-4 rounded-2xl p-4 text-sm font-bold"
              style={{
                background: iWon ? "var(--yellow)" : "var(--paper-sunk)",
              }}
            >
              <p className="flex items-center gap-2">
                <Trophy aria-hidden size={16} />
                Ticket #{raffle.winningTicketId} of {raffle.tickets.length}
              </p>
              <p className="mt-1.5 font-medium text-[var(--ink)]/70">
                {thresholdMet(raffle)
                  ? "The threshold was met, so the winning ticket takes the NFT and the sponsor takes the distributable pot."
                  : "The threshold was missed, so the winning ticket takes 80% of the distributable pot and the NFT goes back to the sponsor."}
              </p>
            </div>
          ) : null}

          <div className="mt-5 grid gap-2">
            {isPrizeClaimant && !raffle.prizeClaimed ? (
              <button
                className="btn btn-primary w-full"
                onClick={() => claimPrize(raffle.id)}
                type="button"
              >
                <Gift aria-hidden size={17} /> Claim the NFT
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

            {raffle.prizeClaimed && isPrizeClaimant ? (
              <p className="rounded-2xl bg-[var(--grass-wash)] p-3 text-center text-sm font-bold text-[#0d6b45]">
                <Check aria-hidden className="inline" size={15} /> NFT claimed
                and in your wallet
              </p>
            ) : null}

            {!isPrizeClaimant && owed === 0n ? (
              <p className="text-center text-sm text-[var(--ink-2)]">
                {mine > 0
                  ? "None of your tickets were drawn this time."
                  : "You held no tickets in this raffle."}
              </p>
            ) : null}
          </div>
        </>
      ) : null}
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
