# raffle.fun audit r001 — Anthropic provider lane: final report

**Lane scope:** the five Anthropic harness cells (CLAUDE-SIMAO, CLAUDE-PASHOV, CLAUDE-OPENKRITT, CLAUDE-TOB, CLAUDE-GEBAL), one supplementary review, and the lane's own tool campaigns. Other providers' cells and the coordinator's reconciliation were not read and are not covered.
**Target:** `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`, five production files (`SCOPE.md`).
**Model:** `claude-opus-5-5` for every controller, specialist and judge session, run in Claude Code 2.1.299 with effort `max` requested and no fallback.
**Authorization:** the owner's overnight instruction (`../../prompts/claude-overnight.md`) was used as delegated assistant authorization. The owner reviewed no plan hash.

This is not a security certification or release approval. Workflow completion is tracked separately from findings. Bounded fuzzing and timeouts do not prove properties.

---

## 1. Executive assessment

- **No Critical or High code defect was confirmed.** Under the documented trust model (canonical USDC, official Chainlink VRF v2.5 wrapper, honest standards-compliant prize collections), no path was found that lets a third party take buyers' USDC, sponsor assets or protocol fees. Ten cold first-pass reviews (Pashov 12 specialists, Gebal, six ToB stages, SUP) agreed on this. Lane property campaigns that reached every lifecycle branch also found no counterexample to solvency, conservation, exact 95/5, 80/15/5 and 100% splits, refund exactness, ticket-range partition, timing windows, or authorization (Foundry 512k calls per property, Echidna 330k, Medusa 15 min, 9 Halmos proofs). These are bounded campaigns, not proofs.
- **Most material item, CL-01 (Medium, design and integration):** in the NFT outcome the sponsor (95%) and treasury (5%) are paid whether or not the prize can be delivered. Prize escrow is attested only by the untrusted prize contract. Two lane reproductions confirm it: a lying prize and an honest collection paused after creation each leave the winner with nothing while 100% of the pot is released. The code matches DESIGN.md, and historical project notes already list this as a retained risk, but this round has no owner acceptance. A product or design decision is needed.
- **Confirmed Low defect, CL-02:** prize outflows are not re-screened at payout, and creation-time screens let not-yet-deployed clone addresses through. A sponsor's prize can therefore be moved into another raffle clone, technically breaching "Never move assets between raffle clones" (reproduced). The damage is self-inflicted. The remedy is one line.
- **Other items:** Low and Informational integration, configuration and documentation items CL-03 to CL-12, plus one unresolved lead.
- **Workflow coverage was incomplete:**
  - Two of five cells are BLOCKED. 0xSimao was refused by the provider safeguard on the exact model. OpenKritt has no supported Opus 5.5 route.
  - ToB is INCOMPLETE: S6 timed out, and S5 checked only 10 of 248 extracted requirements.
  - Pashov and Gebal (cold) are COMPLETE.

## 2. Five-cell matrix (Anthropic row) and supplementary review

| Cell | Pin | Status | Model evidence | Original output |
|---|---|---|---|---|
| CLAUDE-SIMAO | 0xsimao-ai @3f81e58 | **BLOCKED** | init/assistant `claude-opus-5-5`; 12/12 lenses failed with provider safeguard `[reasoning_extraction]` | money map + 12 bundles preserved; 0 findings (`runs/CLAUDE-SIMAO/attempt-01/BLOCKED.md`) |
| CLAUDE-PASHOV | pashov/skills @8ce544c | **COMPLETE** | main 104 msgs + 376 subagent msgs, all `claude-opus-5-5`; 12/12 specialists completed | `preserved/.solidity-auditor/runs/20261021-005507/full-report.md` (2 findings [75], 9 leads) |
| CLAUDE-OPENKRITT | open-kritt @43e1d19 | **BLOCKED** | no route: bundled Claude Code 2.1.215 < required 2.1.280; no claude-opus-5-5 catalog entry; no container host; interactive-only login | `runs/CLAUDE-OPENKRITT/attempt-01/BLOCKED.md` |
| CLAUDE-TOB | trailofbits/skills @82fe822 (six declared skills; **not** the full catalog) | **INCOMPLETE** | every stage `claude-opus-5-5` | S1 dossier, S2–S5 reports, S6 partial sections |
| CLAUDE-GEBAL | gebal @9ad2464 (historical pin unresolvable) | **COMPLETE (cold)**; deterministic run **BLOCKED** | reviewer 61 msgs `claude-opus-5-5`; schema-valid, origin-bound import | `native-attempt-01/report.md`, `review.json` (4 observations) |
| CLAUDE-SUP (supplementary) | — | **COMPLETE** | 95 msgs `claude-opus-5-5` | `SUP-REPORT.md` |

ToB stages:

| Stage | Status |
|---|---|
| S1 audit-context-building | COMPLETE (attempt-02; attempt-01 stopped) |
| S2 entry-point-analyzer | COMPLETE |
| S3 token-integration-analyzer | COMPLETE |
| S4 guidelines-advisor | COMPLETE |
| S5 spec-to-code-compliance | Workflow COMPLETE (attempt-03); only 10/248 requirements judged |
| S6 secure-workflow-guide | INCOMPLETE: 75-min timeout before final assembly; partial report sections and artifacts preserved |

Full per-attempt identity, exit, duration, cost and freeze evidence are in `matrix.json` and `runs/**/runner-selection.json`.

Identity and effort recording:
- **Requested:** `claude-opus-5-5`, effort `max`.
- **Accepted locally:** the init event reported `claude-opus-5-5`; `max` was accepted with no warning (an invalid value does warn).
- **Provider-returned:** every assistant message reports `model: claude-opus-5-5`, and `modelUsage` contains only `claude-opus-5-5`.
- **Provider-returned effort:** unknown, because it is not echoed.
- **Fallbacks:** none configured and none observed.
- **Old runner:** Claude Code 2.1.58 rejected both `max` ("not available for Claude.ai subscribers") and the model (400 `claude_code_version_too_old`). Evidence is preserved.

## 3. Prioritized findings (deduplicated by root cause; full detail in `reconciliation/RECONCILIATION.md`)

| ID | Title | Class | Severity | Original IDs | Repro |
|---|---|---|---|---|---|
| CL-01 | NftWon payouts don't depend on prize deliverability; escrow attested only by the untrusted prize | design/integration risk | **Medium** | Pashov F2 [75] + 3 leads; TIA-1 (Med); GA-H1; TOB-S6-3; SUP-03; Gebal obs 1 | `test_RC3a`, `test_RC3b` |
| CL-02 | Prize leg lacks payout-time destination screen; future-clone addresses pass creation checks | confirmed defect (self-inflicted) | **Low** | SUP-01; Pashov 2 leads; TIA-5; S5 REQ-38; TOB-S6-1; Gebal obs 3 | `test_RC1` |
| CL-03 | Tickets transferable while Drawing; fulfilment reveals winner early | integration/market | **Low** | Pashov F1 [75] + lead; SUP-04; GA-M1; TOB-S6-2; Gebal obs 2 | `test_RC4` (mechanism) |
| CL-06 | Immutable USDC recipients unrecoverable if blocklisted | trusted-dependency/config | Low | TIA-2; TOB-S6-5; SUP-06 | reasoning |
| CL-04 | Future-clone treasury bricks createRaffle | deployment config | Info | SUP-02; TOB-S6-1 | `test_RC2` |
| CL-05 | Sponsor early cancel of empty raffle vs DESIGN.md wording | spec/doc discrepancy | Info | Gebal obs 4; S5 REQ-23; TOB-S6-4; S2 | `test_RC5` |
| CL-07 | USDC/VRF identity enforced only by deployment tooling | config | Info | TIA-4; SUP-06; GA-H3 | reasoning |
| CL-08 | Sponsor self-entries reach reserve at 5% cost | intended (aggravates CL-01) | Info | Pashov 2 leads; TIA-7 | reasoning |
| CL-09 | VRF liveness/config (fee payer, tx.gasprice quote, confirmations range) | config/liveness | Info | SUP-05/06; S6 §5.3 | reasoning |
| CL-10 | Value outside protocol flows unrecoverable | intended, documented | Info | TOB-S6-6; SUP §6 | reasoning |
| CL-11 | DESIGN.md too thin; contradicts NatSpec on prize trust | documentation | Info | GA-H2; S5 doc problems | text |
| CL-12 | Hygiene/gas (transient guard, assembly, unreachable checks, event order, metadata, EIP-7702) | informational | Info | TOB-S6-8; SUP §7; TIA-6; SUP-07 | — |
| LEAD-1 | Reorg can rebind a pending buy to another raffle at the same CREATE address | unresolved lead | — | Pashov lead | not reproduced |
| FP-1 | "Security tooling absent" | false positive (clean-context exclusion) | — | TOB-S6-7 | project suites run post-seal |

Agreement between harnesses was not counted as independent proof: all reviews read the same source. Each disposition rests on file and line evidence plus a lane reproduction or an explicit reason.

## 4. Per-file and per-property coverage, with gaps

**Per file:**

| File | Read by cold cells | Lane tests | Project tests | Gaps |
|---|---|---|---|---|
| Raffle.sol | Pashov ×12, Gebal, ToB S1–S6, SUP | invariants, fuzzers, Halmos, mutation, repro | 99.60% lines / 89.66% branches | 6 statements / 6 branches unexecuted by project suite; Simao lenses missing |
| RaffleFactory.sol | same | same | 100% lines / 94.44% branches | — |
| IRaffle.sol / IRaffleFactory.sol | explicitly in scope (filename mode); S5 used NatSpec as spec | ABI exercised | — | S5 judged only 10/248 requirements |
| RaffleConstants.sol | same | mutants M23/M24 killed | — | — |

**Per property** (lane): see the table at the end of `reconciliation/RECONCILIATION.md`. Open proof obligations:
1. **Settlement split exactness (symbolic):** Halmos `check_settlementSplit` timed out at 600 s and again at 1,800 s. Concrete, fuzz and stateful evidence agree, and the arithmetic is exact for `pot = n·1e6` (fee `n·5e4`, cash `n·8e5`). The symbolic proof is not done.
2. **Winner-in-range for arbitrary totals (symbolic):** timed out. It is proven only for fixed sizes 3+5 with a symbolic word.
3. **SMTChecker CHC (z3 4.12.6):** TIMEOUT after about 92 min; no verdict.
4. **Certora:** not run (unavailable).
5. **Real USDC and VRF wrapper/coordinator behaviour:** no fork or RPC run. Callback gas, confirmation range and FiatToken semantics are assumptions.
6. **ToB S5:** 238/248 extracted requirements have no verdict.
7. **ToB S6:** its final report was never assembled. Its partial artifacts include its own Echidna/Foundry/mutation work, which the lane has not independently replayed.
8. **Gebal:** the test-inclusive deterministic run is blocked (the image supports solc ≤0.8.30 only; there is no Docker host).
9. **0xSimao:** all 12 attack lenses are missing (provider safeguard).
10. **OpenKritt:** the whole method is missing.
11. **Lane mutation survivor M21:** the in-flight guard is not exercised by lane properties; the project test covers it.

## 5. Reproduction commands
```
# validation copy and dependencies (lane runtime RT=…/raffle-audit-r001-claude)
tar -xzf audits/2026-10-21-r001/target.tar.gz -C $RT/validation && cd $RT/validation/snapshot
pnpm@11.18.0 install --frozen-lockfile          # node 22.23.2
# lane harness: copy the five frozen src files into harness-src/claude-harness/src, verify sha256 vs freeze.json
cd claude-harness && forge test --match-contract 'LaneReproTest|LaneGapTests' -vvv
forge test --match-contract LaneInvariantCoverage -vv --fuzz-seed 0x434c41554445
halmos --contract LaneHalmosTest --solver-timeout-assertion 600000 --loop 4
cd claude-harness-fuzz2 && echidna . --contract LaneEchidna --config echidna.yaml   # needs LaneFactoryDeployer predeploy (config)
medusa fuzz --config medusa.json
python3 harness-src/bin/mutate.py && python3 harness-src/bin/mutate_pass2.py
# project suite
cd snapshot/packages/contracts && forge test --no-match-path 'test/foundry/fork/*' && FOUNDRY_PROFILE=ci forge test --no-match-path 'test/foundry/fork/*'
pnpm exec hardhat compile && pnpm exec hardhat test nodejs
# cells
python3 harness-src/bin/run_cell.py <CELL> <attempt> --prompt-file <prompt> --plugin-dir <plugin>
```
Exact commands, versions and exit codes for each campaign are in `tools/*/command.txt` and `exit.txt`.

## 6. Dependency, configuration, deployment and integration limitations
- Canonical USDC (FiatToken proxy: pause, blocklist, upgrade) and the Chainlink VRF v2.5 native wrapper are trusted. Their identity is enforced only by deployment tooling (CL-07).
- Prize collections are the main trust boundary (CL-01). Frontends must reread chain state and must not keep listings open during `Drawing` (CL-03).
- Dependency advisories apply only to npm copies that are never compiled (`tools/LANE-DEPENDENCIES/DISPOSITION.md`).
- No deployed bytecode was compared, because none is in scope.

## 7. Proposed remediation order (each requires an owner decision, a new candidate and a targeted re-audit)
1. **CL-01:** decide between disclosure plus admission control (no code change) and gating NftWon sponsor proceeds or adding a delivery-failure fallback (design change).
2. **CL-02:** add a payout-time `_isProtocolDestination` screen in `releaseSponsorPrize`, and for symmetry in the NFT branch of `redeemWinningTicket`. UI/SDK should reject code-less predicted clone recipients.
3. **CL-04 and CL-07:** add deployment-validator assertions (treasury is an existing Safe/EOA and is not a predicted CREATE address; canonical USDC and wrapper live checks; `requestConfirmations` inside the coordinator range).
4. **CL-03, CL-05, CL-11:** update documentation and frontend policy (listings during Drawing, empty-raffle cancel semantics, prize-trust wording, expanded DESIGN.md).
5. **CL-06, CL-08 to CL-10, CL-12:** disclosure or hygiene.

## 8. Targeted re-audit plan
- **Code change for CL-01 or CL-02:** re-run Pashov (1 pass) and Gebal on the diff with a new snapshot and new hashes. Re-run lane `LaneReproTest`; RC1 must revert at `releaseSponsorPrize`, and RC3a/b must keep the sponsor share held. Re-run the invariant, Echidna and Medusa campaigns plus mutation, add a property for the new gate, and refresh the project gas snapshot.
- **Closing open obligations:** retry Halmos settlementSplit with a split per outcome and a bounded `n`, or check the mulDiv lemma separately. Run an authorized mainnet-fork lifecycle against real USDC and the VRF wrapper. Complete ToB S5 with a higher requirement limit and S6 with a larger time budget. Revisit OpenKritt and 0xSimao only through an approved route; do not work around the safeguard.

## 9. Final integrity check
See `STATUS.md`, section "Final integrity". Every attempt recorded `freeze-before.ok == freeze-after.ok == true` (`matrix.json`). The sealed `FIRST-PASS.md` hash is re-verified there.

## Process disclosures
- **Lane output location:** the worktree-guard hook blocked the Write tool for the base-checkout path. Lane files were therefore written with shell copies into the assigned exclusive directory `audits/2026-10-21-r001/provider-lanes/claude/`. Nothing else in the repository was modified.
- **Invocation-level additions:** each cell received a short "Runner context" paragraph with the non-interactive flag, explicit scope (interfaces in scope) and DESIGN.md as the spec. The ToB S1 and S5 retries explicitly asked for the named workflow and asked the session to stay active. No harness file was modified; the plugin wrappers are packaging only, and the files are byte-identical.
- **Runner permissions:** `rm` was denied to preserve 0xSimao/Pashov bundles before auto-clean, and reads of the main repo, the coordinator runtime and other transcripts were denied. A 15-second preserver also copied bundles.
- **Exposure audit (`EXPOSURE-AUDIT.json`):** no cell read tests, audit history, scanner output or peer output. Name-only exposures were compiler-cache `find ~` lookups, `find /` name searches for forge-std (ToB S4) and for the Chainlink consumer base (ToB S1 attempt-02, S5 attempt-03 workflow agents), plus globs for `packages/contracts/test/**` inside the clean work dir, where no tests exist; no tool call targeted the main repository (0 main-repo hits), and the stopped S1/S5 attempt-01 plugin searches. The controller also briefly saw the coordinator's halmos process names in `ps` (no contents) before the seal.
- **Controller exposure before the seal:** the controller read the clean source and its own lane tool outputs, which are excluded from FIRST-PASS. It did not alter any cell output.
- **Usage:** the five-hour subscription window reached about 66% during the cold phase, with no overage use observed. Cost at reported list price is about $169 across lane sessions (subscription; informational).

---

## Addendum (2026-10-22T00:50Z): OpenKritt-mod post-seal run
At the owner's request the lane ran OpenKritt as a **disclosed modified controller** (CLAUDE-OPENKRITT-MOD). The patch bumps the bundled Claude Code to 2.1.299 and adds `claude-opus-5-5` to the catalogs. It ran on a dedicated lima Docker VM with an owner-completed Claude sign-in and the native `external-flow-analysis` workflow, the default ranker and PoC Creator, at `claude-opus-5-5`/`max`. Details: `runs/CLAUDE-OPENKRITT-MOD/attempt-01/RESULT.md`.
- **Outcome:** completed after ≈6 h 48 m. 193/195 attempts completed; the 2 failures were controller-stopped hung jobs whose retries completed. **0 raw candidates, 0 findings.**
- **Effect on conclusions:** none. It adds no finding and does not contradict CL-01…CL-12. Zero findings are not proof of absence.
- **Matrix effect:** the native CLAUDE-OPENKRITT cell remains **BLOCKED**. OpenKritt-mod is recorded separately as COMPLETE (modified, post-seal). FIRST-PASS is unchanged.
- **Disclosures:**
  - live settings changed (harness timeout 2700 s, workers 4);
  - two hung containers stopped;
  - provider-returned identity per job unknown (CLI args observed: `--model claude-opus-5-5 --effort max`, Claude Code 2.1.299, no fallback);
  - budget overrun.
  - A separate "Daybreak audit coordinator" session wrote supervisor and diagnosis files into the run directory. They are preserved and excluded from lane evidence.
