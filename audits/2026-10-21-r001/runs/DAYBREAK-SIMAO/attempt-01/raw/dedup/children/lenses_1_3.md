Exhaustive mechanical inventory:

### `raw/lenses/lens-01-accounting.md`

- No `FINDING` block.
- No `LEAD` block.
- The file explicitly states this at line 5.

### `raw/lenses/lens-02-shares.md`

1. `FINDING`
   - Source location: lines 78–89
   - ID/title: none present
   - Exact `(contract, function)`: `(Raffle, _settleWinningTicket)`

```text
FINDING | contract: Raffle | function: _settleWinningTicket | bug_class: premature-proceeds-release | group_key: Raffle | _settleWinningTicket | premature-proceeds-release
root_cause: In the `NftWon` branch at Raffle.sol:543-555, settlement converts the entire pot into immediately releasable sponsor and treasury balances before the only prize-delivery attempt at Raffle.sol:334; the independent exits at Raffle.sol:375-390 require neither `prizeClaimed` nor `winnerRedeemed`.
internal_pre: A sponsor-selected ERC-721 allows the initial escrow but can later reject transfers from the raffle; one entry is sold, the reserve is met, and the authenticated callback resolves `NftWon`.
external_pre: None
path:
  1. Mallory deploys a pausable ERC-721, mints token 1, leaves transfers enabled, and creates a raffle with `reserveEntries = 1`, herself as `sponsorRecipient`, and token 1 as the prize; factory escrow and its immediate ownership check succeed.
  2. Alice buys the sole entry for 1,000,000 raw USDC units. After the sale, randomness necessarily selects entry 1 and `totalEntries >= reserveEntries` produces `NftWon`.
  3. Mallory disables outbound transfers in the prize contract. A permissionless caller settles ticket 1: `protocolFees = 1,000,000 * 500 / 10,000 = 50,000`, `sponsorProceeds = 950,000`, and `unsettledPot = 0`.
  4. `releaseSponsorProceeds` pays Mallory 950,000 raw units, and `releaseProtocolFees` can pay the remaining 50,000 to the treasury. The full sale pot has left the raffle.
  5. Alice calls `redeemWinningTicket(1)`. The prize rejects the transfer at Raffle.sol:334, so Alice's redemption transaction reverts, but the earlier settlement and releases persist. `NftWon` has no transition to `Refunding`, so Alice can receive neither the NFT nor her 1,000,000-unit payment back.
impact: The winning-ticket owner is left holding an unredeemable claim and loses the full 1 USDC purchase while a malicious sponsor extracts 0.95 USDC and the treasury may extract 0.05 USDC. At larger sales the loss scales linearly with the entire pot.
mitigation: Do not make the `NftWon` sponsor and treasury balances releasable until successful prize delivery; keep that pot uncommitted and route it to ticket refunds after a bounded delivery failure instead.
```

- No `LEAD` block in this file.

### `raw/lenses/lens-03-temporal.md`

1. `FINDING`
   - Source location: lines 116–127
   - ID/title: none present
   - Exact `(contract, function)`: `(Raffle, releaseSponsorProceeds)`

```text
FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: premature-proceeds-release | group_key: Raffle | releaseSponsorProceeds | premature-proceeds-release
root_cause: `releaseSponsorProceeds` at Raffle.sol:375-381 and its sibling `releaseProtocolFees` at Raffle.sol:385-391 release all sale USDC in an NFT result without requiring `winnerRedeemed`, so the sponsor can be paid before the untrusted prize has successfully left escrow.
internal_pre: The raffle resolved `NftWon`, the winning ticket was settled, and neither the winning ticket nor prize has been redeemed.
external_pre: The sponsor-selected ERC-721 accepts the initial escrow and ownership verification but can later revert, pause, blacklist the raffle, or otherwise refuse the outbound winner transfer.
path:
  1. At t0 Mallory creates a raffle with `reserveEntries = 1`, names a sponsor recipient she controls, and supplies a prize contract that accepts escrow but whose outbound transfers she can block.
  2. At t1 Alice buys 100 entries for 100,000,000 raw USDC units; she owns the only ticket and is therefore the eventual winner.
  3. At t2 the draw resolves `NftWon`; Mallory (or any caller) settles Alice's ticket, allocating 95,000,000 units to Mallory's recipient and 5,000,000 units to the treasury.
  4. Mallory calls `releaseSponsorProceeds` and receives 95,000,000 units; the fee release can remove the remaining 5,000,000 units as well.
  5. At t3 Alice calls `redeemWinningTicket`; the prize rejects `transferFrom`, so Alice's redemption state rolls back, while the already completed quote payments remain final.
impact: Alice, the current winning-ticket owner, paid 100 USDC but can receive neither the promised NFT nor any refund; Mallory keeps 95 USDC despite withholding the prize, and after the fee release the raffle has no sale USDC left to make Alice whole.
mitigation: In both sponsor and protocol quote-release paths, reject release while `status == NftWon && !winnerRedeemed`; keep the sale pot unavailable to those recipients until successful prize delivery (and, if undeliverable prizes are to remain supported, add a bounded transition that converts the retained pot to ticket refunds).
```

2. `LEAD`
   - Source location: lines 137–140
   - ID/title: none present
   - Exact `(contract, function)`: `(Raffle, buyEntries)`

```text
LEAD | contract: Raffle | function: buyEntries | bug_class: sponsor-last-minute-reserve-manipulation | group_key: Raffle | buyEntries | sponsor-last-minute-reserve-manipulation
smell: A sponsor can wait for genuine demand, buy the final entries just before closing, flip the outcome from the 80% cash fallback to the NFT branch, and recycle 95% of the combined pot through its sponsor recipient while also holding the new winning chances.
unverified: The scoped specification defines the reserve using all entries and does not state that sponsor-funded entries must be excluded; on-chain identity is sybilable, so it is unclear whether this is an intended seller option or a prohibited cohort manipulation and no minimal sybil-resistant fix was established.
description: The concrete one-entry Alice / one-entry Mallory timeline removes Alice's 0.8-USDC fallback and lets Mallory net 0.9 USDC plus a 50% chance to retain the prize, but the entitlement Alice owns before the still-open sale closes is not specified strongly enough to elevate this to a finding.
```

Total: 2 `FINDING` blocks and 1 `LEAD` block.
