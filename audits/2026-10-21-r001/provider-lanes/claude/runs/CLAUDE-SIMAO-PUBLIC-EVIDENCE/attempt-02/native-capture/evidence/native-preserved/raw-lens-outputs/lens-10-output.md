# Lens 10: Integration and Environment Assumptions (raffle.fun)

Line numbers point to the on-disk files under `packages/contracts/src/`. `F:` means `RaffleFactory.sol`. Chainlink and OpenZeppelin references point to the vendored copies under `packages/contracts/node_modules/`. Target chain: Ethereum L1 (`hardhat.config.ts` lists mainnet and Sepolia; `evm_version = cancun`).

Result: 1 FINDING and 2 LEADs.

---

FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: admin-gated-prize-transfer | group_key: Raffle | releaseSponsorProceeds | admin-gated-prize-transfer
root_cause: Raffle.sol:376. `releaseSponsorProceeds` pays out `sponsorProceeds` with no check on `status` or `prizeClaimed`. In `NftWon`, `_settleWinningTicket` allocates 95% to the sponsor and 5% to the treasury (Raffle.sol:543-544, 554-555) through permissionless, storage-only settlement. Neither step depends on the NFT leg in `redeemWinningTicket` (Raffle.sol:329-337) ever succeeding. `NftWon` also has no fallback for the winner: `enableRefunds` only accepts Active or Drawing (Raffle.sol:279-293), `releaseSponsorPrize` excludes NftWon (Raffle.sol:397), and `winnerProceeds` stays 0. The code assumes the escrowed ERC-721 can still be transferred out of the clone when the winner redeems. Real ERC-721s let an admin revoke that after deposit: OpenZeppelin `ERC721Pausable` (`_update` is `whenNotPaused` and reverts `EnforcedPause()`), Manifold Creator Core's admin-set transfer-approval hook (`setApproveTransfer`), Limit Break ERC721-C transfer validators (creator-set soulbound or OTC-blocking policies, account freezing), and upgradeable ERC-721 proxies. DESIGN.md says "arbitrary prize contracts ... are untrusted", but IRaffle.sol:14-15 assumes "honest" prizes. The code follows the weaker of the two.
internal_pre: The reserve is met, so the result is `NftWon`. No other state is needed.
external_pre: The prize collection has an owner-controlled transfer gate (pause, approve-transfer hook, validator policy or freeze, or proxy upgrade), and the sponsor controls it or colludes with whoever does. The common case qualifies: an artist raffling a token from their own Manifold or OpenZeppelin collection.
path:
  1. Artist S owns collection C, an OZ v5 `ERC721` + `ERC721Pausable` + `Ownable` contract that reports `supportsInterface(0x80ac58cd) == true`. C is unpaused and S holds C#7.
  2. S calls `RaffleFactory.createRaffle({sponsorRecipient: S, prizeToken: C, prizeTokenId: 7, reserveEntries: 1_000, endTime: now + 7 days})`. The escrow at F:128-134 succeeds and raffle R is Active, holding C#7.
  3. Buyers purchase 20,000 entries. R now holds 20,000 USDC and `unsettledPot = 20_000e6`.
  4. After `endTime`, S already knows the result will be `NftWon` (20,000 >= 1,000 is fixed before randomness), so S calls `C.pause()`. No draw or refund path touches C. With a per-address gate (a Manifold hook rejecting `from == R`, or an ERC721-C freeze of R), S's other collectors are not affected.
  5. S calls `R.requestDraw{value: fee}()`. The VRF callback sets `status = NftWon` and `winningEntry = 13_337`, which falls in buyer W's ticket #412.
  6. S calls `R.settleWinningTicket(412)`, which is permissionless and makes no NFT check. Result: `sponsorProceeds = 19_000e6`, `protocolFees = 1_000e6`.
  7. S calls `R.releaseSponsorProceeds()` and receives 19,000 USDC. Anyone calls `releaseProtocolFees()` and the treasury receives 1,000 USDC.
  8. W calls `R.redeemWinningTicket(412)`. `C.transferFrom(R, W, 7)` reverts `EnforcedPause()`, so the whole call reverts and the ticket is not burned. Every retry reverts for as long as C stays gated, and no other claim path exists in `NftWon`. Upgradeable variant: S upgrades C, pulls C#7 back out of R, and still keeps the 19,000 USDC.
impact: The buyer cohort paid 20,000 USDC. S takes 19,000 USDC and the treasury 1,000 USDC, and the NFT is never delivered. Winner W is left holding the loss: the claim on C#7 can never be redeemed and there is no cash or refund substitute. This defeats the protocol's trust-minimising guarantee ("Exactly one ERC721 prize is escrowed atomically at creation") while fully protecting the sponsor's 95%. S's cost is a token S controls anyway.
mitigation: In `releaseSponsorProceeds` (Raffle.sol:375-376), add `if (status == Status.NftWon && !prizeClaimed) revert` so NftWon sponsor proceeds unlock only after `redeemWinningTicket` has delivered and verified the prize. Optionally apply the same gate to `releaseProtocolFees`. This narrows DESIGN.md's "claim independently after settlement" for the NftWon branch only. That is the branch where the sponsor can control the opposite leg, and the gate removes the sponsor's profit from blocking the prize.

---

LEAD | contract: Raffle | function: releaseProtocolFees | bug_class: usdc-blacklist-immutable-recipient | group_key: Raffle | releaseProtocolFees | usdc-blacklist-immutable-recipient
smell: Two USDC claim legs pay out only to addresses that can never change, and neither has a redirect or claim-to path.
  - `releaseProtocolFees` pays `protocolTreasury` (Raffle.sol:385-390). That address comes from the factory immutable (F:39, passed in at F:114) and is the same for every raffle.
  - `releaseSponsorProceeds` pays `sponsorRecipient` (Raffle.sol:375-380), which is set once at initialize.
  Ethereum-mainnet USDC (Circle FiatToken v2.2) reverts `transfer` when `to` is blacklisted. So one Circle blacklisting of the treasury permanently freezes the 5% fee of every past and future raffle from this factory. A blacklisted `sponsorRecipient` permanently freezes that raffle's 95% or 15% proceeds. The returned-prize payout in `releaseSponsorPrize` (Raffle.sol:404) has the same shape for collections that blocklist recipients.
  Ticket-holder legs are safe (Raffle.sol:342, 369): they pay the current bearer, who can move the ticket to a clean address first.
unverified: No third-party victim. Only the blacklisted beneficiary loses, and only after an outside Circle action. I could not construct an attacker-induced path.
description: Immutable USDC recipients with no redirect path turn a USDC blacklist into a permanent freeze of protocol fees (factory-wide) or sponsor proceeds (per raffle).

---

LEAD | contract: Raffle | function: requestDraw | bug_class: immutable-vrf-wrapper-dependency | group_key: Raffle | requestDraw | immutable-vrf-wrapper-dependency
smell: The Chainlink wrapper can never be changed, each raffle gets one request attempt, and there is no admin.
  - The wrapper address is fixed at F:36 and in the immutable `i_vrfV2PlusWrapper` (VRFV2PlusWrapperConsumerBase.sol:35), set at Raffle.sol:157 and shared by every clone.
  - Chainlink's VRFV2PlusWrapper owner can call `disable()`, after which its price and request functions revert. Chainlink has retired whole VRF versions before: v1 and v2 were sunset in favor of v2.5.
  - Once the wrapper stops serving, `getVrfRequestPrice()` (Raffle.sol:436-438) and therefore `requestDraw` (Raffle.sol:249) revert for every raffle from this factory. Every sold raffle then ends in `Refunding` after `endTime + 2 days`.
  - If the wrapper's coordinator is re-pointed while a request is pending, the callback is never delivered. The requester's native fee (Raffle.sol:257) is lost before refunds open (Raffle.sol:289-291).
unverified: Whether Chainlink will retire v2.5, or move the mainnet wrapper to a new coordinator, while a raffle is live. The impact is liveness (sponsor sales never complete, the protocol earns no fees) plus the draw requester's fee. Principal is safe: refunds and prize return still work.
description: The whole factory hard-depends on one Chainlink wrapper with no migration path, so a Chainlink-side sunset turns every raffle into a refund.

---

## Public audit-evidence summaries

Chainlink deployment parameters for Ethereum v2.5 (minimum confirmations 3, maximum 200, max callback gas 2.5M, `s_disabled` semantics) are stated from Chainlink's published configuration and wrapper source. They could not be checked offline, because only the interfaces and consumer base are vendored.

**[Model: buyEntries]** The buyer pays `entryCount * 1e6` USDC (Raffle.sol:223-224) and gets one bearer ticket covering `[first,last]` (229-235). The only total that changes is `unsettledPot += grossAmount` (233). No live `balanceOf` is read anywhere in `src/`, so there is no donation surface. The credit relies on USDC being fee-free, which is a documented trust assumption (IRaffle.sol:13-14).

**[Model: requestDraw]** The caller pays native ETH of at least the wrapper quote (249-250). The wrapper receives exactly `calculateRequestPriceNative`, computed from `tx.gasprice` in the same transaction (VRFV2PlusWrapperConsumerBase.sol:82-88). The excess goes back to `msg.sender` in the same call (262-270), and the raffle keeps no ETH.

**[Model: settle/redeem/release]** In NftWon the 5% fee and 95% sponsor share are allocated at settlement (543-555) and can be released immediately (375-391), while the NFT moves only in redeem (329-337), which is the gap in the FINDING. In CashWon, for P = n·1e6 the split is n·800,000 / n·150,000 / n·50,000, which is exact with no dust.

**[Model: refundTickets]** Burns the caller's tickets, pays `entries * 1e6` to `msg.sender`, and decrements `remainingRefundLiability` by the same amount (349-372).

**[Why: Raffle.sol:255-257]** The extraArgs value is `0x92fd1338 || bool(true)` (36 bytes), which matches the wrapper's native-payment check. 30 confirmations and a 300k callback gas limit are within the Ethereum v2.5 coordinator bounds. The callback (509-524) does O(1) work, roughly two SSTOREs and one event, so it cannot run out of gas under 300k.

**[Why: ReentrancyGuard.sol:36-37, 112-114]** OZ 5.6 uses a namespaced slot and only `== ENTERED` counts as locked. Clones start that slot at 0 and work without any initializer. ERC721 `_name` and `_symbol` are empty in clones but `name()` and `symbol()` are overridden as pure. The implementation is locked: `initialized = true` and `status = Refunding` (163-165).

**[Why: Raffle.sol:266-267]** The refund call has output size 0, so a returndata bomb is impossible and only the caller can make it fail.

**[Why: USDC pause]** No deadline-gated path touches USDC (`requestDraw`, `enableRefunds`, `fulfillRandomWords`), and claim functions have no deadline. A USDC pause or upgrade can delay claims but cannot push a raffle into refunds or strand a claim. Fee-on-transfer or rebasing behaviour is excluded under the documented trust in canonical USDC.

**[Defeat: createRaffle prize escrow]** Every non-standard prize case below fails closed at F:128-134 and Raffle.sol:421-426:
- no ERC-165 support (CryptoPunks, or CryptoKitties with its draft interface ID)
- `safeTransferFrom` missing, or not calling the receiver
- `operator` not the factory, or `from` not the sponsor
- a nesting Moonbird
- ERC721-C at whitelist levels that block the factory as operator
- a double receiver callback

A malicious prize contract can fake the deposit, but that only produces a worthless prize, which buyers can check up front.

**[Defeat: fulfillRandomWords ignore conditions]** `_requestInFlight` is only true inside `requestDraw`. Status leaves Drawing only through the callback or through `enableRefunds` at or after the deadline, and `requestId` is pinned. The outcome type (NftWon or CashWon) is fixed before randomness. Nobody who sees the random word can steer it into refunds, short of a builder censoring for two days.

**[Defeat: _isProtocolDestination TOCTOU]** The only check that can change over time is `isRaffle`. An address can flip from safe to unsafe only if it is a not-yet-deployed CREATE address of the factory, and nobody controls such an address. So no third party can be stranded. The same holds for the NFT legs that are not re-screened (`releaseSponsorPrize`, 404).

**[Defeat: _transferQuote recipients]** A USDC-blacklisted ticket holder can move the bearer ticket and then claim. Only the fixed-recipient legs (380, 390) are exposed, which is LEAD 1.

**[Defeat: environment]**
- EIP-7702 delegated EOAs have code (`0xef0100||addr`), so `isRaffle` is queried and returns false, with no false positive.
- SELFDESTRUCT under EIP-6780 rules out metamorphic recipients.
- A 100-ticket refund batch costs about 1.3M gas, within the EIP-7825 per-transaction cap of 16.77M gas.
- ENS `.eth` prizes whose `ownerOf` reverts after expiry can be renewed by anyone within the 90-day grace period, so they are recoverable.
- ERC-6551, ERC-4907 and ERC404 prizes expose only a prize-value risk, not a protocol defect.
- Secondary-market bids on tickets being picked off around the VRF fulfillment is ordinary MEV and is excluded.

**[LastOut: Refunding]** `remainingRefundLiability = P = Σ` of unburned ranges × 1e6. Each ticket burns exactly once, so the last refunder is paid exactly. The only outside dependency is USDC.

**[LastOut: CashWon]** USDC claims equal the balance exactly. Returning the NFT to `sponsorRecipient` depends on the prize staying transferable, which only puts the sponsor at risk.

**[LastOut: NftWon]** The USDC claims (95/5) equal the balance and can always be collected, but the winner's NFT claim depends on the prize contract and has no fallback. This is the gap in the FINDING.

**[LastOut: native ETH]** `msg.value = paidPrice + excess`, settled atomically. Forced ETH is untracked and has no claimant.

**Saturation sweep.** I checked every site of the form "one leg is released while the other leg depends on an untrusted outside transfer":
- NftWon `releaseSponsorProceeds` and `releaseProtocolFees`: this is the FINDING.
- CashWon and Refunding `releaseSponsorPrize`: only the sponsor's own NFT is at risk.
- Factory escrow: fails closed.

I checked every immutable-recipient push for the blacklist shape: 380, 390 and 404 belong to LEAD 1, while 342 and 369 can be redirected by moving the ticket.

I checked every Chainlink call site (436, 441, 257, `rawFulfillRandomWords`) against the wrapper interface and its selectors; only the immutability and sunset dependency remains (LEAD 2).
