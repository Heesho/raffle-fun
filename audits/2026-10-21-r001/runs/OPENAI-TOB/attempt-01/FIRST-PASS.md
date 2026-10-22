# FIRST-PASS — OPENAI-TOB

Original aggregate conclusions, sealed before any external reconciliation. Explicit Trail of Bits six-stage aggregate; **not the full catalog and not full native completion**.

Target SHA requested: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`. Pinned harness: `82fe8226252622fa807643bdca1710901198553a` (selected resources match commit). Snapshot content verified by SHA256 manifest; no source git history accessed.

## Original conclusions
No confirmed exploitable security vulnerability was established by completed work. This is a bounded result, not a safety certification. Slither analyzed36contracts/102detectors and emitted14results; source triage did not establish a security exploit. Native ERC721 conformance checks succeeded.

Retained leads:
1. **Quote semantics:** Raffle.sol:223-233 credits nominal transfers without balance deltas. A six-decimal token that lies or charges fees can underfund liabilities, but requires violating the stated trusted-canonical-token assumption. No deployed-token claim made.
2. **Prize truthfulness / specification wording:** DESIGN.md:2 calls arbitrary prizes untrusted; IRaffle.sol:14-15 limits supported prizes to honest compliant ERC721s. Factory:129-135 and Raffle:334-336 ask the prize contract itself to confirm ownership. This is a concrete wording/trust-boundary ambiguity; no honest-token theft or cross-raffle loss proven.
3. **Cross-factory scope:** Raffle.sol:593-605 screens its canonical factory registry only. Whether the design's inter-clone prohibition spans other deployments is unresolved. No confirmed exploit or severity assigned.

## Stage completion and exposure
| Stage | Original output and coverage | Native limitation |
|---|---|---|
| S1 audit-context-building | Orient;12separate function analysts; dossier;40candidates,28below depth cutoff | Pinned JS logic completed via disclosed adapter; upstream Workflow/Write runtime unavailable |
| S2 entry-point-analyzer |18potentially state-changing signatures; inherited access and both interfaces | Tooling deferred until after source seal |
| S3 token-integration-analyzer |10categories;24weird-token patterns;2conditional leads | Tool phase deferred; no deployment/on-chain input |
| S4 guidelines-advisor |5phases;11areas; source-derived diagrams | Tests/CI unknown; native verification deferred; failed child dispatch preserved |
| S5 spec-to-code-compliance |6documents discovered; extraction dispatched; partial raw outputs | Alignment, independent refutation and report did NOT run; no compliance verdict |
| S6 secure-workflow-guide | Native scan/ERC721/printers; documented properties/manual review | Echidna compilation failed; Manticore unavailable; complete visual inspection unfinished |

S1 synthesized before hunting. S2/S3 used source plus non-finding context; S4 and S5 received no prior findings. S1 synthesis consumed its own records by native design. S1-S5 and source-only aggregate were independently sealed before S6. No external reconciliation, historical reports/tests/scanner outputs or accepted-risk lists were consulted.

## Per-file coverage
| Production file | Covered | Limits |
|---|---|---|
| Raffle.sol | Lifecycle, purchasing/ranges, VRF/auth/deadlines, settlement, bearer redemption/refunds, payout isolation, inherited transfers | No end-to-end fuzz proof; dependency implementation behavior external |
| RaffleFactory.sol | Immutable construction, identity/decimals checks, clone initialization/registry, prize escrow and validators | Canonical deployed identities not verified on-chain |
| interfaces/IRaffle.sol | Explicit inclusion: lifecycle/API/events/errors, claim semantics and trust assumptions | Native spec alignment unfinished |
| interfaces/IRaffleFactory.sol | Explicit inclusion: creation/configuration/registry API | Native spec alignment unfinished |
| libraries/RaffleConstants.sol | All economics, timing, bounds and VRF constants | Arithmetic harness campaign failed to compile |

Reachable dependencies were followed in selected call chains; this is not exhaustive independent certification of every dependency routine.

## Per-property coverage
| Property | Evidence/coverage | Verification limit |
|---|---|---|
| Immutable identities / factory-only initialization | Factory:65-92; Raffle:155-206; S1/S2/S4 | Deployment identity external |
| Atomic escrow and prize delivery | Factory:129-135; Raffle:416-431,329-337 | Honest-prize assumption; documentary ambiguity |
| Quote receipts and solvency | Raffle:223-233,564-567; S3all24patterns | Nominal accounting; token implementation absent |
| Range partition / uint128 caps | Raffle:218-235; S1buyEntries | Source reasoning, no campaign |
| Bearer authority / approvals / burns | Raffle:320-325,359-364; ERC721; S2/S3 | Native ERC checker passed; dynamic adversarial tests absent |
| Draw and callback boundaries | Raffle:240-301,509-524; wrapper base:101-107 | Wrapper liveness/canonical identity assumed |
| One result and one settlement | Raffle:509-558; S1 | No model checker |
| Economic allocation / rounding | Raffle:539-555; Constants | Source conservation; arithmetic-only harness unexecuted |
| Single-use independent claims | Raffle:309-407; S1/S3/S4 | Failed external transfers rollback by EVM; no runtime fault injection |
| Refund batches and duplicate IDs | Raffle:349-372; max100 | Source analysis only |
| Reentrancy / call ordering | Guard; guarded economic paths; source and Slither triage | Native observations not dynamic proof |
| Protocol destination isolation | Raffle:497-502,593-605 | Cross-factory scope unresolved |
| ERC721 conformity | Imported implementation/overrides plus native checker | Full behavioral test suite not run |
| Privacy/front-running/crypto/DeFi | S6pattern search/manual review | Bounded source pass; no live systems |
| Specification alignment | S5discovery/partial extraction | INCOMPLETE; no per-requirement verdict |

## Provenance and artifacts
Accepted local root selection: gpt-6-astra / ultra (runner statement). Every accepted child dispatch explicitly selected the same model/effort; failed S4grandchild inherited that parent and started no rollout. Fallback disabled. Provider-returned model and reasoning effort: **unknown**. No provider identity inferred from names, prompt or self-identification.

Exact resource hashes, stage IDs, requests/responses, model selections, coverage and native execution results are in stage-ledger.json and artifacts/. Raw reports are retained before corrections; see artifacts/CORRECTIONS.md. Source/isolated compiler inputs were checked unchanged. All artifacts/caches remain in cell or run output. No live transactions, deployment, publication or production modification.

Recorded at: 2026-10-21T08:18:22.981361+00:00
