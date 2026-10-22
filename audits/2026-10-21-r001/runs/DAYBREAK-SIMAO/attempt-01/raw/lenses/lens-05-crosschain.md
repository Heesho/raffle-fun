Single-chain conclusion: the scoped protocol has no bridge, peer, remote-chain copy, or cross-chain message. The relevant latency boundaries are (1) factory initialization to prize escrow/activation and (2) draw request to VRF callback. I therefore use “request side” and “callback side” below as the two sides of the asynchronous trace.

[Model: raffle creation and prize escrow]
The sponsor gives one advertised NFT. The new raffle gives buyers a future claim on that prize and records one new raffle identity. Activation is supposed to mean that the exact prize is actually held for the eventual winner or sponsor recipient.

[Why: RaffleFactory.sol:172]
Why can the factory treat the sponsor-selected prize contract's statement that it supports ERC-721 as evidence that its later custody statements and outgoing transfer will be honest? The implicit belief is that the prize contract is trusted to attest to its own behavior, even though the stated threat model makes arbitrary prize contracts untrusted.

[Defeat: createRaffle]
1. A sponsor deploys `EvilNFT`, makes `supportsInterface(0x80ac58cd)` return true, invokes the expected receiver callback during deposit, and makes `ownerOf(7)` return the clone; every creation guard passes although `EvilNFT` can later reject the outgoing transfer.
2. A sponsor deposits token 7 through an upgradeable NFT while transfers work, sells 100 entries, and then changes the NFT implementation so transfers from the raffle revert; the creation-time ownership check says nothing about delivery-time behavior.
3. A prize contract accepts transfers into the raffle but blacklists that raffle as a sender after activation; the post-deposit owner check passes, while both winner delivery and sponsor return can be made permanently unreachable.

[Model: draw request]
After the sale, one caller gives enough native currency to pay the randomness service. The raffle records that a draw is pending, the request time, and the returned request identity; the service keeps its exact fee and the caller gets every excess unit back.

[Why: Raffle.sol:254]
Why is a callback refused while the request call itself is still executing? The request identity does not exist in raffle storage until the external service returns it, so accepting an in-call callback would compare authenticated data against an uncommitted request.

[Defeat: requestDraw]
1. If the wrapper attempts a synchronous callback while request identity 0 is still stored, `_requestInFlight` makes it an ignored callback rather than a premature resolution; a revert later in the request also rolls that event back.
2. A requester contract sends the quoted fee plus 1 wei and rejects the 1-wei return; the whole request, including the wrapper-side request, reverts, and a different caller remains able to request the draw.
3. Two callers submit at `endTime`; the first successful call changes the state to drawing before yielding control, and the second call cannot create or overwrite a second request.

[Model: VRF callback]
The callback contributes no user value. It converts the one pending draw into one immutable winning entry and either an NFT result or a cash result. The sale pot is not moved during this step.

[Why: Raffle.sol:512]
Why is a callback rejected at exactly the callback deadline while refunds become available at that same timestamp? The implicit rule is an exclusive callback window and inclusive recovery window, ensuring no timestamp at which both terminal transitions are valid.

[Defeat: fulfillRandomWords]
1. The authenticated wrapper calls with request 42 while request 43 is stored; the raffle only emits an ignored-callback event and leaves request 43 pending.
2. The correct callback for request 43 lands at exactly `drawRequestedAt + 2 days`; it is ignored, and refunds—not resolution—are the only valid terminal transition.
3. Request 43 resolves one block before the deadline and the wrapper calls it again; the first call changes the state out of drawing, so the duplicate cannot overwrite the entry or result.

[Model: timeout recovery]
No new value enters. Once the applicable deadline is reached, the entire unallocated sale pot becomes an equal full-refund obligation, and the raffle changes permanently into the refund state.

[Defeat: enableRefunds]
1. A caller tries one second before the pending callback deadline and cannot move the pot into refunds.
2. At the exact deadline, a late callback is ignored while a refund transition succeeds, so ordering within that block cannot create both a winner and refund claims.
3. After the refund transition, an arbitrarily delayed authenticated callback sees a non-drawing state and cannot recreate a winner or overwrite the refund liability.

[Model: winner redemption and prize return]
The winning owner gives up the bearer ticket and should receive either the NFT or the allocated cash. In a cash or refund result, the sponsor recipient should receive the escrowed NFT. The winner-use flag, prize-use flag, and any cash obligation are consumed only if delivery succeeds.

[Defeat: redeemWinningTicket]
1. A caller supplies ticket 8 when the selected entry is in ticket 7; range validation rejects it before any obligation moves.
2. Ticket 7 is transferred to another owner immediately before redemption; the previous owner cannot burn it or redirect delivery because ownership is reread in the redemption transaction.
3. The current owner submits the real ticket 7, but the sponsor-controlled prize contract reverts when asked to transfer token 7 out of escrow; local redemption changes roll back, yet independently released sponsor and treasury proceeds do not, leaving no refund route. This defeats liveness and is the finding below.

Asynchronous ordering trace (single-chain analogue):

1. Escrow side, transaction E0: the attacker creates a raffle with `EvilNFT` token 7 and reserve 100. `EvilNFT` self-reports ERC-721 support, performs the expected callback, and reports the clone as owner, so the clone becomes active.
2. Sale side, transactions E1..E100: 100 entrants buy one entry for 1 USDC each. The clone holds 100 USDC and records 100 entries.
3. Request side, transaction R: a caller pays the wrapper; before the external request the clone records drawing status and the request time, then it records the returned request ID before callbacks can be accepted.
4. Callback side, transaction C: the authenticated, matching callback arrives strictly before the deadline and sets an entry plus `NftWon`. No competing refund liability exists.
5. Settlement side, transaction S: the correct ticket is proven. The 100-USDC pot becomes 95 USDC of sponsor proceeds and 5 USDC of protocol fees.
6. Release side, transactions P1 and P2: permissionless calls pay 95 USDC to the attacker's sponsor recipient and 5 USDC to the treasury. The clone now holds 0 USDC.
7. Delivery side, transaction D: the winning-ticket owner calls redemption. `EvilNFT` reverts its outgoing transfer, so D rolls back, but P1 and P2 are earlier transactions and remain final.
8. Final state: the raffle is permanently `NftWon`, settlement is complete, sponsor and protocol quote obligations are zero, the winner-use and prize-use flags remain false, and the winning ticket remains outstanding. The unrecoverable value is the promised NFT delivery; the winner also has no path to recover the USDC paid into the now-empty raffle.

[LastOut: draw-request native funding]
If the actual service price is F and the requester supplies F+X, the service receives F and the requester receives X. If either the request or return fails, the whole transaction reverts. The only requester is therefore paid in full and the raffle records no native-currency liability.

[LastOut: callback-timeout refunds]
With 100 one-entry tickets and 100 USDC, let 99 owners refund in adversarial order. Each burn removes exactly 1 USDC, leaving one live ticket, 1 USDC of liability, and 1 USDC in the clone. The final owner burns the last ticket and receives the full 1 USDC; liability and intended quote balance both reach zero.

[LastOut: cash-result lifecycle]
For a 100-USDC pot, the winner, protocol, and sponsor obligations are 80, 5, and 15 USDC. Because each obligation is fixed before any release and zeroed atomically with its transfer, every release order leaves the last quote claimant fully paid. A hostile prize contract can still block the sponsor's separate NFT return, but it cannot make the quote buckets insolvent.

[LastOut: NFT-result lifecycle]
For a 100-USDC pot and an honest prize, the sponsor receives 95 USDC, the treasury receives 5 USDC, and the winning owner receives the one NFT. With the permitted untrusted prize, the worst order releases both quote claims first; the last claimant—the winning-ticket owner—is short exactly one promised NFT, and the clone has no remaining quote value or refund transition with which to make that owner whole.

Saturation:

- Prize entry has three checks—self-reported interface support, a callback emitted by the prize contract, and an ownership answer returned by that same contract. None is independent of the adversarial prize.
- The winner exit at `Raffle.sol:334-336` and sponsor exit at `Raffle.sol:404-405` both use the same external prize behavior. Reverting delivery correctly rolls back each individual call, but neither branch supplies an alternate terminal path.
- The cash-winner, sponsor-quote, protocol-quote, and ticket-refund exits use the trusted canonical quote token, zero their own obligation atomically, and do not depend on a prize call. Thus they cannot repair or collateralize a failed NFT delivery, and they can empty the quote balance before the failure becomes observable.
- The synchronous receiver callbacks on ticket mint and prize deposit do not expose a second unguarded accounting entry: protected value-moving routes reject reentry, and any failure in the factory deposit transaction rolls back clone creation and registry writes.
- Wrong-ID, wrong-length, in-flight, late, and duplicate VRF callbacks converge on an ignored callback; the complementary timeout transition preserves the full sale pot for refunds. No separate VRF ordering finding remains after saturation.

FINDING | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-escrow | group_key: RaffleFactory | createRaffle | untrusted-prize-escrow
root_cause: `RaffleFactory.sol:154-176` accepts any sponsor-selected contract that self-reports ERC-721 support, while `RaffleFactory.sol:128-133` asks that same untrusted contract whether deposit and ownership succeeded; the protocol has no trusted backing check or undeliverable-prize refund transition before `Raffle.sol:334` relies on that contract for winner delivery.
internal_pre: An attacker sponsors a raffle with a prize contract it controls; at least 100 one-entry purchases meet a reserve of 100, and the authenticated callback resolves the raffle as `NftWon`.
external_pre: None
path:
  1. The attacker deploys `EvilNFT`, which reports ERC-721 support, accepts token 7 into the new clone, performs the expected receiver callback, and reports the clone as token owner.
  2. One hundred entrants buy one entry each for 1 USDC, creating a 100-USDC pot.
  3. A valid request and callback select a winning entry; a settler proves its ticket, allocating 95 USDC to the attacker's sponsor recipient and 5 USDC to the treasury.
  4. Permissionless release calls pay both quote obligations, leaving the raffle with zero USDC.
  5. The winning-ticket owner calls `redeemWinningTicket`, but `EvilNFT.transferFrom` reverts. The redemption transaction rolls back while the earlier quote releases remain final, and terminal `NftWon` exposes neither refunds nor an alternate prize-delivery route.
impact: The winning-ticket owner receives neither the advertised NFT nor any refund, while the malicious sponsor captures 95 of the entrants' 100 USDC and the treasury receives the other 5. The last claimant is short one prize, and the entrants' paid quote value is no longer available to cover that failure.
mitigation: In an NFT result, keep sponsor and protocol quote proceeds locked until the NFT is successfully delivered; add a fixed delivery deadline after which an undelivered result atomically recombines those untouched proceeds into `remainingRefundLiability` and enters `Refunding`.
