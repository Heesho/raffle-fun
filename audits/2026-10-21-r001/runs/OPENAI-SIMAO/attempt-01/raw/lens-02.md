# Lens 02 — Shares, exchange rates, and redemption

Target revision supplied by the money map: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`.
Scope: `Raffle.sol`, `RaffleFactory.sol`, `RaffleConstants.sol`, `IRaffle.sol`, `IRaffleFactory.sol`, and `DESIGN.md`.
Requested and locally accepted execution configuration: `gpt-6-astra`, reasoning effort `ultra`, as communicated by the audit dispatcher. Provider-reported execution model and effort: **unknown**; no such runtime metadata is visible. The configuration is not an identity inference from the prompt.

The full 1,878-line lens bundle was read in consecutive ranges 1–300, 301–600, 601–900, 901–1200, 1201–1500, 1501–1800, and 1801–1878. No peer outputs, existing tests, historical reports, scanner results, or memory were read. Additional reads are limited to reachable implementation dependencies. The target is unchanged. This document preserves the audit reasoning record, including defeated candidates, explicit non-applicability, and any remaining leads.

## Phase 0 and Phase 1 — Vocabulary and money map first

A payer gives one USDC for each entry. One purchase creates one transferable ticket containing exactly those entries. The current ticket holder owns its eventual refund or prize right; the payer has no separate claim. There is no yield, interest, deposit-dependent exchange rate, or divisible pool receipt. A winning ticket can be worth an indivisible NFT or 80% of all gross sales, which is the explicitly purchased lottery risk rather than a reversible exchange rate.

The quantities this lens owns are lifetime `totalEntries` and `ticketCount`, immutable inclusive `_ticketRanges`, live inherited ticket ownership, `unsettledPot`, and all four terminal payment balances. Each purchase adds entries, one ticket, a contiguous range, and the exact nominal amount collected. Neither a ticket transfer nor a burn reduces lifetime totals. Settlement empties the pot into winner/sponsor/treasury claims; refunds empty the pot into the full-refund balance. Each successful payment extinguishes its corresponding right once. The NFT is a separate indivisible liability represented by terminal result and `prizeClaimed`.

| Quantity | All scoped writers | Direction and backing |
| --- | --- | --- |
| totalEntries | buyEntries | + entryCount, after quote pull; historical forever |
| ticketCount | buyEntries | + 1 per positive purchase; historical forever |
| ticket range | buyEntries | [old total + 1, old total + count], never overwritten |
| live ticket ownership | inherited ERC721._update through mint/transfer/burn | One owner per unburned ticket; burn removes live claim |
| unsettledPot | buyEntries, enableRefunds, _settleWinningTicket | + paid amount; exactly one terminal transition removes entire amount |
| remainingRefundLiability | enableRefunds, refundTickets | + old pot; − exact represented entry cost on burn |
| winnerProceeds | _settleWinningTicket cash branch, redeemWinningTicket cash branch | + floor(80% pot); − complete claim on burn/payment |
| sponsorProceeds | _settleWinningTicket, releaseSponsorProceeds | + residual after other allocations; − entire claim |
| protocolFees | _settleWinningTicket, releaseProtocolFees | + floor(5% pot); − entire claim |
| prizeClaimed | redeemWinningTicket NFT branch, releaseSponsorPrize | false → true once; transfer failure rolls back |
| registry/count | createRaffle | all writes revert unless complete escrow and activation succeed |

The relevant asymmetries are intentional unless a sequence defeats them: lifetime totals do not decrease when tickets burn; cash winner funds exist only in the cash branch; sponsor receives arithmetic remainder; donations do not create liabilities; settlement is independent of the live ticket owner's ability to receive the prize. The last asymmetry is the important trust-boundary question. DESIGN.md says arbitrary prize contracts are untrusted; IRaffle.sol:12–15 narrows supported prizes to honest, standards-compliant NFTs. Both interpretations are retained explicitly.

## Phase 2 — Written invariants

1. For trusted, fee-free USDC, the sum of five outstanding quote claims never exceeds the clone's actual USDC; absent donations they are equal.
2. Every sold entry costs exactly 1,000,000 raw quote units, and grossSales equals lifetime entries times this price.
3. Ticket ranges partition [1,totalEntries] once; ticketCount is at most totalEntries.
4. A refund burns a live ticket and pays its inclusive range length times the fixed price exactly once.
5. A ticket transfer moves the entire remaining refund/winner right to its current owner without changing its range or value.
6. Only the current owner can redeem/refund; previous owners and merely approved operators cannot receive payment through those paths.
7. Settlement allocates the entire old pot once; the sum of allocated balances equals the pot in both terminal outcomes.
8. Successful outgoing USDC payment decreases the matching balance by exactly the transferred amount. A failed payment rolls all state back.
9. The NFT-winning claim and sponsor's returned-prize claim are mutually exclusive, and a failed prize delivery preserves the unburned winning claim.
10. A refunded or redeemed ticket's retained historical range never grants a second payable right.
11. A draw's denominator is positive, frozen after the sale, and cannot be increased by donation or ticket transfer.
12. Every last refundable ticket and every last cash claimant remains fully backed, irrespective of payout order.
13. One clone's receipts and balances cannot be used to debit another clone's liabilities through a protocol path.
14. Terminal asset delivery remains collectible under the actual permitted prize-token trust model; this is stronger than mere preservation of a reverted claim.

## Phase 3 — Lifecycles and mandatory working markers

[Model: createRaffle and initialize]
The sponsor gives one configured NFT to a fresh raffle and fixes the sponsor's payout recipient, entry threshold, and closing time. The factory adds one raffle to its count and directory. Buyers receive no claim until they separately pay. Creation must either leave the configured prize in an active raffle or undo the count, directory, initialization, and transfer together.

[Why: RaffleFactory.sol:123]
Why register the clone before calling the prize contract? The recipient checks consult the factory directory, so the new clone must already be recognizable as protocol plumbing during later external interaction; transaction rollback is assumed to restore all registration if escrow verification fails.

[Defeat: createRaffle]
1. At attacker address A, provide an NFT that calls its recipient hook but then reports owner A: the final owner check rejects creation and restores the count/directory.
2. Provide an NFT that reports the clone as owner without invoking the expected receipt hook: the final status check remains AwaitingPrize and rejects creation.
3. Provide an NFT that honestly escrows on creation but refuses every later transfer out of the clone: creation passes. This does not break initial accounting, but it challenges terminal collection and is retained for saturation below.

[Model: onERC721Received]
The configured prize contract acknowledges the factory's transfer of the sponsor's exact NFT. This changes the raffle from waiting for a prize to open for purchases; it creates no entry or money balance.

[Defeat: onERC721Received]
1. A sends the hook from a different token address with the right token ID: the token check rejects it.
2. The right token sends the wrong ID or claims a different sender than the sponsor: the full tuple check rejects it.
3. The right token repeats the hook after activation or during redemption: the waiting-state check rejects it. The hook still cannot certify the honesty of the token making the report.

[LastOut: create and escrow]
Before purchases, there are no buyer cash claims. A failed creation reverts all effects. For an honest NFT and an empty raffle, the sponsor can close and reclaim the exact prize. For a malicious NFT that refuses outgoing transfers, the sponsor's recovery can fail; when only the sponsor is affected, this is self-harm and not a finding. The same token admitted to a sold raffle requires a separate buyer-victim analysis.

[Model: buyEntries]
The payer gives entryCount USDC and chooses who receives one ticket covering exactly those new entries. The lifetime entry total rises by entryCount, the lifetime ticket count rises by one, and the unallocated cash pot rises by the amount paid. All these changes and the payment undo if the recipient rejects the ticket.

[Why: Raffle.sol:226]
Why calculate the new range after collecting the payment rather than before it? The implementation assumes the fixed quote token transfers exactly the requested units and cannot change sale accounting while the purchase is in progress; the shared transaction guard protects economic entrypoints, and the trusted canonical-token premise supplies exact-transfer behavior.

[Defeat: buyEntries]
1. A donates 100 USDC before B buys one entry: B still pays 1 USDC, receives range [1,1], and adds only 1 USDC to the pot. Donation cannot inflate a conversion rate.
2. A buys entryCount=0, or totalEntries=2^128−1 and entryCount=1: explicit checks reject before collection or minting.
3. Receiver C tries to buy or refund again during its ticket-receipt callback: guarded economic entrypoints reject reentry. C may transfer its newly received ticket normally, which changes only the legitimate bearer and does not create another range or credit.

[Model: ticket transfer and _update]
A current holder or authorized transfer operator gives the existing ticket to a new holder. The entire remaining claim follows the ticket. One live ownership balance falls and the other rises, while the entry range, lifetime totals, pot, and payout balances do not change.

[Why: Raffle.sol:497]
Why screen destinations before the inherited owner update, including on mint? The policy aims to prevent a valid bearer claim becoming stuck in known protocol contracts that cannot initiate redemption. It is not a proof that every arbitrary recipient can later act.

[Defeat: _update and inherited transferFrom]
1. A transfers B's ticket without approval: inherited authorization rejects it.
2. A transfers a live ticket to its own raffle, the canonical factory, the configured prize token, or a registered sibling clone: the destination check rejects it before owner mutation.
3. A tries to transfer an already burned winning ticket or sends an incorrect from address: inherited ownership/existence checks reject, reverting any tentative ownership update. An approved operator can first transfer a ticket to itself, but that is the transfer authority the holder granted, not an extra payout privilege.

[LastOut: buy and transfer]
Let A buy 2 entries and B buy 3. A transfers its ticket to C. Total pot is 5 USDC and ranges are [1,2], [3,5]. If the raffle refunds, B can take 3 first and C takes the last 2 in full. A has no remaining claim, and no claim was duplicated during transfer. The order C then B also leaves the final B claim fully backed.

[Model: requestDraw and fulfillRandomWords]
After the sale, the caller pays the oracle's native-currency fee and receives back only the excess of that payment. The entry pot does not pay the fee. The accepted oracle response chooses one sold entry and records whether the entry threshold was met; it does not pay anyone or change the pot.

[Why: Raffle.sol:518]
Why is the lifetime entry count the random-selection denominator even though ticket burns exist? Purchases stop before drawing, while burns exist only in mutually exclusive terminal refund/redemption paths; no valid burn can reduce the live competing range before the winning entry is selected.

[Defeat: requestDraw and fulfillRandomWords]
1. A asks for a draw with zero entries: requestDraw rejects before division can occur.
2. A buys after sale end or while Drawing to change totalEntries after learning the request: the sale/time/state checks reject.
3. A calls the callback directly, repeats the authenticated callback, or submits a callback exactly at the callback deadline: inherited wrapper authentication, terminal-state checks, and the exclusive deadline respectively reject/ignore; the frozen denominator is not manipulated.

[LastOut: draw]
Drawing alone leaves every collected USDC in the same pot. If the oracle times out, the last holder retains a full-price refund. For an ordinary request funded with 0.012 native units and an actual fee of 0.010, the caller recovers 0.002, while a preexisting forced donation remains unchanged. No ticket claimant pays the fee or subsidizes a later caller.

[Model: enableRefunds]
After a permitted timeout, or cancellation of an empty raffle, the entire unallocated cash pot becomes the amount owed to refundable ticket holders. Nothing is paid yet, and the pot becomes zero. The NFT becomes returnable to the sponsor's fixed recipient.

[Defeat: enableRefunds]
1. A attempts early cancellation after one honest entry was sold: the sold-raffle request deadline prevents it, including when A is the sponsor.
2. A enables refunds at the exact callback deadline while a callback transaction competes: a callback at that timestamp cannot resolve, so only the refund branch wins.
3. A tries refunds after NftWon/CashWon or repeats enableRefunds after Refunding: the state guard rejects, preventing the same pot funding two outcomes.

[Model: refundTickets]
The current holder destroys between one and 100 chosen live tickets and receives their exact original entry cost. The sum still owed to refundable ticket holders falls by the same amount. The historical ranges and lifetime counts remain to describe past sales, not extra live claims.

[Why: Raffle.sol:363]
Why burn before reducing the aggregate refund balance, and why can historical ranges remain? The number of refundable entries comes from the immutable range just read; destroying the live ownership record prevents a later duplicate claim. No payment calculation divides by the remaining ticket count or depends on a post-burn rate.

[Defeat: refundTickets]
1. A submits ticket IDs [1,1] for a two-entry ticket: the first burn removes ownership, the second owner lookup reverts, and the transaction restores both the first burn and all balances.
2. A submits B's valid ticket or a never-minted ID: current-owner/existence checks reject before payment.
3. A submits its ticket with a stale historical range after a previous refund, or an empty/101-ticket batch: live ownership or the bounded-batch guard rejects. Splitting into valid batches changes neither amount nor entitlement.

[LastOut: refunds]
For ticket sizes 1, 2, and 7, the initial liability is 10,000,000 raw units. Refund 7, then 2, then 1: liability and token backing successively become 3,000,000; 1,000,000; 0. Reverse the order and the last seven-entry holder receives 7,000,000 in full. A failed transfer restores the burned tickets and full liability, so no earlier failed claimant consumes the final claimant's backing. Shortfall: zero under trusted quote-token transfers.

[Model: settleWinningTicket and _settleWinningTicket]
Anyone can prove which stored entry range contains the winning entry. The entire unallocated pot is converted once into the sponsor and treasury claims, and into a winner cash claim when the threshold was missed. No token moves and the winner keeps the transferable ticket until redemption.

[Why: Raffle.sol:538]
Why verify the winning range without requiring a currently live owner? No ticket can have been burned before settlement in either winning state: refunds belong to a different terminal branch, and winning redemption either settles first or requires settlement already completed. Historical range retention therefore does not by itself produce a live double-payment path.

[Defeat: _settleWinningTicket]
1. A submits never-minted ticket 0 with range [0,0] after winningEntry=1: range containment rejects it.
2. A submits a different real ticket whose range does not include the selected entry, or repeats a previously successful settlement: range/settlement guards reject.
3. A settles the actual winning ticket immediately before its owner transfers it to C: no ownership was snapshotted, so C still receives the full remaining bearer claim. A cannot redirect the payment to the settler.

[Model: redeemWinningTicket]
The current holder of the winning ticket destroys it and receives either the entire allocated cash amount or the escrowed NFT. The winner record is written, the winner's live ticket disappears, and the relevant unpaid claim is consumed. Any failed delivery undoes these changes.

[Why: Raffle.sol:325]
Why record the current owner and burn before calculating the cash payment? The cash amount is a fixed previously allocated liability, not a ratio of current ticket supply. Burning cannot increase the rate; it closes the bearer claim before external payment.

[Defeat: redeemWinningTicket]
1. Previous owner A transfers the winning ticket to B, then calls redeem: current ownership rejects A. B is paid if B redeems.
2. Approved operator C calls redeem directly without becoming owner: the explicit caller-equals-owner check rejects C despite transfer approval.
3. B tries repeated redemption, or a prize token tries nested redemption during NFT delivery: winnerRedeemed and the common entry guard prevent second payment. Failed NFT delivery rolls back the burn but can still leave the winning claim perpetually uncollectible, explored below.

[LastOut: NFT settlement and redemption]
For 100 entries, the 100-USDC pot becomes sponsor=95 and treasury=5. They may be paid in either order; the last cash claimant receives its complete amount. With an honest transferable prize, the winner can redeem before or after those cash payments and receives the NFT once. With an admitted malicious prize, sponsor-first order can leave the last winner with a conserved but permanently uncollectible NFT claim; the cash ledger itself remains balanced. This distinction is not cured by atomic rollback.

[LastOut: cash settlement and redemption]
For 10 entries below reserve, 10,000,000 raw units become winner=8,000,000, sponsor=1,500,000, treasury=500,000. Sponsor then treasury leaves exactly 8,000,000 for the last winner. Winner then sponsor leaves 500,000 for the last treasury. All six possible orders sum to 10,000,000 and leave zero liability. The sponsor's separate NFT return neither debits nor competes for these cash claims.

[Model: releaseSponsorProceeds]
Any caller can trigger payment of the sponsor's complete allocated cash balance to the recipient fixed at raffle creation. That balance is cleared before payment and restored if the transfer fails. The caller gets no payment by triggering it.

[Defeat: releaseSponsorProceeds]
1. A calls before settlement when sponsorProceeds is zero: the zero-claim guard rejects.
2. A calls after the sponsor has already received 95 USDC: the cleared claim prevents another 95-USDC payment.
3. A calls on B's raffle hoping to substitute A as recipient: the destination comes from immutable-per-raffle configuration, not the trigger caller.

[Model: releaseProtocolFees]
Any caller can pay the treasury its complete allocated fee. The outstanding fee is cleared before the trusted quote-token transfer, and failure restores it. No other claimant's balance changes.

[Defeat: releaseProtocolFees]
1. A calls before settlement: a zero fee cannot be paid.
2. A calls repeatedly after the initial 5-USDC fee payment: clearing prevents repetition.
3. A attempts to supply a different recipient or amount: the method has neither parameter; the fixed treasury and complete fee are used.

[Model: releaseSponsorPrize]
After a cash result or refunds, any caller can return the original prize to the sponsor's chosen recipient. The single prize-claimed flag is consumed before delivery and restored on failure. No ticket or quote balance changes.

[Why: Raffle.sol:404]
Why use an outgoing transfer followed by a reported-owner check? This avoids requiring a recipient callback while attempting to verify delivery. It relies on the prize contract both permitting the transfer and reporting ownership honestly; querying the same untrusted contract cannot establish those assumptions universally.

[Defeat: releaseSponsorPrize]
1. A triggers sponsor prize return in NftWon: result-state guard rejects, preserving the winner's entitlement.
2. A returns the prize twice in CashWon: prizeClaimed rejects the second attempt.
3. The prize contract reports success but refuses to change its actual owner, or reports a fictitious owner: an honest owner report detects the former, while a dishonest token defeats the verification. The latter is a trust-boundary limitation, not a USDC arithmetic error.

[LastOut: independent sponsor and treasury releases]
Clearing one allocated balance never changes another balance or the winning ticket. Any release order leaves the remaining claim backed by exactly the remaining accounted USDC. A failed recipient transfer leaves its amount owed and does not consume another party's balance. Honest-prize return succeeds independently in cash/refund outcomes; a malicious sponsor's stuck own prize alone is not reportable harm.

