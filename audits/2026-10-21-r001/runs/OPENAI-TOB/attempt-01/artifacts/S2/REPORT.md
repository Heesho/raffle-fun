# Entry Point Analysis: raffle.fun
Analyzed: 2026-10-21T08:05:00Z. Target: 9238b6ce8eb7f768c0dcd0cfcef26e1427a03155. Solidity 0.8.36. Scope: all five production files, explicitly including both interfaces, and inherited externally callable functions. This is an entry-point inventory, not vulnerability findings.

## Native workflow and limitation
Language detection, contract discovery, source extraction, access classification and report generation completed. `which slither` found `/opt/homebrew/bin/slither`; raw availability output is retained. The native `slither . --print entry-points` step is deferred to S6 so independently sealed source-only outputs precede static tooling. This is a disclosed ordering adaptation, not the skill's unavailable-tool fallback and not full native completion. No detector output was consumed. Inputs: target source plus S1 context; no prior vulnerability findings.

## Summary
Counts are distinct reachable signatures across RaffleFactory and Raffle, not clone instances or duplicate interface declarations.

| Category | Count |
|---|---:|
| Public, subject to business preconditions | 8 |
| Role restricted: current ticket owner / ERC721 authority | 6 |
| Mixed sponsor/public temporal access | 1 |
| Contract-only integration | 3 |
| Total potentially state-changing signatures | 18 |

An additional `receive()` path always reverts and is recorded below. Two constructors are deployment-only, excluded from recurring totals. View/pure functions and generated getters are excluded by the skill.

## Public entry points
| Function | Evidence | Restrictions / effects |
|---|---|---|
| RaffleFactory.createRaffle(tuple) | RaffleFactory.sol:97-148 | nonReentrant; validates configuration, clones, initializes, registers and escrows caller's prize |
| Raffle.buyEntries(address,uint128) | Raffle.sol:209-237 | nonReentrant; Active, before end, positive bounded entries, quote transfer and safe mint |
| requestDraw() payable | Raffle.sol:240-273 | nonReentrant; Active with sold entries, request window and native fee |
| settleWinningTicket(uint256) | Raffle.sol:304-306,533-558 | nonReentrant; terminal winner state, valid range, one allocation; ownership irrelevant |
| releaseSponsorProceeds() | Raffle.sol:375-382 | nonReentrant; nonzero claim, pays fixed recipient |
| releaseProtocolFees() | Raffle.sol:385-392 | nonReentrant; nonzero claim, pays fixed treasury |
| releaseSponsorPrize() | Raffle.sol:395-407 | nonReentrant; CashWon/Refunding and unclaimed, pays fixed recipient |
| setApprovalForAll(address,bool) | ERC721.sol:104-106,409-418 | changes caller's own operator approval, nonzero operator; no administrator role |

## Role-restricted entry points
| Function | Evidence | Actual authority |
|---|---|---|
| redeemWinningTicket(uint256) | Raffle.sol:309-346, especially 320-321 | current winning-ticket owner only; approved operator alone cannot redeem |
| refundTickets(uint256[]) | Raffle.sol:349-372, especially 359-360 | caller owns every submitted ticket; 1..100 tickets; Refunding |
| approve(address,uint256) | ERC721.sol:93-95,383-399 | owner or owner's operator-for-all; a single-token approved spender cannot grant another approval |
| transferFrom(address,address,uint256) | ERC721.sol:115-125,164-187,216-245 | owner, approved operator, or approved spender; supplied from must match owner |
| safeTransferFrom(address,address,uint256) | ERC721.sol:128-130 | same authority via four-argument overload |
| safeTransferFrom(address,address,uint256,bytes) | ERC721.sol:133-135 | same authority via transferFrom; receiver acceptance checked |

All mints/transfers/burns pass Raffle._update (Raffle.sol:497-502); nonzero protocol destinations are rejected. This hook is internal and not separately counted. Approval authority does not bypass this hook.

## Mixed access requiring branch-aware classification
`enableRefunds()` (Raffle.sol:276-301), nonReentrant: sponsor may close an empty Active raffle before end; anyone may close it at/after end. With sold entries anyone may enable refunds at/after draw-request deadline. In Drawing anyone may do so at/after callback deadline. All other states revert. It is neither universally sponsor-only nor universally open independent of time/state.

## Contract-only integration
| Function | Evidence | Caller condition |
|---|---|---|
| initialize(tuple) | Raffle.sol:176-206 | immutable factory only, once; implementation is locked in constructor at 164-165 |
| onERC721Received(address,address,uint256,bytes) | Raffle.sol:416-431 | configured prize token only, AwaitingPrize, expected ID/from=sponsor/operator=factory |
| rawFulfillRandomWords(uint256,uint256[]) | VRFV2PlusWrapperConsumerBase.sol:101-107; Raffle.sol:509-524 | immutable wrapper only; inherited external handler calls guarded lifecycle/request/deadline logic |

## Rejected paths, constructors and coverage
`receive()` at Raffle.sol:171-173 always reverts with DirectNativeTransfer; no successful state-changing path. No fallback function is declared in the production contracts. ERC1167 proxy routing is deployment infrastructure, not an extra business signature. RaffleFactory constructor:65-92 and Raffle constructor:155-166 establish immutable identities and implementation lock; deployment-only.

| Production file | Coverage |
|---|---|
| Raffle.sol | all external/public declarations, receive, internal permission helpers and inherited overrides; 17 successful state-changing signatures including inherited ones |
| RaffleFactory.sol | constructor, createRaffle and validators; 1 recurring state-changing signature |
| interfaces/IRaffle.sol | explicit inclusion; all 10 non-view declarations mapped to implementation; view declarations excluded, interface does not itself enforce permissions |
| interfaces/IRaffleFactory.sol | explicit inclusion; createRaffle mapped; getters excluded |
| libraries/RaffleConstants.sol | no external state-changing functions; bounds/timing constants referenced by callers |

Native scanner cross-check remains INCOMPLETE until the later tool phase. No source parsing failure; initial oversized console read was truncated, retained numbered source copies and focused follow-up reads were used.
