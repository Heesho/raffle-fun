# HANDOFF → Codex coordinator (Anthropic lane, raffle.fun r001)

Lane directory: `audits/2026-10-21-r001/provider-lanes/claude/`. Lane runtime: `~/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001-claude/`.
Nothing outside this directory and that runtime was written. Common freeze files, `matrix.json`, `STATUS.md` and the coordinator's reports were not touched.

## Seal
- `FIRST-PASS.md` sha256 **`16cb0e68e79fba00c1ba91878e682184db08a175fbcf9164dd7b51cc469aefb2`**, sealed 2026-10-21T09:19:07Z (`FIRST-PASS.md.sha256`, file mode 0444). It embeds every original cold report verbatim and hash-binds the rest.

## Cell status (Anthropic row)
| Cell | Status | Original report(s) |
|---|---|---|
| CLAUDE-SIMAO | **BLOCKED**: provider safeguard `[reasoning_extraction]` refused 12/12 lenses on claude-opus-5-5; not worked around | `runs/CLAUDE-SIMAO/attempt-01/BLOCKED.md`, `preserved/.audit-simao-VxctT4/` |
| CLAUDE-PASHOV | **COMPLETE** (memory off, 12/12 specialists, native judge and assembler) | `runs/CLAUDE-PASHOV/attempt-01/preserved/.solidity-auditor/runs/20261021-005507/full-report.md`, `run-1.md` |
| CLAUDE-OPENKRITT | **BLOCKED**: bundled CC 2.1.215 cannot serve Opus 5.5; no container host; interactive-only login | `runs/CLAUDE-OPENKRITT/attempt-01/BLOCKED.md`, `blocker-probes.txt` |
| CLAUDE-TOB | **INCOMPLETE**: S1–S4 complete; S5 complete with 10/248 requirements judged; S6 timed out (partial) | `runs/CLAUDE-TOB/S{1..6}/…/preserved/TOB-*.md`, `S6/attempt-01/partial-artifacts/report/` |
| CLAUDE-GEBAL | **COMPLETE (cold)**; deterministic test-inclusive run **BLOCKED** | `runs/CLAUDE-GEBAL/native-attempt-01/{review.json,report.md,report.json}` (snapshot 1c720af5…, context cbec7142…) |
| CLAUDE-OPENKRITT-MOD (extra; modified controller, post-seal) | COMPLETE: 0 findings | `runs/CLAUDE-OPENKRITT-MOD/attempt-01/RESULT.md`, `scan-final.json` |
| CLAUDE-SUP (extra) | COMPLETE | `runs/CLAUDE-SUP/attempt-01/preserved/SUP-REPORT.md` |

## Results to reconcile across providers
- **CL-01 (Medium, design):** NftWon sponsor and treasury payouts don't depend on prize deliverability; escrow is attested only by the untrusted prize. Repro: `test_RC3a`, `test_RC3b`.
- **CL-02 (Low, confirmed):** the prize leg is not re-screened at payout; future-clone addresses pass creation checks, so an NFT can move into another clone. Repro: `test_RC1`.
- **CL-03 (Low):** tickets are transferable during Drawing while the fulfilment is publicly readable. **CL-04 (Info):** a future-clone treasury bricks creation. **CL-05 (Info):** sponsor early empty-cancel vs DESIGN.md. CL-06 to CL-12 are Info/Low. LEAD-1 is the reorg rebinding lead.
- No Critical or High code defect was confirmed. Full table: `reconciliation/RECONCILIATION.md`. Report: `FINAL-AUDIT-REPORT.md`.

## Tool evidence (lane-owned, validation copy only): `TOOLS.md`, `tools/`
Slither and Aderyn: 0 true positives. Foundry, Echidna and Medusa: 9/9 properties held, non-vacuous after fixes (bounded, not proofs). Halmos: 9 PASS, settlementSplit and general winnerInRange TIMEOUT (open). SMTChecker: TIMEOUT (~92 min, no verdict). Mutation: 20/24 killed. Project Foundry 79/79 (default and ci) and Hardhat 22/22. Certora and fork runs: NOT_RUN.

## Evidence index
`PLAN.md`, `SCOPE.md`, `toolchain.json`, `matrix.json`, `STATUS.md`, `EXPOSURE-AUDIT.json`, `runs/**/{command.json,prompt.txt,settings.json,events.jsonl,stderr.txt,transcripts/,runner-selection.json,freeze-before.json,freeze-after.json,workdir-delta.json,final-result.md,preserved/}`, `harness-src/`, `tools/`.
