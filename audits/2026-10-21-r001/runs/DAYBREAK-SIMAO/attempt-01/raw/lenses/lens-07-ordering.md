# Lens 7 — Ordering, MEV & Price Manipulation

The money map exposes four ordering-sensitive surfaces: atomic raffle creation, entry ordering before the exclusive sale end, the one-shot draw/refund transitions, and permissionless terminal settlement. There are no protocol-owned swaps, asset-price reads, user signatures, exchange-rate conversions, or mutable rate updates in scope.

[Model: factory deployment and locked implementation]
The deployer supplies the canonical payment-token, randomness-service, and treasury addresses and receives no withdrawable claim. The factory fixes those destinations forever, creates one unusable template raffle, and starts the factory raffle count at zero. No user asset enters during deployment.

[Model: createRaffle → initialize → onERC721Received]
The sponsor gives exactly one named NFT and receives an active raffle whose eventual sponsor proceeds and prize-return destination are fixed. The factory count rises by one, both registry directions are recorded, the new raffle moves from waiting-for-prize to active, and custody of the named NFT moves from the sponsor to that raffle. Any failure rolls the entire creation back.

[Why: RaffleFactory.sol:127]
Why is the clone registered before the untrusted prize handoff finishes? The implicit requirement is that every already-live raffle can recognize the new clone as protocol plumbing during reentrant token behavior; transaction atomicity guarantees that a failed handoff also erases the earlier count and registry writes.

[Defeat: Raffle.initialize]
1. Address `0xA` calls `initialize` on the implementation before any sponsor transaction; the implementation was locked during construction, so the call reverts.
2. `0xA` watches a sponsor's creation and tries to initialize the fresh clone first; no external transaction can interleave between clone creation and the factory's immediate call, and a non-factory caller is rejected in any reentrant call.
3. A malicious prize contract calls back into `createRaffle` while its token is being handed over; the factory's reentry lock rejects the nested creation, and failure of the outer custody checks reverts the count, registry, configuration, and NFT movement together.

[Defeat: RaffleFactory.createRaffle]
1. `0xA` copies the victim's creation parameters and front-runs them; the factory attempts to take the NFT from `0xA`, not from the victim, so `0xA` cannot capture the victim's approved prize.
2. `0xA` creates an unrelated raffle first and shifts the victim's expected numeric ID by one; the victim still becomes sponsor of a separately returned and emitted clone, and no asset or claim is keyed to a caller-supplied expected ID.
3. `0xA` predicts a future clone address and sends assets there before deployment; this neither grants initialization authority nor changes the factory's sponsor, recipient, prize, reserve, or end-time values, and forced unrelated assets are not used for raffle accounting.

[LastOut: creation and prize escrow]
There is no withdrawable user pool at this intermediate stage. In the worst order, a failed creation leaves no registered raffle and the sponsor retains the NFT because all effects revert; a successful creation leaves the sole configured NFT in the active raffle until exactly one terminal prize path. There is no partially created last sponsor left short.

[Model: buyEntries]
The buyer gives exactly one USDC per requested entry and the named recipient receives one bearer ticket covering that many consecutive entry numbers. The sold-entry count, ticket count, historical coverage, and unallocated sale pot all rise by the same purchase. If the recipient refuses the ticket, both payment and every total revert.

[Why: Raffle.sol:230]
Why are the entry totals and paid pot recorded before the recipient is asked to accept the ticket? The recipient must never observe or move a ticket whose paid entries are absent from the raffle's totals; atomic rollback removes those writes if acceptance fails.

[Defeat: Raffle.buyEntries]
1. A searcher buys one entry immediately before a victim's 10-entry purchase, shifting the victim's range and ticket ID; the searcher spends 1 USDC for exactly one uniformly eligible entry and gains no better probability from its position in the range.
2. A searcher buys the exact missing entries immediately before a victim so the reserve is met; the searcher pays the fixed price for every added chance, cannot exit in a back-run, and receives only the ordinary raffle payoff of the entries deliberately purchased. This is strategic participation in the user-chosen raffle, not extraction of protocol-owned value.
3. A searcher attempts to place a draw request before a victim's late purchase in the same block; one block timestamp applies to both calls, while buying requires a time strictly before the sale end and requesting requires a time at or after it, so both calls cannot succeed in either order.

[Model: ticket transfer]
The current holder gives the complete bearer claim to a new holder and receives whatever consideration they arranged outside the protocol. Sold entries, recorded coverage, and all raffle liabilities stay unchanged; only the identity entitled to a later refund or winning redemption changes.

[Defeat: Raffle._update]
1. A holder sends a ticket to the same raffle, factory, payment token, randomness wrapper, prize token, implementation, or any registered sibling raffle; the dynamic destination check rejects each transfer.
2. A holder transfers the winning ticket after someone else has permissionlessly settled it; settlement records only the winning ticket ID, so the new current holder—not the settler—still owns redemption.
3. An approved operator front-runs the owner's redemption by transferring the ticket to itself; that requires pre-existing authority to transfer the bearer NFT and is ordinary ERC-721 authorization, not a protocol-created ordering privilege.

[LastOut: ticket ownership before a terminal branch]
Transferring every ticket in any order neither adds nor removes USDC and leaves each represented entry attached to exactly one live bearer claim. The last transferred ticket carries its full later claim; the terminal last-user-out checks below cover payment.

[Model: requestDraw]
The requester gives native currency solely to pay for randomness. The wrapper receives its actual fee, the same requester receives all excess immediately, and the raffle records one drawing state, one request time, and one request ID. A failed fee payment or failed excess return reverses the request and all state changes.

[Why: Raffle.sol:257]
Why are the drawing state and request time recorded before the external wrapper call while the request ID is recorded afterward? The raffle must reject resolution during the call before the wrapper-assigned ID exists, then accept only a later callback for the persisted ID; `_requestInFlight` encodes that assumption explicitly.

[Defeat: Raffle.requestDraw]
1. A searcher front-runs a victim's request with sufficient native currency; the searcher pays the wrapper fee plus gas, earns zero, and advances the exact draw the raffle needs. The victim's later revert costs gas but does not lose supplied value or any raffle claim.
2. A searcher requests with a deliberately excessive value hoping to leave native currency behind; the complete difference from the actual wrapper fee is returned to that same caller or the whole request reverts.
3. A requester chooses a contract that rejects the excess refund; only its own request reverts, status returns to active, and another caller can request within the still-open window.

[Model: fulfillRandomWords]
The authenticated wrapper supplies one random number and receives no raffle asset. The raffle fixes one winning entry, one resolution time, and either the NFT-result or cash-result state. Entry totals and the paid pot do not change, so the selected entry is drawn over the sale population already frozen at the end time.

[Defeat: Raffle.fulfillRandomWords]
1. `0xA` directly submits a chosen word; the inherited wrapper authentication prevents `0xA` from reaching the internal handler.
2. The wrapper supplies a stale request ID, a duplicate callback, a wrong word count, or a same-call callback before request persistence; each is ignored without changing the winner or result.
3. A block builder orders a callback and `enableRefunds` in the same block near expiry; before the exclusive callback deadline refunds revert, while at or after the deadline the callback is rejected. Transaction order never creates a timestamp at which both state transitions are valid.

[Model: enableRefunds]
No asset moves when refunds are enabled. The entire unallocated sale pot is relabeled as debt to current ticket holders, the unallocated amount becomes zero, and the raffle enters the refund state. For an empty raffle both amounts are zero.

[Why: Raffle.sol:296]
Why is the whole pot copied into one refund liability rather than recalculated from current ticket owners? Every entry has one immutable historical range and one unburned bearer ticket on this branch, so the entry total fixes the exact debt without any order-dependent ownership snapshot.

[Defeat: Raffle.enableRefunds]
1. An arbitrary address front-runs a sold raffle's draw request before the request deadline; the time check rejects the refund transition.
2. An arbitrary address front-runs a valid wrapper callback before its callback deadline; the time check again rejects refunds, allowing the callback to resolve normally.
3. The sponsor front-runs the first pending purchase while the raffle is still empty and closes it; the sponsor alone is expressly granted this pre-end cancellation right, recovers only its own prize later, and cannot take buyer funds because no purchase has succeeded. The pending buyer can lose gas, but this is the documented sponsor-controlled empty-raffle cancellation rather than an unguarded third-party race.

[LastOut: draw request and callback]
The only native-currency claimant is the current requester: the wrapper fee and full excess are handled in the same transaction, or everything reverts. After a successful request there is no tracked requester balance for a later user to drain. A forced native balance has no protocol claimant and does not make the last requester short.

[Model: settleWinningTicket → _settleWinningTicket]
The caller gives only gas and receives nothing. The frozen sale pot becomes exact debts to the winner, sponsor recipient, and treasury; the unallocated amount becomes zero, the winning ticket ID is fixed, and settlement is consumed once. For an NFT result the winner's cash debt is zero; for a cash result it is eighty percent of the pot.

[Why: Raffle.sol:539]
Why can settlement safely use the stored unallocated pot without rereading the token balance or resnapshotting entries? Sales were already closed before the draw could start, the result cannot be reached from the refund branch, and unsolicited token transfers must not enlarge or dilute any raffle cohort's claim.

[Defeat: Raffle.settleWinningTicket]
1. A searcher supplies a losing ticket ID before the owner acts; its stored range does not contain the chosen entry, so the transaction changes nothing.
2. A searcher front-runs with the correct ticket ID; it pays gas, earns zero, cannot change ticket ownership, and merely allocates the same fixed liabilities the owner would have allocated.
3. Two searchers submit the correct ID; only the first allocation succeeds, and the one-time flag makes the second revert without duplicating any debt.

[Model: redeemWinningTicket]
The current winning-ticket holder gives up and destroys that bearer claim, then receives either the escrowed NFT or the full recorded cash-winner amount. The winner identity is recorded at redemption, the one-time winner flag is consumed, and the cash debt becomes zero or the prize-delivered flag is consumed. Failed delivery reverses the ticket destruction and every state change.

[Defeat: Raffle.redeemWinningTicket]
1. A non-owner front-runs the owner with the known winning ID; it cannot pass the current-owner check and receives neither asset.
2. A settler front-runs redemption with `settleWinningTicket`; the owner's transaction detects the same recorded ID and continues to redemption, so no ownership snapshot is stolen.
3. The owner transfers the ticket in a transaction ordered before its own redemption; the old owner's redemption reverts and the new holder owns the bearer claim, which is the explicit consequence of transferring the ticket rather than a stale-snapshot defect.

[LastOut: NFT-result settlement and claims]
Let the sale pot be `G`. Settlement creates treasury debt `floor(5% × G)` and sponsor debt `G - floor(5% × G)`. If treasury claims first, the sponsor receives the full remainder last; if sponsor claims first, treasury receives its full floor amount last. The winning holder independently receives the sole NFT. After all three claims, quote debt and intended quote balance are zero and the prize has exactly one delivered owner; the last claimant is short by 0.

[LastOut: cash-result settlement and claims]
Let the sale pot be `G`. Settlement creates winner debt `floor(80% × G)`, treasury debt `floor(5% × G)`, and sponsor debt `G - winner - treasury`. Winner, sponsor, and treasury can claim in all six orders because each exit first zeros only its own complete debt. Whoever claims last receives the exact remaining balance; the shortfall is 0, and the sponsor recipient separately receives the NFT.

[Model: refundTickets]
The current holder destroys one to one hundred selected bearer tickets and receives exactly one USDC for every entry those tickets cover. The aggregate refund debt falls by that exact amount; historical entry coverage and lifetime sales remain unchanged because they describe past purchases rather than unpaid claims.

[Defeat: Raffle.refundTickets]
1. A searcher front-runs another holder with the victim's ticket IDs; ownership checks reject the searcher before any payment.
2. A holder repeats an ID or includes a foreign ID after valid IDs in the same batch; the failed ownership lookup reverses every earlier destruction and debt reduction in that transaction.
3. Holders choose the most adversarial refund order, including alternating one-entry tickets with maximum-size range tickets; every payment is range length times the immutable price, so order cannot change the remaining amount.

[LastOut: refund lifecycle]
For tickets covering `N` total entries, the initial refund debt is exactly `N × 1 USDC`. Burn every ticket in any order and in batches of at most 100. Each unique range subtracts and pays its own exact value once. The last live ticket receives its complete range value, after which both refund debt and the intended USDC balance are zero; the shortfall is 0.

[Model: releaseSponsorProceeds]
The caller gives only gas and receives nothing. The immutable sponsor recipient receives the entire recorded sponsor amount, and that debt becomes zero before delivery. A failed delivery reverses the zeroing.

[Model: releaseProtocolFees]
The caller gives only gas and receives nothing. The immutable treasury receives the entire recorded protocol amount, and that debt becomes zero before delivery. A failed delivery reverses the zeroing.

[Defeat: releaseSponsorProceeds / releaseProtocolFees]
1. A searcher front-runs either intended recipient's release; the money still goes to the immutable recipient, so the searcher spends gas and earns zero.
2. Sponsor and treasury releases are reordered around winner redemption; each uses a disjoint recorded debt, so no ordering consumes another cohort's balance.
3. The same caller repeats a successful release; the relevant amount is already zero and the repeat reverts rather than pulling unsolicited token balance.

[Model: releaseSponsorPrize]
The caller gives only gas and receives nothing. After a cash result or refund transition, the immutable sponsor recipient receives the sole escrowed NFT and the prize-delivered flag is consumed. Failed delivery reverses the flag.

[Defeat: Raffle.releaseSponsorPrize]
1. A searcher calls before resolution while the raffle is active or drawing; the state check rejects it.
2. A searcher front-runs the sponsor recipient after a cash result or refund transition; the prize still goes only to the immutable sponsor recipient, so the searcher earns zero.
3. A caller races a duplicate release after the first succeeds; the one-time prize flag rejects the second, while an NFT-result winner path cannot race this function because that result state is ineligible.

[LastOut: empty raffle]
No ticket or quote claimant exists. Whether the sponsor closes it before the end or anyone closes it at or after the end, the immutable sponsor recipient receives the sole NFT and the quote shortfall is 0.

## Ordering-boundary check

| Boundary | Earlier side | Boundary/later side | Ordering result |
| --- | --- | --- | --- |
| `endTime` | Entries may be bought only while `timestamp < endTime` | A draw may be requested only while `timestamp >= endTime` | No same-block order permits both at one timestamp |
| `endTime + 2 days` | A sold raffle may request only while `timestamp < deadline` | Refunds may start while `timestamp >= deadline` | No request/refund overlap |
| `drawRequestedAt + 2 days` | A callback resolves only while `timestamp < deadline` | Refunds may start while `timestamp >= deadline` | No callback/refund overlap |
| terminal settlement | First correct winning-ticket proof allocates debts | Every later settlement reverts | Front-running changes only who pays gas |
| terminal releases | First call pays the fixed claimant | Every later call sees zero/consumed state | Front-running cannot redirect value |

## Explicit MEV candidate economics

| Candidate sequence | Attacker cost | Attacker profit / victim damage | Disposition |
| --- | --- | --- | --- |
| Attacker buys entries → victim buys entries → attacker waits for the draw | Fixed USDC price for every attacker entry, capital lock, and raffle risk | Only the normal expected payoff of purchased entries; no deterministic back-run or protocol-value capture | Ordinary user-chosen raffle participation; not a finding |
| Attacker creates a raffle → victim's creation lands with the next ID | Gas and custody of the attacker's own prize | 0; victim still gets its own configured clone | Numeric-ID ordering has no economic authority |
| Attacker requests the draw → victim's request reverts | Wrapper fee plus gas | 0; victim may lose gas, while the raffle obtains the intended randomness request | No profitable or protocol-harming one-shot capture |
| Sponsor closes an empty raffle → pending first purchase reverts | Sponsor's gas | Sponsor recovers its own prize; prospective buyer may lose gas | Explicit sponsor-only empty-raffle right, not an unguarded attacker action |
| Attacker settles/releases → intended claimant's transaction lands later | Attacker gas | 0; all value still goes to the current ticket owner or immutable recipient | Permissionless liveness action |
| Refund call and callback are reordered near expiry | Gas for a reverting ineligible call | 0; strict complementary comparisons select exactly one valid branch for the block timestamp | No deadline race |

## Saturation

- Initialization pattern: the only `initialize` entry is factory-only, the implementation is pre-locked, and clone creation plus initialization is atomic. The factory's count and all three registry writes revert with any failed prize handoff.
- First-call and one-shot pattern: `requestDraw`, `enableRefunds`, `_settleWinningTicket`, winner redemption, quote releases, and prize release were each attacked from both sides of their state transition. A caller can at most perform the intended action first; no caller address becomes a value recipient merely by winning the race.
- Discrete-jump pattern: reserve crossing changes the advertised raffle outcome, but it occurs only through fixed-price entry purchases before sales close. There is no instantaneous deposit/withdraw round trip, no share price, and no protocol-owned inventory repriced by the jump.
- Price-manipulation pattern: the only live quote is the trusted wrapper's caller-funded native fee. The actual fee is checked, the entire excess returns to the same payer, and sale USDC never funds it. No AMM reserve, `slot0`, vault exchange rate, spot oracle, or live token balance determines a user claim.
- Approval-window pattern: entry cost is an immutable asset amount rather than a moving share amount. Prize creation takes the named token from the actual caller. Ticket operators have only standard bearer-NFT transfer authority and receive no special redemption shortcut.
- Replay pattern: there are no signature-authorized actions, nonces, signed deadlines, permits, or relayer-supplied fee fields in scope.
- Cohort pattern: sales are closed before randomness is requested, randomness is fixed before settlement, and settlement never snapshots ownership. Late ticket transfers move the complete existing bearer claim rather than joining a historical pro-rata distribution.
- Exit-pattern saturation: cash winner, sponsor, treasury, ticket refund, NFT winner, sponsor prize return, and native excess refund were all checked. Each exit consumes exactly its own debt or one-time asset flag before delivery, with atomic rollback on failure.
- Cross-clone pattern: every ticket transfer and quote destination is screened against registered clones, while factory registration occurs atomically before external prize behavior. No ordering window permits one clone to become another clone's claimant.

## Result

No FINDING or LEAD is warranted for the Ordering/MEV lens. Every candidate ordering either has complementary time/state guards, leaves the caller unable to redirect value, or is ordinary fixed-price raffle participation expressly chosen by the entrant. The last user out is paid in full in every terminal quote-token branch, with a computed shortfall of zero.
