# Security invariants

Review date: 2026-08-09. This catalog is for the constructor-deployed, single-USDC,
transferable bearer-ticket protocol in the reviewed worktree. It contains 110
practical invariants. The attached clone-era list is reconciled at the end rather than
being represented as if it applied to different code.

Evidence tags:

- `U`: Foundry unit/boundary test;
- `A`: Foundry adversarial/regression test;
- `F`: Foundry fuzz property;
- `I`: broad or multi-actor stateful invariant;
- `S`: strict fail-on-revert invariant;
- `E`: Echidna/Medusa independent property;
- `H`: Halmos focused symbolic check;
- `K`: pinned Base fork test;
- `X`: SDK, subgraph, frontend, deployment, or static check.

## Factory, construction, and immutable authority

1. A raffle constructor accepts only its declared factory caller. `U`
2. Every canonical raffle is an ordinary non-upgradeable `CREATE` deployment. `U/X`
3. Creation, registration, exact prize deposit, activation, and verification are one reverting transaction. `U/A`
4. A failed prize transfer rolls back the deployment, count, and registry. `U/A`
5. A failed ownership or activation postcondition rolls back the complete creation. `U`
6. No successfully registered raffle remains in `AwaitingPrize`. `U/I`
7. Factory IDs begin at one and map bijectively to registered raffle addresses. `U/I`
8. The factory quote token is immutable and contains runtime code. `U/X`
9. The factory Entropy dependency is immutable and contains runtime code. `U/X/K`
10. Callback gas is immutable, nonzero, and identical in fee and request calls. `U/A/K`
11. Ticket price and minimum threshold are nonzero. `U`
12. A scheduled start cannot precede the creation timestamp. `U`
13. Start delay is at most seven days. `U`
14. Sale duration is positive and at most 30 days. `U`
15. Metadata is at most 2,048 bytes. `U`
16. Prize admission requires a deployed contract reporting ERC-721 support. `U/A`
17. Factory creation pause affects only future creation. `U/I`
18. Treasury updates affect only subsequently created raffles. `U/I`
19. Ownership transfer is OpenZeppelin `Ownable2Step`; only the owner changes future policy. `U/X`
20. No factory owner action can change an existing raffle's assets, deadlines, winner, dependencies, or claims. `U/I/S`

## Prize custody

21. The receiver activates only for the exact prize contract and token ID. `U/A`
22. The prize sender must be the immutable sponsor. `U/A`
23. The prize operator must be the canonical factory. `U/A`
24. A duplicate or unrelated safe NFT deposit cannot activate or mutate a raffle. `U/A`
25. An unrelated unsafe NFT transfer changes no configured-prize accounting. `A`
26. A supported prize remains owned by the raffle until one terminal claim succeeds. `I/S/E`
27. The configured prize leaves escrow at most once. `U/A/I/S/E/H`
28. A reverting prize receiver restores the ticket, claimant, and `prizeClaimed` state. `U/A`
29. NFT-winner redemption burns the winning credential before its external transfer. `A/H`
30. Sponsor-side recovery marks the claim before its external transfer. `U/A/I`
31. `NftWon` assigns the NFT only to the current winning-ticket owner. `U/F/I`
32. `CashWon`, `Refunding`, and `Closed` expose the NFT only to the immutable recovery recipient. `U/I`
33. The recovery recipient may choose a different nonzero safe NFT destination. `U`
34. Factory owner and treasury have no prize seizure or rescue selector. `X/I`
35. Prize recovery is independent of quote claims and refund-ticket burns. `U/I`

## Sales and bearer tickets

36. Sale start is inclusive and sale end is exclusive. `U/F`
37. Purchases before start or at/after end revert atomically. `U`
38. Purchase quantity is between one and 100. `U/F`
39. The ticket recipient is nonzero. `U`
40. Gross multiplication is checked before token interaction. `U/F`
41. Incoming quote credit equals `ticketPrice * quantity` exactly. `U/A/F`
42. A failed, false-returning, taxed, or reentrant payment cannot mint tickets or liabilities. `A`
43. A rejecting or reentrant ticket receiver rolls back payment and every tentative mint. `A`
44. Ticket IDs begin at one, remain contiguous, and never repeat. `U/F/I/E`
45. Separate purchases continue from `totalTickets + 1`. `U`
46. `totalTickets` equals all tickets ever issued and `grossSales = ticketPrice * totalTickets`. `F/I/S/E`
47. Every unburned ticket has exactly one nonzero owner. `U/I/E`
48. Tickets and approvals follow ERC-721 bearer semantics in every lifecycle state. `U/F/I`
49. A winning or refundable right moves with its unburned ticket and is consumed by burning. `U/F/H`
50. A zero-sales raffle closes only by the sponsor before end or permissionlessly at/after end. `U/I`

## Randomness and lifecycle

51. Status follows one monotonic enum and no terminal result returns to `Active` or `Drawing`. `I/S/E`
52. A draw requires at least one ticket and cannot precede sale end. `U/A`
53. A request succeeds at `endTime` and before, but not at, the three-day grace deadline. `U`
54. A raffle completes at most one Entropy request. `I/S/E`
55. Fee-read or request reverts leave the raffle `Active` and preserve deadline recovery. `A`
56. Exact fee payment succeeds; insufficient payment reverts. `U/A/K`
57. Native overpayment is returned immediately to the requester or the request rolls back. `U/A`
58. Direct native transfers revert and forced native value creates no liability. `U/I`
59. Status becomes `Drawing` and the in-flight guard is set before the oracle call. `A`
60. A synchronous callback cannot settle before the returned sequence is stored. `A`
61. Only the immutable Entropy wrapper can enter the callback. `U/A/K`
62. Wrong sender, wrong sequence, in-flight, stale, duplicate, and post-failure callbacks cannot settle. `U/A/H`
63. Sequence zero or reuse cannot create a second request or resolution within a raffle. `A`
64. The callback performs bounded storage work and no token, prize, treasury, or recipient call. `A/X`
65. Winning ID is `(random mod totalTickets) + 1`, never zero or above sold range. `F/I/S/E/H`
66. One ticket always selects ticket one and the final sold ticket is reachable. `U/F/H`
67. Modulo bias is nonzero in general and documented rather than described as perfect uniformity. `X`
68. Missing-request refunds become available exactly at `end + 3 days`. `U/I`
69. Callback-timeout refunds become available exactly at `drawRequestedAt + 2 days`. `U/I/H`
70. Callback-first and timeout-first ordering are mutually exclusive; the first valid terminal transition wins. `U/I/S/H`

## Settlement and quote conservation

71. A successful resolution charges `floor(grossSales * 500 / 10,000)` in both NFT and cash branches. `U/F/I/S/E`
72. A failure branch charges no protocol fee and creates no sponsor or winner proceeds. `U/I/E`
73. Threshold equality selects `NftWon`; threshold minus one selects `CashWon`. `U/F`
74. `NftWon` assigns all post-fee distributable quote to the sponsor. `U/F`
75. `CashWon` assigns floor 80% of post-fee quote to the winning ticket and the remainder to the sponsor. `U/F`
76. Fee plus sponsor plus winner liabilities conserve every gross unit in successful branches. `F/I/E`
77. Refund enablement moves the complete unsettled pot to `remainingRefundLiability`. `U/I/S/E`
78. Each refund ticket burns for exactly one ticket price. `U/F/H`
79. Refund redemption accepts one to 100 caller-owned IDs and no unbounded loop. `U/F/I`
80. Duplicate, invalid, or foreign refund IDs revert the whole batch and restore tentative burns. `U/A`
81. Refund tickets can be redeemed in arbitrary order and by independent owners. `U/I`
82. Winning cash can be consumed at most once by the current winning-ticket owner. `U/F/H`
83. Sponsor and treasury claims are pull liabilities and can be consumed at most once. `U/I/S/E`
84. `claimQuoteFor` is permissionless but can pay only the fixed account itself. `U/A`
85. A claimant may direct its own quote claim to another nonzero destination. `U`
86. A payment to the raffle itself is rejected and preserves the claim. `U/A`
87. Exact outgoing raffle debit and recipient credit are both verified. `U/A`
88. A failing, taxed, surcharged, blacklisted, or paused outgoing token transfer restores all effects. `A`
89. `accountedQuoteBalance = unsettledPot + remainingRefundLiability + winnerCashLiability + totalClaimableQuote`. `F/I/S/E`
90. Supported quote-token balance is never below accounted liabilities; donations create only surplus. `U/F/I/S/E`

## Protocol destinations, integrations, and operations

91. A ticket cannot be transferred to its own raffle. `A`
92. A ticket cannot be transferred to its factory, quote token, Entropy contract, or configured prize contract. `A`
93. A ticket cannot be transferred to an already registered sibling raffle. `A`
94. OpenZeppelin safe-transfer overloads route through the same protocol-destination rejection. `A`
95. The newly constructed raffle cannot be its own fixed recovery recipient. `A`
96. The newly constructed raffle cannot be its own treasury. `A`
97. Factory treasury configuration rejects the factory, quote token, Entropy, and registered raffles. `A`
98. Tickets and fixed claims assigned to a future code-less canonical raffle remain recoverable after it registers. `A`
99. Protocol-owned ticket, quote, and prize claims route only to the holder raffle's immutable recovery recipient. `A`
100.  The protocol-owned claim-kind helper accepts only a canonical registered target and exposes no arbitrary call. `U/A`
101.  Arbitrary user-selected non-callable contracts remain an explicit bearer-transfer risk, not a claimed solved case. `X`
102.  Lens rejects unregistered targets before forwarding reads. `U/X`
103.  Lens batch length is at most 64 and fields match authoritative contract state. `U/X`
104.  Entropy fee-read failure cannot hide non-fee state or refund availability in Lens. `U/X`
105.  SDK ABI, enums, deadline arithmetic, and economic arithmetic match Solidity. `X`
106.  SDK rejects duplicate, nonpositive, empty, and oversized refund batches before simulation. `X`
107.  Every first-party wallet write is simulated against live chain state; the subgraph is non-authoritative. `X`
108.  Subgraph handlers reconstruct bearer transfers, burns, liabilities, fees, and one terminal result without duplicate entities. `X`
109.  Deployment records fail closed on chain, code, official USDC/Entropy, immutables, owner/pending owner, treasury, and Lens mismatch. `X/K`
110.  No checked-in deployment record or placeholder enables public writes; public deployment and ownership transfer require an external reviewed release procedure. `X`

## Reconciliation of the clone-era 342-item list

The following requested groups are not applicable to this code and were not
reintroduced: shared implementation locks, EIP-1167 clone initialization, CREATE2
salts/address prediction, quote-token allowlisting/removal/caps, transfer freezes,
refund credit/souvenir state, native pull-refund liabilities, `claimPrizeFor`, and a
100-entry Lens batch. Their replacement invariants are respectively constructor
authentication/atomic registration, one immutable factory-wide token, transferable
bearer burns, immediate native excess rollback, recovery-recipient initiated prize
claims, and a 64-entry Lens bound.

This catalog is evidence organization, not formal verification. External asset,
oracle, chain, sequencer, key-management, legal, and operational assumptions remain in
the threat model and audit residual-risk report.
