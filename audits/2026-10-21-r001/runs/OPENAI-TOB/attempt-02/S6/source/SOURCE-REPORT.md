# S6 — secure-workflow-guide source-only continuation

Completed: Step 4 property documentation (P01–P16), Step 5 manual source review, and Step 2 applicability searches. This is the SAME-CELL OPENAI-TOB continuation of the six-stage aggregate. S5 remains independently pending. **No new confirmed exploitable vulnerability is established by this bounded continuation.** No full-workflow, specification-compliance, conformance, or safety verdict is implied.

## Authority, provenance and method boundary

Frozen target: `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/OPENAI-TOB-continuation/target`. Requested commit: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`. The target is a source snapshot without Git metadata: read-only `git rev-parse HEAD` failed, so the commit is recorded as supplied, not independently attested against bytes. `coverage.json` records SHA-256 for every inspected production/dependency/design file and the import graph.

Requested model/effort: `gpt-6-astra` / `ultra`. Provider-returned identity is **unknown**; no identifying event was supplied. No model switching, delegation, API/network calls, access-program override or fallback was performed.

Applied the actual pinned [secure-workflow-guide SKILL.md](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/building-secure-contracts/skills/secure-workflow-guide/SKILL.md), [WORKFLOW_STEPS.md](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/building-secure-contracts/skills/secure-workflow-guide/resources/WORKFLOW_STEPS.md), and [EXAMPLE_REPORT.md](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/building-secure-contracts/skills/secure-workflow-guide/resources/EXAMPLE_REPORT.md). Method HEAD is `82fe8226252622fa807643bdca1710901198553a`; a read-only diff of these three resources against HEAD returned no differences. Their hashes are in `coverage.json`.

The explicit user instruction adapts native ordering to source-first sealing. Shell source reads/searches, import bookkeeping, hashes and report serialization are the only local operations used. No target code, compilation, security tools, tests, fuzz campaigns or symbolic execution ran; no visuals or fuzz infrastructure were generated. Native execution remains deferred until the parent seals the source first pass. This report is ready for parent sealing and **does not self-seal or authorize that next phase**.

| Native step | Source-only status | Deferred work |
|---|---|---|
| 1 — Known issues | Deferred | Slither run and detector triage |
| 2 — Special features | Applicability searches and source classification complete | Applicable native conformance/proxy checks |
| 3 — Visual inspection | Deferred | Actual generated diagrams and their inspection |
| 4 — Security properties | All 16 property records documented; P16 assessment pending S5 | Harness/configuration setup and fuzz/formal execution |
| 5 — Manual review | Privacy, ordering, crypto/randomness, DeFi/flash loans/oracles complete within source scope | Deployment/integration facts remain outside source evidence |

## Inherited conclusions preserved

The permitted SAME-CELL `attempt-01/artifacts/source-only/FIRST-PASS.md` conclusion is retained verbatim:

> Original conclusions before S6 tooling: no confirmed exploitable vulnerability established by completed source passes. Token pass retains conditional quote-semantic and prize-truthfulness leads. Guidelines pass identifies a prize-trust wording discrepancy and an unconfirmed cross-factory scope lead. Specification compliance is INCOMPLETE and supplies no verdict.

Permitted S2, S3 and S4 SOURCE reports were read as inherited records; none was edited or superseded. S1 context filenames were inventoried, but its dossier/function text was not needed. S3 L-T01 (quote semantics) and L-T02 (prize truthfulness), S4 prize-trust wording discrepancy, and S4 cross-factory scope lead keep their inherited status. New evidence below is explicitly marked S6 continuation evidence. All new source citations use the inspected snapshot's line numbering; inherited reports retain their original wording and citations. No earlier source copy comparison or reconciliation was performed.

S5 results and prior S6 reports/logs were not read. Historical audits/tests/corpora/scanner campaigns, other cells, accepted risks, external project facts, deployed contracts and configuration/lock files were not consulted. No inference about the quality or outcome of an unrun tool/test is made.

## Step 2 — Special-feature applicability

### A01 — Upgradeability / minimal proxies

Status: `proxy_review_applicable_fixed_target_no_upgrade_entry_found`. Searches: Q01, Q07, Q09.

ERC1167 clone/inherited-storage review applies. Canonical implementation is created by the factory and used by the non-deterministic clone overload. No source-visible upgrade setter, UUPS/beacon implementation or selfdestruct was located. StorageSlot's ERC1967 example and LowLevelCall delegatecall helpers are not project upgrade paths.

Evidence: `packages/contracts/src/RaffleFactory.sol:89-125`; `packages/contracts/src/Raffle.sol:155-206`; `packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:32-62`; `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:88-118`.

Deferred/unknown: slither-check-upgradeability applicability/configuration with the actual compiled proxy model, storage/initialization and bytecode checks remain deferred; no such tool was invoked.

### A02 — ERC conformance

Status: `ERC721_and_ERC165_applicable_native_conformance_pending`. Searches: Q02, Q09.

Raffle is an ERC721 ticket issuer with inherited metadata/ERC165. Both production interfaces are included in coverage; IRaffle itself does not inherit/redeclare the entire ERC721 or wrapper API. Source-path review does not certify standard conformance, especially intentional destination restrictions.

Evidence: `packages/contracts/src/Raffle.sol:28-29`; `packages/contracts/src/Raffle.sol:477-502`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:44-135`; `packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/ERC165.sol:20-24`.

Deferred/unknown: slither-check-erc for the applicable ERC721 specification, inherited method/overload/receiver verification deferred. No ERC20-issuer conformance claim.

### A03 — Third-party token integration

Status: `applicable_inherited_S3_preserved`. Searches: Q02, Q08.

Fixed external ERC20 quote and sponsor-selected ERC721 prize integrations are present. The method's token-integration recommendation is already represented by permitted same-cell S3; its L-T01/L-T02 conclusions are preserved, not rerun or rewritten. No external implementation can be inferred from the interfaces.

Evidence: `packages/contracts/src/RaffleFactory.sol:65-79`; `packages/contracts/src/RaffleFactory.sol:127-134`; `packages/contracts/src/Raffle.sol:223-235`; `packages/contracts/src/Raffle.sol:329-342`; `packages/contracts/src/Raffle.sol:395-405`; `packages/contracts/src/Raffle.sol:560-567`.

Deferred/unknown: Actual external token semantics, authenticity and deployment behavior remain unknown; no new skill, network call or token campaign invoked.

### A04 — ERC20 property generation / test framework condition

Status: `no_production_ERC20_issuer_target_test_framework_unassessed`. Searches: Q02, Q09.

The source corpus has ERC20 interfaces/consumer calls but no production ERC20 implementation for the method's ERC20 slither-prop mode. This does not make property documentation inapplicable: P01-P16 cover raffle properties.

Evidence: `packages/contracts/src/Raffle.sol:28-29`; `packages/contracts/src/RaffleFactory.sol:21`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol:9-79`.

Deferred/unknown: Truffle/tests/configuration were not inspected under source-only restrictions; no assertion that a test framework is absent. Fuzz infrastructure and all execution are deferred by user instruction.

## Step 4 — Property documentation

These are proposed concrete invariants/transition checks derived from source, not executed properties. They apply to canonical factory-created clones in reachable states. Unless a property states otherwise, accounting invariants refer to committed transaction boundaries. External token truthfulness, canonical wrapper behavior, normal EVM rollback, and representable timestamps are explicit assumptions, not conclusions from interfaces. `Paid` below is a proposed harness ghost ledger; it is not production state.

### P01 — Immutable dependencies

Status: `documented_source_supported_with_assumptions`.

**Proposed actual property.** For every successfully factory-created raffle, factory(), quoteToken(), vrfWrapper(), callbackGasLimit(), and requestConfirmations() remain fixed to its implementation/factory configuration; sponsor, sponsorRecipient, treasury, prize, reserve and endTime never change after successful initialization. Only the fixed factory implementation is cloned; no recurring call can replace these identities or configuration.

**Source evidence.** `packages/contracts/src/RaffleFactory.sol:25-42`; `packages/contracts/src/RaffleFactory.sol:65-92`; `packages/contracts/src/RaffleFactory.sol:105-125`; `packages/contracts/src/Raffle.sol:44-58`; `packages/contracts/src/Raffle.sol:155-165`; `packages/contracts/src/Raffle.sol:176-206`; `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:34-47`; `packages/contracts/src/interfaces/IRaffleFactory.sol:6-9`.

**Source reasoning.** Factory constructor installs its own Raffle implementation; Raffle constructor binds factory to deployer and quoteToken to its argument, while the base embeds the wrapper and LINK identities. Clone-specific configuration has one write path in initialize. No target-changing setter was found by Q01/Q07/Q09.

**Assumptions.** Only canonical factory-created clones are covered; an arbitrary third-party proxy pointing at the implementation is not a registered raffle. The deployment supplies authentic canonical dependencies and a usable treasury; address immutability is not immutability of external code or policy.

**Uncertainty / limits.** No deployed code, quote implementation, wrapper implementation, deployment provenance, or external governance was inspected. Code presence, six decimals, and link() return do not authenticate identity. Compiler/bytecode/storage checks are deferred.

**Proposed later check — not run.** Snapshot all identities/configuration after creation; vary every public call and callback, then compare. Create two clones and check shared code immutables but isolated mutable storage.

### P02 — Initialization

Status: `documented_source_supported_with_assumptions`.

**Proposed actual property.** The implementation rejects initialize. A fresh canonical clone accepts initialize exactly once, only from its immutable factory. Successful createRaffle produces exactly one initialized registered Active clone with consistent forward/reverse registries and validated positive reserve/future end (at most 30 days); any failed creation leaves factory counters, registrations and asset changes unchanged.

**Source evidence.** `packages/contracts/src/Raffle.sol:164-165`; `packages/contracts/src/Raffle.sol:176-206`; `packages/contracts/src/RaffleFactory.sol:97-148`; `packages/contracts/src/RaffleFactory.sol:154-185`; `packages/contracts/src/libraries/RaffleConstants.sol:29-30`; `packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:32-62`; `packages/contracts/src/interfaces/IRaffle.sol:305-308`; `packages/contracts/src/interfaces/IRaffleFactory.sol:101-104`.

**Source reasoning.** Factory validates before cloning, initializes before the prize call, records all three registry entries, and checks final escrow and Active state. initialized is written before the initialization destination queries; any revert rolls it back. The clone has no transaction gap for another caller to initialize.

**Assumptions.** Factory constructor and canonical creation path succeed under ordinary EVM transaction atomicity. Fresh clone storage starts zero; do not substitute direct implementation storage for clone storage.

**Uncertainty / limits.** initialize does not independently repeat all reserve/end/code/decimals validation; the actual property relies on the immutable canonical factory. No deployed-clone runtime, storage layout, or compiler proof was obtained.

**Proposed later check — not run.** Exercise nonfactory, repeated, implementation and failed initialization; fail at each createRaffle external boundary and compare pre/post registry state.

### P03 — Prize escrow

Status: `documented_source_supported_with_assumptions`.

**Proposed actual property.** A successful canonical creation ends Active and reports ownerOf(configured prize ID)==clone. AwaitingPrize becomes Active only on the configured prize contract's callback with exact sponsor/from, factory/operator, and token ID. Under an honest transferable ERC721, the configured prize remains escrowed until one authorized terminal release, whose reported final owner equals the intended recipient.

**Source evidence.** `packages/contracts/src/RaffleFactory.sol:123-134`; `packages/contracts/src/RaffleFactory.sol:154-178`; `packages/contracts/src/Raffle.sol:416-431`; `packages/contracts/src/Raffle.sol:329-337`; `packages/contracts/src/Raffle.sol:395-407`; `packages/contracts/src/interfaces/IRaffle.sol:12-15`; `packages/contracts/src/interfaces/IRaffleFactory.sol:93-104`.

**Source reasoning.** Factory requires deployed prize code and claimed ERC721 support, safe-transfers the exact prize, then reads owner and raffle status. Winner/sponsor prize paths write prizeClaimed before transfer and verify ownerOf afterward.

**Assumptions.** Prize token truthfully implements ownership and transfers and cannot arbitrarily confiscate the escrowed token. Sponsor holds/authorizes the selected prize; safeTransferFrom semantics are truthful.

**Uncertainty / limits.** An arbitrary prize contract can lie in supportsInterface, callback and ownerOf. Neither interface screening nor a post-transfer query proves economic value or future transferability. Inherited L-T02 and the DESIGN/interface trust discrepancy remain conditional/documentary, not a new exploit.

**Proposed later check — not run.** Model honest prizes separately from adversarial callbacks, lying ownerOf, missing callback, wrong callback fields, transfer reverts and delivery-no-op cases; distinguish reported ownership from actual external semantics.

### P04 — Quote-token semantics

Status: `documented_source_supported_with_assumptions`.

**Proposed actual property.** For an entry purchase of n>0 that commits, the raffle credits exactly n*1,000,000 nominal units; for each successful quote claim it debits and sends exactly that nominal claim. Under exact fee-free, non-rebasing token semantics, actual clone quote balance is at least accountedQuoteBalance at transaction boundaries; equality holds only when there is no unaccounted surplus. Direct token donations never increase sale counts or liabilities.

**Source evidence.** `packages/contracts/src/RaffleFactory.sol:59-79`; `packages/contracts/src/Raffle.sol:223-235`; `packages/contracts/src/Raffle.sol:468-475`; `packages/contracts/src/Raffle.sol:560-567`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:33-47`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:176-244`; `packages/contracts/src/interfaces/IRaffle.sol:12-15`; `packages/contracts/src/libraries/RaffleConstants.sol:20-24`.

**Source reasoning.** Accounting follows requested amounts; there is no incoming or outgoing balance-delta verification. SafeERC20 propagates call failure and accepts a true response or successful empty response from code-bearing tokens; it does not establish transferred quantities.

**Assumptions.** Canonical quote identity is verified externally, balances do not rebase/confiscate, and successful transfers move the nominal amount. Recipient or token restrictions may revert; safety-on-failure does not imply eventual claim availability.

**Uncertainty / limits.** Inherited L-T01 remains an external-dependency condition, not a confirmed in-model bug. Exact token semantics and deployed pause/blocklist/upgrade features are unknown. A malicious token's successful no-op is not a detected delivery failure.

**Proposed later check — not run.** Maintain a nominal-liability ghost ledger with exact-transfer token model; separately use fee/no-op/rebase/false/empty-return/reverting models to expose where the assumption is required.

### P05 — Bearer authorization

Status: `documented_source_supported_with_assumptions`.

**Proposed actual property.** At redemption/refund entry, msg.sender must be the current owner of each claimed ticket; original buyer, sponsor, settler, previous owner and approved operator alone cannot directly claim. Settlement never freezes an owner or transfers assets. An authorized ERC721 transfer moves the future claim with the ticket; successful redemption records the then-current owner in winnerRecipient.

**Source evidence.** `packages/contracts/src/Raffle.sol:304-346`; `packages/contracts/src/Raffle.sol:349-365`; `packages/contracts/src/Raffle.sol:533-558`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:93-135`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:164-187`; `packages/contracts/node_modules/@openzeppelin/contracts/utils/Context.sol:17-19`; `packages/contracts/src/interfaces/IRaffle.sol:326-344`.

**Source reasoning.** Redemption reads ownerOf only after range settlement and compares msg.sender; any failed comparison reverts the enclosing settlement. Refund loops perform the same owner check. Settlement stores the winning ticket ID, not its current owner.

**Assumptions.** ERC721 owner and approval storage have only the inspected update paths; caller controls its current address.

**Uncertainty / limits.** An approved operator can transfer a ticket to itself and then redeem as owner, which is ordinary transferable-token authority. No promise is made that an approval cannot indirectly enable claiming. Receiver callbacks can further transfer tickets.

**Proposed later check — not run.** Transfer before/after callback and settlement; attempt direct claims as buyer, settler, operator and former owner; then transfer via an approved operator and verify only the new owner can claim.

### P06 — Entry ranges

Status: `documented_source_supported_with_assumptions`.

**Proposed actual property.** Historical ranges for ticket IDs 1..ticketCount form a non-overlapping contiguous partition of [1,totalEntries]. A purchase of n appends [oldTotal+1,oldTotal+n], increments ticketCount once and never reuses an ID; 0<=ticketCount<=totalEntries<=2^128-1. Transfers/burns preserve ranges and lifetime counters. With a valid winningEntry, exactly one minted historical range contains it; unmapped IDs return [0,0] and cannot settle.

**Source evidence.** `packages/contracts/src/Raffle.sol:85-91`; `packages/contracts/src/Raffle.sol:138-139`; `packages/contracts/src/Raffle.sol:215-235`; `packages/contracts/src/Raffle.sol:451-455`; `packages/contracts/src/Raffle.sol:518-521`; `packages/contracts/src/Raffle.sol:579-585`; `packages/contracts/src/interfaces/IRaffle.sol:368-373`; `packages/contracts/src/interfaces/IRaffle.sol:450-456`.

**Source reasoning.** Every purchase has n>=1 and an explicit uint128 total cap before incrementing counters. Thus ticketCount cannot overflow independently of the entry cap. Fresh stored intervals are the only range writes, and no claim deletes their history. Maximum nominal gross is below 2^148.

**Assumptions.** No storage mutation outside inspected code; checks apply to reachable canonical-clone states rather than arbitrary fuzzed storage.

**Uncertainty / limits.** There is no on-chain range enumeration; a future harness must track minted IDs. Historical range existence does not establish current ERC721 ownership after a burn.

**Proposed later check — not run.** Exercise n=1, large n, remaining-cap n, n=0 and cap+1; compare partitions and unique winning-range proofs across transfers and refunds.

### P07 — Sale and draw windows

Status: `documented_source_supported_with_assumptions`.

**Proposed actual property.** Purchases commit only while Active and timestamp<endTime. A sold raffle requests once only in Active with endTime<=timestamp<endTime+2 days; success fixes Drawing, drawRequestedAt and the returned request ID. Successful requestDraw spends paidPrice<=msg.value and refunds exactly msg.value-paidPrice to the caller, with zero net use of any pre-existing native surplus; a failing refund/request reverts the entire request.

**Source evidence.** `packages/contracts/src/Raffle.sol:209-237`; `packages/contracts/src/Raffle.sol:240-273`; `packages/contracts/src/Raffle.sol:436-443`; `packages/contracts/src/Raffle.sol:458-465`; `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:76-89`; `packages/contracts/src/libraries/RaffleConstants.sol:29-42`; `packages/contracts/src/interfaces/IRaffle.sol:316-320`.

**Source reasoning.** Sales and draw requests use complementary inequalities at endTime. Drawing is installed before the wrapper call; the in-flight flag protects incomplete request state. The second fee calculation is used as actual paidPrice and checked even if the first quote differed. Caller refund uses a checked native call.

**Assumptions.** Timestamp fits uint64 for stored timestamps and advances under the chain's normal rules. Wrapper returns a valid usable request identifier and accepts the configured native mode, gas and confirmations. Native conservation excludes independent forced transfers during the transaction.

**Uncertainty / limits.** An off-chain quote is not a reserved fee. The full supplied msg.value is the effective spending ceiling; the wrapper price/liveness and 300,000-gas sufficiency are unmeasured. At remote timestamps >=2^64, timestamp casts are not covered.

**Proposed later check — not run.** Use end-1/end/end+timeout-1/deadline, no entries, competing requesters, changing quote/paid fee, forced native surplus, exact/excess payment and rejecting refund receiver.

### P08 — Randomness and callbacks

Status: `documented_source_supported_with_assumptions`.

**Proposed actual property.** Only the immutable wrapper can enter rawFulfillRandomWords. A decoded callback changes winner state only when not in-flight, status==Drawing, request ID matches, length==1 and timestamp<callbackDeadline. Accepted callback sets winningEntry=(word mod totalEntries)+1 in [1,totalEntries], resolvedAt and NftWon iff totalEntries>=reserveEntries; it does not transfer assets, settle liabilities, read ownership, or change totalEntries. No second callback can overwrite the result.

**Source evidence.** `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:101-107`; `packages/contracts/src/Raffle.sol:249-260`; `packages/contracts/src/Raffle.sol:504-524`; `packages/contracts/src/libraries/RaffleConstants.sol:38-42`; `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol:7-25`; `packages/contracts/src/interfaces/IRaffle.sol:98-108`.

**Source reasoning.** Drawing can be reached only after positive sales and sale closure. Wrong/late/duplicate/in-flight/decoded wrong-length callbacks emit ignored events without economic-state changes; unauthenticated callers revert in the base. The selector-tagged ExtraArgs encodes nativePayment=true. No timestamp/blockhash entropy or custom signature verifier was found.

**Assumptions.** Canonical wrapper/coordinator provides unpredictable, unbiased 256-bit words and authentic request routing; local sender authentication is not a proof of VRF validity. One successful asynchronous request does not guarantee a timely callback.

**Uncertainty / limits.** Wrapper/coordinator/proof implementation and deployed settings are absent. Modulo sampling is not perfectly uniform for arbitrary N: outcome preimage counts differ by at most one out of 2^256. For N<=2^128-1, total variation from uniform is r(N-r)/(N*2^256)<=N/(4*2^256)<2^-130. No practical exploit is established by that arithmetic. Malformed ABI reverts before the handler.

**Proposed later check — not run.** Try unauthorized, in-flight, wrong-ID, zero/two-word, repeated and deadline callbacks; test words 0 and 2^256-1 and N near cap. Separate authentication/invariants from external randomness-quality assertions.

### P09 — Refund activation and timeouts

Status: `documented_source_supported_with_assumptions`.

**Proposed actual property.** Active empty raffles may enter Refunding before end only at sponsor request and at/after end by anyone. Active sold raffles may do so only at/after end+2 days; Drawing raffles only at/after drawRequestedAt+2 days. Transition moves the entire unsettledPot to remainingRefundLiability once and zeroes unsettledPot. Refunding never returns to a sale or winner state; late callbacks cannot revive it.

**Source evidence.** `packages/contracts/src/Raffle.sol:276-301`; `packages/contracts/src/Raffle.sol:458-465`; `packages/contracts/src/Raffle.sol:509-524`; `packages/contracts/src/libraries/RaffleConstants.sol:32-36`; `packages/contracts/src/interfaces/IRaffle.sol:20-34`; `packages/contracts/src/interfaces/IRaffle.sol:322-324`.

**Source reasoning.** The callback accepts strictly before its deadline and refunds permit at/after it, so both cannot be valid at the same timestamp. Sold request expiry is also exclusive for requests and inclusive for refunds. Winner states reject enableRefunds.

**Assumptions.** Normal timestamp domain and committed canonical lifecycle transitions. Someone submits the enabling transaction and owners subsequently submit their claims.

**Uncertainty / limits.** Availability is permissionless eligibility, not automatic execution. No refunds exist after a timely winner result merely because external prize delivery later fails. This preserves inherited prize availability/trust limits.

**Proposed later check — not run.** Test each state at deadline-1/deadline/deadline+1, sponsor versus outsider on empty raffles, competing cancellation/first purchase and late callbacks after refund activation.

### P10 — Payout conservation

Status: `documented_source_supported_with_assumptions`.

**Proposed actual property.** Let G=totalEntries*ENTRY_PRICE, A=unsettledPot+remainingRefundLiability+winnerProceeds+sponsorProceeds+protocolFees, and Paid be cumulative nominal successful quote claims/refunds. At committed transaction boundaries A+Paid==G. Settlement preserves A, sets unsettledPot=0, allocates F=floor(G*500/10000), cash W=floor(G*8000/10000) only in CashWon (otherwise W=0), and sponsor S=G-F-W. Refund activation preserves A. Each successful payout decreases A by exactly its paid nominal amount.

**Source evidence.** `packages/contracts/src/Raffle.sol:223-235`; `packages/contracts/src/Raffle.sol:296-300`; `packages/contracts/src/Raffle.sol:339-342`; `packages/contracts/src/Raffle.sol:367-390`; `packages/contracts/src/Raffle.sol:468-475`; `packages/contracts/src/Raffle.sol:533-558`; `packages/contracts/src/libraries/RaffleConstants.sol:7-24`; `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:37-46`; `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:199-277`; `packages/contracts/src/interfaces/IRaffle.sol:383-390`.

**Source reasoning.** One-time settlement transfers nominal pot into disjoint claims and assigns the remainder to sponsor. Price 1,000,000 is divisible by 10,000, so for reachable undonated nominal pots the 5% and 80% allocations have no raw-unit dust at all. G<2^148 and G*8000<2^161, so the reachable mulDiv product fits 256 bits.

**Assumptions.** Paid tracks successful protocol outflows only and is a harness ghost value, not production storage. No arbitrary storage injection; actual asset sufficiency additionally requires P04 token semantics.

**Uncertainty / limits.** This proves the form of nominal conservation by source reasoning, not executed verification. Do not require contract token balance==G after claims or count donations as sales. The invariant is stated at transaction boundaries, not arbitrary callback observations during partial updates.

**Proposed later check — not run.** Maintain a per-clone ghost ledger through interleaved independent claims, failed calls, refunds and donations; verify conservation and exact 95/5 or 80/15/5 allocation at settlement.

### P11 — Single claims

Status: `documented_source_supported_with_assumptions`.

**Proposed actual property.** Each raffle successfully settles at most once, successfully redeems its winning ticket at most once, and successfully delivers the configured prize at most once across winner/sponsor routes. Every sponsor/treasury/winner quote allocation is consumed at most once. Claims to fixed recipients are permissionless to trigger but cannot be redirected by the caller. Claim failure preserves that claim for later retry.

**Source evidence.** `packages/contracts/src/Raffle.sol:309-346`; `packages/contracts/src/Raffle.sol:375-407`; `packages/contracts/src/Raffle.sol:533-558`; `packages/contracts/src/interfaces/IRaffle.sol:281-301`; `packages/contracts/src/interfaces/IRaffle.sol:333-355`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:303-307`.

**Source reasoning.** settlementComplete, winnerRedeemed and prizeClaimed guard one-time transitions. Payout variables are zeroed before transfers, winner claims burn, and refund/winner branches are mutually exclusive. No refill path exists after one-time settlement. Prize return in CashWon/Refunding is independent of quote claims.

**Assumptions.** External transfers either truthfully succeed or revert/produce detectable failure; P03/P04 qualify delivery claims. Terminal status and allocations remain immutable except consumption.

**Uncertainty / limits.** Failure of a separate earlier/later payout is not global rollback of already committed claims. Sponsor and treasury can be paid before winner redemption; blocked winner delivery does not unwind their completed transactions.

**Proposed later check — not run.** Permute all release orders; repeat each release/settlement/redemption, mix same recipients, and fail individual external sends while comparing only that transaction's state.

### P12 — Refunds and burns

Status: `documented_source_supported_with_assumptions`.

**Proposed actual property.** In Refunding, a successful refund batch contains 1..100 existing tickets currently owned by msg.sender, burns each exactly once, pays sum(last-first+1)*ENTRY_PRICE, and decreases remainingRefundLiability by precisely that amount. Remaining liability equals the nominal value of all unburned refund tickets. Duplicate, absent, previously burned or foreign-owned IDs revert the entire batch. Historical ranges, totalEntries and ticketCount remain unchanged.

**Source evidence.** `packages/contracts/src/Raffle.sol:349-372`; `packages/contracts/src/Raffle.sol:451-455`; `packages/contracts/src/libraries/RaffleConstants.sol:26-27`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:216-245`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:303-307`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:426-432`; `packages/contracts/src/interfaces/IRaffle.sol:340-344`.

**Source reasoning.** Ownership lookup precedes each burn, so the second occurrence of a duplicate fails _requireOwned and rolls back earlier burns. Batch loop is bounded by tickets, not represented entries. Aggregate refund entries cannot exceed lifetime entries on valid unique IDs.

**Assumptions.** No prior winner redemption can coexist with Refunding; ERC721 burns clear ownership and approvals as inspected. Actual quote received requires P04; current holder may differ from buyer.

**Uncertainty / limits.** A 100-ticket bound does not prove a concrete gas limit. Ranges remain accessible after burns but are not redeemable ownership. Contract owners need a way to invoke refundTickets.

**Proposed later check — not run.** Use 0/1/100/101 ticket batches; duplicate early/late, nonexistent and foreign IDs; quote-send failures; owner transfers followed by refunds and repeated refunds.

### P13 — Rollback and reentrancy

Status: `documented_source_supported_with_assumptions`.

**Proposed actual property.** A guarded economic call that reverts rolls back its entire call subtree, including prior nested external state changes; if that revert propagates to the transaction top level, the whole transaction rolls back. During a guarded function, other functions using that same instance's guard cannot execute recursively. Successful reentrant unguarded ERC721 actions must still satisfy ownership/destination checks and cannot duplicate quote/NFT liabilities. Fulfillment during the wrapper request call is ignored until the request ID is persisted.

**Source evidence.** `packages/contracts/src/RaffleFactory.sol:97-134`; `packages/contracts/src/Raffle.sol:209-273`; `packages/contracts/src/Raffle.sol:309-407`; `packages/contracts/src/Raffle.sol:497-524`; `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:35-59`; `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:69-118`; `packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:90-97`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:128-135`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:287-307`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:25-49`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:176-244`.

**Source reasoning.** The guard rejects only ENTERED==2, so initial clone guard value zero still blocks recursive entry after the first function writes 2 and later resets to 1. Claim effects precede external sends; SafeERC20, ERC721 receiver rejection, native refund failure and owner postcheck failures bubble reverts. initialize sets initialized before external view queries; prize receiver checks its exact phase.

**Assumptions.** Standard EVM nested-call/transaction rollback and the supplied dependency source behavior. External tokens cannot create irreversible off-chain side effects that EVM rollback would undo.

**Uncertainty / limits.** Inherited transfers/approvals, raw fulfillment and onERC721Received are not blanket nonReentrant. A safe-mint recipient may transfer the ticket during its callback, so ownerOf(ticketId)==original recipient on return is NOT a valid invariant. During an ordinary inherited safeTransferFrom with no guard already entered, its new owner may legitimately redeem/refund/burn inside the receiver callback. Read-only intermediate observations are possible. No dynamic adversarial-callback campaign ran. A caller that catches a low-level revert can retain unrelated outer-transaction effects; rollback assertions must use the correct call boundary.

**Proposed later check — not run.** Exercise quote/prize/receiver/native-refund callback edges; compare reverted whole transactions; permit authorized nested transfers and ordinary safe-transfer receiver claims, while checking ledger and one-time claims rather than universal callback rejection.

### P14 — Destinations and isolation

Status: `documented_source_supported_with_assumptions`.

**Proposed actual property.** At each screening call, nonzero ticket destinations and quote payout recipients must not equal self, canonical factory, quote token, wrapper, configured prize token, factory implementation, or a code-bearing raffle registered by that same factory. Initialization screens sponsor, sponsorRecipient and treasury; creation also screens prize selection and sponsorRecipient. Burns to zero remain allowed. Payout callers cannot choose alternate recipients.

**Source evidence.** `packages/contracts/src/Raffle.sol:181-195`; `packages/contracts/src/Raffle.sol:497-502`; `packages/contracts/src/Raffle.sol:560-567`; `packages/contracts/src/Raffle.sol:587-605`; `packages/contracts/src/RaffleFactory.sol:80-91`; `packages/contracts/src/RaffleFactory.sol:154-169`; `packages/contracts/src/interfaces/IRaffle.sol:225-227`; `packages/contracts/src/interfaces/IRaffle.sol:266-268`; `packages/contracts/src/interfaces/IRaffleFactory.sol:136-139`.

**Source reasoning.** All ticket updates funnel through the override; quote transfers share _transferQuote. Registry screening is explicitly against IRaffleFactory(factory), and skips the registry for code-less addresses. Fixed prize recipients derive from already-screened initialization or ticket ownership.

**Assumptions.** Canonical factory registry is truthful and its clone addresses retain code. A recipient outside the enumerated set is responsible for being able to operate its ticket and receive/recover assets.

**Uncertainty / limits.** The property is local to same-factory plumbing, not universal all-contract recoverability or all-factory isolation. Cross-factory clones and arbitrary incapable contracts are not generally recognized. Outgoing prize uses transferFrom rather than receiver acceptance. Inherited cross-factory scope lead stays unresolved; DESIGN's broader wording is reserved for S5.

**Proposed later check — not run.** Exercise all forbidden addresses through buy/mint/transfer/quote/creation, same-factory clones, another factory's clone, code-less and contract recipients. Characterize acceptance separately from a specification failure verdict.

### P15 — ERC721 and clone inheritance

Status: `documented_source_supported_with_assumptions`.

**Proposed actual property.** Canonical clones preserve inherited ERC721 owner/approval/balance rules and receiver checks while routing mint/transfer/burn through the raffle destination override. Transfers/burns clear per-token approval; absent/burned ownerOf and tokenURI revert. name/symbol remain fixed despite skipped ERC721 constructor storage on clones; valid tokenURI returns empty with the inherited empty base URI. ERC165 reports IERC165, IERC721 and metadata support. Clones share fixed implementation code/immutables but not token/lifecycle/guard storage.

**Source evidence.** `packages/contracts/src/Raffle.sol:28-29`; `packages/contracts/src/Raffle.sol:155-165`; `packages/contracts/src/Raffle.sol:477-502`; `packages/contracts/src/RaffleFactory.sol:89-91`; `packages/contracts/src/RaffleFactory.sol:105-125`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:19-135`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:164-245`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:259-307`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:383-432`; `packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/ERC165.sol:20-24`; `packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:32-62`; `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:88-118`.

**Source reasoning.** The project overrides _update only to screen destinations then calls super. Constant metadata overrides avoid relying on implementation constructor strings. Factory uses only the unsalted clone(address) path, which embeds the fixed implementation and does not expose an upgrade slot. Inherited wrapper getters/raw callback are part of the actual surface even though IRaffle does not redeclare them all.

**Assumptions.** Compiled inheritance/dispatch implements the inspected Solidity semantics; ordinary minimal-proxy delegatecall storage isolation.

**Uncertainty / limits.** No slither-check-erc, compiler linearization/storage inspection, runtime dispatch test or bytecode check occurred. Destination restrictions intentionally qualify generic unrestricted-transfer expectations; this is not full ERC721 conformance certification. Imported unused extension/helper functions are not additional production entrypoints.

**Proposed later check — not run.** After sealing, check supported ERC721 interfaces and inherited overloads, approvals/clearing, safe receiver failures, empty metadata, two-clone state isolation and guard initialization with actual compiled code.

### P16 — Specification alignment — S5 pending

Status: `documented_assessment_pending_S5`.

**Proposed actual property.** After the independently proceeding S5 is available, each normative DESIGN/interface requirement must map to an actual source transition/property, explicit assumption, or supported mismatch. The candidate requirements include atomic escrow, fixed economics, owner-controlled burn/delivery rollback, deadline inequalities, storage-only settlement and isolation. Until then, property documentation must not present full specification compliance as established.

**Source evidence.** `DESIGN.md:1-4`; `packages/contracts/src/interfaces/IRaffle.sol:12-15`; `packages/contracts/src/interfaces/IRaffle.sol:305-355`; `packages/contracts/src/interfaces/IRaffle.sol:375-390`; `packages/contracts/src/interfaces/IRaffleFactory.sol:6-9`; `packages/contracts/src/Raffle.sol:533-567`; `packages/contracts/src/Raffle.sol:587-605`.

**Source reasoning.** P01-P15 express the source-side obligations and limits for later comparison. The permitted FIRST-PASS explicitly says specification compliance is INCOMPLETE and supplies no verdict; this continuation preserves that statement. Existing prize-trust wording discrepancy and cross-factory scope lead are inherited, not newly resolved here.

**Assumptions.** S5 remains independent and its result will be consumed only under later parent authorization. DESIGN is a candidate requirement source; implementation establishes actual behavior.

**Uncertainty / limits.** S5 result not read, inferred or claimed. P16 is documented with pending assessment, not passed or completed spec verification. No reconciliation was performed.

**Proposed later check — not run.** Parent may map the independently sealed S5 requirements to these exact evidence references and proposed properties in a later authorized phase.

No executable property harness, test source, configuration, or lockfile was created. When the parent later permits execution, the concrete checks above need separate honest-dependency and adversarial-dependency models, per-clone nominal ledgers, timestamp-boundary actions, and receiver/callback scenarios. An invariant falsified only by violating its explicit external trust assumption must be recorded as such.

## Step 5 — Manual source review

### M01 — Privacy

Status: `source_review_complete_no_hidden_secret_claim`. Searches: Q03, Q05.

Private _ticketRanges is exposed through ticketRange and purchase events; ticket ownership, purchase amounts, raffle parameters and winning entry are observable. Random words are supplied as public transaction calldata on fulfillment; privacy is not what prevents advance selection. No secret-dependent raffle branch, commitment/reveal protocol or confidentiality guarantee was found. Library salt/private/keccak hits belong to unused deterministic clone helpers, formatting or storage constants.

**Assumptions / limits.** Unpredictability before fulfillment depends on the external VRF path. No participant anonymity, private mempool behavior or frontend secrecy was assessed. Absence of local commit-reveal is not a finding by itself.

**Evidence.** `packages/contracts/src/Raffle.sol:138-142`; `packages/contracts/src/Raffle.sol:235-236`; `packages/contracts/src/Raffle.sol:451-455`; `packages/contracts/src/Raffle.sol:518-523`; `packages/contracts/src/interfaces/IRaffle.sol:64-108`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:60-63`; `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:101-107`.

### M02 — Ordering and front-running

Status: `source_review_complete_ordering_dependencies_documented`. Searches: Q04, Q02, Q08.

Pending buys can change assigned intervals, final ownership probabilities and whether reserve is met; buyer pays fixed per-entry price but cannot constrain final totalEntries or branch. Purchasing is forbidden at/after sale end, before requests become valid, so a local buyer cannot add entries after an accepted draw request. Empty-raffle sponsor cancellation and first purchase race by ordering: cancellation first makes buy fail; purchase first removes the pre-end empty-cancellation condition. At draw/callback deadlines the inequalities are disjoint. Front-running permissionless settlement cannot redirect ownership or payouts, though the losing duplicate settlement reverts. Ticket transfer/redeem races follow current ownership and ordinary granted ERC721 authority. Off-chain VRF price quotes can become stale; msg.value bounds the actual fee and excess is refunded atomically. Competing requesters can waste revert gas but cannot create two committed requests.

**Assumptions / limits.** No fixed-odds or branch guarantee exists in buyEntries. Claiming one from an off-chain quote would be a conditional integration error, not a source-confirmed exploit. Block inclusion/censorship can affect eligibility at boundaries; no external MEV strategy, marketplace or frontend behavior was examined. Authorized operators can move bearer claims before revocation.

**Evidence.** `packages/contracts/src/Raffle.sol:209-237`; `packages/contracts/src/Raffle.sol:240-301`; `packages/contracts/src/Raffle.sol:309-342`; `packages/contracts/src/Raffle.sol:436-465`; `packages/contracts/src/Raffle.sol:509-558`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:93-135`; `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:23-33`.

### M03 — Cryptography and randomness

Status: `source_review_complete_external_randomness_trust_retained`. Searches: Q05, Q07, Q08.

Local authentication is exact msg.sender equality with the immutable wrapper. Winning entry depends on one supplied word and frozen entry count, not timestamp/blockhash. A successful request cannot be rerolled locally; terminal/late/duplicate callback guards prevent rewriting the outcome. The application contains no signature/permit/replay-nonce scheme, ecrecover, tx.origin authorization or dynamic packed-message hash. ExtraArgs uses a fixed selector tag and ABI encoding. Imported CREATE2 hashes, address checksum/bytes equality helpers, and Math modExp/packed precompile arguments are not raffle authentication or randomness paths. Modulo output preimage counts differ by at most one; P08 gives the explicit negligible-bias bound instead of claiming perfect uniformity.

**Assumptions / limits.** No VRF proof verification, wrapper/coordinator implementation, key security, live configuration or callback gas measurement was available. Timely fulfillment, honest randomness and no selective withholding remain external assumptions; timeout refunds are the documented liveness fallback.

**Evidence.** `packages/contracts/src/Raffle.sol:249-260`; `packages/contracts/src/Raffle.sol:504-524`; `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:101-107`; `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol:7-25`; `packages/contracts/src/libraries/RaffleConstants.sol:38-42`; `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:393-473`.

### M04 — DeFi, flash loans and oracles

Status: `source_review_complete_no_direct_AMM_lending_path_found`. Searches: Q06, Q08, Q07, Q09.

No project AMM swap, lending/borrowing, reserve-price read, price-feed query, flash-loan callback or balance-based vote/reward input was located. Byte swaps and an Uniswap credit in library comments are not DeFi integrations. Entry price and payout ratios are constants; donation/temporary balance changes do not alter totalEntries or nominal liabilities. A buy made before end cannot also draw/redeem that newly purchased claim in the same transaction under one timestamp: request requires timestamp>=end while buy requires timestamp<end. Existing matured bearer claims can be acquired/redeemed by external integrations, but this source supplies no flash-borrow callback or duplicated claim path. There IS an external oracle/service boundary: wrapper fee quoting plus VRF; the wrapper interface declares linkNativeFeed although Raffle does not call it.

**Assumptions / limits.** Do not conclude 'no oracle risk' or 'flash loans impossible.' Wrapper pricing/feed/proof internals and external credit/marketplace arrangements are absent. Fee failure, bad randomness or withholding are dependency/liveness assumptions; canonical quote semantics remain inherited L-T01.

**Evidence.** `packages/contracts/src/Raffle.sol:215-257`; `packages/contracts/src/Raffle.sol:436-443`; `packages/contracts/src/Raffle.sol:468-475`; `packages/contracts/src/Raffle.sol:518-521`; `packages/contracts/src/Raffle.sol:533-558`; `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:23-33`; `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:61-82`; `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:76-89`.

## Explicit source-search coverage

All searches used read-only `rg -n` against `target/packages/contracts/src` and `target/packages/contracts/node_modules`, restricted to `*.sol`: the five production files plus the 31 reachable dependencies. No tests/configuration/history directories were searched. Matching line counts include comments and interfaces; they are search coverage, not vulnerability counts. Q07 returned exit 1 because there were no matches, not because of a tool failure. Full commands and per-file matched line numbers are retained in `coverage.json`.

| Search | Matched lines | Interpretation |
|---|---:|---|
| Q01 | 140 | Proxy/storage/initialization matches include fixed Clones path and comments/unused helpers; no mutable upgrade route established. |
| Q02 | 223 | ERC721 issuer and external ERC20/ERC721 calls confirmed; approval/1363/LINK interface hits do not imply production allowance or hook use. |
| Q03 | 79 | Private ranges are explicitly viewable/evented; no secret, commitment or reveal-dependent protocol logic found. |
| Q04 | 105 | Timing, fixed reserve, transfers and current-owner claims are ordering-sensitive; fee quote/timeout and cancellation boundaries reviewed. |
| Q05 | 37 | VRF word/request guard and modulo mapping found; library hashes and packed encodings classified by reachability; no application signature or block-entropy path found. |
| Q06 | 33 | Native wrapper fee functions and payout math found; no direct AMM/lending/flash callback. Byte swaps/Uniswap attribution are false-positive DeFi matches. |
| Q07 | 0 | No matches for the enumerated upgrade/signature/block-entropy/flash/oracle/min-output symbols in all 36 Solidity files. This negative lexical evidence is bounded and corroborated by call-path review. |
| Q08 | 28 | All matched external-call/assembly boundaries classified: quote/prize/receiver/native fee/refund and immutable link lookup; linkNativeFeed declaration and unused Math/LowLevelCall helpers separated. |
| Q09 | 55 | Declarations show two production contracts, two production interfaces, one constants library, inherited ERC721 and wrapper base; no production ERC20 issuer or alternative clone invocation. |

Reproducible commands actually used (source searches only):

```sh
rg -n -i '\b(upgrade|upgradeTo|upgradeToAndCall|UUPS|ERC1967|TransparentUpgradeableProxy|BeaconProxy|delegatecall|selfdestruct|Clones|clone|initializer|initialize|implementation|StorageSlot)\b' target/packages/contracts/src target/packages/contracts/node_modules -g '*.sol'
rg -n -i '\b(ERC20|IERC20|ERC721|IERC721|IERC165|supportsInterface|safeTransfer|safeTransferFrom|transferFrom|transfer|balanceOf|approve|allowance|decimals|slither-prop|Truffle)\b' target/packages/contracts/src target/packages/contracts/node_modules -g '*.sol'
rg -n -i '\b(private|secret|commit|commitment|reveal|password|salt|encrypted|encrypt|TicketPurchased|RaffleResolved)\b' target/packages/contracts/src target/packages/contracts/node_modules -g '*.sol'
rg -n -i '\b(block\.timestamp|tx\.gasprice|deadline|endTime|reserveEntries|slippage|minOut|amountOutMin|maxFee|requestDraw|settleWinningTicket|redeemWinningTicket|approve|transferFrom)\b' target/packages/contracts/src target/packages/contracts/node_modules -g '*.sol'
rg -n -i '\b(blockhash|prevrandao|difficulty|randomWords|randomness|vrfRequestId|ecrecover|ECDSA|signature|nonce|permit|keccak256|sha256|encodePacked|tx\.origin)\b' target/packages/contracts/src target/packages/contracts/node_modules -g '*.sol'
rg -n -i '\b(oracle|AggregatorV3|latestRoundData|latestAnswer|getReserves|TWAP|Uniswap|swap|flashLoan|flashloan|flashMint|borrow|lending|vault|deposit|withdraw|calculateRequestPriceNative|estimateRequestPriceNative|balanceOf|mulDiv)\b' target/packages/contracts/src target/packages/contracts/node_modules -g '*.sol'
rg -n -i '\b(upgradeTo|upgradeToAndCall|_authorizeUpgrade|ERC1967Proxy|UUPSUpgradeable|TransparentUpgradeableProxy|UpgradeableBeacon|selfdestruct|tx\.origin|ecrecover|ECDSA|permit|blockhash|prevrandao|difficulty|flashLoan|flashMint|latestRoundData|latestAnswer|getReserves|AggregatorV3|amountOutMin|minOut)\b' target/packages/contracts/src target/packages/contracts/node_modules -g '*.sol'
rg -n 'linkNativeFeed|\.call\b|\.delegatecall\b|\.staticcall\b|call\(gas|staticcall\(gas|delegatecall\(gas|\.safeTransfer|\.transferFrom|\.ownerOf|\.balanceOf|requestRandomWordsInNative|\.link\(' target/packages/contracts/src target/packages/contracts/node_modules -g '*.sol'
rg -n '^(abstract )?contract |^interface |^library |function (name|symbol|tokenURI|supportsInterface)|Clones\.' target/packages/contracts/src target/packages/contracts/node_modules -g '*.sol'
```

Negative searches are bounded lexical evidence and were paired with actual call-path reads. In particular, `linkNativeFeed` is a wrapper interface declaration, inherited token transfers are real entrypoints, and unused LowLevelCall/Math/Create2 helpers are not promoted to production external calls.

## New S6 continuation evidence

### S6-N01 — Callback-safe properties must allow valid bearer actions

Classification: `new_continuation_source_observation_not_finding`; properties P05, P13, P15.

Safe-mint ownership need not remain with the original recipient after its callback, and ordinary inherited safe-transfer receivers can claim/burn while no economic guard is already entered. The appropriate assertions are authorization, conservation and single use, not a blanket ban on callbacks.

Evidence: `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:93-135`; `packages/contracts/src/Raffle.sol:230-236`; `packages/contracts/src/Raffle.sol:309-369`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:287-290`.

### S6-N02 — Exact nominal allocation and bounded modulo bias

Classification: `new_continuation_source_arithmetic_observation_not_finding`; properties P06, P08, P10.

Reachable pots are multiples of 1,000,000, so 5% and 80% produce exact raw-unit allocations; current cap also puts mulDiv products below 2^161. Modulo randomness is extremely close to uniform under a uniform 256-bit source, but not exactly uniform for all entry counts.

Evidence: `packages/contracts/src/libraries/RaffleConstants.sol:11-24`; `packages/contracts/src/Raffle.sol:219-233`; `packages/contracts/src/Raffle.sol:518-521`; `packages/contracts/src/Raffle.sol:539-555`.

### S6-L01 — A fixed entry-price quote does not fix odds or reserve outcome

Classification: `new_continuation_conditional_integration_lead_not_confirmed_bug`; properties P06, P07, P08.

A pending purchase can be included after other purchases; the transaction has no maxTotalEntries or required-result condition. If an integration represents observed odds/reserve branch as guaranteed, transaction ordering can violate that representation. No such integration or source requirement was examined; no exploit/severity is assigned.

Evidence: `packages/contracts/src/Raffle.sol:209-237`; `packages/contracts/src/Raffle.sol:518-521`.

Follow-up, only when separately authorized: When separately authorized, check transaction/UI semantics for stale odds and branch promises. Do not modify this frozen source or promote this conditional lead to a confirmed finding.

### S6-N03 — Oracle boundary exists even without a direct AMM/feed query

Classification: `new_continuation_applicability_clarification_not_finding`; properties P01, P07, P08.

The fee service and authenticated randomness remain external dependencies. linkNativeFeed is an interface declaration, not an actual project price-feed call; no wrapper/feed implementation or configuration result is claimed.

Evidence: `packages/contracts/src/Raffle.sol:436-443`; `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:74-82`.

These records add source reasoning and a conditional integration lead; they do not rewrite inherited conclusions or assign a new vulnerability severity. No new confirmed exploit, dynamic reproduction, deployed-token behavior, tool finding, or S5 result is claimed.

## Per-file coverage and dependency reachability

All **5 production files (including both interfaces), 31 transitive Solidity dependencies, and clean DESIGN.md** are inventoried. The 59 source import edges close with zero missing imports. Total inspected corpus: 6,891 Solidity source lines plus four design lines. This is corpus size, not executed line coverage. Import reachability is distinguished from possible runtime calls and from reviewed line ranges.

Paths below are relative to the frozen target root. Every file's exact SHA-256, line count, inbound/outbound import locations, reviewed ranges and property IDs are in `coverage.json`. Complete production coverage does not mean every unused dependency routine received a full independent audit.

| Production/design file | Reviewed lines | Properties | Coverage |
|---|---|---|---|
| `DESIGN.md` | 1-4 | P16 | Read as candidate requirement context and inherited wording boundary; no S5 compliance verdict. S5 pending independently; no reconciliation or external design material consumed. |
| `packages/contracts/src/Raffle.sol` | 1-614 | P01, P02, P03, P04, P05, P06, P07, P08, P09, P10, P11, P12, P13, P14, P15, P16 | All declarations, storage, constructors, initialization, sale/draw/refund/claim paths, callback guards, range helpers, metadata and destination override. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/src/RaffleFactory.sol` | 1-186 | P01, P02, P03, P04, P07, P13, P14, P15, P16 | Constructor/dependency validation, fixed implementation, atomic clone lifecycle, registries, escrow postchecks and all parameter validators. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/src/interfaces/IRaffle.sol` | 1-521 | P01, P02, P03, P04, P05, P06, P07, P08, P09, P10, P11, P12, P13, P14, P15, P16 | Lifecycle enum, init tuple, all events/errors, 10 state-changing declarations, views/getters, token trust assumptions and atomic-claim/timeout contracts. Interface declarations do not themselves enforce behavior. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/src/interfaces/IRaffleFactory.sol` | 1-150 | P01, P02, P03, P04, P07, P14, P15, P16 | Creation tuple, event/errors, creation API and all immutable/registry getters; explicit canonical-token identity boundary. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/src/libraries/RaffleConstants.sol` | 1-43 | P01, P04, P06, P07, P08, P09, P10, P12, P16 | All economic, precision, duration, callback and refund-batch constants. Source review only; no execution, compiler or tool-derived validation. |

| Dependency | Reviewed lines / depth | Reachability and review limit |
|---|---|---|
| `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol` | 1-31; full_interface_read_inherited_type | Wrapper base stores/returns this type; internal LINK-payment method uncalled by Raffle. No external LINK implementation or production LINK transfer path inferred. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol` | 1-118; full_source_read_inherited_paths | Constructor link lookup and immutable wrapper, native request:76-89, raw callback authentication:101-107, public getBalance/getLinkToken and immutable getter. Internal LINK request:62-73 has no Raffle caller. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol` | 1-83; full_interface_read | Native price/estimate/request/link ABI; linkNativeFeed:82 exists as an interface declaration but Raffle does not call it. Wrapper/coordinator/feed implementation and deployment behavior are outside supplied source. |
| `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol` | 1-27; full_source_read_runtime_path_focused | EXTRA_ARGS_V1_TAG and selector-tagged ExtraArgs encoding:7-25; nativePayment true set by Raffle; unused subscription request struct separated. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC1363.sol` | 1-86; full_interface_read_not_runtime_used | Imported by unused SafeERC20 relaxed transfer/approval helpers; no project ERC1363 call or implementation. Import-only integration surface; not evidence that configured quote has ERC1363 hooks. |
| `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC165.sol` | 1-6; full_alias_read | IERC165 re-export through IERC1363; no separate executable path. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC20.sol` | 1-6; full_alias_read | IERC20 re-export through IERC1363; no separate code or deployed token. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/interfaces/draft-IERC6093.sol` | 1-162; interface_error_declarations | IERC721Errors:56-108 used by inherited ERC721/receiver checks; ERC20/ERC1155 errors do not add production execution paths. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol` | 1-294; full_source_read_runtime_path_focused | Factory calls clone(address):32-34 -> clone(address,uint256):47-62 with value zero. Embeds fixed implementation via CREATE; failure reverts. Other deterministic/immutable-args helpers have no project caller. Import reachability includes Create2/Errors; it does not make every Clones helper dynamically reachable. No bytecode/proxy tooling executed. |
| `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol` | 1-79; full_interface_read | Transfer/transferFrom ABI used by SafeERC20; balanceOf/approve declarations are not proof of project reads or allowance writes. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol` | 1-26; full_interface_read | Factory consumes decimals():25, not quote name or symbol. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol` | 1-280; full_source_read_runtime_path_focused | Used safeTransfer/safeTransferFrom wrappers and assembly optional-return/failure paths:33-47,176-244. Unused approval/ERC1363 helpers distinguished from project calls. Success response is not balance-delta validation. ERC1363 and approval helpers are import-reachable but not called by production. |
| `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol` | 1-433; full_source_read_inherited_paths | All external methods plus ownership/approval/update, safe mint/receiver, burn, fixed empty base URI and error paths. Raffle override dispatch traced. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol` | 1-135; full_interface_read | Prize and ticket ABI, transfers/approval/ownership and recipient-capability warnings; no external prize implementation supplied. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol` | 1-28; full_interface_read | Exact callback ABI and acceptance selector:22-27. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol` | 1-27; full_interface_read | Metadata ABI; implementation name/symbol overridden, URI inherited. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol` | 1-50; full_source_read_runtime_path | Code-length gate, receiver selector check and revert bubbling:25-49. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/utils/Bytes.sol` | 1-35, 240-332; focused_import_only_search_triage | Imported by unused Strings functions; equal hash and reverseBytes swap hits reviewed as library utilities, not protocol cryptography or AMM calls. No production path calls Bytes; remaining unused byte-editing routines not independently audited. |
| `packages/contracts/node_modules/@openzeppelin/contracts/utils/Context.sol` | 1-28; full_source_read_runtime_path | _msgSender returns msg.sender:17-19; no meta-transaction sender override in Raffle. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/utils/Create2.sol` | 1-91; full_source_read_not_runtime_used | Imported by Clones; actual factory uses CREATE clone overload, so deterministic creation/hash helpers not called. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/utils/Errors.sol` | 1-34; full_error_declaration_read | Clones actual deployment uses InsufficientBalance/FailedDeployment declarations; other error declarations add no behavior. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol` | 1-127; full_source_read_not_runtime_used | Reached by Create2 import only; direct call/delegatecall helpers and returndata handling do not create project upgrade/external-call paths. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/utils/Panic.sol` | 1-57; full_source_read_error_helper | Panic codes and assembly revert:50-55 imported by Math; unreachable overflow under stated valid raffle accounting still identified. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol` | 1-119; full_source_read_runtime_path | Dedicated slot, constructor value1, rejection of only value2 and before/after writes; zero-initialized clones covered by source logic. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol` | 1-143; full_source_read_runtime_path_focused | Guard calls getUint256Slot:93-97; ERC1967 example is a comment, not a project upgrade mechanism. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/utils/Strings.sol` | 1-150; focused_metadata_branch_and_imports | ERC721 tokenURI references toString:42-60 only when _baseURI is nonempty; inherited _baseURI returns empty and no override exists. Other parsing, checksumming and equality helpers are not called. File-level import/search coverage; no independent audit of all unused parsing helpers. |
| `packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/ERC165.sol` | 1-25; full_source_read_runtime_path | supportsInterface reports IERC165:20-24; extended by inherited ERC721. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol` | 1-25; full_interface_read | Factory ERC721 feature declaration query; declaration cannot prove token honesty. Source review only; no execution, compiler or tool-derived validation. |
| `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol` | 1-310, 374-491, 660-763; focused_reachable_arithmetic_and_search_triage | mul512:37-46 and floor mulDiv:206-277 used for accounting. Given entry cap, high word is zero on reachable products. modExp/precompile patterns:374-489 inspected as unused; log10:675-707 is referenced only behind empty-URI false branch. Entire file import/search coverage; not a full audit of unused inverses, roots and other math routines. |
| `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SafeCast.sol` | 1-60, 1140-1162; focused_transitive_helper | Math.ternary uses boolean toUint:1157-1161 on general mulDiv error paths; reachable raffle products stay in high==0 path. Other casts belong to unused helpers. All-file pattern search/import inventory; repeated integer-cast routines not independently audited. |
| `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SignedMath.sol` | 1-68; full_source_read_not_runtime_used | Imported by Strings for signed formatting absent from the raffle path; no signed-accounting behavior introduced. Source review only; no execution, compiler or tool-derived validation. |

Dependency runtime summary: Factory -> Clones.clone/Errors; Raffle -> ERC721 ownership/approval/update/receiver helpers, ReentrancyGuard/StorageSlot, SafeERC20 transfer paths, Math.mulDiv/mul512 and Chainlink native request/authenticated callback/ExtraArgs. Interfaces supply types/selectors and external-call contracts, not implementations. Clones imports Create2, which imports LowLevelCall, but the actual factory does not call their deterministic helpers. ERC721 imports Strings whose tokenURI formatting branch is bypassed by an empty base URI; its Bytes/SignedMath imports do not become raffle logic. SafeERC20 imports IERC1363/aliases without production use of its relaxed-call extensions. LINK request code exists internally in the base, but Raffle requests native payment only.

## Completion and deferred actions

1. Parent seals the aggregate source first pass; this report does not self-seal or unlock execution.
2. Only after that gate, perform the native Step 1 detector run, applicable Step 2 validations, Step 3 generated visuals, and Step 4 property harness/setup/execution under subsequent authorization.
3. Use P01-P16 as proposed assertions/transition checks with explicit honest-token and adversarial-dependency models, boundary timestamps, ghost ledgers and inherited callback cases; no harness or test configuration was created here.
4. Leave independent S5 result and any reconciliation pending; no aggregate spec verdict is supplied.
5. Keep dependency authenticity and deployment-specific semantics explicitly unknown unless later authorized evidence establishes them.


Source-only deliverables: `SOURCE-REPORT.md` and `coverage.json` in the authorized attempt-02/S6/source directory. Target source/configuration/lock files are unchanged. Property documentation and bounded manual review are complete; native execution/visualization and independent S5 are pending. No parent seal is asserted.

Artifact integrity: all 37 source/design hashes were rechecked unchanged before output. All recorded property, review, search and file-coverage line references were checked against the inspected file lengths. These are document/source integrity checks only, not tests of the contracts.

