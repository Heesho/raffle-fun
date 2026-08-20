# Security invariants

This catalog applies to the Ethereum/Chainlink, fixed-price, ERC-1167 v1 in the
current worktree. It is a review map, not a proof or an independent audit.

Evidence tags:

- `U`: deterministic Foundry unit or boundary test;
- `A`: adversarial or regression test;
- `F`: Foundry fuzz property;
- `I`: stateful Foundry invariant;
- `E`: Echidna property;
- `K`: Ethereum mainnet/Sepolia fork test;
- `X`: SDK, subgraph, deployment, frontend, or static check.

## Factory and initialization

1. The factory deploys one implementation and its constructor permanently locks
   initialization. `U`
2. Every registered raffle is a canonical ERC-1167 clone of that immutable
   implementation. `U/X`
3. Initialization is callable only once and only by the factory. `U/A`
4. Clone creation, registry writes, prize transfer, ownership verification, and
   activation are one atomic transaction. `U/A/I`
5. A failed prize transfer, receiver check, ownership check, or activation check
   leaves no registered raffle. `U/A`
6. Successful clones begin in `Active`; no usable clone remains in
   `AwaitingPrize`. `U/I`
7. Clone storage and asset custody are isolated. `U/I`
8. Factory IDs begin at one and map bijectively to registered raffle addresses.
   `U/I/X`
9. The quote token, VRF wrapper, treasury, implementation, entry price, callback
   gas, confirmations, fee rate, and timeouts cannot change for an existing raffle.
   `U/I/X`
10. The factory has no owner, role, pause, upgrade, rescue, or mutable configuration.
    `U/X`
11. A prize must be a deployed ERC-721 contract and must not be a known protocol
    destination. `U/A`
12. The reserve is positive and the sale ends in `(now, now + 30 days]`. `U/F`
13. The quote token reports six decimals; production deployment validation pins the
    intended USDC and Chainlink wrapper. `U/K/X`

## Entry ranges and ticket ownership

14. One successful purchase mints exactly one ERC-721 ticket, regardless of the
    number of entries bought. `U/F/I/E`
15. Ticket IDs begin at one and increase by exactly one; each ID maps to a separately
    stored inclusive `{firstEntry,lastEntry}` range. `U/F/I/E`
16. The first range begins at one; later ranges are contiguous, non-overlapping,
    and cover every sold entry exactly once. `U/F/I/E`
17. A purchase accepts any positive `uint128` count that does not overflow the
    cumulative `uint128 totalEntries`; there is no business-level per-ticket cap.
    `U/F`
18. The incoming quote balance delta equals `entryCount * 1_000_000` exactly before
    the ticket is minted. `U/A/F`
19. False-returning, taxed, rebasing-at-transfer, or reentrant payment behavior
    cannot create an unfunded ticket or liability. `A`
20. A rejecting or reentrant ticket receiver rolls back the payment and mint. `A`
21. Purchases are valid before `endTime` and invalid at or after it. `U/F`
22. Every unburned ticket remains transferable before and after `endTime`, including
    while drawing and after resolution. `U/A/F/I`
23. Winner and refund rights follow live `ownerOf(ticketId)` bearer ownership; a
    successful claim burns the ticket atomically. `U/F/I`
24. Tickets cannot be transferred to the raffle, factory, implementation, quote
    token, VRF wrapper, prize contract, or a registered sibling raffle. `U/A`

## Randomness and lifecycle

25. Status ordinals are exactly `AwaitingPrize`, `Active`, `Drawing`, `NftWon`,
    `CashWon`, and `Refunding`; there is no `Closed` state. `U/I/X`
26. A draw requires at least one entry, `now >= endTime`, and
    `now < endTime + 2 days`. `U/A/F`
27. A raffle accepts at most one VRF request. `U/A/I/E`
28. `requestDraw` uses the exact-pinned Chainlink Contracts `1.5.0` wrapper consumer,
    client, and interface to quote and forward one native-funded request with one word,
    300,000 callback gas, and 30 confirmations. `U/A/K/X`
29. Insufficient fee, fee-read failure, wrapper failure, or failed excess refund
    rolls the complete request back to `Active`. `U/A`
30. Direct native transfers revert; forced native value is not an economic
    liability. `U/A/I`
31. The official `VRFV2PlusWrapperConsumerBase` permits only the immutable wrapper to
    call `rawFulfillRandomWords`. `U/A/K`
32. A synchronous, wrong-ID, malformed, stale, or duplicate callback cannot settle
    the raffle. `U/A`
33. A valid callback stores one winning entry and terminal result without searching
    tickets, looping over entries, or calling a token, prize, or user. `U/A/X`
34. The winning entry is `(randomWord % totalEntries) + 1`, always inside the sold
    range. `U/F/I/E`
35. Exactly one minted ticket range contains a resolved winning entry. `F/I/E`
36. The callback chooses `NftWon` when `totalEntries >= reserveEntries`; equality is
    an NFT result. Otherwise it chooses `CashWon`. `U/F`
37. A sold `Active` raffle accepts a draw request exactly while
    `endTime <= block.timestamp < drawRequestDeadline()`, where the request deadline is
    `endTime + 2 days`. `U/I/E`
38. At and after `drawRequestDeadline()`, a sold raffle with no accepted request cannot
    enter `Drawing` and anyone may move it to full refunds. Before that deadline the
    sold-`Active` refund path is unavailable. `U/I/E`
39. A matching callback may resolve only while
    `block.timestamp < callbackDeadline()`. At and after the callback deadline it is
    ignored, while full refunds are available; the equality boundary is not a race.
    `U/A/I/E`
40. An empty raffle enters `Refunding` with zero quote liability: the sponsor may do
    so before the end, and anyone may do so at or after the end. `U/I`

## Settlement and accounting

42. `grossSales == totalEntries * ENTRY_PRICE`; burns never reduce historical sales.
    `F/I/E`
43. `accountedQuoteBalance` equals unsettled pot plus refund liability plus winner,
    sponsor, and protocol proceeds. `F/I/E`
44. The raffle's supported quote-token balance never falls below accounted
    liabilities; donations are surplus and create no claim. `U/F/I/E`
45. A cash callback records only the result and winning entry. Winning-ticket settlement
    records the ticket ID without reading ownership and allocates 80% of gross to the
    bearer claim, `floor(gross * 5%)` for the treasury, and the exact remainder for the
    sponsor. `U/F/I`
46. An NFT callback records only the result and winning entry. Winning-ticket settlement
    records the ticket ID without reading ownership and allocates 5% for the treasury
    and 95% for the sponsor. The ticket remains the bearer claim to the NFT. `U/A/F/I`
47. Every refund branch charges no fee and moves the complete unsettled pot into
    weighted ticket refunds. `U/A/F/I/E`
48. Winner proof is O(1) inclusive range containment; redemption separately checks
    live ticket ownership in O(1). `U/F/I`
49. NFT and cash settlement are permissionless accounting only: they record the proven
    winning ticket and liabilities without reading ownership, burning a ticket, or
    transferring an external asset. `U/A/F`
50. A settled winning ticket remains transferable. Only its current owner, not an
    approved operator, may redeem it; successful redemption burns it while delivering
    its NFT or cash atomically and can perform settlement first. `U/A/I/E`
51. Failed winner delivery restores the ticket, `winnerRedeemed`, `winnerRecipient`,
    the cash liability, and any lazy settlement in that call. A prior permissionless
    settlement and sponsor/protocol claims remain usable. `U/A`
52. NFT winner redemption uses `transferFrom` plus an `ownerOf` postcondition without
    a receiver callback; transfer or verification failure reverts the burn and leaves
    the bearer claim pending. `U/A`
53. Refund value is the sum of the inclusive entry counts in the caller-owned
    tickets times one USDC. `U/F/I/E`
54. A refund call handles 1–100 tickets; duplicate, invalid, or mixed-owner batches
    revert atomically. `U/A/F`
55. Refund batch complexity depends on ticket count, never on the entries represented
    by those tickets. `U/A/X`
56. Sponsor prize recovery is available only in `CashWon` or `Refunding`, is
    independent of quote settlement, and consumes the prize once. `U/A/I/E`
57. Sponsor and treasury quote balances are independent immutable-recipient liabilities.
    The winner cash liability follows the transferable ticket until its current owner
    burns it through owner-only redemption. `U/A/I`
58. Outgoing quote transfers verify both exact raffle debit and exact recipient
    credit; failures restore all effects. `U/A`
59. Known protocol destinations cannot receive tickets, quote payouts, or claimed
    prizes. `U/A`
60. No factory or treasury function can seize, redirect, rescue, or mutate a raffle's
    assets or result. `U/I/X`

## Off-chain consistency

61. SDK arithmetic uses `bigint`, validates sequential ticket IDs and stored
    `uint128` entry ranges, and uses the same NFT 5/95, cash 80/5/15 gross, and
    full-refund economics. `X`
62. The subgraph creates one ticket entity per purchase and never loops over entries.
    `X`
63. The subgraph is discovery data only; writes and ownership-sensitive actions are
    simulated against chain state. `X`
64. Deployment validation checks chain identity, finalized block/hash, code hashes,
    official dependencies, six-decimal quote behavior, implementation locking,
    constants, ownerless factory surface, and verified source requirements. `K/X`
65. No checked-in deployment record enables public mainnet writes. `X`

## Explicit assumptions

These invariants assume an honest standards-compliant ERC-721 prize, an exact-transfer
non-rebasing USDC deployment, correct Chainlink VRF wrapper/coordinator operation,
normal Ethereum consensus, and reachable credential owners. Upgradeable/freezeable
assets, future-code destinations, blocklists, key loss, oracle outage, transaction
censorship, and legal/operational failures remain external risks. See
`docs/THREAT-MODEL.md` and `packages/contracts/audit/CURRENT-RESIDUAL-RISKS.md`.
