:::part id="appendices" no="Technical Appendices" title="Exact Reference"
The appendices summarize the state machine, formulas, contracts, events, invariants,
supported assets, review evidence, deployment gates, legal risks, terms, and sources.
- A|Exact State Machine
- B|Exact Formulas
- C|Contract Reference
- D|Event Guide
- E|Security Invariants
- F|Supported Asset Model
- G|Audit and Test Evidence
- H|Deployment Verification
- I|Legal and Operational Risks
- J|Glossary
- K|References
:::

# Appendix A | Exact State Machine

:::figure src="diagrams/04-lifecycle.svg" num="21" title="Complete lifecycle" caption="Seven status values represent both lifecycle and economic result. Asset claims do not create additional status transitions."
:::

<!-- table:breakable -->
| From | To | Caller | Exact preconditions | Core effects | Event | Ticket transfer |
| --- | --- | --- | --- | --- | --- | --- |
| construction | `AwaitingPrize` | factory through constructor | `msg.sender` equals declared factory; fixed parties and dependencies nonzero; unsafe fixed protocol destinations rejected | store all immutables and metadata | none | no tickets exist |
| `AwaitingPrize` | `Active` | factory-operated prize safe transfer | exact prize contract and ID; sponsor is `from`; factory is operator | activate raffle | `PrizeDeposited` | no tickets yet |
| `Active` | `Closed` | sponsor before end, anyone at/after end | `totalTickets == 0` | expose sponsor-side prize claim | `EmptyRaffleClosed` | no tickets exist |
| `Active` | `Drawing` | anyone | `timestamp >= endTime`; tickets exist; `timestamp < requestGraceDeadline`; sufficient current fee; Entropy request and immediate excess return succeed | store request time and one sequence | `DrawRequested` | remains allowed |
| `Active` | `Refunding` | anyone | tickets exist; `timestamp >= requestGraceDeadline` | move `unsettledPot` to `remainingRefundLiability` | `RefundsEnabled` with request false | remains allowed |
| `Drawing` | `NftWon` | authenticated Entropy callback | not in flight; exact sequence; threshold met | select ticket; clear unsettled pot; credit fee and sponsor | `RaffleResolved` | remains allowed until burn |
| `Drawing` | `CashWon` | authenticated Entropy callback | not in flight; exact sequence; threshold missed | select ticket; clear unsettled pot; record winner cash; credit fee and sponsor | `RaffleResolved` | remains allowed until burn |
| `Drawing` | `Refunding` | anyone | `timestamp >= callbackDeadline` | move unsettled pot to refund liability | `RefundsEnabled` with request true | remains allowed |

Invalid, in-flight, stale, duplicate, or post-terminal callbacks emit
`EntropyCallbackIgnored` without a transition. Claims and burns do not change the
terminal status. They update ticket existence, prize-claimed state, and liabilities.

## Status reference

| Status | Meaning | Claims available |
| --- | --- | --- |
| `AwaitingPrize` | transient constructor state inside atomic factory transaction | none |
| `Active` | sale or post-sale request grace | purchases during window; request after end; empty close; failure finalization at grace |
| `Drawing` | one Entropy sequence pending | valid callback or timeout finalization |
| `NftWon` | threshold met after valid callback | winning bearer burns for NFT; sponsor and treasury pull USDC |
| `CashWon` | threshold missed after valid callback | winning bearer burns for cash; sponsor and treasury pull USDC; recovery recipient claims NFT |
| `Refunding` | liveness failure finalized | current bearers burn for refunds; recovery recipient claims NFT |
| `Closed` | zero-sales close | recovery recipient claims NFT |

# Appendix B | Exact Formulas

Let:

- `P` = raw ticket price;
- `Q` = purchase quantity;
- `T` = total tickets ever minted;
- `G` = gross sales;
- `F` = protocol fee;
- `D` = post-fee distributable pot;
- `W` = cash winner amount;
- `S` = sponsor amount;
- `R` = remaining refund liability;
- `C` = aggregate sponsor and treasury quote claims.

## Purchases and sales

`grossPurchase = P x Q`

`G = P x T`

Tickets from one purchase are:

`firstTicketId = previousTotalTickets + 1`

`lastTicketId = previousTotalTickets + Q`

## Successful resolution

`F = floor(G x {{PROTOCOL_FEE_BPS}} / 10,000)`

`D = G - F`

When threshold is met:

`S = D`

`W = 0`

When threshold is missed:

`W = floor(D x {{CASH_WINNER_BPS}} / 10,000)`

`S = D - W`

Therefore `F + W + S = G` in cash outcome and `F + S = G` in NFT outcome.

## Failed draw

At failure finalization:

`R = unsettledPot = G`

For a successful batch of `N` refundable tickets:

`refund = P x N`

`R_after = R_before - refund`

## Aggregate quote accounting

`accountedQuoteBalance = unsettledPot + R + winnerCashLiability + C`

For a supported quote token:

`actualQuoteBalance >= accountedQuoteBalance`

The difference is unaccounted surplus and creates no claim.

## Winner and odds

`winningTicketId = (uint256(randomNumber) % T) + 1`

`current holder share = tickets currently owned / T`

## Pixel Passport raw-unit check

| Value | Human USDC | Raw units |
| --- | --: | --: |
| Ticket price | 10.00 | `{{RAW_TICKET_PRICE}}` |
| 120-ticket gross | {{EXAMPLE_NFT_GROSS}} | `{{RAW_NFT_GROSS}}` |
| 120-ticket fee | {{EXAMPLE_NFT_FEE}} | `{{RAW_NFT_FEE}}` |
| 120-ticket sponsor | {{EXAMPLE_NFT_SPONSOR}} | `{{RAW_NFT_SPONSOR}}` |
| 80-ticket gross | {{EXAMPLE_CASH_GROSS}} | `{{RAW_CASH_GROSS}}` |
| 80-ticket fee | {{EXAMPLE_CASH_FEE}} | `{{RAW_CASH_FEE}}` |
| 80-ticket cash winner | {{EXAMPLE_CASH_WINNER}} | `{{RAW_CASH_WINNER}}` |
| 80-ticket sponsor | {{EXAMPLE_CASH_SPONSOR}} | `{{RAW_CASH_SPONSOR}}` |
| 80-ticket failed-draw refunds | {{EXAMPLE_REFUND_TOTAL}} | `{{RAW_REFUND_TOTAL}}` |

# Appendix C | Contract Reference

## RaffleFactory

**Purpose.** Validate and atomically create canonical raffles.

**Immutable dependencies.** Factory-wide quote token, Pyth Entropy v2, callback gas
limit.

**Mutable state.** Future treasury, future creation pause, owner/pending owner, raffle
count, registry mappings.

**Public actions.** `createRaffle`, `setProtocolTreasury`, `setCreationPaused`,
`transferOwnership`, `acceptOwnership`, `renounceOwnership`, and reads.

**Access.** Creation is open while unpaused. Policy writes are owner-only.

**External calls.** Raffle constructor deployment, prize ERC-165, safe transfer,
`ownerOf`, and raffle `status` verification.

**Security notes.** Nonreentrant atomic creation; future-only administration; runtime
size margin is narrow.

## Raffle

**Purpose.** Hold one NFT, mint transferable tickets, request randomness, account for
one result, and expose claims.

**Immutable dependencies and configuration.** Factory, sponsor, recovery recipient,
treasury, quote token, Entropy, prize contract and ID, raffle ID, price, threshold,
start, end, callback gas.

**Mutable state.** Tickets, status, sales and liabilities, request sequence/time,
winner, prize claim flag, metadata, quote claims.

**Public actions.** Purchase, zero-sales close, fee read, draw request, failure
finalization, winner/refund redemption, quote claims, sponsor prize claim, selective
protocol-owned recovery, ERC-721 transfers and approvals, and reads.

**Access.** No administrator. Rights are status-based, permissionless, actual-ticket-
owner, fixed-recipient, or quote-claimant checks.

**External calls.** USDC balance/transfer, Entropy fee/request, prize safe transfer,
ticket receiver callbacks, factory registry reads.

**Security notes.** Reentrancy guard, exact token deltas, storage-only callback,
bounded loops, known protocol-destination checks, no rescue.

## RaffleLens

**Purpose.** Aggregate wallet-oriented reads.

**Immutable dependency.** One canonical factory.

**Storage responsibilities.** None beyond immutable factory.

**Public actions.** Single and up-to-{{LENS_BATCH_SIZE}} raffle views.

**Access.** Public reads, but only for factory-registered raffles.

**External calls.** Factory registry, raffle views, ticket ownership, dynamic Entropy
fee through the raffle.

**Security notes.** Read-only; fee failure isolated; results can become stale after the
queried block.

# Appendix D | Event Guide

Indexers should also process inherited ERC-721 `Transfer`, `Approval`, and
`ApprovalForAll` events.

<!-- table:breakable -->
| Event | Meaning | Important reconstruction rule |
| --- | --- | --- |
| `RaffleCreated` | factory assigned and configured a new address | reverted transaction means no creation; later `PrizeDeposited` activates |
| `PrizeDeposited` | exact configured NFT entered escrow | status becomes `Active` |
| `TicketsPurchased` | exact USDC received and ticket range minted | combine with ERC-721 mint transfers; gross is event raw amount |
| ERC-721 `Transfer` | ticket minted, transferred, or burned | zero `from` is mint; zero `to` is burn; current owner is bearer |
| `EmptyRaffleClosed` | zero-sales raffle entered `Closed` | no request or quote liability |
| `DrawRequested` | one Entropy sequence accepted | record fee, excess returned, request time, callback deadline |
| `EntropyCallbackIgnored` | callback could not settle | do not create a terminal result |
| `RaffleResolved` | valid callback chose ticket and NFT/cash branch | record exact fee, winner cash, sponsor cash, and one terminal status |
| `RefundsEnabled` | request or callback liveness failure entered `Refunding` | event identifies whether request had been accepted |
| `WinningTicketRedeemed` | selected ticket burned for NFT or cash | update burn, cash liability, and prize claim when applicable |
| `RefundTicketsRedeemed` | owner burned a bounded batch for exact refund | decrease remaining liability by event amount |
| `QuoteClaimed` | sponsor or treasury claim transferred | decrease claimant and aggregate pull liabilities |
| `SponsorPrizeClaimed` | fixed recovery recipient withdrew NFT | set prize claimed |
| `ProtocolTreasuryUpdated` | future factory treasury changed | do not rewrite existing raffle treasury |
| `CreationPauseUpdated` | future creation pause changed | do not alter existing raffle status |
| Ownable events | factory ownership transition | future-policy authority only |

# Appendix E | Security Invariants

The internal catalog maps 110 practical invariants to unit, adversarial, fuzz,
stateful, independent-fuzzer, symbolic, fork, static, and integration evidence. Core
invariants are summarized below.

<!-- table:breakable -->
| Plain-English invariant | Technical form or evidence target |
| --- | --- |
| Creation is all or nothing | registered implies exact prize owner and `Active`; revert rolls back ID and deployment |
| Only the factory constructs a raffle | constructor requires `msg.sender == params.factory` |
| Existing rules do not change | constructor immutables; no raffle owner or upgrade selector |
| Sales start inclusively and end exclusively | `timestamp >= startTime && timestamp < endTime` |
| Every paid ticket has one sequential ID | `totalTickets == grossSales / ticketPrice`; IDs 1 through total |
| Exact payment precedes mint | raffle balance delta equals `ticketPrice x quantity` |
| Tickets are bearer rights | actual `ownerOf` required at redemption; transfer stays open until burn |
| Known protocol destinations cannot trap tickets | transfer rejects self, factory, dependencies, prize, registered raffles |
| One request and one terminal result | monotonic status and stored sequence; no second request path |
| Callback cannot settle in flight | private guard remains true until sequence is stored |
| Wrong or duplicate callback is harmless | status/sequence/guard mismatch emits ignored event |
| Winner is always sold | `1 <= winningTicketId <= totalTickets` |
| Both oracle-liveness failures recover | exact grace and timeout boundaries reach `Refunding` |
| Callback and timeout are mutually terminal | first status change prevents the other result |
| Successful branches charge the compiled fee | `fee = floor(gross x {{PROTOCOL_FEE_BPS}} / 10,000)` |
| Failed branches charge no fee | `enableRefunds` creates no sponsor or treasury claim |
| Threshold equality awards NFT | `totalTickets >= minimumTickets` selects `NftWon` |
| Cash branch allocates every unit | fee + winner + sponsor = gross |
| Every refund ticket pays once | successful burn reduces liability by exactly one ticket price |
| Outgoing token failure preserves rights | exact debit/credit check reverts complete transaction |
| Prize leaves at most once | burn or fixed claim plus `prizeClaimed`; retry on revert |
| Callback work is bounded | no token/user call and no sold-ticket loop |
| Admin affects future only | only treasury/pause and ownership writes on factory |
| Onchain state is authoritative | Lens authenticates registry; SDK/subgraph/frontend have no settlement selector |

The complete catalog is in `docs/SECURITY-INVARIANTS.md`. Evidence mapping is not
formal verification.

# Appendix F | Supported Asset Model

## Supported prize assumptions

- deployed contract reporting ERC-721 through ERC-165;
- truthful and stable `ownerOf` behavior;
- available safe transfers and receiver calls;
- no malicious burn, reentry, or upgrade that violates custody;
- metadata and rights independently evaluated.

## Supported quote assumptions

- the factory's chain-specific USDC contract is correct;
- balances are truthful;
- transfers are exact, non-rebasing, and continuously available;
- no fee, tax, sender surcharge, receiver haircut, or unexpected rebase;
- issuer pause, blacklist, and upgrade powers are understood.

## Chain and oracle assumptions

- Base executes EVM semantics and includes transactions;
- timestamps and ordering remain within the chain model;
- the configured Pyth address is authentic;
- the random value is correct under Pyth's external security model;
- fees and callback-gas policy remain operable.

## Explicit exclusions

Issuer freezes, arbitrary malicious token code, dishonest ownership or balance reads,
burned escrowed NFTs, lost keys, arbitrary incapable ticket destinations, unrelated
forced NFTs, forced native value, direct donation recovery, universal censorship, and
chain halt are outside the supported recovery claim.

# Appendix G | Audit and Test Evidence

Document status: Security review status: {{SECURITY_REVIEW_STATUS}}. Independent
external audit: {{INDEPENDENT_AUDIT_STATUS}}.

The internal audit used source identity `{{AUDIT_BASELINE_COMMIT}}` plus dirty-worktree
fingerprint `{{AUDIT_PATCH_FINGERPRINT}}`. The final reviewed implementation is
committed at `{{FINAL_REVIEWED_COMMIT}}`.

Findings: 0 Critical; 4 High fixed; 1 Medium fixed; 2 Low fixed; 1 Informational
accepted. No unresolved Critical, High, or Medium supported-asset finding remained in
the internally reviewed source. This does not imply no unknown vulnerability exists.

Key completed evidence includes 70 default Foundry passes, 660,000 critical fuzz
cases, 10,000 differential sequences, 10,240,000 strict release handler calls, 200,421
Echidna transactions, 113,261 Medusa calls, a 52-mutant 100% killed sample, five Halmos
checks, production coverage of 100% lines/functions and 98.84% branches, static
analysis, gas and size checks, two pinned Base fork tests, and SDK/subgraph/web gates.

Blocked or incomplete evidence: Mythril not executed due Python compatibility;
SMTChecker inconclusive; Certora not configured; no whole-protocol formal proof; no
independent external audit; no monitored testnet campaign.

# Appendix H | Deployment Verification Checklist

No item below should be inferred complete merely because local tests pass.

- [ ] exact final source commit and dependency lock selected;
- [ ] all repository and security gates rerun from a clean checkout;
- [ ] official Base chain ID and current Pyth Entropy address verified from primary
  sources on release day;
- [ ] official Base USDC address, decimals, runtime code, proxy and issuer controls
  verified on release day;
- [ ] exact factory and Lens bytecode compiled with pinned settings;
- [ ] callback gas remeasured against exact deployment bytecode and provider policy;
- [ ] treasury Safe and factory-owner Safe reviewed;
- [ ] ownership acceptance completed and verified;
- [ ] factory quote token, Entropy, callback gas, treasury, owner, pending owner, and
  Lens binding read onchain;
- [ ] verified source reconciled byte-for-byte with deployment;
- [ ] signed deployment record written only after live validation;
- [ ] frontend and subgraph configured to the exact chain and addresses;
- [ ] Base Sepolia monitored through NFT, cash, empty, both failure, partial refund,
  complete refund, recovery-helper, and retry branches;
- [ ] independent external audit completed for exact source and locks;
- [ ] Critical, High, and supported-asset Medium external findings remediated and
  re-reviewed;
- [ ] legal, sanctions, tax, consumer, promotion, gaming, licensing, and age review
  completed for the operating model;
- [ ] monitoring, incident response, private disclosure, and communication runbooks
  staffed.

# Appendix I | Legal and Operational Risks

raffle.fun is experimental software. This paper explains a code state; it is not a
promise, offer, authorization to deploy, or assurance of future performance.

Chance-based prize systems may be regulated differently across jurisdictions. Laws
concerning gambling, lotteries, sweepstakes, contests, consumer protection,
advertising, sanctions, anti-money laundering, tax, licensing, privacy, intellectual
property, and age restrictions may apply. Treatment depends on the sponsor, prize,
participants, jurisdiction, payment model, marketing, and operational facts.

The protocol does not itself guarantee legal compliance. Sponsors, operators, and
users must obtain jurisdiction-specific legal and tax advice. This document is not
legal, tax, investment, or financial advice. Ticket NFTs are chance-based entries and
should not be described as investments.

NFTs and USDC may lose value, become unavailable, be frozen, or fail technically.
Internal testing does not eliminate smart-contract risk. No one should deposit a
valuable asset solely because of this paper.

Operational risks include key loss, malicious signers, wrong-network deployment,
incorrect official addresses, stale frontends, compromised DNS, RPC censorship,
missing monitoring, slow incident communication, and inability to patch existing
raffles.

# Appendix J | Glossary

**Accounted quote balance:** Sum of the four USDC liability categories recorded by a
raffle.

**Active:** Status covering the sale and post-sale request grace before a request.

**Base:** Ethereum-compatible layer-2 network targeted by deployment tooling.

**Bearer right:** A right controlled by current ownership of an unburned ticket.

**Basis point:** 0.01 percentage point.

**Burn:** Destroy an ERC-721 token and clear its ownership record.

**Callback:** Separate Entropy transaction delivering randomness.

**Cash fallback:** Successful below-threshold result with one cash winner and no
general refunds.

**Claim:** Authorized action that moves a recorded asset or liability.

**Closed:** Zero-sales terminal status.

**Constructor deployment:** Independent contract created with configuration fixed at
deployment, rather than a clone or proxy initializer.

**Drawing:** Status with one accepted Entropy sequence pending.

**Entropy:** Pyth service supplying the random callback value.

**Escrow:** Contract custody of the configured prize under fixed functions.

**Exact transfer:** Transfer whose measured sender debit and recipient credit equal the
accounted amount.

**Factory:** Contract that validates, deploys, registers, deposits, and verifies.

**Gas:** Native-currency cost of EVM execution.

**Gross sales:** Ticket price times total tickets ever minted.

**Immutable:** Not changeable through the deployed contract's exposed controls.

**Indexer:** Offchain service reconstructing state and history from events.

**Lens:** Read-only contract aggregating factory-authenticated views.

**Modulo bias:** Tiny distribution difference created when a finite random domain does
not divide evenly by ticket count.

**NftWon:** Successful threshold-met result.

**Nonreentrant:** Guarded against nested entry into protected functions.

**Oracle:** External data service delivering information to a contract.

**Pull claim:** Recorded balance withdrawn later by the claimant.

**Quote token:** Factory-wide USDC used for price and cash accounting.

**Recovery recipient:** Fixed sponsor-side account authorized to claim the prize in
cash, refund, or empty outcomes.

**Refunding:** Liveness-failure status in which current bearers burn for exact refunds.

**Safe transfer:** ERC-721 transfer that calls a contract receiver hook.

**Sequencer:** Base actor that orders layer-2 transactions.

**Sponsor:** Prize depositor, parameter chooser, and successful sponsor-cash claimant.

**Subgraph:** Event-indexed offchain data model.

**Threshold:** Sold-ticket boundary between NFT and cash after successful randomness.

**Transaction:** Signed request for the chain to execute contract code.

**USDC:** The intended factory-wide quote token; issuer-controlled and externally
dependent.

**Wallet:** Key-management and transaction-signing software.

# Appendix K | References

## Primary raffle.fun sources

- Reviewed repository and contract commit: `{{REVIEWED_COMMIT}}`.
- Production contracts: `packages/contracts/src/Raffle.sol`, `RaffleFactory.sol`,
  `RaffleLens.sol`, interfaces, and `RaffleConstants.sol`.
- Executable evidence: `packages/contracts/test/` and generated Hardhat artifacts.
- Internal review: `packages/contracts/audit/`.
- Security invariants: `docs/SECURITY-INVARIANTS.md`.
- Architecture, state, randomness, threat, and deployment notes under `docs/`.
- SDK: `packages/sdk/`; subgraph: `packages/subgraph/`; frontend: `apps/web/`.

## External primary references

- [Solidity documentation](https://docs.soliditylang.org/en/latest/)
- [Solidity security considerations](https://docs.soliditylang.org/en/latest/security-considerations.html)
- [ERC-20 token standard](https://eips.ethereum.org/EIPS/eip-20)
- [ERC-165 interface detection](https://eips.ethereum.org/EIPS/eip-165)
- [ERC-721 non-fungible token standard](https://eips.ethereum.org/EIPS/eip-721)
- [OpenZeppelin Contracts 5.x](https://docs.openzeppelin.com/contracts/5.x/)
- [OpenZeppelin ERC-721 API](https://docs.openzeppelin.com/contracts/5.x/api/token/erc721)
- [OpenZeppelin access-control API](https://docs.openzeppelin.com/contracts/5.x/api/access)
- [Pyth Entropy](https://docs.pyth.network/entropy)
- [Pyth Entropy EVM guide](https://docs.pyth.network/entropy/generate-random-numbers-evm)
- [Pyth request and callback variants](https://docs.pyth.network/entropy/request-callback-variants)
- [Pyth custom callback gas](https://docs.pyth.network/entropy/set-custom-gas-limits)
- [Base protocol overview](https://docs.base.org/base-chain/specs/protocol/overview)
- [Base transaction troubleshooting](https://docs.base.org/base-chain/network-information/troubleshooting-transactions)

References explain standards and dependencies. They do not endorse raffle.fun or
convert the internal review into an independent audit.
