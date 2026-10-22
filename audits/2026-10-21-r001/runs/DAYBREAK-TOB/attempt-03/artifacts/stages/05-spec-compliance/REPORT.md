# Spec-to-Code Compliance Report

**Conclusion:** the frozen contract implementation only partially matches DESIGN.md. Of 56 extracted properties, 45 initially held, seven divergences survived both independent refutation lenses, and four candidates were considered and dropped. The seven surviving requirement IDs consolidate into four root-cause findings, ordered by consequence: one Critical, one High, one Medium, and one Low.

| Finding | Severity | Surviving requirement IDs | Result |
| --- | --- | --- | --- |
| F-01 — Untrusted prize self-reports stand in for escrow and delivery | Critical | REQ-14, REQ-48, REQ-53 | A sponsor-selected contract can make creation look funded and can later withhold or fabricate prize delivery while quote-token liabilities are independently releasable (packages/contracts/src/RaffleFactory.sol:L127-L134,L154-L177; packages/contracts/src/Raffle.sol:L329-L337,L375-L391,L416-L430,L533-L555). |
| F-02 — A future clone address defeats destination invariants | High | REQ-44, REQ-47 | One accepted address lifecycle can strand sponsor proceeds and, on the separate prize path, receive an NFT from another clone (packages/contracts/src/RaffleFactory.sol:L105-L125,L154-L169; packages/contracts/src/Raffle.sol:L375-L405,L593-L604). |
| F-03 — The sponsor can close an empty raffle before its deadline | Medium | REQ-35 | The sponsor can enter Refunding and recover the prize before endTime while no entries have been sold (packages/contracts/src/Raffle.sol:L275-L300,L395-L405). |
| F-04 — Frontend fresh-state rereads are absent from the frozen target | Low | REQ-56 | The contracts expose live state and revalidate transactions, but no frontend implementation is present to satisfy the frontend-specific requirement (packages/contracts/src/interfaces/IRaffleFactory.sol:L132-L149; packages/contracts/src/Raffle.sol:L240-L250,L309-L321; dependency-hashes.json:L2-L32). |

## Scope and provenance

- Frozen target: /Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-TOB-continuation/target
- Controller-supplied frozen SHA: 9238b6ce8eb7f768c0dcd0cfcef26e1427a03155. The frozen directory has no Git metadata, so this Report phase records rather than independently recomputes that commit identity.
- Authoritative specification checked: DESIGN.md:L1-L4.
- Route tuple recorded by the controller: model gpt-daybreak-blue-latest; cyber access program daybreak_blue; reasoning effort ultra; fallback disabled. Provider identity remains unknown because no actual provider event was supplied.
- Native-controller adaptation: all 56 extracted requirements were checked, one per fresh exact-route context. This extends the native MAX_LIMIT selection count while retaining Extract → Align → Verify → Report, the native schemas and evidence rules, the reverse sweep, and two independent refuters for every non-implemented candidate.
- This was a source-only compliance pass. It did not read or run tests, scanners, prior audits, peer findings, other cells, attempt-02, S2-S4 reports, or cross-cell reconciliation.
- Code citations below are relative to the frozen target root. Every statement of intended behavior quotes DESIGN.md verbatim.

## Surviving divergences

### F-01 — Untrusted prize self-reports stand in for escrow and delivery

**Severity: Critical. Behavioral/security consequence.**

Surviving requirements:

- **REQ-14:** “Exactly one ERC721 prize is escrowed atomically at creation.” — DESIGN.md:L2
- **REQ-48:** “Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted.” — DESIGN.md:L2
- **REQ-53:** “Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted.” — DESIGN.md:L2

**What the code does instead.** Creation accepts any code-bearing sponsor-selected prize contract that returns true for its own ERC-165 query (packages/contracts/src/RaffleFactory.sol:L154-L177). The same selected contract executes safeTransferFrom and supplies the ownerOf answer used as the factory's custody postcondition (packages/contracts/src/RaffleFactory.sol:L127-L134). The raffle becomes Active when that contract calls the public receiver with the expected tuple; the receiver validates the caller and arguments but has no ownership fact independent of the caller (packages/contracts/src/Raffle.sol:L416-L430). Inline production documentation makes the dependency explicit by stating, “Supported prizes are honest, standards-compliant ERC-721s” (packages/contracts/src/interfaces/IRaffle.sol:L12-L15), which conflicts with DESIGN.md's verbatim “arbitrary prize contracts ... are untrusted” boundary.

The dependency persists after resolution. NftWon settlement allocates the gross quote-token pot into sponsor and protocol liabilities without touching the prize (packages/contracts/src/Raffle.sol:L533-L555), and those liabilities may be released in separate transactions without a winner-redemption or prize-delivery condition (packages/contracts/src/Raffle.sol:L375-L391). Winner redemption then calls the arbitrary prize's transferFrom and trusts that same contract's ownerOf report (packages/contracts/src/Raffle.sol:L329-L337).

**Reachability and consequence.**

1. An external sponsor selects a contract that reports ERC-721 support, invokes the raffle receiver with the accepted fields, and reports the new raffle as owner. Those are sufficient for createRaffle to publish the raffle as active (packages/contracts/src/RaffleFactory.sol:L97-L147; packages/contracts/src/Raffle.sol:L421-L430).
2. Entrants can then pay the immutable quote token; each purchase adds entryCount × 1,000,000 units to unsettledPot (packages/contracts/src/Raffle.sol:L209-L235; packages/contracts/src/libraries/RaffleConstants.sol:L20-L24).
3. A timely authenticated callback can select NftWon, after which permissionless settlement records sponsor and treasury claims and their release functions can complete (packages/contracts/src/Raffle.sol:L509-L523,L533-L557,L375-L391).
4. The prize contract can later revert on transfer, leaving the winner unable to complete redemption after earlier payout transactions have finalized, or it can return from transferFrom and report the winner from ownerOf without an independently established NFT ownership transition (packages/contracts/src/Raffle.sol:L323-L337). Reversion rolls back only that redemption transaction; it does not reverse earlier settlement or release transactions.

The demonstrated consequence is therefore not merely interface nonconformance: buyer-funded quote-token liabilities can be allocated and released although the target has no enforceable fact that one NFT was escrowed or delivered. An actor expressly outside the documented trust boundary chooses this path, so value can move under conditions DESIGN.md rules out. That makes the finding Critical under the consequence rubric. REQ-14, REQ-48, and REQ-53 are three views of this same root cause and are intentionally not counted as separate findings.

### F-02 — A future clone address defeats destination invariants

**Severity: High. Behavioral/security consequence.**

Surviving requirements:

- **REQ-44:** “Sponsor and treasury can claim independently after settlement.” — DESIGN.md:L2
- **REQ-47:** “Never move assets between raffle clones.” — DESIGN.md:L2

**What the code does instead.** Creation rejects a sponsor recipient only if it is already known as protocol plumbing or is already registered as a raffle (packages/contracts/src/RaffleFactory.sol:L154-L169). The factory later deploys clones with ordinary CREATE and registers their addresses (packages/contracts/src/RaffleFactory.sol:L105-L125; packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L24-L60). The raffle's runtime classifier treats a code-bearing address as unsafe when the factory now reports it as a raffle (packages/contracts/src/Raffle.sol:L593-L604).

The two asset paths then disagree:

- Sponsor quote proceeds pass through a fresh destination check, so releaseSponsorProceeds reverts after the stored recipient becomes a registered clone (packages/contracts/src/Raffle.sol:L375-L380,L564-L566,L598-L604).
- Sponsor-prize return reads the same stored recipient but performs no fresh destination check and calls unsafe ERC-721 transferFrom (packages/contracts/src/Raffle.sol:L395-L405). transferFrom does not invoke ERC721 receiver acceptance; only safeTransferFrom adds that callback (packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L75-L91).

**Reachability and consequence.** A sponsor can choose the predictable, presently code-less address of a future same-factory CREATE clone as raffle A's sponsorRecipient. It passes both current-state checks and is stored (packages/contracts/src/RaffleFactory.sol:L154-L169; packages/contracts/src/Raffle.sol:L181-L205,L593-L604). A later successful creation deploys and registers clone B at that address (packages/contracts/src/RaffleFactory.sol:L105-L125; packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L60).

Afterward, A's sponsor proceeds cannot be released because B is now rejected at transfer time, leaving the allocated sponsor bucket in A while the treasury's separate bucket remains callable (packages/contracts/src/Raffle.sol:L375-L391,L551-L555,L564-L566). On the prize-return path, however, A sends its prize directly to B without reclassification or a receiver callback (packages/contracts/src/Raffle.sol:L395-L405). The NFT is then outside B's raffle accounting, and the source says unrelated NFTs received through unsafe transferFrom cannot be rescued (packages/contracts/src/Raffle.sol:L409-L411).

This needs unusual but source-reachable nonce/address coordination, and the actor chooses the affected recipient. Those gates keep it below Critical. Enforcement exists on the ordinary paths yet fails on one reachable asset path, and the outcome includes both a blocked entitlement and an actual cross-clone NFT transfer, so High is consequence-proportionate. REQ-44 and REQ-47 are cross-linked here because both arise from the same time-of-check/time-of-use address classification.

### F-03 — The sponsor can close an empty raffle before its deadline

**Severity: Medium. Behavioral consequence with bounded reach.**

Surviving requirement:

- **REQ-35:** “Refunds open at deadline.” — DESIGN.md:L2

**What the code does instead.** Sold Active raffles reject refunds before endTime + 2 days, and Drawing raffles reject refunds before drawRequestedAt + 2 days; equality is accepted on both paths (packages/contracts/src/Raffle.sol:L285-L300,L458-L465; packages/contracts/src/libraries/RaffleConstants.sol:L32-L36). But on a zero-entry Active raffle, the only pre-endTime check is conditioned on msg.sender != sponsor. The sponsor therefore bypasses the assigned deadline, sets the same Refunding status, and can then release the prize (packages/contracts/src/Raffle.sol:L279-L300,L395-L405).

**Reachability and consequence.** Every newly activated raffle begins with zero entries because initialization does not add entries and purchases are the only positive totalEntries writer (packages/contracts/src/Raffle.sol:L176-L205,L223-L233). The sponsor can call enableRefunds before endTime, permanently close that raffle, and return the escrowed prize to sponsorRecipient (packages/contracts/src/Raffle.sol:L276-L300,L395-L406). No ticket owner loses a refund on this path because the branch requires zero sold entries. The established consequence is an early sponsor-controlled cancellation of an advertised raffle and early prize return; any wider reliance by prospective entrants was not established in source. The privilege, zero-entry condition, and bounded consequence make this Medium rather than High.

### F-04 — Frontend fresh-state rereads are absent from the frozen target

**Severity: Low. Out-of-scope implementation status, not a contract defect.**

Surviving requirement:

- **REQ-56:** “Frontend discovery is advisory; transaction decisions must reread current chain state.” — DESIGN.md:L2

**What the code does instead.** The frozen production scope consists of five Solidity files (packages/contracts/src/Raffle.sol:L1-L2; packages/contracts/src/RaffleFactory.sol:L1-L2; packages/contracts/src/interfaces/IRaffle.sol:L1-L2; packages/contracts/src/interfaces/IRaffleFactory.sol:L1-L2; packages/contracts/src/libraries/RaffleConstants.sol:L1-L2), and every declared dependency is also Solidity (dependency-hashes.json:L2-L32). The factory exposes current registry getters (packages/contracts/src/interfaces/IRaffleFactory.sol:L132-L149), and contract execution rereads current state—for example, requestDraw checks status, time, entries, deadline, and fee (packages/contracts/src/Raffle.sol:L240-L250), while redemption checks result, settlement state, winning ticket, and live ownership (packages/contracts/src/Raffle.sol:L309-L321). Those are useful on-chain defenses, but they are not frontend logic executed before a UI decides what transaction to offer or submit.

No frontend or off-chain transaction-decision artifact exists in the frozen target, so the Report phase cannot verify the required reread policy. This does not establish that a separately maintained production frontend violates the requirement; it establishes only that REQ-56 is absent from, and cannot be discharged by, this contract-only implementation scope. The consequence of stale frontend state is therefore unestablished here, and many attempted stale transactions would still meet contract-side revalidation. This is Low and should be resolved by supplying and checking the exact frontend revision, implementing the reads there, or explicitly moving that requirement outside this target's compliance claim.

## Alignment matrix — all 56 properties

All 56 extracted properties were checked. The native Align pass initially returned 45 implemented verdicts, seven candidates that survived both refuters, and four candidates that were dropped after refutation. The final matrix therefore contains 49 implemented properties, six partial properties, and one absent property. “Implemented after refutation” identifies a considered candidate, not a surviving divergence.

| Requirement | Final verdict | Concise evidence |
| --- | --- | --- |
| REQ-01 | Implemented | Creation validates and escrows the selected ERC-721, resolution selects an entry, and NftWon redemption transfers the configured NFT (packages/contracts/src/RaffleFactory.sol:L127-L134; packages/contracts/src/Raffle.sol:L518-L523,L329-L337). |
| REQ-02 | Implemented | The concrete factory stores its implementation in an immutable assigned during construction (packages/contracts/src/RaffleFactory.sol:L21-L42,L85-L91). |
| REQ-03 | Implemented | The sole creation path calls Clones.clone, whose selected overload emits fixed-target ERC-1167 bytecode with CREATE (packages/contracts/src/RaffleFactory.sol:L105-L106; packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L61). |
| REQ-04 | Implemented | The clone runtime embeds the implementation address rather than loading a writable implementation slot (packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L51-L57). |
| REQ-05 | Implemented | Every purchase computes entryCount × 1,000,000 and passes that amount to quoteToken.safeTransferFrom (packages/contracts/src/Raffle.sol:L218-L224; packages/contracts/src/libraries/RaffleConstants.sol:L20-L24). |
| REQ-06 | Implemented after refutation | DESIGN.md declares canonical USDC a trusted dependency; source assigns official-address verification to deployment tooling, then immutably propagates the selected six-decimal token (DESIGN.md:L2; packages/contracts/src/RaffleFactory.sol:L58-L78,L85-L91). |
| REQ-07 | Implemented | The price constant is 1,000,000 and factory construction rejects a quote token that does not report six decimals (packages/contracts/src/libraries/RaffleConstants.sol:L20-L24; packages/contracts/src/RaffleFactory.sol:L70-L78). |
| REQ-08 | Implemented | Each successful buyEntries execution records one range and invokes _safeMint exactly once (packages/contracts/src/Raffle.sol:L226-L236). |
| REQ-09 | Implemented | Raffle inherits ERC721; the base supplies interface discovery, ownership, approvals, and authorized transfers (packages/contracts/src/Raffle.sol:L28; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L44-L135,L164-L186). |
| REQ-10 | Implemented | transferFrom and both safe-transfer routes update live ownership through Raffle's destination-screening override (packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135; packages/contracts/src/Raffle.sol:L497-L502). |
| REQ-11 | Implemented | Purchase stores firstEntry and lastEntry under the new ticket ID, and ticketRange returns those endpoints (packages/contracts/src/Raffle.sol:L226-L232,L451-L455). |
| REQ-12 | Implemented | The sole range formula is [old total + 1, old total + entryCount], with no interior representation that could introduce gaps (packages/contracts/src/Raffle.sol:L226-L233). |
| REQ-13 | Implemented | Refund cardinality uses last − first + 1 and winning containment accepts equality at both endpoints (packages/contracts/src/Raffle.sol:L362-L364,L579-L584). |
| REQ-14 | Partial — F-01 | One scalar prize path exists, but activation and custody ultimately depend on the arbitrary prize contract's callback and ownerOf report (packages/contracts/src/RaffleFactory.sol:L127-L134,L171-L177; packages/contracts/src/Raffle.sol:L416-L430). |
| REQ-15 | Implemented | Creation carries one prize contract/token-ID pair and uses the ERC-721 transfer interface for that pair (packages/contracts/src/interfaces/IRaffleFactory.sol:L20-L25; packages/contracts/src/RaffleFactory.sol:L127-L128). |
| REQ-16 | Implemented | createRaffle does not return or emit RaffleCreated until transfer, ownership, and Active-status checks succeed (packages/contracts/src/RaffleFactory.sol:L127-L147). |
| REQ-17 | Implemented | Clone creation, initialization, registry writes, prize transfer, and postconditions occur in one uncaught createRaffle transaction (packages/contracts/src/RaffleFactory.sol:L97-L147). |
| REQ-18 | Implemented | Reserve-met resolution selects NftWon and owner-gated redemption transfers the configured prize (packages/contracts/src/Raffle.sol:L518-L523,L320-L337). |
| REQ-19 | Implemented | NftWon assigns grossPot minus the floored 5% protocol fee to sponsor proceeds (packages/contracts/src/libraries/RaffleConstants.sol:L11-L15; packages/contracts/src/Raffle.sol:L539-L555). |
| REQ-20 | Implemented | Settlement calculates protocolFee as floor(grossPot × 500 / 10,000) and stores it as protocolFees (packages/contracts/src/libraries/RaffleConstants.sol:L11-L15; packages/contracts/src/Raffle.sol:L539-L555; packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L216). |
| REQ-21 | Implemented | CashWon assigns floor(grossPot × 8,000 / 10,000) to winnerProceeds (packages/contracts/src/libraries/RaffleConstants.sol:L11-L18; packages/contracts/src/Raffle.sol:L545-L555). |
| REQ-22 | Implemented | CashWon gives the sponsor grossPot minus the 80% winner allocation and 5% fee, which is exactly 15% for reachable whole-entry pots (packages/contracts/src/Raffle.sol:L223-L233,L539-L555). |
| REQ-23 | Implemented | The same aggregate 5% protocol-fee calculation applies before the NftWon/CashWon branch (packages/contracts/src/Raffle.sol:L539-L555). |
| REQ-24 | Implemented | Refunding moves the whole pot into refund liability, and each burned ticket receives inclusive entry count × ENTRY_PRICE without fee arithmetic (packages/contracts/src/Raffle.sol:L296-L299,L349-L369). |
| REQ-25 | Implemented after refutation | The verbatim requirement says the prize “returns,” not that recipient equals depositor; creation documents a distinct immutable sponsorRecipient and refund-state release sends the prize there (DESIGN.md:L2; packages/contracts/src/interfaces/IRaffleFactory.sol:L14-L25; packages/contracts/src/Raffle.sol:L395-L405). |
| REQ-26 | Implemented | Purchases first accumulate their full gross amounts; one settlement helper then calculates the protocol fee from aggregate unsettledPot (packages/contracts/src/Raffle.sol:L223-L233,L533-L555). |
| REQ-27 | Implemented | The invoked three-argument Math.mulDiv explicitly computes floor(x × y / denominator) (packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L216). |
| REQ-28 | Implemented | NftWon uses fee plus gross-minus-fee; CashWon uses winner plus fee plus the subtraction remainder, while refunding preserves the whole pot (packages/contracts/src/Raffle.sol:L296-L299,L539-L555). |
| REQ-29 | Implemented | Protocol dependencies are constructor-set immutables and clone initialization is factory-only and one-shot; no administrator field appears in either configuration path (packages/contracts/src/RaffleFactory.sol:L32-L42,L65-L91; packages/contracts/src/Raffle.sol:L176-L205). |
| REQ-30 | Implemented | Factory configuration is assigned in construction and all per-raffle configuration writes occur in guarded initialization (packages/contracts/src/RaffleFactory.sol:L65-L91; packages/contracts/src/Raffle.sol:L176-L205). |
| REQ-31 | Implemented | The factory implementation reference is immutable and the chosen clone runtime embeds that target (packages/contracts/src/RaffleFactory.sol:L42,L89-L91,L105-L106; packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L51-L57). |
| REQ-32 | Implemented | requestDraw rejects timestamps below endTime and permits equality, subject to its remaining state and fee checks (packages/contracts/src/Raffle.sol:L240-L250). |
| REQ-33 | Implemented | drawRequestDeadline is endTime + 2 days and requestDraw rejects at or after that exclusive bound (packages/contracts/src/Raffle.sol:L244-L246,L458-L460; packages/contracts/src/libraries/RaffleConstants.sol:L32-L33). |
| REQ-34 | Implemented | callbackDeadline is drawRequestedAt + 2 days and the callback guard ignores equality and later times (packages/contracts/src/Raffle.sol:L463-L465,L509-L515). |
| REQ-35 | Partial — F-03 | Normal sold and Drawing paths open at equality, but a zero-entry sponsor bypasses the pre-endTime guard and enters Refunding early (packages/contracts/src/Raffle.sol:L279-L300). |
| REQ-36 | Implemented | Every accepted callback writes winningEntry, resolvedAt, and the terminal result before emitting RaffleResolved (packages/contracts/src/Raffle.sol:L509-L523). |
| REQ-37 | Implemented | The callback body contains only validation, entry calculation, result-state writes, and one event; settlement and delivery live in later entrypoints (packages/contracts/src/Raffle.sol:L504-L523,L528-L558). |
| REQ-38 | Implemented | settleWinningTicket is external and nonReentrant but has no actor-specific authorization; its helper checks only result, completion, and winning range (packages/contracts/src/Raffle.sol:L304-L305,L533-L558). |
| REQ-39 | Implemented | _settleWinningTicket only writes liability and result-accounting state and makes no token or NFT call (packages/contracts/src/Raffle.sol:L533-L558). |
| REQ-40 | Implemented | Both redemption settlement states converge on ownerOf(ticketId) and exact msg.sender equality before claim mutation (packages/contracts/src/Raffle.sol:L314-L325). |
| REQ-41 | Implemented | Successful redemption sets a one-way latch and invokes the inherited burn, which clears ownership (packages/contracts/src/Raffle.sol:L309-L325; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L303-L307). |
| REQ-42 | Implemented | Inline settlement, owner check, claim flags, burn, and NFT/cash delivery occur in the same redeemWinningTicket call (packages/contracts/src/Raffle.sol:L309-L345). |
| REQ-43 | Implemented | Prize transfer or ownership-check failure is uncaught, and SafeERC20 converts failed cash delivery into a revert, unwinding the same redemption transaction (packages/contracts/src/Raffle.sol:L329-L342; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L30-L46). |
| REQ-44 | Partial — F-02 | Settlement creates sponsor proceeds, but a recipient later registered as a clone is rejected by the claim-time destination check (packages/contracts/src/Raffle.sol:L375-L380,L551-L555,L593-L604). |
| REQ-45 | Implemented | releaseProtocolFees reads, clears, and transfers the complete independent protocolFees bucket to the immutable treasury (packages/contracts/src/Raffle.sol:L385-L391,L551-L555). |
| REQ-46 | Implemented after refutation | “Independently” concerns separate entitlements and ordering: settlement writes separate buckets, and either release clears only its own bucket; a destination prohibition is not cross-consumption by the other claim (DESIGN.md:L2; packages/contracts/src/Raffle.sol:L375-L391,L551-L555). |
| REQ-47 | Partial — F-02 | Ticket and quote paths recheck destinations, but sponsor-prize return omits that check and can transfer to a later-registered clone (packages/contracts/src/Raffle.sol:L395-L405,L497-L502,L564-L566,L593-L604). |
| REQ-48 | Partial — F-01 | Quote token and wrapper are pinned, but the sponsor-selected prize supplies the interface, transfer, callback, and ownership assertions treated as security facts (packages/contracts/src/RaffleFactory.sol:L65-L91,L127-L134,L171-L177; packages/contracts/src/interfaces/IRaffle.sol:L12-L15). |
| REQ-49 | Implemented | The selected quote token is immutable in the shared implementation, every clone has the fixed target, and all quote movements use that field (packages/contracts/src/RaffleFactory.sol:L85-L91,L105-L106; packages/contracts/src/Raffle.sol:L58,L161-L162,L223-L224,L564-L566). |
| REQ-50 | Implemented | The wrapper is constructor-fixed, requests target it, and raw callbacks require that exact sender (packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L34-L47,L76-L88,L101-L107). |
| REQ-51 | Implemented after refutation | DESIGN.md makes canonical wrapper identity a trusted deployment premise; source pins one constructor-selected wrapper for every request and callback with no replacement path (DESIGN.md:L2; packages/contracts/src/RaffleFactory.sol:L32-L42,L65-L91; packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L34-L47,L76-L107). |
| REQ-52 | Implemented | The sponsor supplies prizeToken; validation requires code and reported ERC-721 support but contains no trusted-prize allowlist (packages/contracts/src/RaffleFactory.sol:L97-L128,L154-L177). |
| REQ-53 | Partial — F-01 | Source explicitly assumes honest prizes, and NftWon quote liabilities can be released before the arbitrary prize is asked to deliver (packages/contracts/src/interfaces/IRaffle.sol:L12-L15; packages/contracts/src/Raffle.sol:L329-L337,L375-L391,L533-L555). |
| REQ-54 | Implemented | Ticket delivery uses guarded safe minting; contract-recipient rejection bubbles as a revert and nested guarded calls fail (packages/contracts/src/Raffle.sol:L209-L235; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L279-L290; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48; packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L105). |
| REQ-55 | Implemented | Transaction-critical contract paths derive decisions from current storage and environment, including requestDraw and redemption, rather than trusting discovery events (packages/contracts/src/Raffle.sol:L240-L250,L309-L321; packages/contracts/src/RaffleFactory.sol:L123-L147). |
| REQ-56 | Absent — F-04 | The scope supplies registry getters and contract-side revalidation but no frontend consumer or pre-decision reread implementation (packages/contracts/src/interfaces/IRaffleFactory.sol:L132-L149; packages/contracts/src/Raffle.sol:L240-L250; dependency-hashes.json:L2-L32). |

## Consequential undocumented behavior — reverse-direction sweep

The reverse sweep found 11 externally relevant behaviors that DESIGN.md does not describe. These are documentation gaps unless separately cross-linked to a surviving requirement finding.

### U-01 — Zero reserves and sales longer than 30 days are rejected

Factory validation rejects reserveEntries == 0, and createRaffle rejects a prospective sale duration above 30 days (packages/contracts/src/RaffleFactory.sol:L97-L104,L154-L179; packages/contracts/src/libraries/RaffleConstants.sol:L29-L30). Any prospective sponsor can reach these rejections through createRaffle. DESIGN.md says, “Reserve met awards NFT and 95% sponsor / 5% treasury. Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury” and specifies request/callback timing, but it states neither a positive reserve minimum nor a maximum sale duration (DESIGN.md:L2).

### U-02 — The depositor can nominate a different permanent beneficiary

createRaffle records msg.sender as sponsor while accepting a separate sponsorRecipient; proceeds and every returned prize go to the latter (packages/contracts/src/RaffleFactory.sol:L97-L120,L154-L169; packages/contracts/src/Raffle.sol:L197-L204,L375-L405). A sponsor chooses this routing at creation, after which no recipient setter exists in the supplied configuration path. DESIGN.md says “95% sponsor,” “15% sponsor,” “Refund outcome ... returns prize,” and “Sponsor and treasury can claim independently” without introducing a separate beneficiary role (DESIGN.md:L2).

### U-03 — Ticket recipients are denied beyond the stated cross-clone rule

Every ticket mint and transfer rejects the raffle itself, factory, quote token, wrapper, configured prize token, implementation, and a currently registered same-factory raffle (packages/contracts/src/Raffle.sol:L491-L502,L587-L604). Buyers reach the rule by choosing a mint recipient; owners or approved operators reach it through inherited ERC-721 transfers (packages/contracts/src/Raffle.sol:L209-L235; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135). DESIGN.md promises “a transferable ERC721 ticket” and says “Never move assets between raffle clones,” but does not disclose the additional prohibited recipient classes (DESIGN.md:L2).

### U-04 — Draw requests are caller-funded native-token operations with fixed parameters and an atomic excess refund

Direct native transfers revert; requestDraw asks for one word with a 300,000 callback-gas limit and 30 confirmations, pays the wrapper, and sends excess native value back to msg.sender. A requester that cannot accept the excess causes the request transaction to revert (packages/contracts/src/Raffle.sol:L43-L50,L170-L173,L240-L272; packages/contracts/src/libraries/RaffleConstants.sol:L38-L42; packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L88). Any address can reach this path after the sale under the request-state conditions. DESIGN.md states only “Request window [sale end, end+2days)” and “Quote token and Chainlink wrapper are trusted canonical dependencies”; it does not specify the funder, native payment, one-word request, fixed gas/confirmation values, or refund callback (DESIGN.md:L2).

### U-05 — Authenticated but unusable callbacks are acknowledged and ignored

After wrapper authentication, a synchronous, wrong-state, wrong-ID, wrong-length, or late ABI-decodable callback emits VrfCallbackIgnored and returns normally without changing the result (packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L99-L107; packages/contracts/src/Raffle.sol:L504-L516). Only the configured wrapper can reach this behavior. DESIGN.md states “callback accepted strictly before request timestamp+2days” and “Callback records result only,” but does not say rejected authenticated callbacks return successfully or emit an acknowledgement (DESIGN.md:L2).

### U-06 — Winning entry selection uses modulo reduction

An accepted callback maps its sole word to (randomWords[0] % totalEntries) + 1 (packages/contracts/src/Raffle.sol:L509-L523). The configured wrapper reaches this operation with a timely matching callback. DESIGN.md says “Callback records result only” but gives no randomness-to-entry mapping, so a reader cannot reproduce the winning entry from the design alone (DESIGN.md:L2).

### U-07 — The sponsor has a zero-entry early-cancellation power

While Active with zero entries, the sponsor can enter Refunding before endTime; any caller can do so at or after endTime (packages/contracts/src/Raffle.sol:L275-L300). That state permits the prize-return path (packages/contracts/src/Raffle.sol:L395-L405). DESIGN.md says “Refunds open at deadline” and does not disclose this sponsor-only pre-deadline branch (DESIGN.md:L2). This is also the behavioral divergence reported as F-03 / REQ-35.

### U-08 — A refund call accepts at most 100 ticket IDs

refundTickets rejects an empty list and any list longer than MAX_REFUND_TICKET_BATCH_SIZE, which is 100 (packages/contracts/src/Raffle.sol:L348-L369; packages/contracts/src/libraries/RaffleConstants.sol:L26-L27). A current owner with more than 100 refundable tickets must use multiple transactions. DESIGN.md states “Refund outcome pays 100% per entry” but does not describe a batching limit (DESIGN.md:L2).

### U-09 — Claim releases are permissionless push operations with independently callable timing

Any address can trigger releaseSponsorProceeds or releaseProtocolFees once the corresponding bucket is nonzero, and any address can trigger prize return in CashWon or Refunding. Prize return does not require settlement or completion of ticket refunds (packages/contracts/src/Raffle.sol:L374-L406). The fixed recipient still receives the asset; the caller controls only timing. DESIGN.md says “Sponsor and treasury can claim independently after settlement” but does not disclose unrelated callers, or prize return as a separate pre-completion operation (DESIGN.md:L2).

### U-10 — Prize delivery does not require contract-recipient acceptance

Both winner delivery and sponsor-prize return use ERC-721 transferFrom rather than safeTransferFrom (packages/contracts/src/Raffle.sol:L329-L337,L395-L405). The inherited distinction is concrete: transferFrom updates ownership without a receiver callback, while safeTransferFrom adds checkOnERC721Received (packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L75-L91). A contract-valued ticket owner or sponsorRecipient therefore cannot reject delivery through IERC721Receiver. DESIGN.md says redemption “must revert all effects on delivery failure,” but does not define missing or rejecting receiver support as outside failure detection (DESIGN.md:L2).

### U-11 — Unsolicited NFTs can be stranded outside raffle accounting

The strict receiver accepts only the configured factory deposit, but an unrelated ERC-721 owner or operator can bypass receiver validation by calling that token's unsafe transferFrom with the raffle as recipient (packages/contracts/src/Raffle.sol:L409-L425; packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L75-L91). The raffle source states that such NFTs remain outside accounting and cannot be rescued (packages/contracts/src/Raffle.sol:L409-L411). DESIGN.md says “Exactly one ERC721 prize is escrowed atomically at creation” but gives no warning or recovery policy for unsolicited NFTs (DESIGN.md:L2).

## Problems in the documentation

1. **Contradictory prize trust model.** DESIGN.md says “arbitrary prize contracts and ticket recipients are untrusted” (DESIGN.md:L2), while the production interface says “Supported prizes are honest, standards-compliant ERC-721s” (packages/contracts/src/interfaces/IRaffle.sol:L12-L15). This contradiction is the documentation side of F-01.
2. **Refund timing omits a documented source exception.** DESIGN.md says “Refunds open at deadline” (DESIGN.md:L2), while the public interface says enableRefunds “Also closes an empty raffle immediately for the sponsor” (packages/contracts/src/interfaces/IRaffle.sol:L322-L324). Readers cannot derive the sponsor's early-cancellation authority from DESIGN.md.
3. **The sponsor beneficiary is undefined.** DESIGN.md allocates value to “sponsor” and says the refund outcome “returns prize” (DESIGN.md:L2), while the ABI defines sponsorRecipient as a separately selected recipient of proceeds and any returned prize (packages/contracts/src/interfaces/IRaffleFactory.sol:L14-L25; packages/contracts/src/interfaces/IRaffle.sol:L36-L53). The design should define whether “sponsor” means depositor, beneficiary, or both.
4. **The frontend requirement has no identified artifact.** DESIGN.md mandates, “Frontend discovery is advisory; transaction decisions must reread current chain state” (DESIGN.md:L2), but the frozen target and its dependency manifest contain only Solidity source (the five production headers at packages/contracts/src/Raffle.sol:L1-L2, packages/contracts/src/RaffleFactory.sol:L1-L2, packages/contracts/src/interfaces/IRaffle.sol:L1-L2, packages/contracts/src/interfaces/IRaffleFactory.sol:L1-L2, packages/contracts/src/libraries/RaffleConstants.sol:L1-L2; dependency-hashes.json:L2-L32). The design should name the frontend repository/revision or mark the requirement outside this artifact.
5. **Operational policy is materially under-specified.** The 11 reverse-direction items above include creation bounds, draw funding and fixed VRF parameters, ignored-callback handling, modulo selection, refund batching, permissionless release timing, unsafe prize delivery, and unsolicited-NFT handling. The closest DESIGN.md language is the single-line description at DESIGN.md:L2; none of those policies is stated there.

No extracted requirement was itself undecidable, and the two-lens verification recorded no additional internal contradiction within DESIGN.md beyond the cross-document issues above.

## Considered and dropped

These four candidates are not findings:

- **REQ-06 — canonical USDC identity:** dropped because “Quote token and Chainlink wrapper are trusted canonical dependencies” (DESIGN.md:L2) is a deployment trust premise, not a demand for on-chain address or code-hash attestation. Source assigns official-USDC verification to deployment tooling and immutably uses the selected six-decimal token (packages/contracts/src/RaffleFactory.sol:L58-L78,L85-L91).
- **REQ-25 — prize returned to the depositor:** dropped because “Refund outcome pays 100% per entry and returns prize” (DESIGN.md:L2) does not say the return address must equal the escrow source. The public configuration explicitly selects sponsorRecipient for any returned prize (packages/contracts/src/interfaces/IRaffleFactory.sol:L14-L25; packages/contracts/src/Raffle.sol:L395-L405).
- **REQ-46 — claim independence:** dropped because “Sponsor and treasury can claim independently after settlement” (DESIGN.md:L2) concerns separate buckets and claim ordering. Settlement creates separate balances and each release clears only its own balance; a later destination prohibition does not make one claim consume or gate the other (packages/contracts/src/Raffle.sol:L375-L391,L551-L555).
- **REQ-51 — canonical wrapper identity:** dropped because the same trusted-dependency premise does not require constructor-time Chainlink provenance proof. The chosen wrapper is immutable, handles every request, authenticates every callback, and has no replacement path (packages/contracts/src/RaffleFactory.sol:L32-L42,L65-L91; packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L34-L47,L76-L107).

## Coverage

### Per-property coverage

REQ-01 through REQ-56 are all present in the alignment matrix. Each was checked in its own fresh exact-route context. Every initial non-implemented verdict received two independent refutation lenses, one code-focused and one document-focused. There are no unchecked, failed, unreadable, or unverified properties.

### Production files

| File | Coverage and role |
| --- | --- |
| packages/contracts/src/Raffle.sol | Read in full; all lifecycle, purchase, draw, refund, settlement, redemption, release, receiver, callback, range, and destination branches were covered (representative surface packages/contracts/src/Raffle.sol:L151-L613). |
| packages/contracts/src/RaffleFactory.sol | Read in full; constructor trust anchors, clone creation, registration, prize escrow, postconditions, and validation were covered (packages/contracts/src/RaffleFactory.sol:L58-L185). |
| packages/contracts/src/interfaces/IRaffle.sol | Read in full; lifecycle/ABI semantics and inline trust assumptions were covered, including the honest-prize statement and public operation contracts (packages/contracts/src/interfaces/IRaffle.sol:L8-L53,L303-L520). |
| packages/contracts/src/interfaces/IRaffleFactory.sol | Read in full; creation ABI, sponsorRecipient semantics, deployment-tooling trust assignment, and registry getters were covered (packages/contracts/src/interfaces/IRaffleFactory.sol:L4-L25,L99-L149). |
| packages/contracts/src/libraries/RaffleConstants.sol | Read in full; rates, price, batch bound, sale bound, timing, gas, and confirmation constants were covered (packages/contracts/src/libraries/RaffleConstants.sol:L4-L42). |

### Dependency files

The completed native phase recorded all 31 dependency files as read in full and all 31 SHA-256 values as matching dependency-hashes.json. The manifest lines below identify every dependency in the reviewed closure.

| Dependency file | Coverage role | Manifest |
| --- | --- | --- |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol | ERC-721 ownership and safe/unsafe transfer contract; decisive for F-01, F-02, U-10, and U-11. | dependency-hashes.json:L2 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol | ERC-165 interface declaration used by prize admission. | dependency-hashes.json:L3 |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol | Quote-token transfer interface. | dependency-hashes.json:L4 |
| packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol | Wrapper price/request interface. | dependency-hashes.json:L5 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol | Full-precision floor mulDiv used by settlement. | dependency-hashes.json:L6 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SafeCast.sol | Integer conversion dependency and extreme timestamp lead. | dependency-hashes.json:L7 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/Panic.sol | Math failure support. | dependency-hashes.json:L8 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol | Guard enter/reject/reset behavior for state-changing entrypoints. | dependency-hashes.json:L9 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol | Generic storage-slot utility in the reviewed dependency closure. | dependency-hashes.json:L10 |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol | Ticket/prize receiver ABI. | dependency-hashes.json:L11 |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol | Ticket interface, authorization, ledger, mint, transfer, safe callback, and burn behavior. | dependency-hashes.json:L12 |
| packages/contracts/node_modules/@openzeppelin/contracts/interfaces/draft-IERC6093.sol | Standard token error declarations used by ERC-721/ERC-20 helpers. | dependency-hashes.json:L13 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/ERC165.sol | Base interface-discovery implementation inherited by ERC-721. | dependency-hashes.json:L14 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/Strings.sol | ERC-721 metadata formatting dependency. | dependency-hashes.json:L15 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/Bytes.sol | Byte-array utility in the reviewed dependency closure. | dependency-hashes.json:L16 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SignedMath.sol | Signed-number formatting dependency. | dependency-hashes.json:L17 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/Context.sol | ERC-721 message-sender abstraction. | dependency-hashes.json:L18 |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol | Contract-recipient acceptance and revert bubbling for safe ticket delivery. | dependency-hashes.json:L19 |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol | Ticket metadata interface. | dependency-hashes.json:L20 |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol | Quote-token call/return handling and delivery failure propagation. | dependency-hashes.json:L21 |
| packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC1363.sol | ERC-1363 interface dependency of SafeERC20. | dependency-hashes.json:L22 |
| packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC165.sol | Aggregated ERC-165 interface declaration. | dependency-hashes.json:L23 |
| packages/contracts/node_modules/@openzeppelin/contracts/interfaces/IERC20.sol | Aggregated ERC-20 interface declaration. | dependency-hashes.json:L24 |
| packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol | Native-payment request argument encoding. | dependency-hashes.json:L25 |
| packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol | Immutable wrapper routing, native request, and callback caller authentication. | dependency-hashes.json:L26 |
| packages/contracts/node_modules/@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol | LINK-token interface dependency of the wrapper consumer base. | dependency-hashes.json:L27 |
| packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol | Six-decimal constructor query. | dependency-hashes.json:L28 |
| packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol | ERC-1167 fixed target and ordinary CREATE deployment used by the factory. | dependency-hashes.json:L29 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/Errors.sol | Clone deployment error support. | dependency-hashes.json:L30 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/Create2.sol | Alternate clone-library support; the selected production call uses ordinary CREATE, not CREATE2 (packages/contracts/src/RaffleFactory.sol:L105-L106; packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L24-L60). | dependency-hashes.json:L31 |
| packages/contracts/node_modules/@openzeppelin/contracts/utils/LowLevelCall.sol | Generic low-level-call utility in the reviewed dependency closure. | dependency-hashes.json:L32 |

## Depth gaps and unresolved leads

- **No dynamic corroboration.** This audit stage is source-only. Tests and scanner outputs were neither read nor run, so none of the reachable sequences above was dynamically reproduced. That limitation does not change source-visible verdicts, but reproduction would improve remediation confidence.
- **Concrete prize bytecode is outside scope.** The configured prize is supplied per raffle and no concrete implementation is frozen here (packages/contracts/src/RaffleFactory.sol:L109-L128,L154-L177). F-01 establishes a permitted source path, not that every deployed prize is malicious. Deployed prize bytecode and upgrade controls are needed to assess individual raffles.
- **Deployment provenance is outside scope.** The actual factory deployment transaction, chain ID, quote-token address, wrapper address, and wrapper administration are absent. Source expressly assigns official-USDC verification to deployment tooling (packages/contracts/src/RaffleFactory.sol:L58-L63; packages/contracts/src/interfaces/IRaffleFactory.sol:L6-L9). This is why REQ-06 and REQ-51 were dropped rather than reported, but the concrete deployment identities remain unverified.
- **No live nonce/state check.** F-02 follows from ordinary CREATE and current-state registry checks (packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L24-L60; packages/contracts/src/RaffleFactory.sol:L105-L125), but no deployed factory nonce, transaction ordering, or affected raffle was inspected.
- **Frontend remains an external lead.** No frontend source or revision is in the frozen target. A separately maintained frontend could satisfy REQ-56; it must be supplied and checked before making a system-wide compliance claim.
- **Extreme timestamp width was not resolved.** drawRequestedAt and resolvedAt narrow block.timestamp to uint64 (packages/contracts/src/Raffle.sol:L111-L115,L252-L253,L518-L520). No environmental proof was supplied that every possible timestamp fits uint64. This far-horizon lead is separate from, and cannot remove, F-03.

## Completeness status

- **Not checked:** None.
- **Checks failed:** None.
- **Unreadable documents:** None.
- **Unverified divergences:** None.




