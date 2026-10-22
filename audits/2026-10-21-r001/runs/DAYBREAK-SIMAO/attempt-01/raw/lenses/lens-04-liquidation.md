# Lens 4 — Liquidation, Bad Debt & Solvency

## Scope redirect

There is no borrowing, leverage, oracle-priced collateral, health factor, liquidation eligibility, seize calculation, or bad-debt clearing machinery in scope. A collateral/debt position therefore cannot be stated without inventing one. This lens is redirected to the equivalent solvency question for this raffle: whether every USDC and prize liability is fully backed and can actually be settled in every terminal branch.

In plain English, a sponsor gives one NFT. Buyers give 1,000,000 raw USDC units per entry and receive transferable range tickets. The ticket is worth either its full entry cost in the refund branch, 80% of the whole pot if it contains the winning entry in the cash branch, or the escrowed NFT if it contains the winning entry in the NFT branch. There is no yield. When an asset is unavailable, the contract has no loss waterfall: the relevant claimant is simply unable to collect.

The central quote-token invariant is:

`unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees <= quoteToken.balanceOf(address(this))`.

For intended flows using the trusted, fee-free canonical USDC, equality holds until all claims are paid. The separate asset-side invariant is that exactly one deliverable prize backs the NFT-winner claim until successful redemption. The quote ledger enforces the first invariant, but the terminal state machine does not enforce the second against an untrusted prize contract.

## Concrete balance sheets

Use 100 entries at 1,000,000 raw units each, so the raffle holds `G = 100,000,000` raw USDC (100 USDC).

| State | USDC assets | `unsettledPot` | refund liability | winner liability | sponsor liability | fee liability | NFT obligation |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Active/Drawing | 100,000,000 | 100,000,000 | 0 | 0 | 0 | 0 | one escrowed NFT awaits the result |
| CashWon, settled | 100,000,000 | 0 | 0 | 80,000,000 | 15,000,000 | 5,000,000 | return NFT to sponsor |
| NftWon, settled | 100,000,000 | 0 | 0 | 0 | 95,000,000 | 5,000,000 | deliver one NFT to winner |
| Refunding | 100,000,000 | 0 | 100,000,000 | 0 | 0 | 0 | return NFT to sponsor |

In the cash and refund branches, the quote liabilities sum exactly to the held USDC. In the honest-prize NFT branch, the two quote claims sum to the held USDC and the separately escrowed NFT backs the winner. In the adversarial-prize NFT branch, sponsor and treasury can reduce the USDC assets and quote liabilities to zero even though the one-NFT winner obligation is permanently nondeliverable; `accountedQuoteBalance()` cannot expose that asset-side shortfall.

## Function and lifecycle reasoning

[Model: RaffleFactory.createRaffle] The sponsor gives one claimed NFT and receives an activated raffle whose future ticket sales can monetize that prize. The factory count and three registry entries advance once, and the new raffle records its sponsor, recipients, reserve, end time, and prize. If any step reverts, creation, registration, and custody all roll back.

[Why: RaffleFactory.sol:127-134] Why is the same arbitrary prize contract's `ownerOf` answer accepted as proof of economically reliable escrow? The implicit belief is that self-reported ERC-721 support and custody at creation guarantee that the token will remain transferable after buyers have paid. A sponsor-controlled pausable or upgradeable token disproves that belief.

[Defeat: RaffleFactory.createRaffle] (1) A token at `0xA1` returns true for the ERC-721 interface query, performs the initial transfer, and later pauses transfers. (2) An upgradeable token at `0xA2` reports the raffle as owner during factory verification and changes its transfer implementation after 100 USDC is sold. (3) A fully malicious token at `0xA3` directly supplies the expected receiver callback tuple and self-reports the raffle as owner. All three pass checks whose evidence is supplied by the untrusted token itself.

[Model: Raffle.onERC721Received] The surrounding factory transfer is supposed to give the raffle its one prize; the raffle gives no value in return at this point and changes its state from waiting-for-prize to active. No quote liability exists yet.

[Defeat: Raffle.onERC721Received] (1) An unrelated token at `0xB1` supplies the right token ID but fails the caller-address check. (2) The configured token supplies the sponsor as sender but an operator other than the factory and fails the operator check. (3) The configured malicious token supplies its own address, token ID 7, sponsor `0xB2`, and the factory operator exactly as expected; the tuple guard passes even if that token can later refuse delivery.

[LastOut: create → escrow → activate] There is no quote claimant yet. With an honest prize, one held NFT backs the eventual winner or sponsor claim. With the accepted hostile-prize cases above, the lifecycle can finish `Active` without a durable delivery guarantee, so the eventual last NFT claimant is not assured payment.

[Model: Raffle.buyEntries] A buyer gives `entryCount * 1,000,000` raw USDC and the chosen recipient gets one transferable ticket covering that many consecutive entries. `totalEntries` rises by the entry count, `ticketCount` rises by one, and `unsettledPot` rises by exactly the payment.

[Defeat: Raffle.buyEntries] (1) A buyer tries one entry above the remaining `uint128` capacity and is rejected before payment or counters change. (2) A recipient contract at `0xC1` rejects the ticket callback; the mint, pot increase, and USDC movement all revert. (3) A recipient at `0xC2` reenters an accounting function during receipt; the reentrancy guard rejects it, while a permitted transfer of the just-minted ticket only changes which address owns the same claim.

[LastOut: buy → hold/transfer ticket] After Alice buys 60 entries and Bob buys 40, the raffle holds 100,000,000 raw USDC and records the same amount in `unsettledPot`; ticket transfers change the bearer, not the amount owed. No one exits in this phase, and there is no cohort drift before a terminal branch is chosen.

[Model: Raffle.requestDraw] The requester gives native currency for one randomness request. The wrapper receives its actual price, the same requester receives every excess wei, and the raffle records the drawing state, request time, and request ID. Sale USDC and all quote liabilities are unchanged.

[Defeat: Raffle.requestDraw] (1) An EOA supplies the exact quoted price and leaves no native remainder. (2) Contract `0xD1` overpays by 1 wei and rejects the excess refund; the whole request, including wrapper-side state, reverts atomically. (3) A callback arrives synchronously before request persistence; `_requestInFlight` makes it non-resolving, and the trusted wrapper's later authenticated callback remains the usable path.

[Model: Raffle.fulfillRandomWords] No user gives or receives value. One authenticated random word fixes an entry and changes the result to NFT-won or cash-won; it does not allocate or transfer the pot.

[Defeat: Raffle.fulfillRandomWords] (1) The wrapper supplies request ID 12 while 11 is stored and the call is ignored. (2) it supplies two words instead of one and the call is ignored. (3) it supplies the correct request at exactly `drawRequestedAt + 2 days`; the strict deadline check ignores it, matching refund availability at that boundary.

[LastOut: sale end → request → callback] The draw requester is the only native-currency claimant and receives all excess in the request transaction or that transaction reverts. The 100,000,000 raw-USDC sale pot remains untouched and fully accounted. No quote user exits here.

[Model: Raffle.enableRefunds] No caller receives value immediately. The entire unallocated pot is relabeled as refund liability, `unsettledPot` becomes zero, and the raffle enters the refund state. Because tickets cannot previously be burned in an active or drawing raffle, the liability still matches all live ranges.

[Defeat: Raffle.enableRefunds] (1) The sponsor tries to cancel a sold 100-entry raffle one second before the request deadline and is rejected. (2) Any caller acts exactly at a sold raffle's request or callback deadline and is accepted, while a callback at that exact time is not. (3) A non-sponsor tries to close an empty raffle before `endTime` and is rejected; the sponsor alone can do so early.

[Model: Raffle.refundTickets] An owner gives up and burns selected tickets and receives their represented entry count times 1,000,000 raw USDC. `remainingRefundLiability` falls by the exact payment; historical sales and range facts intentionally stay unchanged.

[Defeat: Raffle.refundTickets] (1) Alice submits ticket 1 twice; the second ownership lookup fails and the whole batch rolls back. (2) Alice combines her ticket with Bob's ticket 2; the foreign-owner check rolls back all burns and payment. (3) Alice supplies 101 ticket IDs; the bounded-size check rejects the batch before any liability changes.

[LastOut: request/callback timeout → refunds] Let Alice's ticket represent 60 entries and Bob's represent 40. If Alice exits first, assets/liability move from 100,000,000/100,000,000 to 40,000,000/40,000,000, and Bob—the last user out—receives all 40,000,000. In the reverse order Alice is last and receives all 60,000,000. The protocol is short by zero raw USDC in either worst order.

[Model: Raffle._settleWinningTicket] A caller gives only a valid winning-ticket identifier and receives nothing. The function consumes the unallocated pot and creates terminal winner, sponsor, and treasury claims. For 100 USDC, CashWon creates 80/15/5 USDC claims; NftWon creates 95/5 quote claims while leaving prize delivery for a later transaction.

[Why: Raffle.sol:539-555] Why do the NFT-result sponsor and treasury claims become unconditional before the winner asset moves? The implicit belief is that later NFT delivery cannot fail permanently. That belief conflicts with the stated untrusted-prize boundary.

[Defeat: Raffle._settleWinningTicket] (1) Ticket ID 999 was never minted, has range `[0,0]`, and cannot contain a positive winning entry. (2) A real losing ticket whose range ends at 60 cannot settle winning entry 61. (3) A second call with the correct ticket is rejected by `settlementComplete`. These proof/replay guards are sound, but none tests whether the prize backing an `NftWon` result is still deliverable.

[Model: Raffle.redeemWinningTicket] The current winning-ticket owner gives up and burns the ticket. In CashWon the owner receives the entire winner claim and that liability becomes zero. In NftWon the owner is supposed to receive the prize and the winner/prize flags become consumed. A failure in this transaction rolls back its burn and flag changes, but it cannot roll back settlement or quote releases completed in earlier transactions.

[Why: Raffle.sol:332] Why is reverting the winner's NFT-redemption transaction considered sufficient when quote settlement and releases are independent earlier transactions? The implicit belief is that reverting this call restores the whole economic exchange; it restores only this call, not USDC already paid to sponsor and treasury.

[Defeat: Raffle.redeemWinningTicket] (1) A non-owner at `0xE1` supplies the correct winning ticket and fails the ownership check. (2) The owner supplies a different ticket after settlement and fails the recorded-ID check. (3) The sponsor-controlled prize pauses or upgrades itself after escrow and makes the configured transfer revert forever; redemption now always reverts, while prior sponsor and treasury releases remain final.

[Model: Raffle.releaseSponsorProceeds] Any caller triggers payment of the whole sponsor claim to the immutable sponsor recipient. The claim is set to zero before the trusted quote token pays; a failed payment reverts both operations.

[Defeat: Raffle.releaseSponsorProceeds] (1) A caller invokes it before settlement and encounters a zero-claim revert. (2) A caller replays it after a successful payment and encounters the same revert. (3) The hostile sponsor settles an `NftWon` raffle and invokes it before the winner can receive the paused prize; the function succeeds because it has no `prizeClaimed` or `winnerRedeemed` condition. The third move defeats economic atomicity.

[Model: Raffle.releaseProtocolFees] Any caller triggers payment of the whole protocol-fee claim to the immutable treasury. The fee claim becomes zero atomically with the trusted quote-token payment.

[Defeat: Raffle.releaseProtocolFees] (1) Calling before settlement sees zero and reverts. (2) replay after payment sees zero and reverts. (3) calling after `NftWon` settlement but before prize delivery succeeds, confirming that all quote consideration can leave without the winner asset being deliverable.

[Model: Raffle.releaseSponsorPrize] In CashWon or Refunding, any caller returns the one NFT to the sponsor recipient and consumes the prize claim. The quote claims are independent, and a failed token transfer rolls back `prizeClaimed`.

[Defeat: Raffle.releaseSponsorPrize] (1) A caller tries it in NftWon and the status guard rejects the call. (2) a caller repeats a successful return and the consumed flag rejects it. (3) a hostile prize reverts in CashWon or Refunding; the sponsor's own NFT remains stuck, but cash-winner or refund liabilities do not change, so this sibling branch does not make entrants' quote claims insolvent.

[Model: Raffle._transferQuote] One already-recorded quote claimant receives its entire claim from this raffle. Known same-factory protocol sinks are rejected, and the calling function's prior liability decrement rolls back if the trusted token payment fails.

[Defeat: Raffle._transferQuote] (1) A current ticket owner tries to route a payout to a registered same-factory raffle and is rejected. (2) a normal contract owner with no token-receive hook still receives canonical USDC because the token does not invoke a recipient callback. (3) a trusted-token transfer failure reverts the preceding claim deletion, leaving assets and liabilities aligned.

[LastOut: CashWon → settle → redeem/release] Starting at 100,000,000 assets and 80,000,000/15,000,000/5,000,000 liabilities, pay sponsor and treasury first. Assets fall to 80,000,000 and only the winner claim remains; the winning owner—the last user out—receives all 80,000,000. Paying the winner first or interleaving releases gives the same zero ending balance. The protocol is short by zero raw USDC.

[LastOut: NftWon → settle → redeem/release] With an honest prize, sponsor and treasury receive 95,000,000 and 5,000,000 in either order and the winning owner receives the single NFT; every last claimant is paid in full. With a sponsor-controlled prize that becomes non-transferable, sponsor and treasury can exit first and reduce quote assets/liabilities to zero, but the winning owner—the last claimant—cannot receive the NFT. The protocol is short by one deliverable NFT, and there is no 100,000,000-raw-USDC refund liability to substitute for it.

[LastOut: empty raffle cancellation] There are zero quote assets and zero quote claimants. The sponsor recipient is the sole NFT claimant. Honest delivery pays that claimant; hostile-token failure harms the sponsor's own returned-prize claim and does not create a buyer shortfall because no entries were sold.

## Saturation of the broken pattern

The untrusted-external-asset pattern appears at every prize boundary:

1. Ingress: `RaffleFactory.createRaffle` checks an interface response, performs the initial transfer, then asks that same token for `ownerOf`; none of these proves future transferability.
2. Activation: `onERC721Received` authenticates the expected address and tuple, but the configured token itself can manufacture that tuple.
3. NFT-winner egress: `redeemWinningTicket` is the exploitable branch because an unrelated winner is owed the NFT while sponsor and treasury quote claims can already be paid.
4. Sponsor-prize egress: `releaseSponsorPrize` has the same external-call failure shape, but only in CashWon/Refunding, where buyers' cash/refund liabilities remain exactly backed and independently claimable. Its worst direct victim is the sponsor recipient, so it is not a second finding.
5. A prize that merely reverts causes permanent winner-claim denial. A pausable or upgradeable prize makes that denial sponsor-controlled. A fully malicious prize can additionally fake receiver and ownership answers. The profitable worst case is therefore the NftWon path below.
6. The analogous quote-token exits are not repeat instances: USDC is explicitly trusted, every claim is zeroed once, and transfer failure rolls the decrement back. Ticket-receiver failure during purchase likewise rolls back the payment and all aggregate writes.

FINDING | contract: Raffle | function: _settleWinningTicket | bug_class: unbacked-prize-settlement | group_key: Raffle | _settleWinningTicket | unbacked-prize-settlement
root_cause: `Raffle.sol:539-555` converts the full pot into immediately releasable sponsor and protocol claims in `NftWon` before prize delivery, while `Raffle.sol:332-336` has no recovery transition when the arbitrary prize contract permanently refuses delivery; the factory's self-reported ERC-721/ownership checks at `RaffleFactory.sol:127-134` cannot establish future transferability.
internal_pre: A raffle uses a sponsor-controlled pausable, blacklistable, or upgradeable ERC-721; at least the reserve number of entries is sold, so the authenticated callback sets `NftWon`.
external_pre: None
path:
  1. A malicious sponsor deploys an ERC-721 that permits escrow initially but whose transfer can later be disabled, then creates a raffle with reserve 100 and an attacker-controlled `sponsorRecipient`.
  2. Honest entrants buy 100 entries for 100,000,000 raw USDC; assets and `unsettledPot` are both 100,000,000.
  3. The sponsor disables transfers after escrow. Because total entries meet the reserve, any authenticated random result produces `NftWon`; the selected honest winning ticket is immaterial to the attack.
  4. The sponsor or any caller supplies the publicly derivable winning ticket to settlement. `unsettledPot` becomes zero, `sponsorProceeds` becomes 95,000,000, and `protocolFees` becomes 5,000,000 without moving the prize.
  5. Permissionless releases pay 95,000,000 to the attacker's recipient and 5,000,000 to the treasury, leaving zero quote assets and zero quote liabilities.
  6. The winning owner calls redemption. The prize transfer reverts forever, so this call rolls back, but the earlier quote releases remain final; `NftWon` has no transition to full refunds.
impact: Entrants collectively lose the 100 USDC consideration to a raffle with no deliverable prize, the malicious sponsor extracts 95 USDC without providing the promised terminal asset, and the winning-ticket owner is left holding an unpayable one-NFT claim. The protocol is asset-side insolvent by one prize NFT and exposes no replacement refund liability.
mitigation: Enforce an immutable factory allowlist (or immutable code-hash allowlist) of audited, non-upgradeable, non-pausable prize-token implementations; an arbitrary ERC-721 cannot be made economically trustworthy by querying its own interface and ownership methods.

No additional solvency candidate survived saturation. Forced unrelated assets create surplus rather than claimant insolvency; predicted or foreign protocol destinations require the ticket owner to strand its own claim; and all honest-prize quote payout orders leave the last claimant fully paid.
