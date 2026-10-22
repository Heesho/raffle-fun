# Lens 12 — Flow Completeness & Symmetry

Result: one concrete finding and one lead. The quote-token accounting is symmetric across purchase, settlement, refund, redemption, and independent release. The exploitable gap is the assumption that an arbitrary prize contract which accepts escrow will also honor the inverse transfer; no such trust restriction is enforced. The remaining destination-screening asymmetry is retained as a LEAD because I could not turn it into non-self-harm loss.

## Mandatory models and guard-defeat work

[Model: RaffleFactory.createRaffle] A sponsor gives one advertised prize and gets an activated raffle. On success the lifetime raffle count rises by one, both registry directions are filled, and the new raffle becomes active; on failure the entire sequence disappears.

[Model: Raffle.initialize] The factory gives a fresh raffle its sponsor, payout destinations, prize identity, reserve, identifier, and sale end. The raffle gives no asset yet; its lifecycle changes from unused to waiting for the exact prize.

[Model: Raffle.onERC721Received] The sponsor's configured prize enters custody and the raffle becomes sellable. No sale balance changes; the only tracked transition is waiting-for-prize to active.

[Why: RaffleFactory.sol:172] Why should a prize contract's own claim that it supports ERC-721 prove that it will later let the raffle transfer the prize out? It does not; the check assumes the very contract declared adversarial by the threat model tells the truth and behaves symmetrically over time.

[Why: RaffleFactory.sol:129] Why is asking the prize contract who owns the token independent evidence of escrow? It is not: the party being verified also supplies the answer.

[Defeat: createRaffle] (1) A token at `0xA11CE` reports ERC-721 support, invokes the expected receipt callback, and reports the raffle as owner without honoring real custody. (2) A token genuinely transfers token 7 in, then permanently rejects only transfers whose sender is the raffle. (3) A token accepts escrow while unpaused, then its sponsor-controlled switch blocks outbound transfers after buyers pay. The existing interface, callback, and ownership checks admit all three; cases (2) and (3) yield the FINDING below.

[Model: Raffle.buyEntries] A payer gives `entryCount * 1,000,000` raw quote units and the named recipient gets one bearer ticket covering that many consecutive entries. Lifetime entries, lifetime tickets, and the unallocated sale pot rise by exactly the purchased amount.

[Model: Raffle._update] Ticket ownership moves while its entry range and economic claim remain unchanged. Mint creates the bearer claim, transfer changes its bearer, and the two terminal burn paths consume it.

[Defeat: buyEntries] (1) Buying zero entries is rejected. (2) Buying past the last representable entry is rejected before payment. (3) Naming the current raffle, its factory, its implementation, a current same-factory raffle, or another fixed plumbing address is rejected by the common ownership-update hook. A future or foreign raffle address is the residual LEAD below.

[Model: Raffle.requestDraw] A caller gives native currency for one randomness request and receives no raffle claim. The raffle records that drawing has begun, the request time and identifier, pays the wrapper's actual price, and returns every supplied unit above that price to the same caller.

[Defeat: requestDraw] (1) At `endTime - 1`, a request is rejected. (2) At `endTime + 2 days`, a request is rejected and the refund route is available. (3) A synchronous callback during the wrapper call is ignored because the request is still in flight and its identifier is not yet persisted. None creates a second request or consumes the sale pot.

[Model: Raffle.fulfillRandomWords] The authenticated request gives one random word and the raffle records one winning entry, one resolution time, and exactly one result: prize won when the reserve was met, otherwise cash won. No asset or quote liability moves at callback time.

[Defeat: fulfillRandomWords] (1) A callback for request 9 when request 10 is stored is ignored. (2) A callback with zero or two words is ignored. (3) A callback exactly at the exclusive deadline is ignored while refunds become available. Duplicate, malformed-length, in-flight, and late callbacks cannot rewrite the result.

[Model: Raffle.enableRefunds] An expired active or drawing raffle converts the entire unallocated sale pot into an equal aggregate refund obligation and changes to refunding. An empty raffle converts zero into zero; only its sponsor can close it before the sale end.

[Defeat: enableRefunds] (1) A non-sponsor tries to close an empty raffle one second before sale end and is rejected. (2) A sold raffle tries to close one second before the request deadline and is rejected. (3) A drawing raffle tries to close one second before the callback deadline and is rejected. At each exact deadline, the complementary refund branch is open.

[Model: Raffle.refundTickets] A current owner gives up one to 100 bearer tickets and receives exactly the entry price for every represented entry. The aggregate refund obligation falls by the same amount; historical sale and range facts remain unchanged.

[Why: Raffle.sol:364] Why may each ticket be destroyed before the aggregate obligation is reduced and money is sent? Because any later ownership, arithmetic, destination, or transfer failure reverses every earlier change in the transaction; there is no partial batch burn.

[Defeat: refundTickets] (1) Repeating ticket 3 in one batch fails on the second ownership lookup and reverses the first burn. (2) Mixing Alice's ticket with Bob's reverses the whole batch. (3) Making the final quote payment fail reverses the burns and obligation decrement. No sibling refund path bypasses the decrement.

[Model: Raffle._settleWinningTicket] Anyone may identify the unique historical range containing the selected entry. The entire unallocated pot becomes fixed winner, sponsor, and treasury obligations; the old pot becomes zero and settlement becomes permanently consumed.

[Why: Raffle.sol:538] Why is a historical range enough without a separate current-existence check? Before settlement, the state machine exposes no burn path: refund burns require refunding and winner burn first settles atomically. Thus the unique winning range is still represented by a live ticket at this point.

[Why: Raffle.sol:543] Why may the prize-won arm allocate 95% of buyer money to the sponsor before the prize has successfully left escrow? The code assumes successful inbound escrow implies successful future outbound delivery. That belief is false for an adversarial prize contract.

[Defeat: settleWinningTicket] (1) Ticket 0 has range `[0,0]` and cannot contain a positive winning entry. (2) Any non-winning minted range is rejected. (3) A second correct settlement is rejected after the consumed flag is set. The remaining attack does not forge the winning range; it lets the legitimate settlement make sponsor proceeds releasable while prize delivery is impossible.

[Model: Raffle.redeemWinningTicket] The current winning-ticket owner gives up that ticket and receives either the escrowed prize or the fixed cash obligation. The recipient and consumed flags are recorded, and any failed transfer reverses the burn and all flag changes.

[Defeat: redeemWinningTicket] (1) A former owner calling after transferring the ticket is rejected by the current-owner check. (2) A different ticket after permissionless settlement is rejected by the stored winning-ticket identifier. (3) A hostile prize rejects the outbound transfer after sponsor proceeds have already become independently claimable; the burn reverses, but there is no refund, cash substitute, or result transition. Move (3) breaks completion.

[Model: Raffle.releaseSponsorProceeds] The complete sponsor obligation is consumed and the immutable sponsor recipient receives the same quote amount. A failed payment restores the obligation.

[Model: Raffle.releaseProtocolFees] The complete treasury obligation is consumed and the immutable treasury receives the same quote amount. A failed payment restores the obligation.

[Model: Raffle._transferQuote] One already-accounted quote claim leaves for its intended recipient. The function changes no aggregate itself; its caller first consumes exactly that claim, and transaction rollback restores it if delivery fails.

[Defeat: quote releases] (1) Sponsor release before settlement sees zero and fails. (2) A second treasury release sees zero and fails. (3) A blocked current protocol destination is rejected and the caller's preceding zeroing reverses. Winner, sponsor, treasury, and refund siblings all preserve their own bucket.

[Model: Raffle.releaseSponsorPrize] In a cash or refund result, the sponsor's immutable recipient receives the sole escrowed prize and the one-time prize claim is consumed. A reported delivery failure reverses the flag.

[Defeat: releaseSponsorPrize] (1) Calling in active or prize-won state is rejected. (2) Calling a second time is rejected by the consumed flag. (3) A hostile token can reject or counterfeit the outbound movement just as on winner redemption. In cash/refund states that normally harms the sponsor-selected recipient; in the prize-won sibling it harms an honest winner and enables the concrete extraction below.

[Why: Raffle.sol:602] Why does the sink check recognize only already-deployed raffles registered by this factory? It assumes an allowed address cannot later become a raffle and that no raffle from another factory is equivalent protocol plumbing. Predictable future clone addresses and foreign clones violate that belief, although I found no third-party-loss path.

[Defeat: _isProtocolDestination] (1) A currently registered same-factory raffle is caught. (2) The code-less address predicted for the factory's next clone passes, can receive a ticket, and later becomes a raffle. (3) An already-deployed clone from another factory has code but returns false in the canonical factory's registry and passes. Cases (2) and (3) strand a claim, but the constructed loss remains with the actor who selected and funded the destination.

## Forward / inverse symmetry table

| Forward operation | Required inverse or terminal counterpart | Result |
| --- | --- | --- |
| Increment factory count and install both registry directions in `createRaffle` | Failed creation must remove all three writes; successful identities are lifetime facts | Present through transaction-wide rollback; no deletion path is required. |
| Move the configured prize from sponsor to raffle and activate it | Move that same prize to the winner in `NftWon`, or sponsor recipient in `CashWon`/`Refunding` | Syntactically present, but behaviorally incomplete: inbound success is not evidence that the adversarial token will honor outbound movement. Missing operation: a factory-level trusted-prize/allowlist check. |
| Pull purchase quote and add the same amount to the unallocated pot | Allocate the whole pot once to refunds or terminal claims | Present; every terminal conversion first captures the old pot and then zeroes it. |
| Mint one ticket and create one immutable range | Burn the bearer claim on winner redemption or refund | Present. Lifetime ticket count and historical ranges intentionally are not decremented. |
| Convert pot to refund obligation | Burn each refunded range, decrement by its exact entry value, and pay its owner | Present; batch failure is atomic. |
| Convert pot to cash-result obligations | Winner + sponsor + treasury must equal the old pot | Present: `floor(80%) + floor(5%) + remainder == gross`. |
| Convert pot to prize-result obligations | Sponsor + treasury must equal the old pot, and the prize must reach the winning bearer | Quote inverse is complete; prize inverse is not guaranteed under the stated untrusted-token model. |
| Credit winner, sponsor, or treasury bucket | Zero precisely that bucket and deliver precisely that amount | Present; each sibling zeroes before the external payment and relies on rollback. |
| Receive native request value | Pay actual wrapper price and return the full excess to the requester | Present; a failed excess return reverses the request. |
| Enter drawing | Accept one timely matching callback, or enter refunds at the callback deadline | Present with complementary exclusive/inclusive boundary checks. |

## Sibling symmetry table

| Function family | Reference behavior | Sibling comparison |
| --- | --- | --- |
| `NftWon` / `CashWon` settlement | Zero old pot, set settlement and winning ticket, allocate fee and sponsor remainder | Both do so; only cash adds the 80% winner bucket, as required. |
| NFT / cash winner redemption | Verify current bearer, consume ticket and winner claim, deliver result atomically | Cash relies on trusted canonical quote token and is complete. NFT relies on an adversarial prize's future behavior and has no failure fallback. |
| Winner / sponsor prize exit | Set the same one-time prize flag, transfer token, query post-owner | Code shape is symmetric and both share the same untrusted-attestation weakness; they are saturated into one root cause, not split findings. |
| Winner / sponsor / treasury / refund quote exits | Consume only the matching liability before payment | Symmetric; failures reverse consumption. |
| Empty / sold / drawing refund activation | Select the relevant authority and deadline, then move the whole pot to refund liability | Symmetric at `endTime`, draw-request deadline, and callback deadline. |
| Mint / ordinary transfer ticket sink screening | Route all ownership changes through `_update` | Symmetric for current known sinks; future and foreign raffles fall outside the predicate. |
| Factory / clone creation validation | Reject zero/fixed/current protocol destinations | Clone initialization catches its own address and current registry members; neither stage reserves future clone addresses or identifies foreign-factory clones. LEAD only. |

## Branch symmetry table

| Branch | State/value written on each arm | Assessment |
| --- | --- | --- |
| Prize interface query succeeds / reverts / returns false | Continue only on reported true | Mechanically complete, but validates attacker-controlled testimony rather than behavior. |
| Request has excess / exact fee | Return excess / return nothing | Both leave exactly the actual fee spent. |
| Refund activation from empty Active / sold Active / Drawing | Sponsor-or-end / request deadline / callback deadline | All converge on the same pot-to-refund write. |
| Callback accepted / ignored | Record entry, time, result / emit only | Ignored paths retain a live retry window or reach permissionless refunds. |
| Settlement `NftWon` / `CashWon` | Sponsor+fee / winner+sponsor+fee | Both conserve quote value. |
| Redemption `NftWon` / `CashWon` | Prize flag and token / winner bucket and quote | Both are atomic locally; only the NFT arm depends on an untrusted contract and lacks an alternate terminal route. |
| Sponsor prize `CashWon` / `Refunding` | Identical one-time return | Symmetric. |
| Destination has code / has no code | Query same-factory registry / skip registry | Current registry membership is caught; future-address identity is absent. |

## Precondition symmetry table

| Consumer | Required fresh/validated state | Result |
| --- | --- | --- |
| `buyEntries` | Active, before sale end, nonzero recipient/count, representable cumulative entries | All checked before accounting; quote movement rollback protects later mint failure. |
| `requestDraw` | Active, at/after sale end, positive sales, before request deadline, enough native value | All checked; actual wrapper charge is checked again. |
| `fulfillRandomWords` | Request persisted, no request in flight, Drawing, matching ID, exactly one word, before callback deadline | All checked on the callback path. |
| `enableRefunds` | Correct source state plus the matching authority/deadline | Each source branch has its own complete predicate. |
| `_settleWinningTicket` | Terminal result, unsettled, supplied range contains winning entry | All checked; current ownership intentionally is deferred to redemption. |
| `redeemWinningTicket` | Terminal result, correct settled ticket or valid first settlement, current owner, unconsumed winner | All local preconditions checked. Missing precondition: prize contract belongs to a trusted behavior set, or a failure route exists. |
| `refundTickets` | Refunding, bounded nonempty batch, current ownership of every ticket | Checked per ticket before final aggregate debit/payment. |
| Sponsor / treasury releases | Positive matching bucket | Checked; the bucket itself proves settlement occurred. |
| Sponsor prize return | Cash or refund result and unconsumed prize | Checked. |

There is no interest index, cached price, cumulative rate, epoch snapshot, or other time-dependent derived accounting that requires a refresh call. Deadlines are derived directly from immutable sale time or the single recorded request time.

## Last-user-out checks

[LastOut: create -> escrow -> activate] With an honest prize, either the factory count, registry, custody, and active state all persist or all roll back, so no partial last participant exists. With an adversarial prize, the apparent custody check can be false evidence; that defect manifests in the prize-result lifecycle below.

[LastOut: buy -> hold/transfer ticket] This is an intermediate lifecycle, not an exit. For purchases of two and three entries, the tickets retain `[1,2]` and `[3,5]` regardless of transfer order, and the pot is exactly 5,000,000 raw units. The last ticket retains its complete range claim.

[LastOut: sale end -> request -> callback] If 1,000,000 native units are supplied and the wrapper charges 700,000, the requester gets 300,000 back immediately; the paid 700,000 is the requester's consumed service cost, not a raffle liability. A missing timely callback leaves all 5,000,000 sale units available for the timeout-refund lifecycle.

[LastOut: NFT result -> settle -> redeem/release] For a 5,000,000-unit pot, sponsor and treasury quote claims are 4,750,000 and 250,000; either release order pays the last quote claimant in full and leaves zero quote liability. With a behaviorally trusted prize, the winning bearer also receives the sole NFT. With the allowed hostile prize used in the FINDING, the quote claimants can take all 5,000,000 while the last winning bearer is short exactly the promised NFT and has no quote refund.

[LastOut: cash result -> settle -> redeem/release] For 5,000,000 units, winner, sponsor, and treasury receive 4,000,000, 750,000, and 250,000. In the worst order, the first two claims consume only their buckets and the last claimant receives its entire bucket; balance and accounted liability both reach zero.

[LastOut: request/callback timeout -> refunds] If the three-entry ticket refunds first, it receives 3,000,000 and leaves 2,000,000. The two-entry ticket refunds last, receives all 2,000,000, and leaves zero balance obligation. Reversing the order gives the same result; the last owner is never charged rounding dust or another owner's amount.

[LastOut: empty raffle cancellation] Quote liability starts and ends at zero. The sponsor recipient is the only prize claimant and receives the prize under a behaviorally honest token. A hostile token can obstruct its own sponsor-selected recipient, but that adds no victim beyond the common untrusted-prize root; it is not a separate finding.

## Saturation record

The untrusted-prize shape was followed through every occurrence in the bundle:

1. `RaffleFactory._validateCreateParams` trusts the prize's self-reported interface support.
2. `RaffleFactory.createRaffle` relies on the prize to invoke the receipt callback and then trusts that same prize's `ownerOf` response.
3. `Raffle.redeemWinningTicket` relies on the prize to honor an outbound transfer and then trusts that same prize's `ownerOf` response.
4. `Raffle.releaseSponsorPrize` repeats the identical outbound pattern.
5. `Raffle._settleWinningTicket`, `releaseSponsorProceeds`, and `releaseProtocolFees` make quote proceeds independently collectible before successful winner delivery.

The counterfeit-escrow, selective-outbound-revert, post-sale pause, and counterfeit-post-owner variants have the same missing trust restriction and therefore form one finding. The cash winner and all quote-release siblings use the explicitly trusted canonical quote token, so the pattern does not create a second finding there. The wrapper is also explicitly trusted and its request-return values are persisted and reconciled.

The destination predicate was also saturated across initial mint, later transfer, winner payout, sponsor payout, treasury payout, clone initialization, same-factory current clones, future same-factory clone addresses, and foreign-factory clones. Only future/foreign identities escape. Because every concrete stranded-ticket or stranded-recipient sequence I found requires the affected actor to choose or fund that destination and produces no attacker gain or other-cohort shortfall, it remains a LEAD.

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-contract | group_key: RaffleFactory | createRaffle | untrusted-prize-contract
root_cause: A factory-level trusted-prize or allowlist check is not performed in `RaffleFactory._validateCreateParams` at RaffleFactory.sol:154; lines 172-176 accept the prize contract's self-reported interface, lines 128-132 accept its self-reported escrow ownership, and Raffle.sol:334-336 later assume the same adversarial contract will honor and truthfully attest the inverse transfer.
internal_pre: A sponsor-created raffle uses a sponsor-controlled prize contract, sells at least one ticket, and resolves `NftWon`; setting `reserveEntries = 1` guarantees that result after any sale.
external_pre: None
path:
  1. A malicious sponsor deploys prize token `T`, mints token 7, and programs `T` to behave normally when token 7 moves into a raffle but to revert forever whenever that raffle tries to move token 7 out.
  2. The sponsor creates a raffle with token 7 and `reserveEntries = 1`. `T` reports ERC-721 support, performs the expected inbound callback, and reports the raffle as owner, so creation succeeds.
  3. Alice is the sole buyer and buys 100 entries for 100,000,000 raw USDC units. A normal callback necessarily records `NftWon`, and Alice's single ticket contains the winning entry.
  4. The sponsor settles Alice's ticket. The raffle makes 95,000,000 units independently claimable by `sponsorRecipient` and 5,000,000 by the treasury, and the sponsor release succeeds.
  5. Alice calls `redeemWinningTicket`. `T` rejects the outbound prize transfer, so her redemption reverses. The raffle has no transition to refunds, no cash substitute, and no way to replace the token, while the sponsor's 95,000,000 units are already gone.
impact: The current winning-ticket owner is left holding the loss: Alice paid 100 USDC and can never receive the advertised prize or a refund, while the malicious sponsor extracts 95 USDC (and the treasury can extract the remaining 5 USDC) from an unbacked raffle. Honest entry purchasers therefore fund a result whose sole winner claim is permanently unfulfillable.
mitigation: Add an immutable factory-level allowlist check in `_validateCreateParams` and accept only vetted, behaviorally trusted, non-upgradeable ERC-721 prize implementations; arbitrary adversarial token contracts cannot be made safe by asking the same contract to attest interface support, custody, or delivery.

LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: incomplete-protocol-destination-screening | group_key: Raffle | _isProtocolDestination | incomplete-protocol-destination-screening
smell: Raffle.sol:599-603 recognizes fixed plumbing and already-registered raffles from only the canonical factory. A code-less address predicted for the next clone can receive a ticket before becoming registered, and an existing clone from another factory also passes, after which the raffle-owned bearer claim has no callable redemption/refund path.
unverified: I could not establish attacker profit or loss to a distinct victim cohort. In every concrete sequence, the buyer or configured recipient deliberately selects and funds the eventual dead destination and sacrifices only its own claim; the newly created or foreign raffle's own accounting remains unchanged.
description: The guard does not fully enforce the documented no-assets-between-raffle-clones invariant, but the observable consequence established from this bundle is self-stranding rather than an exploitable third-party loss.
