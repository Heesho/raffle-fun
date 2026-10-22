# Halmos accounting continuation — sealed report

This is a separately declared post-seal campaign. It read the previous TOOL-HALMOS summary, attempt-03 harness/results and timeout SMT queries after authorization. It does not replace the independent SUP-A1 source-only first pass or the prior TOOL-HALMOS record. It uses isolated projects under `runtime/halmos-continuation`, with separate mutable build, cache, and SMT outputs; dependency symlinks were used read-only.

## Verified result

All three unchanged original terminal accounting properties have passed without narrowing their original symbolic domains. Refund and cash passed with Yices 2.6.4; NFT passed with Bitwuzla 0.8.1. The two exact NFT obligations left unresolved by the Yices run separately returned `unsat` with Bitwuzla. No production source/config was changed.

The stronger successful-completion properties are also closed over those same domains: refund passes directly; cash and NFT completed path exploration with solver timeouts, and **all 11 residual negated-assertion queries were subsequently discharged as unsatisfiable using exact arithmetic refinement and alternate solvers**. Their original CLI TIMEOUT statuses remain in the record. No ordinary-revert omission is hidden by the result: separate wrappers require every allowed accounting sequence to complete successfully and preserve every original assertion.

The successful integrity check compared all five production files and four build/config files in seven project roots (the original Halmos project and six isolated copies). All matched the pre-run hashes. All 36 parent helper before/after checks were clean, and the SUP-A1 report still matches its original sealed SHA256.

## Domains and checked execution

These are symbolic executions through the real frozen factory, cloned Raffle, OpenZeppelin ERC721 prize implementation and quote-transfer/VRF mocks; they are not arithmetic-only surrogate proofs. The reference allocation uses literal expected percentages rather than calling production settlement math.

- Both uint8 entry inputs `a,b` range independently from 1 through 16: two distinct owners, two range tickets, total 2–32 entries at 1,000,000 quote units per entry. Each buyer starts with 100,000,000 quote units.
- Refunds cover both symbolic refund orders (512 input tuples). The outsider cannot refund another holder's ticket; liability/ownership/balance checks remain unchanged after the rejected call. Both owners exit, quote liabilities clear, and the sponsor receives the prize.
- Cash covers every symbolic `pick < a+b` and both sponsor-before-winner and sponsor-after-winner orders (8,704 input tuples). Reserve is 33. Expected winner/sponsor/treasury allocations are 80%/15%/5%, the loser cannot redeem the winning ticket, balances equal accounted liabilities after successful releases, principal is conserved across both buyers and payout recipients, final liability is zero, and the sponsor receives the prize.
- NFT covers every symbolic `pick < a+b` (4,352 input tuples). Reserve is 1. Treasury then sponsor then winner release order is fixed. Sponsor/treasury receive 95%/5%, the current winner receives the NFT, redemption flags hold, principal is conserved, and final liability is zero.
- The callback word is `pick`, so the selected entry is `pick+1`; this covers all selected entries in these ranges but not arbitrary 256-bit callback words or modulo-bias properties. Sale timestamp, actor/recipient addresses, prize ID, reserve choice and transfer behavior are fixed by the harness. The actors do not transfer tickets. No claim is made for larger entry counts, additional actors/tickets, all payout permutations, fee/rebase/malicious tokens, chain forks, or arbitrary external callbacks.
- All Halmos runs use loop bound 3; every completed original proof reports **zero bounded loops** and **zero blocked paths**, so this setting did not truncate those executions. Mocks return VRF fee zero and request ID one. Quote mock transfers exact units and returns true; NFT is the exact linked OZ implementation.

Exact original harness coverage: `HARNESS-original-preserved.sol:45–56` (purchase/range/balance helpers), `:57–65` (refund terminal path), `:67–74` (callback, settlement and wrong-owner redemption), `:76–87` (cash terminal path), `:89–97` (NFT terminal path). `HARNESS-complete.sol:6–20` contains the additional completion obligations. Production execution includes `Raffle.sol:304–345`, `:349–405`, `:468–470`, and `:533–555`, with factory clone creation and exact linked dependencies executed by the harness setup.

## Proof records and solver changes

The per-attempt `result.json` records exact command, cwd, time cap, UTC times, exit code and integrity results; matching `stdout.txt`/`stderr.txt` preserve logs. Halmos JSON records path counts, symbolic runtimes, counterexamples and loop bounds. Raw/refined SMT and solver outputs remain under each `smt-*` directory.

- Original refund: PASS, 25 explored / 2 successful / 0 blocked paths, 18.1145 seconds symbolic execution, no counterexamples or bounded loops.
- Original cash: PASS, 268 / 16 / 0, 211.8888 seconds, no counterexamples or bounded loops.
- Original NFT/Yices: TIMEOUT, 56 / 4 / 0, 173.9371 seconds. Exact unresolved queries were `30.refined.smt2` and `54.refined.smt2`; this failed attempt is retained.
- Original NFT/Bitwuzla: PASS, 55 / 4 / 0, 127.9826 seconds, no counterexamples or bounded loops. Path count variation reflects solver-dependent exploration/pruning; no input constraints changed.
- Direct replay of those exact NFT timeout queries: `unsat`, 22.8895 and 24.4178 seconds respectively, process exit 0.
- Prior campaign refund timeout queries 11/12: direct Yices replay `unsat` in 0.07694 / 0.04361 seconds. Their old appended get-model commands produce an expected message that an unsatisfiable context has no model; the query itself is closed.
- Equivalent-reference NFT/Yices: PASS, 56 / 4 / 0, 45.2777 seconds, no counterexamples or bounded loops. Only the expected reference expressions changed: `gross*95/100` to `(a+b)*950000`, and `gross*5/100` to `(a+b)*50000`. Since `gross=(a+b)*1000000` exactly and a+b <= 32, the substitutions are algebraically equal, have no rounding or overflow and do not narrow inputs. The original production Math.mulDiv and execution remain untouched. The original NFT also passed independently, so this alternative encoding is supplementary.

Halmos 0.3.3; Z3 4.12.6 internal branching; Yices 2.6.4 and Bitwuzla 0.8.1 assertion solvers; Python 3.12.12; Forge 1.7.1; Solidity 0.8.36; Cancun EVM; optimizer 200 runs, no via-IR. Full versions and executable SHA256 values are in `versions/attempt-01/stdout.txt`. Original proof runs use 100ms branching queries, 120s assertion queries, 20-minute per-process caps and two solver threads (refund four). Bitwuzla was installed through Halmos's checksum-verified official solver download and its installation log is retained. No provider-returned model identity is claimed.

## Completion-wrapper method

`HARNESS-complete.sol` imports the byte-identical original harness, reasserts the same input assumptions before a low-level self call, and checks `assert(ok)`. This catches any ordinary revert in the full accounting sequence as well as preserving the inner assertions. The outer assumptions avoid confusing deliberate out-of-domain assume pruning with a failure. The low-level call remains the same test contract address, preserving sponsor identity and all mocked participants.

Halmos 0.3.3 `__main__.py` lines 1087–1126 distinguish assertion panics, stuck states, successful states, and ordinary error outputs; ordinary error outputs are otherwise skipped. This is why the stronger wrappers are separate proof obligations. No source-level assumption that an accounting operation succeeds is added.

Some completion queries time out before Halmos reaches its arithmetic refinement. The replay script uses the installed **unchanged** `halmos.solve.refine(SMTQuery(raw,[]))` on the exact dumped query. This replaces Halmos's uninterpreted multiplication/division/remainder abstractions with their defined bit-vector operations, including the EVM zero-divisor behavior. It adds or removes no path constraints or assertions. Every original/refined query, both hashes, exact solver command, timeout, output, runtime and exit code is retained. An abstract `sat` output is not called a valid counterexample; Halmos normally refines such outputs before accepting a model.

## Integrity and reproduction

`HARNESS-original-preserved.sol`, `HARNESS-linear-reference.sol`, `HARNESS-complete.sol`, the exact diffs, `reproduce_isolation.py`, `replay_refined.py`, and `capture_versions.py` are retained. Source/config hashes were taken before execution and are checked again at sealing. The parent command helper checks the original repository, frozen snapshot and reachable clean dependencies before and after every tool process. The original independent report and prior campaign files are not written by this campaign.

## Stronger completion results and residual-query closure

| Property | Native Halmos result | Explored / successful / blocked | Symbolic seconds | Subsequent closure |
| --- | --- | --- | ---: | --- |
| Refund | PASS | 22 / 2 / 0 | 14.0461 | No residual queries |
| Cash | TIMEOUT | 269 / 16 / 0 | 776.3250 | All 9 residual queries unsat |
| NFT | TIMEOUT | 53 / 4 / 0 | 338.1257 | Both residual queries unsat |

Every completed wrapper exploration has zero counterexamples and zero bounded loops. Cash queries 87, 99, 121 and 133 closed after exact Halmos arithmetic refinement with Bitwuzla. Cash queries 150, 220, 231, 253 and 265 closed after the same refinement with Yices. NFT queries 20 and 43 closed after refinement with Yices in 3.6461 and 3.8606 seconds respectively; the first refined Bitwuzla replay of query 20 timed out at 180 seconds and remains recorded. No timeout is relabeled as a native Halmos PASS.

`CLOSURE.json` maps every one of the 11 original wrapper timeout queries, by exact SHA256, to its successful solver record. `verify_closure.py` recomputes the original and refined bytes using the installed unchanged Halmos refinement function, checks unsat outputs/exit codes, checks that every timeout query is covered, and confirms there are no models, blocked paths or bounded loops in the wrapper exploration results. This discharges the remaining obligations of the completed path explorations at the SMT level. It does not depend on the earlier weaker original PASS.

A supplementary exhaustive SMT decomposition of the two NFT timeout queries also succeeded. For **every one of the 256 pairs** `(a,b)` in `[1,16]^2`, it conjoined only the corresponding low-byte equalities with the exact refined execution obligation; `pick`, storage/balance arrays, other inputs and all original path constraints remained symbolic. All **512 subqueries** returned unsat, as did an independent coverage obligation proving that no permitted `(a,b)` pair lies outside that partition. This is exhaustive decomposition of original cloned-execution SMT, not a set of concrete EVM regression tests. The full-domain direct refined queries also succeeded, so the decomposition is supplementary. No original property domain was narrowed, and no subset of partitions was claimed as complete.

## Final scope and limits

The original refund, cash and NFT terminal-accounting assertions are proved for the exact declared domains and mocks, and the augmented full-sequence successful-completion obligations are closed for the same domains. There are **no unresolved obligations within this campaign's declared domain**. This does not establish arbitrary-size protocol accounting, all actor/claim permutations, hostile-token compatibility, transferable-bearer scenarios or the entire protocol's safety; those were outside these symbolic properties. The two earlier authorization properties were not rerun or silently counted among these three accounting continuations.

All attempts, including timeouts and the unsuccessful first NFT refinement replay, are retained. No OpenAI rejection occurred. Local solver/setup limitations were resolved by alternate solvers, exact refinement and exhaustive decomposition rather than accepted as final failures. `EXECUTION-MANIFEST.json` indexes exact helper commands and results. `ARTIFACT-SHA256.json` inventories the final artifact bytes; `SEAL.json` records the summary and inventory SHA256 and UTC seal time. `SUMMARY-working.md` is retained as the explicitly nonfinal draft.

