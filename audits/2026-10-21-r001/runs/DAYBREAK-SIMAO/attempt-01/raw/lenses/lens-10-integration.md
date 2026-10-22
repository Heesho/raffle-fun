[Model: raffle creation and prize escrow]
A sponsor gives one advertised NFT and fixes the sponsor's payout address, reserve, and sale end. In return, the factory creates and records one raffle, while the raffle becomes responsible for the NFT. The factory count and both registry directions grow by one; no sale-money total changes yet.

[Why: RaffleFactory.sol:171] Why does a token saying “I implement ERC-721,” then saying “the raffle owns token 7,” prove that a valuable token actually moved? It does not: both attestations, and the receiver call between them, are controlled by the same untrusted prize contract.

[Defeat: createRaffle] 1. A sponsor supplies prize contract `P` and token 7; `P` reports ERC-721 support, fabricates the expected receiver call, and reports the raffle as owner without moving a real asset. 2. An upgradeable prize behaves honestly during creation, then its controller pauses transfers or burns token 7 after buyers have paid 100 USDC. 3. A sponsor chooses `C2`, the Ethereum CREATE address of a future raffle clone, as `sponsorRecipient`; `C2` is code-less and unregistered now, then later becomes protocol plumbing. The first two moves break prize backing for a generic hostile token, but the bundle names no deployed real-world ERC-721 with those semantics, so they remain a lead under this lens's named-instance rule. The third move is saturated below.

[Model: entry purchase]
A buyer gives exactly one Circle USDC per entry. The named recipient gets one transferable ticket covering a consecutive set of entry numbers. The sold-entry total, ticket total, historical coverage, and unallocated sale pot rise by exactly the amount purchased.

[Why: Raffle.sol:213] Why is the requested payment also the received payment? Because the deployment promises canonical six-decimal USDC, whose normal transfers are fee-free and non-rebasing; the constructor's decimals check alone would not establish this for an arbitrary six-decimal token.

[Defeat: buyEntries] 1. A counterfeit six-decimal fee token would credit 100 entries after delivering less than 100 USDC-equivalent units. 2. Circle can deny-list the buyer or raffle address, making the canonical Ethereum USDC transfer revert. 3. A recipient contract can reenter while receiving ticket 1, but all accounting is already written and the guarded value-moving entry points reject reentry. Move 1 is excluded by the canonical-token trust boundary; move 2 is a real named integration behavior and is carried into the payout findings; move 3 does not break an invariant.

[Model: native-funded draw]
After sales close, a caller gives enough ether for one Chainlink VRF v2.5 native-funded request. The caller receives no financial claim; it buys progress for the raffle. The raffle records that a draw is pending, its request time, and the returned request identifier, while returning any unused ether to that same caller.

[Defeat: requestDraw] 1. A caller supplies exactly the wrapper's in-transaction quote, leaving no refund edge. 2. A contract caller deliberately overpays and rejects the excess ether; the whole request rolls back, so only that caller loses gas and another caller can retry. 3. A hypothetical wrapper calls back before returning the request identifier; the in-flight flag ignores it, while the named canonical Chainlink VRF v2.5 wrapper is asynchronous and later calls the clone as consumer. The bundle establishes no selector, payment, or callback mismatch for the named wrapper.

[LastOut: draw request] There is no pooled last requester: one caller pays one wrapper fee and receives all excess in the same transaction. A failed excess refund reverts the wrapper request atomically, so it cannot leave an ether shortfall for a later caller.

[Model: terminal USDC allocation and release]
Resolution converts the entire sale pot into winner, sponsor, and treasury claims without moving money. A cash winner later destroys the winning ticket for cash; the sponsor and treasury independently collect their fixed claims. Each successful payment removes exactly that claim, and the three claims add back to the original pot.

[Why: Raffle.sol:564] Why can every recorded claim eventually leave the raffle? The code assumes Circle's Ethereum USDC will continue permitting transfers from the raffle and to each immutable destination. Balance sufficiency does not make a deny-listed transfer reachable.

[Defeat: _transferQuote] 1. Circle deny-lists raffle `R` after `R` has collected 100 USDC; every cash redemption, refund, sponsor release, and fee release from `R` reverts. 2. Circle deny-lists fixed sponsor recipient `S` after settlement; only the payment to `S` reverts, and there is no authorized replacement destination. 3. Circle deny-lists the fixed treasury `T`; the fee remains recorded but cannot be sent elsewhere. These are separate sender- and recipient-side failure shapes and are reported separately.

[LastOut: cash-win payout] With 100 entries and a missed reserve, the claims are 80 USDC to the winner, 15 to the sponsor recipient, and 5 to the treasury. In the worst ordinary order—winner, treasury, sponsor—the balances go 100→20→15→0, so the last claimant is paid in full. If `R` is deny-listed, all three transfers fail and 100 USDC remains unreachable. If only `S` is deny-listed, winner and treasury receive 85 USDC, while the last 15 USDC remains backed but unreachable by `S`; the protocol is not numerically short, but the claim cannot settle.

[Model: ticket refunds]
On timeout, the unallocated pot becomes a refund obligation. Each current ticket owner destroys selected tickets and receives exactly their represented entry value; the refund obligation falls by the same amount.

[Defeat: refundTickets] 1. Owners of 50-, 30-, and 20-entry tickets refund in that order. 2. The owner of a deny-listed address transfers its ticket to a clean address before refunding, so recipient-side USDC denial does not permanently trap an owner-derived claim. 3. Circle deny-lists the raffle itself; transferring tickets cannot change the blocked USDC sender and every refund attempt reverts.

[LastOut: refund lifecycle] Starting from 100 USDC, ordinary refunds of 50, 30, then 20 entries leave liabilities and balances of 50, 20, then 0; the last owner is paid in full. With the raffle address deny-listed, neither the first nor last owner is paid: the contract still holds all 100 USDC, so the failure is reachability rather than an accounting deficit.

[Model: NFT delivery and return]
For an NFT result, the winning ticket owner destroys the ticket and receives the escrowed prize. For a cash result or refund, the sponsor recipient receives it instead. A successful delivery consumes the one prize claim; a failed delivery restores every state change.

[Defeat: prize exits] 1. Prize contract `P` lies that winner `W` owns token 7 after doing no transfer. 2. `P` is upgraded or paused after deposit and rejects both winner delivery and sponsor return. 3. The sponsor recipient was a future clone address when accepted and is a registered clone at return time; the unguarded non-safe transfer deposits token 7 into a contract with no recovery function. Moves 1 and 2 lack a source-supported named real-world token instance and remain one untrusted-prize lead; move 3 remains a separate counterfactual-address lead because the demonstrated loss is presently chosen by the same sponsor.

[LastOut: NFT-win and empty-refund lifecycles] With an honest ERC-721 and 100 USDC of NFT-win sales, the treasury can take 5 USDC first, the sponsor takes the remaining 95, and the winner receives the sole NFT; all backing reaches the last claimant. An empty raffle has no USDC claimant and returns the sole NFT. A hostile or later-disabled prize can leave the winner or sponsor recipient unpaid despite the claim flag rolling back, but no named deployed prize contract is established by the bundle.

[Saturation: external asset boundaries] Every quote-token exit—cash redemption, refunds, sponsor proceeds, and protocol fees—funnels through `_transferQuote`, so sender-side USDC denial affects all four and is one root cause. Recipient-side denial is permanent only for the immutable sponsor and treasury destinations; ticket-derived winner and refund claims can be moved to a clean ticket owner, so they are not duplicate findings. Both prize exits and the factory deposit rely on statements made by the same prize contract, so fabricated escrow and later transfer revocation are consolidated. Every protocol-destination check was also reviewed: existing clones are rejected, while code-less future Ethereum CREATE addresses are not recognizable at the time of the check. The Chainlink price, native payment, authenticated callback, wrong-request, late-callback, and single-word branches produced no source-supported mismatch with the named VRF v2.5 wrapper.

FINDING | contract: Raffle | function: _transferQuote | bug_class: usdc-denylist-escrow-lock | group_key: Raffle | _transferQuote | usdc-denylist-escrow-lock
root_cause: `Raffle.sol:564-568` makes every quote claim leave from the raffle clone itself, but Circle-issued USDC on Ethereum rejects transfers from a deny-listed sender and the immutable clone has no migration or alternate settlement path.
internal_pre: A raffle clone holds nonzero USDC backing `unsettledPot`, `remainingRefundLiability`, `winnerProceeds`, `sponsorProceeds`, or `protocolFees`.
external_pre: Circle places that raffle clone on canonical Ethereum USDC's denylist and does not remove it.
path:
  1. Buyers purchase 100 entries, transferring 100 USDC into raffle `R` and creating 100 USDC of backed claims.
  2. Circle deny-lists `R` while it still holds the 100 USDC.
  3. The raffle enters refunds, or settles into winner/sponsor/treasury claims.
  4. Every relevant path reaches `_transferQuote`; USDC rejects the transfer because `R` is the sender, SafeERC20 propagates the revert, and retrying or transferring a ticket cannot change the blocked sender.
impact: Every otherwise clean ticket owner, winner, sponsor recipient, and treasury claimant in that raffle can lose access to its share of the full 100 USDC balance; the funds remain present but no claimant can make them leave the clone.
mitigation: No contract path can move USDC after its sender is deny-listed; either use a quote asset without sender freezing or explicitly make Circle unfreezing/remediation an operational recovery requirement of the USDC trust model.

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: usdc-denylisted-fixed-recipient | group_key: Raffle | releaseSponsorProceeds | usdc-denylisted-fixed-recipient
root_cause: `Raffle.sol:375-390` can release sponsor proceeds and protocol fees only to the immutable `sponsorRecipient` and `protocolTreasury`; Circle-issued USDC on Ethereum rejects a transfer to a deny-listed recipient, and neither claim has a claimant-authorized redirection path.
internal_pre: Settlement has allocated nonzero `sponsorProceeds` or `protocolFees`.
external_pre: Circle deny-lists the corresponding fixed recipient after raffle initialization and does not remove it.
path:
  1. A raffle sells 100 entries and resolves `NftWon`, allocating 95 USDC to sponsor recipient `S` and 5 USDC to treasury `T`.
  2. Circle adds `S` to canonical Ethereum USDC's denylist.
  3. Any caller invokes `releaseSponsorProceeds`; the attempted transfer to `S` reverts and the preceding zeroing rolls back.
  4. Every retry targets the same `S`, so the backed 95 USDC claim is unreachable. The same sequence at `releaseProtocolFees` strands 5 USDC if `T` is deny-listed.
impact: The sponsor recipient can lose access to 95 USDC in the concrete NFT-win example, or the treasury to 5 USDC in the repeated instance, even while all other cohorts settle in full; the affected fixed recipient is left holding the loss.
mitigation: Add a claim-redirection function authorized by the current sponsor beneficiary (or stored sponsor) and by the current treasury respectively, so each can select a non-protocol replacement destination before the transfer.

LEAD | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-self-attestation | group_key: RaffleFactory | createRaffle | untrusted-prize-self-attestation
smell: `RaffleFactory.sol:128-134` and `RaffleFactory.sol:171-178` accept prize custody using ERC-721 support and `ownerOf` answers supplied by the same untrusted prize contract, while `Raffle.sol:416-429` lets that contract fabricate the expected receiver callback; the token can also revoke transferability after a genuine deposit.
unverified: The supplied source names no deployed real-world ERC-721 whose canonical semantics permit forged ownership, arbitrary escrowed-token burn, or post-deposit transfer revocation, and browsing for one is disallowed; the named-instance requirement therefore prevents promotion to a finding.
description: A sponsor-controlled prize can make creation appear funded, collect buyers' USDC after an NFT-win result, and then deliver no genuine NFT, or can brick both winner delivery and sponsor return after initially honest escrow.

LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: counterfactual-clone-destination | group_key: Raffle | _isProtocolDestination | counterfactual-clone-destination
smell: `Raffle.sol:593-604` rejects only the current clone and already-registered code-bearing clones, but future OpenZeppelin clone addresses are predictable under Ethereum CREATE and pass while code-less; a ticket or configured sponsor destination can therefore become a raffle sink later.
unverified: The concrete paths shown require the ticket owner or sponsor to choose the counterfactual address for its own asset, and no path was established for an attacker to force an unrelated victim's existing claim there, so the present impact is self-harm rather than a reportable exploit.
description: After the predicted address becomes a registered clone, a prior ticket cannot be exercised by that clone, sponsor USDC releases are rejected at runtime, and `releaseSponsorPrize` can move the NFT into the clone without a recovery path, violating the no-cross-clone design invariant.
