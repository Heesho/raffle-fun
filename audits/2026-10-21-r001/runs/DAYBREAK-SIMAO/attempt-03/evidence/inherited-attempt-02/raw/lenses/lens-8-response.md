[Model: createRaffle] A sponsor gives one prize and receives an active raffle. The lifetime raffle count rises by one, and the registry binds one new identifier to one new raffle; buyer-money totals remain zero.

[Model: initialize] The factory supplies the sponsor, beneficiaries, prize identity, reserve, and closing time. The raffle moves from unused to waiting for its prize; no asset or liability moves.

[Model: onERC721Received] The configured prize contract presents the sponsor’s prize. The raffle opens entry sales; no USDC total changes.

[Model: buyEntries] A buyer gives 1 USDC per entry, and the chosen recipient receives one ticket covering those entries. Lifetime entries, lifetime tickets, and the unallocated sale pot increase by the corresponding amounts.

[Model: _update] A ticket owner gives the same bearer claim to another address. Entry coverage and every USDC total remain unchanged.

[Model: requestDraw] A caller gives the randomness service its native-currency fee and receives any excess back. The raffle records the request and enters the drawing state; USDC liabilities do not change.

[Model: fulfillRandomWords] Nobody gives or receives value. Authenticated randomness selects one sold entry and fixes either the NFT or cash result.

[Model: enableRefunds] No new money enters. The complete unallocated sale pot becomes the aggregate refund liability, preserving the total amount owed.

[Model: settleWinningTicket] Nobody receives assets yet. The unallocated pot becomes the winner, sponsor, and treasury claims, whose sum equals the old pot.

[Model: redeemWinningTicket-nft] The winning owner burns the winning ticket and should receive the escrowed prize. The prize changes from unclaimed to claimed; USDC totals are unchanged.

[Model: redeemWinningTicket-cash] The winning owner burns the winning ticket and receives the complete cash-winner claim. That claim falls to zero.

[Model: refundTickets] An owner burns up to 100 tickets and receives exactly 1 USDC per represented entry. The aggregate refund liability decreases by the same amount.

[Model: releaseSponsorProceeds] The immutable sponsor recipient receives the complete sponsor claim, which becomes zero.

[Model: releaseProtocolFees] The immutable treasury receives the complete fee claim, which becomes zero.

[Model: releaseSponsorPrize] After a cash or refund result, the sponsor recipient receives the prize. The prize becomes claimed; buyer-money liabilities are independent.

[Model: _transferQuote] One named beneficiary receives one complete USDC claim after its matching liability has been reduced. A failed payment restores the entire transaction.

[Why: RaffleFactory.sol:129] Why does one ownership answer prove escrow? Because the design assumes the sponsor-selected prize contract truthfully describes and preserves custody, even though that same contract supplies both the transfer behavior and the answer.

[Why: Raffle.sol:235] Why is the ticket-recipient call made after recording the purchase? Because any rejection must undo the payment and all totals atomically; it does.

[Why: Raffle.sol:254] Why is an in-flight flag needed? Because the code assumes the trusted randomness service normally answers later and deliberately refuses a callback arriving before the request identifier is stored.

[Why: Raffle.sol:267] Why must excess native currency be returned synchronously? Because the raffle keeps no native-currency claim ledger; a rejecting requester therefore cancels only its own request attempt.

[Why: Raffle.sol:298] Why is the entire pot copied into refund liability? Because every live ticket remains entitled to its full purchase price, with no other USDC cohort sharing that branch.

[Why: Raffle.sol:315] Why may redemption settle first without reading ownership? Because the ticket remains transferable after allocation and ownership is checked immediately before burning it.

[Why: Raffle.sol:334] Why can failed NFT delivery only revert? Because there is no terminal deadline or alternate state transition; the code assumes every accepted prize remains transferable forever.

[Why: Raffle.sol:335] Why check reported ownership after delivery? It catches an honest no-op transfer, but still assumes the untrusted prize contract answers truthfully.

[Why: Raffle.sol:368] Why reduce refund liability before paying? Because transaction rollback restores both the ticket and liability if payment fails, preventing repeat claims.

[Why: Raffle.sol:375] Why may sponsor proceeds leave before NFT delivery? Because settlement is treated as economically final, implicitly assuming the prize handoff cannot fail permanently.

[Why: Raffle.sol:404] Why does sponsor-prize return use the same untrusted token calls? Because the sponsor selected that asset; failure does not obstruct buyer refunds or cash-winner payment.

[Why: Raffle.sol:511] Why are malformed, early, late, and mismatched callbacks ignored? Because reverting a trusted callback could consume its only delivery attempt, while timeout refunds supply the recovery path.

[Why: Raffle.sol:544] Why does the sponsor receive the arithmetic remainder? Because this allocates every raw USDC unit and prevents last-claimant dust shortfalls.

[Why: Raffle.sol:602] Why are code-less destinations skipped during the registry check? Because they cannot be registered raffles yet, implicitly accepting that a predictable future raffle address can receive a ticket before deployment.

[Defeat: _validateCreateParams] (1) Mallory’s prize contract returns true for the NFT interface; (2) it permits token 1 to enter the raffle but rejects every later exit; (3) an upgradeable prize behaves normally during creation and changes behavior after buyers pay. All three pass the interface check.

[Defeat: createRaffle] (1) EvilNFT directly produces the expected receiver callback; (2) it reports the raffle as token owner during the factory check; (3) it later permanently disables transfers from the raffle. Creation detects none of the future-delivery failure.

[Defeat: buyEntries] (1) Alice buys at exactly the closing timestamp and is rejected; (2) Mallory names the factory as recipient and the sink check rejects it; (3) a recipient contract rejects its ticket and the payment plus all totals roll back. None creates shared unavailability.

[Defeat: requestDraw] (1) Eve requests one second before closing and is rejected; (2) a requester overpays by 1 wei but rejects the refund, cancelling only its own transaction; (3) Eve directly forges a callback and the inherited sender check rejects her. Another caller remains able to request.

[Defeat: enableRefunds] (1) A nonsponsor tries to close an empty raffle before its end and is rejected; (2) Eve tries to refund a sold raffle one second before the request deadline and is rejected; (3) a callback arriving at the exact callback deadline is ignored while refunds become available. No gap traps buyer money.

[Defeat: fulfillRandomWords] (1) An external account sends a callback and fails authentication; (2) an authenticated callback supplies request ID 999 instead of the recorded ID and is ignored; (3) the correct callback arrives at the exclusive deadline and is ignored in favor of timeout refunds.

[Defeat: settleWinningTicket] (1) Mallory supplies nonexistent ticket 999 and its zero range fails; (2) Mallory supplies a real losing ticket and its range fails; (3) Mallory repeats the correct ticket after settlement and the one-shot guard fails. Allocation cannot be poisoned.

[Defeat: redeemWinningTicket] (1) Mallory submits Alice’s winning ticket but is not its owner; (2) Mallory submits ticket 2 after ticket 1 was recorded as winner; (3) EvilNFT permanently rejects the raffle-to-Alice prize transfer. The first two fail safely; the third permanently blocks the only NFT redemption path.

[Defeat: refundTickets] (1) Alice supplies 101 ticket IDs and is rejected before iteration; (2) she repeats ticket 7 and the entire batch rolls back; (3) she includes Bob’s ticket and the entire batch rolls back. Alice can retry with batches of at most 100, so no shared queue can be poisoned.

[Defeat: releaseSponsorProceeds] (1) An arbitrary caller cannot redirect the payment from the immutable recipient; (2) a recipient cannot reenter through canonical USDC delivery; (3) Mallory releases the 95-USDC sponsor claim before the blocked NFT winner receives anything. The third move amplifies the surviving delivery defect.

[Defeat: releaseSponsorPrize] (1) The prize contract reverts; (2) it lies about returned ownership; (3) the sponsor recipient cannot manage the received NFT. These affect the sponsor-selected asset and do not poison buyer refunds or cash payout, so they do not create a separate cross-user finding.

[Defeat: _isProtocolDestination] (1) Sending a ticket to the factory is rejected; (2) sending it to an already registered raffle is rejected; (3) sending it to the predictable address of the next undeployed raffle passes and becomes trapped after deployment. The third path requires the payer or authorized owner to strand its own claim, so it is excluded as self-harm.

[Defeat: _transferQuote] (1) A payout to a current protocol raffle is rejected; (2) a malicious recipient contract cannot invoke a receipt hook because canonical USDC has none; (3) a blocked cash winner can transfer the still-live ticket to another address before redemption. No shared USDC withdrawal is poisoned.

[LastOut: create/escrow] With a stable compliant prize, the raffle holds exactly one prize before accepting buyers. With a mutable hostile prize, the factory’s initial check cannot guarantee later delivery; this survives as the terminal-delivery finding.

[LastOut: buy/transfer] Ten sold entries produce exactly 10 USDC in the unallocated pot and ranges covering entries 1 through 10. Ticket transfers change no backing; the eventual last claimant remains fully funded.

[LastOut: successful draw] The native fee leaves for the trusted randomness service and excess returns in the same transaction. No USDC leaves; if no callback arrives, all 10 USDC can become refundable at the deadline.

[LastOut: settle/redeem NFT] For 10 entries, 9.5 USDC goes to the sponsor and 0.5 USDC to the treasury; both are fully payable in either order. With a compliant prize, the winner receives the NFT. With EvilNFT blocking line 334, the last claimant receives no prize and has no refund path: the shortfall is the entire promised NFT.

[LastOut: settle/redeem cash] For 10 entries, the cash winner receives 8 USDC, the sponsor 1.5 USDC, and the treasury 0.5 USDC. In every release order the last claimant receives the full amount; USDC shortfall is zero.

[LastOut: timeout/refund] Tickets covering 7, 2, and 1 entries can refund in that worst order: liability moves from 10 to 3 to 1 to 0 USDC. The final one-entry owner receives the full 1 USDC; shortfall is zero.

[LastOut: empty raffle] No USDC claimant exists. The sponsor recipient receives the prize after cancellation; with a compliant prize, the last asset leaves and nothing remains owed.

[LastOut: independent releases] Winner, sponsor, and treasury claims are fixed before any release. Paying any two first cannot consume the third’s backing; the final USDC claimant is paid in full.

FINDING | contract: Raffle | function: redeemWinningTicket | bug_class: permanent-prize-delivery-dos | group_key: Raffle | redeemWinningTicket | permanent-prize-delivery-dos
root_cause: Raffle.sol:334 in Raffle.redeemWinningTicket makes the sole NftWon exit depend on a sponsor-selected prize-contract call and omits a timeout transition from NftWon to Refunding when that call can never succeed.
internal_pre: A raffle using the attacker-controlled prize has sold 100 entries, totalEntries is at least reserveEntries, and the authenticated draw has set status to NftWon.
external_pre: The prize contract accepts the initial sponsor-to-raffle transfer but can later make every raffle-to-winner transfer permanently revert; honest buyers participate. No market, oracle, or chain condition is required.
path:
  1. Mallory deploys EvilNFT with token 1 and creates a raffle with reserveEntries = 1 and Mallory as sponsorRecipient; outbound transfers are initially enabled, so factory escrow succeeds.
  2. Alice and Bob collectively buy 100 entries for 100 USDC.
  3. Mallory irreversibly disables transfers whenever EvilNFT token 1 is sent from the raffle.
  4. After closing, the draw resolves NftWon because 100 entries exceed the reserve.
  5. Mallory calls settleWinningTicket with the winning ticket, allocating 95 USDC to Mallory and 5 USDC to the treasury, then releases both claims.
  6. The winning owner calls redeemWinningTicket; the call at line 334 reverts permanently. The ticket burn rolls back, but NftWon has no refund or alternate-delivery exit.
impact: For only deployment gas and an optional randomness fee, Mallory receives 95 USDC from an undeliverable raffle while the treasury receives 5 USDC. The entrants funded 100 USDC without any prize being delivered, and the winning-ticket owner is permanently left holding the failed prize claim; no ticket can obtain a refund.
mitigation: Keep all NftWon USDC proceeds unreleasable until prize delivery succeeds, and add a fixed post-resolution deadline that atomically moves the full untouched pot into remainingRefundLiability if delivery has not succeeded.

LEAD | contract: RaffleFactory | function: createRaffle | bug_class: self-attested-prize-escrow | group_key: RaffleFactory | createRaffle | self-attested-prize-escrow
smell: RaffleFactory.sol:128-132 treats a callback and ownerOf response controlled by the same sponsor-selected prize contract as proof of escrow.
unverified: Ownership of an arbitrary NFT exists only through that contract’s own state and answers, so no token-independent fact distinguishes forged custody from a genuine NFT; absent later non-delivery, a separate loss beyond the reported finding could not be established.
description: If factory registration is intended to attest prize authenticity rather than merely identify the selected contract, the protocol needs a vetted immutable prize-token policy.

COVERAGE | files: Raffle.sol—creation, sales, transfers, request/callback, settlement, both redemption branches, refunds, all releases, sink screening, and every prize/USDC call; RaffleFactory.sol—constructor assumptions, cloning, registry ordering, escrow, and parameter validation; IRaffle.sol—lifecycle, claim, deadline, and ABI promises; IRaffleFactory.sol—creation and registry ABI; RaffleConstants.sol—economic, timing, callback-gas, and batch bounds; DESIGN.md—money-map invariants and untrusted-boundary requirements.

COVERAGE | properties: USDC solvency and allocation conservation; worst-order last claimant; range coverage and refund batching; callback authentication and timeout recovery; reentrancy and batch poisoning; untrusted prize and recipient liveness; protocol-sink reachability; clone isolation; one-shot transitions; ingress/egress sibling saturation.