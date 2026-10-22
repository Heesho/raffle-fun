Source: `/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-01/raw/lenses/lens-05-crosschain.md`  
Coverage: entire file, lines 1–94.

Counts:

- `FINDING`: 1
- `LEAD`: 0

FINDING 1

- Source location: lines 83–94
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

No `LEAD` record appears anywhere in the file.
