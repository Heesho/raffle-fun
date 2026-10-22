
Canonical groups and preserved content:

- G1 — `(RaffleFactory, createRaffle, fake-prize-escrow)`; key `rafflefactory|createraffle|fake-prize-escrow`. The labels had no majority, so the shortest defect label wins.
  - Members: agents 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 9.1, and 12.1.
  - Preserved mechanisms: a false token forges the initial callback and ownership report; it can reuse one alleged prize across raffles; it can later reject delivery or forge delivery and leave the burned-ticket owner without a usable NFT.
  - Preserved fix: a deployment-time, non-mutable allowlist of reviewed ERC-721 contracts with trusted ownership and transfer behavior.
  - Confidence: 90 = 100 − 10 for requiring a specific but achievable attacker-controlled prize contract.

- G2 — `(Raffle, releaseSponsorProceeds, payout-before-prize-delivery)`; key `raffle|releasesponsorproceeds|payout-before-prize-delivery`. This is the majority label.
  - Members: agents 1.1, 3.2, 4.2, 5.2, 6.2, 7.2, 9.2, 11.2, and 12.2.
  - Preserved mechanisms: a prize administrator pauses or changes transfer behavior after escrow; or an attacker-selected token intrinsically accepts the factory deposit but rejects every outbound transfer from the raffle.
  - Preserved fixes: require `winnerRedeemed` before sponsor payout; require it before both sponsor and protocol payout; or hold both payouts and open full refunds after a fixed delivery deadline.
  - The administrator-only variant BLOCKS at Gate 3 and is not a basis for the report. The intrinsic asymmetric-token variant survives because any unprivileged sponsor can select that behavior without a later privileged action.
  - Confidence: 90 = 100 − 10 for requiring a specific but achievable asymmetric prize contract.

- G3 — `(Raffle, settleWinningTicket, payout-before-prize-delivery)`; key `raffle|settlewinningticket|payout-before-prize-delivery`.
  - Member: agent 8.1.
  - Preserved mechanism: standalone settlement exposes sponsor and protocol claims before NFT delivery, unlike settlement rolled back inside a failed redemption.
  - Preserved fix: require `prizeClaimed` before the NFT-result claims can be released.

- G4 — `(Raffle, requestDraw, timestamp-downcast-deadline-rollover)`; key `raffle|requestdraw|timestamp-downcast-deadline-rollover`.
  - Member: agent 10.1.
  - Preserved mechanism: `uint64(block.timestamp)` becomes zero at `2^64`, which makes `callbackDeadline()` zero and immediately enables refunds.
  - No raw fix was supplied.

- G5 — `(Raffle, buyEntries, prize-custody-not-revalidated)`; key `raffle|buyentries|prize-custody-not-revalidated`.
  - Member: agent 11.1.
  - Preserved mechanism: the selected token administrator removes the prize after initial escrow and before a victim buys entries.
  - Preserved fix: verify current prize ownership before transferring the buyer’s USDC.

1. Agent 1, raw candidate 1
   - Raw: `(Raffle, releaseSponsorProceeds, premature-proceeds-release)`.
   - Canonical/key: `(Raffle, releaseSponsorProceeds, payout-before-prize-delivery)`; `raffle|releasesponsorproceeds|payout-before-prize-delivery`.
   - Duplicate/merge: G2; preserves both G2 mechanisms and all three fixes.
   - Gate 1: `ALLOWS` — settlement exposes the proceeds, release pays them, failed redemption rolls back only the redemption transaction, and `NftWon` blocks refunds.
   - Gate 2: `ALLOWS` — the factory accepts a caller-selected token that can accept escrow but reject outbound delivery.
   - Gate 3: `ALLOWS` — G2 survives through the intrinsic asymmetric-token path; this raw pause-based administrator variant separately `BLOCKS` and is excluded.
   - Gate 4: `ALLOWS` — buyers lose their payments and receive neither the NFT nor a refund while the sponsor receives 95%.
   - Final disposition: `FINDING`, merged into G2.
   - Confidence/deductions: 90; only the specific achievable token-state deduction applies.
   - Reason: the raw administrator action is not promoted, but the deduplicated defect has a complete unprivileged path.

2. Agent 2, raw candidate 1
   - Raw: `(RaffleFactory, createRaffle, forged-prize-escrow)`.
   - Canonical/key: `(RaffleFactory, createRaffle, fake-prize-escrow)`; `rafflefactory|createraffle|fake-prize-escrow`.
   - Duplicate/merge: G1; preserves forged escrow, rejected delivery, forged delivery, cross-raffle reuse, and the fixed allowlist.
   - Gate 1: `ALLOWS` — the false token controls every ERC-165, callback, `ownerOf`, and delivery response used by the checks.
   - Gate 2: `ALLOWS` — any contract that self-reports ERC-721 support can be selected under valid reserve and timing parameters.
   - Gate 3: `ALLOWS` — any unprivileged caller can deploy the token and call `createRaffle`.
   - Gate 4: `ALLOWS` — buyers fund a raffle with no enforceable prize while the sponsor receives 95% of sales.
   - Final disposition: `FINDING`, merged into G1.
   - Confidence/deductions: 90; −10 for the specific attacker-controlled token.
   - Reason: full source-supported exploit chain; no promotion or demotion.

3. Agent 3, raw candidate 1
   - Raw: `(RaffleFactory, createRaffle, untrusted-prize-token)`.
   - Canonical/key: `(RaffleFactory, createRaffle, fake-prize-escrow)`; `rafflefactory|createraffle|fake-prize-escrow`.
   - Duplicate/merge: G1; preserves all G1 mechanisms and its allowlist fix.
   - Gate 1: `ALLOWS` — false custody and ownership reports satisfy every factory and receiver check.
   - Gate 2: `ALLOWS` — the source permits an attacker-selected prize contract and reuse across separate clones.
   - Gate 3: `ALLOWS` — raffle creation and later settlement are available without a protocol role.
   - Gate 4: `ALLOWS` — repeated raffles can take material USDC from identifiable buyers.
   - Final disposition: `FINDING`, merged into G1.
   - Confidence/deductions: 90; −10 for the specific false token.
   - Reason: full path; canonicalized because its label is synonymous with G1.

4. Agent 3, raw candidate 2
   - Raw: `(Raffle, releaseSponsorProceeds, payout-before-prize-delivery)`.
   - Canonical/key: unchanged; `raffle|releasesponsorproceeds|payout-before-prize-delivery`.
   - Duplicate/merge: G2; preserves both mechanisms and all three fixes.
   - Gate 1: `ALLOWS` — no delivery-state check precedes the sponsor transfer.
   - Gate 2: `ALLOWS` — asymmetric prize behavior is accepted after the one initial custody check.
   - Gate 3: `ALLOWS` — the intrinsic asymmetric-token path needs no privileged transition; the raw mutable-token administrator variant is excluded.
   - Gate 4: `ALLOWS` — the winner loses payment and receives no NFT or refund.
   - Final disposition: `FINDING`, merged into G2.
   - Confidence/deductions: 90; −10 for the specific asymmetric token.
   - Reason: the merged group supplies the required unprivileged path.

5. Agent 4, raw candidate 1
   - Raw: `(RaffleFactory, createRaffle, untrusted-prize-attestation)`.
   - Canonical/key: `(RaffleFactory, createRaffle, fake-prize-escrow)`; `rafflefactory|createraffle|fake-prize-escrow`.
   - Duplicate/merge: G1; preserves all G1 mechanisms and its allowlist fix.
   - Gate 1: `ALLOWS` — the selected token can forge both the receiver callback and `ownerOf`.
   - Gate 2: `ALLOWS` — normal creation accepts that token when it reports ERC-721 support.
   - Gate 3: `ALLOWS` — the attacking sponsor needs no trusted factory role.
   - Gate 4: `ALLOWS` — buyers pay into an active raffle without a transferable prize.
   - Final disposition: `FINDING`, merged into G1.
   - Confidence/deductions: 90; −10 for the specific token.
   - Reason: full path; synonymous label canonicalized.

6. Agent 4, raw candidate 2
   - Raw: `(Raffle, releaseSponsorProceeds, pre-delivery-sponsor-payout)`.
   - Canonical/key: `(Raffle, releaseSponsorProceeds, payout-before-prize-delivery)`; `raffle|releasesponsorproceeds|payout-before-prize-delivery`.
   - Duplicate/merge: G2; preserves both mechanisms and all fixes.
   - Gate 1: `ALLOWS` — sponsor proceeds are transferable before `winnerRedeemed`.
   - Gate 2: `ALLOWS` — the source admits an intrinsically asymmetric token.
   - Gate 3: `ALLOWS` — G2 survives on the unprivileged token-selection path; this raw administrator-controlled block separately `BLOCKS`.
   - Gate 4: `ALLOWS` — the sponsor receives 95% while buyers retain an undeliverable claim.
   - Final disposition: `FINDING`, merged into G2.
   - Confidence/deductions: 90; −10 for the specific token.
   - Reason: the administrator-only mechanism is excluded rather than promoted.

7. Agent 5, raw candidate 1
   - Raw: `(RaffleFactory, createRaffle, fake-prize-escrow)`.
   - Canonical/key: unchanged; `rafflefactory|createraffle|fake-prize-escrow`.
   - Duplicate/merge: G1; preserves all G1 mechanisms and its allowlist fix.
   - Gate 1: `ALLOWS` — the false contract can activate the clone without transferring a token.
   - Gate 2: `ALLOWS` — no independent custody authority or prize allowlist exists.
   - Gate 3: `ALLOWS` — any sponsor can execute the path.
   - Gate 4: `ALLOWS` — buyers fund an absent-prize raffle and the sponsor obtains the sales allocation.
   - Final disposition: `FINDING`, merged into G1.
   - Confidence/deductions: 90; −10 for the specific false token.
   - Reason: full path; this raw label becomes the canonical label.

8. Agent 5, raw candidate 2
   - Raw: `(Raffle, releaseSponsorProceeds, premature-nft-proceeds-release)`.
   - Canonical/key: `(Raffle, releaseSponsorProceeds, payout-before-prize-delivery)`; `raffle|releasesponsorproceeds|payout-before-prize-delivery`.
   - Duplicate/merge: G2; preserves its later-transfer-refusal mechanism and its payout-gate plus refund-deadline fix.
   - Gate 1: `ALLOWS` — proceeds leave before delivery and no `NftWon` refund transition exists.
   - Gate 2: `ALLOWS` — a token can genuinely enter escrow yet reject the raffle’s outbound transfer.
   - Gate 3: `ALLOWS` — the merged intrinsic behavior needs no administrator action.
   - Gate 4: `ALLOWS` — buyers lose material USDC without receiving the prize.
   - Final disposition: `FINDING`, merged into G2.
   - Confidence/deductions: 90; −10 for the specific token.
   - Promotion reason: the raw lead is promoted because G2 contains a complete source-supported path and nine-agent convergence; the best merged proof supports 90 rather than the default promotion score of 75.

9. Agent 6, raw candidate 1
   - Raw: `(RaffleFactory, createRaffle, spoofed-erc721-escrow)`.
   - Canonical/key: `(RaffleFactory, createRaffle, fake-prize-escrow)`; `rafflefactory|createraffle|fake-prize-escrow`.
   - Duplicate/merge: G1; preserves all G1 mechanisms and its allowlist fix.
   - Gate 1: `ALLOWS` — the fake token supplies the exact expected callback fields and false ownership response.
   - Gate 2: `ALLOWS` — the token can be deployed and selected through normal factory use.
   - Gate 3: `ALLOWS` — the attacker needs no privileged protocol role.
   - Gate 4: `ALLOWS` — the winner loses the paid amount and cannot obtain a refund.
   - Final disposition: `FINDING`, merged into G1.
   - Confidence/deductions: 90; −10 for the specific fake token.
   - Reason: full path; synonymous label canonicalized.

10. Agent 6, raw candidate 2
   - Raw: `(Raffle, releaseSponsorProceeds, payout-before-prize-delivery)`.
   - Canonical/key: unchanged; `raffle|releasesponsorproceeds|payout-before-prize-delivery`.
   - Duplicate/merge: G2; preserves both mechanisms and all fixes.
   - Gate 1: `ALLOWS` — sponsor and protocol claims can leave before prize delivery.
   - Gate 2: `ALLOWS` — an asymmetric prize token is reachable through ordinary creation.
   - Gate 3: `ALLOWS` — the intrinsic-token path is unprivileged; this raw pause action separately `BLOCKS`.
   - Gate 4: `ALLOWS` — the winner receives neither the NFT nor the paid value.
   - Final disposition: `FINDING`, merged into G2.
   - Confidence/deductions: 90; −10 for the specific token.
   - Reason: the final finding does not rely on the administrator-only pause.

11. Agent 7, raw candidate 1
   - Raw: `(RaffleFactory, createRaffle, false-prize-ownership)`.
   - Canonical/key: `(RaffleFactory, createRaffle, fake-prize-escrow)`; `rafflefactory|createraffle|fake-prize-escrow`.
   - Duplicate/merge: G1; preserves the forged-delivery mechanism in addition to forged escrow and the allowlist fix.
   - Gate 1: `ALLOWS` — caller-dependent ownership reports pass the post-transfer checks and let redemption burn the ticket without a usable NFT.
   - Gate 2: `ALLOWS` — the factory accepts this caller-selected contract.
   - Gate 3: `ALLOWS` — an unprivileged sponsor deploys and selects it.
   - Gate 4: `ALLOWS` — the winner loses the purchase and the claim while the sponsor receives 95%.
   - Final disposition: `FINDING`, merged into G1.
   - Confidence/deductions: 90; −10 for the specific false token.
   - Reason: full path; its forged-delivery variant is retained in G1.

12. Agent 7, raw candidate 2
   - Raw: `(Raffle, releaseSponsorProceeds, sponsor-payout-before-prize-delivery)`.
   - Canonical/key: `(Raffle, releaseSponsorProceeds, payout-before-prize-delivery)`; `raffle|releasesponsorproceeds|payout-before-prize-delivery`.
   - Duplicate/merge: G2; supplies the surviving intrinsic-token mechanism and the sponsor-payout gate.
   - Gate 1: `ALLOWS` — a token can accept the factory deposit, reject every raffle-originated transfer, and leave the prior sponsor payout final.
   - Gate 2: `ALLOWS` — no source invariant requires outbound transferability after escrow.
   - Gate 3: `ALLOWS` — any sponsor can select a token with this fixed behavior; no later administrator call is required.
   - Gate 4: `ALLOWS` — buyers lose material funds and the winner cannot redeem or refund.
   - Final disposition: `FINDING`, merged into G2.
   - Confidence/deductions: 90; −10 for the specific asymmetric token.
   - Reason: this raw candidate supplies G2’s complete unprivileged path.

13. Agent 8, raw candidate 1
   - Raw: `(Raffle, settleWinningTicket, payout-before-prize-delivery)`.
   - Canonical/key: unchanged; `raffle|settlewinningticket|payout-before-prize-delivery`.
   - Duplicate/merge: singleton G3; preserves the standalone-versus-inline settlement asymmetry and `prizeClaimed` fix. It cannot merge with G2 because the functions differ.
   - Gate 1: `ALLOWS` — standalone settlement persists the claims before the later release and failed redemption.
   - Gate 2: `ALLOWS` — an `NftWon` state with a pausable prize is reachable.
   - Gate 3: `BLOCKS` — the only raw trigger is the sponsor’s privileged pause, and no unprivileged amplifier is named.
   - Gate 4: `IRRELEVANT` — not evaluated after Gate 3 blocks.
   - Final disposition: `REJECTED`.
   - Rejection reason: the strict administrator-action rule forbids even a lead for this path.

14. Agent 9, raw candidate 1
   - Raw: `(RaffleFactory, createRaffle, fake-erc721-escrow)`.
   - Canonical/key: `(RaffleFactory, createRaffle, fake-prize-escrow)`; `rafflefactory|createraffle|fake-prize-escrow`.
   - Duplicate/merge: G1; preserves all G1 mechanisms and its allowlist fix.
   - Gate 1: `ALLOWS` — the selected token fabricates all evidence used to activate the clone.
   - Gate 2: `ALLOWS` — the factory accepts that dependency through normal creation.
   - Gate 3: `ALLOWS` — the sponsor is an unprivileged factory caller.
   - Gate 4: `ALLOWS` — buyers pay for an NFT that cannot be delivered.
   - Final disposition: `FINDING`, merged into G1.
   - Confidence/deductions: 90; −10 for the specific fake token.
   - Reason: full path; synonymous label canonicalized.

15. Agent 9, raw candidate 2
   - Raw: `(Raffle, releaseSponsorProceeds, payout-before-prize-delivery)`.
   - Canonical/key: unchanged; `raffle|releasesponsorproceeds|payout-before-prize-delivery`.
   - Duplicate/merge: G2; preserves both mechanisms and all fixes.
   - Gate 1: `ALLOWS` — payout precedes the only delivery attempt, and `NftWon` has no refund branch.
   - Gate 2: `ALLOWS` — intrinsic asymmetric prize behavior is reachable.
   - Gate 3: `ALLOWS` — the surviving path needs only unprivileged token selection; the raw pause or upgrade variant separately `BLOCKS`.
   - Gate 4: `ALLOWS` — the sponsor receives 95% while the winner has no delivered prize or refund.
   - Final disposition: `FINDING`, merged into G2.
   - Confidence/deductions: 90; −10 for the specific token.
   - Reason: the administrator-only variant is excluded from the report’s proof.

16. Agent 10, raw candidate 1
   - Raw: `(Raffle, requestDraw, timestamp-downcast-deadline-rollover)`.
   - Canonical/key: unchanged; `raffle|requestdraw|timestamp-downcast-deadline-rollover`.
   - Duplicate/merge: singleton G4; preserves the downcast mechanism; no fix was supplied.
   - Gate 1: `ALLOWS` — at timestamp `2^64`, the cast stores zero and the subsequent refund deadline check permits immediate refunds.
   - Gate 2: `BLOCKS` — the required timestamp is about 584 billion years away, so the bundle shows no reachable live-deployment state.
   - Gate 3: `IRRELEVANT` — not evaluated after Gate 2 blocks.
   - Gate 4: `IRRELEVANT` — not evaluated after Gate 2 blocks.
   - Final disposition: `REJECTED`.
   - Rejection reason: the pinned rules exclude implausible preconditions; it is not retained as a lead.

17. Agent 11, raw candidate 1
   - Raw: `(Raffle, buyEntries, prize-custody-not-revalidated)`.
   - Canonical/key: unchanged; `raffle|buyentries|prize-custody-not-revalidated`.
   - Duplicate/merge: singleton G5; preserves the post-escrow removal mechanism and pre-payment ownership-check fix.
   - Gate 1: `ALLOWS` — `buyEntries` transfers USDC without checking current prize ownership, so later redemption can fail.
   - Gate 2: `ALLOWS` — a selected ERC-721 with an administrator transfer function can reach this state.
   - Gate 3: `BLOCKS` — the path requires the token administrator to remove the prize, and no unprivileged amplifier is named.
   - Gate 4: `IRRELEVANT` — not evaluated after Gate 3 blocks.
   - Final disposition: `REJECTED`.
   - Rejection reason: the strict administrator-action rule forbids demotion to a lead.

18. Agent 11, raw candidate 2
   - Raw: `(Raffle, releaseSponsorProceeds, proceeds-before-prize-delivery)`.
   - Canonical/key: `(Raffle, releaseSponsorProceeds, payout-before-prize-delivery)`; `raffle|releasesponsorproceeds|payout-before-prize-delivery`.
   - Duplicate/merge: G2; preserves both mechanisms and all fixes.
   - Gate 1: `ALLOWS` — settlement and release complete before the delivery call.
   - Gate 2: `ALLOWS` — an intrinsically asymmetric prize is source-reachable.
   - Gate 3: `ALLOWS` — the merged intrinsic-token path is unprivileged; this raw pause action separately `BLOCKS`.
   - Gate 4: `ALLOWS` — buyers lose the sale value and cannot redeem or refund.
   - Final disposition: `FINDING`, merged into G2.
   - Confidence/deductions: 90; −10 for the specific token.
   - Reason: the final proof excludes the raw administrator-only trigger.

19. Agent 12, raw candidate 1
   - Raw: `(RaffleFactory, createRaffle, prize-self-attestation)`.
   - Canonical/key: `(RaffleFactory, createRaffle, fake-prize-escrow)`; `rafflefactory|createraffle|fake-prize-escrow`.
   - Duplicate/merge: G1; preserves both forged escrow and forged delivery plus the allowlist fix.
   - Gate 1: `ALLOWS` — one token controls the initial and final transfer attestations, so both checks can pass without a transferable NFT.
   - Gate 2: `ALLOWS` — normal factory parameters can select that token.
   - Gate 3: `ALLOWS` — any caller can create the raffle and supply the false token.
   - Gate 4: `ALLOWS` — the ticket is burned, the sponsor receives 95%, and the winner has no transferable prize.
   - Final disposition: `FINDING`, merged into G1.
   - Confidence/deductions: 90; −10 for the specific token.
   - Reason: full path; the forged-delivery mechanism remains explicit in G1.

20. Agent 12, raw candidate 2
   - Raw: `(Raffle, releaseSponsorProceeds, payout-before-prize-delivery)`.
   - Canonical/key: unchanged; `raffle|releasesponsorproceeds|payout-before-prize-delivery`.
   - Duplicate/merge: G2; preserves both mechanisms and all fixes.
   - Gate 1: `ALLOWS` — the sponsor transfer persists before the later failed prize call.
   - Gate 2: `ALLOWS` — a token that accepts escrow and rejects delivery is reachable.
   - Gate 3: `ALLOWS` — G2’s intrinsic-token path is unprivileged; this raw pause action separately `BLOCKS`.
   - Gate 4: `ALLOWS` — the winner receives neither the NFT nor a refund after material buyer payments.
   - Final disposition: `FINDING`, merged into G2.
   - Confidence/deductions: 90; −10 for the specific token.
   - Reason: the final finding relies only on the surviving unprivileged mechanism.

Function-level second pass: G1 retains forged escrow, rejected delivery, forged delivery, and cross-raffle reuse. G2 retains every payout and refund fix, while its administrator-only mechanism is recorded but excluded. G3 remains separate from G2 because `settleWinningTicket` and `releaseSponsorProceeds` are different functions. No composite chain adds impact beyond the surviving individual findings.

Completeness: 5 unique (Contract, function) in raw, 5 covered in final.

