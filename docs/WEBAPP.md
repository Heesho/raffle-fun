# Web application

The Next.js app uses indexed data for discovery/history and live registered-contract
reads for every actionable state. Before a write it checks the wallet chain, rereads
the lens/factory, derives raw-unit bigint amounts, and simulates the exact call.

| Route                | Purpose                                                                   |
| -------------------- | ------------------------------------------------------------------------- |
| `/`                  | discovery and state/outcome filtering                                     |
| `/create`            | NFT validation, verified quote-token selection, approval, atomic creation |
| `/raffle/[address]`  | live economics, deadlines, buy/draw/failure/refund/claim actions          |
| `/profile/[address]` | positions and live claimability                                           |
| `/activity`          | indexed lifecycle and claim history                                       |
| `/docs`              | mechanic, guarantees, and external risks                                  |

## Creation policy

The canonical factory rejects unverified quote tokens. The creation form offers only
currently admitted tokens, limits the start delay to 7 days and sale duration to 30
days, and supplies a sponsor recovery recipient (the connected sponsor by default).
Decimals are display-only; parsed prices become exact raw token units.

Issuer pause, blacklist, upgrade, and freeze controls remain residual risks even for
an admitted token. Delisting blocks future creation but does not change existing
raffle liabilities, so direct raffle pages continue to expose recovery and claim
actions.

## Live lifecycle UI

The raffle page displays state/outcome, request grace and callback deadlines, entropy
sequence/timestamps, current prize claimant/recovery recipient, outstanding quote and
native liabilities, refund liability, and whether the entropy fee read succeeded.
Oracle fee failure does not hide failure-finalization buttons.

Available writes include purchase, draw request, missing-request finalization,
callback-timeout finalization, comma-separated bounded refund-ticket crediting,
no-sales closure, cancellation, and quote/prize/native claims. The SDK constructs each
call; the UI never fabricates a winner, refund owner, claimant, or amount.

For insufficient allowance, the app simulates ordered approve/buy behavior before
requesting an EIP-5792 wallet batch and falls back to separately confirmed approval
only if no batch was submitted. A receipt triggers direct refresh while the index
catches up.

## Offline sandbox

Demo mode is a pure reducer that mirrors normal settlement and the bounded failure
model: three-day request grace, two-day callback timeout, `Refunding`, maximum 100-ID
refund batches, frozen-owner credits, zero failure fee, and pull claims. The stand-in
oracle normally responds after four seconds, while reducer tests exercise both exact
failure boundaries. Demo state uses a versioned local-storage key and is never mixed
with a live deployment.

## Content and numerical safety

NFT metadata is untrusted. It is never rendered as HTML; Zod bounds fields; embedded
credentials, active schemes, oversized responses, and SVG are rejected. HTTPS/IPFS
image URLs use constrained handling.

Contract amounts remain bigint end to end. Exponent notation, negatives, grouping,
and excess decimals are rejected. Projected normal settlement uses the SDK's
Solidity-equivalent floor math; failure refunds always display exact ticket price.
Values from different quote tokens are never aggregated.

## Verification

```bash
pnpm --filter @raffle-fun/web lint
pnpm --filter @raffle-fun/web typecheck
pnpm --filter @raffle-fun/web test
pnpm --filter @raffle-fun/web build
```
