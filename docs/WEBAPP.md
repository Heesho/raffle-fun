# Web application

## Stack and routes

The app uses Next.js App Router, React, Tailwind CSS, Wagmi, Viem, TanStack Query,
GraphQL Request, and Zod.

| Route                | Purpose                                                              |
| -------------------- | -------------------------------------------------------------------- |
| `/`                  | discover, search, filter, active/resolved empty/error/loading states |
| `/create`            | NFT verification, exact economics, approval, create                  |
| `/raffle/[address]`  | live state, provider disclosure, buy/draw/close/claims               |
| `/profile/[address]` | sponsored/positions plus live batch claimability                     |
| `/activity`          | indexed purchases, resolutions, and claims                           |
| `/docs`              | plain-language mechanic, examples, trust, risks                      |

## Configuration

Copy `apps/web/.env.example`. Base Sepolia is the default. Every supplied value is
validated; empty optional endpoints remain unset. The chain deployment comes only from
`@raffle-fun/config`. If it is absent, writes are disabled and the UI explains why.
There are no fake addresses, raffles, odds, volume, or activity.

## Data authority

- **Subgraph:** lists, search, profile discovery, history, aggregates.
- **Direct chain:** registration, lifecycle state, outcome, price, threshold, sold
  count, claims, account ticket balance, quote-token verification, provider allowlist,
  and current Entropy fee.

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

The `?ref=` address is syntax-checked and read from the factory allowlist. Zero is
treated as no provider. Invalid/unapproved nonzero values disable purchase; they are
never silently replaced. Exact protocol/provider/net amounts appear before confirmation.

## NFT metadata policy

Metadata is never HTML-rendered. JSON fields are bounded with Zod. Display URLs allow
HTTPS, local HTTP in development, or `ipfs://` transformed through a fixed HTTPS
gateway. Embedded credentials, script/data schemes, redirects, oversized declared
responses, and SVG images are rejected. Metadata and prize authenticity remain
untrusted even after safe display.

## Numerical safety

Contract amounts are bigint end to end. `parseQuoteAmount` accepts the selected
token's decimals, plain decimal strings, and rejects exponent notation, negatives,
grouping separators, and excess decimals. Fee/payout helpers mirror Solidity floor
rounding. The UI never combines monetary values from different quote tokens.

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
