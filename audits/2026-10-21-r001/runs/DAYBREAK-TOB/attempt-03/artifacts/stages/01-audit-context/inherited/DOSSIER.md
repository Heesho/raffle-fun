# Audit Context Dossier — Raffle Contracts

This is a context model, not a judgment pass. It records structure, invariants, assumptions, reachability, and unresolved questions only.

## Synthesis identity and coverage

- Target SHA: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`.
- Accepted selection: model `gpt-daybreak-blue-latest`, reasoning effort `ultra`, access program `daybreak_blue`, fallback `false`.
- Provider-returned model and provider identity: `unknown`.
- Native workflow default analyzed **12 of 24** ranked candidates. The synthesis barrier includes all 12 structured records and all 12 prose analyses.
- Complete first-party production coverage: `Raffle.sol` (lifecycle, custody, accounting, range tickets), `RaffleFactory.sol` (deployment, registry, escrow), `IRaffle.sol` (types, events, errors, full raffle ABI and dependency assumptions), `IRaffleFactory.sol` (creation ABI, registry ABI and deployment responsibility), and `RaffleConstants.sol` (economics, bounds, timeouts and VRF parameters).

Ranked below the native cut, and therefore not given standalone per-function records:

13. `Raffle.releaseSponsorPrize`
14. `RaffleFactory._validateCreateParams`
15. `Raffle._isProtocolDestination`
16. `Raffle._transferQuote`
17. `ERC721.transferFrom`
18. `ERC721.safeTransferFrom(address,address,uint256,bytes)`
19. `Raffle._requireWinningTicket`
20. `Raffle.releaseSponsorProceeds`
21. `Raffle.releaseProtocolFees`
22. `RaffleFactory.constructor`
23. `Raffle.constructor`
24. `ReentrancyGuard.nonReentrant path`

These functions were still encountered through complete production-file reading or followed as callees; “below the cut” means no separate micro-analysis document.

## System model

`RaffleFactory` fixes one quote token, VRF wrapper, treasury, and locked `Raffle` implementation. Any sponsor can request a new ERC-1167 clone. The factory validates inputs, creates and initializes the clone, registers it, transfers the selected NFT, verifies token-reported custody and `Active` status, then emits `RaffleCreated` (`RaffleFactory.sol:L65-L92`, `L97-L148`).

Each clone sells one transferable ERC-721 range ticket per purchase. Its stored inclusive ranges partition the sold global entry interval. After sale, a permissionless caller can fund a one-word VRF request. An authenticated, current, timely callback records a one-based winning entry and selects `NftWon` or `CashWon`; a later permissionless settlement maps that entry to a supplied ticket and allocates liabilities. The current ticket owner alone redeems. Timeout paths instead move the full unsettled pot into per-ticket refund liability (`Raffle.sol:L209-L372`, `L509-L558`).

Lifecycle transitions are:

`implementation: Refunding (locked)`; `clone: uninitialized -> AwaitingPrize -> Active -> Drawing -> {NftWon | CashWon}`; and `{Active | Drawing} -> Refunding`. Settlement and redemption add orthogonal completion flags without changing a terminal result (`Raffle.sol:L155-L205`, `L240-L345`, `L509-L558`).

## Cross-function state map and invariants

| State | Writers and readers | Cross-function invariant |
|---|---|---|
| Factory configuration and registry | Constructor fixes dependencies/implementation; `createRaffle` advances `raffleCount` and writes all three lookup mappings (`RaffleFactory.sol:L24-L54`, `L65-L125`). | A successful creation uses the incremented ID consistently in clone configuration, forward/reverse registry entries, and membership. Reverting external paths unwind the creation transaction. |
| Clone configuration | `initialize` writes sponsor, destinations, prize, ID, reserve and end time once; all lifecycle and payout paths read them (`Raffle.sol:L176-L205`). | A canonical returning initialization is factory-only, one-time, nonzero-address screened, and ends in `AwaitingPrize`. |
| Lifecycle/result | Prize callback activates; request enters `Drawing`; callback selects a terminal result; refund activation enters `Refunding` (`Raffle.sol:L240-L300`, `L416-L430`, `L509-L523`). | Sale mutation requires `Active`; therefore `totalEntries` is frozen during drawing and is nonzero on every accepted callback. A first accepted callback leaves `Drawing`, so later callbacks are ignored. |
| Draw coordination | `requestDraw` writes `drawRequestedAt`, `_requestInFlight`, and `vrfRequestId`; callback reads all three (`Raffle.sol:L252-L260`, `L509-L516`). | A synchronous wrapper callback is ignored while `_requestInFlight` is true. Later acceptance additionally requires wrapper identity, stored ID equality, one word, `Drawing`, and time strictly before the deadline. |
| Ticket ranges and ERC-721 ledger | Purchases append `[oldTotal+1, oldTotal+entryCount]`; inherited ERC-721 moves ownership; burns do not delete `_ticketRanges` (`Raffle.sol:L218-L235`, `L451-L455`, `L497-L502`). | Successful purchases produce positive, sequential, disjoint ranges covering `1..totalEntries`. Settlement proves range containment; refund and redemption separately require exact current ownership. |
| Quote liabilities | Purchases grow `unsettledPot`; refund activation moves it to `remainingRefundLiability`; settlement replaces it with terminal buckets; claim paths clear their bucket before transfer (`Raffle.sol:L223-L233`, `L296-L299`, `L339-L342`, `L367-L390`, `L539-L555`). | Under the documented quote-token behavior, each branch conserves the recorded pot: refund is 100%; NFT result is 5% protocol plus sponsor remainder; cash result is 80% winner, 5% protocol, sponsor remainder. |
| Prize custody | Factory deposit activates the clone; NFT redemption or sponsor-prize release sets `prizeClaimed` and transfers the configured token (`RaffleFactory.sol:L127-L134`; `Raffle.sol:L329-L337`, `L395-L406`). | Successful source-visible release is one-time and finishes only after the prize contract reports the intended recipient as owner. |
| Shared guard | Each contract/clone has one fixed ReentrancyGuard slot shared by its protected entrypoints. | A protected call holds that instance's guard through its external calls; factory and each clone have distinct storage. |

## End-to-end flows

1. **Creation and escrow:** sponsor -> `createRaffle` -> validation -> clone -> `initialize` -> registry -> prize `safeTransferFrom` -> `onERC721Received` -> owner/status checks -> event. Sponsor-selected token code lies on the path between factory state and publication.
2. **Purchase and transfer:** buyer -> quote-token `transferFrom` -> append range/accounting -> safe mint -> optional receiver callback. Later owner/operator transfers pass inherited authorization, `Raffle._update` destination screening, ledger mutation, and optional receiver acceptance.
3. **Draw:** any funded caller -> lifecycle/time/entry checks -> two wrapper price/request interactions. State enters `Drawing` before the request; returned ID is persisted and the in-flight flag cleared before any excess native refund and `DrawRequested`.
4. **Resolution:** configured wrapper -> `rawFulfillRandomWords` caller check -> Raffle's current-request/shape/time guard -> winning entry/result storage only. At the exact callback deadline, callback acceptance is closed and the Drawing refund branch is eligible.
5. **Settlement and redemption:** any caller proposes a ticket; its historical range must contain `winningEntry`; settlement allocates the whole pot. The exact current ticket owner burns it, then receives either the NFT or the entire cash-winner bucket.
6. **Refund:** sponsor may open an empty Active raffle early; sold Active raffles open after the request deadline; Drawing raffles open at the callback deadline. The full pot becomes refund liability. Owners burn bounded batches and receive range length times entry price.
7. **Independent releases:** any caller can trigger sponsor and protocol quote payouts after their buckets exist, and can return the prize to `sponsorRecipient` in `CashWon` or `Refunding`; destinations are fixed at initialization.

## Actor, entrypoint, and reachability map

| Actor / trust | Entrypoint | What it reaches |
|---|---|---|
| Deployment tooling / trusted | `RaffleFactory` constructor | Selects quote token, wrapper, treasury, and deploys the shared implementation. |
| Sponsor / untrusted | `createRaffle` | Factory registry, clone initialization, sponsor-selected ERC-721 calls, prize receiver callback, published creation state. |
| Canonical factory / trusted | `initialize`; prize operator role | Establishes all clone configuration and is the only accepted initialization caller/operator. |
| Buyer / untrusted | `buyEntries` | Quote-token custody, range/liability state, ERC-721 mint, contract-recipient callback. |
| Permissionless keeper / untrusted | `requestDraw`, `enableRefunds`, `settleWinningTicket`, release functions | Draw state and native wrapper payment; refund transition; terminal allocation; fixed-destination asset releases. |
| Configured wrapper / trusted | `rawFulfillRandomWords` | Internal callback filter and, only on acceptance, `winningEntry`, `resolvedAt`, and terminal status. |
| Prize token / semi-trusted | `onERC721Received` with exact tuple | `AwaitingPrize -> Active`; its other calls also provide custody reports and delivery behavior. |
| Ticket owner / untrusted | `refundTickets`, `redeemWinningTicket` | Ticket burn, corresponding liability consumption, quote/NFT delivery. |
| Ticket owner or approved operator / untrusted | inherited approvals and transfers | ERC-721 authorization state, `Raffle._update`, destination screening, optional receiver callback. |
| Ticket receiver / untrusted | receiver callback after safe mint/transfer | Executes after ownership mutation; outer guarded operations remain guarded. |
| Quote token / trusted by configuration | ERC-20 calls | Actual custody movement beneath recorded quote liabilities. |
| Block timestamp / semi-trusted environment | time gates | Sale close, request window, callback window, and refund eligibility. |

## Trust boundaries

- Deployment selection -> immutable factory configuration: source checks code presence and token decimals, while canonical identity remains a deployment fact.
- Sponsor -> factory: untrusted creation fields cross validation into clone configuration, registry, and prize custody.
- Sponsor-selected ERC-721 -> factory/clone: self-reported interface support, transfer callbacks, `ownerOf`, and later delivery reports cross a black-box boundary.
- Buyer -> quote-token/clone: buyer-selected quantities and recipients become custody, liabilities, range records, and ticket ownership after local gates.
- Clone -> VRF wrapper: native value and request parameters leave the clone; price, request ID, scheduling, and callback data return from wrapper behavior not present in target.
- Wrapper -> callback gateway: address equality establishes caller identity; Raffle's downstream guard establishes current-request acceptance.
- ERC-721 owner/operator -> transferable claim ledger: ownership can change independently of historical entry ranges and lifecycle.
- Clone -> ticket receiver: safe mint/transfer invokes arbitrary receiver code after the ownership write.
- Recorded liabilities -> quote-token custody: equality depends on the configured token's documented fee-free, non-rebasing behavior.
- Fixed recipients -> external asset contracts: release paths consume recorded buckets/flags and then rely on token behavior to complete delivery.

## Fragility clusters

- **Creation ordering across three contracts:** clone registration precedes sponsor-selected NFT interaction; activation occurs in the receiver callback; post-callback checks and `RaffleCreated` occur afterward.
- **Asynchronous request/callback continuity:** two price observations, returned-ID persistence, `_requestInFlight`, a native refund call, strict deadline comparison, and later callback filtering jointly define the draw.
- **External dependency identity and semantics:** quote token, VRF wrapper, and arbitrary prize implementations carry properties that local code cannot derive from interface declarations alone.
- **Range-ticket proof versus live ownership:** historical ranges remain after burns while ERC-721 ownership is transferable; settlement, refund, and redemption each consume a different combination of those facts.
- **Accounting/custody coupling:** five liability buckets, actual quote balance, result branch, settlement flag, and independent claim paths must remain aligned.
- **Lifecycle/time boundaries:** the sale end, draw-request deadline, and callback deadline are exclusive on one side and refund-enabling on the other.
- **Central destination classification:** initialization, ticket updates, and quote payouts depend on the same local/factory registry classification and its external getter calls.

## Unenforced assumptions (`nothing found`) — verbatim carry-forward

1. **RaffleFactory.createRaffle** — “A true ERC-165 response from the sponsor-selected prize address corresponds to actual ERC-721 safe-transfer and ownership behavior.” Established by: “nothing found; target/packages/contracts/src/RaffleFactory.sol:L171-L177 records only the black-box self-report”
2. **RaffleFactory.createRaffle** — “The sponsor-selected prize contract enforces ownership or approval, transfers the selected token, invokes the receiver with the standard arguments, and honors the returned selector.” Established by: “nothing found; these are interface requirements at target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L42-L73 and target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol:L11-L27, but the selected implementation is absent”
3. **RaffleFactory.createRaffle** — “The sponsor-selected prize contract's ownerOf result truthfully represents persistent ownership by the clone.” Established by: “nothing found; createRaffle checks one black-box return at target/packages/contracts/src/RaffleFactory.sol:L129-L131”
4. **RaffleFactory.createRaffle** — “Sponsor-selected code does not leave the Active clone with additional creation-time state changes beyond those checked by the factory.” Established by: “nothing found; after target/packages/contracts/src/Raffle.sol:L428-L430 returns control to the token, createRaffle verifies only ownerOf and status at target/packages/contracts/src/RaffleFactory.sol:L129-L134”
5. **Raffle.requestDraw** — “calculateRequestPriceNative returns a meaningful price and requestRandomWordsInNative accepts the attached second price according to the declared interface.” Established by: “nothing found; only the declarations at target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L23-L33, L67-L81 are present”
6. **Raffle.requestDraw** — “A successful requestRandomWordsInNative return value is the identifier of an accepted request and is the identifier a later authenticated callback will carry; local code does not require it to be nonzero or independently prove uniqueness.” Established by: “nothing found; requestId is returned and stored directly at target/packages/contracts/src/Raffle.sol:L257-L260, while the wrapper implementation is absent”
7. **Raffle.requestDraw** — “block.timestamp is representable in uint64 so drawRequestedAt preserves the request timestamp and callbackDeadline does not encounter its zero sentinel through narrowing.” Established by: “nothing found; target/packages/contracts/src/Raffle.sol:L253 narrows without a bound check and L463-L465 treats zero specially”
8. **Raffle.fulfillRandomWords** — “The configured wrapper is the intended Chainlink wrapper and supplies the intended unpredictable, unbiased callback word.” Established by: “nothing found on chain beyond a code-length check; deployment trust is documented at target/packages/contracts/src/RaffleFactory.sol:L58-L67, and the external request is interface-only at target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L68-L81”
9. **Raffle.fulfillRandomWords** — “The request ID returned by requestRandomWordsInNative is bound by the deployed wrapper to the later callback carrying the corresponding word.” Established by: “nothing found in the target's wrapper implementation because only the interface is present; Raffle stores the returned ID and compares it at target/packages/contracts/src/Raffle.sol:L257-L260, L511-L515”
10. **Raffle.fulfillRandomWords** — “block.timestamp is representable as uint64 when resolvedAt is written.” Established by: “nothing found; target/packages/contracts/src/Raffle.sol:L520 narrows without a local range check”
11. **Raffle.redeemWinningTicket** — “The sponsor-selected prize contract honors ERC-721 transfer and ownership semantics and its ownerOf result represents actual ownership.” Established by: “Protocol trust assumption at target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15; factory checks ERC-165 and initial escrow ownership at target/packages/contracts/src/RaffleFactory.sol:L127-L134,L171-L177. Actual deployed implementation: nothing found in target/.”
12. **Raffle.redeemWinningTicket** — “A successful quote-token call moves exactly cashAmount without fees or rebasing.” Established by: “Protocol trust assumption at target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15 and helper documentation at target/packages/contracts/src/Raffle.sol:L560-L566; SafeERC20 checks only call/return behavior at target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L176-L199. Actual deployed implementation: nothing found in target/.”
13. **Raffle.enableRefunds** — “The contract's actual quote-token balance covers the accounting liability under fee-free, non-rebasing canonical USDC behavior.” Established by: “nothing found on chain; declared trust assumption at packages/contracts/src/interfaces/IRaffle.sol:L12-L15, while the factory checks only code and decimals at packages/contracts/src/RaffleFactory.sol:L58-L78”
14. **Raffle.refundTickets(uint256[])** — “The concrete quote token is official, standard, fee-free, non-rebasing six-decimal USDC and credits exactly amount on accepted transfer.” Established by: “Declared trust/deployment assumption; exact on-chain identity and recipient/balance delta verification: nothing found.” Evidence: `IRaffle.sol:L12-L15`, `Raffle.sol:L560-L566`, `RaffleFactory.sol:L65-L78`, `IRaffleFactory.sol:L6-L9`.
15. **Raffle.onERC721Received** — “The configured prize contract gives operator and from their ERC-721 meanings, transfers the configured NFT to the clone before acceptance completes, honors the selector, and preserves custody.” Established by: “The OpenZeppelin reference path has transfer-before-callback and selector enforcement at target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L135 and token/ERC721/utils/ERC721Utils.sol:L25-L48; for the actual sponsor-selected external token, nothing found beyond the standards-compliance trust statement at target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15.”
16. **Raffle.onERC721Received** — “The factory's post-transfer ownerOf response is a truthful representation of ownership.” Established by: “nothing found for the concrete external token; the factory queries and trusts ownerOf before comparing it at target/packages/contracts/src/RaffleFactory.sol:L127-L134.”
17. **Raffle.initialize** — “The configured quote token and VRF wrapper are the intended official external deployments.” Established by: “nothing found in target source; RaffleFactory checks deployed code and six quote-token decimals and explicitly assigns official-address verification to deployment tooling at target/packages/contracts/src/RaffleFactory.sol:L58-L78.”
18. **Raffle.initialize** — “The arbitrary sponsor-selected prize contract behaves as an honest standards-compliant ERC-721 throughout escrow and later delivery.” Established by: “nothing found that enforces behavior on every path; the factory checks code and a claimed ERC-721 interface response at target/packages/contracts/src/RaffleFactory.sol:L154-L177 and verifies ownership/status after escrow at L127-L134, while target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15 states the honest-prize assumption.”
19. **VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords** — “The wrapper binds returned randomness and request IDs to the earlier paid request.” Established by: “nothing found; wrapper implementation is absent, while Raffle only checks the stored ID and one-word shape.” Evidence: `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L68-L81; target/packages/contracts/src/Raffle.sol:L509-L518`.

## Record disagreements

No irreconcilable disagreement was found among the 12 records. Closely related statements were retained at their original scope rather than collapsed. In particular, the purchase record says, “A contract recipient's successful callback establishes ERC721 acceptance, but does not establish that recipient remains owner when buyEntries returns,” while the update record says, “After super._update succeeds, _owners[ticketId] equals to.” These describe different observation points: before versus after receiver execution. Likewise, the gateway record says, “Only msg.sender equal to the immutable configured wrapper reaches the virtual callback hook,” while the callback record says, “A decoded callback is ignored if the request is still in flight, status is not Drawing, the ID differs, the word count is not one, or the timestamp is at/after the callback deadline.” Caller authentication and application acceptance are distinct gates.

## Unresolved questions — verbatim carry-forward

### RaffleFactory.createRaffle

- unclear; need to inspect the deployed prize-token implementation and upgrade controls to establish its ERC-165, transfer, callback, and ownerOf behavior relied on at target/packages/contracts/src/RaffleFactory.sol:L127-L134 and L171-L177
- unclear; need to inspect the intended creation-time state contract to determine whether RaffleCreated is meant to imply zero entries or no other clone mutations after the callback activates the clone (target/packages/contracts/src/Raffle.sol:L208-L237, L428-L430; target/packages/contracts/src/RaffleFactory.sol:L129-L147)
- unclear; need to inspect external integrations to know how callers reconcile RaffleCreated with current registry, clone, and token state; no caller exists under target/packages/contracts/src (target/packages/contracts/src/interfaces/IRaffleFactory.sol:L28-L52, L99-L149)

### Raffle.requestDraw

- unclear; need to inspect the deployed Chainlink wrapper implementation to establish all paths of calculateRequestPriceNative and requestRandomWordsInNative, including quote stability, request-ID guarantees, and callback/re-entry behavior; target contains only IVRFV2PlusWrapper.sol:L23-L33, L67-L81
- unclear; need to inspect deployment configuration or records to establish that vrfWrapper_ is the intended canonical wrapper; target on-chain validation only requires deployed code at target/packages/contracts/src/RaffleFactory.sol:L65-L67

### Raffle.buyEntries

- unclear; need to inspect the deployed quote-token implementation and deployment evidence to confirm canonical identity and exact grossAmount balance-delta semantics; the target contains only its interface, trust requirement, and factory code/decimal checks (IRaffle.sol:L12-L15; IRaffleFactory.sol:L7-L9; RaffleFactory.sol:L66-L78).

### Raffle.fulfillRandomWords

- unclear; need to inspect the deployed wrapper implementation and deployment evidence to establish configured-code identity, callback-word provenance, and returned-ID/callback-ID binding (target/packages/contracts/src/RaffleFactory.sol:L58-L67; target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L68-L81)
- unclear; need to inspect deployed wrapper fulfillment/retry semantics after VrfCallbackIgnored is emitted and the handler returns successfully (target/packages/contracts/src/Raffle.sol:L509-L516)
- unclear; need to inspect deployment-chain timestamp bounds to establish that block.timestamp fits uint64 at resolution (target/packages/contracts/src/Raffle.sol:L520)

### Raffle.redeemWinningTicket

- unclear; deployed prize-token source is unavailable, so actual transferFrom callback behavior and ownerOf ledger semantics cannot be inspected (RaffleFactory.sol:L127-L134,L171-L177; IRaffle.sol:L12-L15).
- unclear; deployed quote-token source is unavailable, so the assumed exact fee-free, non-rebasing balance movement cannot be verified (IRaffle.sol:L12-L15; SafeERC20.sol:L176-L199).
- unclear; an arbitrary contract ticket owner receives the prize via transferFrom, so this path does not establish IERC721Receiver support or the winner contract's ability to operate the prize (Raffle.sol:L320-L334; IERC721.sol:L76-L91).

### Raffle.enableRefunds

- unclear; need to inspect deployment configuration and deployed quote-token behavior to establish the documented canonical, fee-free, non-rebasing USDC assumption; target code checks only code presence and six decimals (packages/contracts/src/RaffleFactory.sol:L58-L78; interfaces/IRaffle.sol:L12-L15)

### Raffle.refundTickets(uint256[])

- Need deployed quote-token bytecode/configuration to establish exact official-USDC identity and fee-free, non-rebasing, no-callback transfer semantics.
- Need concrete deployment provenance when applying this record outside the canonical RaffleFactory construction path, because Raffle later ABI-calls its constructor caller as IRaffleFactory.

### Raffle.onERC721Received

- unclear; need to inspect each concrete configured prize-token implementation to establish transfer ordering, callback-field fidelity, selector enforcement, and ownerOf custody semantics; target/ contains no sponsor-selected token implementation.

### Raffle.initialize

- unclear; need to inspect deployment records or live chain configuration outside target source to confirm that quoteToken and vrfWrapper are the intended official deployments; source documents this tooling responsibility at target/packages/contracts/src/RaffleFactory.sol:L58-L78.
- unclear; need to inspect each dynamically selected prize-token implementation to determine behavior beyond the visible code-presence/interface-response checks and post-transfer ownership/status checks at target/packages/contracts/src/RaffleFactory.sol:L127-L134, L154-L177.

### VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords

- Wrapper implementation behavior for request binding, word generation, scheduling, retry, and gas forwarding is not visible in target.
- Actual deployed wrapper identity and runtime code are outside target.
- Wrapper upgradeability and authority behind calls from the wrapper address are not represented by the supplied interface.

`Raffle._settleWinningTicket` and `Raffle._update` recorded no open questions. Total carried unresolved items: **21**.
