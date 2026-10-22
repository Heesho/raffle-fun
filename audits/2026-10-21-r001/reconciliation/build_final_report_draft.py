from pathlib import Path
import json,hashlib,datetime,collections
A=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001');R=Path('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001');S=R/'clean-context/packages/contracts/src';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def link(label,rel):return f'[{label}]({A/rel})'
def src(label,file,line):return f'[{label}]({S/file}:{line})'
m=json.loads((A/'matrix.json').read_text());d=json.loads((A/'reconciliation/findings-register-final-draft.json').read_text());ech=json.loads((A/'ECHIDNA-EXTENDED-RESULTS.json').read_text())
assert [x['actual_calls'] for x in ech]==[100040,100077]
# Preserve the obsolete assessment before replacing the explicitly mutable parent draft.
archive=A/'reconciliation/archived-assessments';archive.mkdir(exist_ok=True);old=A/'FINAL-AUDIT-REPORT.md';oldhash=sha(old);backup=archive/f'FINAL-AUDIT-REPORT-before-readable-draft-{oldhash[:12]}.md'
if not backup.exists():backup.write_bytes(old.read_bytes())
text=f'''# raffle.fun audit r001

**Status: INCOMPLETE — current evidence draft.** Required native continuations and provider qualification remain unfinished. This report is not a release approval or a claim that all requested workflows completed. The parent coordinator will update the final status, matrix and integrity record before delivery.

Frozen commit: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`. Draft assembled {now}; workflow table uses the matrix snapshot dated {m['updated_at']}, with the later Claude S5/S6 correction noted below. No production remediation, deployment or live transaction was performed.

## Assessment

The review identifies two principal source-level root causes. The more consequential is conditional on the prize contract: a dishonest or later nontransferable NFT can leave a winner without the promised prize even though the sponsor can receive 95% of sales. Reviewers disagree on whether this is a High design violation, a Medium integration flaw or an explicitly limited prize-trust guarantee. The disagreement arises from conflicting scope language and remains open.

The second is a Low destination-safety failure. A sponsor can choose the address of a future raffle as its fixed recipient. After that raffle exists, the first raffle can send an ordinary ERC721 prize into it, where the prize becomes unrecoverable. A local honest-token reproduction passed. The demonstrated loss belongs to the sponsor-selected recipient; it does not show theft from an arbitrary EOA or another raffle's accounted funds.

Completed testing provides substantial evidence for ordinary custody, allocation, authorization and lifecycle behavior. It does not remove the prize-trust issue, prove all external integrations, or make weakly exercised invariant handlers comprehensive. There is no demonstrated unconditional Critical exploit or production quote-ledger insolvency in the reconciled evidence.

The register contains 21 findings, observations, configuration risks, closed candidates and advisory entries—not 21 vulnerabilities. Its 190 attribution records plus the two late Pashov attributions preserve every adopted original ID, including rejected candidates and conflicting severity judgments. Eighteen sealed first-pass report paths underpin the combined reconciliation; repeated paths, report copies, functions and model agreement are not independent votes. OpenKritt's four native candidate records are separately identified and deduplicated. See the {link('original reconciliation','reconciliation/RECONCILIATION.md')}, {link('sealed addendum','reconciliation/RECONCILIATION-ADDENDUM.md')}, {link('updated register','reconciliation/findings-register-final-draft.json')} and {link('late Pashov supplement','reconciliation/RECONCILIATION-PASHOV-SUPPLEMENT.md')}.

## Scope and method

Production scope comprises `Raffle.sol`, `RaffleFactory.sol`, `interfaces/IRaffle.sol`, `interfaces/IRaffleFactory.sol` and `libraries/RaffleConstants.sol`, plus 31 exact reachable dependency files and DESIGN.md. The clean review package excludes repository tests, historical audits and scanner outputs from the independent source-first passes. Later test-exposed, tool-assisted and cross-review work is declared separately; it does not overwrite the sealed first passes.

The architecture is immutable factory-created raffle clones with transferable bearer tickets. Entry purchases fund quote-token liabilities; authenticated VRF chooses an entry; settlement allocates 95/5 for an NFT outcome or 80/15/5 for a cash outcome; timeouts allow full ticket refunds. Fixed recipient claims can be released independently. Correct quote accounting assumes the configured canonical quote token transfers exact amounts without fees or rebasing. ERC165, receiver callbacks and ownerOf are statements made by the selected NFT contract, not independent proof of its honesty or permanent transferability.

The campaign requests five harnesses across three providers (15 required cells), five additional Daybreak cells, and three supplementary source reviews. The six selected Trail of Bits skills form the declared ToB workflow; this is not an execution claim for every skill in its catalog. Source review, workflow completion, input coverage, model provenance, instrumented coverage and property proof are tracked separately.

Compiler evidence comes from the actual retained build artifacts: Solidity `0.8.36+commit.8a079791`, Cancun, optimizer 200 runs for the normal build. Forge 1.7.1, Slither 0.11.6, Aderyn 0.6.8, Echidna 2.3.3 and Halmos 0.3.3 versions and commands are retained. An initial guessed solc binary path failed; successful artifact provenance supplies the compiler identity. See {link('toolchain','toolchain.json')} and {link('compiler artifact provenance','compiler-artifact-provenance.json')}.

## Findings

### RF-001 — Prize delivery is conditional while NFT-outcome proceeds are independently payable

**Severity:** High under the explicit untrusted-prize DESIGN requirement; Medium or Low/integration risk under other reviewers' interpretation of the honest, standards-compliant prize assumption. **Confidence:** high in the reachable behavior; unresolved classification because the scope statements conflict.

A sponsor chooses a prize contract that either fabricates escrow/delivery statements or genuinely escrows an NFT and later refuses, pauses or revokes transferability. The factory checks that token's callback, Active status and ownerOf response. Buyers then purchase entries and the normal VRF path resolves NftWon. Settlement makes sponsor proceeds and protocol fees available without first delivering the prize. A prior successful payout is not rolled back by a later failed redemption, and NftWon has no failed-delivery refund transition.

The sponsor needs control over the selected collection's dishonest implementation or relevant transfer authority, or an external collection failure must occur. Quote-token or VRF compromise is not required. The economic exposure is 95% of sales paid to the sponsor while the winner lacks an enforceable promised NFT. The quote ledger can remain exactly solvent throughout. This is not demonstrated against a truthful NFT that stays transferable, and no other clone is drained.

Source anchors: {src('factory admission and escrow','RaffleFactory.sol',127)}, {src('prize receipt','Raffle.sol',416)}, {src('redemption and verification','Raffle.sol',309)}, {src('independent proceeds release','Raffle.sol',375)} and {src('terminal allocation','Raffle.sol',533)}. The scope conflict is recorded between DESIGN.md and IRaffle.sol:12–15. Earlier sealed fabrication mocks support a concrete artificial-token path; their separate ownership ledger illustrates dishonest semantics rather than proving the value or behavior of a deployed collection. Incoming claimed proofs are not automatically independent validation.

Daybreak Simao H-1 through H-5 cover different functions of this economic chain. Late Pashov findings 1 and 2 have confidence 90, not an assigned security severity. Claude TIA-1/TOB-S6-3 and Gemini FP-M-02 use Medium; Claude SUP-03 calls it a Low integration risk and explicitly not a code defect. Those judgments remain visible. No reviewer statement is treated as owner risk acceptance.

Before implementation, specify whether the product promises enforceable prize delivery or only interaction with approved/trusted collection semantics. An allowlist can restrict exposure but cannot itself prevent later upgrades, pauses or seizure. A funded failure fallback must retain all quote amounts it promises, including protocol fees, and handle settlement and payout order explicitly. Simply checking ownerOf again does not authenticate a malicious token. No patch was applied.

### RF-002 — A future clone recipient bypasses creation-time destination screening

**Severity:** Low. **Confidence:** high for the demonstrated sponsor-return path.

A sponsor configures raffle A's immutable recipient as the predictable address of future raffle B. That address has no code and is not yet registered, so creation checks accept it. B is then normally deployed. If A refunds or takes the cash branch, anyone can call releaseSponsorPrize; its plain transferFrom sends A's NFT to B without repeating the runtime protocol-destination screen used by quote payouts. B exposes exits only for its own configured prize, leaving A's prize stuck.

The root reproduction used an honest ERC721 and both real clones. It confirms cross-clone asset movement and sponsor-selected own loss. Quote payout screening can instead leave A's sponsor proceeds unclaimable. The proof does not show an attacker choosing an unrelated victim's recipient. It also does not show B redeeming an A ticket: redemption requires the current owner to originate the call, which B cannot do.

Source anchors: {src('CREATE clone and registration','RaffleFactory.sol',105)}, {src('recipient validation','RaffleFactory.sol',163)}, {src('sponsor prize release','Raffle.sol',395)} and {src('runtime quote screen','Raffle.sol',564)}. Reproduction: {link('RecipientValidation.t.sol','reconciliation/recipient-validation/RecipientValidation.t.sol')} and {link('passing log','runs/TOOL-RECIPIENT-VALIDATION/attempt-01/stdout.txt')}.

Simao J-4 rejects the candidate as self-harm; Gemini's grouped FP-M-01 assigns Medium; Claude SUP-01 assigns Low. The register retains the Low destination-invariant defect and its strict preconditions. Apply a consistent runtime NFT destination policy if this invariant is required. Refusing the transfer prevents cross-clone movement but does not recover an immutable stranded claim; any recovery mechanism requires a separate authority and design decision. Changing CREATE to CREATE2 or adding address randomness is not a complete recovery or destination-safety solution.

## Other observations and unresolved leads

These entries remain distinct from the two root causes. Full original IDs, source lines, actor capabilities, proof status, exclusions, remedies and re-audit properties are in the linked register.

| IDs | Classification and current conclusion |
|---|---|
| OBS-001, OBS-002 | Dependency availability: quote-token sender freeze can stop all exits; a frozen or unusable fixed beneficiary can lose its own payout availability. Liability preservation does not guarantee transfer availability. Earlier reviewers' Medium judgments remain recorded. |
| OBS-003 | Unsupported quote semantics: fees, rebasing or false-success behavior violate exact nominal accounting assumptions. Canonical deployment identity is a required configuration assumption. |
| OBS-004 | Bearer usability: accepting an ERC721 or owning an address does not prove that a recipient contract can later originate the owner-only claim. This includes counterfactual recipients and contracts without suitable execution paths. |
| OBS-005 | Unsolicited donations are outside recorded liabilities and have no rescue. Extra custody is not an underfunded claimant ledger; the lack of recovery is intentional unless the product chooses otherwise. |
| DOC-001 | Broad refund-deadline prose omits sponsor-only early cancellation of an empty raffle. That limited actor right is not a general protocol administrator. |
| LEAD-001 | Pending VRF disclosure may disadvantage standing secondary-market orders. A real executable marketplace, pending-data visibility and transaction ordering must be demonstrated. No randomness manipulation or deployed-market exploit was established. |
| OBS-006 | A funded callback purchase can emit TicketPurchased before RaffleCreated. The clone is Active during the prize callback. Final failed escrow checks roll back all effects; the demonstrated concern is phase/event integration, not a free purchase. |
| CONFIG-001 | A treasury configured to a future clone can halt new creation at that CREATE nonce because initialization rejects self-recipient and rollback restores the nonce. Deployer configuration is required; existing raffle funds are not drained. |
| OBS-007 | Generic ticket names/metadata do not authenticate canonical clones or show current claim value. Integrators must inspect chain, factory, clone, owner, entry range and outcome. |
| LEAD-002 | Reorganization can potentially rebind an unconfirmed CREATE address before a pending client purchase. This needs the actual chain/client sequence; no full demonstration was supplied. |
| CONFIG-002, OBS-008 | An unreachable reserve forces the specified cash branch. Draw liveness depends on someone paying the native VRF fee; absent participation still has a bounded refund route under functioning dependencies. |
| CLOSED-001, CLOSED-002 | Modulo bias is negligible at the stated bounds; reserve top-ups, sponsor participation and single-buyer branch economics follow the configured rules. No minimum-two-buyer guarantee is implemented. |
| CLOSED-003, CLOSED-004 | A uint64 timestamp wrap is impractical in the intended chain horizon. A valid paid purchase ordered before empty cancellation legitimately removes the empty-sale cancellation condition. |
| EVIDENCE-001, ADVISORY-001 | Live configuration and deployment evidence remain absent. Documentation, gas, incident-response and style recommendations are work items, not additional confirmed vulnerabilities. |

## Test assurance and remediation-proposal quality

The four-mutant campaign tested fee allocation, an owner guard, a deadline comparison and disabled purchases in disposable copies. All four compiled and were killed by existing unit/fuzz/security tests. All four initially survived short invariant runs. The fee mutant was eventually killed at the larger recorded run count, while completely disabled purchases still passed strict invariants because failures were caught inside the handler. This constrains the meaning of large successful call counters. See {link('mutation report','runs/TOOL-MUTATION-QUALITY/SUMMARY.md')}.

| ID | Assurance issue |
|---|---|
| AQ-001 | Swallowed reverts/no-op paths can leave every economic action inactive while invariants pass. |
| AQ-002 | Handlers select the actual ticket owner, so they do not exercise the adversarial caller needed to expose owner-check deletion. |
| AQ-003 | Deadline prefilters omit the forbidden exact boundary and can conceal rejection-boundary mutations. |
| AQ-004 | Independent allocation checks are useful, but short-run branch reachability is weak and some ghost values follow implementation state. |
| AQ-005 | The standalone Python model does not roll back lazy settlement on rejected unauthorized redemption. Solidity does roll back; passing Python tests are not an equivalence proof. |
| AQ-006 | Eleven of 52 historical mutation definitions do not match the current target. Invalid definitions are not surviving mutants and must not inflate the score. |
| AQ-007 | Partial or rejected workflows, missing source-context files and uncertain model identity must not be reported as completed assurance. Excluded tests do not establish repository-wide test absence. |
| AQ-008 | The late Pashov Option C patch is unvalidated and incorrectly migrates zero terminal balances when NftWon is still unsettled, leaving the pot outside its proposed refund liability. This is a flaw in a suggestion, not frozen production code. |

The proposed Option C is excluded from recommended implementation. Any delivery fallback must cover pre-settlement and settled NftWon, move each liability exactly once, retain all promised money and define successful delivery and previously paid claims. No proposal has been applied or accepted by the owner.

## Executed tool evidence

| Campaign | Completed evidence and limits |
|---|---|
| Foundry release | 79 passed, 0 failed, 1 unconfigured RPC-fork skip; nine fuzz tests ran 100,000 cases each. Nine invariants reported 233,698,304 total native calls. These include handler attempts, not necessarily successful economic actions. The longer run took about 3,854 seconds; the earlier timeout remains preserved. |
| Echidna | Both extended 100,000-target campaigns completed at 100,040 and 100,077 actual calls, six properties passing each, sequence length 100, one worker, seeds 2026102101 and 2026102102. Native rejected-input/revert counts are unknown. Earlier 180-second incomplete attempts and separate 3,000-target campaigns remain separate evidence. |
| Medusa | Bounded 100,000-target campaign completed: 26 native checks, including six actual properties. The other checks are assertion/function checks, not 20 independent invariants. No exact scheduling-seed replay is claimed. |
| Halmos | Original terminal refund/cash/NFT properties passed on unchanged declared domains. Stronger successful-completion checks closed all 11 residual SMT obligations; original timeout statuses were preserved. Details below. |
| Slither and Aderyn | Complete scans produced 23 source-triaged items in total; no scanner-only exploit was established. Slither's finding-gate exit 255 is not analyzer failure. Gebal's separate Slither run adds 22 mock observations and repeats the same 12 production observations. |
| Build and integration | Seven Foundry profiles and both Hardhat profiles compiled. Adjacent tests: 22 Hardhat, 16 SDK, 25 web, eight subgraph, 11 standalone Python. Config-package test selected zero tests. Format, lint, typechecks, codegen, ABI checks and local gas checks completed after recorded setup repairs. |

The {link('actual release counters','runs/TOOL-RELEASE-EXTENDED/attempt-01/campaign-statistics-final.json')}, {link('extended Echidna results','ECHIDNA-EXTENDED-RESULTS.json')}, {link('tool ledger','tool-campaign-results.json')} and {link('tool summary','TOOL-CAMPAIGN-SUMMARY.md')} preserve commands, exit codes, profiles, seeds, retries and raw outputs. The extended Echidna results supersede the older summary's statement that only the smaller targets completed; they do not rewrite the original incomplete attempts.

Halmos executed the real factory and clone with exact linked OZ NFT code and quote/VRF mocks. Two distinct owners each buy 1–16 entries. Refund covers both orders (512 tuples); cash covers every selected position and both sponsor/winner orders (8,704 tuples); NFT covers every selected position with a fixed treasury/sponsor/winner order (4,352 tuples). Loop bound three caused no bounded loops or blocked paths in the completed original proofs. The reference math uses independent literal percentages.

Yices 2.6.4 and Bitwuzla 0.8.1 closed the original assertions. Stronger completion wrappers assert that the whole allowed sequence succeeds, preventing ordinary reverts from being silently skipped. Nine cash and two NFT residual negated assertions were discharged UNSAT using the unchanged Halmos arithmetic refinement and alternative solvers; exact queries and hashes are mapped in {link('CLOSURE.json','runs/TOOL-HALMOS-CONTINUATION/CLOSURE.json')}. No native TIMEOUT is renamed PASS. There are no unresolved obligations inside those declared domains, but larger amounts, more actors/tickets, ticket transfers, arbitrary callback words, all payout permutations and hostile token behavior are outside them. See the {link('sealed Halmos report','runs/TOOL-HALMOS-CONTINUATION/SUMMARY.md')}.

## File and property coverage

| Production file | Source coverage | Instrumented execution |
|---|---|---|
| Raffle.sol | Every production function and exposed inherited mutation surface | 246/247 lines; 31/31 functions; 52/58 branches |
| RaffleFactory.sol | Constructor, all production functions and registries/getters | 61/61 lines; 4/4 functions; 17/18 branches |
| interfaces/IRaffle.sol | Types, events, errors, signatures, getters and assumptions | No meaningful executable denominator |
| interfaces/IRaffleFactory.sol | All declarations and deployment assumptions | No meaningful executable denominator |
| libraries/RaffleConstants.sol | All economic, deadline, batch, callback constants and units | No meaningful executable denominator |

The {link('per-file/property map','PER-FILE-PROPERTY-COVERAGE.md')} links P01–P16: custody, individual allocation, range partition, owner authorization, initialization, deadlines, NFT delivery, economic prize delivery, recipient isolation, VRF behavior, rollback, gas bounds, handler quality, integrations, reference math and dependency provenance. The {link('detailed function/dependency review','runs/SUP-S1/attempt-01/COVERAGE.md')} distinguishes fully read reachable paths from unused library APIs. Inclusion of 31 dependency files is not an independent complete audit of every API in their packages.

Instrumented coverage does not establish assertion quality or deployed bytecode identity. Default/CI/audit/strict/release templates match; coverage/comparison implementations differ while ABIs match. The unoptimized coverage Raffle exceeds EIP-170, whereas optimized production Raffle runtime is 15,947 bytes and Factory runtime is 3,949 bytes. Runtime immutables prevent treating template hashes as actual deployed-instance hashes. No deployment was supplied.

## Required and supplementary workflow matrix

This table reports workflow completion from the current coordinator matrix, not security votes. “Complete” does not mean universal proof or independent validation of every finding. Source artifacts from incomplete cells may still contribute explicitly limited hypotheses.

| Method | OpenAI Astra | Claude | Gemini | Additional Daybreak |
|---|---|---|---|---|
'''
methods=['SIMAO','PASHOV','OPENKRITT','TOB','GEBAL'];idx={r['id']:r for r in m['runs']}
for method in methods:
 cells=[]
 for provider in ['OPENAI','CLAUDE','GEMINI','DAYBREAK']:
  x=idx[provider+'-'+method];v=x['workflow_status']
  if x['execution_state']=='PROVIDER_REJECTED':v+='; provider rejected'
  elif x['execution_state']=='RUNNING':v+='; running'
  if provider=='CLAUDE' and method=='TOB':v='INCOMPLETE; S6 continuation running'
  if provider=='GEMINI':v+='; qualification gaps'
  cells.append(v)
 text+='| '+method+' | '+' | '.join(cells)+' |\n'
text+=f'''
The current matrix has four of 15 required cells complete, four of five additional Daybreak cells complete, and all three supplementary reviews (SUP-A1, SUP-A2, SUP-S1) complete and sealed. Remaining work is visible in {link('matrix.json','matrix.json')}; the parent will refresh this snapshot as final continuations arrive.

OpenAI source lanes requested/locally selected `gpt-6-astra` at `ultra`; Daybreak selected `gpt-daybreak-blue-latest` at `ultra` through its named access program. Provider-returned identities are not present in those event records and remain unknown. Standard OpenAI Simao and seven Pashov specialist routes received explicit cybersecurity-risk rejections; rejected routes were not replaced and are not complete. Completed Daybreak Simao/Pashov contexts and earlier rejected auxiliary occurrences remain separately preserved.

Claude's retained streams corroborate `claude-opus-5-5`; argv requests `max`, but server-applied effort is not echoed. Pashov's native specialist/judge/assembler and Gebal's cold export/import qualify as complete under the validation record. Claude Simao's actual `[reasoning_extraction]` safeguard refused the lenses. Claude ToB S5 completed the pinned native default of ten selected requirements; the other 238 are deferred coverage, not an unfinished declared ten-check run. Its S6 continuation remains running. The earlier snapshot is corrected explicitly in {link('provider handoff validation','PROVIDER-HANDOFF-VALIDATION.md')}.

Gemini's display selection and inherited subagent requests support “Gemini 4 Argon (High)” as requested, but exact returned identity/applied effort and fallback-disable evidence remain unresolved. Written harness pins conflict; independent resource comparisons repair part of the provenance, not all native stage claims. Its cold Gebal context omits the required 31 dependencies; a later test-exposed intake does not repair that cold review or show tests executed. Its sealed first-pass observations are retained as hypotheses, but no disputed Gemini workflow is counted complete.

OpenKritt Astra and Daybreak native queue/ranker/post-processing runs completed through disclosed CLI/routing/isolation adaptations. Astra's sealed result has zero candidate records; Daybreak has four: #1 paused-prize/payout, #2 future clone, #3 forged escrow, #4 duplicate of #3. The separate independent validator `supp_whole` was **OpenAI-provider rejected after partial work** and was not retried. Native completion therefore is not complete independent finding validation. External Claude/Gemini modified OpenKritt continuations remain separately qualified.

Gebal's cold native context export/review/import remains bound to its own context hash. The completed Docker deterministic run is a distinct compatibility method with exact patches and original failed attempts retained; it is not retroactively imported as a cold source review or a model audit. Local ToB host primitives use disclosed adapters. Workflow changes, identities and stage limits belong in the method/provenance record rather than being hidden by a generic completed label.

## Dependencies, SDK and deployment limits

The dependency scan returned 85 advisory records, 69 distinct GHSA IDs and 1,074 path occurrences. These are scanner/dependency counts, not production exploit counts. The actual compiled Solidity closure uses OpenZeppelin 5.6.1 and Chainlink 1.5.0; the flagged old transitive OZ modules are absent from that closure. This does not certify all package code or deployed dependencies. See {link('dependency review','reconciliation/DEPENDENCY-REVIEW.md')} and its complete path register.

DEP-01 demonstrates a local unit-level Next image-optimizer DNS check/socket mismatch using controlled loopback behavior. It does not demonstrate the full deployed HTTPS image route, DNS timing, hosting or SSRF reachability; the NFT image UI uses unoptimized images. DEP-02/03 retain conditional image-decoder and feature/platform risks. DEP-04 concerns Graph CLI/developer archive traversal; DEP-07 records remaining tooling input paths. These remain separate from Raffle/Factory source defects. DEP-05 explains why old OZ advisories do not apply to the actual imported versions/modules. DEP-06 is a provenance gap: 1,286 registry signatures verified, but an unpublished era-contracts npm packument cannot attest the pinned Git-sourced dependency. No tampering conclusion or automatic upgrade was made.

SDK sync and canonical ABI comparison eventually succeeded: all 125 Raffle and 26 Factory entries match compiler ABIs as canonical entry sets, preserving tuple/parameter order. Top-level array order differs; this is not byte-for-byte array identity. The earlier unresolved literal-array comparison is superseded by {link('ABI equality result','sdk-abi-equality-final.json')}. SDK/web tests and typechecks do not establish a full live wallet/browser/chain lifecycle.

No configured RPC fork or live deployment was supplied. Actual USDC/Chainlink identities, administration, native billing, callback configuration, chain finality and deployed bytecode therefore remain unverified here. The fork test was skipped, not passed. Halmos is the supported executed symbolic verifier; no successful separate SMTChecker or Certora result is claimed.

## Remediation and re-audit order

1. **Resolve RF-001's prize guarantee and specification conflict.** Decide the supported collection trust model and any funded failed-delivery exit. Re-audit dishonest callback/ownerOf, genuine escrow followed by pause/seizure, successful delivery, pre/post settlement, both fee legs and every allowed payout/refund ordering. Demonstrate full conservation and successful authorized exits, not only reverting behavior.
2. **Address recipient isolation and deployment configuration.** Recheck runtime NFT destinations if required; define recovery authority separately from transfer refusal. Re-run the honest future-clone test, treasury-nonce collision, own/foreign protocol sinks and counterfactual ticket ownership. Unrelated beneficiaries and raffles must remain unaffected.
3. **Strengthen assurance before treating invariants as broad evidence.** Record successful actions, expected failures and no-ops; generate adversarial callers and exact boundaries; repair stale mutants and the Python rollback model. Require the intended properties to kill all four valid mutants at disclosed bounds. Do not apply the broken proposed Option C.
4. **Validate actual integrations and deployment.** Confirm canonical dependencies and callback/gas settings, exercise the real intended marketplace and client ordering assumptions, verify full ABI/deployed-bytecode binding, and test claim-aware indexing. Review dependency updates in isolated candidates with route-specific tests and locked provenance.

No remediation or risk acceptance has been authorized by this report. Any approved candidate must be a new reviewed revision with its own diff, configuration, tests, exact source hashes and targeted re-audit. Historical failed attempts, provider rejections, original severity judgments and sealed first passes must remain available.

## Evidence, integrity and remaining completion work

The original reconciliation, addendum and Pashov supplement are separately sealed; none overwrites earlier reports. Their hashes bind findings and attribution data. Completed campaigns preserve per-attempt source/config integrity checks, including the Halmos seven-root comparison and clean Gebal final verification. The five frozen production hashes matched during this draft's reconciliation work. **The parent's final whole-freeze verification and delivery seal are still pending; this mutable draft is not that final integrity attestation.**

Native ToB and external modified-controller/provenance continuations remain pending according to the current matrix. Provider-rejected work stays incomplete without retry. The final delivery must update the table, incorporate only newly sealed findings, verify artifact references and record the final source/config integrity result.

Reproduction and audit trail: {link('RERUN.md','RERUN.md')}, {link('RETRIES.md','RETRIES.md')}, {link('freeze manifest','freeze.json')}, {link('scope files','scope-files.txt')}, {link('coverage/property map','PER-FILE-PROPERTY-COVERAGE.md')} and {link('tool ledger','tool-campaign-results.json')}. Each run retains exact commands, versions, seed/bound information, outputs, failures and classification. Re-execution must use fresh mutable directories and leave sealed artifacts untouched.
'''
old.write_text(text)
inputs=['matrix.json','PROVIDER-HANDOFF-VALIDATION.md','PER-FILE-PROPERTY-COVERAGE.md','TOOL-CAMPAIGN-SUMMARY.md','ECHIDNA-EXTENDED-RESULTS.json','toolchain.json','reconciliation/findings-register-final-draft.json','reconciliation/findings-register-PASHOV-SUPPLEMENT.json','runs/TOOL-HALMOS-CONTINUATION/SUMMARY.md','reconciliation/DEPENDENCY-REVIEW.md']
(A/'FINAL-REPORT-DRAFT-PROVENANCE.json').write_text(json.dumps({'created_utc':now,'status':'INCOMPLETE parent-editable draft; final integrity pending','report_sha256_at_draft':sha(old),'prior_assessment_backup':str(backup),'prior_assessment_sha256':oldhash,'input_snapshots':{x:sha(A/x) for x in inputs},'new_source_edits':False,'new_test_or_exploit_campaign':False},indent=2)+'\n')
print(json.dumps({'report':str(old),'sha256':sha(old),'bytes':old.stat().st_size,'words':len(text.split()),'matrix_snapshot':m['updated_at'],'backup':str(backup)},indent=2))
