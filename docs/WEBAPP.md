# Web application

The Next.js app uses the subgraph for discovery and ticket history, then reads the
factory and raffle contracts directly for authoritative state. There is no Lens. Every
write checks the wallet chain, uses raw-unit `bigint` values, and is simulated against
the target contract before submission.

| Route                | Purpose                                                           |
| -------------------- | ----------------------------------------------------------------- |
| `/`                  | discover and filter indexed raffles                               |
| `/create`            | validate/approve one NFT and atomically create a raffle           |
| `/raffle/[address]`  | buy entries, request a draw, settle, refund, and release proceeds |
| `/profile/[address]` | indexed range tickets and protocol positions                      |
| `/activity`          | indexed lifecycle and redemption history                          |
| `/docs`              | mechanics, guarantees, and external risks                         |

## Creation

The factory fixes the quote token, one-USDC entry price, Chainlink configuration,
treasury, implementation, and economics. The sponsor supplies only:

- an ERC-721 prize and token ID;
- an immutable sponsor payout/prize recipient;
- a positive reserve entry count;
- a future sale end, at most 30 days away.

Because every entry costs $1 USDC, the reserve entry count is also the nominal reserve
amount in dollars. There is no scheduled start, arbitrary entry price, recovery
metadata blob, cash split, or gross-value cap in the form.

## Buying and tickets

A buyer chooses any positive entry count representable by the contract and affordable
under its USDC balance/allowance. One transaction mints one ERC-721 ticket containing
the complete inclusive entry range; it does not mint one NFT per number. UI calculations
stay `bigint`, and display helpers never convert uncapped `uint128` totals to JavaScript
`number`.

Allowance handling simulates ordered approve/buy behavior before requesting an
EIP-5792 wallet batch, with a separately confirmed approval fallback when batching is
unavailable.

Tickets remain transferable until successful winner settlement or a refund burns them.
The UI treats the current `ownerOf(ticketId)` result as authoritative.

## Draw, settlement, and refunds

The raffle page displays the single status, sold/reserve entries, gross USDC, callback
deadline, winning entry, quote liabilities, and sponsor/treasury proceeds.

The Chainlink callback records only the winning entry. It does not discover the
containing ticket, so winner settlement requires a ticket ID. The app discovers
candidate ranges from indexed history, then the contract proves live `ownerOf` and
range containment. NFT and cash settlement may be triggered by anyone, with delivery
fixed to the current owner.

Refunds similarly require explicit ticket IDs. A call accepts at most 100 tickets,
and each ticket refunds its stored number of entries. The owner must initiate the call,
and payment always goes to that owner. The subgraph can help select tickets but is never
ownership authority.

Profiles derive entry totals from indexed range tickets rather than ERC-721
`balanceOf`, which counts tickets rather than entries. When indexed ranges are absent
or stale, the UI shows the value as unavailable instead of inventing zero.

## Sandbox and untrusted content

The offline sandbox mirrors the same sequential ticket IDs, stored ranges, 5% fee,
branch-specific 95% sponsor or 80/5/15 gross economics, O(1) winner selection,
permissionless current-owner settlement, and accepted-callback-timeout refunds. Demo
state uses a versioned local-storage key and is never mixed with a live deployment.

NFT metadata is untrusted. It is never rendered as HTML; schema validation bounds
fields, and active schemes, embedded credentials, oversized responses, and SVG are
rejected.

## Verification

```bash
pnpm --filter @raffle-fun/web lint
pnpm --filter @raffle-fun/web typecheck
pnpm --filter @raffle-fun/web test
pnpm --filter @raffle-fun/web build
```
