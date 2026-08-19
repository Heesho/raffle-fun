# Production monitoring specification

This is the minimum monitoring contract for every supported factory. It is an
operator specification, not evidence that the monitors are deployed. Chain reads and
transaction receipts are authoritative; the subgraph is a discovery and UX layer.

## Required inputs

- the signed deployment record and its finalized validation block/hash;
- two independent Ethereum RPC providers, one archive-capable;
- factory, implementation, USDC, and Chainlink wrapper addresses;
- the reviewed owner and treasury Safe addresses;
- ABI/source identities for the exact release commit.

The monitor must refuse to start if `deployment:write` validation fails. It must
persist block number/hash and rewind on a reorg instead of treating unfinalized events
as permanent.

## Chain-derived inventory

Discover raffles only from finalized `RaffleCreated` logs, then prove for every entry:

1. `factory.isRaffle(raffle)` and both registry directions agree;
2. runtime is the canonical 45-byte ERC-1167 proxy targeting
   `factory.raffleImplementation()`;
3. `initialized()` is true and immutable/shared configuration matches the factory;
4. the recorded prize, sponsor, treasury, and reserve match the event, and the live
   request/callback deadline getters match the event-derived configuration and state;
5. `USDC.balanceOf(raffle) >= raffle.accountedQuoteBalance()`.

Direct donations can make the last inequality strict. A deficit is never expected.

## Alerts

| Severity | Trigger                                                                                                                                                                                        | Maximum acknowledgement | Required first action                                                                            |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------: | ------------------------------------------------------------------------------------------------ |
| P0       | quote-token deficit; unrecognized raffle runtime/implementation; authenticated callback produces impossible state; confirmed asset-moving exploit                                              |               5 minutes | verify on the second RPC, pause new creation through the owner Safe, invoke the incident runbook |
| P1       | factory owner/pending owner or immutable treasury differs from the approved registry; unexpected creation-pause change; USDC paused; wrapper disabled/unconfigured; repeated creation failures |              15 minutes | stop UI writes and sponsor onboarding; obtain Safe and chain evidence                            |
| P1       | sold `Active` raffle reaches `drawRequestDeadline()` without a request or refund transaction                                                                                                   |              15 minutes | submit `enableRefunds` and alert affected users                                                  |
| P1       | `Drawing` reaches `callbackDeadline()` without a result or refund transaction                                                                                                                  |              15 minutes | submit `enableRefunds` and alert affected users                                                  |
| P2       | sold `Active` raffle remains without `DrawRequested` beyond the agreed keeper SLO but before `drawRequestDeadline()`                                                                           |                  1 hour | notify sponsor/buyers and submit a public draw request before the hard cutoff                    |
| P2       | any `VrfCallbackIgnored`; request remains unresolved beyond the normal fulfillment SLO; RPC providers disagree past finality                                                                   |                  1 hour | correlate request ID with Chainlink logs and preserve raw receipts/traces                        |
| P2       | claim/refund/redemption failures rise above the agreed threshold; indexer lags finalized head by more than 20 blocks                                                                           |                  1 hour | validate directly from chain and mark indexed data degraded                                      |
| P3       | stale unclaimed winner/sponsor/protocol/refund liability or unreleased prize; Safe signer/threshold review due                                                                                 |          1 business day | notify the entitled account or operations owner                                                  |

Thresholds for rate-based alerts must be set before launch from Sepolia measurements;
they may not be left as vendor defaults.

The draw-request keeper SLO must leave at least the acknowledgement objective plus a
measured inclusion margin before `drawRequestDeadline()`; an alert that cannot be acted
on before the hard cutoff is not a liveness control.

## Dashboards and reconciliation

At minimum display:

- finalized head, indexer head, RPC agreement, and reorg count;
- owner, pending owner, immutable treasury, creation pause, wrapper configured/disabled state,
  USDC paused state, and all runtime hashes;
- raffle counts by lifecycle, sales volume, native request fees, fulfillment latency,
  ignored callbacks (from the subgraph's immutable `IgnoredVrfCallback` records,
  reconciled to finalized raw logs), and separate request-deadline and
  callback-deadline queues;
- unsettled pot, refund liability, winner proceeds, sponsor proceeds, protocol fees, actual USDC
  balance, and deficit per raffle and in aggregate;
- winning settlements, refunds, fixed-recipient releases, and winner/sponsor prize withdrawals.

Run full finalized-state reconciliation at least hourly and after every deployment,
ownership change, pause change, reorg, or incident. Page on any unexplained
disagreement between events, registry state, liabilities, and balances.

## Operational drills

Before mainnet, demonstrate with timestamped evidence that the team can: acknowledge a
P0, execute the reviewed Safe pause, disable frontend writes, find every affected
raffle without the subgraph, sponsor each permissionless deadline action, publish a
warning, and validate a replacement factory without altering existing raffles.
