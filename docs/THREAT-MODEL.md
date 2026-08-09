# Threat model

## Safety property and scope

For a supported standards-compliant ERC-721 prize and a verified exact-transfer
ERC-20 quote token, no protocol-controlled lifecycle state permanently prevents the
authorized party from recovering the prize or accounted quote funds.

The protocol enforces this with immutable clone configuration, explicit deadlines,
permissionless failure transitions, bounded refund crediting, pull claims, and the
accounting invariant documented in `ARCHITECTURE.md`.

## Supported assets

A supported prize honestly reports ERC-165/ERC-721 support and ownership, and permits
the configured safe transfers. A supported quote token has contract code, is admitted
by the canonical factory, supports normal no-return or optional-return ERC-20 calls,
does not rebase, and moves the exact requested amount both into and out of a raffle.
Raw units are used; decimals never affect accounting.

The guarantee cannot cover dishonest/upgradeable/paused/burned/frozen/blacklisting
NFTs; malicious/rebasing/frozen/blacklisting ERC-20s; issuer controls introduced after
creation; lost keys; a halted/reorganized chain; or unrelated NFTs forced in with
unsafe `transferFrom`. There is deliberately no broad rescue authority.

## Attacks and controls

| Attack                                | Control / residual risk                                                           |
| ------------------------------------- | --------------------------------------------------------------------------------- |
| Failed or fake prize escrow           | exact receiver tuple plus factory `ownerOf` postcondition; whole creation reverts |
| Clone/implementation reinitialization | implementation lock, canonical-factory authentication, `initializer`              |
| Infinite sale lock                    | 7-day maximum start delay and 30-day maximum sale duration                        |
| Oracle unavailable before request     | permissionless failure after fixed 3-day grace                                    |
| Accepted request never fulfilled      | permissionless failure after fixed 2-day callback timeout                         |
| Timeout/callback race                 | first valid included terminal transition wins; other path harmless                |
| Wrong/duplicate/late callback         | authenticated sender plus sequence/state/in-flight checks                         |
| Winner ownership changes pending      | all ticket transfers frozen in `DrawRequested`                                    |
| Refund redirected by transfer         | uncredited ticket frozen; current owner credited onchain                          |
| Refund double spend/unbounded gas     | per-ticket marker and maximum 100-ID batch                                        |
| Fee-on-transfer/sender-tax token      | exact inbound delta and exact outbound debit/credit checks                        |
| Reentrant ERC-20/ERC-721/receiver     | checks-effects-interactions plus reentrancy guard                                 |
| Claim destination reverts             | transfer and consumed-marker revert atomically; claimant retries                  |
| Permissionless claim redirect         | claim-for destination fixed to rightful account                                   |
| Admin seizure/settlement              | no clone admin, upgrade, rescue, or settlement override                           |
| Direct donations/forced native        | explicit liability aggregates; extra balance is surplus only                      |
| Fake raffle passed to lens            | factory registry checked before candidate reads                                   |
| Stale/malicious index/UI              | live chain reread and simulation before writes                                    |

## Admin compromise

A compromised factory owner may pause or misconfigure future creation, change the
future treasury, change token admission, or transfer ownership. It cannot change an
existing clone's token, recovery recipient, economics, deadlines, winner, claims, or
code; pause settlement; or seize its assets. Removing token admission prevents new
raffles but does not mutate existing ones.

## Remaining risks

- unaudited first-party code, compiler, dependency, EVM, and tooling defects;
- oracle randomness/availability assumptions before deterministic failure;
- Base ordering, censorship, finality, or reorganization behavior;
- claimant key loss and hostile safe-transfer destinations;
- counterfeit, mutable, legally encumbered, or economically worthless prizes;
- browser, wallet, RPC, metadata, or supply-chain compromise;
- jurisdiction-specific gambling, sweepstakes, sanctions, tax, and consumer law.

Independent audit, multisig review, monitored testnet operation, frontend
supply-chain hardening, and legal review remain production prerequisites.
