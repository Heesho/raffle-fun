Exhaustive inventory: **2 FINDING records, 0 LEAD records**.

### `raw/lenses/lens-04-liquidation.md`

- Coverage: lines 1–127
- FINDING count: 1
- LEAD count: 0
- Record location: lines 113–125
- ID/title: none present
- Exact `(contract, function)`: `(Raffle, _settleWinningTicket)`
- Exact cited code locations: `Raffle.sol:539-555`, `Raffle.sol:332-336`, `RaffleFactory.sol:127-134`

```text
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
```

### `raw/lenses/lens-05-crosschain.md`

- Coverage: lines 1–94
- FINDING count: 1
- LEAD count: 0
- Record location: lines 83–94
- ID/title: none present
- Exact `(contract, function)`: `(RaffleFactory, createRaffle)`
- Exact cited code locations: `RaffleFactory.sol:154-176`, `RaffleFactory.sol:128-133`, `Raffle.sol:334`

```text
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
```

### `raw/lenses/lens-06-rounding.md`

- Coverage: lines 1–117
- FINDING count: 0
- LEAD count: 0
- Exact declaration at line 117:

```text
No FINDING or LEAD was identified for the Rounding, Precision & Scale lens.
```
