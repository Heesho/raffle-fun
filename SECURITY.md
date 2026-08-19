# Security policy

## Status and scope

The candidate raffle.fun v1 is not deployed, independently audited, or approved for
production. The current ERC-1167/range-ticket design is a rewrite, so audit reports
for older full-deployment, Lens, Pyth, Base, per-ticket, or different economic designs
are historical evidence only.

In scope:

- `packages/contracts/src/Raffle.sol`;
- `packages/contracts/src/RaffleFactory.sol`;
- first-party production interfaces and libraries;
- deployment configuration and validation;
- SDK or web behavior that can construct unsafe transactions;
- subgraph behavior that materially misrepresents financial state.

Mocks, local test infrastructure, and unrelated forced asset donations are out of
scope unless they demonstrate production impact.

## Private disclosure

Do not publish an unpatched vulnerability in an issue, pull request, social post, or
public chat. Use the repository's GitHub private vulnerability reporting feature.
Include:

- the affected commit and component;
- impact and required preconditions;
- focused reproduction steps or a test;
- whether funds, prize custody, randomness, or liveness are affected;
- a proposed remediation, if available.

Do not include private keys, credentials, or unrelated personal data. Maintainers aim
to acknowledge a complete report within five business days and provide a triage
status within ten business days.

## Safe research

Use local networks or accounts and assets you control. Do not:

- access another person's wallet or data;
- disrupt a live oracle, RPC, indexer, or application;
- exploit a public deployment to prove impact;
- retain, move, burn, or destroy another person's assets.

## Security model

Every raffle is a fixed-target ERC-1167 clone. Its implementation and dependencies
cannot be upgraded. The factory's two-step owner can pause only future creation; it
cannot change, pause, settle, or rescue an existing raffle.

The intended bounded paths are:

- anyone may request the one draw at any time after sale end;
- anyone may enable refunds if an accepted request misses its two-day callback deadline;
- anyone may settle a winning NFT or cash ticket to allocate liabilities without
  reading ownership or burning the ticket;
- only the current winning-ticket owner may atomically burn it and redeem the NFT or cash;
- each refund owner burns up to 100 tickets per call for their exact entry value;
- sponsor and treasury balances are independent fixed-recipient liabilities;
- anyone may release either balance only to its immutable recipient.

Tickets remain transferable bearer claims until burned. One ticket may contain any
positive `uint128`-bounded entry range, but purchase, callback, and winner proof do
not loop over entries.

## Supported recovery envelope

The quote-token property assumes the configured official six-decimal USDC remains
available, non-rebasing, and exact-transfer. Incoming and outgoing balance deltas are
verified. Issuer pauses and blacklists can still prevent transfer.

Prize custody assumes a standards-compliant ERC-721 whose `ownerOf` and transfer
behavior remain honest. A malicious or upgraded collection can lie, freeze, burn, or
misdirect its NFT. Winner redemption burns the ticket and delivers the prize in one
transaction, so failed delivery restores the ticket and every redemption marker.
Permissionless accounting settlement allows sponsor and treasury quote claims to
remain usable independently, but there is no successful-result timeout or rescue path
that can force a broken prize out of escrow.

Winner NFT delivery uses `transferFrom` plus an ownership postcondition rather than
`safeTransferFrom`. Owner-initiated redemption therefore does not depend on a receiver
callback, but a contract ticket owner must be able to call the raffle and manage an
ERC-721 received without that callback.

The contracts cannot guarantee recovery from a halted or reorganized chain, universal
censorship, a broken Chainlink wrapper, lost keys, unsupported recipient contracts,
or unrelated NFTs and USDC sent directly to a raffle. There is no administrator
rescue function.

## Operational response

Existing raffles cannot be upgraded or paused. If a vulnerability is confirmed,
maintainers may pause future creation, warn users, remove first-party UI exposure, and
deploy a new factory. Those actions cannot rewrite existing raffles or seize their
assets.

See the [threat model](docs/THREAT-MODEL.md), [security invariants](docs/SECURITY-INVARIANTS.md),
and [release checklist](packages/contracts/audit/RELEASE-CHECKLIST.md).
