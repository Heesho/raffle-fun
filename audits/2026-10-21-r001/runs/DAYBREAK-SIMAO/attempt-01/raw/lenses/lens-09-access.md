# Lens 9 — Access, Authorization & Trust Boundaries

Result: one concrete trust-boundary finding. The owner gates, permissionless settlement/release design, fixed payout targets, request/callback state gates, and ordinary ticket approvals do not expose a second victim-funded path in the supplied scope.

## Models

[Model: factory-deployment] The deployer chooses the one accepted payment token, randomness service, and treasury, and the factory fixes them forever while creating the shared raffle implementation. No participant claim exists yet; the security consequence is that every later raffle inherits these three trust choices.

[Model: createRaffle] A sponsor gives one advertised prize and receives a new raffle whose eventual sponsor proceeds and returned prize go to the chosen sponsor recipient. The successful-raffle count rises by one, all three registry directions are recorded, and the new raffle moves from waiting for a prize to selling tickets.

[Model: initialize] The canonical factory gives a fresh raffle its sponsor, recipients, prize identity, reserve, identifier, and end time. The raffle gives nobody value at this step; it records those fixed terms and moves into the waiting-for-prize state.

[Model: prize-deposit-callback] The prize contract is expected to confirm that the sponsor's exact prize arrived through the factory. The raffle then changes from waiting for a prize to active. This status change is the authorization point that permits genuine payment-token sales.

[Model: buyEntries] The payer gives `entryCount * 1,000,000` payment-token units, and the named recipient receives one bearer ticket covering that many consecutive entries. The sold-entry total rises by `entryCount`, the lifetime ticket total rises by one, and the unallocated sale pot rises by the exact payment.

[Model: ticket-transfer] A current ticket owner gives the entire bearer claim to a recipient. The recipient becomes entitled to any later refund or winning payout; lifetime entry and ticket totals and every payment-token liability remain unchanged.

[Model: requestDraw] Any caller gives native currency to pay the fixed randomness service. The service receives its actual price, the same caller receives all excess, and the raffle records one pending request and its time; the sale pot is untouched.

[Model: randomness-callback] The configured randomness service gives one random word. No asset moves; the raffle records one winning entry and changes to either the NFT result or cash result, while all sale value remains in the unallocated pot.

[Model: enableRefunds] No caller receives value. Once the applicable liveness deadline is reached, the entire unallocated sale pot is reclassified, without loss, as the amount owed to unrefunded ticket owners and the raffle changes to refunding.

[Model: settleWinningTicket] Any caller may prove the unique ticket range containing the winning entry. No asset moves and ownership is irrelevant; the whole unallocated pot is reclassified once into winner, sponsor, and treasury obligations.

[Model: redeemWinningTicket] The current winning-ticket owner gives up and destroys that ticket and receives either the prize or the complete cash-winner obligation. The winner obligation becomes zero in the cash branch; the winner and prize-consumption records become final in the prize branch.

[Model: refundTickets] The caller gives up one to 100 tickets that the caller currently owns and receives their exact represented purchase value. The outstanding refund obligation falls by exactly the amount paid; lifetime sales and historical entry ranges do not change.

[Model: releaseSponsorProceeds] Any caller may trigger the transfer, but gives and receives nothing merely for calling. The fixed sponsor recipient receives the entire current sponsor obligation, which is set to zero before delivery.

[Model: releaseProtocolFees] Any caller may trigger the transfer, but gives and receives nothing merely for calling. The fixed treasury receives the entire current fee obligation, which is set to zero before delivery.

[Model: releaseSponsorPrize] After a cash result or refund transition, any caller may trigger return of the prize to the fixed sponsor recipient. The one-prize claim is consumed before the external prize interaction; a failed delivery rolls the whole transaction back.

## Complete caller and entry-point inventory

### Deployment and factory

| Entry point | Caller and enforced check | Authorization-relevant impact |
| --- | --- | --- |
| `RaffleFactory.constructor` | Deployment caller; payment token and wrapper must contain code, payment token must report six decimals, and treasury must be nonzero and not a then-known protocol sink. | Permanently selects trusted dependencies and treasury and deploys the locked implementation. There is no later owner or configuration role. |
| `Raffle.constructor` | Called by the factory's construction flow for the canonical implementation; payment token and wrapper must be nonzero. | Binds the implementation to its deploying factory and locks the implementation itself as already initialized. |
| `RaffleFactory.createRaffle` | Anyone may call as sponsor. End time, maximum duration, positive reserve, prize code/interface response, and then-known protocol destinations are checked; `nonReentrant` applies. The prize pull always names `msg.sender` as `from`. | Creates, initializes, registers, and attempts to fund exactly one clone atomically. The untrusted-prize verification is the finding below. |
| `quoteToken`, `vrfWrapper`, `protocolTreasury`, `raffleImplementation`, `callbackGasLimit`, `requestConfirmations`, `raffleCount`, `raffleById`, `idByRaffle`, `isRaffle` | Anyone; read-only. | No authority or value movement. |
| Factory receive/fallback | Neither exists. | Empty native transfers and unknown selectors revert. |

### Raffle-specific mutators and callbacks

| Entry point | Caller and enforced check | Authorization-relevant impact |
| --- | --- | --- |
| `receive` | Anyone can reach it, but it always reverts. | Direct native transfers cannot enter the normal accounting path. Forced native value remains outside it. |
| `initialize` | Exactly the immutable canonical factory and only while `initialized == false`; all required addresses must be nonzero and then-known protocol sinks are rejected. | Writes every raffle-specific authority/destination and enters `AwaitingPrize`. |
| `buyEntries` | Any payer while active and before the end; positive count, nonzero recipient, bounded total, and reentrancy checks apply. Payment is pulled only from the caller. | Creates a ticket for the caller-selected recipient and increases sales liabilities. The safe-receive hook can run on a contract recipient only after the ticket and accounting are recorded. |
| `requestDraw` | Anyone in `[endTime,endTime+2 days)` when at least one entry exists, provided the caller funds the current fee; reentrancy guarded. | Records the sole request, pays the fixed wrapper, and refunds excess only to the same caller. |
| `enableRefunds` | Sponsor alone may close an empty raffle before `endTime`; anyone may close that empty raffle from `endTime`, a sold active raffle from the request deadline, or a drawing raffle from the callback deadline. | Reclassifies the pot into refunds; the caller receives nothing. |
| `settleWinningTicket` | Anyone after a successful result; the supplied historical range must contain `winningEntry`, and settlement must not already be complete. | Records the unique winning ticket and allocates liabilities; caller identity and ticket ownership intentionally confer no value. |
| `redeemWinningTicket` | Strict current owner of the recorded or proved winning ticket; approved operators are not accepted. Correct result/status and unused winner claim are required; reentrancy guarded. | Burns the owner's ticket and sends the winner asset to that same owner. |
| `refundTickets` | Strict current owner of every supplied ticket, with a batch of one to 100, only while refunding; approved operators are not accepted; reentrancy guarded. | Burns only the caller's tickets and pays only the caller. Any bad, duplicate, nonexistent, or foreign ID reverts the batch. |
| `releaseSponsorProceeds` | Anyone when the sponsor obligation is nonzero; reentrancy guarded. | Sends the whole obligation only to immutable `sponsorRecipient`, never to the caller. |
| `releaseProtocolFees` | Anyone when the fee obligation is nonzero; reentrancy guarded. | Sends the whole obligation only to immutable `protocolTreasury`, never to the caller. |
| `releaseSponsorPrize` | Anyone only in `CashWon` or `Refunding`, while the prize claim is unused; reentrancy guarded. | Sends the configured prize only to immutable `sponsorRecipient`. |
| `onERC721Received` | Purports to require `AwaitingPrize`, caller equal to configured prize token, exact token ID, `from == sponsor`, and `operator == factory`. | Activates sales. The caller supplies the latter three callback fields and is itself adversarial, so these checks do not establish escrow. |
| inherited `rawFulfillRandomWords` → internal `fulfillRandomWords` | Intended caller is the immutable wrapper, authenticated by the imported Chainlink base. In-scope handling additionally requires no request in flight, `Drawing`, the stored request ID, exactly one word, and time strictly before the deadline. | Selects the winning entry and result once. The inherited external base body is not present in the bundle; the local handler is not directly callable. |

### Inherited ticket surface

| Entry point | Caller and enforced check | Authorization-relevant impact |
| --- | --- | --- |
| `approve` | Ticket owner or an operator approved for all, under the inherited ERC-721 rules. | Grants transfer authority for one ticket; it does not grant raffle redemption or refund authority, which require the owner itself. |
| `setApprovalForAll` | Any holder for that holder's own tickets. | Grants or removes standard transfer authority only. |
| `transferFrom`, `safeTransferFrom(address,address,uint256)`, `safeTransferFrom(address,address,uint256,bytes)` | Owner, per-ticket approved address, or operator approved for all; inherited ownership/from checks apply. `_update` additionally rejects the zero address for ordinary transfers through the base behavior and rejects then-known protocol destinations. | Moves the complete bearer claim. Safe variants may call the recipient after ownership changes; the recipient can move its newly received ticket but cannot reenter guarded payout/accounting functions. |
| `balanceOf`, `ownerOf`, `tokenURI`, `getApproved`, `isApprovedForAll`, `supportsInterface` | Anyone; read-only. | No authority or value movement. |

### Raffle read surface

The following are all callable by anyone and are read-only: `getVrfRequestPrice`, `estimateVrfRequestPrice`, `vrfWrapper`, `ticketRange`, `drawRequestDeadline`, `callbackDeadline`, `accountedQuoteBalance`, `grossSales`, `name`, `symbol`, plus the generated getters `ENTRY_PRICE`, `callbackGasLimit`, `requestConfirmations`, `factory`, `quoteToken`, `sponsor`, `sponsorRecipient`, `protocolTreasury`, `prizeToken`, `prizeTokenId`, `raffleId`, `reserveEntries`, `endTime`, `totalEntries`, `ticketCount`, `unsettledPot`, `remainingRefundLiability`, `winnerRecipient`, `winnerProceeds`, `sponsorProceeds`, `protocolFees`, `vrfRequestId`, `drawRequestedAt`, `resolvedAt`, `winningEntry`, `winningTicketId`, `status`, `settlementComplete`, `winnerRedeemed`, `prizeClaimed`, and `initialized`. There is no raffle fallback; unknown selectors revert.

## Guard attacks

[Why: RaffleFactory.sol:129] Why is the prize contract's own `ownerOf` response independent evidence that the prize moved? It is not: the prospective prize contract supplies the transfer behavior, callback, and ownership answer, so all three checks collapse to one adversarial assertion.

[Why: Raffle.sol:423] Why do `operator == factory` and `from == sponsor` authenticate the transfer? Only an honest ERC-721 constructs those callback arguments from a real transfer; a malicious configured token can call the receiver itself and put those two addresses in calldata.

[Why: Raffle.sol:602] Why is a code-less address excluded from the factory registry query? The implicit belief is that it cannot yet be protocol plumbing. A predicted future clone disproves that belief, although the only available paths require the ticket owner/payer or sponsor to choose that address and therefore produce self-harm rather than theft from a distinct victim.

[Why: Raffle.sol:315] Why may settlement occur before the caller is checked as ticket owner? Settlement is intentionally permissionless, transfers nothing, and a later failed owner check reverts the earlier allocation in the same transaction; caller identity cannot redirect any allocation.

[Defeat: initialize]

1. An attacker calls `initialize` on a canonical clone after creation; `initialized` is already true.
2. An attacker deploys an independent clone of the implementation and calls `initialize`; the implementation-baked factory address rejects the attacker.
3. An attacker predicts the factory's next clone and tries to initialize first; no contract exists there before the factory transaction, and creation plus initialization are atomic.

The initialization authority holds.

[Defeat: createRaffle]

1. Alice owns honest NFT `#7` and has approved the factory; an attacker supplies that token and ID, but the factory fixes `from` to the attacker, so the honest token rejects the pull.
2. An attacker supplies an EOA or a contract returning false for the ERC-721 interface; the code/interface checks reject it.
3. An attacker supplies `Fake721`, which returns true for the interface, fabricates the receiver call, and returns caller-dependent ownership answers; every current check passes without an independently backed prize.

Move 3 defeats the guard and is the finding.

[Defeat: rawFulfillRandomWords]

1. An EOA directly invokes the inherited callback entry; the imported base is intended to reject every caller other than the immutable wrapper.
2. The wrapper calls synchronously while `requestDraw` is still obtaining the request ID; `_requestInFlight` makes the callback a no-op.
3. The wrapper supplies request ID `99` instead of the recorded ID, two words instead of one, or calls at the exact deadline; each callback is ignored without changing the result.

The visible request-binding/state/deadline checks hold; no in-scope bypass was found.

[Defeat: redeemWinningTicket/refundTickets]

1. A stranger supplies Alice's winning ticket ID; the strict `msg.sender == ownerOf(ticketId)` check reverts.
2. Alice approves a marketplace for ticket transfers and the marketplace tries to redeem or refund; approval is deliberately insufficient because those functions still require Alice herself.
3. A malicious prize contract reenters during winner delivery after the ticket is burned; `nonReentrant` blocks guarded state-changing paths, and any delivery failure reverts the burn. The token can still lie about delivery, but that is the same untrusted-prize root cause reported below.

No independent missing-owner-check path remains.

[Defeat: permissionless-releases]

1. An outsider calls a release before allocation; the zero-obligation or result-state check reverts.
2. An outsider front-runs a valid release; value still goes only to the immutable recipient, not the outsider.
3. A callback attempts a second release; the obligation or prize flag was consumed before interaction and `nonReentrant` applies.

Permissionless execution does not create caller-controlled destinations.

[Defeat: protocol-destination-screen]

1. A ticket owner sends to the factory, payment token, wrapper, prize token, implementation, or an already registered same-factory raffle; `_update` rejects it.
2. A ticket owner sends to the predicted address of the next factory clone before it exists and then causes that clone to be deployed; the transfer passes and the claim becomes unreachable, but the owner deliberately sacrificed its own bearer claim.
3. A sponsor chooses a code-less future clone as `sponsorRecipient`, or an owner selects a raffle from another factory; current checks can miss those destinations, but the chooser controls only its own recipient/claim and cannot move another owner's ticket or redirect another cohort's payout.

These counterfactual cases violate the broad destination aspiration but are excluded as self-harm absent a victim-funded authorization path.

## Lifecycle and Last-Out checks

[LastOut: create-escrow-activate] With a conforming prize contract, the sole prize is held before sales activate. With the adversarial configured contract expressly in the threat model, the last eventual winner can be short the entire one-NFT prize because activation is based only on that contract's fabricated callback and ownership response. This is the reported finding.

[LastOut: buy-hold-transfer] No one exits during this phase. Each payment creates exactly one range claim, and transferring it changes only the bearer. After all transfers, the final owners collectively cover every entry exactly once; no caller can transfer a foreign ticket without inherited approval.

[LastOut: request-callback] The request caller pays exactly the wrapper's reported actual price and receives every excess unit in the same transaction; if that refund fails, the request and payment revert. The sale pot is unchanged, so the last sale claimant is not diluted by draw initiation.

[LastOut: NFT-result] For gross sale value `G`, the treasury receives `floor(5% * G)` and the sponsor recipient receives the exact remainder, in either order. With a conforming prize, the winning owner also receives the one prize and the last quote claimant is paid in full. With a malicious prize, quote claimants can be paid while the winning owner remains short one genuine prize.

[LastOut: cash-result] The winner receives `floor(80% * G)`, the treasury receives `floor(5% * G)`, and the sponsor receives `G` minus those two amounts. Releases are independent, so the last quote claimant is paid in full and the payment-token balance reaches zero absent unsolicited tokens.

[LastOut: request-or-callback-timeout-refunds] Tickets may be refunded in any owner order. Each range is destroyed before its exact value is paid and cannot be used twice; after the final live ticket, both the refund obligation and intended payment-token balance reach zero. The last owner is not short.

[LastOut: empty-cancellation] There is no payment-token claimant. With a conforming prize, the fixed sponsor recipient receives the sole prize and no balance remains; the adversarial-prize caveat is the same reported root cause, not a separate instance.

## Saturation

The untrusted-prize pattern was checked at every same-shape site. `RaffleFactory._validateCreateParams` trusts the token's self-reported interface at `RaffleFactory.sol:171-177`; `createRaffle` trusts its transfer behavior and `ownerOf` at `RaffleFactory.sol:128-133`; `Raffle.onERC721Received` trusts callback fields supplied by that same token at `Raffle.sol:421-428`; winner delivery again trusts `transferFrom` plus `ownerOf` at `Raffle.sol:334-336`; sponsor return repeats it at `Raffle.sol:404-405`. These are one root cause and one required trust-model fix. No payment-token path accepts a caller-selected `from`; no payout path accepts a caller-selected target; and the native refund returns only to the payer, so the pattern does not repeat for the trusted payment token or wrapper.

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-self-attestation | group_key: RaffleFactory | createRaffle | untrusted-prize-self-attestation
root_cause: `RaffleFactory.sol:171-177` and `RaffleFactory.sol:128-133` accept an arbitrary prize contract's self-reported interface and `ownerOf` result as proof of escrow, while `Raffle.sol:421-428` lets that same untrusted contract fabricate the `operator` and `from` callback fields that activate sales; no independent trust gate constrains prize-token behavior.
internal_pre: None
external_pre: At least one victim purchases an entry and the canonical wrapper returns randomness before the deadline
path:
  1. A malicious sponsor deploys `Fake721`. It reports ERC-721 support; its `safeTransferFrom` performs no ownership change but directly calls the new raffle's receiver with token ID `7`, `from` equal to the sponsor, and `operator` equal to the factory. Its `ownerOf(7)` returns the raffle only when queried by the factory.
  2. The sponsor calls `createRaffle` with `Fake721`, token ID `7`, `reserveEntries = 1`, a distinct attacker-controlled sponsor recipient, and a valid end time. The fabricated callback sets the clone to `Active`, and the fabricated ownership answer passes the factory's post-check.
  3. Victims buy 100 entries for `100,000,000` raw USDC units. A timely draw necessarily produces `NftWon` because the positive reserve is met; the attacker or any caller proves the winning range and allocates `95,000,000` units to the sponsor recipient and `5,000,000` to the treasury.
  4. Anyone calls `releaseSponsorProceeds`, paying the attacker-controlled recipient `95,000,000` genuine USDC units before the winner receives anything. On redemption, `Fake721` may revert forever, or return normally and make `ownerOf(7)` report the requested winner only when the raffle queries it; the latter consumes and burns the winner's ticket despite no stable, externally consistent prize ownership.
impact: Ticket purchasers pay genuine USDC into a raffle with no independently backed prize, the malicious sponsor extracts 95% of gross sales, and the winning-ticket owner is left holding the loss of the entire advertised NFT claim.
mitigation: Before clone creation, require `params.prizeToken` to belong to an immutable set of vetted, non-upgradeable ERC-721 implementations/collections. An interface response, receiver callback, and ownership response all supplied by the same adversarial contract cannot prove its semantics or custody.
