# Native adjudication record

Completeness: 8 unique (Contract, function) in raw, 8 covered in final.

Raw inventory: 16 `FINDING` blocks and 3 `LEAD` blocks, deduplicated into 9 candidates.

## Composite-chain check

J-1/J-2 let a sponsor activate a raffle with counterfeit or revocable prize collateral. J-5 then converts buyer USDC into immediately releasable sponsor and treasury claims before delivery, J-8 permits those claims to leave, and J-6 leaves the winning owner in terminal `NftWon` with no refund escape when delivery fails. This combined chain crosses the untrusted-prize boundary into buyer funds and is supported by the bundled source; each contributing root remains separate because it occurs in a different function.

## Candidate J-1 — `RaffleFactory::_validateCreateParams()` admits self-attested or revocable prize code [lenses: 6]

Raw members: FINDING [lens 2] `RaffleFactory | _validateCreateParams | revocable-prize-escrow`; FINDING [lens 4] `RaffleFactory | _validateCreateParams | untrusted-prize-authentication`; FINDING [lens 7] `RaffleFactory | _validateCreateParams | revocable-prize-custody`; FINDING [lens 9] `RaffleFactory | _validateCreateParams | untrusted-prize-authentication`; FINDING [lens 10] `RaffleFactory | _validateCreateParams | untrusted-prize-seizure`; FINDING [lens 11] `RaffleFactory | _validateCreateParams | untrusted-prize-attestation`.

Dedup/mechanisms/mitigations: The exact `untrusted-prize-authentication` key from lenses 4 and 9 was collapsed first; the remaining synonymous keys were merged within this function. At `RaffleFactory.sol:172`, ERC-165 support is supplied by the candidate token itself. Preserved mechanisms are: fabricated interface support; genuine initial escrow followed by administrator seizure; transfer pause or denylisting; and post-sale implementation upgrade. Each path proceeds through buyer purchases, `NftWon`, settlement, and failed or fabricated delivery. Preserved mitigation—trusted-code admission: “In `_validateCreateParams`, require `params.prizeToken` to belong to an immutable, pre-vetted prize-token allowlist or match an approved code identity; do not treat `supportsInterface`, receiver callbacks, or `ownerOf` reports from an arbitrary prize contract as custody proof.” Approval must exclude upgradeable or privileged pause, burn, seizure, and transfer implementations.

Gate 1 — ALLOWS — `_requireContract` and the line-172 `supportsInterface` query check code presence and a self-reported interface but do not authenticate code identity, immutability, or custody powers.
Gate 2 — ALLOWS — any sponsor can deploy or select such a token and create the malicious raffle from an empty protocol state at ordinary deployment and draw cost.
Gate 3 — ALLOWS — Alice and the other ticket purchasers are non-attacker victims whose USDC finances the sponsor claim.
Gate 4 — ALLOWS — the sponsor can retain or disable the prize while extracting 95% of sales, leaving the winner without the prize or a refund.
Disposition: ACCEPT FINDING — High; the complete source-supported path exists independently of lens count.

## Candidate J-2 — `RaffleFactory::createRaffle()` treats token-supplied assertions as escrow proof [lenses: 5]

Raw members: FINDING [lens 1] `RaffleFactory | createRaffle | untrusted-erc721-custody`; FINDING [lens 3] `RaffleFactory | createRaffle | untrusted-prize-self-attestation`; FINDING [lens 5] `RaffleFactory | createRaffle | untrusted-prize-custody`; LEAD [lens 8] `RaffleFactory | createRaffle | self-attested-prize-escrow`; FINDING [lens 12] `RaffleFactory | createRaffle | counterfeit-prize-escrow`.

Dedup/mechanisms/mitigations: All five synonymous escrow classes were merged within `createRaffle`. At `RaffleFactory.sol:128-132`, especially line 129, the same sponsor-selected token controls `safeTransferFrom`, the receiver callback, and `ownerOf`. Preserved paths are: a counterfeit token fabricates the callback and reported owner without creating an enforceable asset; or a real token passes the point-in-time check and is later force-transferred or disabled. Buyers then fund the active raffle, sponsor and treasury claims are released, and the winner receives no usable prize. Preserved mitigation—authenticated prize code: “Restrict `params.prizeToken` during creation to an immutable allowlist or trusted registry of reviewed, non-upgradeable ERC-721 implementations; ERC-165, receiver callbacks, and `ownerOf` reported by arbitrary prize code cannot authenticate that code.”

Gate 1 — ALLOWS — the exact receiver fields, `ownerOf` result, and `Active` status can all be manufactured by the configured token, and the one-time check does not establish durable custody.
Gate 2 — ALLOWS — a malicious sponsor can deploy the counterfeit token, invoke creation normally, and attract ordinary entry purchases.
Gate 3 — ALLOWS — Alice, Bob, and the selected winning-ticket owner fund the raffle while the sponsor controls the purported collateral.
Gate 4 — ALLOWS — buyer USDC is distributed while the winner’s ticket is burned or left unredeemable without an enforceable NFT.
Disposition: ACCEPT FINDING — High; the raw lead is promoted because the bundled source supplies the complete counterfeit-escrow and victim-loss path.

## Candidate J-3 — `Raffle::_update()` permits transfers around a pending VRF reveal [lenses: 1]

Raw members: FINDING [lens 7] `Raffle | _update | vrf-reveal-front-running`.

Dedup/mechanisms/mitigations: No duplicate existed. At `Raffle.sol:498`, holder-to-holder transfers remain possible in `Drawing`, `NftWon`, and `CashWon`. The proposed path requires a pending fulfillment whose word can be observed or simulated, an external executable fixed-price order, and ordering the order fill before fulfillment. Preserved mitigation: “In `_update`, reject holder-to-holder transfers while status is `Drawing`, `NftWon`, or `CashWon`, while continuing to permit protocol burns.”

Gate 1 — ALLOWS — `_update` screens protocol destinations but has no lifecycle transfer lock before or after the winning entry becomes transaction-ordering information.
Gate 2 — UNCERTAIN — exploitation requires an external signed order plus visibility and ordering of the pending fulfillment, none of which is established by bundled source.
Gate 3 — ALLOWS — if those external conditions hold, Alice is the named stale-order seller whose winning claim is purchased at the stale price.
Gate 4 — ALLOWS — under that assumed path, the price-to-prize spread is real transferable value rather than informational harm.
Disposition: RETAIN LEAD — the in-scope source proves transferability but not the marketplace order or callback-observation path needed for exploitation.

## Candidate J-4 — `Raffle::_isProtocolDestination()` omits foreign and future clones [lenses: 1]

Raw members: LEAD [lens 9] `Raffle | _isProtocolDestination | incomplete-protocol-destination-detection`.

Dedup/mechanisms/mitigations: No duplicate existed. `Raffle.sol:603` consults only the canonical factory registry, and `RaffleFactory.sol:159` likewise recognizes only current same-factory raffles. A foreign-factory clone or predicted code-less future clone can therefore receive a ticket or be selected as a configured destination. No raw mitigation was supplied.

Gate 1 — ALLOWS — foreign-factory clones and not-yet-deployed addresses are not matched by the current factory’s registry or code-length branch.
Gate 2 — BLOCKS — the bundle establishes no path for an attacker to choose that destination for somebody else’s ticket without the owner’s authorization.
Gate 3 — BLOCKS — the demonstrated loss falls on the owner or sponsor who deliberately selected the destination, not a named non-attacker victim.
Gate 4 — UNCERTAIN — a claim may become unusable, but the source does not establish permanent loss for an involuntary claimant.
Disposition: REJECT — the only concrete paths are authorized self-harm, and Gates 2 and 3 block the candidate.

## Candidate J-5 — `Raffle::_settleWinningTicket()` creates payable NFT-result claims before prize delivery [lenses: 1]

Raw members: FINDING [lens 4] `Raffle | _settleWinningTicket | premature-proceeds-release`.

Dedup/mechanisms/mitigations: No duplicate existed. At `Raffle.sol:554`, an `NftWon` settlement credits sponsor and treasury liabilities before attempting prize delivery. With a genuinely deposited but pausable or seizable prize, a keeper can settle after delivery is disabled; the downstream release functions then empty the USDC while the winning transfer fails. Preserved mitigation—release gating: “In `NftWon`, make both sponsor proceeds and protocol fees unreleasable until `winnerRedeemed` confirms a successful NFT transfer; failed delivery must leave the sale pot unavailable to the sponsor.”

Gate 1 — ALLOWS — settlement checks status, range membership, and one-shot completion but neither current prize custody nor successful winner delivery before creating releasable claims.
Gate 2 — ALLOWS — an admitted prize sponsor can genuinely escrow its token and later activate a transfer pause, seizure, denylist, or upgrade before settlement.
Gate 3 — ALLOWS — Alice as winning owner and the entrant cohort are left without either the advertised NFT or ticket refunds.
Gate 4 — ALLOWS — the complete entry pot can become externally payable despite failure of the consideration backing the NFT outcome.
Disposition: ACCEPT FINDING — High; this candidate supplies the monetary-allocation step of the complete composite chain.

## Candidate J-6 — `Raffle::redeemWinningTicket()` has no recovery from permanent prize-transfer failure [lenses: 1]

Raw members: FINDING [lens 8] `Raffle | redeemWinningTicket | permanent-prize-delivery-dos`.

Dedup/mechanisms/mitigations: No duplicate existed. At `Raffle.sol:334`, the sole `NftWon` exit depends on the sponsor-selected prize accepting an outbound transfer. A token can accept genuine inbound escrow and later make every raffle-to-winner transfer revert. Transaction rollback preserves the ticket, but `NftWon` has no delivery deadline or transition to `Refunding`; settlement and releases remain independently available. Preserved mitigation: “Keep all `NftWon` USDC proceeds unreleasable until prize delivery succeeds, and add a fixed post-resolution deadline that atomically moves the full untouched pot into `remainingRefundLiability` if delivery has not succeeded.”

Gate 1 — ALLOWS — transfer failure reverts redemption, but no source path changes terminal `NftWon` into a refundable state after repeated or permanent failure.
Gate 2 — ALLOWS — the sponsor can deploy a token that permits the initial transfer and permanently rejects transfers whose sender is the raffle.
Gate 3 — ALLOWS — the selected winning-ticket owner and all paying entrants are non-attacker victims of the undeliverable outcome.
Gate 4 — ALLOWS — the prize claim is permanently unusable and no ticket can recover its purchase price while sponsor proceeds may leave.
Disposition: ACCEPT FINDING — High; the bundled source supplies the complete permanent-failure and named-victim path.

## Candidate J-7 — `Raffle::redeemWinningTicket()` omits contract-recipient acknowledgement [lenses: 1]

Raw members: LEAD [lens 12] `Raffle | redeemWinningTicket | unsafe-contract-nft-delivery`.

Dedup/mechanisms/mitigations: No duplicate existed. `Raffle.sol:334` and sibling `Raffle.sol:404` use `transferFrom`, so a contract winner or sponsor recipient receives no ERC-721 receiver callback before reported ownership finalizes delivery. The proposed path requires a recipient implementation that accepts raffle tickets but cannot recognize or recover arbitrary NFTs without its hook. No raw mitigation was supplied.

Gate 1 — ALLOWS — `transferFrom` omits receiver acknowledgement and the subsequent `ownerOf` comparison proves nominal ownership only.
Gate 2 — UNCERTAIN — no bundled recipient implementation establishes that a contract able to own and redeem a ticket cannot later transfer or recover the prize.
Gate 3 — UNCERTAIN — a downstream contract beneficiary could be harmed, but no concrete non-attacker beneficiary is established in scope.
Gate 4 — UNCERTAIN — absence of the hook may cause accounting failure, or it may leave a fully recoverable NFT owned by the contract.
Disposition: RETAIN LEAD — the source proves the integration smell but not permanent loss or a concrete victim.

## Candidate J-8 — `Raffle::releaseSponsorProceeds()` pays before successful NFT delivery [lenses: 2]

Raw members: FINDING [lens 3] `Raffle | releaseSponsorProceeds | payout-before-prize-delivery`; FINDING [lens 9] `Raffle | releaseSponsorProceeds | premature-nft-proceeds-release`.

Dedup/mechanisms/mitigations: The synonymous keys were merged within `releaseSponsorProceeds`. At `Raffle.sol:376`, the function requires only a nonzero claim; it does not require `winnerRedeemed`, successful prize delivery, or continuing custody. Its sibling protocol-fee release has the same missing delivery-success gate. The preserved path genuinely escrows a switchable prize, sells entries, disables outbound transfers, settles `NftWon`, releases 95% plus the fee, and leaves the winner without a prize or refund. Preserved mitigation: “In `NftWon`, require `winnerRedeemed` before releasing either sponsor proceeds or protocol fees.”

Gate 1 — ALLOWS — the release path clears and transfers the sponsor claim without checking status-specific prize completion; the treasury release is equally independent.
Gate 2 — ALLOWS — the malicious sponsor controls the prize’s post-escrow transfer state and can directly or permissionlessly trigger release.
Gate 3 — ALLOWS — Alice and the other entrants are named victims financing proceeds for an undelivered prize.
Gate 4 — ALLOWS — 95% of the pot, and eventually 100% with fees, can leave before the only promised NFT transfer succeeds.
Disposition: ACCEPT FINDING — High; the complete path is present in source, and `[lenses: 2]` is attention metadata rather than proof.

## Candidate J-9 — `Raffle::_transferQuote()` cannot recover from canonical-USDC sender blacklisting [lenses: 1]

Raw members: FINDING [lens 10] `Raffle | _transferQuote | freezable-usdc-payout-lock`.

Dedup/mechanisms/mitigations: No duplicate existed. At `Raffle.sol:566`, every quote claim ultimately requires an outgoing transfer from the clone. The proposed path requires the external USDC administrator to blacklist the clone, after which refunds and releases revert atomically. Preserved mitigation: “If unconditional onchain collectability is required, use a non-freezable quote asset; no raffle-side fallback can move USDC after Circle has blacklisted the sender.”

Gate 1 — ALLOWS — the raffle has no alternate payout asset or migration path if the immutable quote token rejects every transfer from the clone.
Gate 2 — BLOCKS — the required state change belongs to the trusted canonical token’s privileged blacklister, not an attacker-reachable operation established by bundled source.
Gate 3 — ALLOWS — if that privileged external event occurred, Alice, Bob, and other claimants would be unable to collect.
Gate 4 — ALLOWS — their backed balances would remain frozen and inaccessible for the duration of the blacklist.
Disposition: REJECT — Gate 2 blocks the candidate under the explicit trusted-canonical-USDC model, and the bundle does not supply the external token implementation as independent source proof.

# Security Review — raffle.fun

**Scope:** 5 production files, 5 Solidity units (2 deployable contracts, 2 interfaces, 1 library)  
**Method:** accounting-first review across 12 attack lenses  
**Findings:** 5 High · 0 Medium · 0 Low · 0 Info

A sponsor supplies one advertised ERC-721 prize, while buyers pay one canonical-USDC unit per entry and receive transferable tickets covering contiguous entry ranges. Authenticated randomness selects one entry; settlement then allocates the exact USDC pot as 95/5 for an NFT result or 80/15/5 for a cash result. The quote-token accounting, range coverage, percentage allocation, and refund arithmetic conserve value under the declared canonical-USDC model. The material failure is instead at the prize boundary: sponsor-selected code is accepted as its own evidence of custody and can disable delivery while sponsor and treasury proceeds become independently payable. This is a sealed source adjudication; no proof or reproduction test was run.

## Systemic observations

Prize admission, escrow verification, settlement, redemption, and proceeds release all assume more trustworthy behavior than the stated untrusted-prize boundary provides. The findings below keep separate function-level root causes: admission permits hostile code, creation accepts self-attested custody, settlement creates claims before delivery, redemption lacks a failure escape, and release pays those claims without delivery confirmation. Lens counts indicate attention only and did not establish or promote any finding.

## H-1. `RaffleFactory::_validateCreateParams()` trusts self-reported ERC-721 support, allowing sponsors to revoke prize collateral after buyers fund the raffle [lenses: 6]

**Description:**

[`target/packages/contracts/src/RaffleFactory.sol:172`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO-continuation/target/packages/contracts/src/RaffleFactory.sol:172) accepts a sponsor-selected token because that same token reports ERC-721 interface support. It does not authenticate a reviewed implementation or exclude upgrade, pause, burn, denylist, or administrator-seizure powers.

Mallory can genuinely escrow a token, let Alice and other entrants fund the raffle, then seize or disable that token before an ordinary `NftWon` resolution. Settlement and releases distribute the buyers’ USDC while the winner cannot receive the advertised NFT or obtain a refund.

**Recommended Mitigation:**

Require `params.prizeToken` to belong to an immutable, pre-vetted collection set or match an approved code identity. The approval mechanism must not query the candidate token as its source of truth and must exclude upgradeable or privileged-transfer implementations.

```diff
 function _validateCreateParams(CreateRaffleParams calldata params) private view {
+    if (!_approvedPrizeCode(params.prizeToken)) {
+        revert UnsupportedPrizeToken(params.prizeToken);
+    }
     _requireContract(params.prizeToken);
     ...
 }
```

**Fix review:**

## H-2. `RaffleFactory::createRaffle()` treats `ownerOf()` as independent escrow proof, allowing phantom prizes to back paid entries [lenses: 5]

**Description:**

[`target/packages/contracts/src/RaffleFactory.sol:129`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO-continuation/target/packages/contracts/src/RaffleFactory.sol:129) asks the sponsor-selected prize contract whether the new clone owns the prize. That contract also controls the preceding transfer and receiver callback, so the check is not independent evidence of custody.

A counterfeit token can report ERC-721 support, invoke `onERC721Received` with the expected fields without creating an enforceable token, and return the clone from `ownerOf`. After Alice and Bob fund the resulting `Active` raffle, it can similarly fabricate winner ownership or reject delivery while Mallory extracts the sponsor proceeds.

**Recommended Mitigation:**

Enforce an immutable trusted-prize or approved-code policy before cloning or making any prize call. Keep `ownerOf` only as a consistency check for an already authenticated implementation.

```diff
 function createRaffle(CreateRaffleParams calldata params)
     external
     nonReentrant
     returns (address raffle)
 {
+    _requireApprovedPrizeCode(params.prizeToken);
     _validateCreateParams(params);
     ...
 }
```

**Fix review:**

## H-3. `Raffle::_settleWinningTicket()` allocates NFT-sale proceeds before prize delivery, making an undelivered raffle payable [lenses: 1]

**Description:**

[`target/packages/contracts/src/Raffle.sol:554`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO-continuation/target/packages/contracts/src/Raffle.sol:554) credits `sponsorProceeds` and `protocolFees` as soon as the winning range is proven. An `NftWon` settlement neither verifies continuing custody nor waits for successful prize delivery.

A pausable or seizable prize can therefore be disabled before settlement. The resulting claims can empty the USDC pot even though Alice’s winning redemption permanently fails and no refund transition exists.

**Recommended Mitigation (Option A — reorder allocation):**

For `NftWon`, retain the gross pot as pending until `redeemWinningTicket()` successfully transfers and verifies the prize. Only then allocate sponsor and treasury claims.

**Recommended Mitigation (Option B — gate releases):**

In `NftWon`, make both sponsor proceeds and protocol fees unreleasable until `winnerRedeemed` confirms successful NFT delivery.

```diff
 function releaseSponsorProceeds() external nonReentrant returns (uint256 amount) {
+    if (status == Status.NftWon && !winnerRedeemed) revert PrizeDeliveryPending();
     ...
 }

 function releaseProtocolFees() external nonReentrant returns (uint256 amount) {
+    if (status == Status.NftWon && !winnerRedeemed) revert PrizeDeliveryPending();
     ...
 }
```

**Fix review:**

## H-4. `Raffle::redeemWinningTicket()` has no failed-delivery timeout, permanently trapping the winner in `NftWon` [lenses: 1]

**Description:**

[`target/packages/contracts/src/Raffle.sol:334`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO-continuation/target/packages/contracts/src/Raffle.sol:334) makes the sole `NftWon` exit depend on the sponsor-selected prize contract accepting an outbound transfer. A revert restores the ticket and redemption flags, but the terminal status has no timeout, alternate delivery, or transition to ticket refunds.

Mallory can use a token that accepts initial escrow and later rejects every transfer from the raffle. The winner then retains a permanently unusable ticket, all losing tickets remain non-refundable, and the independently allocated sponsor and treasury claims can still leave.

**Recommended Mitigation:**

Keep all `NftWon` USDC proceeds unreleasable until delivery succeeds. Add a fixed post-resolution deadline that, if `winnerRedeemed` remains false, atomically clears the sponsor and treasury allocations, restores the complete pot as `remainingRefundLiability`, and changes status to `Refunding`.

```diff
+function enableNftDeliveryRefunds() external nonReentrant {
+    if (status != Status.NftWon || winnerRedeemed) revert InvalidStatus(status);
+    if (block.timestamp < uint256(resolvedAt) + NFT_DELIVERY_TIMEOUT) {
+        revert RefundsNotAvailable(
+            uint256(resolvedAt) + NFT_DELIVERY_TIMEOUT,
+            block.timestamp
+        );
+    }
+
+    uint256 liability = sponsorProceeds + protocolFees;
+    sponsorProceeds = 0;
+    protocolFees = 0;
+    remainingRefundLiability = liability;
+    status = Status.Refunding;
+}
```

**Fix review:**

## H-5. `Raffle::releaseSponsorProceeds()` pays the sponsor before NFT delivery, allowing 95% of entrant funds to leave [lenses: 2]

**Description:**

[`target/packages/contracts/src/Raffle.sol:376`](/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/cells/DAYBREAK-SIMAO-continuation/target/packages/contracts/src/Raffle.sol:376) releases any nonzero sponsor claim without requiring `winnerRedeemed`. `releaseProtocolFees()` has the same missing delivery-success condition.

After genuinely escrowing a switchable prize, Mallory can disable outbound transfers, let the raffle settle `NftWon`, and collect 95% of the entry pot before Alice attempts redemption. Alice receives neither the NFT nor a refund; the remaining fee can also be released.

**Recommended Mitigation:**

In `NftWon`, require `winnerRedeemed` before releasing either sponsor proceeds or protocol fees.

```diff
 function releaseSponsorProceeds() external nonReentrant returns (uint256 amount) {
+    if (status == Status.NftWon && !winnerRedeemed) revert PrizeDeliveryPending();
     ...
 }

 function releaseProtocolFees() external nonReentrant returns (uint256 amount) {
+    if (status == Status.NftWon && !winnerRedeemed) revert PrizeDeliveryPending();
     ...
 }
```

**Fix review:**

## Unverified leads

- `Raffle::_update()` — tickets remain transferable around a pending VRF reveal — the bundle does not establish an executable external order or that the fulfillment can be observed and ordered against before inclusion. [lenses: 1]
- `Raffle::redeemWinningTicket()` — `transferFrom` omits contract-recipient acknowledgement — no in-scope recipient proves that the nominally received NFT would be unrecoverable or that a non-attacker beneficiary would lose value. [lenses: 1]

# Coverage

## Per-file coverage

| File | Coverage |
| --- | --- |
| `target/packages/contracts/src/Raffle.sol` | Initialization, prize receipt, purchases, range minting and transfers, draw request and callback, both timeout transitions, settlement, both redemption branches, refunds, sponsor/treasury/prize releases, quote transfers, sink checks, reentrancy, exact deadlines, and all tracked-liability writes. |
| `target/packages/contracts/src/RaffleFactory.sol` | Constructor validation, immutable dependency binding, implementation deployment, clone creation, initialization and registry ordering, prize admission, receiver interaction, escrow verification, external-call rollback, and reentrancy. |
| `target/packages/contracts/src/interfaces/IRaffle.sol` | Lifecycle, bearer-claim, ownership, deadline, payout, event, error, getter, and documented token-assumption semantics matched against implementation behavior. |
| `target/packages/contracts/src/interfaces/IRaffleFactory.sol` | Creation parameters, immutable configuration, registry promises, errors, events, and implementation consistency. |
| `target/packages/contracts/src/libraries/RaffleConstants.sol` | Entry price, six-decimal scale, 95/5 and 80/15/5 splits, basis-point rounding, sale duration, request and callback windows, refund batch bound, gas limit, confirmations, and maximum arithmetic. |
| `target/DESIGN.md` | Asset custody, exact allocation, full-refund behavior, one-shot lifecycle, permissionless settlement, claim independence, clone isolation, explicit untrusted-prize boundary, and trusted canonical dependencies. |

## Per-property coverage

| Property | Result |
| --- | --- |
| Assets and solvency | Canonical-USDC accounting conserves all recorded liabilities; NFT backing fails across admission, escrow, pre-delivery allocation, release, and terminal recovery as reported. |
| Ticket-range coverage and ownership | Purchases create contiguous, non-overlapping ranges covering `[1,totalEntries]`; winning proof and refund value use the stored range; redemption follows current ownership. |
| Initialization and clone binding | Implementation is locked, clones initialize once through the immutable factory, and failed creation rolls back count and registry writes. |
| Authorization | Ticket redemption and refunds require current ownership; settlement and releases are intentionally permissionless but pay fixed recipients. |
| Lifecycle and timing boundaries | Sale, request, callback, and refund boundaries are mutually exclusive at exact timestamps; the missing post-`NftWon` delivery-failure transition is reported. |
| VRF request and callback | Fee handling, in-flight suppression, wrapper authentication, request-ID matching, word-count checking, duplicate handling, and callback deadline were covered; reveal-ordering remains an unverified lead. |
| Settlement, split, and rounding | 95/5 and 80/15/5 allocations sum exactly to the gross pot; sponsor receives any remainder; premature NFT-result allocation is reported. |
| Refund, liveness, and Last User Out | Refund liability equals all live ticket values, bounded batches preserve atomicity, and the final refund claimant is fully paid under the declared quote-token model. |
| NFT custody and adversarial prize behavior | Fabricated callbacks, false `ownerOf`, privileged seizure, pause, denylist, upgrade, no-op delivery, reverting delivery, and both prize exits were saturated. |
| Canonical USDC behavior | Fee-free, non-rebasing transfer accounting and rollback were checked under the explicitly trusted canonical-token model. |
| Reentrancy and external calls | Factory and raffle economic functions use shared guards; failed ticket receipt, wrapper interaction, quote transfer, and prize transfer revert their preceding state changes atomically. |
| Cross-clone isolation | Same-factory raffles, implementation, factory, quote token, wrapper, and configured prize are screened as destinations; no accepted involuntary cross-clone exploit survived adjudication. |
| Edge states, DoS, and ordering | Zero/one/maximum entries, ticket zero, 100/101 refund batches, duplicate IDs, exact reserve boundaries, exact deadlines, repeated terminal calls, payout permutations, and permanent prize-delivery failure were covered. |