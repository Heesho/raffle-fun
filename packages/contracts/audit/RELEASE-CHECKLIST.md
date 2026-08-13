# Security release checklist

This checklist applies to the exact source, lockfile, compiler, deployment parameters,
and generated artifacts being released. A checked internal item does not replace
independent review or operational approval.

> **Current status: not release-ready.** Checked campaign items below describe the
> pre-remediation audit baseline unless stated otherwise. The 2026-08-13 ETHSkills
> patch and exact production commit were followed by the deep campaign recorded in
> `DEEP-TESTING-2026-08-13.md`, including live pinned Base forks, compiler
> differentials, 197M+ strict invariant calls, a dual-harness Echidna rerun, Halmos,
> and current-commit mutation testing. A final clean release commit and independent
> review are still required. The unresolved Entropy
> selective-reveal trust assumption is a release decision, not a solved property.

## Source identity and reproducibility

- [x] Record reviewed commit and pre-audit worktree fingerprint.
- [x] Preserve the audit branch locally; do not push or open a PR during review.
- [ ] Create the final source commit and record its SHA.
- [ ] Re-run every gate from a clean checkout of that final SHA.
- [ ] Match Hardhat and Foundry compiler, source, optimizer, EVM, ABI, and storage
      assumptions.
- [ ] Match verified source and deployed runtime bytecode byte-for-byte.
- [ ] Confirm the release contains no unsigned or stale generated artifact.

## Findings and security properties

- [x] No unresolved Critical finding.
- [ ] Resolve or explicitly accept the Entropy provider selective-reveal High finding
      after independent RNG architecture review.
- [x] No unresolved Medium finding involving supported assets.
- [x] Every fix has a minimal preserved regression.
- [x] Prize leaves at most once.
- [x] Every supported lifecycle has bounded terminal and claim progress.
- [x] Missing request and missing callback both reach fee-free refunds.
- [x] Every failed-draw ticket burns for exactly one refund.
- [x] Normal and failure branches conserve gross quote liabilities.
- [x] Known protocol destinations are rejected for tickets and quote payouts.
- [x] A new raffle cannot select itself as recovery recipient or treasury.
- [x] The unsafe predicted-address cross-raffle recovery dispatcher is removed.
- [x] Ticket ownership locks during the Entropy reveal gap and for the selected winner.
- [x] NFT proceeds remain escrowed until delivery; failed delivery reaches full refunds.
- [x] Callback and its two-day timeout transition are mutually exclusive.
- [x] Callback work is bounded beneath 300,000 gas.
- [x] Purchase and refund loops are capped at 100.
- [x] Factory owner cannot mutate or seize existing raffles.
- [ ] Reconcile and rerun all 110 practical invariants for the remediated state machine.

## Automated campaigns

- [x] Foundry unit, security, integration, and regression suites.
- [x] Critical Foundry fuzz campaign at 100,000 cases per property.
- [x] Second deterministic fuzz seed.
- [x] Broad multi-actor invariant campaign.
- [x] Strict 1,000 x 256 invariant campaign with zero reverts.
- [x] Release 5,000 x 512 strict invariant campaign with zero reverts.
- [x] Independent differential model plus after-sequence terminal drain.
- [x] Echidna two-seed campaign with retained corpus.
- [x] Medusa campaign with retained corpus.
- [x] Gambit mutation campaign with no meaningful survivor.
- [x] Focused Halmos checks.
- [x] Slither and required printers.
- [x] Aderyn, Semgrep, Solhint, Gitleaks, dependency audit, and size checks.
- [x] Canonical, via-IR, optimizer-disabled, and alternative-EVM comparisons.
- [x] Production-only coverage and documented exclusions/warnings.
- [x] Worst-case callback, purchase, refund, claim, deployment, and Lens gas.
- [x] Pinned Base mainnet and Base Sepolia fork validation.
- [ ] Re-run the final aggregate transcript after creating the release commit.

## Generated and offchain integrations

- [x] Regenerate Hardhat artifacts from final production interfaces.
- [x] Synchronize SDK ABIs and types.
- [x] SDK validates refund batches before simulation.
- [x] Regenerate subgraph ABIs and code.
- [x] Subgraph tests cover terminal exclusivity, burns, and claims.
- [x] Frontend treats chain state as authoritative and simulates writes.
- [x] Missing/wrong-chain deployment disables writes.
- [x] Untrusted metadata is not executed as HTML/script.
- [ ] Re-run SDK, subgraph, and web gates after the final release commit.

## Deployment candidate

- [ ] Verify official Base chain ID and current Pyth Entropy v2 address from primary
      sources on release day.
- [ ] Pin and callback-check a reviewed Entropy provider, or replace the RNG integration
      with an independently reviewed design that addresses selective reveal.
- [ ] Verify official USDC address, decimals, runtime code, proxy/issuer controls, and
      exact-transfer assumptions on release day.
- [ ] Re-measure callback gas using the exact deployed bytecode.
- [ ] Select and review a nonzero treasury Safe.
- [ ] Select and review the final factory-owner Safe, signer set, threshold, modules,
      guards, and recovery process.
- [ ] Confirm completed owner acceptance from the intended Safe (`owner == Safe`,
      `pendingOwner == address(0)`).
- [ ] Validate factory quote token, Entropy, callback gas, treasury, owner, pending
      owner, runtime code, and Lens binding onchain.
- [ ] Require mainnet verified source and contract-wallet final ownership.
- [ ] Write and sign the deployment record only after live validation.
- [ ] Confirm CI cannot broadcast a mainnet deployment.

## External and operational blockers

- [ ] Independent external audit of the exact final commit and locks.
- [ ] Resolve every external-audit Critical/High and supported-asset Medium finding.
- [ ] Monitored Base Sepolia soak covering NFT and cash success, empty close, both
      liveness failures, NFT delivery timeout, partial/complete refunds, transfer locks,
      and retry after destination rejection.
- [ ] Production dashboards and alerts for creation, draw, ignored callbacks,
      deadlines, refund liabilities, quote solvency, redemptions, pause, treasury, owner,
      and pending owner.
- [ ] Incident-response, frontend-disable, warning, and new-factory migration runbooks.
- [ ] Private vulnerability disclosure and bug-bounty process staffed.
- [ ] Jurisdiction-specific legal, consumer-promotion, sanctions, tax, and gaming review.

Until every unchecked release item is complete, the protocol must not be described as
independently audited, formally verified, risk-free, trustless, guaranteed safe, or
ready for unlimited production value.
