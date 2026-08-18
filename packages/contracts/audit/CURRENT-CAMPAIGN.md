# Current v1 internal audit campaign — 2026-08-18

This record covers the active Ethereum v1 range-ticket candidate. It is an internal
security campaign, not an independent audit and not a mainnet authorization.

> **Decision:** internally audit-ready for independent review; **not mainnet-ready**.
> The candidate is committed and merged to `main`, has no live deployment, and has not
> completed the release blockers in `RELEASE-CHECKLIST.md`.

## Candidate identity and scope

| Item               | Current value                                                                             |
| ------------------ | ----------------------------------------------------------------------------------------- |
| implementation SHA | `92eccb4beda71175dfeab4fa2282fbcfaab075c4`                                                |
| evidence SHA       | `e9e0e730c17c07b21e911aa0c02804336e4f146b`                                                |
| candidate identity | committed audit candidate on `main`; not yet designated or attested as a final release    |
| target chain       | Ethereum mainnet, with Sepolia required before mainnet                                    |
| architecture       | one immutable `RaffleFactory`, one locked implementation, fixed-target ERC-1167 clones    |
| quote asset        | factory-fixed six-decimal token; production binding intended to be official USDC          |
| entry economics    | fixed `1_000_000` quote units per entry; 5% protocol fee                                  |
| randomness         | Chainlink VRF v2.5 wrapper, native payment, 30 confirmations, 300,000 callback gas        |
| ticket model       | sequential ERC-721 ID per purchase with a stored inclusive `uint128` entry range          |
| deployment status  | no deployment, broadcast, source verification, ownership transfer, or package publication |

The reviewed protocol has no Lens, scheduled start, arbitrary entry price, per-entry
minting, recovery-recipient role, `Closed` state, Pyth Entropy integration, Base
deployment, or upgrade path for existing raffles.

## Security model exercised

- Purchase, callback, and winner proof are constant-time in the number of entries.
  Refund iteration is bounded by at most 100 submitted ticket IDs.
- Tickets remain transferable bearer claims in every status until settlement or a
  refund burns them.
- The callback authenticates the wrapper and request, handles synchronous, malformed,
  stale, duplicate, and wrong-request callbacks, and stores only the winning entry and
  terminal economic branch.
- Reserve equality selects the NFT branch. Winning-ticket settlement delivers the NFT
  and records 5% for the treasury and 95% for the sponsor. A valid result is final.
- A missed reserve selects the final cash branch: 80% of gross to the winner, 5% to
  the treasury, and 15% to the sponsor, who also recovers the NFT. There is no cash-branch
  refund timeout.
- Winner settlement is permissionless and fixed to the current ticket owner. The
  supplied ticket ID must contain the winning entry.
- Refund value is derived from the ticket's stored inclusive range. Exact
  inbound and outbound quote-token deltas, non-reentrancy, fixed-recipient releases, prize custody,
  and post-transfer ownership are exercised against adversarial assets.
- The factory owner can pause only future creation. Existing clones are immutable and
  have no factory-admin override.

## Verified evidence

These are the latest reported results for the committed v1 audit candidate. The
mutation campaign was repeated from the clean implementation SHA; the complete gate
set must still be reproduced from a clean checkout of the eventual release SHA.

| Gate                                                       |                                                Result |
| ---------------------------------------------------------- | ----------------------------------------------------: |
| Foundry deterministic, security, fuzz, and invariant suite |                                   72 passed, 0 failed |
| RPC-gated Ethereum fork test                               |                     1 skipped without an RPC endpoint |
| Hardhat deployment and journey suite                       |                                   22 passed, 0 failed |
| independent Python protocol model                          |                                   11 passed, 0 failed |
| declared mutation campaign                                 |                               52 of 52 mutants killed |
| deterministic gas suite                                    |                                   57 passed, 0 failed |
| RPC-gated gas/fork case                                    |                     1 skipped without an RPC endpoint |
| SDK tests                                                  |                                   14 passed, 0 failed |
| web tests                                                  |                                   15 passed, 0 failed |
| subgraph tests                                             |                                    7 passed, 0 failed |
| production-only coverage                                   |     100.00% lines, 100.00% functions, 94.12% branches |
| Slither                                                    |                 47 contracts, 64 detectors, 0 results |
| Gitleaks                                                   | tracked worktree and 25-commit history scans: 0 leaks |

Eight Foundry fuzz properties passed the 1,000-case default campaign and the 100,000-case
audit profile. Seven stateful invariants passed the default 16,384-call/property profile
and the 256,000-call/property audit and strict profiles. The strict profile enables
`fail_on_revert` and completed with zero handler reverts. The 52-mutant result covers the
declared, hand-selected compiling set; it is not an exhaustive mutation-space claim.

Fresh production-only coverage is 100.00% lines, 100.00% functions, and 94.12%
branches. It must still be reproduced from a clean checkout of the eventual release SHA.

Slither exits 0 across 47 contracts and 64 detectors with 0 results and an empty triage
database. The fixed-clone initialization heuristic is suppressed only at the exact
`nonReentrant`, one-time initialization call, with its rationale in source; no detector
is disabled globally. Gitleaks also exits 0 for the tracked candidate and a 25-commit
history scan.

## Fixed findings and second-pass internal review

The final campaign closed one Medium release-integrity issue, five Low
release/observability issues, and the mutation-oracle gaps discovered during the
campaign. The most recent Low fixes were:

1. ignored VRF callback events are now indexed as immutable subgraph diagnostics and
   covered by a mapping regression;
2. deployment validation includes Chainlink's EIP-150 forwarding overhead,
   `floor(callbackGasLimit / 63) + 1`, in addition to wrapper overhead when comparing
   against the coordinator maximum; and
3. source verification requires an explicit empty Etherscan `Implementation` field
   and rejects nonempty `SimilarMatch` values instead of accepting proxy/similar-match
   evidence.

All three fixes were confirmed closed by a separate internal security-review pass and
are covered by the current Hardhat/subgraph totals. This is second-pass internal
review, not the still-required third-party audit. See `CURRENT-FINDINGS.md` for the
complete disposition.

## Evidence limits

- The single Ethereum fork case was compiled but skipped in the reported local run;
  no fresh RPC-backed mainnet or Sepolia execution is claimed for this exact candidate.
- The Echidna harness compiles, but no current runtime campaign is claimed because the
  executable was unavailable. Deterministic, fuzz, invariant, model, and mutation
  evidence do not replace an external fuzzer campaign.
- Static analysis, dependency/signature/secrets checks, aggregate workspace gates,
  gas, coverage, ABI drift, source verification, and deployment validation must be
  rerun after the candidate is frozen. The exact Slither source annotation must remain
  narrowly reviewable and must not suppress new findings.
- No production Safe, treasury, Chainlink/USDC release-day binding, signed deployment
  record, live monitoring, incident drill, or legal approval has been accepted.
- The contracts intentionally have no economic value ceiling. A frontend limit is not
  an enforceable protocol control, so launch value policy requires an explicit go/no-go
  decision.

## Mainnet blockers

1. Freeze a final commit and lockfile, then reproduce every gate from a clean checkout
   and archive the exact toolchain, source, ABI, runtime, and dependency hashes.
2. Reproduce production coverage, high-count fuzz/invariants, static analysis, the
   declared mutation campaign, gas/size checks, dependency/signature/secrets checks,
   and RPC-backed pinned plus latest-head Ethereum fork tests.
3. Obtain an independent audit of the exact final SHA, including the three internally
   fixed Low items, and resolve every Critical/High and supported-asset Medium finding.
4. Select and independently review production owner and treasury Safes, verify official
   USDC and Chainlink wrapper/coordinator configuration, and validate exact verified
   source/runtime bytecode and ownership acceptance.
5. Deploy to Sepolia first and complete the monitored soak for NFT success, cash
   success, empty raffles, the callback timeout, both deadline orderings, weighted refunds,
   contract owners, and failed/retried prize delivery.
6. Deploy and drill monitoring, incident response, frontend-disable, disclosure, and
   new-factory migration procedures.
7. Complete jurisdiction-specific legal review, decide the supported launch-value
   policy, and record a written final go/no-go approval.

## Historical evidence

Earlier Base/Pyth, per-ticket, Lens, scheduled-start, and pre-range Ethereum reports are
preserved as commit-pinned historical evidence. They are **superseded** and must not be
used to claim coverage, reviewed behavior, gas, sizes, economics, or deployability for
this v1 candidate. `RELEASE-READINESS-2026-08-17.md` is likewise a superseded candidate
snapshot. The current decision is recorded in
`RELEASE-READINESS-2026-08-18.md` and `RELEASE-CHECKLIST.md`.
