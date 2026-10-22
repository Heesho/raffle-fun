Source file read completely: `/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/DAYBREAK-SIMAO/attempt-01/raw/lenses/lens-10-integration.md`

Inventory: 2 `FINDING` records and 2 `LEAD` records. No explicit ID/title field is present in any record.

1. `FINDING` — lens lines 47–57  
   Exact `(contract, function)`: `(Raffle, _transferQuote)`  
   Explicit code location: `Raffle.sol:564-568`

```text
47 FINDING | contract: Raffle | function: _transferQuote | bug_class: usdc-denylist-escrow-lock | group_key: Raffle | _transferQuote | usdc-denylist-escrow-lock
48 root_cause: `Raffle.sol:564-568` makes every quote claim leave from the raffle clone itself, but Circle-issued USDC on Ethereum rejects transfers from a deny-listed sender and the immutable clone has no migration or alternate settlement path.
49 internal_pre: A raffle clone holds nonzero USDC backing `unsettledPot`, `remainingRefundLiability`, `winnerProceeds`, `sponsorProceeds`, or `protocolFees`.
50 external_pre: Circle places that raffle clone on canonical Ethereum USDC's denylist and does not remove it.
51 path:
52   1. Buyers purchase 100 entries, transferring 100 USDC into raffle `R` and creating 100 USDC of backed claims.
53   2. Circle deny-lists `R` while it still holds the 100 USDC.
54   3. The raffle enters refunds, or settles into winner/sponsor/treasury claims.
55   4. Every relevant path reaches `_transferQuote`; USDC rejects the transfer because `R` is the sender, SafeERC20 propagates the revert, and retrying or transferring a ticket cannot change the blocked sender.
56 impact: Every otherwise clean ticket owner, winner, sponsor recipient, and treasury claimant in that raffle can lose access to its share of the full 100 USDC balance; the funds remain present but no claimant can make them leave the clone.
57 mitigation: No contract path can move USDC after its sender is deny-listed; either use a quote asset without sender freezing or explicitly make Circle unfreezing/remediation an operational recovery requirement of the USDC trust model.
```

2. `FINDING` — lens lines 59–69  
   Exact `(contract, function)`: `(Raffle, releaseSponsorProceeds)`  
   Explicit code location: `Raffle.sol:375-390`

```text
59 FINDING | contract: Raffle | function: releaseSponsorProceeds | bug_class: usdc-denylisted-fixed-recipient | group_key: Raffle | releaseSponsorProceeds | usdc-denylisted-fixed-recipient
60 root_cause: `Raffle.sol:375-390` can release sponsor proceeds and protocol fees only to the immutable `sponsorRecipient` and `protocolTreasury`; Circle-issued USDC on Ethereum rejects a transfer to a deny-listed recipient, and neither claim has a claimant-authorized redirection path.
61 internal_pre: Settlement has allocated nonzero `sponsorProceeds` or `protocolFees`.
62 external_pre: Circle deny-lists the corresponding fixed recipient after raffle initialization and does not remove it.
63 path:
64   1. A raffle sells 100 entries and resolves `NftWon`, allocating 95 USDC to sponsor recipient `S` and 5 USDC to treasury `T`.
65   2. Circle adds `S` to canonical Ethereum USDC's denylist.
66   3. Any caller invokes `releaseSponsorProceeds`; the attempted transfer to `S` reverts and the preceding zeroing rolls back.
67   4. Every retry targets the same `S`, so the backed 95 USDC claim is unreachable. The same sequence at `releaseProtocolFees` strands 5 USDC if `T` is deny-listed.
68 impact: The sponsor recipient can lose access to 95 USDC in the concrete NFT-win example, or the treasury to 5 USDC in the repeated instance, even while all other cohorts settle in full; the affected fixed recipient is left holding the loss.
69 mitigation: Add a claim-redirection function authorized by the current sponsor beneficiary (or stored sponsor) and by the current treasury respectively, so each can select a non-protocol replacement destination before the transfer.
```

3. `LEAD` — lens lines 71–74  
   Exact `(contract, function)`: `(RaffleFactory, createRaffle)`  
   Explicit code locations: `RaffleFactory.sol:128-134`, `RaffleFactory.sol:171-178`, `Raffle.sol:416-429`

```text
71 LEAD | contract: RaffleFactory | function: createRaffle | bug_class: untrusted-prize-self-attestation | group_key: RaffleFactory | createRaffle | untrusted-prize-self-attestation
72 smell: `RaffleFactory.sol:128-134` and `RaffleFactory.sol:171-178` accept prize custody using ERC-721 support and `ownerOf` answers supplied by the same untrusted prize contract, while `Raffle.sol:416-429` lets that contract fabricate the expected receiver callback; the token can also revoke transferability after a genuine deposit.
73 unverified: The supplied source names no deployed real-world ERC-721 whose canonical semantics permit forged ownership, arbitrary escrowed-token burn, or post-deposit transfer revocation, and browsing for one is disallowed; the named-instance requirement therefore prevents promotion to a finding.
74 description: A sponsor-controlled prize can make creation appear funded, collect buyers' USDC after an NFT-win result, and then deliver no genuine NFT, or can brick both winner delivery and sponsor return after initially honest escrow.
```

4. `LEAD` — lens lines 76–79  
   Exact `(contract, function)`: `(Raffle, _isProtocolDestination)`  
   Explicit code location: `Raffle.sol:593-604`

```text
76 LEAD | contract: Raffle | function: _isProtocolDestination | bug_class: counterfactual-clone-destination | group_key: Raffle | _isProtocolDestination | counterfactual-clone-destination
77 smell: `Raffle.sol:593-604` rejects only the current clone and already-registered code-bearing clones, but future OpenZeppelin clone addresses are predictable under Ethereum CREATE and pass while code-less; a ticket or configured sponsor destination can therefore become a raffle sink later.
78 unverified: The concrete paths shown require the ticket owner or sponsor to choose the counterfactual address for its own asset, and no path was established for an attacker to force an unrelated victim's existing claim there, so the present impact is self-harm rather than a reportable exploit.
79 description: After the predicted address becomes a registered clone, a prior ticket cannot be exercised by that clone, sponsor USDC releases are rejected at runtime, and `releaseSponsorPrize` can move the NFT into the clone without a recovery path, violating the no-cross-clone design invariant.
```
