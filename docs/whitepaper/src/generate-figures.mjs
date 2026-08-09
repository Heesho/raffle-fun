#!/usr/bin/env node

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { buildFacts } from "./protocol-facts.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const output = resolve(here, "../assets/diagrams");
const facts = buildFacts();

const palette = {
  ink: "#10143a",
  indigo: "#1e2a9b",
  violet: "#7b3fe4",
  pink: "#d31d8b",
  yellow: "#ffd84d",
  sky: "#5aa9ff",
  green: "#22b573",
  cream: "#fff8e7",
  palePink: "#fce9f5",
  paleBlue: "#e9eefc",
  paper: "#fbfaff",
  white: "#ffffff",
  muted: "#676c94",
  line: "#d9daea",
  danger: "#c8213f",
};

function esc(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function wrap(text, max = 24) {
  const words = String(text).split(/\s+/);
  const lines = [];
  let current = "";
  for (const word of words) {
    const next = current ? `${current} ${word}` : word;
    if (next.length > max && current) {
      lines.push(current);
      current = word;
    } else {
      current = next;
    }
  }
  if (current) lines.push(current);
  return lines;
}

function textBlock(text, x, y, options = {}) {
  const {
    anchor = "middle",
    size = 16,
    weight = 700,
    color = palette.ink,
    max = 24,
    lineHeight = 20,
  } = options;
  const lines = wrap(text, max);
  return `<text x="${x}" y="${y}" text-anchor="${anchor}" font-family="Inter,Arial,sans-serif" font-size="${size}" font-weight="${weight}" fill="${color}">${lines
    .map(
      (line, index) =>
        `<tspan x="${x}" dy="${index === 0 ? 0 : lineHeight}">${esc(line)}</tspan>`,
    )
    .join("")}</text>`;
}

function box({ x, y, w, h, title, body = "", fill = palette.white, accent }) {
  const stroke = accent || palette.line;
  const bodyLines = body ? wrap(body, Math.max(18, Math.floor(w / 9))) : [];
  const titleLines = wrap(title, Math.max(16, Math.floor(w / 8.5)));
  let titleY = y + 30;
  const titleSvg = `<text x="${x + w / 2}" y="${titleY}" text-anchor="middle" font-family="Nunito,Arial,sans-serif" font-size="16" font-weight="800" fill="${palette.ink}">${titleLines
    .map(
      (line, index) =>
        `<tspan x="${x + w / 2}" dy="${index === 0 ? 0 : 19}">${esc(line)}</tspan>`,
    )
    .join("")}</text>`;
  const bodyY = titleY + titleLines.length * 19 + 6;
  const bodySvg = body
    ? `<text x="${x + w / 2}" y="${bodyY}" text-anchor="middle" font-family="Inter,Arial,sans-serif" font-size="12.5" font-weight="500" fill="${palette.muted}">${bodyLines
        .map(
          (line, index) =>
            `<tspan x="${x + w / 2}" dy="${index === 0 ? 0 : 16}">${esc(line)}</tspan>`,
        )
        .join("")}</text>`
    : "";
  return `<g><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="16" fill="${fill}" stroke="${stroke}" stroke-width="2"/><rect x="${x}" y="${y}" width="8" height="${h}" rx="4" fill="${stroke}"/>${titleSvg}${bodySvg}</g>`;
}

function arrow(x1, y1, x2, y2, label = "", dashed = false) {
  const line = `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${palette.indigo}" stroke-width="2.5" ${dashed ? 'stroke-dasharray="7 6"' : ""} marker-end="url(#arrow)"/>`;
  const lx = (x1 + x2) / 2;
  const ly = (y1 + y2) / 2 - 7;
  const labelSvg = label
    ? `<text x="${lx}" y="${ly}" text-anchor="middle" font-family="Inter,Arial,sans-serif" font-size="11" font-weight="700" fill="${palette.indigo}">${esc(label)}</text>`
    : "";
  return `${line}${labelSvg}`;
}

function svg(title, description, body, height = 390) {
  return `<svg xmlns="http://www.w3.org/2000/svg" role="img" aria-labelledby="title desc" viewBox="0 0 720 ${height}">
  <title id="title">${esc(title)}</title>
  <desc id="desc">${esc(description)}</desc>
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="${palette.indigo}"/></marker>
    <linearGradient id="brand" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${palette.indigo}"/><stop offset="0.55" stop-color="${palette.pink}"/><stop offset="1" stop-color="${palette.yellow}"/></linearGradient>
  </defs>
  <rect width="720" height="${height}" rx="22" fill="${palette.paper}"/>
  ${body}
  <text x="24" y="${height - 16}" font-family="Inter,Arial,sans-serif" font-size="10.5" fill="${palette.muted}">Solid arrows: calls or asset movement. Dashed arrows: reads, conditions, or external dependencies.</text>
</svg>`;
}

function horizontalFlow(title, description, items, options = {}) {
  const height = options.height || 300;
  const margin = 22;
  const gap = 18;
  const y = options.y || 82;
  const h = options.boxHeight || 132;
  const w = (720 - margin * 2 - gap * (items.length - 1)) / items.length;
  let body = textBlock(title, 24, 38, {
    anchor: "start",
    size: 21,
    weight: 800,
    max: 70,
  });
  items.forEach((item, index) => {
    const x = margin + index * (w + gap);
    body += box({ x, y, w, h, ...item });
    if (index < items.length - 1) {
      body += arrow(x + w, y + h / 2, x + w + gap - 2, y + h / 2, item.arrow);
    }
  });
  if (options.note) {
    body += textBlock(options.note, 360, y + h + 42, {
      size: 12.5,
      weight: 600,
      color: palette.muted,
      max: 90,
      lineHeight: 17,
    });
  }
  return svg(title, description, body, height);
}

function grid(title, description, items, options = {}) {
  const columns = options.columns || 2;
  const height = options.height || 430;
  const margin = 24;
  const gapX = 18;
  const gapY = 18;
  const y0 = 70;
  const rows = Math.ceil(items.length / columns);
  const w = (720 - margin * 2 - gapX * (columns - 1)) / columns;
  const available = height - y0 - 46;
  const h = (available - gapY * (rows - 1)) / rows;
  let body = textBlock(title, 24, 36, {
    anchor: "start",
    size: 21,
    weight: 800,
    max: 70,
  });
  items.forEach((item, index) => {
    const col = index % columns;
    const row = Math.floor(index / columns);
    body += box({
      x: margin + col * (w + gapX),
      y: y0 + row * (h + gapY),
      w,
      h,
      ...item,
    });
  });
  return svg(title, description, body, height);
}

const E = facts.examples;
const C = facts.display;

const figures = {
  "01-at-a-glance.svg": horizontalFlow(
    "raffle.fun at a glance",
    "A sponsor escrows one NFT, buyers receive bearer tickets, one Pyth Entropy request resolves the raffle, and claimants redeem assets.",
    [
      {
        title: "Create",
        body: "Sponsor chooses terms",
        fill: palette.palePink,
        accent: palette.pink,
      },
      {
        title: "Escrow",
        body: "Exact NFT enters raffle",
        fill: palette.cream,
        accent: palette.yellow,
      },
      {
        title: "Sell",
        body: "USDC in, ticket NFTs out",
        fill: palette.paleBlue,
        accent: palette.sky,
      },
      {
        title: "Draw",
        body: "One Entropy request",
        fill: palette.palePink,
        accent: palette.violet,
      },
      {
        title: "Redeem",
        body: "Burn ticket or pull claim",
        fill: palette.cream,
        accent: palette.green,
      },
    ],
    {
      height: 300,
      boxHeight: 128,
      note: "If the request or callback deadline expires, each current ticket owner may burn tickets for exact refunds.",
    },
  ),
  "02-participant-role-map.svg": grid(
    "Participant role map",
    "The sponsor, ticket holders, requester, recovery recipient, treasury, factory owner, Pyth, and read layers have separate powers.",
    [
      {
        title: "Sponsor",
        body: "Deposits prize; sets price, threshold, dates, recovery recipient",
        accent: palette.pink,
        fill: palette.palePink,
      },
      {
        title: "Ticket holder",
        body: "Owns transferable bearer claim; may redeem winner or refund",
        accent: palette.sky,
        fill: palette.paleBlue,
      },
      {
        title: "Draw requester",
        body: "Anyone; pays current Entropy fee",
        accent: palette.violet,
        fill: palette.white,
      },
      {
        title: "Recovery recipient",
        body: "Claims NFT after cash, refund, or empty result",
        accent: palette.yellow,
        fill: palette.cream,
      },
      {
        title: "Factory owner",
        body: "Future pause and treasury only",
        accent: palette.indigo,
        fill: palette.white,
      },
      {
        title: "Pyth and read layers",
        body: "Pyth calls back; Lens, SDK, subgraph, frontend help users",
        accent: palette.green,
        fill: palette.white,
      },
    ],
    { height: 500, columns: 2 },
  ),
  "03-atomic-creation.svg": horizontalFlow(
    "Atomic creation and prize escrow",
    "The factory deploys, registers, deposits, and verifies a raffle in one reverting transaction.",
    [
      {
        title: "Validate",
        body: "Prize, terms, dates, addresses",
        accent: palette.indigo,
      },
      {
        title: "CREATE",
        body: "Independent Raffle constructor",
        accent: palette.violet,
      },
      {
        title: "Register",
        body: "Assign ID and canonical address",
        accent: palette.sky,
      },
      {
        title: "Deposit",
        body: "Factory-operated safe NFT transfer",
        accent: palette.pink,
      },
      { title: "Verify", body: "ownerOf and Active", accent: palette.green },
    ],
    {
      height: 300,
      note: "Any failure rolls back the deployment, registry writes, event, and NFT movement.",
    },
  ),
  "04-lifecycle.svg": grid(
    "Complete raffle lifecycle",
    "The seven status values and their allowed forward transitions.",
    [
      {
        title: "AwaitingPrize",
        body: "Constructor exists inside atomic creation",
        accent: palette.yellow,
        fill: palette.cream,
      },
      {
        title: "Active",
        body: "Sale window and request grace",
        accent: palette.sky,
        fill: palette.paleBlue,
      },
      {
        title: "Drawing",
        body: "One Entropy sequence pending",
        accent: palette.violet,
        fill: palette.palePink,
      },
      {
        title: "NftWon",
        body: "Winning bearer burns for prize",
        accent: palette.green,
      },
      {
        title: "CashWon",
        body: "Winning bearer burns for cash",
        accent: palette.pink,
      },
      {
        title: "Refunding",
        body: "Each bearer burns for ticket price",
        accent: palette.indigo,
      },
      {
        title: "Closed",
        body: "Zero sales; recovery recipient claims prize",
        accent: palette.muted,
      },
    ],
    { height: 620, columns: 2 },
  ),
  "05-sale-deadline-timeline.svg": horizontalFlow(
    "Sale and deadline timeline",
    "The sale starts inclusively, ends exclusively, then a three-day request window and two-day callback timeout bound oracle liveness.",
    [
      {
        title: "startTime",
        body: "Purchase allowed at exact start",
        accent: palette.green,
      },
      {
        title: "Sale",
        body: `At most ${C.maxSaleDurationDays} days`,
        accent: palette.sky,
      },
      {
        title: "endTime",
        body: "No purchase; draw may begin",
        accent: palette.yellow,
      },
      {
        title: "Request grace",
        body: `${C.requestGraceDays} days; deadline excluded`,
        accent: palette.violet,
      },
      {
        title: "Callback wait",
        body: `${C.callbackTimeoutDays} days from request`,
        accent: palette.pink,
      },
    ],
    {
      height: 315,
      note: "At either liveness deadline, enableRefunds becomes valid. At the callback boundary, callback and timeout may race; the first included transaction wins.",
    },
  ),
  "06-ticket-ownership.svg": horizontalFlow(
    "Bearer ticket ownership through time",
    "Tickets remain transferable in every status until the owner burns them for the award or refund.",
    [
      {
        title: "Maya buys #12",
        body: "Maya owns the bearer claim",
        accent: palette.sky,
      },
      {
        title: "Transfer to Leo",
        body: "Ownership and future right move",
        accent: palette.violet,
      },
      {
        title: "Draw or refund",
        body: "No snapshot and no freeze",
        accent: palette.yellow,
      },
      {
        title: "Leo transfers",
        body: "Still allowed before redemption",
        accent: palette.pink,
      },
      {
        title: "Current owner burns",
        body: "Asset paid; ticket ceases to exist",
        accent: palette.green,
      },
    ],
    {
      height: 315,
      note: "Approvals may transfer a ticket, but only the actual owner can call the redemption functions.",
    },
  ),
  "07-randomness-sequence.svg": horizontalFlow(
    "Randomness request and callback sequence",
    "A requester pays Pyth, the raffle stores one sequence, and a later authenticated callback records the result.",
    [
      {
        title: "Requester",
        body: "Reads fee and calls requestDraw",
        accent: palette.sky,
      },
      {
        title: "Raffle",
        body: "Enters Drawing; sets in-flight guard",
        accent: palette.indigo,
      },
      {
        title: "Pyth Entropy v2",
        body: "Accepts fee and returns sequence",
        accent: palette.violet,
      },
      { title: "Callback", body: "Separate transaction", accent: palette.pink },
      {
        title: "Storage result",
        body: "Winner, fees, liabilities, status",
        accent: palette.green,
      },
    ],
    {
      height: 315,
      note: "Wrong, duplicate, stale, in-flight, and post-failure callbacks emit an ignored event and do not settle.",
    },
  ),
  "08-winner-selection.svg": horizontalFlow(
    "Winner selection",
    "The 256-bit random value is mapped into the complete sold ticket range.",
    [
      {
        title: "randomNumber",
        body: "Authenticated bytes32 value",
        accent: palette.violet,
      },
      {
        title: "Modulo",
        body: "randomNumber % totalTickets",
        accent: palette.pink,
      },
      { title: "+ 1", body: "Shift zero-based result", accent: palette.yellow },
      {
        title: "Ticket ID",
        body: "1 through totalTickets inclusive",
        accent: palette.green,
      },
    ],
    {
      height: 300,
      note: "One ticket always selects #1. The final sold ticket is reachable. Modulo bias is mathematically nonzero for most ticket counts.",
    },
  ),
  "09-outcome-comparison.svg": grid(
    "Outcome comparison",
    "The protocol distinguishes successful randomness, failed randomness, and zero-sales closure.",
    [
      {
        title: "NftWon",
        body: `Threshold met; ${C.protocolFeePercent} fee; winner burns for NFT; sponsor gets post-fee USDC`,
        accent: palette.green,
      },
      {
        title: "CashWon",
        body: `Threshold missed; ${C.protocolFeePercent} fee; winner burns for ${C.cashWinnerPercent} of post-fee pot; recovery recipient gets NFT`,
        accent: palette.pink,
      },
      {
        title: "Refunding",
        body: "No fee; no winner; each current holder burns tickets for exact price; recovery recipient gets NFT",
        accent: palette.indigo,
      },
      {
        title: "Closed",
        body: "Zero sales; no request and no quote liability; recovery recipient gets NFT",
        accent: palette.muted,
      },
    ],
    { height: 430, columns: 2 },
  ),
  "10-nft-awarded-flow.svg": horizontalFlow(
    "NFT-awarded money flow",
    "With 120 tickets at 10.00 USDC, the NFT winner receives the prize and quote proceeds split between sponsor and treasury.",
    [
      {
        title: "Gross sales",
        body: `${E.thresholdMet.gross} USDC`,
        accent: palette.sky,
      },
      {
        title: "Treasury",
        body: `${E.thresholdMet.fee} USDC fee`,
        accent: palette.pink,
      },
      {
        title: "Sponsor",
        body: `${E.thresholdMet.distributable} USDC`,
        accent: palette.yellow,
      },
      {
        title: "Winning bearer",
        body: "Burns ticket for Pixel Passport #42",
        accent: palette.green,
      },
    ],
    {
      height: 300,
      note: "All values are generated from compiled fee constants using six-decimal raw units.",
    },
  ),
  "11-cash-fallback-flow.svg": horizontalFlow(
    "Cash-fallback money flow",
    "With 80 tickets at 10.00 USDC, successful randomness produces one cash winner and no general refunds.",
    [
      {
        title: "Gross sales",
        body: `${E.cashFallback.gross} USDC`,
        accent: palette.sky,
      },
      {
        title: "Treasury",
        body: `${E.cashFallback.fee} USDC`,
        accent: palette.pink,
      },
      {
        title: "Winner",
        body: `${E.cashFallback.winnerCash} USDC`,
        accent: palette.green,
      },
      {
        title: "Sponsor",
        body: `${E.cashFallback.sponsorCash} USDC`,
        accent: palette.yellow,
      },
      {
        title: "Recovery wallet",
        body: "Claims the NFT",
        accent: palette.violet,
      },
    ],
    {
      height: 320,
      note: `${C.cashWinnerPercent} is applied to the post-fee pot of ${E.cashFallback.distributable} USDC, not gross sales.`,
    },
  ),
  "12-missing-request-refund.svg": horizontalFlow(
    "Missing-request refund flow",
    "If no draw request succeeds before the grace deadline, anyone enables refunds and bearers redeem exactly.",
    [
      {
        title: "Sale ends",
        body: "80 tickets; 800.00 USDC",
        accent: palette.sky,
      },
      {
        title: "No accepted request",
        body: `${C.requestGraceDays}-day grace expires`,
        accent: palette.danger,
      },
      {
        title: "enableRefunds",
        body: "Anyone moves pot to refund liability",
        accent: palette.indigo,
      },
      {
        title: "Owners burn tickets",
        body: "10.00 USDC per ticket",
        accent: palette.green,
      },
      {
        title: "Recovery wallet",
        body: "Claims the NFT",
        accent: palette.violet,
      },
    ],
    {
      height: 320,
      note: "No protocol fee, sponsor proceeds, or selected winner exists in this branch.",
    },
  ),
  "13-timeout-refund.svg": horizontalFlow(
    "Callback-timeout refund flow",
    "If one request succeeds but no valid callback wins before timeout finalization, the same bearer refund branch begins.",
    [
      {
        title: "Request accepted",
        body: "Tickets remain transferable",
        accent: palette.violet,
      },
      {
        title: "No valid callback",
        body: `${C.callbackTimeoutDays} days pass`,
        accent: palette.danger,
      },
      {
        title: "enableRefunds",
        body: "First valid terminal transaction",
        accent: palette.indigo,
      },
      {
        title: "Owners burn tickets",
        body: "Exact refund to chosen destination",
        accent: palette.green,
      },
      {
        title: "Late callback",
        body: "Ignored after Refunding",
        accent: palette.muted,
      },
    ],
    {
      height: 320,
      note: "At the exact deadline, the callback and timeout transaction may both be valid before inclusion. Block ordering decides which executes first.",
    },
  ),
  "14-refund-redemption.svg": horizontalFlow(
    "Refund redemption sequence",
    "Refunds are bounded bearer burns, not batch credits to a frozen ownership snapshot.",
    [
      {
        title: "Current owner",
        body: "Chooses 1 to 100 owned IDs",
        accent: palette.sky,
      },
      {
        title: "Validate",
        body: "Refunding, owner, unique existing tickets",
        accent: palette.indigo,
      },
      {
        title: "Burn tickets",
        body: "Bearer rights are consumed",
        accent: palette.pink,
      },
      {
        title: "Reduce liability",
        body: "ticketPrice x quantity",
        accent: palette.yellow,
      },
      {
        title: "Exact transfer",
        body: "USDC to chosen destination",
        accent: palette.green,
      },
    ],
    {
      height: 320,
      note: "Any bad ID or failed outgoing token transfer reverts the entire batch, restoring burns and liability.",
    },
  ),
  "15-pull-claim-architecture.svg": grid(
    "Claims and bearer redemptions",
    "Sponsor and treasury proceeds are pull claims; winning and refund rights are consumed through ticket burns.",
    [
      {
        title: "claimQuote(to)",
        body: "Sponsor or treasury chooses a nonzero destination",
        accent: palette.indigo,
      },
      {
        title: "claimQuoteFor(account)",
        body: "Anyone may call; payment can only go to account itself",
        accent: palette.sky,
      },
      {
        title: "redeemWinningTicket(to)",
        body: "Actual owner burns winning ticket for NFT or cash",
        accent: palette.green,
      },
      {
        title: "redeemRefundTickets(ids,to)",
        body: "Actual owner burns up to 100 refundable tickets",
        accent: palette.pink,
      },
      {
        title: "claimSponsorPrize(to)",
        body: "Fixed recovery recipient chooses safe NFT destination",
        accent: palette.yellow,
      },
      {
        title: "Retry on failure",
        body: "Revert preserves ticket, claim, liability, and prize state",
        accent: palette.violet,
      },
    ],
    { height: 500, columns: 2 },
  ),
  "16-contract-architecture.svg": grid(
    "Contract architecture",
    "One factory constructor-deploys independent raffles; one read-only lens aggregates authenticated state.",
    [
      {
        title: "RaffleFactory",
        body: "Immutable USDC, Entropy, callback gas; registry; future policy",
        accent: palette.indigo,
        fill: palette.paleBlue,
      },
      {
        title: "Independent Raffle",
        body: "Own storage, prize, tickets, deadlines, liabilities; no owner",
        accent: palette.pink,
        fill: palette.palePink,
      },
      {
        title: "RaffleLens",
        body: "Read-only, factory-authenticated, batch limit 64",
        accent: palette.sky,
      },
      {
        title: "Pyth Entropy v2",
        body: "Dynamic fee, sequence, authenticated callback",
        accent: palette.violet,
      },
      {
        title: "USDC and prize",
        body: "External token contracts remain dependencies",
        accent: palette.yellow,
        fill: palette.cream,
      },
      {
        title: "SDK, subgraph, web",
        body: "Convenience and indexing; never settlement authority",
        accent: palette.green,
      },
    ],
    { height: 500, columns: 2 },
  ),
  "17-onchain-offchain.svg": grid(
    "Onchain versus offchain",
    "Settlement state is onchain while access, presentation, indexing, metadata, and legal interpretation remain external.",
    [
      {
        title: "Onchain authority",
        body: "Configuration, escrow owner, ticket owner, deadlines, status, winner, liabilities, claims",
        accent: palette.indigo,
        fill: palette.paleBlue,
      },
      {
        title: "Offchain access",
        body: "Frontend, RPC, wallet, SDK, subgraph, notifications",
        accent: palette.sky,
      },
      {
        title: "External services",
        body: "Pyth provider and keeper, Base sequencer and validators, token issuers",
        accent: palette.violet,
      },
      {
        title: "External meaning",
        body: "Metadata, intellectual property, tax, gaming, sanctions, age and consumer law",
        accent: palette.pink,
        fill: palette.palePink,
      },
    ],
    { height: 420, columns: 2 },
  ),
  "18-owner-matrix.svg": grid(
    "Factory owner: can and cannot",
    "Factory ownership changes only future creation policy and cannot administer existing raffles.",
    [
      {
        title: "Can",
        body: "Pause or resume future creation; set treasury for future raffles; begin two-step ownership transfer",
        accent: palette.green,
        fill: "#e3f7ee",
      },
      {
        title: "Cannot",
        body: "Change existing price, threshold, dates, token, recipient, treasury, winner, status, claim, or prize",
        accent: palette.danger,
        fill: "#fdeaee",
      },
      {
        title: "Cannot",
        body: "Pause, upgrade, rescue, reroll, settle, or refund an existing raffle",
        accent: palette.danger,
        fill: "#fdeaee",
      },
      {
        title: "Incident response",
        body: "Warn users, hide writes, pause new creation, and deploy a new factory after review",
        accent: palette.indigo,
        fill: palette.paleBlue,
      },
    ],
    { height: 420, columns: 2 },
  ),
  "19-recovery-envelope.svg": grid(
    "Supported recovery envelope",
    "The internal recovery claim is conditional on honest, available token and chain behavior.",
    [
      {
        title: "Inside the envelope",
        body: "Honest ERC-721 ownership and safe transfer; exact non-rebasing USDC; functioning Base inclusion",
        accent: palette.green,
        fill: "#e3f7ee",
      },
      {
        title: "Bounded protocol paths",
        body: "Winner burn, refund burns, quote pulls, sponsor prize claim, protocol-owned claim helper",
        accent: palette.indigo,
        fill: palette.paleBlue,
      },
      {
        title: "Outside the envelope",
        body: "Issuer freeze or blacklist, malicious upgrade, dishonest reads, burned prize, lost keys, universal censorship",
        accent: palette.danger,
        fill: "#fdeaee",
      },
      {
        title: "No rescue",
        body: "Forced unrelated NFTs, direct surplus donations, or maliciously trapped assets cannot be swept",
        accent: palette.pink,
        fill: palette.palePink,
      },
    ],
    { height: 450, columns: 2 },
  ),
  "20-trust-dependency-map.svg": grid(
    "Trust and dependency map",
    "Protocol correctness depends on code, infrastructure, external assets, user keys, and legal-operational controls.",
    [
      {
        title: "Base",
        body: "Execution, ordering, inclusion, reorg and sequencer behavior",
        accent: palette.indigo,
      },
      {
        title: "Pyth Entropy",
        body: "Randomness correctness, provider, keeper, fees and callback availability",
        accent: palette.violet,
      },
      {
        title: "USDC issuer",
        body: "Transfers, balances, pause, blacklist and upgrade behavior",
        accent: palette.sky,
      },
      {
        title: "Prize contract",
        body: "ERC-165 report, ownerOf truth, safe transfers, metadata",
        accent: palette.pink,
      },
      {
        title: "User stack",
        body: "Wallet keys, RPC, frontend authenticity, transaction review",
        accent: palette.yellow,
        fill: palette.cream,
      },
      {
        title: "Operations and law",
        body: "Factory-owner Safe, monitoring, incident response, jurisdictional compliance",
        accent: palette.green,
      },
    ],
    { height: 500, columns: 2 },
  ),
  "21-worked-example.svg": grid(
    "Pixel Passport #42: all branches",
    "The central example uses a 10.00 USDC ticket, 100-ticket threshold, and six-decimal raw units.",
    [
      {
        title: "120 sold",
        body: `NFT winner; sponsor ${E.thresholdMet.distributable}; treasury ${E.thresholdMet.fee} USDC`,
        accent: palette.green,
      },
      {
        title: "80 sold + callback",
        body: `Cash winner ${E.cashFallback.winnerCash}; sponsor ${E.cashFallback.sponsorCash}; treasury ${E.cashFallback.fee} USDC`,
        accent: palette.pink,
      },
      {
        title: "80 sold + failure",
        body: `${E.failedDraw.totalRefunds} USDC total; each current bearer burns for ${E.failedDraw.refundPerTicket}`,
        accent: palette.indigo,
      },
      {
        title: "0 sold",
        body: "Sponsor may close early; anyone after end; recovery wallet claims NFT",
        accent: palette.muted,
      },
      {
        title: "Ticket #12 transfers",
        body: "Maya to Leo; then Noor may receive it; current owner at burn redeems",
        accent: palette.sky,
      },
      {
        title: "All numbers",
        body: "Illustrative names and assets; arithmetic generated from compiled constants",
        accent: palette.yellow,
        fill: palette.cream,
      },
    ],
    { height: 500, columns: 2 },
  ),
};

mkdirSync(output, { recursive: true });
for (const [name, content] of Object.entries(figures)) {
  writeFileSync(resolve(output, name), `${content}\n`);
}
console.log(
  `Generated ${Object.keys(figures).length} SVG figures in ${output}`,
);
