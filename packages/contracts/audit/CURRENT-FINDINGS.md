# Current v1 findings — 2026-08-18

This ledger applies only to the active, committed Ethereum v1 range-ticket audit
candidate. It records an internal review, not an independent audit. Passing tests and
an empty open-defect column do not establish that no undiscovered defect exists.

> **Disposition:** no known open Critical, High, Medium, or Low production-contract
> finding remains from the internal campaign. One Medium release-integrity item and
> five Low release/observability items are fixed and confirmed closed by a separate
> internal security-review pass. The candidate remains
> **not mainnet-ready** because the release gates below are incomplete.

> The later hard request/callback-boundary remediation, official Chainlink
> consumer-base migration, and bearer-redemption redesign change the recorded
> candidate. They are not covered by the historical counts or closure statements in
> this ledger and must be independently reviewed and rerun before a release claim.

## Severity summary

| Severity      | Open production defects | Fixed and internally re-reviewed |   Accepted/external risks |
| ------------- | ----------------------: | -------------------------------: | ------------------------: |
| Critical      |                       0 |                                0 |                         0 |
| High          |                       0 |                                0 |                         0 |
| Medium        |                       0 |                                1 |                         0 |
| Low           |                       0 |                                5 |                         0 |
| Informational |                       0 |                                0 | multiple disclosed limits |

Release-verification gaps are tracked separately because they are blockers, not
evidence of a reproduced Solidity defect.

## Closed finding inventory

| ID              | Severity | Closed issue                                                                                         |
| --------------- | -------- | ---------------------------------------------------------------------------------------------------- |
| V1-DEPLOY-BIND  | Medium   | deployment publication was not cryptographically bound to clean source, exact build, and transaction |
| V1-DEPLOY-SHA   | Low      | deployment config typed a bare Git commit SHA as viem `Hex`                                          |
| V1-GAS-SNAPSHOT | Low      | the committed gas snapshot and command targeted obsolete behavior                                    |
| V1-DEPLOY-01    | Low      | coordinator capacity omitted EIP-150 forwarding compensation                                         |
| V1-DEPLOY-02    | Low      | explorer evidence did not fail closed on proxy/similar-match field omission                          |
| V1-SUBGRAPH-01  | Low      | ignored authenticated VRF callbacks were absent from indexed operational evidence                    |

Every item above has a regression or deterministic release check and was confirmed
closed by a separate internal reviewer. `V1-DEPLOY-BIND` is closed by clean-HEAD/source
binding, pinned production build evidence, exact Factory deployment input and runtime
comparison, implementation runtime comparison, finalized live-state checks, and
independent exact Etherscan records. `V1-DEPLOY-SHA` is closed by the schema-backed
bare-SHA type/fixture. `V1-GAS-SNAPSHOT` is closed by the v1-only deterministic
snapshot and check. These closures do not replace review by an external auditor of the
final release SHA.

---

### V1-SUBGRAPH-01 — Ignored VRF callbacks were absent from indexed operational evidence

- **Severity:** Low
- **Confidence:** High
- **Status:** Closed; fix independently confirmed
- **Category:** Indexer observability
- **Affected code:** subgraph schema, factory initialization, raffle mapping, and
  mapping tests
- **Violated property:** Operators should be able to distinguish ignored stale, wrong,
  in-flight, malformed, or duplicate callback attempts from accepted resolution
  without depending on ad hoc log inspection.
- **Impact:** On-chain state and funds were not affected, but subgraph-backed
  monitoring could omit oracle anomalies and weaken incident diagnosis.
- **Root cause:** `VrfCallbackIgnored` was emitted onchain but had no indexed diagnostic
  entity or aggregate counter.
- **Patch:** Add immutable ignored-callback records and a per-raffle counter, with
  idempotent mapping behavior.
- **Regression evidence:** The subgraph suite now covers event indexing, exact request
  IDs, status mapping, counter increment, and duplicate-handler idempotence; the
  complete subgraph result is 7 passed, 0 failed.
- **Residual risk:** The subgraph is eventually consistent and non-authoritative.
  Production alerts must also consume finalized raw logs and tolerate reorgs and
  indexing lag.

---

### V1-DEPLOY-01 — Coordinator callback-gas validation omitted EIP-150 forwarding overhead

- **Severity:** Low
- **Confidence:** High
- **Status:** Closed; fix confirmed by second-pass internal review
- **Category:** Deployment configuration validation
- **Affected code:** Chainlink wrapper/coordinator checks in deployment validation and
  their Hardhat regressions
- **Violated property:** The recorded 300,000 consumer callback limit plus every
  wrapper and coordinator forwarding overhead must fit within the live coordinator
  maximum.
- **Impact:** A configuration close to the coordinator ceiling could pass preflight
  even though the wrapper's forwarded-gas request exceeds that ceiling. Current
  Ethereum configuration reportedly has substantial margin, so this was a
  release-validator correctness issue rather than a reproduced contract failure.
- **Root cause:** The validator added wrapper gas overhead but did not add the
  coordinator's EIP-150 compensation, `floor(callbackGasLimit / 63) + 1`.
- **Patch:** Include both wrapper overhead and EIP-150 compensation in the maximum-gas
  comparison and report all terms in the failure.
- **Regression evidence:** Boundary tests accept a coordinator maximum of 318,162 and
  reject 318,161 for a 300,000 callback limit with the test wrapper configuration;
  included in the 22-of-22 Hardhat result.
- **Residual risk:** Live wrapper/coordinator configuration can change. The validator
  must run at the finalized release block and be repeated before enabling writes.

---

### V1-DEPLOY-02 — Published-source verification needed explicit non-proxy and exact-match proof

- **Severity:** Low
- **Confidence:** High
- **Status:** Closed; fix confirmed by second-pass internal review
- **Category:** Deployment source verification
- **Affected code:** Etherscan source-verification helper and Hardhat regressions
- **Violated property:** A publishable deployment must be an exact source match for the
  intended direct contract and must not be accepted from omitted, proxy, or
  similar-match metadata.
- **Impact:** Weak API-field validation could allow incomplete explorer evidence to be
  treated as proof of exact source publication. It did not change deployed runtime
  code or contract custody behavior.
- **Root cause:** Release validation needed a strict policy for explorer response
  fields, including field omission.
- **Patch:** Require `Proxy === "0"`, require `Implementation === ""` exactly, require
  a string `SimilarMatch`, and reject any nonempty/nonzero similar-match address.
- **Regression evidence:** Tests reject missing implementation metadata, proxy
  metadata, missing exact-match status, and nonempty similar matches; included in the
  22-of-22 Hardhat result.
- **Residual risk:** Explorer APIs are external evidence. Release approval must also
  compare locally built runtime hashes and the canonical ERC-1167 clone target at a
  finalized block.

## Release-verification gaps

The following are open and block mainnet even though none is presently classified as
a reproduced production defect:

| ID        | Gap                                                             | Required closure                                                                                                                                                                                                                            |
| --------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| V1-REL-01 | No signed final release artifact                                | Designate the exact release SHA and record lockfile, toolchain, build, dependency, and signed artifact hashes.                                                                                                                              |
| V1-REL-02 | Current evidence was not reproduced from a clean final checkout | Rerun every contract, integration, formatting, build, analysis, dependency, signature, secret, ABI, size, gas, and deployment gate.                                                                                                         |
| V1-REL-03 | Coverage was not reproduced from a clean release checkout       | Reproduce 100.00% lines/functions and at least 94.12% branches on the frozen final SHA.                                                                                                                                                     |
| V1-REL-04 | Reported fork case skipped without RPC                          | Run pinned and latest-head Ethereum mainnet and Sepolia forks against the exact final SHA.                                                                                                                                                  |
| V1-REL-05 | Current external-fuzzer runtime evidence is absent              | Execute the compiled Echidna harness with a retained corpus and explicit branch-reachability review.                                                                                                                                        |
| V1-REL-06 | No independent audit of this exact v1                           | Review the final SHA and all internally fixed findings; resolve every Critical/High and supported-asset Medium.                                                                                                                             |
| V1-REL-07 | No monitored Sepolia soak or operational drill                  | Exercise every terminal branch, exact request/callback cutoff, last-valid-second request, both timeout-refund origins, contract-owner case, weighted refund, and failed/retried delivery while monitors and incident procedures are active. |
| V1-REL-08 | Production identities and dependencies are unapproved           | Review the treasury Safe and verify official USDC, wrapper, coordinator, verified source, runtime, clone target, ownerless factory ABI, and signed deployment record.                                                                       |
| V1-REL-09 | Launch policy and legal approval are incomplete                 | Decide supported value policy, complete jurisdiction-specific review, and record a written go/no-go decision.                                                                                                                               |

Current static and secret-scanning evidence is green: Slither exits 0 with 0 results
across 47 contracts and 64 detectors, and its triage database is empty; Gitleaks exits 0
for the tracked candidate and 25-commit history. Both tools must be rerun on the frozen
SHA.

## Accepted design and dependency risks

These are intentional or external limits, not closed by the internal test suite:

- Chainlink VRF, its wrapper/coordinator, Ethereum liveness, confirmation behavior,
  and transaction inclusion remain external assumptions. Requests and callbacks must
  be included before hard cutoffs; censorship or a reorganization that removes one
  after its cutoff can force refunds.
- Official USDC retains issuer, proxy, pause, and blocklist controls. Exact-delta checks
  prevent silent accounting drift but cannot guarantee transfer liveness.
- A future-hostile, upgradeable, pausable, transfer-restricted, or consistently lying
  ERC-721 can prevent release of the winner's prize after a valid result. Settlement
  still records the terminal quote allocations, so the sponsor and treasury claims
  remain independently releasable; there is intentionally no post-result refund path.
- A destroyed or incapable ticket-owning contract can make its owner-only refund
  unreachable.
- The ownerless factory and existing clones are immutable. A discovered defect cannot
  be patched in place and creation cannot be paused onchain; containment depends on
  first-party UI/onboarding controls and migration to a new factory.
- The contracts enforce no economic value ceiling. `uint128` is a machine bound, not a
  risk limit, and a frontend cap is bypassable.
- The winning modulo mapping has negligible but mathematically nonzero `2^-256`-scale
  bias for most entry counts.
- Forced native value, unrelated NFTs, and quote surplus outside recorded liabilities
  have no rescue path by design.

## Historical disposition

Findings tied to Base, Pyth Entropy, per-ticket minting, Lens, scheduled starts,
arbitrary ticket prices, capped purchase quantities, or the pre-range Ethereum
candidate are preserved only in historical reports. They are **superseded**, not
silently carried forward or represented as evidence for this v1. The current release
decision is in `RELEASE-READINESS-2026-08-18.md`.
