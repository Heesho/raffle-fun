# S6 secure-workflow-guide — native tool pass

All S1-S5 source-only seals precede START.json. No historical scanner output or external reconciliation used. Slither0.11.6 analyzed36contracts with102detectors and produced14results. Exit255 is findings-present, not a compilation failure. ERC721 conformity command succeeded. Inheritance graph, function-summary and vars-and-auth printers succeeded; raw outputs retained. Graph generated/rendered where available; complete visual review is INCOMPLETE.

## Step1 native scan triage
- events-maths (initialize): clone initialization is followed atomically by factory RaffleCreated carrying configuration (Factory:137-148); no standalone canonical-factory initializer route established. Informational logging recommendation, not confirmed loss.
- calls-loop (2): reported path refundTickets->_burn->_update passes to=zero; Raffle._update:498 short-circuits before _isProtocolDestination. No external factory call on this burn path. Bounded refund loop remains100.
- reentrancy-benign (2): factory creation guarded and calls its own fixed implementation initialization; requestDraw guarded, sets Drawing/_requestInFlight before wrapper call, and callback explicitly ignores in-flight responses (Raffle:252-260,509-515). No source-supported exploit established.
- timestamp (6): deliberate sale/request/callback/refund deadlines with exclusive windows; no randomness derived from timestamp.
- assembly (1): native excess refund call at Raffle:266-269 checks success and reverts atomically on failure.
- pragma (1): imported ranges and exact0.8.36 production constraint; not proof of different compiled versions.
- naming-convention (1): IRaffle.ENTRY_PRICE getter naming, informational.
These account for14reported results; none promoted to confirmed security finding.

## Step2 special features
ERC721 checker succeeded on Raffle. Fixed ERC1167 clones are present; no target-changing upgrade method found in source, so upgradeability-change checker is not applicable. ERC20-property generator is not applicable to an ERC721 implementation; quote integration source checklist is S3. On-chain token/deployment identity remains unknown.

## Step3 native visual artifacts
Inheritance DOT, function summary and variables/authorization outputs produced. Complete visual inspection not performed before deadline; not marked complete merely because files exist.

## Step4 properties and testing
Properties: one-time factory initialization; contiguous ranges; owner-only burn; pot conservation; no repeated claim; refunds1..100; callback sender/request/state/deadline binding; rollback on failed delivery; protocol-destination exclusion. Arithmetic-only AllocationProperties.sol and echidna.yaml created without changing production compiler inputs. This harness covers imported economics/math only, not end-to-end raffle execution. Echidna first attempt FAILED because solc executable was unavailable to its compiler adapter. First stderr retained. Manticore launch FAILED (executable unavailable). No fuzz or symbolic-verification success claimed; full harness/campaign BLOCKED/INCOMPLETE.

## Step5 manual areas
Privacy: entries, ranges and result are public; no secret/signature material found. Ordering: current owner controls redemption and tickets remain transferable; purchase ends before draw begins. Native fee refund rejection reverts request, other callers may request within window. Cryptography: randomness comes from authenticated wrapper; no ecrecover or custom signature scheme. DeFi: no price/AMM oracle; fixed token semantics and wrapper liveness remain trusted external assumptions. Search output preserved.

## Deferred and compatibility outputs
S2 entry-points and S3 human/contract summaries attempted after source seals; they do not retroactively change sealed stage conclusions or native ordering status. Forced-Foundry invocation is a separately logged compatibility experiment, with unchanged source/configuration. See execution-summary for exact outcomes. Overall S6 INCOMPLETE: native static work ran, but fuzzing/formal and complete visual review did not.
