# Ethereum v1 security release checklist

This checklist applies to the exact source, lockfile, compiler, deployment parameters,
generated artifacts, and operational configuration proposed for release. Internal
review does not replace an independent audit or operational approval.

> **Current status — 2026-08-18:** internally audit-ready; **not mainnet-ready**.
> The v1 candidate is committed and merged to `main`, but it is not yet designated as
> a signed final release, one RPC-gated fork case is skipped, and no
> independent audit, Sepolia soak, live deployment, operations approval, or legal
> approval exists.

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
- [x] Tickets remain transferable in every status until settlement/refund burns them.
- [x] A delayed draw request remains permissionless forever and cannot itself trigger refunds.
- [x] A missing callback reaches full refunds at the exact two-day boundary.
- [x] Both valid resolution branches are final and have no refund timeout.
- [x] The callback/refund race is mutually exclusive under first-valid inclusion.
- [x] Cash settlement is 80% winner / 5% treasury / 15% sponsor of gross.
- [x] NFT settlement releases 5% treasury / 95% sponsor only after verified delivery.
- [x] Winner settlement is permissionless and cannot redirect delivery from the current owner.
- [x] Sponsor and protocol releases are permissionless but always use immutable recipients.
- [x] Every refund pays the stored entry count at the fixed price exactly once.
- [x] Exact inbound/outbound quote accounting, prize custody, and failed-transfer
      rollback are covered with adversarial assets and non-reentrancy regressions.
- [x] Wrapper authentication, request matching, synchronous/repeated/malformed callback
      behavior, and callback gas boundedness are exercised.
- [x] Sponsor, treasury, and runtime destinations reject known protocol sinks.
- [x] Factory authority is limited to pausing future creation.
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
- [x] Run aggregate formatting, lint, typecheck, build, and test gates after
      implementation edits settled.
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
- [ ] Execute pinned and latest-head Ethereum mainnet and Sepolia fork tests for the
      exact final SHA with archived block identities.

## Integrations and deployment validation

- [x] Factory construction rejects a quote token whose `decimals()` is not exactly 6.
- [x] SDK and web use `bigint` for counts/ranges and explicit ticket IDs for
      authoritative settlement/refund operations.
- [x] Subgraph stores one ticket range per purchase and never expands entries.
- [x] Deployment tooling uses one factory/implementation and no Lens.
- [x] Deployment validation binds the fixed price, 300,000 callback gas, 30
      confirmations, implementation lock, official dependency expectations, and final
      ownership.
- [x] Coordinator capacity validation includes wrapper overhead and EIP-150 forwarding
      compensation, `floor(callbackGasLimit / 63) + 1`.
- [x] Source verification requires `Proxy === "0"`, exact empty `Implementation`, and
      rejects absent/nonempty `SimilarMatch` evidence.
- [x] Ignored VRF callback events are indexed and tested for operational visibility.
- [x] The ignored-callback Low was independently confirmed closed.
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
- [ ] Select and independently review nonzero owner and treasury Safes, signer sets,
      thresholds, modules, guards, recovery, and monitoring.
- [ ] Deploy only to Sepolia first; verify implementation and factory source exactly.
- [ ] Confirm factory ownership acceptance: `owner == Safe` and
      `pendingOwner == address(0)`.
- [ ] Prove sampled raffle runtimes are canonical fixed-target 45-byte ERC-1167 clones.
- [ ] Complete every required scenario in `docs/SEPOLIA-SOAK.md` under active
      monitoring.
- [ ] Produce, independently verify, and sign the finalized deployment record.
- [x] No live deployment, broadcast, source verification, or ownership transaction has
      been performed for this candidate.
- [x] CI contains no mainnet broadcast job or production-private-key path.

## Operations, policy, and law

- [ ] Decide and approve the launch value policy. The contracts enforce no economic
      ceiling; a frontend limit is not a security boundary.
- [ ] Deploy dashboards and alerts for creation, draw requests, ignored callbacks,
      timeouts, outcomes, settlements, refund liabilities, solvency, pause, and
      ownership.
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
