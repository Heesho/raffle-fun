# Web application

## Stack and routes

The app uses Next.js App Router, React, Tailwind CSS, Wagmi, Viem, TanStack Query,
GraphQL Request, and Zod.

| Route                | Purpose                                                              |
| -------------------- | -------------------------------------------------------------------- |
| `/`                  | discover, search, filter, active/resolved empty/error/loading states |
| `/create`            | NFT verification, exact economics, approval, create                  |
| `/raffle/[address]`  | live state, economics, buy/draw/close/claims                         |
| `/profile/[address]` | sponsored/positions plus live batch claimability                     |
| `/activity`          | indexed purchases, resolutions, and claims                           |
| `/docs`              | plain-language mechanic, examples, trust, risks                      |

## Configuration

Copy `apps/web/.env.example`. Base Sepolia is the default; Base and local Anvil are also supported. Every supplied value is
validated; empty optional endpoints remain unset. The chain deployment comes only from
`@raffle-fun/config`. If it is absent, writes are disabled and the UI explains why.

## Interactive preview

`NEXT_PUBLIC_DEMO_MODE` swaps the chain-backed app for a playable, offline
model of the protocol, so the product can be demonstrated before a deployment
and a subgraph exist.

| Value            | Behavior                                               |
| ---------------- | ------------------------------------------------------ |
| `auto` (default) | Preview only while `NEXT_PUBLIC_SUBGRAPH_URL` is unset |
| `on`             | Always preview                                         |
| `off`            | Never substitute simulated state                       |

`src/lib/sandbox/engine.ts` is a pure reducer mirroring
`packages/contracts/src/Raffle.sol`, covered by `engine.test.ts`:

- the advertised ticket price is the total paid; the aggregate 5% fee is allocated at resolution
- tickets are sequential ids from 1, owned by their recipient
- sales are uncapped and bounded only by `endTime`
- the sponsor may cancel only while zero tickets have sold
- settlement is two steps — `requestDraw` (paying the entropy fee), then a
  callback that picks `(random % totalTickets) + 1`
- **the callback moves no assets**; it credits pull claims, and the winner
  claims the NFT or their 80% afterwards

`store.tsx` holds the state outside React behind `useSyncExternalStore`,
persists it to `localStorage`, schedules the stand-in oracle callback, and
runs ambient buyers so open raffles move. Raffles the visitor sponsors are
excluded from ambient buying so the cancel-before-sales path stays reachable.

Sale windows are compressed to minutes and each open raffle offers a
skip-ahead control, so a visitor can watch a sale close, request the draw and
claim inside one sitting.

The preview presents as the real product — a connected account with balances
rather than demo badges — with a single disclosure in the footer stating that
balances, draws and prizes are simulated. Any build serving real users must
set `NEXT_PUBLIC_DEMO_MODE=off`; with a subgraph configured, `auto` already
does this. Outside preview mode there are no fake addresses, raffles, odds,
volume, or activity.

Prize artwork for the fixtures is vendored in `public/demo/` — see that
directory's README for provenance and the licensing caveat.

## Data authority

- **Subgraph:** lists, search, profile discovery, history, aggregates.
- **Direct chain:** registration, lifecycle state, outcome, price, threshold, sold
  count, claims, account ticket balance, quote-token verification, and current
  Entropy fee.

Immediately before a write, the app checks the wallet chain, rereads the lens/factory,
derives exact bigint amounts, and simulates. After a receipt it refreshes direct reads
and marks the index as catching up.

## Transaction behavior

The contracts and SDK accept any contract-backed ERC20. The official creation flow
enumerates the bounded verification registry and offers only currently verified
tokens with readable decimals. Public discovery and activity hide unverified-token
raffles by default. Profiles and direct links still render them with an explicit risk
warning; purchases require acknowledgement, while claims remain available.

For insufficient quote allowance, the app first simulates ordered `approve` and
`buyTickets` calls with `eth_simulateV1`, then requests an EIP-5792 wallet batch with
Viem's sequential fallback enabled. If batching fails before submission, it simulates
and confirms approval, rereads raffle state, and only then simulates/submits purchase.

Before purchase, the UI shows the exact gross payment, projected aggregate protocol
fee, and projected distributable pot. Because the fee is allocated only at resolution,
the projection can change as more tickets sell. Ticket sales remain open until the
fixed closing time even after the minimum threshold is reached.

## NFT metadata policy

Metadata is never HTML-rendered. JSON fields are bounded with Zod. Display URLs allow
HTTPS, local HTTP in development, or `ipfs://` transformed through a fixed HTTPS
gateway. Embedded credentials, script/data schemes, redirects, oversized declared
responses, and SVG images are rejected. Metadata and prize authenticity remain
untrusted even after safe display.

## Numerical safety

Contract amounts are bigint end to end. `parseQuoteAmount` accepts the selected
token's decimals, plain decimal strings, and rejects exponent notation, negatives,
grouping separators, and excess decimals. Settlement helpers calculate the aggregate
fee and payout splits with Solidity-equivalent floor rounding. The UI never combines
monetary values from different quote tokens.

## Design system

Tokens live at the top of `src/app/globals.css`, sampled from the brand exports in
`public/brand`: indigo ink `#1b2a9b`, hot pink `#ec2fa0`, sunshine `#ffd84d`, sky
`#5aa9ff`, on near-white paper with soft pink/blue gradient blooms. Display and body
text use Nunito via `next/font`.

Component classes (`.card`, `.btn`, `.input`, `.chip`, `.progress-*`) are declared
inside `@layer components` so Tailwind utilities still win — without that layer,
`.btn { display: inline-flex }` silently overrides `hidden` and `md:hidden`.

Ticket iconography is a dashed `.perforation` rule inside cards. The earlier
pseudo-element notches painted an opaque paper color and visibly leaked wherever a
card sat on a non-paper surface.

`ThresholdBar` keeps visual headroom past the minimum and marks the flip point — the
ticket count where the prize switches from the cash pot to the NFT. Sales beyond the
minimum remain visible as an overshoot segment instead of collapsing into a full bar.

## Accessibility and UX

The interface is mobile-first, keyboard operable, contrast-aware, and respects
`prefers-reduced-motion`. It provides status labels, transaction progress, skeletons,
recoverable index errors, known-address explorer links, and explicit likely-but-not-
guaranteed branch language.

## Verification

```bash
pnpm --filter @raffle-fun/web lint
pnpm --filter @raffle-fun/web typecheck
pnpm --filter @raffle-fun/web test
pnpm --filter @raffle-fun/web build
```

The generated Open Graph image is a non-data brand asset. It does not represent a real
prize or protocol activity.
