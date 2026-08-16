# Current-Commit Residual Risks and Release Blockers

This ledger applies to source commit `5772e54ba89c06646815ed52a881cd8940f094ca` and the 2026-08-16 internal campaign worktree. It is intentionally non-conclusive: internal testing cannot establish safety, an audit, formal verification, trustlessness, or production readiness.

## Unresolved external trust assumptions

1. **Entropy selective reveal (High):** a provider that learns the result before reveal can withhold an unfavorable result and permit full refunds. Simplified maximum option advantage is `G/4` at 50% ticket ownership. Authentication, ticket locks, and timeout tests do not solve it.
2. **Entropy and Base liveness:** provider, sequencer, RPC, or network censorship can delay request/callback/finalization. Timeouts preserve buyer recovery paths but not prompt or unbiased resolution.
3. **Circle USDC policy:** proxy upgrades, pauses, freezes, and sender/receiver blocklists can suspend purchases, claims, or refunds. Exact deltas preserve accounting when calls revert; they do not guarantee availability.
4. **Prize behavior:** an ERC-721 can pause, freeze, burn, upgrade, lie about ownership/interface support, or become incapable after escrow. Delayed proceeds and refunds protect quote buyers, but cannot guarantee prize delivery/recovery.
5. **Key/counterparty capability:** Factory owner key loss while paused can permanently stop new creation. Treasury/recovery accounts or arbitrary ticket holders can lose execution capability. Two-step ownership and destination checks reduce, not remove, this risk.

## Accepted design limitations

- Cross-Factory raffle-ticket prizes and other dynamically frozen ERC-721s can become stranded. Buyer quote funds remain refundable after the NFT timeout.
- Future code-less and arbitrary incapable destinations cannot be rejected reliably. Bearer holders are responsible for destination capability.
- Losing tickets survive successful settlement as transferable souvenirs; UIs/markets must not imply continuing economic value.
- Direct quote donations, forced native currency, and unrelated forced NFTs are unaccounted and have no rescue function.
- Lifecycle transitions require transactions; deadlines do not execute themselves. First valid transaction at callback/NFT timeout wins.
- Modulo bias is nonzero for counts not dividing `2^256`, but the absolute per-ticket probability difference is exactly `2^-256`.
- Factory creation uses ordinary `CREATE`; address prediction depends on nonce and is not a supported guarantee.
- Lens/subgraph/UI availability and freshness are not authorization.

## Unchecked release blockers

- [ ] Rebase/reconcile the campaign changes onto the now-four-commit-newer `origin/main` and rerun affected documentation, formatting, and aggregate gates; this evidence reviews `5772e54`, not remote `d293735`.
- [ ] Obtain a fresh independent external review of the exact release commit and resolved deployment configuration.
- [ ] Decide, disclose, and operationally mitigate/accept Pyth provider selective reveal; pin and monitor the provider.
- [ ] Expand the completed 38/38 current-source sample to event fields, every status/deadline comparison, interaction-order changes, and broad Gambit operators when available.
- [ ] Restore/install the repository's Halmos-equivalent setup; record fresh path counts, feasible success paths, and vacuity warnings.
- [ ] Add durable external-fuzzer reachability counters for cash, NFT, missed request, callback timeout, and NFT-delivery timeout branches.
- [ ] Strengthen deployment validation for expected runtime identity, exact block hash/staleness, proxy implementation identity, and Lens binding; retain the passing pending-ownership, treasury, pause, and decimals policy checks.
- [ ] Decide whether to index `EntropyCallbackIgnored`; add subgraph mapping tests or explicitly designate raw logs as the source.
- [ ] Publish a versioned current public spec/whitepaper; retain old reports with their reviewed commits and superseded labels.
- [ ] Resolve pre-existing formatting gates (`pnpm format:check`, `forge fmt --check`) without rewriting historical evidence deceptively.
- [ ] Review the remaining Low `elliptic <=6.6.1` advisory when upstream publishes a patched version or dependency path changes.
- [ ] Make `pnpm contracts:slither` reliably find the pinned executable in CI; repair the Semgrep X.509 store and Aderyn macOS crash if those tools remain required gates.
- [ ] Re-run all gates on a clean final release commit and verify generated artifacts/ABIs have no diff.
- [ ] Repeat size gate: Factory currently has only 309 runtime bytes of EIP-170 margin.
- [ ] Perform deployment rehearsal and rollback/monitoring/keeper runbooks without broadcasting from this campaign.

## Evidence limitations

- Current tests cover exact boundaries, malicious token/NFT behaviors, multi-Raffle isolation, and terminal drains extensively, but finite tests do not enumerate all EVM states.
- The independent Python model is abstract. It does not import production formulas, but it is neither an EVM-equivalent interpreter nor a formal proof.
- Slither returned zero detector findings; Aderyn findings were manually dispositioned, then the tool crashed; Semgrep did not start. Static tools have false negatives/positives.
- Pinned fork observations are tied to exact blocks. Latest-head observations are ephemeral and may change after this report.
- External fuzzing exceeded 100,000 calls per cash/NFT harness and Medusa exceeded 500,000, but retained corpus/coverage does not prove semantic branch completeness.
- Compiler differentials show consistent tests/layout under the tested configurations only; alternative settings are not endorsed for deployment.

## Owner-facing decisions

1. **Randomness:** prefer a reviewed/pinned provider plus monitoring immediately; separately evaluate a non-selectively-abortable composed source or alternative RNG. Do not market the current design as trustless.
2. **Prize eligibility:** document nested raffle tickets, upgradeable/freezeable NFTs, and arbitrary malicious ERC-721s as unsupported/high risk. A universal on-chain capability test is impossible.
3. **Operational finalization:** operate public monitoring/keepers for request, callback, and NFT-delivery deadlines while preserving permissionless calls.
4. **Release discipline:** prioritize the mutation/symbolic/deployment/off-chain gaps above new protocol features. Any production Solidity fix needs a deterministic red regression and another full fuzz/invariant/size/fork/component run.

## Production-change statement

No production Solidity changed in this campaign. The only fixed items are test instrumentation/reachability, SDK local validation, and a dependency resolution. Consequently there is no claim that an on-chain defect was patched.
