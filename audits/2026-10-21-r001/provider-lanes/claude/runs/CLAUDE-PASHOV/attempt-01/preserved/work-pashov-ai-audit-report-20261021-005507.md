# 🔐 Security Review — work

---

## Scope

|  |  |
| --- | --- |
| **Mode** | filename |
| **Files reviewed** | `packages/contracts/src/Raffle.sol` · `packages/contracts/src/RaffleFactory.sol` · `packages/contracts/src/interfaces/IRaffle.sol`<br>`packages/contracts/src/interfaces/IRaffleFactory.sol` · `packages/contracts/src/libraries/RaffleConstants.sol` |
| **Confidence threshold (1-100)** | 75 |

---

## Findings

[75] **1. `_update` allows ticket transfers during a pending VRF request**

`Raffle._update` · Confidence: 75

**Description**
`_update` allows transfers in `Drawing`, so an attacker who reads the VRF fulfillment buys the winning ticket or sells losing tickets before the callback runs.

**Fix**

```diff
     function _update(address to, uint256 ticketId, address auth) internal override returns (address previousOwner) {
+        if (status == Status.Drawing) revert InvalidStatus(status);
         if (to != address(0) && _isProtocolDestination(to, address(prizeToken))) {
             revert UnsafeProtocolDestination(to);
         }
```

---

[75] **2. `releaseSponsorProceeds` pays the sponsor before NFT delivery in `NftWon`**

`Raffle.releaseSponsorProceeds` · Confidence: 75

**Description**
A sponsor who controls the prize contract takes 95% of the pot, then pauses or moves the NFT, so the winner gets nothing.

**Fix (Option A — restrict)**:

```diff
     function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
+        if (status == Status.NftWon && !prizeClaimed) revert InvalidStatus(status);
         amount = sponsorProceeds;
         if (amount == 0) revert NoSponsorProceeds();
```

**Fix (Option B — restrict with timeout)**:

```diff
     function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
+        // Pay `sponsorProceeds` in `NftWon` only after the NFT reaches the winner, with a timeout for a winner who never redeems.
+        if (status == Status.NftWon && !prizeClaimed && block.timestamp < uint256(resolvedAt) + SPONSOR_CLAIM_TIMEOUT) {
+            revert InvalidStatus(status);
+        }
         amount = sponsorProceeds;
         if (amount == 0) revert NoSponsorProceeds();
```

---

Findings List

| # | Confidence | Title |
|---|---|---|
| 1 | [75] | `_update` allows ticket transfers during a pending VRF request |
| 2 | [75] | `releaseSponsorProceeds` pays the sponsor before NFT delivery in `NftWon` |

---

## Leads

_Vulnerability trails with concrete code smells where the full exploit path could not be completed in one analysis pass. These are not false positives — they are high-signal leads for manual review. Not scored._

- **`_isProtocolDestination` treats every address with no code as safe** — `Raffle._isProtocolDestination` — Code smells: the `destination.code.length != 0` branch skips `isRaffle` for an address with no code; anyone can compute the next clone address from the factory nonce; `releaseSponsorPrize` and the NFT branch of `redeemWinningTicket` send the NFT with no check at delivery; a ticket sent to the empty predicted address passes `_update` — A future clone address passes the check as `sponsorRecipient` or ticket owner, so the prize NFT or the ticket later stays in that clone. Only the party that chose the address loses, and we found no gain for a third party.
- **Settlement credits 95% to the sponsor before NFT delivery** — `Raffle._settleWinningTicket` — Code smells: `_settleWinningTicket` sets `sponsorProceeds = grossPot - protocolFee` in `NftWon` and moves no prize; any caller can run `settleWinningTicket`; `releaseSponsorProceeds` reads neither `winnerRedeemed` nor `prizeClaimed`; only `redeemWinningTicket` moves the NFT, through `prizeToken.transferFrom` on an untrusted contract — Settlement credits the sponsor 95% before NFT delivery, so a prize contract that blocks `transferFrom` leaves the winner with nothing. DESIGN.md makes the sponsor claim independent on purpose, and we did not find an honest prize that fails this way.
- **The sponsor buys entries toward the reserve at a 5% cost** — `Raffle.buyEntries` — Code smells: `buyEntries` accepts the sponsor, and any other address of the sponsor, until `endTime`; `fulfillRandomWords` sets `NftWon` when `totalEntries >= reserveEntries`; `_settleWinningTicket` pays 95% of the pot, sponsor entries included, to `sponsorRecipient`; a sponsor who also controls the prize contract can force `NftWon` this way and then block NFT delivery — The sponsor gets back 95% of what it pays, so it buys entries at 5% cost to reach the reserve or lower other buyers' odds. DESIGN.md does not forbid sponsor entries, and a `msg.sender` check does not stop a second address.
- **The reserve check counts the sponsor's own entries** — `Raffle.fulfillRandomWords` — Code smells: `fulfillRandomWords` compares `totalEntries` with `reserveEntries`, and `totalEntries` includes entries that the sponsor buys; in `NftWon`, `_settleWinningTicket` gives `grossPot - protocolFee` to the sponsor — A sponsor buys the missing reserve entries and gets 95% back, so the sponsor turns `CashWon` into `NftWon` for a 5% fee. We found no on-chain fix that stops a sponsor who uses a second address.
- **Mempool readers learn the winning entry ahead of the callback** — `Raffle.fulfillRandomWords` — Code smells: `fulfillRandomWords` sets `winningEntry` to `randomWords[0] % totalEntries + 1`; the coordinator computes `randomWords[0]` from the VRF proof in the pending fulfillment calldata; `_update` allows ticket transfers while `status` is `Drawing` — An attacker who reads the VRF fulfillment in the mempool buys the winning ticket from an open listing first. We did not confirm that mainnet VRF nodes send the fulfillment to the public mempool.
- **`releaseSponsorPrize` has no runtime check of the recipient** — `Raffle.releaseSponsorPrize` — Code smells: `_isProtocolDestination` skips the `isRaffle` lookup for an address with no code, so `initialize` accepts the next clone address as `sponsorRecipient`; `Clones.clone` uses CREATE, so anyone can compute that address from the factory nonce; `_transferQuote` checks the recipient again at payout, but `releaseSponsorPrize` calls `prizeToken.transferFrom` with no check; `releaseSponsorProceeds` then reverts with `InvalidQuoteDestination` on every call — When the sponsor sets `sponsorRecipient` to a future clone address, any caller can send the prize NFT into that clone. This breaks the DESIGN.md rule against asset moves between clones, and we found no loss for any party other than the sponsor.
- **`createRaffle` checks prize ownership only after the transfer** — `RaffleFactory.createRaffle` — Code smells: `createRaffle` calls `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` with the operator approval that sponsors gave the factory; no check before the transfer shows that `msg.sender` owns the token; `onERC721Received` takes `from` and `operator` from the prize token; the attacker then cancels the empty raffle with `enableRefunds`, and `releaseSponsorPrize` sends the NFT to the attacker's `sponsorRecipient` — An attacker can take an NFT that a victim approved to the factory, if the prize token ignores `from`. We did not find a deployed ERC721 that does this.
- **Clone addresses depend only on the factory nonce** — `RaffleFactory.createRaffle` — Code smells: `Clones.clone` uses CREATE, so the clone address depends only on the factory nonce; `buyEntries` takes no raffle ID, prize or parameter hash, so a call cannot bind to the raffle that the buyer saw — If a reorg reorders two `createRaffle` calls, a pending `buyEntries` call pays into a different raffle at the same address. An attacker cannot cause the reorg, and we did not measure how often it occurs.
- **`createRaffle` trusts the prize contract to report the escrow** — `RaffleFactory.createRaffle` — Code smells: `Raffle.onERC721Received` accepts the deposit when `msg.sender == address(prizeToken)`, so the prize contract can call it and move no token; the `prize.ownerOf` check after the transfer reads the same contract; in `NftWon`, `releaseSponsorProceeds` does not read `prizeClaimed` — A sponsor who deploys a fake prize contract passes every escrow check and takes 95% of the buyer USDC in `NftWon`. The winner gets nothing, and we did not confirm if the design accepts this risk.

---

> ⚠️ This review was performed by an AI assistant. AI analysis can never verify the complete absence of vulnerabilities and no guarantee of security is given. Team security reviews, bug bounty programs, and on-chain monitoring are strongly recommended. For a consultation regarding your projects' security, visit [https://www.pashov.com](https://www.pashov.com)
