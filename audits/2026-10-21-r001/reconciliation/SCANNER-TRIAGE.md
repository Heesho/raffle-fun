# Scanner triage

Recorded 2026-10-21T08:07:31.610480Z. This is a **tool/test-exposed follow-up**, separate from the sealed cold first pass. No peer findings were consulted. Frozen production source was checked byte-for-byte against the clean snapshot before copying and against the production checkout after execution; no production changes were made.

**All 23 scanner items were individually triaged:** 12 Slither observations (10 Low, 2 Informational) and 11 Aderyn instances (3 High instances across 2 classes; 8 Low instances across 6 classes). Aderyn covers all 5 source files and 710 SLOC. No exploitable security vulnerability was confirmed by these alerts. Forced/unaccounted ETH being unrecoverable is retained as one informational limitation, rather than incorrectly dismissing every part of the Ether-lock alert.

## Evidence and execution

Isolated runtime: `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage`. Source and test dependencies were copied; no validation/static cache was shared. Solc 0.8.36 compiled 67 files. The targeted command passed 27 executions, representing 16 distinct tests; 11 inherited repeats are explicitly not additional independent tests. Four new proofs cover actual forced ETH, inability to subsidize underfunded draw requests with forced ETH, a 100-ticket refund with exactly one final factory lookup, and absence of factory runtime code during constructor decimals().

Full execution log: `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/triage-tests.log`. New proof source: `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/ScannerTriage.t.sol`. The100-ticket refund segment used 667,412 gas in the local warmed mock environment; total test gas includes minting 100 tickets and is not refund-only gas. This does not certify production-chain cold-state gas or a live Chainlink deployment.

The existing test named testDonationsAndForcedNativeDoNotAlterQuoteAccounting does not actually force ETH: it calls the reverting receive path. This triage uses a newly deployed selfdestructing helper to prove the residual forced balance. The sole compiler warning is the helper’s intentional selfdestruct deprecation; it is audit-only proof code.

## Run-status correction

Slither raw JSON reports success=true, error=null, and12 detector outputs. Its process exit255 is the configured findings gate, not compilation or analysis failure. The original runs/TOOL-SLITHER/attempt-01/result.json is preserved. An append-only assessment addendum records COMPLETE_WITH_OBSERVATIONS, distinguishing successful scanner execution from security triage. No process exit code was rewritten.

## Per-item dispositions

### Slither 01 — events-maths

Stable ID: `85cca564fcada590e9af2d7e4001101f5886ff6ebb177b3e201053e15ea3f0dc`. Raw pointer: `/results/detectors/0`. Scanner severity: Low. Disposition: **informational_or_style**; confidence: high.

Source: `packages/contracts/src/Raffle.sol:201; packages/contracts/src/Raffle.sol:203; packages/contracts/src/Raffle.sol:204`.

Property: Initialization configuration remains observable and immutable.

Exploit preconditions: An exploitable omission would require an authorized initialization outside atomic canonical factory creation, or a later silent setter; neither exists.

The three individual flagged writes at Raffle.sol:201 (prizeTokenId), :203 (reserveEntries), and :204 (endTime) are emitted by the canonical factory RaffleCreated event at RaffleFactory.sol:136-147. initialize is factory-only and one-time (:177-179). The receiver also emits PrizeDeposited. No per-clone initialization event is needed for recoverability of these values. Indexers must consume the canonical factory event.

Evidence: `testImplementationAndCloneInitializationAreLocked` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:209; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Slither 02 — calls-loop

Stable ID: `0d4426784e474fdf01ac9750cc03383ea24d113a142a5762740408106bb27f02`. Raw pointer: `/results/detectors/1`. Scanner severity: Low. Disposition: **false_positive**; confidence: high.

Source: `packages/contracts/src/Raffle.sol:599,600,601`.

Property: No external factory call occurs for each refund burn.

Exploit preconditions: The alleged path requires _isProtocolDestination to execute during a burn whose destination is zero.

refundTickets:357-364 calls _burn; inherited ERC721._burn calls _update(address(0),...). Raffle._update:498 short-circuits because to==0, so the alleged factory.raffleImplementation call at :599-601 is unreachable inside that loop. One lookup occurs after the loop in _transferQuote. The 100-ticket proof expects exactly one factory implementation lookup in the whole refund and passes.

Evidence: `testTriageOneHundredRefundBurnsSkipFactoryCallsInsideLoop` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/ScannerTriage.t.sol:61; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Slither 03 — calls-loop

Stable ID: `283434d605d8192e35ddfe44b8809d5e3f914fac6a89dd6070d74ae86dd65b8c`. Raw pointer: `/results/detectors/2`. Scanner severity: Low. Disposition: **false_positive**; confidence: high.

Source: `packages/contracts/src/Raffle.sol:603`.

Property: No registry callback occurs for each refund burn.

Exploit preconditions: The alleged call stack requires to!=0 during ERC721._burn, contrary to the inherited implementation.

The same _update:498 zero-address short circuit bypasses all of _isProtocolDestination, including isRaffle at :603. Additionally :602 only queries isRaffle for code-bearing destinations. The actual final payment is outside the loop. The loop contains local owner/range reads and burns, not the alleged registry external call.

Evidence: `testTriageOneHundredRefundBurnsSkipFactoryCallsInsideLoop` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/ScannerTriage.t.sol:61; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Slither 04 — reentrancy-benign

Stable ID: `522085466e3ee47a4f921b04324ce7ffd4bf0398d4b869f0b73d0bc51b4ed9ae`. Raw pointer: `/results/detectors/3`. Scanner severity: Low. Disposition: **false_positive**; confidence: high.

Source: `packages/contracts/src/RaffleFactory.sol:109,110,111,112,113,114,115,116,117,118,119,120,121; packages/contracts/src/RaffleFactory.sol:124; packages/contracts/src/RaffleFactory.sol:123`.

Property: A fresh canonical clone cannot reenter factory creation and corrupt its registry.

Exploit preconditions: Attack would require replacing the freshly created fixed implementation clone, defeating the factory nonReentrant guard, or a malicious factory getter performing mutation under STATICCALL.

createRaffle:97 is guarded. :106 constructs a fixed-target clone; :109-121 invokes the known initialize code, which authenticates the factory and sets initialized before any registry view lookup. Its only external lookups are back to immutable canonical factory getters. Registration writes :123-125 then arbitrary NFT escrow occur under the same guard. An escrow reentry test is rejected and successful outer creation retains count1 and correct escrow.

Evidence: `testImplementationAndCloneInitializationAreLocked` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:209; PASS); `testFactoryReentrancyDuringPrizeEscrowIsBlockedAtomically` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/security/RaffleSecurity.t.sol:177; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Slither 05 — timestamp

Stable ID: `15f6492c5dc75b7a8b3384c97bbde3c3df0697a8be76cd7166af7a1c7921a86d`. Raw pointer: `/results/detectors/4`. Scanner severity: Low. Disposition: **protected_intended_behavior**; confidence: high.

Source: `packages/contracts/src/Raffle.sol:282; packages/contracts/src/Raffle.sol:287; packages/contracts/src/Raffle.sol:291`.

Property: Refunds open at the exact defined deadline and cannot coexist with a valid result.

Exploit preconditions: A bypass would require timestamp authority beyond chain rules or a mismatch between request/callback expiration and refund gates; ordinary callers cannot supply block.timestamp.

The three flagged comparisons have distinct intended roles: :282 allows only the sponsor to close an empty raffle before sale end; :287 opens sold-raffle refunds at end+2days; :291 opens Drawing refunds at requestedAt+2days. Requests/callbacks reject >= their deadlines, so equality gives refunds exclusively. Time determines liveness, not random selection.

Evidence: `testEmptyRaffleUsesRefundingWithoutClosedState` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:1131; PASS); `testSoldRaffleHasHardRequestAndCallbackRefundDeadlines` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:970; PASS); `testCallbackDeadlineIsHardAtEqualityRegardlessOfOrdering` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:1044; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Slither 06 — timestamp

Stable ID: `6935b73fa9a3ca75276626987a3497496d619b6a9be6b65f3ca6d41a04589a82`. Raw pointer: `/results/detectors/5`. Scanner severity: Low. Disposition: **protected_intended_behavior**; confidence: high.

Source: `packages/contracts/src/RaffleFactory.sol:100; packages/contracts/src/RaffleFactory.sol:102`.

Property: Creation enforces a future end time and maximum prospective duration.

Exploit preconditions: Only chain timestamp inclusion variance can shift a borderline transaction; there is no arbitrary timestamp argument supplied by a later attacker.

RaffleFactory.sol:100 rejects endTime<=currentTime. :102 rejects sale duration>30days. These are intended domain checks, and equality at 30 days is valid. Timestamp inclusion can cause a near-boundary request to revert but does not bypass configuration validation or select a winner.

Evidence: `testFactoryConstructorAndCreationValidation` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:284; PASS); `testFactoryAcceptsExactMaximumSaleDuration` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:353; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Slither 07 — timestamp

Stable ID: `97a32216e3dc959bdfc9c4b4b3eca8361b8faeb9d49b8a41fbbad25580152f0c`. Raw pointer: `/results/detectors/6`. Scanner severity: Low. Disposition: **protected_intended_behavior**; confidence: high.

Source: `packages/contracts/src/Raffle.sol:511,512`.

Property: Late VRF callbacks cannot override full refunds.

Exploit preconditions: An exploit would require accepting a callback at/after its deadline, or unauthenticated selection; neither source path permits it.

Raffle.sol:511-512 authenticates phase/recorded ID through the wrapper entrypoint and rejects callback time>=deadline. enableRefunds uses the complementary <deadline rejection. Tests cover callback-first and refund-first order at exact equality; no winner is accepted at equality.

Evidence: `testCallbackDeadlineIsHardAtEqualityRegardlessOfOrdering` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:1044; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Slither 08 — timestamp

Stable ID: `98eca2436b1b4609e0358edd094e72a5335f964c847457825b856ce7c57279d9`. Raw pointer: `/results/detectors/7`. Scanner severity: Low. Disposition: **protected_intended_behavior**; confidence: high.

Source: `packages/contracts/src/Raffle.sol:216`.

Property: Entry supply closes before randomness can be requested.

Exploit preconditions: Manipulating winner odds after sales would require buyEntries to accept now>=endTime or drawing to precede endTime.

Raffle.sol:216 rejects buying at/after endTime. requestDraw:242 permits starting exactly at endTime; every transaction observes the same block timestamp. Ticket transfers remain intentional bearer-claim transfers and do not change totalEntries. No timestamp-derived entropy is used.

Evidence: `testSaleEndsButTicketsStayTransferableUntilBurned` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:472; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Slither 09 — timestamp

Stable ID: `9ec05bc52af3b2a2acfec4071c928886b71f16dd9fdcac1327abaf232c6fab66`. Raw pointer: `/results/detectors/8`. Scanner severity: Low. Disposition: **false_positive**; confidence: high.

Source: `packages/contracts/src/Raffle.sol:464`.

Property: The zero timestamp sentinel distinguishes no accepted request.

Exploit preconditions: A relevant failure would need an accepted request at Unix time0. Canonical creation requires a future endTime and requestDraw cannot precede it, so no canonical request can occur at 0.

Raffle.sol:464 compares stored drawRequestedAt against 0 to return0 before a request. It does not compare an attacker input to a current clock or use time for randomness. A recorded nonzero request yields uint256(timestamp)+2days without uint64 addition overflow.

Evidence: `testSoldRaffleHasHardRequestAndCallbackRefundDeadlines` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:970; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Slither 10 — timestamp

Stable ID: `a49e42ba370cd222e60f7ea7f472362e517dc63c043c81b71619433b54a284e8`. Raw pointer: `/results/detectors/9`. Scanner severity: Low. Disposition: **protected_intended_behavior**; confidence: high.

Source: `packages/contracts/src/Raffle.sol:242; packages/contracts/src/Raffle.sol:245`.

Property: Draw initiation has a finite exclusive request deadline.

Exploit preconditions: Attack requires inconsistent sale/request/refund interval endpoints or offchain callers treating stale data as authority.

The two flagged checks at :242 and :245 define endTime<=now<endTime+2days. At the latter equality a draw reverts and enableRefunds succeeds. At one second before the deadline, the accepted request gets its own two-day callback window. This is explicit liveness policy.

Evidence: `testSoldRaffleHasHardRequestAndCallbackRefundDeadlines` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:970; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Slither 11 — assembly

Stable ID: `90beae518a97b87965cde210956021e3da4682c6032a1aac02176a4939bd3135`. Raw pointer: `/results/detectors/10`. Scanner severity: Informational. Disposition: **informational_or_style**; confidence: high.

Source: `packages/contracts/src/Raffle.sol:266,267,268`.

Property: Native surplus refund is bounded by caller contribution and fully checked.

Exploit preconditions: An attacker can deploy a refund recipient that reverts or burns gas; the effect must remain confined to its own uncommitted request.

The assembly at :266-268 calls the original msg.sender with excess=msg.value-paidPrice and empty calldata/output buffers. success is checked at :269, so failure reverts wrapper payment, request state, and all intermediate effects. Zero output-copy size avoids copying malicious returndata. nonReentrant protects economic paths; forced ETH is not included in excess.

Evidence: `testDrawForwardsExactDynamicFeeAndRefundsExcess` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:570; PASS); `testTriageForcedEtherRemainsButNormalDrawDoesNotRetainSurplus` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/ScannerTriage.t.sol:24; PASS); `testTriageForcedEtherCannotSubsidizeUnderfundedCaller` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/ScannerTriage.t.sol:47; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Slither 12 — naming-convention

Stable ID: `206c18a5eed67d3b05f54d01e0c013972f82d79b708d56bf09f77e47282b3ac2`. Raw pointer: `/results/detectors/11`. Scanner severity: Informational. Disposition: **informational_or_style**; confidence: high.

Source: `packages/contracts/src/interfaces/IRaffle.sol:396`.

Property: Constant getter ABI matches its implementation.

Exploit preconditions: No exploit follows from this identifier casing; the scanner checks a naming convention.

IRaffle.ENTRY_PRICE at :396 deliberately matches the public constant ENTRY_PRICE generated getter at Raffle.sol:44. Renaming only the interface would break API correspondence. Uppercase constant naming is not a security defect.

Evidence: source semantics; no additional runtime test was necessary for this declaration/style observation.

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Aderyn 01 — contract-locks-ether

Stable ID: `aderyn:contract-locks-ether:src/Raffle.sol:28:1898:6`. Raw pointer: `/high_issues/issues/0/instances/0`. Scanner severity: High. Disposition: **residual_limitation**; confidence: high.

Source: `packages/contracts/src/Raffle.sol:28`.

Property: Normal request funding is forwarded/refunded; forced native surplus is outside protocol accounting.

Exploit preconditions: Someone must forcibly send ETH, such as a contract selfdestruct beneficiary transfer, or otherwise credit the clone outside receive(). There is no theft of another party's USDC or accepted fee payment.

The normal payable request path forwards paidPrice through the inherited wrapper helper and refunds msg.value-paidPrice; receive():171-173 rejects direct deposits. The new proof injects 1 ETH using a constructor selfdestruct under Cancun, then completes an overfunded draw, winner redemption, and both fee claims. Exactly1ETH remains, while the requester paid only the wrapper fee and accountedQuoteBalance is 0. Underpayment cannot spend forced ETH. There is no rescue method, so forced/unaccounted ETH is indeed unrecoverable. Downgrade the broad High alert to an informational residual limitation; ordinary draw payments are not locked.

Evidence: `testDrawForwardsExactDynamicFeeAndRefundsExcess` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:570; PASS); `testTriageForcedEtherRemainsButNormalDrawDoesNotRetainSurplus` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/ScannerTriage.t.sol:24; PASS); `testTriageForcedEtherCannotSubsidizeUnderfundedCaller` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/ScannerTriage.t.sol:47; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Aderyn 02 — reentrancy-state-change

Stable ID: `aderyn:reentrancy-state-change:src/RaffleFactory.sol:71:3249:192`. Raw pointer: `/high_issues/issues/1/instances/0`. Scanner severity: High. Disposition: **false_positive**; confidence: high.

Source: `packages/contracts/src/RaffleFactory.sol:71`.

Property: Factory constructor validation cannot be used to execute its undeployed runtime.

Exploit preconditions: A hostile decimals implementation would have to mutate a factory whose runtime code does not yet exist, and the Solidity view call also executes under STATICCALL.

The flagged decimals() call at RaffleFactory.sol:71 occurs in construction before runtime code is installed. It is an IERC20Metadata view call, so static context also prohibits mutation in descendants. Writes to constructor-selected immutables at :85-91 are not vulnerable runtime CEI violations. The new probe token asserts msg.sender.code.length==0 and that a static call to raffleCount returns empty data, then deployment completes with count0. Reverting/wrong decimal validation separately reverts atomically. Canonical USDC identity remains a deployment trust assumption, not a reentrancy exploit.

Evidence: `testTriageDecimalsCallbackCannotExecuteFactoryRuntimeDuringConstruction` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/ScannerTriage.t.sol:79; PASS); `testFactoryConstructorAndCreationValidation` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:284; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Aderyn 03 — reentrancy-state-change

Stable ID: `aderyn:reentrancy-state-change:src/RaffleFactory.sol:109:5055:489`. Raw pointer: `/high_issues/issues/1/instances/1`. Scanner severity: High. Disposition: **false_positive**; confidence: high.

Source: `packages/contracts/src/RaffleFactory.sol:109`.

Property: Atomic factory registration after initialization cannot be reentered.

Exploit preconditions: Requires malicious replacement of the fixed clone or bypass of factory nonReentrant; the attacker controls neither.

The initializer target is the clone just created at :106, not a sponsor-supplied implementation. initialize is one-time factory-only and its protocol checks use static factory getters. createRaffle holds nonReentrant across initialization and all registry writes (:123-125), followed by untrusted prize escrow. Escrow reentrancy is dynamically blocked and initialization replay/unauthorized calls are tested.

Evidence: `testImplementationAndCloneInitializationAreLocked` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:209; PASS); `testFactoryReentrancyDuringPrizeEscrowIsBlockedAtomically` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/security/RaffleSecurity.t.sol:177; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Aderyn 04 — costly-loop

Stable ID: `aderyn:costly-loop:src/Raffle.sol:357:13959:434`. Raw pointer: `/low_issues/issues/0/instances/0`. Scanner severity: Low. Disposition: **protected_intended_behavior**; confidence: high.

Source: `packages/contracts/src/Raffle.sol:357`.

Property: Refund work is bounded by ticket count and each burned ownership record must be persisted.

Exploit preconditions: A global denial would require an unbounded mandatory batch or per-entry iteration; callers choose1–100 ticket IDs and can submit smaller batches.

Raffle.sol:351-354 enforces the 100-ticket cap; :357-364 burns one unique ownership record per ticket, which cannot safely be replaced by one local aggregate SSTORE. Only aggregateEntries accumulates locally; the refund liability is updated once after the loop. The new100-ticket proof passes and measures 667412 gas for its refund segment, with exactly one factory lookup after burns. This is local warmed-state/mock evidence, not a chain-wide gas certification.

Evidence: `testTriageOneHundredRefundBurnsSkipFactoryCallsInsideLoop` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/ScannerTriage.t.sol:61; PASS); `testRefundBatchValidationAndMixedOwnershipAreAtomic` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:1102; PASS); `testWeightedRefundBatchPaysExactRangesAndConsumesOnce` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:1076; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Aderyn 05 — large-numeric-literal

Stable ID: `aderyn:large-numeric-literal:src/libraries/RaffleConstants.sol:12:610:6`. Raw pointer: `/low_issues/issues/1/instances/0`. Scanner severity: Low. Disposition: **informational_or_style**; confidence: high.

Source: `packages/contracts/src/libraries/RaffleConstants.sol:12`.

Property: BPS denominator is exactly 10000 and nonzero.

Exploit preconditions: No attacker control; replacing10000 with1e4 changes presentation only.

RaffleConstants.sol:12 uses readable grouped integer 10_000 for the basis-point denominator. It is exactly the intended integer; the choice of notation has no runtime or arithmetic distinction.

Evidence: source semantics; no additional runtime test was necessary for this declaration/style observation.

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Aderyn 06 — large-numeric-literal

Stable ID: `aderyn:large-numeric-literal:src/libraries/RaffleConstants.sol:21:1041:9`. Raw pointer: `/low_issues/issues/1/instances/1`. Scanner severity: Low. Disposition: **informational_or_style**; confidence: high.

Source: `packages/contracts/src/libraries/RaffleConstants.sol:21`.

Property: Every entry costs exactly 1000000 canonical six-decimal quote units.

Exploit preconditions: No attacker-controlled literal or rounding occurs at the declaration.

RaffleConstants.sol:21 uses 1_000_000, exactly equivalent to 1e6. Purchase/refund multiplication uses uint256 and is bounded by uint128 totalEntries. A style suggestion is not loss of funds.

Evidence: `testWeightedRefundBatchPaysExactRangesAndConsumesOnce` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:1076; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Aderyn 07 — large-numeric-literal

Stable ID: `aderyn:large-numeric-literal:src/libraries/RaffleConstants.sol:39:2009:7`. Raw pointer: `/low_issues/issues/1/instances/2`. Scanner severity: Low. Disposition: **informational_or_style**; confidence: high.

Source: `packages/contracts/src/libraries/RaffleConstants.sol:39`.

Property: Requested callback gas value remains 300000.

Exploit preconditions: The notation alone cannot change execution; actual network callback gas sufficiency is a separate deployment/runtime question.

RaffleConstants.sol:39 uses 300_000, numerically identical to 3e5. This alert establishes no underfunded callback or excessive gas use. No live Chainlink configuration or production callback gas measurement is claimed by this triage.

Evidence: source semantics; no additional runtime test was necessary for this declaration/style observation.

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Aderyn 08 — require-revert-in-loop

Stable ID: `aderyn:require-revert-in-loop:src/Raffle.sol:357:14012:381`. Raw pointer: `/low_issues/issues/2/instances/0`. Scanner severity: Low. Disposition: **protected_intended_behavior**; confidence: high.

Source: `packages/contracts/src/Raffle.sol:357`.

Property: Refund batches are atomic and only current owners can burn/pay themselves.

Exploit preconditions: A caller must submit its own malformed, duplicate, missing, or foreign-owned ID; an unrelated attacker cannot edit another transaction's calldata.

The per-item current-owner check at Raffle.sol:359-360 and burn at:364 intentionally revert the complete batch when any ID fails. Forgiving failures would alter the documented all-or-nothing API and complicate correct liability allocation. The mixed-owner test proves the earlier valid ticket remains owned and full liability remains; the caller can resubmit valid IDs. The maximum 100 cap bounds failure cost.

Evidence: `testRefundBatchValidationAndMixedOwnershipAreAtomic` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:1102; PASS); `testWeightedRefundBatchPaysExactRangesAndConsumesOnce` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:1076; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Aderyn 09 — state-change-without-event

Stable ID: `aderyn:state-change-without-event:src/Raffle.sol:176:6374:10`. Raw pointer: `/low_issues/issues/3/instances/0`. Scanner severity: Low. Disposition: **informational_or_style**; confidence: high.

Source: `packages/contracts/src/Raffle.sol:176`.

Property: Initialization parameters are observable through the same atomic creation transaction.

Exploit preconditions: Would need a successful standalone initialize or an unlogged later setter; source allows neither for canonical clones.

Raffle.initialize emits no local event, but canonical Factory.RaffleCreated at:136-147 contains the fixed parameters and receiver activation emits PrizeDeposited. Factory-only one-time initialization and atomic factory creation make the configuration reconstructible. Treat as event-location preference, not an unobservable mutable configuration.

Evidence: `testImplementationAndCloneInitializationAreLocked` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:209; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Aderyn 10 — unchecked-return

Stable ID: `aderyn:unchecked-return:src/Raffle.sol:315:12180:30`. Raw pointer: `/low_issues/issues/4/instances/0`. Scanner severity: Low. Disposition: **false_positive**; confidence: high.

Source: `packages/contracts/src/Raffle.sol:315`.

Property: Lazy settlement still allocates and pays the correct winner amount.

Exploit preconditions: An exploit would require the ignored numeric return to be the only record of cash liability or a success indicator; neither is true.

_settleWinningTicket returns an informational cashAmount while writing winnerProceeds, sponsorProceeds, protocolFees, winningTicketId and settlementComplete. Failure reverts, never returns a false-success sentinel. redeemWinningTicket at:339 independently reads the stored winnerProceeds into its own cashAmount and clears/transfers it. NftWon rightly returns0. The owner-only settle-and-redeem test passes.

Evidence: `testOwnerCanSettleAndRedeemAtomicallyButApprovedOperatorCannot` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:803; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

### Aderyn 11 — uninitialized-local-variable

Stable ID: `aderyn:uninitialized-local-variable:src/Raffle.sol:357:13972:5`. Raw pointer: `/low_issues/issues/5/instances/0`. Scanner severity: Low. Disposition: **informational_or_style**; confidence: high.

Source: `packages/contracts/src/Raffle.sol:357`.

Property: The refund loop starts at index 0 deterministically.

Exploit preconditions: Would require Solidity local uint256 default initialization not to be zero, contrary to language semantics.

uint256 index in the for initializer at Raffle.sol:357 is automatically zero-initialized. Explicit zero assignment would be stylistic only. The100-ticket proof and exact weighted refunds exercise inclusion of the first ticket and completion of all iterations.

Evidence: `testTriageOneHundredRefundBurnsSkipFactoryCallsInsideLoop` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/ScannerTriage.t.sol:61; PASS); `testWeightedRefundBatchPaysExactRangesAndConsumesOnce` (/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test/foundry/unit/Raffle.t.sol:1076; PASS).

Uncertainty: No unproven exploit precondition was accepted as fact; conclusion is limited to the frozen source and stated canonical dependencies.

Exact execution arguments are recorded in `/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/runtime/scanner-triage/test-execution.json`.

## Counts and limits

{"false_positive": 7, "informational_or_style": 8, "protected_intended_behavior": 7, "residual_limitation": 1}.

Seven false positives, seven protected intended behaviors, eight informational/style observations, and one residual limitation account for all 23 entries. No scanner instance was omitted or merged into an issue-class count. Slither observations with several flagged expressions list every expression location and distinguish their behavior in the corresponding analysis. Aderyn has no original per-instance ID, so a deterministic ID combines detector, original path, line, and source offset; raw JSON pointers preserve exact provenance.

Passing these tests does not prove overall contract security. Canonical USDC/wrapper identity and deployment configuration remain external assumptions. Timestamp findings are resolved against the specified intervals, not an assertion that validators have no transaction-inclusion influence. This report only reconciles the supplied scanner alerts.
