# Internal adversarial audit

Review date: 2026-08-09 (Europe/Podgorica)

Reviewed identity: commit `a2120f5e163dc3641d9864773febbfedca047edb`
plus the pre-audit simplified-settlement worktree fingerprint
`55589ce1fce0bd5579e60df747796575df9b0d96`. The final remediation remains an
uncommitted worktree on `codex/raffle-fun-adversarial-audit`; no public deployment,
broadcast, push, pull request, or live ownership action was performed.

This is an internal adversarial hardening review. It is not an independent external
audit, whole-protocol formal verification, or a claim of production safety.

## Executive assessment

The campaign reproduced four High-severity protocol-self custody failures, one
Medium-severity protocol-fee destination failure, and two Low-severity release-process
failures. All were narrowly remediated and preserved as regression tests. No unresolved
Critical, High, or Medium finding involving supported assets remains in the reviewed
worktree.

The fixes reject known protocol destinations at configuration and ticket-transfer
boundaries, and add a bounded permissionless recovery path for any claim assigned to
an address before that address became a registered raffle. The recovery helper can
target only a registered raffle, exposes only the four protocol claim kinds, and sends
recovered assets only to the claim-holding raffle's immutable recovery recipient. It
is not a generic rescue or arbitrary call mechanism.

The resulting source has completed deep internal fuzzing, invariant, differential,
independent-fuzzer, mutation, symbolic, static-analysis, compiler-comparison, fork,
coverage, gas, SDK, subgraph, frontend, and deployment-validation work described in
`TEST-CAMPAIGN.md`. Residual external and operational risks are enumerated in
`RESIDUAL-RISKS.md`.

Subject to the final reproducibility commands remaining green, the strongest warranted
conclusion is: raffle.fun has completed an internal adversarial hardening campaign and
is ready for independent external security review.

## Architecture reviewed

Production Solidity, not the older assumptions in the audit request, controls scope.
The reviewed protocol intentionally uses:

- ordinary constructor `CREATE`, not EIP-1167 clones or CREATE2;
- one immutable USDC quote token per factory, not an admission list;
- one lifecycle/outcome enum;
- transferable ERC-721 bearer credentials in every lifecycle;
- winning-ticket burns for the NFT or cash award;
- refundable-ticket burns for immediate exact refunds;
- immediate excess Entropy funding return, not a native pull liability;
- one Pyth Entropy v2 request and the original three-day/two-day liveness deadlines;
- the original 5% fee on both successful NFT and cash outcomes, and no fee on failed
  draws;
- no raffle administrator, upgrade, pause, generic rescue, second oracle, reroll, or
  unbounded settlement loop.

The approved simplified architecture was preserved. The remediation changed neither
the fee, cash split, threshold rule, oracle, timing, batch limits, nor Base deployment
family.

## Security objective

For a supported standards-compliant ERC-721 prize whose ownership and safe transfers
remain honest, and a non-rebasing exact-transfer USDC whose transfers remain available,
no protocol-controlled lifecycle may permanently prevent the rightful party from
making the prize and every accounted quote liability claimable through bounded,
permissionless progress.

This claim deliberately excludes lost keys, arbitrary user contracts incapable of
calling, malicious or upgraded token code, issuer freezes and blacklists, burned
escrowed NFTs, dishonest token reads, chain halt, universal censorship, and unrelated
NFTs forced into the raffle. Predictable protocol-self destinations were tested and
fixed separately rather than classified as user error.

## Findings

| Severity      | Count | Final state                           |
| ------------- | ----: | ------------------------------------- |
| Critical      |     0 | none found                            |
| High          |     4 | all fixed and regression-tested       |
| Medium        |     1 | fixed and regression-tested           |
| Low           |     2 | fixed and tested                      |
| Informational |     1 | accepted scoped user-destination risk |

Full failure sequences, asset impact, affected functions, remediation, and regression
tests are in `FINDINGS.md`.

### High

- `H-01`: an unsafe transfer could make a raffle its own winning/refund bearer.
- `H-02`: a predicted new raffle could be configured as its own recovery recipient.
- `H-03`: a ticket transferred to a future code-less raffle address could bypass the
  registry check and become trapped when code was later deployed there.
- `H-04`: a later code-less raffle address could be selected as an earlier recovery
  recipient or treasury and later own fixed prize/fee claims it could not initiate.

### Medium

- `M-01`: a predicted new raffle could be configured as treasury and own an
  unexecutable 5% fee claim.

### Low

- `L-01`: clean-checkout CI jobs omitted dependencies, generated sources, or tools.
- `L-02`: deployment-record writing validated syntax but not live contract bindings.

### Accepted informational risk

- `I-01`: a user can deliberately unsafe-transfer a bearer ticket to an unrelated
  non-callable contract, including a separately deployed read-only Lens. The protocol
  cannot distinguish all incapable contracts without sacrificing ordinary ERC-721
  transferability. Known protocol-controlled destinations are rejected.

## Remediation review

The ticket transfer override rejects the ticket's own raffle, factory, quote token,
Entropy contract, configured prize, and every registered raffle. Raffle construction
and treasury administration reject known fixed protocol destinations. A newly created
raffle cannot be its own recovery recipient or treasury even though its address is not
known until `CREATE` returns.

The `recoverProtocolOwnedClaim` helper resolves the code-less future-address gap for
bearer tickets, ordinary quote claims, and sponsor-side prize claims. Any caller may
trigger it, but the target must be factory-registered and the destination is fixed to
the holding raffle's immutable recovery recipient. The explicit claim kind permits
only winning-ticket, bounded refund-ticket, quote, or sponsor-prize calls. This
preserves settlement while avoiding administrator seizure or a generic executor.

CI now installs the required toolchains and dependencies before use. Deployment record
creation now reads the target chain and validates chain ID, block, runtime code,
immutable dependencies, callback gas, quote token, treasury, Lens binding, owner, and
pending owner. Mainnet records require a contract-wallet owner and verified source.

## Verification summary

- 110 practical security invariants are mapped to unit, fuzz, stateful,
  differential, fork, symbolic, static, SDK, subgraph, frontend, or deployment checks.
- Critical Foundry fuzz properties completed 600,000 cases under one deterministic
  seed and 60,000 under a second seed.
- Strict release invariants completed 10,240,000 guarded handler calls with
  `fail_on_revert = true` and zero reverts.
- The independent lifecycle/accounting model completed 10,000 action sequences and a
  permissionless terminal drain after each sequence with no divergence.
- Echidna completed 200,421 transactions across two seeds; Medusa completed 113,261.
- Gambit killed all 52 compiling production mutants after adding sequential-ticket and
  exact recovery-return regressions: 100% raw and adjusted mutation score.
- Five focused Halmos checks passed; SMTChecker was inconclusive and is not represented
  as whole-protocol proof.
- Base mainnet and Base Sepolia pinned fork checks passed against official USDC and
  Pyth Entropy deployments.
- Slither reported zero findings after manual cleanup; Aderyn and Semgrep pattern
  results were manually classified. Mythril was not executed because its released
  Python support does not include the available Python 3.12 runtime.

Exact commands, versions, counts, gas, size, fork blocks, partial attempts, and blocked
capabilities are recorded in `TEST-CAMPAIGN.md`, `STATIC-ANALYSIS.md`,
`MUTATION-TESTING.md`, `SYMBOLIC-CHECKS.md`, and `FORK-VALIDATION.md`.

## Release decision

The internal contract/security gates can support external audit handoff only. The
following remain release blockers outside this campaign:

1. independent external audit of the exact final commit and dependency locks;
2. monitored Base Sepolia operation covering every terminal branch and retry path;
3. final multisig/Safe selection, signer and operational review, and ownership
   acceptance;
4. jurisdiction-specific legal and regulatory review;
5. production monitoring, incident response, disclosure, and rollback-by-new-factory
   runbooks;
6. a clean final source commit followed by byte-for-byte deployment artifact and
   verified-source reconciliation.

No unlimited-value or production-safety conclusion is made.
