# Raffle system context dossier

Scope: target commit `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`; synthesis of the supplied orientation and all 12 compact function records. This document builds context only: no findings, severities, fixes or exploit conclusions. The 40 orientation candidates include 12 separate function analyses and 28 candidates without separate depth analyses; transitive inspection does not change that coverage label. Line citations below refer to the supplied source-backed records, not a fresh source audit. `Factory` means `target/packages/contracts/src/RaffleFactory.sol`; `Raffle` means `target/packages/contracts/src/Raffle.sol`; dependency basenames are the exact module paths in the orientation.

## Architecture and cross-function invariants

The immutable factory creates fixed-target clones. Factory construction deploys the implementation; the implementation constructor locks its own initializer storage, while each fresh clone begins with separate zeroed storage. The canonical factory alone initializes each clone. Factory validation and creation establish timing, reserve, sponsor identity, treasury and registry relationships that initialize merely copies or relies upon. Independent Raffle deployments are outside this canonical-construction argument (Factory L65-L125; Raffle L155-L205; initialize and createRaffle records).

| State coupling | Writers and readers | Derived invariant and boundary |
|---|---|---|
| Canonical identity and registry | Factory constructor writes dependencies/implementation; createRaffle writes count, raffleById, idByRaffle and isRaffle. Validation, initialization and ownership/payout destination screening read these values. | Successful canonical creation links one incremented ID to its clone in both directions. Registration precedes prize interaction; transaction rollback binds the published registry to successful completion. Clone/factory guards are separate. Factory L89-L134; Raffle L187-L195,L598-L604. |
| Configuration and initialization | initialize writes sponsor, sponsorRecipient, treasury, prize address/ID, raffleId, reserve and endTime once; sales, callbacks, refunds and releases read them. | Canonical caller relationships and future/bounded sale time arise from factory checks plus one-time initialization. Configuration does not itself establish escrow or Active state. Factory L98-L121,L154-L178; Raffle L176-L205,L421-L428. |
| Lifecycle and supply freeze | initialize -> AwaitingPrize; receiver -> Active; requestDraw -> Drawing; callback -> NftWon/CashWon; enableRefunds -> Refunding. buyEntries reads Active. | Entries change only during Active before endTime. A successful request requires positive supply, so callback modulo uses a positive frozen total. Winning and refund branches have no recorded transition back to sales. Raffle L205,L215-L233,L241-L253,L279-L300,L428,L511-L521. |
| Tickets and entry intervals | buyEntries appends ranges and increments lifetime totalEntries/ticketCount; ERC721 updates ownership/approvals; redemption/refunds burn. Settlement reads ranges; claims read live owners first. | Historical ranges uniquely partition [1,totalEntries]; ticketCount <= totalEntries. Transfers and burns do not erase ranges or decrement lifetime supply. Thus a range getter is not proof of a currently existing ticket, and settlement does not choose the beneficiary. Raffle L218-L235,L320-L325,L359-L364,L451-L455,L533-L558; ERC721 L216-L244. |
| Request identity and clocks | requestDraw writes Drawing, drawRequestedAt, _requestInFlight and vrfRequestId; callback and timeout paths read them. | In-flight callbacks are ignored, ID is stored before the flag clears, and only a matching timely one-word callback in Drawing resolves. Request and callback strict cutoffs meet inclusive refund cutoffs exactly; nonzero callback deadline also depends on stored nonzero request time. Raffle L245-L272,L285-L291,L458-L465,L510-L521. |
| Purchase ledger and branch exclusivity | buyEntries grows unsettledPot; enableRefunds moves it to remainingRefundLiability; settlement moves it into winner/sponsor/protocol allocations. | Before reclassification, nominal pot tracks entry price times cumulative purchased entries. Refunding and winning settlement require disjoint statuses, preventing both allocations from the same lifecycle path. Each move conserves accounted nominal quote liability. Actual token backing is an explicit external assumption. Raffle L223-L233,L279-L299,L468-L475,L533-L555. |
| Terminal allocation and consumption | _settleWinningTicket writes winningTicketId, settlementComplete and allocations; redemption consumes winnerProceeds; sponsor/treasury releases consume their own balances. | Settlement occurs once, with protocol floor(5%), cash winner floor(80%) only in CashWon, and sponsor residual; allocations exactly sum to prior pot. Recipient selection remains current-owner based until redemption. Independent releases do not depend on winner collection. Raffle L314-L342,L375-L392,L533-L558; constants L12-L21. |
| Refund liability | enableRefunds assigns old pot; refundTickets checks 1–100 live owned tickets, burns, sums historical range values and debits. | Refunding liability equals nominal value of unrefunded purchased ranges under the earlier purchase/range invariant; repeated IDs fail after first burn and rollback the call. Approval permits transfer, not owner-only refund. Raffle L296-L299,L349-L369; ERC721 L426-L431. |
| Prize and winner consumption | redeemWinningTicket sets winnerRecipient/winnerRedeemed, burns, and in NFT branch sets prizeClaimed; releaseSponsorPrize consumes prizeClaimed in CashWon/Refunding. | One flag couples the result-specific prize paths. Winner's identity becomes fixed only on redemption; prize correctness still depends on the configured contract's truthful transfer and ownerOf reports. Raffle L309-L346,L395-L407. |
| Ownership screening and guard state | initialize and _update use destination policy; quote payouts recheck it. Guard helpers mutate each instance's own guard slot. | Nonzero ticket destinations must pass current fixed-address/code/registry checks; burns bypass the policy. Screening supplies neither perpetual suitability nor receiver acceptance. Guarded functions exclude each other within one instance, while inherited transfers remain available. Raffle L187-L195,L497-L502,L564-L567,L593-L605; ERC721 L115-L136; guard L69-L118. |

## End-to-end workflows

1. **Creation and activation:** sponsor submits parameters; factory validates code/interface, reserve and endTime, increments ID, creates/initializes clone, publishes registry, then calls prize safeTransferFrom. The matching receiver callback changes AwaitingPrize to Active; factory requires token-reported clone ownership and Active before returning. All successful-creation guarantees are conditional on normal transaction completion; actual prize honesty is separate (Factory L97-L148; Raffle L176-L206,L416-L431).
2. **Purchase and bearer transfer:** payer sends nominal entryCount × 1,000,000 quote units; one ticket records the next inclusive entry range and the nominal pot grows. Safe mint establishes ownership before receiver execution. Owner/operators may subsequently transfer in any lifecycle state through the destination hook; buyer, initial recipient and eventual claimant need not coincide (Raffle L209-L237,L497-L502; ERC721 L115-L136,L287-L290).
3. **Draw and result:** anyone pays during [endTime,endTime+2 days) with positive supply. After an initial quote, requestDraw records Drawing/in-flight/request time; the base requotes and pays the wrapper, returning ID and actual quoted price. ID is stored, in-flight cleared, and excess must return successfully. Authenticated callback before its deadline stores one-based winningEntry and the reserve-dependent result without moving assets or allocating liabilities (Raffle L240-L273,L509-L524; consumer base L76-L107).
4. **Winning settlement and claims:** anyone supplies the historical range containing winningEntry, or the eventual owner settles while redeeming. One-time settlement binds ticket ID and conserves nominal pot across allocations. Current owner redemption burns the ticket and consumes the applicable winner claim before external payment; sponsor/protocol quote releases are separate. CashWon also permits prize return to sponsorRecipient (Raffle L304-L407,L533-L558).
5. **Refunds:** zero-entry Active permits sponsor cancellation before endTime and public activation afterward. Sold Active requires the request deadline; Drawing requires the callback deadline. Activation moves the whole nominal pot to refund liability. Each owner redeems bounded batches of live tickets for their range value; the prize has a separate sponsor-return path (Raffle L276-L301,L349-L407).

## Trust boundaries and reachability

- **Trusted deployment initiator** → `RaffleFactory.constructor / Raffle.constructor`: Binds immutable quote token, wrapper, treasury and implementation; code/decimals checks do not independently establish canonical identity (Factory L65-L92; Raffle L155-L166).
- **Untrusted sponsor and arbitrary prize contract** → `createRaffle -> initialize -> prize.safeTransferFrom -> onERC721Received`: Configuration, registry publication, callback activation and token-reported escrow checks; factory guard is instance-local (Factory L97-L148; Raffle L176-L206,L416-L431).
- **Untrusted payer and ticket recipient** → `buyEntries -> quote transfer -> safe mint -> receiver callback`: Quote boundary, cumulative range/value ledger and ERC721 ownership; callback can use unguarded inherited transfers (Raffle L209-L237,L497-L502; ERC721 L115-L136,L287-L290).
- **Untrusted ticket owner and approved operators** → `approve / setApprovalForAll / transferFrom / safeTransferFrom`: Delegated transfer authority and destination screening in all lifecycle states; only current owners can redeem/refund (ERC721 L93-L136,L383-L418; Raffle L320-L321,L359-L360,L497-L502).
- **Permissionless native fee payer and trusted canonical wrapper** → `requestDraw -> pricing/payment; rawFulfillRandomWords -> fulfillRandomWords`: Native overpayment refund, request identity and deadline gates; wrapper origin is authenticated, service/randomness properties remain external assumptions (Raffle L240-L273,L509-L524; consumer base L76-L107).
- **Permissionless lifecycle and settlement caller** → `enableRefunds / settleWinningTicket`: Timeout-dependent liability reclassification or historical winning-range allocation; neither operation transfers assets (Raffle L276-L306,L533-L558).
- **Current ticket owner** → `redeemWinningTicket / refundTickets`: Live-owner check, claim/ticket consumption and external prize or quote payout; atomic failure restores the transaction (Raffle L309-L372).
- **Permissionless release caller; untrusted fixed recipients** → `releaseSponsorProceeds / releaseProtocolFees / releaseSponsorPrize`: Separate allocated liabilities or prize claim paid to configured recipients; caller cannot select recipient (Raffle L375-L407).
- **Public readers and off-chain indexers** → `Raffle/factory/ERC721/consumer getters; receive`: Registry, historic ranges, accounting, ownership and fee views; empty-calldata direct native transfer reverts (orientation entrypoints; Raffle L170-L173,L436-L486; Factory L25-L54).

Chain timestamp, transaction ordering and rollback are trusted environment inputs, not properties established by the inspected contracts. Canonical quote identity and fee-free/non-rebasing transfer behavior, and canonical wrapper service behavior, are deployment/service assumptions. Sponsor-selected prize and ticket receiver code remain untrusted despite interface/callback checks (orientation actors; IRaffle L12-L15; Factory L58-L78).

## State inventory and provenance

The following retains every state item identified by orientation. Read consumers and cross-function implications are grouped in the coupling table above; getters also expose public configuration/accounting. External asset ledgers are separate from internal liabilities. ERC721 metadata is constructor storage on the implementation while raffle name/symbol overrides supply fixed metadata; consumer LINK/wrapper immutables originate in the implementation constructor and are shared by clones (orientation state and entrypoints; Raffle L436-L486; ERC721 L28-L34; consumer base L35-L46,L109-L117).

- `quoteToken` — target/packages/contracts/src/RaffleFactory.sol; writes: RaffleFactory.constructor.
- `vrfWrapper` — target/packages/contracts/src/RaffleFactory.sol; writes: RaffleFactory.constructor.
- `protocolTreasury` — target/packages/contracts/src/RaffleFactory.sol; writes: RaffleFactory.constructor.
- `raffleImplementation` — target/packages/contracts/src/RaffleFactory.sol; writes: RaffleFactory.constructor.
- `raffleCount` — target/packages/contracts/src/RaffleFactory.sol; writes: RaffleFactory.createRaffle.
- `raffleById` — target/packages/contracts/src/RaffleFactory.sol; writes: RaffleFactory.createRaffle.
- `idByRaffle` — target/packages/contracts/src/RaffleFactory.sol; writes: RaffleFactory.createRaffle.
- `isRaffle` — target/packages/contracts/src/RaffleFactory.sol; writes: RaffleFactory.createRaffle.
- `factory` — target/packages/contracts/src/Raffle.sol; writes: Raffle.constructor (implementation bytecode immutables shared by clones).
- `quoteToken` — target/packages/contracts/src/Raffle.sol; writes: Raffle.constructor (implementation bytecode immutables shared by clones).
- `sponsor` — target/packages/contracts/src/Raffle.sol; writes: Raffle.initialize.
- `sponsorRecipient` — target/packages/contracts/src/Raffle.sol; writes: Raffle.initialize.
- `protocolTreasury` — target/packages/contracts/src/Raffle.sol; writes: Raffle.initialize.
- `prizeToken` — target/packages/contracts/src/Raffle.sol; writes: Raffle.initialize.
- `prizeTokenId` — target/packages/contracts/src/Raffle.sol; writes: Raffle.initialize.
- `raffleId` — target/packages/contracts/src/Raffle.sol; writes: Raffle.initialize.
- `reserveEntries` — target/packages/contracts/src/Raffle.sol; writes: Raffle.initialize.
- `endTime` — target/packages/contracts/src/Raffle.sol; writes: Raffle.initialize.
- `initialized` — target/packages/contracts/src/Raffle.sol; writes: Raffle.constructor (implementation storage), Raffle.initialize (clone storage).
- `totalEntries` — target/packages/contracts/src/Raffle.sol; writes: Raffle.buyEntries.
- `ticketCount` — target/packages/contracts/src/Raffle.sol; writes: Raffle.buyEntries.
- `_ticketRanges` — target/packages/contracts/src/Raffle.sol; writes: Raffle.buyEntries.
- `unsettledPot` — target/packages/contracts/src/Raffle.sol; writes: Raffle.buyEntries, Raffle.enableRefunds, Raffle._settleWinningTicket.
- `remainingRefundLiability` — target/packages/contracts/src/Raffle.sol; writes: Raffle.enableRefunds, Raffle.refundTickets.
- `winnerRecipient` — target/packages/contracts/src/Raffle.sol; writes: Raffle.redeemWinningTicket.
- `winnerRedeemed` — target/packages/contracts/src/Raffle.sol; writes: Raffle.redeemWinningTicket.
- `winnerProceeds` — target/packages/contracts/src/Raffle.sol; writes: Raffle._settleWinningTicket, Raffle.redeemWinningTicket.
- `sponsorProceeds` — target/packages/contracts/src/Raffle.sol; writes: Raffle._settleWinningTicket, Raffle.releaseSponsorProceeds.
- `protocolFees` — target/packages/contracts/src/Raffle.sol; writes: Raffle._settleWinningTicket, Raffle.releaseProtocolFees.
- `vrfRequestId` — target/packages/contracts/src/Raffle.sol; writes: Raffle.requestDraw.
- `drawRequestedAt` — target/packages/contracts/src/Raffle.sol; writes: Raffle.requestDraw.
- `_requestInFlight` — target/packages/contracts/src/Raffle.sol; writes: Raffle.requestDraw.
- `resolvedAt` — target/packages/contracts/src/Raffle.sol; writes: Raffle.fulfillRandomWords.
- `winningEntry` — target/packages/contracts/src/Raffle.sol; writes: Raffle.fulfillRandomWords.
- `winningTicketId` — target/packages/contracts/src/Raffle.sol; writes: Raffle._settleWinningTicket.
- `settlementComplete` — target/packages/contracts/src/Raffle.sol; writes: Raffle._settleWinningTicket.
- `status` — target/packages/contracts/src/Raffle.sol; writes: Raffle.constructor, Raffle.initialize, Raffle.onERC721Received, Raffle.requestDraw, Raffle.fulfillRandomWords, Raffle.enableRefunds.
- `prizeClaimed` — target/packages/contracts/src/Raffle.sol; writes: Raffle.redeemWinningTicket, Raffle.releaseSponsorPrize.
- `ERC721._owners` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol; writes: ERC721._update reached through Raffle._update from buyEntries, inherited transfers, refundTickets and redeemWinningTicket.
- `ERC721._balances` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol; writes: ERC721._update reached through Raffle._update from buyEntries, inherited transfers, refundTickets and redeemWinningTicket.
- `ERC721._tokenApprovals` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol; writes: ERC721._approve reached by approve and ownership updates.
- `ERC721._operatorApprovals` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol; writes: ERC721._setApprovalForAll reached by setApprovalForAll.
- `ERC721._name` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol; writes: ERC721.constructor on implementation; public raffle metadata overrides use fixed strings.
- `ERC721._symbol` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol; writes: ERC721.constructor on implementation; public raffle metadata overrides use fixed strings.
- `i_linkToken` — target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol; writes: VRFV2PlusWrapperConsumerBase.constructor (implementation bytecode immutables shared by clones).
- `i_vrfV2PlusWrapper` — target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol; writes: VRFV2PlusWrapperConsumerBase.constructor (implementation bytecode immutables shared by clones).
- `REENTRANCY_GUARD_STORAGE slot value per factory/raffle instance` — target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol; writes: ReentrancyGuard.constructor on deployed factory/implementation, _nonReentrantBefore, _nonReentrantAfter.
- `Escrowed prize ownership and quote/native balances (external ledger state)` — target/packages/contracts/src/Raffle.sol; writes: Factory.createRaffle prize transfer, buyEntries quote transfer, requestDraw native payment and refund, redeemWinningTicket, refundTickets, releaseSponsorProceeds, releaseProtocolFees, releaseSponsorPrize, unsolicited external token/native transfers outside internal accounting.

## Complexity concentrations

- **Prize activation and escrow reports:** Creation registers before the arbitrary prize call, while activation checks callback identities and the factory later checks reported owner/status. Source establishes those reports, with prize honesty separate (Factory L123-L134; Raffle L421-L430).
- **Bearer tickets versus historical ranges:** Range allocation and lifetime counters persist through transfers/burns; settlement needs range membership while claims need live ownership. Receiver callbacks can change owner before buyEntries returns (Raffle L226-L235,L320-L325,L359-L364,L451-L455,L533-L558).
- **Request, callback and refund boundary:** Two price queries, in-flight suppression, returned request ID, timestamp narrowing, strict callback/request cutoffs and inclusive timeout transitions interact (Raffle L240-L301,L458-L465,L509-L524).
- **Nominal liabilities and independent asset claims:** One pot becomes either refund liability or terminal allocations, then separately consumed balances; actual backing depends on external quote semantics and prize reports (Raffle L296-L299,L323-L405,L468-L475,L533-L566).
- **Destination screening and nested calls:** Initial configuration, mint/transfer and quote payouts reuse a current code/registry policy, while burns skip screening and inherited ERC721 transfers are outside the shared guarded entrypoints (Raffle L187-L195,L497-L502,L564-L567,L593-L605).

## Record tensions and contradiction handling

No direct mutually exclusive factual claims were identified in the 12 supplied compact records. The following tensions are retained with their original scope rather than silently strengthening either side:

- createRaffle: “Creation returns only after the prize reports the clone owner and the clone reports Active.” (Factory L128-L134), versus onERC721Received assumption: “Matching callback arguments correspond to genuine ERC-721 ownership transfer.” established by “nothing found; Raffle.sol L421-L430 checks identities only. IRaffle.sol L14-L15 documents honest ERC-721s; RaffleFactory.sol L128-L131 later checks token-reported ownership.” These are reported-state checks and an unresolved asset-semantic assumption, respectively.
- buyEntries: “Guarded raffle entrypoints cannot nest during payment or receiver execution; inherited ERC721 transfers remain callable, so final owner need not equal original recipient.” (Raffle L212,L224-L236; guard L69-L114; ERC721 L115-L136), alongside _update: “The hook and its callees impose no lifecycle or timestamp condition; transfer callers remain governed by authorization and destination screening.” (Raffle L497-L502,L593-L605). A guarded purchase does not promise stable post-callback recipient ownership.
- _settleWinningTicket: “Success stores the winning ID, clears unsettledPot and locks further settlement without transferring assets or reading ticket ownership.” (Raffle L533-L558), alongside redeemWinningTicket: “Successful redemption requires an unconsumed winner, a winning terminal result, the winning ticket ID and caller equal to its current live owner.” (Raffle L310-L321,L538,L551-L552; ERC721 L426-L431). Settlement and redemption intentionally prove different facts.
- Orientation describes the canonical factory/registered clones as trusted, while _update records: “Factory getter results correspond to the inspected canonical factory implementation; the hook itself does not authenticate factory code.” Canonical construction establishes that linkage; the record explicitly says nothing found for arbitrary independent Raffle deployments (Factory L89-L91; Raffle L155-L162).
- General callback timeout language must retain the zero-time branch: fulfillRandomWords records that callbackDeadline returns zero when drawRequestedAt is zero (Raffle L463-L465), and enableRefunds repeats that exception. Request timestamp width assumptions below remain unresolved; no unconditional nonzero timestamp invariant is inferred.

## Unenforced assumptions — verbatim request list

The following are the request's exact assumptions recorded as established by nothing; they are not findings.

createRaffle: Actual transfer enforces sponsor ownership and factory approval; ownership reports truthfully describe an honest persistent prize ledger (factory call/check at L128-L134).
buyEntries: Accepted quote-token transfer denotes exact grossAmount receipt and proper payer balance/allowance enforcement; wrapper does not compare balances.
buyEntries: Immutable quote address is canonical six-decimal USDC rather than merely code reporting six decimals.
requestDraw: Canonical wrapper prices, request identity and eventual asynchronous fulfillment are faithful; local code does not establish these service properties.
requestDraw: The uint64 request timestamp faithfully represents block.timestamp.
redeemWinningTicket: The prize contract reports real ownership after transfer.
redeemWinningTicket: The quote token transfers the exact amount without fees or rebasing and is canonical USDC.
refundTickets: Quote-token successful transfer delivers exactly the nominal amount under standard non-rebasing fee-free semantics.
fulfillRandomWords: The canonical service supplies randomness with the intended unpredictability/distribution; the inspected origin gate and modulo calculation do not establish those properties (base L101-L107; Raffle.sol:L518).
fulfillRandomWords: The explicit uint64 timestamp conversions preserve the full request/resolution time only when block.timestamp fits uint64; there is no local bound check (Raffle.sol:L253, L520).
_settleWinningTicket: Recorded quote liabilities have matching spendable token backing under the canonical fee-free non-rebasing transfer assumption.
initialize: The prize behaves as an honest standards-compliant ERC721, beyond its interface report (interfaces/IRaffle.sol:L13-L15; RaffleFactory.sol:L171-L178).
initialize: A destination passing current address/code/registry screening can control future payouts and remains suitable after initialization (Raffle.sol:L593-L604,L379-L405).
_update: Factory getter results correspond to the inspected canonical factory implementation; the hook itself does not authenticate factory code.
_validateCreateParams: A true supportsInterface response corresponds to actual standards-compliant ERC-721 behavior (RaffleFactory.sol:L172-L177; IERC165.sol:L17-L24).
onERC721Received: Matching callback arguments correspond to genuine ERC-721 ownership transfer.
onERC721Received: The arbitrary prize contract truthfully supplies operator/from and reports ownership.

## Every open question — verbatim record text

- createRaffle: unclear; need to inspect each actual sponsor-selected prize implementation for authorization, ownership honesty and callback ordering; RaffleFactory.sol:L128-L134 only checks reports and clone status.
- buyEntries: unclear; need to inspect actual quote-token implementation and deployment identity evidence to verify exact balance and allowance behavior (IERC20.sol L69-L78; RaffleFactory.sol L58-L78).
- buyEntries: unclear; need to inspect concrete recipient code to characterize callback actions and later ability to exercise claims (ERC721Utils.sol L32-L47; Raffle.sol L320-L321/L359-L360).
- requestDraw: unclear; need to inspect configured canonical wrapper implementation/configuration for price, request-ID and asynchronous service guarantees; only interface available (IVRFV2PlusWrapper.sol L23-L33, L67-L79).
- requestDraw: unclear; need to inspect any individual contract caller receive/fallback to establish successful positive-excess receipt (Raffle.sol L263-L269).
- redeemWinningTicket: unclear; need to inspect the configured prize implementation to establish truthful transfer and ownership-report semantics; paired external calls alone do not establish them (Raffle.sol L334-L336; IRaffle.sol L14-L15).
- redeemWinningTicket: unclear; need to inspect deployment dependency selection and canonical quote implementation to establish identity and exact-value transfers (Factory.sol L58-L77; Raffle.sol L560-L566). Live-chain verification is outside this context task.
- refundTickets: unclear; need to inspect the concrete canonical quote-token implementation/configuration to establish actual delivery, restriction/pause behavior, and callbacks (IERC20.sol L35-L41; SafeERC20.sol L176-L200; Raffle.sol L560-L566).
- _validateCreateParams: unclear; need to inspect the concrete sponsor-selected prize implementation to determine whether its supportsInterface assertion matches ERC-721 transfer and ownership behavior (RaffleFactory.sol:L172; IERC165.sol:L24).
- onERC721Received: unclear; need to inspect the concrete sponsor-selected prize contract to establish faithful transfer/callback and ownership-reporting semantics (IRaffle.sol L14-L15; RaffleFactory.sol L127-L131).

## Function-analysis index

- `createRaffle` — target/packages/contracts/src/RaffleFactory.sol L97-L148; [audit/S1/audit-context/functions/01-createRaffle.md](audit/S1/audit-context/functions/01-createRaffle.md).
- `buyEntries` — target/packages/contracts/src/Raffle.sol L209-L237; [audit/S1/audit-context/functions/02-buyEntries.md](audit/S1/audit-context/functions/02-buyEntries.md).
- `requestDraw` — target/packages/contracts/src/Raffle.sol L240-L273; [audit/S1/audit-context/functions/03-requestDraw.md](audit/S1/audit-context/functions/03-requestDraw.md).
- `redeemWinningTicket` — target/packages/contracts/src/Raffle.sol L309-L346; [audit/S1/audit-context/functions/04-redeemWinningTicket.md](audit/S1/audit-context/functions/04-redeemWinningTicket.md).
- `refundTickets` — target/packages/contracts/src/Raffle.sol L349-L372; [audit/S1/audit-context/functions/05-refundTickets.md](audit/S1/audit-context/functions/05-refundTickets.md).
- `fulfillRandomWords` — target/packages/contracts/src/Raffle.sol L509-L524; [audit/S1/audit-context/functions/06-fulfillRandomWords.md](audit/S1/audit-context/functions/06-fulfillRandomWords.md).
- `_settleWinningTicket` — target/packages/contracts/src/Raffle.sol L533-L558; [audit/S1/audit-context/functions/07-_settleWinningTicket.md](audit/S1/audit-context/functions/07-_settleWinningTicket.md).
- `enableRefunds` — target/packages/contracts/src/Raffle.sol L276-L301; [audit/S1/audit-context/functions/08-enableRefunds.md](audit/S1/audit-context/functions/08-enableRefunds.md).
- `initialize` — target/packages/contracts/src/Raffle.sol L176-L206; [audit/S1/audit-context/functions/09-initialize.md](audit/S1/audit-context/functions/09-initialize.md).
- `_update` — target/packages/contracts/src/Raffle.sol L497-L502; [audit/S1/audit-context/functions/10-_update.md](audit/S1/audit-context/functions/10-_update.md).
- `_validateCreateParams` — target/packages/contracts/src/RaffleFactory.sol L154-L179; [audit/S1/audit-context/functions/11-_validateCreateParams.md](audit/S1/audit-context/functions/11-_validateCreateParams.md).
- `onERC721Received` — target/packages/contracts/src/Raffle.sol L416-L431; [audit/S1/audit-context/functions/12-onERC721Received.md](audit/S1/audit-context/functions/12-onERC721Received.md).

## 28 candidates without separate depth analysis

These retain their orientation rationale verbatim. Some callees were followed within a selected caller analysis; none has a separate selected-function record in this run.

- `_isProtocolDestination` — target/packages/contracts/src/Raffle.sol: L593-L605: central address policy links initialization, ticket ownership and payout recipients to the canonical factory registry.
- `releaseSponsorPrize` — target/packages/contracts/src/Raffle.sol: L395-L407: validates the return branch and one-time prize claim before external transfer and ownership verification.
- `_transferQuote` — target/packages/contracts/src/Raffle.sol: L564-L567: common payout boundary screens destinations and invokes the trusted token through SafeERC20 for all quote claims.
- `releaseSponsorProceeds` — target/packages/contracts/src/Raffle.sol: L375-L382: clears the allocated sponsor liability before paying its fixed recipient, independently of other claims.
- `releaseProtocolFees` — target/packages/contracts/src/Raffle.sol: L385-L392: clears the allocated treasury liability before paying its fixed recipient, independently of other claims.
- `constructor` — target/packages/contracts/src/RaffleFactory.sol: L65-L92: permanently binds dependency identities, token precision, treasury and implementation for every future clone.
- `constructor` — target/packages/contracts/src/Raffle.sol: L155-L166: binds factory and quote immutables, initializes the wrapper base and locks implementation storage against initialization.
- `_requireWinningTicket` — target/packages/contracts/src/Raffle.sol: L579-L585: validates the supplied historical entry range used to assign the single winning ticket and its liabilities.
- `rawFulfillRandomWords` — target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol: L101-L107: inherited external authentication boundary restricts randomness delivery to the immutable wrapper.
- `_update` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol: L216-L250: performs optional owner/operator authorization, clears approvals, and changes ticket owners and balances for every transfer/mint/burn.
- `transferFrom` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol: L115-L125: binds caller authorization, claimed from-address and nonzero destination to ticket ownership changes.
- `_approve` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol: L383-L401 four-argument overload: validates approval authority and mutates per-ticket delegation, including clearing it during transfers.
- `_checkAuthorized` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol: L179-L187: enforces owner, token approval or global operator authority and distinguishes absent tickets from unauthorized callers.
- `_setApprovalForAll` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol: L409-L418: validates identities and persists holder-wide transfer delegation used by all subsequent transfer authorization.
- `checkOnERC721Received` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol: L25-L50: crosses the untrusted receiver boundary after mint/safe-transfer state changes and rejects incompatible callbacks.
- `requestRandomnessPayInNative` — target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol: L76-L89: requotes the wrapper, forwards exact native request payment and returns the authoritative request ID and fee.
- `_safeTransferFrom` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol: L212-L249: low-level incoming quote transfer validates external call success and optional return data before purchase accounting proceeds.
- `_safeTransfer` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol: L176-L199: low-level outgoing quote transfer validates external call success and optional return data for consumed liabilities.
- `clone` — target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol: L49-L66 two-argument overload: constructs fixed-target proxy bytecode with CREATE and verifies deployment success.
- `mulDiv` — target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol: L206-L277 three-argument overload: supplies exact floor rounding and bounded full-precision arithmetic for terminal monetary allocation.
- `_nonReentrantBefore` — target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol: L94-L100: checks and enters the shared instance guard before guarded lifecycle and asset-transfer operations.
- `_safeMint` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol: L287-L290 three-argument overload: combines unique-ticket minting with receiver acceptance after ownership becomes visible.
- `_mint` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol: L259-L267: validates a nonzero recipient and previously absent ticket while invoking the raffle ownership hook.
- `_burn` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol: L303-L308: consumes an existing ticket without performing caller authorization itself, relying on redemption/refund callers.
- `_requireOwned` — target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol: L426-L432: establishes that a ticket currently exists before owner-only claims and token approval paths proceed.
- `_requireStatus` — target/packages/contracts/src/Raffle.sol: L573-L575: shared lifecycle precondition for sale, draw and refund entrypoints.
- `_requireContract` — target/packages/contracts/src/RaffleFactory.sol: L183-L185: common deployed-code precondition for immutable dependencies and untrusted prize configuration.
- `_validatedVrfWrapper` — target/packages/contracts/src/Raffle.sol: L610-L613: establishes the nonzero wrapper input before the inherited constructor makes an external link() query.

## Execution provenance

Requested model/effort: gpt-6-astra / ultra; no fallback requested or enabled. Provider-returned model and effort: unknown. This is the hosted synthesis artifact; native host/Write-tool availability limitations are documented centrally by the audit orchestrator and are not converted into a claim of successful unavailable tooling. No vulnerability-hunting work occurred in this synthesis.
