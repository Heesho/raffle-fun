# DAYBREAK-TOB First Pass

**Timestamp:** 2026-10-21T01:27:00-07:00  
**Target SHA:** `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`  
**Declared method:** Trail of Bits six-stage aggregate at revision `82fe8226252622fa807643bdca1710901198553a`  
**Status:** **INCOMPLETE — time-bound partial source pass; no clean-audit claim**

## Executive result

Only the native context Orient phase and 1 of its 12 selected per-function Analyze jobs completed. The remaining source-only stages and secure-workflow tool stage did not complete. Accordingly, this report records limited original source observations as leads and coverage facts; it does not claim full catalog coverage, native six-stage completion, or absence of vulnerabilities.

No externally reconciled scanner or historical material was consumed. No static scanner was run before this report and seal.

## Source-supported leads

### L-01 — Cross-factory raffle destinations are not recognized by the protocol-destination guard

**Classification:** confirmed source path, consequence primarily sponsor-controlled; severity not assigned in this incomplete pass.

The design says assets must never move between raffle clones (`DESIGN.md:L2`). Destination screening recognizes only `canonicalFactory.isRaffle(destination)` after checking this clone, its own factory, trusted dependencies, configured prize, and its own implementation (`Raffle.sol:L593-L604`). `RaffleFactory._validateCreateParams` likewise rejects only this factory's registered raffles for `sponsorRecipient` (`RaffleFactory.sol:L154-L178`).

Concrete path: a sponsor supplies a raffle clone registered by another factory as `sponsorRecipient`; `_validateCreateParams` accepts it because the local `isRaffle` mapping is false; after settlement, anyone calls `releaseSponsorProceeds`; `_transferQuote` repeats only the local-factory test and transfers quote assets to the foreign clone (`Raffle.sol:L375-L381`, `L564-L566`). This contradicts the unqualified cross-clone design invariant and may strand the sponsor allocation because unrelated quote tokens are outside the recipient clone's accounting. Confirmation still requires deciding whether “raffle clones” was intended to mean only clones of the canonical factory.

### L-02 — ERC-165 plus self-reported ownership cannot establish custody against an adversarial prize contract

**Classification:** lead with concrete call path; security consequence depends on the intended meaning of “untrusted prize contracts.”

The supplied design labels arbitrary prize contracts untrusted while promising atomic escrow (`DESIGN.md:L2`). Creation checks code presence and a self-reported ERC-721 interface bit (`RaffleFactory.sol:L154-L178`), calls the sponsor-selected contract's `safeTransferFrom`, then relies on that same contract's `ownerOf` response plus clone status (`RaffleFactory.sol:L127-L134`). A malicious contract can claim ERC-721 support, invoke `onERC721Received` with the expected arguments to activate the clone (`Raffle.sol:L416-L430`), and return fabricated ownership. Redemption again relies on its `transferFrom` and `ownerOf` (`Raffle.sol:L329-L337`).

This is a concrete dependency/trust mismatch, but whether it is actionable rather than an inherent limitation of accepting arbitrary token contracts requires native token-analysis and threat-model judgment that did not complete.

### L-03 — The clean design's refund-deadline sentence conflicts with documented early empty-raffle cancellation

**Classification:** documentation/specification lead.

`DESIGN.md:L2` says “Refunds open at deadline.” In `Active` with zero entries, `enableRefunds` permits the sponsor to transition before `endTime`; non-sponsors must wait (`Raffle.sol:L279-L284`). Interface documentation calls the sponsor the “pre-end empty-raffle refund authority” (`IRaffle.sol:L37-L38`). The implementation and inline NatSpec agree with each other, while the clean design sentence is broader. Native spec extraction/refutation did not run, so no formal compliance verdict is assigned.

## Properties reviewed

| Property | Coverage | Source result |
|---|---|---|
| Immutable, ownerless factory/implementation | Partial | Constructor state and absence of admin setters reviewed in `RaffleFactory.sol:L21-L92`; no native guidelines/tool confirmation. |
| Atomic create/register/prize escrow | Partial | Call/order path reviewed at `RaffleFactory.sol:L97-L148`; adversarial-token assumption remains L-02. |
| Fixed entry price and contiguous ticket ranges | Partial | `Raffle.sol:L209-L237`; no completed function micro-analysis. |
| Draw request and callback windows | Partial | `Raffle.sol:L240-L273`, `L458-L465`, `L509-L524`; no completed request/callback records. |
| Refund transition/liability conservation | Native function analysis complete | `enableRefunds` analyzed in `audit-context/functions/08-enableRefunds.md`; downstream refund batch not completed. |
| Reserve-met and reserve-missed split/rounding | Partial | Storage allocation reviewed at `Raffle.sol:L533-L557`; native settlement analysis did not return. |
| Storage-only permissionless settlement | Partial | `_settleWinningTicket` contains storage writes/event only (`Raffle.sol:L533-L557`); call-chain analysis incomplete. |
| Current-owner burn and atomic delivery | Partial | `Raffle.sol:L309-L345`; native redemption analysis did not return. |
| Independent sponsor/treasury claims | Partial | `Raffle.sol:L375-L391`; transfer helper reviewed, no native stage completion. |
| No inter-clone asset movement | Concrete counter-path lead | L-01. |
| Trusted quote token / wrapper boundaries | Partial | Dependency source was in scope and Orient read it; token and secure-workflow stages absent. |
| Untrusted prize/ticket-recipient boundaries | Partial | External call sites reviewed; L-02 remains a lead. |

## Per-file coverage

| Production file | Coverage |
|---|---|
| `Raffle.sol` | Orient complete; one function (`enableRefunds`) deeply analyzed; other selected functions have preserved partial raw streams only. |
| `RaffleFactory.sol` | Orient complete; `createRaffle` Analyze invocation incomplete; controller performed limited line review. |
| `RaffleConstants.sol` | Read by Orient and controller; constants mapped, no independent native stage report. |
| `IRaffle.sol` | Explicitly read by Orient and controller; interface/NatSpec cross-check partial. |
| `IRaffleFactory.sol` | Explicitly read by Orient and controller; interface/NatSpec cross-check partial. |

## Native stage ledger summary

| Stage | Status | Evidence |
|---|---|---|
| S1 audit-context-building | INCOMPLETE | Orient complete; Analyze 1/12; Synthesize absent. |
| S2 entry-point-analyzer | INCOMPLETE | Skill/resources loaded; no model report; Slither not run. |
| S3 token-integration-analyzer | INCOMPLETE | Skill/resources loaded; no native report/tooling. |
| S4 guidelines-advisor | INCOMPLETE | Skill/resources loaded; no native report/diagrams. |
| S5 spec-to-code-compliance | INCOMPLETE | Workflow/resources loaded; no Extract/Align/Verify/Report artifacts. |
| S6 secure-workflow-guide | INCOMPLETE | Skill/resources loaded; no five-step execution. |

## Coverage limitations

- Eleven selected function agents were interrupted after source walks but before schema-valid final records; their partial JSONL is evidence of work attempted, not completed coverage.
- No native context synthesis exists, so cross-function invariants and unenforced assumptions are incomplete.
- No independent spec refuters, static analysis, ERC checks, diagrams, property harness, fuzzing, or formal verification ran.
- Provider-returned model identity was absent from CLI events and is recorded as `unknown`; no identity is inferred from the alias or model prose.
