Source file: `/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-01/raw/lenses/lens-04-liquidation.md`

Inventory totals:

- FINDING: 1
- LEAD: 0

FINDING 1

- Location: line 113; full record spans lines 113–125.
- ID/title: none present.
- Exact fields: `contract: Raffle`; `function: _settleWinningTicket`
- Exact tuple: `(Raffle, _settleWinningTicket)`
- Exact declaration:

```text
FINDING | contract: Raffle | function: _settleWinningTicket | bug_class: unbacked-prize-settlement | group_key: Raffle | _settleWinningTicket | unbacked-prize-settlement
```

- Exact record:

```text
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

No `LEAD` entry appears anywhere in the file.
