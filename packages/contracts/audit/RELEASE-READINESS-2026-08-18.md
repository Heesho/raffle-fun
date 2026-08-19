# Ethereum v1 release-readiness review — 2026-08-18

## Decision

**Internally audit-ready for independent review; no-go for mainnet.**

The completed v1 redesign has a coherent current specification, focused adversarial
coverage, a fully killed declared mutation set, and green contract/application tests.
It is not independently audited, not frozen at a release SHA, and not operationally or
legally approved. There is **no live deployment** of this candidate.

No deployment, broadcast, source verification, ownership transaction, package
publication, push, or pull request is authorized by this report.

> **Superseded-candidate evidence notice:** the numerical results, design narrative, and
> finding closures below are preserved facts for the recorded candidate SHAs. The later
> timeout remediation, official Chainlink consumer-base migration, and bearer-redemption
> redesign require a new frozen identity plus complete affected-gate reproduction; this
> dated report does not claim that validation.

## Candidate identity

| Item                  | Value                                                     |
| --------------------- | --------------------------------------------------------- |
| repository            | `/Users/hishamel-husseini/Documents/projects/raffle-fun`  |
| implementation SHA    | `92eccb4beda71175dfeab4fa2282fbcfaab075c4`                |
| evidence SHA          | `e9e0e730c17c07b21e911aa0c02804336e4f146b`                |
| candidate             | committed and merged to `main`; not designated as release |
| protocol name/version | raffle.fun v1                                             |
| target                | Ethereum mainnet after a required Sepolia release process |
| production status     | not deployed                                              |

The reviewed implementation is now a reproducible commit. It is an audit candidate,
not a designated or signed final release artifact; any later release commit must be
reviewed and tested independently.

## v1 design reviewed

- The factory has a single locked implementation and creates fixed-target ERC-1167
  clones. Neither the factory owner nor any upgrade admin can change existing raffles.
- Creation takes `prizeToken`, `prizeTokenId`, positive `uint128 reserveEntries`, and
  `endTime`. Sales begin immediately and last no more than 30 days.
- The factory uses a fixed six-decimal quote token and fixed entry price of `1_000_000`
  quote units. The protocol fee is 5%.
- Each purchase mints the next sequential ERC-721 ticket ID and stores an inclusive
  `[firstEntry,lastEntry]` range. Counts are `bigint`/`uint128`; the design does not
  impose a meaningful per-user or economic cap.
- Purchase, callback, and ticket-based winner proof are O(1) in entry count. Refunds
  loop over at most 100 ticket IDs, never individual entries.
- Tickets remain transferable bearer claims until burned. The callback authenticates Chainlink VRF,
  uses 30 confirmations and 300,000 callback gas, and stores the winning entry without
  searching tickets or transferring assets.
- At or above reserve, winning-ticket settlement snapshots the current ticket owner and
  records 5% for the treasury and 95% for the sponsor. The winner's NFT is released
  separately to the snapshotted recipient. The valid result is final.
- Below reserve, settlement records 80% of gross for the snapshotted cash winner, 5% for
  the treasury, and 15% for the sponsor. Winner proceeds and the sponsor's NFT are
  released independently so one failed recipient cannot roll back another allocation.
- A third party may settle a winning ticket but can neither redirect the fixed winner
  recipient nor transfer value during settlement.
- A sold raffle accepts a permissionless draw request exactly in
  `[endTime, drawRequestDeadline())`, with full refunds available at the request deadline
  if no request succeeded. An accepted request resolves only through an authenticated,
  ABI-decodable matching callback before `callbackDeadline()`; at and after that deadline
  the callback is ignored and refunds are available. A last-valid-second request places
  the final nominal boundary almost four days after sale end. Empty raffles enter
  zero-liability `Refunding`.
- Quote and prize movements use exact custody/postcondition checks, non-reentrancy,
  fixed-recipient releases, and known-protocol destination defenses.

## Verified internal evidence

| Gate                     |                                            Result |
| ------------------------ | ------------------------------------------------: |
| Foundry                  |                               73 passed, 0 failed |
| RPC-gated Ethereum fork  |                                         1 skipped |
| Hardhat                  |                               22 passed, 0 failed |
| independent Python model |                               11 passed, 0 failed |
| targeted mutation        |             5/5 settlement-related mutants killed |
| deterministic gas        |                               58 passed, 0 failed |
| RPC-gated gas/fork case  |                                         1 skipped |
| SDK                      |                               16 passed, 0 failed |
| web                      |                               15 passed, 0 failed |
| subgraph                 |                                7 passed, 0 failed |
| production-only coverage | 100.00% lines, 100.00% functions, 94.12% branches |
| Slither                  |             47 contracts, 64 detectors, 0 results |
| Gitleaks                 |  tracked candidate and 25-commit history: 0 leaks |

Foundry additionally reports eight fuzz properties passing both 1,000-case default and
100,000-case audit-profile campaigns. Seven stateful invariants passed the default
16,384-call/property campaign and the audit and strict 256,000-call/property campaigns.
The strict profile enabled `fail_on_revert` and completed with zero handler reverts.

Fresh production-only coverage is 100.00% lines, 100.00% functions, and 94.12%
branches. It remains internal candidate evidence and must be reproduced from a clean
checkout after the final release SHA is frozen.

Slither exits 0 across 47 contracts and 64 detectors with no result and an empty triage
database. The fixed-clone initialization heuristic has one exact, documented source
annotation rather than a detector-wide exclusion. Gitleaks exits 0 for both the tracked
candidate and a 25-commit history scan.

## Finding disposition

The internal campaign has no known open Critical, High, Medium, or Low
production-contract defect. The settlement atomic-coupling finding is fixed by
transfer-free allocation and independent fixed-recipient releases; its regression proves
that a blocked winner can no longer roll back sponsor or treasury accounting or release.
The last three Low integration/validation findings were also fixed with regressions:

- ignored VRF callbacks are now indexed for operational diagnosis;
- deployment validation includes Chainlink wrapper overhead and EIP-150 callback-gas
  compensation when checking the coordinator maximum; and
- Etherscan evidence must explicitly identify a direct, exact source match, including
  an empty `Implementation` field and no nonempty `SimilarMatch`.

All three have been confirmed closed by a separate internal security-review pass. The
five changed settlement-related mutation definitions were rerun and killed; the complete
52-mutant campaign must be rerun against the eventual frozen release SHA. The
broader closed inventory also includes the deployment build/source binding Medium,
the bare-Git-SHA typing Low, and the stale gas-snapshot Low. This second-pass internal
review does not replace the required third-party audit.

This disposition is not a finding-free guarantee. The exact final source has not been
independently audited, and internal tests and models have false negatives.

## Why mainnet remains blocked

1. **No signed final release artifact.** The candidate is committed, but no final
   release designation, build provenance bundle, or signed artifact manifest exists.
2. **No clean final reproduction.** Aggregate formatting, lint, typecheck, build,
   deterministic/adversarial tests, high-count fuzz/invariants, coverage,
   mutation, static analysis, dependencies, signatures, secrets, ABI drift, bytecode
   size, gas, and deployment validation must be rerun from the exact SHA.
3. **No fresh network evidence.** The reported RPC-gated fork case skipped. Pinned and
   latest-head Ethereum mainnet and Sepolia forks must be executed and archived.
4. **No independent audit.** The final SHA—including clone initialization/storage,
   VRF authentication/funding/gas/timeouts, range math, asset accounting, settlement,
   and final validator fixes—must receive independent review.
5. **No live dependency or identity approval.** Official USDC and Chainlink contracts,
   live configuration, verified source/runtime, owner/treasury Safes, signer policies,
   ownership acceptance, and the signed deployment record remain unverified.
6. **No Sepolia soak.** NFT and cash outcomes, empty raffles, exact request and callback
   boundaries, a last-valid-second request, both timeout-refund origins, large weighted
   refunds, contract owners, and failed/retried prize delivery have not been exercised
   under live monitoring.
7. **No production operations.** Monitoring, incident response, frontend disable,
   disclosure, bug bounty, and immutable-factory migration procedures have not been
   deployed and drilled.
8. **No policy/legal go-ahead.** The permissionless contracts have no economic value
   ceiling. Supported launch value, jurisdictional gaming/promotion, consumer,
   sanctions, tax, privacy, advertising, and terms decisions remain open.

## Residual risks requiring explicit acceptance

- Chainlink VRF and Ethereum provide authenticated randomness and ordering/liveness
  assumptions, not guaranteed fulfillment or mathematical finality. Censorship or a
  reorganization that removes a request or callback after its hard cutoff prevents
  replay and can force refunds.
- USDC issuer/proxy controls can pause or block transfers. Exact accounting cannot
  restore external token liveness.
- A malicious or later-restricted ERC-721 can block delivery and strand the NFT branch;
  a valid callback is final and never reopens refunds.
- A destroyed or incapable ticket-owning contract can make its owner-only refund
  unreachable.
- Immutable clones remove upgrade-admin seizure risk but cannot be patched after
  deployment; future creation can only be paused and migrated.
- There is no onchain dollar-value ceiling. Frontend policy cannot bound direct contract
  use.

## Conditions for a mainnet go/no-go review

A new release decision may be considered only after:

1. the final SHA and lockfile are frozen and every automated gate is reproducible;
2. independent audit findings are resolved to the agreed severity policy;
3. RPC-backed fork evidence and the monitored Sepolia soak are complete;
4. exact deployment source/runtime/dependencies and production Safe ownership are
   independently accepted;
5. monitoring and incident procedures are live and drilled; and
6. legal, value-policy, and operational owners sign a written go/no-go record.

Until then, the only accurate description is: **internally audit-ready, not
independently audited, not deployed, and not mainnet-ready**.

## Superseded reports

`RELEASE-READINESS-2026-08-17.md` and earlier Base/Pyth, per-ticket, Lens,
scheduled-start, and pre-range campaign reports are retained as historical,
commit-pinned evidence. They are **superseded** for protocol behavior, test counts,
gas, bytecode size, deployment configuration, economics, and release status. This
report, `CURRENT-CAMPAIGN.md`, `CURRENT-FINDINGS.md`, `CURRENT-TEST-MATRIX.md`, and
`RELEASE-CHECKLIST.md` form the current internal release packet.
