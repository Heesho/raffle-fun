# Web application

The Next.js app uses indexed data for discovery and history, then live
registry-authenticated lens reads for every action. Before a write it checks the wallet
chain, refreshes the live view, derives raw-unit bigint amounts, and simulates the exact
contract call.

| Route                | Purpose                                                              |
| -------------------- | -------------------------------------------------------------------- |
| `/`                  | discovery and single-status filtering                                |
| `/create`            | NFT validation, approval, factory-wide USDC display, atomic creation |
| `/raffle/[address]`  | live economics, deadlines, purchase, settlement, burns, claims       |
| `/profile/[address]` | positions and live claimability                                      |
| `/activity`          | indexed lifecycle and claim history                                  |
| `/docs`              | mechanics, guarantees, and external risks                            |

The create form reads the factory's immutable `quoteToken`; the sponsor does not select
an ERC-20. It bounds start and end timestamps to the same seven-day and 30-day contract
limits, parses the ticket price using live USDC decimals, and defaults the recovery
recipient to the connected sponsor.

The raffle page displays the one status, request and callback deadlines, current
winning-ticket owner, refund and winning-cash liabilities, ordinary quote claims, and
recovery eligibility. It exposes one refund-enablement action for either oracle
deadline, then burns current-owner tickets directly for prizes or refunds.

Allowance handling simulates ordered approve/buy behavior before requesting an
EIP-5792 wallet batch and falls back to a separately confirmed approval when batching
is unavailable.

The offline sandbox implements the same bearer semantics: tickets never freeze,
callbacks only record liabilities, the current owner burns the winning ticket, and
refundable ticket burns pay exact value. Demo state uses a versioned local-storage key
and is never mixed with a live deployment.

NFT metadata is untrusted. It is never rendered as HTML; Zod bounds fields; embedded
credentials, active schemes, oversized responses, and SVG are rejected. Contract
amounts remain bigint end to end.

```bash
pnpm --filter @raffle-fun/web lint
pnpm --filter @raffle-fun/web typecheck
pnpm --filter @raffle-fun/web test
pnpm --filter @raffle-fun/web build
```
