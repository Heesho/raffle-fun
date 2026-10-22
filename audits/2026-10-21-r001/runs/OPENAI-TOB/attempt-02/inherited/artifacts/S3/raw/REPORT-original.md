# Token integration analysis — original source-only pass
Timestamp: 2026-10-21T08:07:00Z. Target SHA: 9238b6ce8eb7f768c0dcd0cfcef26e1427a03155. Local model gpt-6-astra / ultra; provider-returned model/effort unknown. No prior findings or scanner results consumed. S1 context and S2 non-finding entry inventory were available; analysis below is grounded directly in target source.

## Result and native phase coverage
No confirmed token-integration vulnerability established within the stated canonical quote-token/VRF trust model. This is not a dynamic proof or an attestation about deployed USDC or prize implementations. Two conditional integration leads are retained below.

Phase 1 context discovery COMPLETE: EVM Solidity 0.8.36; ERC721 ticket implementation, external fixed ERC20 quote integration, arbitrary external ERC721 prize integration. Phase 2 tooling INCOMPLETE/DEFERRED: slither-check-erc, human-summary, contract-summary are reserved for S6 after source-only seals. slither-prop's ERC20-generation mode has no project ERC20 implementation to target. Phase 3 source categories COMPLETE at the coverage described here. Phase 4 on-chain analysis NOT APPLICABLE: no deployment address/RPC supplied; no chain queried. Phase 5 source risk assessment COMPLETE. Overall native stage remains INCOMPLETE because tool phase has not run in native order.

## Ten-category checklist
| Category | Source result / limitation |
|---|---|
| 1 General considerations | Audit history, team accountability/contact and security mailing lists are not established; outside authorized source corpus, not evidence of their absence. |
| 2 Composition | Raffle extends ERC721, ReentrancyGuard and wrapper consumer; factory deploys fixed ERC1167 clones. Constant-time purchase/callback/settlement; refund loop capped at 100. Solidity checked arithmetic; imported Math supplies mulDiv. Native complexity metrics unavailable until S6. |
| 3 Owner privileges | No project owner/pause/upgrade/mutable fee methods in either implementation. Ticket minting only buyEntries; counter and entry cap at Raffle.sol:219-235. External quote/prize implementation governance unknown because their implementations are absent. |
| 4 ERC20 conformity | Project is a consumer, not ERC20 issuer. Factory reads uint8 decimals and requires six (Factory:65-79). No quote name/symbol/permit or project-created allowances. SafeERC20 return/error handling verified in dependency:32-44,176-249. External ERC20 conformance not provable from interfaces. |
| 5 ERC20 extensions | Nominal amounts are assumed: buyEntries:223-233 credits grossAmount after safeTransferFrom without balance delta; _transferQuote:564-567 assumes full outgoing amount. Rebase/fee/hook semantics are not globally normalized. Canonical fee-free/non-rebasing assumptions are explicit in DESIGN.md and Raffle:560-563. |
| 6 Scarcity | No on-chain supply/distribution/liquidity/concentration evidence. Fixed entry price and delayed draw do not use spot-price or holder balances as oracle input (Raffle:223,240-273,509-524). |
| 7 Weird tokens | All 24 reference patterns assessed in table below; external implementation presence remains unknown where source is missing. |
| 8 Integration safety | Safe wrappers yes; actual balance verification no; allowlist is one immutable deployment-supplied quote identity, validated by code/decimals rather than canonical-address proof (Factory:55-79); no normalization wrapper; guarded sale/claim methods, zero-claim guards, and independent claims. |
| 9 ERC721 conformity | Zero-recipient transfer rejection ERC721:115-125; safe overloads/callback :128-135; ownerOf through _requireOwned :426-432 reverts for absent/burned IDs; transfers/burns clear approvals :216-245; IDs are sequential immutable historical ranges (Raffle:226-235,451-455). Metadata fixed via overrides :478-486. Native conformance checker pending. |
| 10 ERC721 common risks | Safe mint invokes receiver only after range/pot/ownership writes (Raffle:230-235; ERC721:287-289). Guard excludes guarded reentry; inherited ticket transfers intentionally remain callable. Burns clear approvals. Prize release uses transferFrom and ownerOf verification, not recipient callback acceptance (Raffle:329-337,395-405), per bearer/atomic-delivery design. |

## All 24 weird ERC20 patterns
“Conditional” denotes an integration assumption/lead, not a claim that the configured canonical token currently exhibits it.

| # | Pattern | Evidence and result |
|---:|---|---|
| 1 | Reentrant transfer hooks | Guarded buy/refund/claims (Raffle:209-237,349-392); guard shared per instance (ReentrancyGuard:69-110). ERC721 transfers are unguarded but authenticated and do not spend quote liabilities. Arbitrary hostile quote behavior outside canonical trust; no concrete same-model loss path shown. |
| 2 | Missing returns / false-on-success | SafeERC20 accepts empty return only for code-bearing token, rejects false (176-249); false-on-success reverts atomically. |
| 3 | Fee on transfer | No balance delta at buy:223-233 or payout:564-567; unsupported conditional L-T01. |
| 4 | Balance changes outside transfers | Internal liabilities are nominal; no rebase reconciliation (accountedQuoteBalance:465-467); conditional L-T01. |
| 5 | Upgradeable external tokens | Project quote address immutable; no external implementation upgrade detector. Governance/code unavailable; compatibility monitoring is an operational requirement. |
| 6 | Flash minting | No balance-based voting/pricing; buyer pays actual configured token amount, sells before draw and waits for authenticated asynchronous result. Token supply bounds unknown. |
| 7 | Blocklists | Safe transfer failures revert and preserve claim; no rescue/migration. Individual claimant or raffle-wide availability depends on external token. Presence in deployed token not verified. |
| 8 | Pausable tokens | Same revert/isolation analysis; no claim of current pause capability/state from absent source. |
| 9 | Approval race protections | Protocol does not issue ERC20 approve; buyer approval is external integration. |
| 10 | Approval to zero | No outgoing ERC20 approval calls. N/A to project execution. |
| 11 | Zero approval | No outgoing ERC20 approval calls. N/A. |
| 12 | Zero transfers | Positive entry count; nonzero proceeds guards; valid nonempty refunds contain positive ranges (Raffle:218,340,351-368,377,387). No forced zero-value quote operation located. |
| 13 | Multiple token addresses | Single immutable quote address; internal accounting does not treat donated aliases as sales. No rescue path. External alias behavior unknown. |
| 14 | Low decimals | Exactly six enforced, ENTRY_PRICE=1_000_000. Other precision rejected (Factory:70-79, Constants:20-24). |
| 15 | High decimals | Non-six rejected before factory deployment succeeds; no arbitrary decimal exponentiation. |
| 16 | transferFrom(src==caller) | Incoming token sees caller=raffle, src=buyer (Raffle:224); project does not rely on allowance bypass. |
| 17 | Non-string metadata | Quote name/symbol unused; decimals uses typed uint8 and catch. Ticket name/symbol pure fixed strings. |
| 18 | Transfer to zero | Clone fixed payout recipients nonzero (Raffle:181-185); ticket owner nonzero via ownerOf; buy recipient nonzero. |
| 19 | False without revert | SafeERC20 checks optional result and raises failure; verified low-level paths. |
| 20 | Large approvals | No project-created ERC20 allowance; buyer-side token limits outside provided implementation. |
| 21 | Name injection | No external token name consumed in Solidity; frontend source not supplied, no frontend safety conclusion. |
| 22 | Unusual permit | No permit path in production. |
| 23 | Transfers less than requested | Same nominal-credit conditional L-T01; library success is not a balance-delta proof. |
| 24 | Native-currency representation | Fixed six-decimal quote and separate native VRF funding; no configurable native-token alias mode. Deployment authenticity remains external; forced native donations are not sale accounting. |

## Conditional leads and prioritized follow-up
L-T01 — **Canonical quote semantics are an unverified external dependency, not a confirmed in-model vulnerability.** Concrete conditional sequence: deploy factory with a six-decimal code-bearing token that returns transfer success while delivering less; buyEntries(…,n) calls safeTransferFrom at Raffle:224 and increments unsettledPot by the requested n*ENTRY_PRICE at :233. Later nominal claims can exceed actual assets. Factory metadata checks do not prove canonical identity (Factory:55-79 explicitly delegates identity to deployment tooling). This requires a violated trusted-canonical-dependency assumption, so no severity or confirmed finding is assigned. Prioritize deployment address verification and change monitoring; balance-delta defenses would be needed if arbitrary tokens became supported.

L-T02 — **Prize custody checks rely on the selected prize contract's truthful semantics.** A sponsor-chosen code-bearing contract can report ERC721 support, invoke expected deposit callback and report matching ownerOf; factory checks these at :172-177 and :129-135. Later delivery relies on its transferFrom/ownerOf at Raffle:334-336 or :404-405. Without its implementation, truthful ownership, later transferability and economic value cannot be proven. No cross-raffle loss path or unauthorized canonical-token withdrawal was established; retain as untrusted-asset selection/availability lead. Prioritize prize-implementation review and UI disclosure; do not promote a lying-interface thought experiment into an aggregate confirmed finding.

## Per-file coverage
Raffle.sol: all purchase, payout, refund, burn, receiver, callback, metadata, destination and accounting helpers reviewed. RaffleFactory.sol: constructor identity/decimals, prize interface screening, clone registration and post-escrow checks. IRaffle.sol: explicit interface inclusion, state-changing declarations and documented ownership/rollback/trust assumptions. IRaffleFactory.sol: explicit inclusion, immutable identity and creation API. RaffleConstants.sol: all economics/limits/timing constants. Reachable ERC721, ERC721Utils, SafeERC20, ReentrancyGuard and wrapper base reviewed; deployment-specific quote/prize/wrapper implementations are not supplied. No external token, history, tests or scanner results were imported.
