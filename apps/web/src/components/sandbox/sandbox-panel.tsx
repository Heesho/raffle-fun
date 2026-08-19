"use client";

import {
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
import { SANDBOX_USDC } from "@/lib/sandbox/adapter";
import {
  canEnableRefunds,
  canRequestDraw,
  entriesOwnedBy,
  ENTRY_PRICE,
  isOpen,
  MAX_UINT128,
  ticketContainingEntry,
  ticketsOwnedBy,
  reserveMet,
  VRF_FEE,
  type SandboxRaffle,
} from "@/lib/sandbox/engine";
import { useSandbox } from "@/lib/sandbox/store";

const amount = (value: bigint) =>
  formatTokenAmount(value, SANDBOX_USDC.decimals, SANDBOX_USDC.symbol);

export function SandboxPanel({ raffle }: { readonly raffle: SandboxRaffle }) {
  const { sandbox, error, clearError, ...actions } = useSandbox();
  const now = useNowMs();
  if (sandbox === undefined || now === undefined) return null;
  const open = isOpen(raffle, now);
  const mine = entriesOwnedBy(raffle, sandbox.player);

  return (
    <>
      {open ? (
        <BuyPanel raffle={raffle} mine={mine} />
      ) : (
        <SettlePanel raffle={raffle} mine={mine} now={now} />
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
  readonly mine: bigint;
}) {
  const { sandbox, buyEntries } = useSandbox();
  const [entryCountText, setEntryCountText] = useState("20");
  if (sandbox === undefined) return null;
  const valid = /^[1-9]\d*$/.test(entryCountText);
  const entryCount = valid ? BigInt(entryCountText) : 0n;
  const withinRange =
    entryCount > 0n && entryCount <= MAX_UINT128 - raffle.totalEntries;
  const gross = withinRange ? ENTRY_PRICE * entryCount : 0n;
  const projectedFee = ((raffle.unsettledPot + gross) * 5n) / 100n;
  const oddsDenominator = raffle.totalEntries + entryCount;
  const oddsBps =
    withinRange && oddsDenominator > 0n
      ? ((mine + entryCount) * 10_000n) / oddsDenominator
      : 0n;
  const affordable = withinRange && sandbox.wallet.usdc >= gross;

  function bump(delta: bigint) {
    const next = entryCount + delta;
    setEntryCountText((next < 1n ? 1n : next).toString());
  }

  return (
    <section className="card p-6">
      <p className="eyebrow">Your action</p>
      <h2 className="mt-2 text-2xl">Buy entries</h2>
      <p className="mt-2 text-sm leading-6 text-[var(--ink-2)]">
        One purchase mints one transferable ticket containing every $1 entry in
        the range.
      </p>
      <div className="mt-5">
        <span className="field-label" id="sandbox-entry-count">
          Entries ($1 each)
        </span>
        <div className="flex items-center gap-2">
          <button
            aria-label="One fewer entry"
            className="btn btn-outline !size-12 !min-h-0 shrink-0 !p-0"
            disabled={entryCount <= 1n}
            onClick={() => bump(-1n)}
            type="button"
          >
            <Minus aria-hidden size={18} />
          </button>
          <input
            aria-labelledby="sandbox-entry-count"
            className="input numeric !h-12 text-center !text-lg !font-extrabold"
            inputMode="numeric"
            onChange={(event) => setEntryCountText(event.target.value)}
            pattern="[0-9]*"
            type="text"
            value={entryCountText}
          />
          <button
            aria-label="One more entry"
            className="btn btn-outline !size-12 !min-h-0 shrink-0 !p-0"
            disabled={!withinRange}
            onClick={() => bump(1n)}
            type="button"
          >
            <Plus aria-hidden size={18} />
          </button>
        </div>
      </div>
      <dl className="mt-5 space-y-2 text-sm">
        <Row label="Total paid" strong value={amount(gross)} />
        <Row label="Projected 5% fee" value={amount(projectedFee)} />
        <Row label="Your odds after" value={`${Number(oddsBps) / 100}%`} />
        <Row label="Ticket NFTs minted" value="1" />
      </dl>
      <div className="perforation my-5" />
      <button
        className="btn btn-primary w-full"
        disabled={!affordable}
        onClick={() => buyEntries(raffle.id, entryCount)}
        type="button"
      >
        <ShoppingBag aria-hidden size={17} />
        {!withinRange
          ? "Enter a valid amount"
          : affordable
            ? `Buy ${entryCount.toString()} entr${entryCount === 1n ? "y" : "ies"}`
            : "Not enough USDC"}
      </button>
    </section>
  );
}

function SettlePanel({
  raffle,
  mine,
  now,
}: {
  readonly raffle: SandboxRaffle;
  readonly mine: bigint;
  readonly now: number;
}) {
  const [winningTicketIdText, setWinningTicketIdText] = useState("");
  const [refundTicketIdsText, setRefundTicketIdsText] = useState("");
  const {
    sandbox,
    requestDraw,
    enableRefunds,
    refundTickets,
    settleWinningTicket,
    redeemWinningTicket,
    releaseSponsorPrize,
    releaseSponsorProceeds,
    releaseProtocolFees,
  } = useSandbox();
  if (sandbox === undefined) return null;

  const drawing = raffle.status === "DRAWING";
  const refunding = raffle.status === "REFUNDING";
  const successful =
    raffle.status === "NFT_WON" || raffle.status === "CASH_WON";
  const winningTicket =
    raffle.winningTicketId !== null
      ? raffle.tickets.find((ticket) => ticket.id === raffle.winningTicketId)
      : raffle.winningEntry === null
        ? undefined
        : ticketContainingEntry(raffle, raffle.winningEntry);
  const ownsWinning =
    winningTicket !== undefined &&
    !winningTicket.burned &&
    winningTicket.owner.toLowerCase() === sandbox.player.toLowerCase();
  const sponsorPrizeAvailable =
    !raffle.prizeClaimed && (raffle.status === "CASH_WON" || refunding);
  const refundableTickets = refunding
    ? ticketsOwnedBy(raffle, sandbox.player)
    : [];
  const winningTicketId = /^[1-9]\d*$/.test(winningTicketIdText)
    ? BigInt(winningTicketIdText)
    : undefined;
  const refundTicketIds = refundTicketIdsText
    .split(",")
    .map((value) => value.trim())
    .filter((value) => /^[1-9]\d*$/.test(value))
    .map(BigInt);
  const refundProofValid =
    refundTicketIds.length > 0 &&
    refundTicketIds.length <= 100 &&
    refundTicketIds.length ===
      refundTicketIdsText.split(",").filter((value) => value.trim() !== "")
        .length &&
    new Set(refundTicketIds.map(String)).size === refundTicketIds.length;

  return (
    <section className="card p-6">
      <p className="eyebrow">Settlement</p>

      {canRequestDraw(raffle, now) ? (
        <>
          <h2 className="mt-2 text-2xl">The sale has closed</h2>
          <p className="mt-3 text-sm leading-6 text-[var(--ink-2)]">
            Anyone can pay Chainlink VRF&apos;s native fee and request the
            single draw.
          </p>
          <dl className="mt-4 space-y-2 text-sm">
            <Row label="Entries" value={raffle.totalEntries.toString()} />
            <Row label="Your entries" value={mine.toString()} />
            <Row
              label="Randomness fee"
              value={formatTokenAmount(VRF_FEE, 18, "ETH")}
            />
            <Row
              label="Branch if drawn now"
              strong
              value={
                reserveMet(raffle)
                  ? "NFT to winning entry"
                  : "80% gross cash to winner · sponsor gets NFT + 15%"
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

      {drawing ? (
        <>
          <h2 className="mt-2 text-2xl">Waiting on Chainlink VRF</h2>
          <p className="mt-3 flex items-center gap-2 text-sm font-bold">
            <LoaderCircle aria-hidden className="animate-spin" size={17} />
            The callback stores one winning entry and never searches tickets.
          </p>
        </>
      ) : null}

      {canEnableRefunds(raffle, sandbox.player, now) ? (
        <button
          className="btn btn-outline mt-5 w-full"
          onClick={() => enableRefunds(raffle.id)}
          type="button"
        >
          <Undo2 aria-hidden size={17} />
          {raffle.totalEntries === 0n
            ? "Finalize empty raffle"
            : "Enable ticket refunds"}
        </button>
      ) : null}

      {successful ? (
        <>
          <h2 className="mt-2 text-2xl">
            {ownsWinning
              ? "One of your entries won!"
              : `Entry #${raffle.winningEntry?.toString()} won`}
          </h2>
          <div className="mt-4 rounded-2xl bg-[var(--paper-sunk)] p-4 text-sm">
            <p className="flex items-center gap-2 font-bold">
              <Trophy aria-hidden size={16} />
              {raffle.winnerRedeemed
                ? "Redeemed by:"
                : "Current ticket owner:"}{" "}
              {winningTicket?.owner.slice(0, 8)}…
            </p>
            <p className="mt-2 text-[var(--ink-2)]">
              {raffle.winnerRedeemed
                ? "The owner surrendered the winning ticket and received the prize atomically."
                : raffle.settlementComplete
                  ? "Settlement allocated every balance without burning the winning ticket. It remains a transferable bearer claim until its owner redeems."
                  : "Anyone can verify the winning ticket and allocate balances without burning it. Its owner can settle and redeem atomically."}
            </p>
            {winningTicket !== undefined && !raffle.winnerRedeemed ? (
              <button
                className="mt-3 font-bold underline"
                onClick={() =>
                  setWinningTicketIdText(winningTicket.id.toString())
                }
                type="button"
              >
                Use indexed ticket {winningTicket.id.toString()}
              </button>
            ) : null}
          </div>
          {!raffle.winnerRedeemed ? (
            <label className="mt-4 block">
              <span className="field-label">Winning ticket ID</span>
              <input
                className="input numeric"
                onChange={(event) => setWinningTicketIdText(event.target.value)}
                placeholder="For example: 3"
                value={winningTicketIdText}
              />
            </label>
          ) : null}
        </>
      ) : null}

      {refunding ? (
        <>
          <h2 className="mt-2 text-2xl">Refunds are open</h2>
          <p className="mt-3 text-sm leading-6 text-[var(--ink-2)]">
            Each ticket refunds every $1 entry in its stored range.
          </p>
          <label className="mt-4 block">
            <span className="field-label">
              Ticket IDs (comma-separated, max 100)
            </span>
            <input
              className="input numeric"
              onChange={(event) => setRefundTicketIdsText(event.target.value)}
              placeholder="For example: 1, 3, 4"
              value={refundTicketIdsText}
            />
            {refundableTickets.length > 0 ? (
              <button
                className="field-hint font-bold underline"
                onClick={() =>
                  setRefundTicketIdsText(
                    refundableTickets
                      .slice(0, 100)
                      .map((ticket) => ticket.id.toString())
                      .join(", "),
                  )
                }
                type="button"
              >
                Use your {Math.min(100, refundableTickets.length)} indexed
                ticket{refundableTickets.length === 1 ? "" : "s"}
              </button>
            ) : null}
          </label>
        </>
      ) : null}

      <div className="mt-5 grid gap-2">
        {ownsWinning && winningTicketId !== undefined ? (
          <button
            className="btn btn-primary w-full"
            onClick={() => redeemWinningTicket(raffle.id, winningTicketId)}
            type="button"
          >
            <Gift aria-hidden size={17} />
            Redeem winning ticket
          </button>
        ) : null}
        {successful &&
        !raffle.settlementComplete &&
        winningTicketId !== undefined ? (
          <button
            className="btn btn-outline w-full"
            onClick={() => settleWinningTicket(raffle.id, winningTicketId)}
            type="button"
          >
            <Gift aria-hidden size={17} />
            Settle without redeeming
          </button>
        ) : null}
        {refundableTickets.length > 0 && refundProofValid ? (
          <button
            className="btn btn-primary w-full"
            onClick={() => refundTickets(raffle.id, refundTicketIds)}
            type="button"
          >
            <CircleDollarSign aria-hidden size={17} /> Claim ticket refunds
          </button>
        ) : null}
        {sponsorPrizeAvailable ? (
          <button
            className="btn btn-primary w-full"
            onClick={() => releaseSponsorPrize(raffle.id)}
            type="button"
          >
            <Gift aria-hidden size={17} /> Release NFT to sponsor
          </button>
        ) : null}
        {raffle.sponsorProceeds > 0n ? (
          <button
            className="btn btn-primary w-full"
            onClick={() => releaseSponsorProceeds(raffle.id)}
            type="button"
          >
            <CircleDollarSign aria-hidden size={17} /> Release{" "}
            {amount(raffle.sponsorProceeds)} to sponsor
          </button>
        ) : null}
        {raffle.protocolFees > 0n ? (
          <button
            className="btn btn-primary w-full"
            onClick={() => releaseProtocolFees(raffle.id)}
            type="button"
          >
            <CircleDollarSign aria-hidden size={17} /> Release{" "}
            {amount(raffle.protocolFees)} to treasury
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
