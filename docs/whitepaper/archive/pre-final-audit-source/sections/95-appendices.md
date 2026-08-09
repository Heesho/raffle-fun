:::part id="part-x" no="Appendices" title="Technical Reference"
The exact state machine, formulas, contract surfaces, events, invariants, asset requirements, glossary, and sources.
- A|Exact State Machine
- B|Economic Formulas
- C|Contract Reference
- D|Event Guide
- E|Security Invariants
- F|Supported Asset Model
- G|Glossary
- H|References
:::

# Appendix A | Exact State Machine

States: `Uninitialized`, `AwaitingPrize`, `Active`, `DrawRequested`, `Resolved`
(terminal), `Cancelled` (terminal), `Refunding` (terminal). Terminal means the
outcome can never change; claim and refund-credit activity continues inside
terminal states. Figure 6 in Chapter 12 draws this table.

<!-- table:breakable,small -->
| # | From | To | Function | Caller | Conditions | Side effects | Event |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Uninitialized | AwaitingPrize | `initialize` | factory only | caller is a contract whose `raffleImplementation()` equals the clone's embedded implementation; all parties and dependencies nonzero | full configuration stored; ERC-721 ticket collection initialized | none (creation is evented by the factory) |
| 2 | AwaitingPrize | Active | `onERC721Received` | prize contract | operator is the factory, `from` is the sponsor, exact prize contract and token ID | none beyond the state | `PrizeDeposited` |
| 3 | Active | Cancelled | `cancelBeforeSales` | sponsor only | `totalTickets == 0` (no time condition) | outcome `CancelledBeforeSale`; prize claimant := recovery address | `RaffleCancelled` |
| 4 | Active | Resolved | `closeNoSales` | anyone | `now >= endTime` and `totalTickets == 0` | outcome `NoSales`; prize claimant := recovery address | `NoSalesClosed` |
| 5 | Active | DrawRequested | `requestDraw` | anyone | `now >= endTime`, `now < endTime + 3 days`, `totalTickets > 0`, `msg.value >=` current Entropy fee | `drawRequestedAt := now`; exact fee forwarded to Entropy; sequence stored; excess credited to requester as native claim | `DrawRequested` |
| 6 | Active | Refunding | `finalizeUnrequestedDraw` | anyone | `totalTickets > 0` and `now >= endTime + 3 days` | outcome `DrawNotRequested`; pot moved to refund liability; prize claimant := recovery address | `DrawFailureFinalized` |
| 7 | DrawRequested | Resolved | `entropyCallback` | Entropy contract only (via Pyth wrapper) | sequence equals stored sequence; no in-flight request | winning ticket and owner snapshotted; fee, winner, and sponsor credits recorded per branch; pot zeroed; outcome `NftAwarded` or `CashFallback`; prize claimant := winner or recovery address | `RaffleResolved` |
| 8 | DrawRequested | Refunding | `finalizeTimedOutDraw` | anyone | `now >= drawRequestedAt + 2 days` | outcome `DrawTimedOut`; same effects as 6 | `DrawFailureFinalized` |

Rejected callback deliveries (wrong sequence, wrong state, in-flight) emit
`EntropyCallbackIgnored` and change nothing. At the timeout boundary (row 7 versus
row 8), both transactions are valid until one executes; the first included wins and
the other becomes a no-op or ignored event.

Non-transition actions, by state:

| Action | Allowed states | Caller | Conditions and effects |
| --- | --- | --- | --- |
| `buyTickets` | Active | anyone | `startTime <= now < endTime`; quantity 1..100; exact gross payment verified; contiguous ticket IDs minted to the recipient |
| ticket transfer | Active, Resolved, Cancelled; Refunding only for credited tickets | ticket owner or approved | owner-to-owner moves revert in DrawRequested (`TicketTransfersFrozen`) and for uncredited refund tickets (`RefundTicketFrozen`) |
| `creditTicketRefunds` | Refunding | anyone | 1..100 valid, not-yet-credited ticket IDs; credits exactly one `ticketPrice` per ticket to its current owner; no external calls |
| `claimQuote` / `claimQuoteFor` | any state (balances exist only after resolution or crediting) | claimant / anyone | zeroes the balance, then transfers with exact debit and credit verification; `-For` pays only the account itself |
| `claimPrize` / `claimPrizeFor` | Resolved, Cancelled, Refunding | prize claimant / anyone | single-use flag set before transfer; failed delivery reverts atomically; `-For` delivers only to the recorded claimant |
| `claimNative` | any | accrued account | pays draw-fee overpayment credits to a chosen destination |

# Appendix B | Economic Formulas

All arithmetic is integer arithmetic on raw token units. `floor` division is
Solidity's default; multiplication happens before division via `Math.mulDiv`, so no
intermediate overflow or premature truncation occurs. Constants: `BPS = 10,000`,
`PROTOCOL_FEE_BPS = 500`, `CASH_WINNER_BPS = 8,000`.

```text
purchase:            gross            = ticketPrice x quantity
resolution:          fee              = floor(pot x 500 / 10,000)
                     distributable    = pot - fee
  threshold met:     sponsorCash      = distributable ; winnerCash = 0
  threshold missed:  winnerCash       = floor(distributable x 8,000 / 10,000)
                     sponsorCash      = distributable - winnerCash
refunding:           refundLiability  = pot ; per ticket: ticketPrice ; fee = 0
```

Accounting identities, maintained continuously and checked by invariant tests:

```text
accountedQuote  = unsettledPot + uncreditedRefundLiability + totalClaimableQuote
solvency        : quoteToken.balanceOf(raffle) >= accountedQuote
conservation    : fee + winnerCash + sponsorCash = pot         (resolved)
                  sum over tickets of ticketPrice = pot         (refunding)
native          : address(raffle).balance >= totalClaimableNative
```

Rounding behavior: `fee` and `winnerCash` round down; `sponsorCash` is a
subtraction and therefore absorbs all rounding remainders (at most 2 raw units
across both floors). The fee is computed once on the aggregate pot, so purchase
splitting cannot alter total fees by even one unit.

Verified vectors (six-decimal token; raw units shown for the dust case):

<!-- table:breakable -->
| Vector | Pot | Fee | Distributable | Winner cash | Sponsor cash |
| --- | --: | --: | --: | --: | --: |
| 120 x 10.00, met | 1,200.000000 | 60.000000 | 1,140.000000 | 0 (NFT) | 1,140.000000 |
| 100 x 10.00, met exactly | 1,000.000000 | 50.000000 | 950.000000 | 0 (NFT) | 950.000000 |
| 99 x 10.00, missed | 990.000000 | 49.500000 | 940.500000 | 752.400000 | 188.100000 |
| 80 x 10.00, missed | 800.000000 | 40.000000 | 760.000000 | 608.000000 | 152.000000 |
| 1 x 10.00, missed | 10.000000 | 0.500000 | 9.500000 | 7.600000 | 1.900000 |
| 10 x 0.333333, missed (raw) | 3,333,330 | 166,666 | 3,166,664 | 2,533,331 | 633,333 |

Each vector reproduces with `calculateResolutionAmounts` in
`packages/sdk/src/math/economics.ts` and matches the contract worked-example tests.

# Appendix C | Contract Reference

## Raffle (the per-raffle clone)

Purpose: escrow one prize, sell tickets, settle one outcome, hold claims. Trust
model: no owner, no admin, no upgrade; only the factory (at initialization) and the
configured Entropy contract (at callback) are privileged, each for one call.

Key storage: configuration (factory, sponsor, recovery address, treasury, quote
token, entropy, prize, price, minimum, times, callback gas, metadata URI);
counters (`totalTickets`, `grossSales`, `unsettledPot`,
`uncreditedRefundLiability`, `totalClaimableQuote`, `totalClaimableNative`);
settlement (`entropySequenceNumber`, `drawRequestedAt`, `winningTicketId`,
`winner`, `prizeClaimant`, `state`, `outcome`, `prizeClaimed`); per-account claim
mappings and the per-ticket refund-credited mapping.

External surface (state-changing): `initialize`, `buyTickets`,
`cancelBeforeSales`, `closeNoSales`, `requestDraw`, `finalizeUnrequestedDraw`,
`finalizeTimedOutDraw`, `creditTicketRefunds`, `claimQuote`, `claimQuoteFor`,
`claimPrize`, `claimPrizeFor`, `claimNative`, plus ERC-721 transfers of tickets.
Views include state, deadlines (`requestGraceDeadline`, `callbackDeadline`),
`getEntropyFee`, odds, solvency and surplus inspectors, and refund-credit status.

External calls made: quote-token transfers (guarded by exact-delta checks), the
prize collection's `safeTransferFrom` (at claim), Entropy's `getFeeV2` and
`requestV2`, and ticket recipients' ERC-721 receiver hooks (bounded by quantity
and the reentrancy guard). Native transfers occur only in `claimNative` and
`requestDraw`'s fee forwarding. The `receive` function reverts.

Errors are custom and specific (over two dozen, from `SaleNotStarted` to
`RefundTicketFrozen`), which keeps reverts cheap and diagnosable; Appendix D lists
the events.

## RaffleFactory

Purpose: create, register, and configure raffles; administer future creation.
Trust model: `Ownable2Step` owner (multisig expected) with the three powers of
Chapter 30; holds no assets; `nonReentrant` creation.

Storage: immutable implementation, Entropy, callback gas limit; current treasury,
raffle count, creation pause; registries (`raffleById`, `idByRaffle`, `isRaffle`);
the bounded admitted-token list with stable indices. Creation validates inputs,
deploys the deterministic clone, initializes it, registers it, emits
`RaffleCreated`, escrows the prize, and verifies real ownership, all atomically.

## RaffleLens

Purpose: one-call aggregated reads for registered raffles (single and batches up
to 100), including deadlines, liabilities, per-account claims and ticket balances,
action availability flags, and an `entropyFeeAvailable` indicator so a broken
oracle fee read cannot hide recovery actions from interfaces. Trust model:
stateless, immutable factory binding, rejects unregistered addresses, cannot write.

# Appendix D | Event Guide

A raffle's complete history reconstructs from events alone, which is exactly what
the subgraph does. In lifecycle order:

<!-- table:breakable -->
| Event (emitter) | Fired when | Key fields |
| --- | --- | --- |
| `QuoteTokenVerificationUpdated` (factory) | owner admits or removes a payment token | token, previous and new status |
| `ProtocolTreasuryUpdated`, `CreationPauseUpdated`, ownership events (factory) | admin policy changes | previous and new values |
| `RaffleCreated` (factory) | a raffle is created | raffle ID and address, sponsor, recovery address, prize, quote token, treasury, price, minimum, normalized start, end, request deadline, metadata |
| `PrizeDeposited` (raffle) | the exact prize enters escrow | prize contract, token ID, sponsor |
| `TicketsPurchased` (raffle) | each purchase | buyer, recipient, quantity, first and last ticket ID, gross amount |
| `Transfer` (raffle, ERC-721) | each ticket mint or move | standard ERC-721 fields; mints come from the zero address |
| `RaffleCancelled` / `NoSalesClosed` (raffle) | the two zero-sales endings | sponsor or caller, prize claimant |
| `DrawRequested` (raffle) | the one accepted request | sequence, requester, fee, excess credited, request time, callback deadline |
| `EntropyCallbackIgnored` (raffle) | a rejected delivery | received and expected sequence, current state |
| `RaffleResolved` (raffle) | the callback settles | sequence, winning ticket, winner, outcome, prize claimant, fee, winner cash, sponsor cash |
| `DrawFailureFinalized` (raffle) | a failure deadline is exercised | outcome, caller, recovery address, gross refund liability |
| `TicketRefundCredited` (raffle) | each ticket's refund credit | ticket ID, credited owner, amount, remaining liability |
| `QuoteClaimed` / `PrizeClaimed` / `NativeClaimed` (raffle) | each withdrawal | account, destination, amount or token ID |

Reconstruction rules an indexer follows: creation precedes the deposit in the same
transaction (the factory registers and emits before escrow); purchase events pair
with mint Transfers; exactly one of `RaffleResolved`, `DrawFailureFinalized`,
`NoSalesClosed`, or `RaffleCancelled` is terminal per raffle; refund credits sum to
the recorded liability; and claim events monotonically consume recorded credits.
Every event ID derives from transaction hash plus log index, so duplicate delivery
is idempotent.

# Appendix E | Security Invariants

Each property is stated formally, then in everyday terms, and each is continuously
attacked by the stateful invariant suite (256 random call sequences of depth 64
locally; 1,000 of depth 256 in CI).

<!-- table:breakable -->
| Formal invariant (test name) | In everyday terms |
| --- | --- |
| `invariantAccountedQuoteAlwaysReconcilesAndIsSolvent` | The contract's token balance always covers the pot plus uncredited refunds plus all recorded claims. The books never show money that is not there. |
| `invariantQuotePaidInEqualsPaidOutPlusContractBalance` | Every unit that ever entered equals what left through claims plus what remains. Nothing leaks and nothing is minted. |
| `invariantPrizeLeavesEscrowAtMostOnceAndOnlyAfterAClaimPathExists` | The prize moves at most once, and only after a terminal outcome named its claimant. |
| `invariantAtMostOneRequestAndResolutionExist` | One randomness request, one resolution, ever. |
| `invariantResolvedWinnerIsAlwaysARealSoldTicket` | A recorded winner always corresponds to a ticket that was actually sold. |
| `invariantEverySoldTicketHasANonzeroOwner` | No ticket is ever ownerless; the selection formula always lands on a real holder. |
| `invariantResolutionBranchMatchesExactThresholdBoundary` | The branch taken always matches `tickets >= minimum`, including exact equality. |
| `invariantRefundingConservesGrossAndNeverCreditsProtocolFee` | In refund mode, credited refunds plus remaining liability always equal the original pot, and no fee is ever taken. |
| `invariantStateTransitionsNeverMoveBackward` | The state machine is monotonic: no sequence of calls re-opens, re-rolls, or rewinds a raffle. |

Two further properties are enforced by construction and unit tests rather than a
dedicated invariant: donations and forced value are inert surplus, and no
administrator path into a live raffle exists (no such function is present in the
bytecode).

# Appendix F | Supported Asset Model

The protocol's guarantees hold for assets within this envelope. Outside it, the
design degrades safely (transactions revert) but user experience may not.

**Payment tokens (ERC-20).** Supported: contract-backed tokens that transfer exact
amounts in both directions with no fee-on-transfer, no rebasing or elastic supply,
no transfer hooks that reenter, and standard `balanceOf`/`transfer`/`transferFrom`
semantics (return-value quirks are tolerated via SafeERC20). The factory admission
list is the operational enforcement of this envelope; the exact-delta checks are
the mechanical enforcement. Explicitly unsupported: taxed or reflective tokens,
rebasing tokens, tokens whose balances change without transfers. Issuer controls
(pause, blacklist, upgrade) are compatible with correctness but can delay or block
individual withdrawals.

**Prize collections (ERC-721).** Supported: deployed contracts that affirmatively
report ERC-721 support via ERC-165, implement honest ownership (`ownerOf` reflects
transfers), and perform standard `safeTransferFrom`. The escrow handshake verifies
these properties at creation. Explicitly unsupported: collections that lie about
ownership (creation reverts), and semi-fungible or fractional standards such as
ERC-1155. Mutable, pausable, or admin-controlled collections pass the handshake if
they behave at that moment; their later behavior is outside the guarantee, as
Chapter 33 states.

**Native currency.** Used only to pay the Entropy fee through `requestDraw`.
Direct sends revert; force-pushed value is inert surplus.

# Appendix G | Glossary

<!-- table:breakable -->
| Term | Meaning |
| --- | --- |
| Base | An Ethereum layer-2 network with low fees; a raffle.fun target chain alongside Ethereum itself. |
| Ethereum | The largest smart-contract blockchain and a raffle.fun target network. |
| Blockchain | A public ledger maintained by many computers that no single party can rewrite. |
| Callback | The second half of the randomness exchange: Entropy's transaction delivering the result. |
| Claim (pull payment) | A recorded debt the claimant withdraws themselves; the contract never pushes assets unprompted. |
| Clone (EIP-1167) | A minimal contract that borrows logic from a shared implementation while keeping its own storage. |
| Commit-reveal | A scheme where parties commit to hidden values first, so no one can choose their value after seeing others'. |
| CREATE2 | A deployment method making contract addresses predictable in advance. |
| Distributable pot | The pot after the 5 percent fee: what winner and sponsor share. |
| ERC-20 | The standard for interchangeable tokens (money-like balances). |
| ERC-165 | The standard by which a contract declares which interfaces it supports. |
| ERC-721 | The standard for non-fungible (unique) tokens; both prizes and tickets follow it. |
| Escrow | Custody by a neutral keeper until rules decide the owner; here, the raffle contract itself. |
| Entropy (Pyth) | The external randomness service delivering the draw's random number. |
| Factory | The contract that creates, registers, and configures raffles. |
| Gas | The network fee paid for executing a transaction. |
| Grace period | The 3-day window after closing during which the draw may be requested. |
| Immutable | Unchangeable after deployment; raffle configuration and code are immutable. |
| Indexer / subgraph | Offchain software that turns contract events into a searchable database. |
| Lens | The read-only contract aggregating raffle state for applications. |
| Metadata | Offchain descriptive data (names, images) referenced by tokens; not authoritative. |
| Minimum (threshold) | The ticket count at or above which the winner receives the NFT rather than cash. |
| Multisig | An account requiring multiple signatures; the intended factory owner. |
| NFT | Non-fungible token: a unique blockchain asset under ERC-721. |
| Oracle | A service that brings offchain information (here, randomness) onchain. |
| Permissionless | Callable by anyone; no allowlist or role required. |
| Pot (unsettled pot) | All ticket payments held by the raffle awaiting settlement. |
| Quote token | The raffle's one payment token, in which the price is quoted. |
| Recovery address | The fixed destination that reclaims the prize in every non-winner ending. |
| Reentrancy | An attack where an external call re-enters the caller mid-operation; guarded throughout. |
| Refunding | The terminal state after a failed draw in which every ticket is credited its price back. |
| RPC provider | The service relaying your reads and transactions to the network. |
| Sequence number | The unique ID of the raffle's one randomness request. |
| Smart contract | A program on the blockchain that runs exactly as written. |
| Sponsor | The raffle's creator and prize depositor. |
| Terminal state | A state from which the outcome can never change (Resolved, Cancelled, Refunding). |
| Transaction | A signed instruction executed by the network. |
| Treasury | The fixed address credited the protocol fee. |
| Wallet | Software holding your signing keys and submitting transactions. |

# Appendix H | References

Primary sources only; all specification claims in this document trace to one of
these or to the repository itself.

- ERC-20 Token Standard: [eips.ethereum.org/EIPS/eip-20](https://eips.ethereum.org/EIPS/eip-20)
- ERC-165 Standard Interface Detection: [eips.ethereum.org/EIPS/eip-165](https://eips.ethereum.org/EIPS/eip-165)
- ERC-721 Non-Fungible Token Standard: [eips.ethereum.org/EIPS/eip-721](https://eips.ethereum.org/EIPS/eip-721)
- EIP-1167 Minimal Proxy Contract: [eips.ethereum.org/EIPS/eip-1167](https://eips.ethereum.org/EIPS/eip-1167)
- Solidity documentation (v0.8.36): [docs.soliditylang.org](https://docs.soliditylang.org)
- OpenZeppelin Contracts 5.x documentation: [docs.openzeppelin.com/contracts/5.x](https://docs.openzeppelin.com/contracts/5.x)
- Pyth Entropy documentation: [docs.pyth.network/entropy](https://docs.pyth.network/entropy)
- Ethereum documentation: [ethereum.org/en/developers/docs](https://ethereum.org/en/developers/docs)
- Base network documentation: [docs.base.org](https://docs.base.org)
- The raffle.fun repository at reviewed commit `a2120f5e163dc3641d9864773febbfedca047edb`: contracts under `packages/contracts/src`, tests under `packages/contracts/test`, protocol documentation under `docs/`, and the claim-by-claim record in `docs/whitepaper/FACT-CHECK.md`.

---

This document is complete as of August 9, 2026, describing protocol version 1.0.0
at the reviewed commit. Corrections and questions: open an issue in the repository
or contact the maintainers through the security policy for sensitive reports.
