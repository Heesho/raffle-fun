# Ethereum v1 security release checklist

This checklist applies to the exact source, lockfile, compiler, deployment parameters,
generated artifacts, and operational configuration proposed for release. Internal
review does not replace an independent audit or operational approval.

> **Current status — 2026-08-18:** internally audit-ready; **not mainnet-ready**.
> The v1 candidate is committed and merged to `main`, but it is not yet designated as
> a signed final release, one RPC-gated fork case is skipped, and no
> independent audit, Sepolia soak, live deployment, operations approval, or legal
> approval exists.

> **Evidence freshness:** checked numerical results below are preserved for the recorded
> pre-remediation candidate. They do not validate the later hard request/callback
> boundaries, official Chainlink consumer-base migration, or bearer-redemption redesign;
> all affected gates remain open until rerun on the final release SHA.

## Source identity and reproducibility

- [x] Production contracts, interfaces, ABIs, and user-facing protocol references use
      v1 naming consistently.
- [x] The current architecture is fixed implementation plus ERC-1167 clones with no
      upgrade/admin path over existing raffles.
- [x] Implementation initialization is locked and clone initialization is one-time.
- [x] Removed Lens, Pyth, Base, scheduled-start, arbitrary-price, metadata, recovery
      recipient, per-entry minting, and `Closed` behavior is absent from current ABIs.
- [ ] Freeze the exact final source commit and lockfile; record SHA, lockfile hash,
      compiler/toolchain versions, and dependency hashes.
- [ ] Reproduce every required gate from a clean checkout of that exact SHA.
- [ ] Confirm every generated ABI/artifact is current, deterministic, signed where
      applicable, and free of stale output.
- [ ] Match locally built and verified runtime bytecode exactly at the finalized
      deployment block.

## Protocol security properties

- [x] Purchase, callback, and winner proof contain no per-entry loop.
- [x] Refund work is bounded by 1–100 submitted ticket IDs, not represented entries.
- [x] One ticket contains a self-contained inclusive `uint128` entry range.
- [x] `totalEntries` and `ticketCount` are separate and tested through extreme ranges.
- [x] Tickets remain transferable in every status, including after settlement, until
      owner redemption or a refund burns them.
- [ ] Prove `requestDraw` succeeds exactly in `[endTime, drawRequestDeadline())`.
- [ ] Prove a sold `Active` raffle rejects refunds before `drawRequestDeadline()`,
      opens refunds at that deadline, and cannot request at or after it.
- [ ] Prove an authenticated, ABI-decodable matching callback resolves only before
      `callbackDeadline()`, is ignored at and after it, and refunds open at the deadline.
- [ ] Prove a request at the last valid second receives a fresh two-day callback window,
      placing the last nominal boundary almost four days after sale end.
- [x] Both valid resolution branches are final and have no refund timeout.
- [x] Cash settlement is 80% winner / 5% treasury / 15% sponsor of gross.
- [x] NFT settlement records 5% treasury / 95% sponsor without external delivery;
      owner-only redemption later burns the winning ticket and verifies NFT delivery.
- [x] Winner settlement is permissionless and owner-agnostic; only the current bearer
      can atomically burn and redeem the winning ticket.
- [x] Sponsor and protocol releases are permissionless but always use immutable recipients.
- [x] Every refund pays the stored entry count at the fixed price exactly once.
- [x] Exact inbound/outbound quote accounting, prize custody, and failed-transfer
      rollback are covered with adversarial assets and non-reentrancy regressions.
- [x] Wrapper authentication, request matching, authenticated ABI-decodable
      synchronous/repeated/wrong-word-count behavior, unauthorized/undecodable reverts,
      and callback gas boundedness are exercised for the recorded candidate.
- [x] Sponsor, treasury, and runtime destinations reject known protocol sinks.
- [x] Factory has no owner, role, pause, upgrade, rescue, or mutable configuration.
- [x] Current internal finding disposition is recorded in `CURRENT-FINDINGS.md`.
- [ ] Obtain an independent third-party audit of the exact final SHA, including every
      internally fixed release-integrity and observability finding.
- [ ] Resolve every independent-audit Critical/High and every supported-asset Medium.

## Automated evidence

- [x] Foundry: 72 passed, 0 failed, excluding one RPC-gated fork skip.
- [x] Foundry fuzz: 8 properties at 1,000 cases each.
- [x] Audit-profile Foundry fuzz: 8 properties at 100,000 cases each on the committed
      candidate source.
- [x] Stateful invariant: 7 properties at 16,384 calls each with zero handler reverts.
- [x] Audit-depth invariant: 7 properties at 256,000 calls each.
- [x] Strict invariant: 7 properties at 256,000 calls each with `fail_on_revert` and
      zero handler reverts.
- [x] Hardhat deployment/source-verification/journey tests: 22 passed, 0 failed.
- [x] Independent Python model: 11 passed, 0 failed.
- [x] Declared current mutation campaign: 52 of 52 compiling mutants killed.
- [x] Deterministic gas suite: 57 passed, 0 failed, plus one RPC-gated fork skip.
- [x] SDK: 14 passed, 0 failed.
- [x] Web: 15 passed, 0 failed.
- [x] Subgraph: 7 passed, 0 failed.
- [x] Fresh production coverage: 100.00% lines, 100.00% functions, 94.12% branches.
- [x] Current Slither run: 47 contracts, 64 detectors, 0 results; triage database empty.
- [x] Current Gitleaks runs: tracked candidate and 25-commit history both exit 0 with no
      leaks.
- [ ] Reproduce coverage on the exact final SHA.
- [ ] Run aggregate formatting, lint, typecheck, build, and test gates after the timeout
      remediation edits settle.
- [ ] Run high-count final fuzz/invariant campaigns on the exact final SHA.
- [ ] Execute the compiled Echidna harness with retained corpus and branch-reachability
      review.
- [ ] Rerun the complete 52-mutant campaign from the final SHA and archive its source
      and oracle fingerprints.
- [ ] Run the complete static-analysis/security policy on the exact final SHA.
- [ ] Review the exact source annotation and empty `packages/contracts/slither.db.json`
      against the final source; every new finding must stay active.
- [ ] Repeat dependency, package-signature, secret, ABI-drift, runtime-size, initcode,
      and gas gates on the final SHA.
- [ ] Formally disposition the npm audit advisories in unrelated transitive packages
      bundled by `@chainlink/contracts@1.5.0`. The current compiled source graph includes
      only the official wrapper base, client, interface, and LINK interface, and transitive
      build scripts are denied; preserve that reachability evidence or remove the unused
      dependency surface before release.
- [ ] Execute pinned and latest-head Ethereum mainnet and Sepolia fork tests for the
      exact final SHA with archived block identities.

## Integrations and deployment validation

- [x] Factory construction rejects a quote token whose `decimals()` is not exactly 6.
- [x] SDK and web use `bigint` for counts/ranges and explicit ticket IDs for
      authoritative settlement/refund operations.
- [x] Subgraph stores one ticket range per purchase and never expands entries.
- [x] Deployment tooling uses one factory/implementation and no Lens.
- [x] Deployment validation binds the fixed price, 300,000 callback gas, 30
      confirmations, implementation lock, and official dependency expectations.
- [x] Coordinator capacity validation includes wrapper overhead and EIP-150 forwarding
      compensation, `floor(callbackGasLimit / 63) + 1`.
- [x] Source verification requires `Proxy === "0"`, exact empty `Implementation`, and
      rejects absent/nonempty `SimilarMatch` evidence.
- [x] Ignored VRF callback events are indexed and tested for operational visibility.
- [x] The ignored-callback Low was independently confirmed closed.
- [ ] Confirm generated SDK/subgraph ABIs, action gates, indexed deadline state, live UI,
      and sandbox behavior agree with both hard deadline getters and equality cases.
- [x] Missing or wrong-chain deployment configuration disables live web writes.
- [x] Confirm the final deployment-validator fixes in a separate internal security
      review pass.
- [ ] Rerun every SDK, web, subgraph, ABI, deployment-record, validation, and
      source-verification gate after the final release commit.
- [ ] Verify event indexing and UI behavior during the monitored Sepolia soak.

## Deployment

- [ ] Re-verify Ethereum chain ID and official Chainlink wrapper/coordinator and USDC
      addresses from primary sources on release day.
- [ ] Verify wrapper/coordinator source, runtime, native pricing, minimum confirmations,
      maximum callback gas, overhead configuration, and operational status.
- [ ] Verify USDC proxy/runtime, six decimals, issuer controls, and exact-transfer
      behavior at the release block.
- [ ] Select and independently review the nonzero treasury Safe, signer set, threshold,
      modules, guards, recovery, and monitoring.
- [ ] Deploy only to Sepolia first; verify implementation and factory source exactly.
- [ ] Confirm the verified factory ABI and runtime expose no owner, role, pause,
      upgrade, rescue, or mutable-configuration path.
- [ ] Prove sampled raffle runtimes are canonical fixed-target 45-byte ERC-1167 clones.
- [ ] Complete every required scenario in `docs/SEPOLIA-SOAK.md` under active
      monitoring.
- [ ] Produce, independently verify, and sign the finalized deployment record.
- [x] No live deployment, broadcast, or source verification has been performed for
      this candidate.
- [x] CI contains no mainnet broadcast job or production-private-key path.

## Operations, policy, and law

- [ ] Decide and approve the launch value policy. The contracts enforce no economic
      ceiling; a frontend limit is not a security boundary.
- [ ] Deploy dashboards and alerts for creation, draw requests, ignored callbacks,
      separate request/callback deadline queues, outcomes, settlements, refund
      liabilities, solvency, treasury configuration, and runtime identity.
- [ ] Staff and drill monitoring, incident-response, frontend-disable, disclosure, and
      new-factory migration procedures.
- [ ] Establish and test private disclosure and bug-bounty processes.
- [ ] Complete jurisdiction-specific gaming/promotion, consumer, sanctions, tax,
      privacy, advertising, and terms review.
- [ ] Hold and record a written final go/no-go review.

## Historical-document control

- [x] Earlier Base/Pyth, per-ticket, Lens, and pre-range Ethereum reports are retained
      as historical evidence rather than rewritten.
- [x] Historical reports are explicitly marked superseded and cannot support current
      v1 claims.
- [ ] Complete final publication review so only current v1 specifications and the
      exact deployment commit are presented as operative documentation.

Until every required unchecked item is complete, do not describe this protocol as
independently audited, formally verified, risk-free, guaranteed safe, or mainnet-ready.
