# raffle.fun internal fact registry

**Purpose.** This is the internal source-of-truth register behind the three public
raffle.fun documents. Every substantive claim in the one-pager, the layman's article,
and the technical whitepaper must trace to a Fact ID here. It exists so that a public
claim can never drift ahead of production Solidity.

**Registry commit.** `e65e1e5f89a548ed03a0ebe0a0b722d609244d18`
(branch `claude/smart-contract-docs-sync-c01d89`, working tree clean at capture time).
Unless a fact says otherwise, every "Commit" field refers to this SHA, and every source
line reference is a line number as of this SHA.

**Registry date.** 2026-08-20.

**Candidate identity.** Ethereum v1: one ownerless `RaffleFactory`, one locked `Raffle`
implementation, fixed-target ERC-1167 clones, a factory-fixed six-decimal quote token,
fixed one-dollar entries, one range ticket per purchase, and Chainlink VRF v2.5 native
direct funding.

## Precedence rules used to build this registry

1. **Production Solidity wins.** `packages/contracts/src/*.sol`,
   `packages/contracts/src/interfaces/*.sol`, and
   `packages/contracts/src/libraries/RaffleConstants.sol` are authoritative for onchain
   behavior.
2. **Current normative documentation is second.** `README.md`, `SECURITY.md`, and
   `docs/{ARCHITECTURE,ECONOMICS,RANDOMNESS,STATE-MACHINE,THREAT-MODEL,SECURITY-INVARIANTS,DEPLOYMENT}.md`
   are treated as normative where they agree with Solidity.
3. **Audit reports are historical evidence only**, valid solely for the commit each one
   names. They are never used to describe current behavior.
4. **Removed behavior is not restored.** See section 19 for the specific traps in this
   repository.

<!-- retired-reference:start -->

## Known stale artifacts in this repository (do not quote as current)

| Artifact                                                                                                                                                                                                                                           | Why it is stale                                                                                                                                                                                                     | Correct current source                                         |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `docs/whitepaper/**` (source sections, `src/*.mjs`, `FACT-CHECK.md`, `BUILD.md`)                                                                                                                                                                   | Pipeline and prose for the retired Base/Pyth/Lens generation. The fact generator still requires a `ProtocolOwnedClaim` enum and a `RaffleLens` artifact that no longer exist, so `pnpm docs:whitepaper` cannot run. | This registry; current Solidity.                               |
| `docs/whitepaper/archive/**`                                                                                                                                                                                                                       | Deliberately preserved pre-audit and superseded generations.                                                                                                                                                        | This registry; current Solidity.                               |
| `packages/contracts/audit/INTERNAL-AUDIT.md`, `INDEPENDENT-SPECIFICATION.md`, `FINDINGS.md`, `MUTATION-TESTING.md`, `TEST-CAMPAIGN.md`, `RESIDUAL-RISKS.md`, `STATIC-ANALYSIS.md`, `SYMBOLIC-CHECKS.md`, `FORK-VALIDATION.md`, `AUDIT-BASELINE.md` | Commit-pinned historical evidence for the Base/Pyth per-ticket design.                                                                                                                                              | `packages/contracts/audit/CURRENT-*.md`.                       |
| `packages/contracts/audit/DEEP-TESTING-2026-08-13.md`, `EXTREME-TESTING-2026-08-13.md`, `ETHSKILLS-REVIEW-2026-08-13.md`                                                                                                                           | Campaigns against the retired architecture.                                                                                                                                                                         | `CURRENT-CAMPAIGN.md`, `CURRENT-TEST-MATRIX.md`.               |
| `packages/contracts/audit/RELEASE-READINESS-2026-08-17.md`                                                                                                                                                                                         | Superseded candidate snapshot.                                                                                                                                                                                      | `RELEASE-READINESS-2026-08-18.md`, `V12-REVIEW-2026-08-20.md`. |
| `docs/whitepaper/assets/diagrams/*.svg`                                                                                                                                                                                                            | Generated from the retired design: they draw a Lens, Pyth Entropy, per-ticket minting, and a `Closed` state.                                                                                                        | Mermaid figures in the current documents.                      |

<!-- retired-reference:end -->

> **Evidence-freshness caveat that applies to the whole registry.** The recorded
> internal campaign totals (`CURRENT-CAMPAIGN.md`, `CURRENT-TEST-MATRIX.md`) were
> captured at implementation SHA `92eccb4` and evidence SHA `e9e0e73`, before the hard
> request/callback-boundary remediation, the official Chainlink consumer-base
> migration, the bearer-redemption redesign, and the ownerless-factory change. The
> behavioral facts below are read directly from the current source. The **numeric**
> campaign totals are preserved evidence for those earlier SHAs and must be reproduced
> from a clean checkout of the eventual release SHA. `V12-REVIEW-2026-08-20.md` records
> a full local suite pass at `3da958f` (Foundry 80, Hardhat 21, one RPC-gated skip).

## Evidence tag legend

Tags match `docs/SECURITY-INVARIANTS.md`: `U` unit/boundary, `A` adversarial/regression,
`F` fuzz property, `I` stateful invariant, `E` Echidna, `K` Ethereum mainnet/Sepolia
fork, `X` SDK/subgraph/frontend/deployment/static check.

---

# 1. Factory authority

### RF-001 — The factory is ownerless and has no administrative surface at all

- **Claim.** There is no owner, admin, pause, upgrade, rescue, or configuration setter
  anywhere in the protocol. Not on the factory, and not on any raffle.
- **Technical.** `RaffleFactory is IRaffleFactory, ReentrancyGuard` — no `Ownable`,
  `Ownable2Step`, `AccessControl`, or role library is inherited. The contract declares no
  `onlyOwner` modifier, no setter, and no privileged function. Its entire external
  mutating surface is `createRaffle`.
- **Source.** `packages/contracts/src/RaffleFactory.sol:23,71`;
  `packages/contracts/src/interfaces/IRaffleFactory.sol`.
- **Function / state.** `RaffleFactory.createRaffle`; immutables `quoteToken`,
  `vrfWrapper`, `protocolTreasury`, `raffleImplementation`.
- **Evidence.** `testFactoryConstructorAndCreationValidation` (`U`); ABI-surface checks
  in the Hardhat deployment suite (`X`); SECURITY-INVARIANTS "Factory and initialization".
- **Status.** Current.
- **Caveats.** Ownerlessness removes seizure risk and also removes every remediation
  lever. A discovered defect cannot be patched and creation cannot be paused onchain;
  containment is first-party frontend controls plus migration to a new factory
  (`RF-063`).

### RF-002 — Factory-wide dependencies and economics are immutable

- **Claim.** The quote token, VRF wrapper, treasury, raffle implementation, callback gas
  limit, and confirmation count are fixed when the factory is deployed and can never be
  changed.
- **Technical.** `quoteToken`, `vrfWrapper`, `protocolTreasury`, and
  `raffleImplementation` are `immutable`. `callbackGasLimit` and `requestConfirmations`
  are `constant`, sourced from `RaffleConstants`. No function writes any of them.
- **Source.** `packages/contracts/src/RaffleFactory.sol:24-29,61-67`;
  `packages/contracts/src/libraries/RaffleConstants.sol:26-27`.
- **Function / state.** `quoteToken()`, `vrfWrapper()`, `protocolTreasury()`,
  `raffleImplementation()`, `callbackGasLimit()`, `requestConfirmations()`.
- **Evidence.** `testFactoryAtomicallyEscrowsAndCapturesFixedConfiguration` (`U`);
  `testFactoryCreatesCanonicalClonesWithIsolatedRangeState` (`U`).
- **Status.** Current.
- **Caveats.** Changing any of these requires deploying a new factory. Existing raffles
  are unaffected by, and invisible to, a newer factory.

### RF-003 — The factory constructor validates its own configuration

- **Claim.** A factory cannot be deployed with a non-contract dependency, a zero
  treasury, a wrong-precision quote token, or a treasury pointing at protocol
  infrastructure.
- **Technical.** The constructor requires `quoteToken_` and `vrfWrapper_` to have code,
  rejects a zero treasury, calls `IERC20Metadata.decimals()` inside `try/catch` and
  rejects anything other than `QUOTE_TOKEN_DECIMALS == 6`, then rejects a treasury equal
  to the factory, the quote token, the wrapper, or the freshly deployed implementation.
- **Source.** `packages/contracts/src/RaffleFactory.sol:41-68`;
  `packages/contracts/src/libraries/RaffleConstants.sol:17`.
- **Function / state.** `RaffleFactory.constructor`; errors `NotContract`, `ZeroAddress`,
  `UnsupportedQuoteToken`, `InvalidQuoteTokenDecimals`, `UnsafeProtocolDestination`.
- **Evidence.** `testFactoryConstructorAndCreationValidation` (`U`); Hardhat deployment
  validation (`X`).
- **Status.** Current.
- **Caveats.** A six-decimal `decimals()` return is a self-report. It does not prove the
  address is official USDC, and it does not prove the token transfers exactly. Those are
  deployment-validation and issuer-trust concerns (`RF-055`, `RF-064`). The treasury
  check runs at deployment only: a treasury address that is code-less now and later
  becomes a registered clone is a deployer-misconfiguration trap, not a runtime attack
  path (`RF-070`).

### RF-004 — Creation is permanently permissionless

- **Claim.** Anyone can create a raffle, forever, and nobody can stop them.
- **Technical.** `createRaffle` has no access modifier and no pause flag. It is
  `nonReentrant` and parameter-validated only.
- **Source.** `packages/contracts/src/RaffleFactory.sol:71-123`.
- **Function / state.** `createRaffle(CreateRaffleParams)`.
- **Evidence.** `testFactoryConstructorAndCreationValidation` (`U`);
  Hardhat journey suite (`X`).
- **Status.** Current.
- **Caveats.** Permissionless creation means the registry contains raffles for prizes
  nobody vetted. `isRaffle` proves canonical deployment, never quality or legitimacy of
  the prize collection (`RF-054`).

### RF-005 — The registry is append-only and assigns dense sequential IDs

- **Claim.** Raffle IDs count from 1 with no gaps, and a registration can never be
  removed or rewritten.
- **Technical.** `raffleId = ++raffleCount`, then `raffleById[raffleId]`,
  `idByRaffle[raffle]`, and `isRaffle[raffle]` are written once. No function deletes or
  overwrites a registry entry.
- **Source.** `packages/contracts/src/RaffleFactory.sol:31-34,81,99-101`.
- **Function / state.** `raffleCount`, `raffleById`, `idByRaffle`, `isRaffle`.
- **Evidence.** `testFactoryCreatesCanonicalClonesWithIsolatedRangeState` (`U`);
  `invariantStatusAndTerminalTransitionsAreMonotonic` (`I`); subgraph mapping tests (`X`).
- **Status.** Current.
- **Caveats.** `isRaffle` is the only authentication an integrator should trust. Bytecode
  shape is not proof: an ERC-1167 clone of the same implementation deployed outside the
  factory is unregistered and must be rejected.

---

# 2. Raffle immutability

### RF-006 — Every raffle is a fixed-target ERC-1167 clone of one locked implementation

- **Claim.** Every canonical raffle runs the exact same code, permanently, with no proxy
  admin, beacon, or upgrade path.
- **Technical.** The factory constructor deploys one `Raffle` implementation and stores
  it in the `raffleImplementation` immutable. `createRaffle` uses
  `Clones.clone(raffleImplementation)`, producing a standard 45-byte EIP-1167 minimal
  proxy whose runtime hard-codes the implementation address. There is no implementation
  setter, no beacon, and no CREATE2 salt.
- **Source.** `packages/contracts/src/RaffleFactory.sol:65-67,82`;
  `packages/contracts/src/Raffle.sol:82-93`.
- **Function / state.** `Clones.clone`, `raffleImplementation`.
- **Evidence.** `testFactoryCreatesCanonicalClonesWithIsolatedRangeState` (`U`);
  `testImplementationAndCloneInitializationAreLocked` (`U`); Hardhat clone-target
  regression (`X`).
- **Status.** Current.
- **Caveats.** Clones share the implementation's immutables (`factory`, `quoteToken`,
  `i_vrfV2PlusWrapper`) and hold isolated storage. A clone deployed by anyone other than
  the factory is not registered and cannot be initialized (`RF-007`).

### RF-007 — The implementation is locked and each clone initializes exactly once

- **Claim.** Nobody can seize the shared implementation, and nobody can re-initialize a
  live raffle to change its prize, reserve, deadline, sponsor, or treasury.
- **Technical.** The implementation's constructor sets `initialized = true` and
  `status = Status.Refunding`, so `initialize` reverts with `AlreadyInitialized()` on the
  implementation itself and its zero-liability `Refunding` state makes every other entry
  point inert. On a clone, `initialize` reverts unless `msg.sender == factory`, then sets
  `initialized = true` before writing any configuration.
- **Source.** `packages/contracts/src/Raffle.sol:82-93,96-126`.
- **Function / state.** `initialize(RaffleInitParams)`, `initialized`; errors
  `AlreadyInitialized`, `OnlyFactory`.
- **Evidence.** `testImplementationAndCloneInitializationAreLocked` (`U`);
  `testCloneInitializationRejectsZeroAndProtocolDestinations` (`U`).
- **Status.** Current.
- **Caveats.** The `initialized` write precedes all validation, so a reverted
  initialization reverts the whole atomic creation rather than leaving a half-configured
  clone (`RF-010`).

### RF-008 — An existing raffle has no administrator, pause, rescue, or override

- **Claim.** Once a raffle exists, no party — sponsor, treasury, deployer, or protocol —
  can alter it, cancel it, choose its winner, redirect its prize, or seize its pot.
- **Technical.** `Raffle` exposes no owner, role, pause, upgrade, arbitrary-call, rescue,
  emergency-settlement, or cancellation selector. Every state transition is gated only by
  `status`, `block.timestamp`, ERC-721 ownership, and Chainlink wrapper authentication.
  Payout destinations are the immutable `sponsorRecipient` and `protocolTreasury` or the
  current ticket owner; a caller can never name a destination.
- **Source.** `packages/contracts/src/Raffle.sol` (complete external surface);
  `packages/contracts/src/interfaces/IRaffle.sol:143-176`.
- **Function / state.** Full external ABI.
- **Evidence.** `testSponsorRecipientIsFixedForProceedsAndReturnedPrize` (`U`);
  `testNftSettlementIsPermissionlessAccountingOnlyAndProofIsExact` (`U`);
  `testRegisteredRaffleCannotReceiveTicketsAndSettlementCannotBeRedirected` (`A`);
  ABI-surface checks (`X`).
- **Status.** Current.
- **Caveats.** The sponsor retains exactly one timing privilege: closing an
  **unsold** raffle before its end time (`RF-039`). That cannot touch buyer funds because
  there are none.

### RF-009 — Incident response cannot reach an existing raffle

- **Claim.** If a bug is found after launch, running raffles still run.
- **Technical.** No onchain lever exists: the factory cannot pause creation, existing
  clones cannot be patched, and the implementation cannot be replaced. Response is
  limited to warning users, disabling first-party frontend writes and sponsor
  onboarding, monitoring, and deploying a new factory version.
- **Source.** `packages/contracts/src/RaffleFactory.sol`; `docs/INCIDENT-RESPONSE.md`.
- **Function / state.** None.
- **Evidence.** `docs/INCIDENT-RESPONSE.md`; `CURRENT-RESIDUAL-RISKS.md`
  ("Immutable implementation").
- **Status.** Current.
- **Caveats.** This is a deliberate trade: no admin key to steal, and no admin key to
  save anyone. It must be disclosed in public material, not softened.

---

# 3. Prize escrow

### RF-010 — Creation, registration, escrow, and activation are one atomic transaction

- **Claim.** A raffle exists only if its prize is already locked inside it.
- **Technical.** `createRaffle` validates parameters and the end time, assigns
  `raffleId = ++raffleCount`, clones, initializes, writes all three registry mappings,
  then calls `safeTransferFrom(msg.sender, raffle, prizeTokenId)`, and finally asserts
  **both** `ownerOf(prizeTokenId) == raffle` **and** `IRaffle(raffle).status() == Active`.
  Either post-condition failing reverts with `PrizeEscrowVerificationFailed`, discarding
  the clone, the registry writes, and the logs.
- **Source.** `packages/contracts/src/RaffleFactory.sol:71-123`.
- **Function / state.** `createRaffle`; `PrizeEscrowVerificationFailed`.
- **Evidence.** `testFactoryAtomicallyEscrowsAndCapturesFixedConfiguration` (`U`);
  `testFactoryRejectsPrizesThatDoNotEscrowAndActivateExactly` (`A`);
  `testFactoryReentrancyDuringPrizeEscrowIsBlockedAtomically` (`A`); Hardhat journey (`X`).
- **Status.** Current.
- **Caveats.** The double post-condition is deliberate. `ownerOf` alone would miss a
  token that fires the receiver hook without transferring; the status check alone would
  miss a token that transfers without firing the hook. Both still route through the prize
  contract, so a consistently lying ERC-721 defeats both (`RF-054`).

### RF-011 — No registered raffle can remain in `AwaitingPrize`

- **Claim.** There is no such thing as a listed raffle waiting for its prize.
- **Technical.** `AwaitingPrize` is set by `initialize` and left only by
  `onERC721Received`. Both happen inside `createRaffle`, whose post-condition requires
  `Active`. A raffle that never activates is never registered, because the whole
  transaction reverts.
- **Source.** `packages/contracts/src/Raffle.sol:125,408`;
  `packages/contracts/src/RaffleFactory.sol:107-109`.
- **Function / state.** `Status.AwaitingPrize`, `Status.Active`.
- **Evidence.** `testFactoryRejectsPrizesThatDoNotEscrowAndActivateExactly` (`A`);
  `invariantStatusAndTerminalTransitionsAreMonotonic` (`I`).
- **Status.** Current.
- **Caveats.** The status ordinal `0` still exists in the enum and appears in ABIs. An
  indexer must not treat it as a reachable public state for a registered raffle.

### RF-012 — The prize receiver hook accepts exactly one specific deposit

- **Claim.** Only the configured prize token ID, sent by the sponsor through the factory,
  during creation, is accepted as the prize.
- **Technical.** `onERC721Received` reverts with `UnexpectedPrize` unless all four hold:
  `status == AwaitingPrize`, `msg.sender == address(prizeToken)`,
  `tokenId == prizeTokenId`, `from == sponsor`, and `operator == factory`. On success it
  sets `Active` and emits `PrizeDeposited`.
- **Source.** `packages/contracts/src/Raffle.sol:396-411`.
- **Function / state.** `onERC721Received`; `UnexpectedPrize`.
- **Evidence.** `testFactoryRejectsPrizesThatDoNotEscrowAndActivateExactly` (`A`);
  `testPrizeCannotReenterDuringSponsorSafeTransfer` (`A`).
- **Status.** Current.
- **Caveats.** Because `AwaitingPrize` is unreachable after activation, a second deposit
  of the same token is rejected. An unrelated NFT pushed in with unsafe `transferFrom`
  bypasses the hook entirely, is never accounted, and has no rescue path (`RF-056`).

### RF-013 — The prize leaves escrow at most once

- **Claim.** The NFT can be delivered to the winner, or returned to the sponsor's
  recipient, but never both and never twice.
- **Technical.** A single `prizeClaimed` boolean guards both exits.
  `redeemWinningTicket` (NFT branch) and `releaseSponsorPrize` each check
  `if (prizeClaimed) revert PrizeAlreadyClaimed()` and set it before transferring. Both
  verify delivery with `ownerOf` afterwards and revert on mismatch.
- **Source.** `packages/contracts/src/Raffle.sol:276-284,342-354`.
- **Function / state.** `prizeClaimed`, `PrizeAlreadyClaimed`,
  `PrizeDeliveryVerificationFailed`.
- **Evidence.** `invariantPrizeCustodyMatchesClaimMarker` (`I`);
  `testCashSponsorPrizeRecoveryIsPermissionlessToFixedRecipient` (`U`);
  `testNonCompliantPrizeCannotPassPostDeliveryVerification` (`A`).
- **Status.** Current.
- **Caveats.** `releaseSponsorPrize` is available only in `CashWon` and `Refunding`.
  In `NftWon` the prize is reserved for the winning ticket with no timeout (`RF-036`).

---

# 4. Entry purchase and range tickets

### RF-014 — One entry costs exactly one dollar and there is no purchase cap

- **Claim.** Every raffle number is 1 USDC. Any positive number of entries can be bought
  in one transaction.
- **Technical.** `ENTRY_PRICE = 1_000_000` raw units against a mandated six-decimal quote
  token. `buyEntries` rejects only `entryCount == 0` and a cumulative `uint128` overflow;
  there is no per-purchase quantity ceiling and no protocol gross-sales cap.
  `grossAmount = uint256(entryCount) * ENTRY_PRICE` cannot overflow because `entryCount`
  is `uint128`.
- **Source.** `packages/contracts/src/libraries/RaffleConstants.sol:16-17`;
  `packages/contracts/src/Raffle.sol:38,137-151`.
- **Function / state.** `ENTRY_PRICE`, `buyEntries(address,uint128)`; errors
  `ZeroEntryCount`, `TotalEntriesOverflow`.
- **Evidence.** `testPurchaseMintsOneSequentialTicketForAnyEntryCount` (`U`);
  `testPurchaseMaximumRangeAndOverflowAreAtomic` (`U`);
  `testFuzzPurchaseCreatesOneSequentialTicketWithExactRange` (`F`).
- **Status.** Current.
- **Caveats.** The absence of a value ceiling is deliberate and is an accepted risk, not
  an oversight: exposure can grow far beyond the internal assurance level. `uint128` is a
  machine bound, not a risk control. A frontend cap is bypassable (`RF-066`).

### RF-015 — A purchase requires an active sale strictly before the end time

- **Claim.** Buying works only while the raffle is live, and stops the instant the
  deadline arrives.
- **Technical.** `buyEntries` requires `status == Active` and
  `block.timestamp < endTime`, reverting `SaleEnded(endTime, block.timestamp)` at or
  after the deadline. The sale begins at creation, when the prize deposit sets `Active` —
  there is no scheduled start.
- **Source.** `packages/contracts/src/Raffle.sol:143-144`.
- **Function / state.** `endTime`, `SaleEnded`, `InvalidStatus`.
- **Evidence.** `testSaleEndsButTicketsStayTransferableUntilBurned` (`U`);
  `testSoldRaffleHasHardRequestAndCallbackRefundDeadlines` (`U`).
- **Status.** Current.
- **Caveats.** The sale end is exclusive and the draw-request window opens inclusively at
  the same instant (`RF-026`), so the two abut with no dead interval.

### RF-016 — Incoming payment is verified by exact balance delta

- **Claim.** A token that delivers less — or more — than the stated amount cannot buy
  entries.
- **Technical.** `buyEntries` snapshots `quoteToken.balanceOf(address(this))`, performs
  `safeTransferFrom`, re-reads the balance, computes the saturating delta, and reverts
  `UnsupportedQuoteToken(grossAmount, receivedAmount)` unless the delta equals
  `grossAmount` exactly. The check runs before any state write or mint.
- **Source.** `packages/contracts/src/Raffle.sol:152-156`.
- **Function / state.** `UnsupportedQuoteToken`.
- **Evidence.** `testFalseReturningAndFeeOnTransferQuotesCannotCreateReceipts` (`A`);
  `testOverCreditQuoteCannotSpoofGrossAccounting` (`A`);
  `testReentrantQuoteTokenCannotNestInboundPurchase` (`A`).
- **Status.** Current.
- **Caveats.** This makes fee-on-transfer and rebasing tokens unusable by construction.
  It cannot detect a token that reports honest balances while behaving dishonestly
  elsewhere (`RF-055`).

### RF-017 — One purchase mints exactly one ticket holding an inclusive entry range

- **Claim.** Buying 1 entry or 1,000,000 entries both mint one NFT. The ticket stores the
  first and last number it covers.
- **Technical.** `firstEntry = totalEntries + 1`, `lastEntry = totalEntries + entryCount`,
  `ticketId = ticketCount + 1`. The contract advances `totalEntries` to `lastEntry`,
  increments `ticketCount`, writes
  `_ticketRanges[ticketId] = TicketRange(firstEntry, lastEntry)`, adds the gross to
  `unsettledPot`, and calls `_safeMint(recipient, ticketId)`. There is no per-entry
  mapping and no per-entry mint.
- **Source.** `packages/contracts/src/Raffle.sol:33-36,71,158-168`.
- **Function / state.** `ticketRange(uint256)`, `totalEntries`, `ticketCount`,
  `TicketPurchased`.
- **Evidence.** `testPurchaseMintsOneSequentialTicketForAnyEntryCount` (`U`);
  `testFuzzPurchaseCreatesOneSequentialTicketWithExactRange` (`F`);
  `invariantTicketIdsAreSequential` (`I`);
  `invariantRangesPartitionEverySoldEntryExactlyOnce` (`I`).
- **Status.** Current.
- **Caveats.** `totalEntries` and `ticketCount` advance independently and must not be
  conflated by an indexer. Large counts must stay `bigint` end to end; a JavaScript
  `number` conversion silently corrupts an uncapped `uint128` (`RF-068`).

### RF-018 — Ranges start at one, are contiguous, and never overlap

- **Claim.** Every sold entry belongs to exactly one ticket, with no gaps and no
  duplicates.
- **Technical.** Each new range begins at `totalEntries + 1` and ends at
  `totalEntries + entryCount`, and `totalEntries` is then set to that last value.
  Ranges therefore partition `[1, totalEntries]` exactly.
- **Source.** `packages/contracts/src/Raffle.sol:158-162`.
- **Function / state.** `_ticketRanges`, `totalEntries`.
- **Evidence.** `testFuzzSeparatePurchasesPartitionEntriesWithoutGaps` (`F`);
  `invariantRangesPartitionEverySoldEntryExactlyOnce` (`I`);
  `invariantWinningEntryHasExactlyOneReceiptProof` (`I`).
- **Status.** Current.
- **Caveats.** `ticketRange()` is persistent historical metadata. It keeps returning a
  burned ticket's range, so live-ticket semantics must come from `ownerOf()`
  (`V12-REVIEW-2026-08-20.md`, entry `243760`).

### RF-019 — Cumulative overflow reverts atomically before any payment or mint

- **Claim.** A purchase that would push total entries past the `uint128` domain fails
  cleanly, taking nobody's money.
- **Technical.** `if (entryCount > type(uint128).max - totalEntries) revert
TotalEntriesOverflow(totalEntries, entryCount)` executes before the token transfer and
  before every state write.
- **Source.** `packages/contracts/src/Raffle.sol:147-149`.
- **Function / state.** `TotalEntriesOverflow`.
- **Evidence.** `testPurchaseMaximumRangeAndOverflowAreAtomic` (`U`).
- **Status.** Current.
- **Caveats.** Reaching this bound requires 3.4×10^38 USDC of gross sales. It is a
  correctness guard, not a realistic operating limit.

### RF-020 — A rejecting or reentrant ticket recipient rolls the whole purchase back

- **Claim.** If the buyer's chosen destination cannot receive the NFT, the payment is not
  taken.
- **Technical.** `_safeMint` invokes `onERC721Received` on contract recipients; a revert
  propagates and rolls back the transfer, both counters, the range write, and the pot
  credit. `buyEntries` is `nonReentrant`, so a malicious receiver or reentrant token
  cannot nest a second purchase.
- **Source.** `packages/contracts/src/Raffle.sol:139,167`.
- **Function / state.** `_safeMint`, `nonReentrant`, `InvalidRecipient`.
- **Evidence.** `testPurchaseValidationAndReceiverRollbackAreAtomic` (`U`);
  `testReentrantReceiptReceiverCannotNestPurchase` (`A`);
  `testReentrantQuoteTokenCannotNestInboundPurchase` (`A`).
- **Status.** Current.
- **Caveats.** `_safeMint` protects only against a receiver that _rejects_. A contract
  that accepts the mint and can never transfer or act later strands its own claim
  (`RF-065`).

---

# 5. Bearer tickets

### RF-021 — The ticket is the claim, and it is transferable in every status

- **Claim.** Whoever holds the ticket at redemption time owns the outcome. It can be sold
  or moved at any point in the raffle's life, including after the winner is known.
- **Technical.** `Raffle` is itself the ERC-721 (`name() == "raffle.fun Ticket"`,
  `symbol() == "RAFFLE"`). The `_update` override adds exactly one restriction — a
  non-burn transfer to a known protocol destination reverts — and imposes no
  status-dependent lock whatsoever. There is no draw-time freeze and no post-resolution
  lock on the winning ticket.
- **Source.** `packages/contracts/src/Raffle.sol:30,128-134,383-390`.
- **Function / state.** `_update(address,uint256,address)`, `ownerOf`, `transferFrom`,
  `safeTransferFrom`.
- **Evidence.** `testSaleEndsButTicketsStayTransferableUntilBurned` (`U`);
  `testNftWinningTicketRemainsTransferableUntilOwnerRedeems` (`U`);
  `testCashSettlementLeavesBearerClaimAndOwnerRedeemsOnce` (`U`);
  `testFuzzPostSettlementBearerCanRedeemNft` (`F`).
- **Status.** Current. **This reverses the retired design's transfer-lock lattice** — see
  section 19.
- **Caveats.** A secondary market can trade a _known-winning_ ticket after settlement.
  That is intended: settlement allocates liabilities without reading ownership, so the
  claim travels with the token.

### RF-022 — Redemption and refund require ownership, not approval

- **Claim.** An approved operator or marketplace cannot redeem or refund on the owner's
  behalf. Possession of the token is the credential.
- **Technical.** `redeemWinningTicket` reads `address winner = ownerOf(ticketId)` and
  reverts `NotTicketOwner` unless `msg.sender == winner`. `refundTickets` performs the
  same check per ticket in the batch. Neither consults `getApproved` or
  `isApprovedForAll`.
- **Source.** `packages/contracts/src/Raffle.sol:267-268,306-307`.
- **Function / state.** `NotTicketOwner`.
- **Evidence.** `testOwnerCanSettleAndRedeemAtomicallyButApprovedOperatorCannot` (`U`);
  `testRefundBatchValidationAndMixedOwnershipAreAtomic` (`U`).
- **Status.** Current.
- **Caveats.** Deliberate. An approval is a transfer right, not a claim right; an
  operator wanting to redeem must first take the token.

### RF-023 — Every claim right is consumed by burning, and a failed delivery restores it

- **Claim.** A ticket pays out exactly once, and a payout that fails does not destroy the
  ticket.
- **Technical.** `redeemWinningTicket` sets `winnerRedeemed`, `_burn`s the ticket, then
  transfers. `refundTickets` burns each ticket, decrements
  `remainingRefundLiability`, then transfers. Both run under `nonReentrant`, and every
  transfer is verified (`ownerOf` post-check for the NFT, exact two-sided deltas for the
  quote). Any verification failure reverts the burn and every accompanying state change.
- **Source.** `packages/contracts/src/Raffle.sol:256-293,296-319,475-492`.
- **Function / state.** `winnerRedeemed`, `_burn`, `_transferQuoteExact`.
- **Evidence.** `testWinnerRedeemsAndFixedProceedsReleaseIndependently` (`U`);
  `testNftDeliveryFailureRollsBackLazySettlementAndBurn` (`A`);
  `testOutboundClaimFailureRestoresClaimAndAccounting` (`A`);
  `testFuzzRefundPaysWeightedRangeExactlyOnce` (`F`);
  `invariantSettlementAndRedemptionMarkersMatchTicketState` (`I`).
- **Status.** Current.
- **Caveats.** Rollback preserves the claim for a later retry. It cannot make an
  unavailable token or a frozen prize collection transfer (`RF-054`, `RF-055`).

### RF-024 — Losing tickets survive settlement as transferable souvenirs

- **Claim.** Non-winning tickets are never burned and remain valid ERC-721 tokens worth
  nothing.
- **Technical.** Only `redeemWinningTicket` and `refundTickets` burn. In `NftWon` and
  `CashWon` no other ticket is touched, so every losing ticket keeps its owner, its
  stored range, and its transferability forever.
- **Source.** `packages/contracts/src/Raffle.sol:272,311`.
- **Function / state.** `_burn`, `ticketRange`.
- **Evidence.** `invariantSettlementAndRedemptionMarkersMatchTicketState` (`I`);
  subgraph ticket-state tests (`X`).
- **Status.** Current.
- **Caveats.** A marketplace integration must not present a losing ticket as a live
  claim. Key on `status`, `winningEntry`, and the ticket's own range.

### RF-025 — Tickets and payouts reject known protocol destinations

- **Claim.** You cannot send a ticket, a payout, or a prize into the protocol's own
  plumbing, where it would become unreachable.
- **Technical.** `_isKnownProtocolDestination(d)` is true when `d` is the raffle itself,
  the factory, the quote token, the VRF wrapper, the prize token, or the shared
  implementation — and, when `d` already has code, when
  `IRaffleFactory(factory).isRaffle(d)` returns true. It is applied in `_update` (for
  non-burn transfers) and in `_transferQuoteExact`. A constructor-time analogue,
  `_isInitializationProtocolDestination`, screens `sponsor`, `sponsorRecipient`, and
  `protocolTreasury` at initialization, and `_validateCreateParams` applies the same
  test to `prizeToken` and `sponsorRecipient` at the factory.
- **Source.** `packages/contracts/src/Raffle.sol:107-115,387-390,476,498-520`;
  `packages/contracts/src/RaffleFactory.sol:125-140`.
- **Function / state.** `UnsafeProtocolDestination`, `InvalidQuoteDestination`.
- **Evidence.** `testProtocolDestinationsCannotReceiveReceiptsOrPayouts` (`A`);
  `testCloneInitializationRejectsRegisteredRaffleSponsorAndTreasury` (`U`);
  `testRegisteredRaffleCannotReceiveTicketsAndSettlementCannotBeRedirected` (`A`).
- **Status.** Current.
- **Caveats.** Two documented limits. First, the `isRaffle` branch fires only when the
  destination **already has code**: an address that is code-less today and later becomes a
  registered clone is unsupported, and a holder who deliberately sends a ticket to such a
  predicted address strands only their own claim (`RF-065`, `V12` entries `243748`,
  `243749`, `243759`). Second, screening is **same-factory only** — a different factory's
  registry is invisible. Every transfer to a code-bearing address costs one external
  `isRaffle` call; batching integrators should budget for it.

---

# 6. Sale, request, and callback boundaries

### RF-026 — The sale end is exclusive and the request window opens at it

- **Claim.** Sales stop at the deadline and the draw becomes requestable at the same
  instant.
- **Technical.** `buyEntries` requires `block.timestamp < endTime`. `requestDraw`
  requires `block.timestamp >= endTime`. The windows abut exactly.
- **Source.** `packages/contracts/src/Raffle.sol:144,189`.
- **Function / state.** `endTime`, `SaleEnded`, `RaffleNotEnded`.
- **Evidence.** `testSoldRaffleHasHardRequestAndCallbackRefundDeadlines` (`U`);
  `invariantDrawAndCallbackDeadlinesAreHardAndOrdered` (`I`).
- **Status.** Current.
- **Caveats.** Boundaries are `block.timestamp` comparisons and inherit validator
  timestamp latitude.

### RF-027 — The sale may not exceed thirty days and must be in the future

- **Claim.** A sponsor picks any deadline up to 30 days out; the sale starts immediately
  on creation.
- **Technical.** `createRaffle` reverts `InvalidEndTime` when
  `params.endTime <= block.timestamp` and `SaleDurationTooLong` when
  `endTime - now > MAX_SALE_DURATION == 30 days`. There is no start delay parameter.
- **Source.** `packages/contracts/src/RaffleFactory.sol:74-79`;
  `packages/contracts/src/libraries/RaffleConstants.sol:22`.
- **Function / state.** `MAX_SALE_DURATION`, `InvalidEndTime`, `SaleDurationTooLong`.
- **Evidence.** `testFactoryAcceptsExactMaximumSaleDuration` (`U`);
  `testFactoryConstructorAndCreationValidation` (`U`).
- **Status.** Current.
- **Caveats.** `endTime` is `uint64`; on Ethereum, execution-payload timestamps are also
  `uint64`, so the cast in `requestDraw`/`fulfillRandomWords` cannot wrap for any valid
  block (`V12` entries `243751`, `243752`).

### RF-028 — The draw-request window is exactly two days and hard-closed

- **Claim.** After the sale ends, anyone has two days to start the draw. At the two-day
  mark the door shuts.
- **Technical.** `drawRequestDeadline() = endTime + DRAW_REQUEST_TIMEOUT`, with
  `DRAW_REQUEST_TIMEOUT = 2 days`. `requestDraw` reverts
  `DrawRequestWindowExpired` when `block.timestamp >= requestDeadline`, so the window is
  the half-open interval `[endTime, drawRequestDeadline())`.
- **Source.** `packages/contracts/src/Raffle.sol:191-194,364-366`;
  `packages/contracts/src/libraries/RaffleConstants.sol:23`.
- **Function / state.** `drawRequestDeadline()`, `DrawRequestWindowExpired`.
- **Evidence.** `testSoldRaffleHasHardRequestAndCallbackRefundDeadlines` (`U`);
  `invariantDrawAndCallbackDeadlinesAreHardAndOrdered` (`I`); independent Python model.
- **Status.** Current.
- **Caveats.** A request at exactly the deadline is invalid, and refunds open at exactly
  the same instant (`RF-040`). The two are mutually exclusive by construction, not by
  race.

### RF-029 — An accepted request gets its own two-day callback window

- **Claim.** Once the draw is requested, Chainlink has two days to answer.
- **Technical.** `requestDraw` records `drawRequestedAt = block.timestamp` before calling
  the wrapper. `callbackDeadline() = drawRequestedAt + DRAW_CALLBACK_TIMEOUT` with
  `DRAW_CALLBACK_TIMEOUT = 2 days`, and returns `0` before any request. A callback
  resolves only when `block.timestamp < callbackDeadline()`.
- **Source.** `packages/contracts/src/Raffle.sol:200,368-371,426`;
  `packages/contracts/src/libraries/RaffleConstants.sol:24`.
- **Function / state.** `drawRequestedAt`, `callbackDeadline()`.
- **Evidence.** `testCallbackDeadlineIsHardAtEqualityRegardlessOfOrdering` (`U`);
  `testAuthenticatedValidCallbackAtDeadlineIsIgnoredBeforeRefunds` (`A`);
  `invariantDrawAndCallbackDeadlinesAreHardAndOrdered` (`I`).
- **Status.** Current.
- **Caveats.** A request included at `drawRequestDeadline() - 1` receives a full fresh
  two-day window, so the last nominal boundary is just under **four days** after sale
  end even though each individual window is two days.

---

# 7. Draw request (Chainlink VRF v2.5)

### RF-030 — Anyone may request the draw, once, by paying the live native fee

- **Claim.** The draw is permissionless. The requester pays Chainlink in ETH; the USDC
  pot is never touched.
- **Technical.** `requestDraw` is `external payable nonReentrant` with no caller
  restriction. It quotes
  `i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1)`, requires
  `msg.value >= quotedFee`, writes `status = Drawing` **before** the external call so a
  second request fails the `Active` check, and calls
  `requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, 1, extraArgs)`
  with `ExtraArgsV1.nativePayment = true`.
- **Source.** `packages/contracts/src/Raffle.sol:172-179,187-220`.
- **Function / state.** `requestDraw()`, `getVrfRequestPrice()`,
  `estimateVrfRequestPrice(uint256)`, `InsufficientVrfFee`.
- **Evidence.** `testDrawForwardsExactDynamicFeeAndRefundsExcess` (`U`);
  `testDrawUsesFixedThirtyConfirmationsAndOneWord` (`U`);
  `testQuotedFeeCanChangeWithoutConsumingRequest` (`A`);
  `testWrapperRequestReentryIsRejected` (`A`).
- **Status.** Current.
- **Caveats.** Nobody is obliged to pay. The economic assumption is that a ticket holder
  or the sponsor is motivated to; if nobody does, the raffle refunds in full at the
  request deadline (`RF-040`). There is no protocol keeper and no fee reimbursement.

### RF-031 — Excess native value is returned in the same transaction or the request reverts

- **Claim.** Overpaying the VRF fee is safe: the difference comes straight back.
- **Technical.** After the wrapper returns `paidPrice`, the raffle reverts if
  `paidPrice > msg.value`, then returns `excess = msg.value - paidPrice` with a raw
  assembly `call` using `retOffset = retSize = 0` (no return-data copy, neutralizing a
  return-data bomb). A failed return reverts the whole request with `NativeRefundFailed`.
  `receive()` reverts with `DirectNativeTransfer`, so the raffle never holds an ETH
  balance outside this path.
- **Source.** `packages/contracts/src/Raffle.sol:205-219,413-415`.
- **Function / state.** `NativeRefundFailed`, `DirectNativeTransfer`, `DrawRequested`.
- **Evidence.** `testDrawForwardsExactDynamicFeeAndRefundsExcess` (`U`);
  `testOfficialHelperRefundsAgainstActualLowerPrice` (`A`);
  `testOfficialHelperCannotUseForcedNativeToSubsidizeQuoteDrift` (`A`);
  `testDonationsAndForcedNativeDoNotAlterQuoteAccounting` (`U`).
- **Status.** Current.
- **Caveats.** Native currency forced in with `SELFDESTRUCT` sits outside accounting and
  has no rescue path (`RF-056`).

### RF-032 — A failed fee read or failed request leaves the raffle `Active` and refundable

- **Claim.** A broken or reverting oracle call does not consume the raffle's one draw
  attempt.
- **Technical.** Neither the price read nor the wrapper request is wrapped in
  `try/catch`, so any failure reverts the whole transaction, restoring `Active`,
  `drawRequestedAt == 0`, and `vrfRequestId == 0`. The request window is preserved for a
  retry, and if it expires the raffle still has its full-refund path.
- **Source.** `packages/contracts/src/Raffle.sol:196-207`.
- **Function / state.** `status`, `vrfRequestId`, `drawRequestedAt`.
- **Evidence.** `testFeeReadAndRequestFailuresRollBackToActiveThenRefundAtDeadline` (`A`);
  `testNonPersistedRequestStillHasBoundedFullRefundRecovery` (`A`);
  `testMetadataPriceEstimateAndDrawFailureBoundaries` (`U`).
- **Status.** Current.
- **Caveats.** Repeated wrapper failure through the whole two-day window converts the
  raffle to refunds. That returns entry value; it does not produce the intended draw.

### RF-033 — VRF parameters are fixed and shared by every raffle

- **Claim.** Every raffle asks Chainlink for the same thing: one word, 30 confirmations,
  300,000 callback gas, paid in ETH.
- **Technical.** `callbackGasLimit = VRF_CALLBACK_GAS_LIMIT = 300_000` and
  `requestConfirmations = VRF_REQUEST_CONFIRMATIONS = 30` are `constant` on both the
  raffle and the factory. The word count is the literal `1` at both the quote and the
  request, so quote and request can never disagree.
- **Source.** `packages/contracts/src/Raffle.sol:39-40,173,204`;
  `packages/contracts/src/libraries/RaffleConstants.sol:26-27`.
- **Function / state.** `callbackGasLimit()`, `requestConfirmations()`.
- **Evidence.** `testDrawUsesFixedThirtyConfirmationsAndOneWord` (`U`);
  `testBothCallbackBranchesStayBelowGasBudget` (`U`); Hardhat journey (`X`).
- **Status.** Current.
- **Caveats.** 300,000 is a gas-**unit** ceiling for callback execution, not a gas-price
  ceiling. Network price spikes raise the wrapper's native quote; they do not shrink the
  allowance. Deployment validation must confirm the consumer limit plus wrapper overhead
  plus Chainlink's EIP-150 compensation, `floor(callbackGasLimit / 63) + 1`, fits the
  live coordinator maximum (`CURRENT-FINDINGS.md`, `V1-DEPLOY-01`).

### RF-034 — The raffle uses the official pinned Chainlink consumer base

- **Claim.** raffle.fun does not roll its own oracle, wrapper, or subscription manager.
- **Technical.** `Raffle is … VRFV2PlusWrapperConsumerBase` and uses
  `IVRFV2PlusWrapper` and `VRFV2PlusClient` from the exact-pinned
  `@chainlink/contracts@1.5.0`. Native direct funding pays the existing official wrapper
  per request, so no raffle creates or manages a VRF subscription. The wrapper address is
  validated non-zero at construction and held `immutable`.
- **Source.** `packages/contracts/src/Raffle.sol:4-6,30,84,522-525`;
  `packages/contracts/package.json:28`.
- **Function / state.** `vrfWrapper()`, `i_vrfV2PlusWrapper`.
- **Evidence.** `testEthereumMainnetChainlinkVrfUsdcAndRangeReceipt` (`K`);
  `testEthereumSepoliaChainlinkVrfUsdcAndRangeReceipt` (`K`); deployment validation (`X`).
- **Status.** Current.
- **Caveats.** Both fork cases are RPC-gated and were **skipped** in the recorded local
  runs. No RPC-backed execution is claimed for this candidate (`RF-062`). A counterfeit
  configured wrapper could choose words outright, which is why deployment validation
  pinning the official address is a mandatory control (`V12` entry `243758`).

---

# 8. Callback authentication and winner selection

### RF-035 — Only the immutable wrapper can deliver a callback, and only one shape qualifies

- **Claim.** Nobody can fake a draw result, and no late, stale, duplicated, or malformed
  callback can change the outcome.
- **Technical.** Authentication is layered. Transport: the inherited
  `rawFulfillRandomWords` accepts only `i_vrfV2PlusWrapper`; anything else reverts.
  Decoding: calldata that cannot ABI-decode reverts in Solidity before the handler runs.
  Application: `fulfillRandomWords` returns early — emitting `VrfCallbackIgnored` — if
  `_requestInFlight`, `status != Drawing`, `requestId != vrfRequestId`,
  `randomWords.length != 1`, or `block.timestamp >= callbackDeadline()`.
- **Source.** `packages/contracts/src/Raffle.sol:73,201,207,417-438`.
- **Function / state.** `fulfillRandomWords`, `_requestInFlight`, `VrfCallbackIgnored`.
- **Evidence.** `testWrongDuplicateMalformedAndUnauthorizedCallbacksAreHarmless` (`A`);
  `testSynchronousWrongDuplicateAndValidCallbacksCannotResolveInFlightRequest` (`A`);
  `testMalformedAndWrongCallbacksAreIgnoredUntilOneValidWordArrives` (`A`);
  `testZeroRequestIdDoesNotMatchUntilRequestReturns` (`A`);
  `testRepeatedRequestIdsRemainRaffleScoped` (`A`);
  `testAuthenticatedValidCallbackAtDeadlineIsIgnoredBeforeRefunds` (`A`).
- **Status.** Current.
- **Caveats.** Rejection **returns rather than reverts**, deliberately, so a rejected
  delivery has no provider-side consequence. The trade-off is that a rejection is visible
  only as an event: monitoring must alert on `VrfCallbackIgnored`. The subgraph indexes
  it as an immutable diagnostic with a per-raffle counter (`CURRENT-FINDINGS.md`,
  `V1-SUBGRAPH-01`, closed).

### RF-036 — The in-flight guard blocks a synchronous callback

- **Claim.** A wrapper that calls back _during_ the request cannot settle before the
  raffle knows its own request ID.
- **Technical.** `_requestInFlight` is set true immediately before
  `requestRandomnessPayInNative` and cleared immediately after `vrfRequestId` is stored.
  While it is true, `fulfillRandomWords` ignores every delivery, including an otherwise
  valid one.
- **Source.** `packages/contracts/src/Raffle.sol:201,206-207,425`.
- **Function / state.** `_requestInFlight`, `vrfRequestId`.
- **Evidence.** `testSynchronousWrongDuplicateAndValidCallbacksCannotResolveInFlightRequest`
  (`A`); `testZeroRequestIdDoesNotMatchUntilRequestReturns` (`A`).
- **Status.** Current.
- **Caveats.** None known. This closes the window in which `vrfRequestId` is still zero.

### RF-037 — The callback records only a number and a branch, with no external call

- **Claim.** Resolution moves no money, touches no NFT, calls no user, and does not
  search tickets.
- **Technical.** A qualifying callback computes
  `winningEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1)`, sets
  `resolvedAt`, sets `status = totalEntries >= reserveEntries ? NftWon : CashWon`, and
  emits `RaffleResolved`. There is no loop, no ERC-20 or ERC-721 interaction, and no call
  to any user-controlled address.
- **Source.** `packages/contracts/src/Raffle.sol:423-438`.
- **Function / state.** `winningEntry`, `resolvedAt`, `status`, `RaffleResolved`.
- **Evidence.** `testCallbackStoresInclusiveWinningEntryAndSelectsReserveBoundary` (`U`);
  `testCallbackMakesNoQuoteOrPrizeExternalTransfers` (`A`);
  `testCallbackGasDoesNotScaleWithReceiptCount` (`U`);
  `testBothCallbackBranchesStayBelowGasBudget` (`U`);
  `testFuzzWinningEntryAlwaysUsesInclusiveSoldRange` (`F`).
- **Status.** Current.
- **Caveats.** This is what makes the 300,000-unit limit safe regardless of how many
  entries or tickets exist.

### RF-038 — Reserve equality selects the NFT branch

- **Claim.** Hitting the reserve exactly counts as success.
- **Technical.** The comparison is `totalEntries >= reserveEntries`. `reserveEntries` is
  `uint128`, must be non-zero at creation, and is unbounded above.
- **Source.** `packages/contracts/src/Raffle.sol:435`;
  `packages/contracts/src/RaffleFactory.sol:149`.
- **Function / state.** `reserveEntries`, `Status.NftWon`, `Status.CashWon`,
  `ZeroReserveEntries`.
- **Evidence.** `testCallbackStoresInclusiveWinningEntryAndSelectsReserveBoundary` (`U`);
  `testFuzzReserveEqualityIsNftAndOneBelowIsCash` (`F`); independent Python model.
- **Status.** Current.
- **Caveats.** The reserve is **not** a sell-out cap: the raffle keeps accepting entries
  past it until the deadline. A sponsor may set an unreachable reserve to force the cash
  branch deterministically; frontends should surface that.

### RF-039 — The winner is `(randomWord mod totalEntries) + 1`, with negligible modulo bias

- **Claim.** One entry number in `[1, totalEntries]` is selected, and the mapping is not
  perfectly uniform.
- **Technical.** `(random mod n) + 1` over a 256-bit domain is non-uniform whenever
  `n` does not divide `2^256`. The absolute per-entry probability difference is on the
  order of `2^-256`. No rejection sampling is performed; it would require an unbounded
  callback loop or a second oracle round.
- **Source.** `packages/contracts/src/Raffle.sol:432`.
- **Function / state.** `winningEntry`.
- **Evidence.** `testFuzzWinningEntryAlwaysUsesInclusiveSoldRange` (`F`);
  `invariantWinningEntryHasExactlyOneReceiptProof` (`I`).
- **Status.** Current.
- **Caveats.** The bias is cryptographically negligible but **not zero**. Public material
  must not claim perfect uniformity, and must not describe the protocol as "provably
  fair".

### RF-040 — A resolved result is final and can never become refunds

- **Claim.** Once the draw resolves, it stays resolved. There is no post-result refund
  timeout in either branch.
- **Technical.** `enableRefunds` dispatches only on `Active` and `Drawing`; any other
  status, including `NftWon` and `CashWon`, reverts `InvalidStatus`. Correspondingly,
  once `status` leaves `Drawing`, `fulfillRandomWords` ignores every further callback.
- **Source.** `packages/contracts/src/Raffle.sol:223-248,425`.
- **Function / state.** `enableRefunds()`, `InvalidStatus`.
- **Evidence.** `testAcceptedDrawCannotRefundBeforeCallbackDeadlineAndValidNftOutcomeNeverRefunds`
  (`U`); `invariantStatusAndTerminalTransitionsAreMonotonic` (`I`); independent model.
- **Status.** Current. **This removes the retired design's 30-day NFT-redemption refund
  fallback** — see section 19.
- **Caveats.** This is the sharpest consequence of the bearer redesign. If the prize
  collection is later paused, frozen, or hostile, the winner's NFT claim can be blocked
  indefinitely and buyers are **not** refunded. The sponsor and treasury quote claims
  remain independently releasable. Prize-collection review is therefore a material
  product control, not optional metadata (`RF-054`, `V12` entry `243754`).

---

# 9. Settlement and redemption

### RF-041 — Settlement is permissionless, transfer-free, and ownership-blind

- **Claim.** Anyone can prove which ticket holds the winning number and lock in the
  money split. Doing so moves nothing and does not read who owns the ticket.
- **Technical.** `settleWinningTicket(ticketId)` requires a resolved status, requires
  `!settlementComplete`, and calls `_requireWinningTicket`, which loads the stored range
  and reverts `TicketDoesNotContainWinningEntry` unless
  `firstEntry <= winningEntry <= lastEntry`. It then records `winningTicketId`, zeroes
  `unsettledPot`, and writes `sponsorProceeds`, `protocolFees`, and (cash branch)
  `winnerProceeds`. It never calls `ownerOf`, never burns, and makes no external asset
  call.
- **Source.** `packages/contracts/src/Raffle.sol:251-253,440-473`.
- **Function / state.** `settleWinningTicket`, `settlementComplete`, `winningTicketId`,
  `WinningTicketSettled`; errors `SettlementAlreadyComplete`,
  `TicketDoesNotContainWinningEntry`.
- **Evidence.** `testNftSettlementIsPermissionlessAccountingOnlyAndProofIsExact` (`U`);
  `testFuzzOnlyContainingReceiptCanSettle` (`F`);
  `testRegisteredRaffleCannotReceiveTicketsAndSettlementCannotBeRedirected` (`A`);
  `invariantWinningEntryHasExactlyOneReceiptProof` (`I`).
- **Status.** Current. **This splits settlement from redemption**, which the retired
  design fused — see section 19.
- **Caveats.** Winner proof is O(1): one storage read and two comparisons, independent of
  entry or ticket count. Exactly one ticket can satisfy it, because ranges partition the
  sold entries (`RF-018`).

### RF-042 — Only the winning ticket's current owner may redeem, and it burns atomically

- **Claim.** The person holding the winning ticket when they call redeem gets the prize,
  in the same transaction that destroys the ticket.
- **Technical.** `redeemWinningTicket(ticketId)` rejects a second redemption
  (`winnerRedeemed`), requires `NftWon` or `CashWon`, settles first if settlement has not
  happened, otherwise requires `ticketId == winningTicketId`
  (`WinningTicketMismatch`). It reads `ownerOf(ticketId)`, requires the caller to be that
  owner, records `winnerRecipient`, sets `winnerRedeemed`, `_burn`s, and then delivers.
- **Source.** `packages/contracts/src/Raffle.sol:256-293`.
- **Function / state.** `redeemWinningTicket`, `winnerRecipient`, `winnerRedeemed`,
  `WinningTicketRedeemed`; errors `WinningTicketAlreadyRedeemed`, `WinningTicketMismatch`,
  `NotTicketOwner`.
- **Evidence.** `testOwnerCanSettleAndRedeemAtomicallyButApprovedOperatorCannot` (`U`);
  `testCashSettlementLeavesBearerClaimAndOwnerRedeemsOnce` (`U`);
  `testNftWinningTicketRemainsTransferableUntilOwnerRedeems` (`U`);
  `testFuzzPostSettlementBearerCanRedeemNft` (`F`).
- **Status.** Current.
- **Caveats.** The one-transaction settle-and-redeem path exists so a winner never has to
  depend on a third party settling first. A caller cannot name a destination: delivery
  always goes to the ticket's owner.

### RF-043 — NFT delivery uses `transferFrom` and is verified afterwards

- **Claim.** A contract holding the winning ticket cannot veto its own prize by
  rejecting a receiver hook — but delivery is still proven.
- **Technical.** The NFT branch sets `prizeClaimed`, calls
  `prizeToken.transferFrom(address(this), winner, prizeTokenId)` — deliberately not
  `safeTransferFrom` — then requires `prizeToken.ownerOf(prizeTokenId) == winner`,
  reverting `PrizeDeliveryVerificationFailed` otherwise. A revert rolls back the burn and
  every redemption state change.
- **Source.** `packages/contracts/src/Raffle.sol:276-284`.
- **Function / state.** `PrizeDeliveryVerificationFailed`, `prizeClaimed`.
- **Evidence.** `testNftDeliveryFailureRollsBackLazySettlementAndBurn` (`A`);
  `testNonCompliantPrizeCannotPassPostDeliveryVerification` (`A`);
  `testPrizeCannotReenterDuringWinnerTransfer` (`A`);
  `testPrizeDeliveryFailureBlocksOnlyWinnerPrizeAndNotSettlementOrCashClaims` (`A`).
- **Status.** Current.
- **Caveats.** The trade-off is explicit: a contract winner that can never itself
  transfer an ERC-721 may strand its own prize. Frontends must warn contract recipients
  before a ticket is acquired. `ownerOf` verification routes through the same contract
  that could be lying (`RF-054`).

### RF-044 — Sponsor proceeds, protocol fees, and the returned prize release independently

- **Claim.** One stuck party cannot block the others.
- **Technical.** `releaseSponsorProceeds`, `releaseProtocolFees`, and
  `releaseSponsorPrize` are three separate permissionless functions. Each zeroes its own
  balance before transferring and pays only the immutable `sponsorRecipient` or
  `protocolTreasury`. `releaseSponsorPrize` is available in `CashWon` and `Refunding`.
- **Source.** `packages/contracts/src/Raffle.sol:322-354`.
- **Function / state.** `sponsorProceeds`, `protocolFees`; errors `NoSponsorProceeds`,
  `NoProtocolFees`, `SponsorPrizeUnavailable`.
- **Evidence.** `testWinnerRedeemsAndFixedProceedsReleaseIndependently` (`U`);
  `testSponsorRecipientIsFixedForProceedsAndReturnedPrize` (`U`);
  `testCashSponsorPrizeRecoveryIsPermissionlessToFixedRecipient` (`U`);
  `testPrizeDeliveryFailureBlocksOnlyWinnerPrizeAndNotSettlementOrCashClaims` (`A`).
- **Status.** Current.
- **Caveats.** "Permissionless" means anyone may _trigger_ the payment; the caller cannot
  redirect it. A sponsor who nominated an incapable `sponsorRecipient` strands only their
  own value (`V12` entries `243753`, `243756`).

---

# 10. Economics

### RF-045 — The protocol fee is 5% of gross, floored, and charged only on a resolved result

- **Claim.** The protocol takes 5% when a raffle resolves, and nothing at all when it
  refunds.
- **Technical.** `protocolFee = Math.mulDiv(grossPot, PROTOCOL_FEE_BPS, BPS)` with
  `PROTOCOL_FEE_BPS = 500` and `BPS = 10_000`, computed once in `_settleWinningTicket`
  over the whole pot rather than per purchase. `enableRefunds` moves the entire
  `unsettledPot` into `remainingRefundLiability` and records no fee.
- **Source.** `packages/contracts/src/Raffle.sol:243-247,447`;
  `packages/contracts/src/libraries/RaffleConstants.sol:11-12`.
- **Function / state.** `protocolFees`, `PROTOCOL_FEE_BPS`.
- **Evidence.** `testFuzzCashSplitAlwaysConservesEightyFifteenFive` (`F`);
  `testFuzzNoRequestTimeoutPaysFullWeightedRange` (`F`);
  `invariantBranchEconomicsRemainEightyFifteenFiveNinetyFiveFiveOrFullRefund` (`I`).
- **Status.** Current.
- **Caveats.** Neither rate can be changed for an existing raffle by any party, because
  both are compile-time constants (`RF-002`).

### RF-046 — NFT branch: 95% to the sponsor, 5% to the protocol, NFT to the ticket

- **Claim.** When the reserve is met the sponsor sells at their number and the winner
  gets the NFT.
- **Technical.** In `_settleWinningTicket` with `result == NftWon`,
  `sponsorAmount = grossPot - protocolFee` and `winnerProceeds` stays zero. The prize
  remains escrowed for the ticket's current owner.
- **Source.** `packages/contracts/src/Raffle.sol:450-451,458-462`.
- **Function / state.** `sponsorProceeds`, `protocolFees`.
- **Evidence.** `testNftSettlementIsPermissionlessAccountingOnlyAndProofIsExact` (`U`);
  `invariantBranchEconomicsRemainEightyFifteenFiveNinetyFiveFiveOrFullRefund` (`I`);
  independent Python model.
- **Status.** Current.
- **Caveats.** The sponsor's 95% is uncapped above the reserve: selling past the reserve
  pays the sponsor more, and still delivers the NFT.

### RF-047 — Cash branch: 80% to the ticket, 5% to the protocol, 15% + NFT to the sponsor

- **Claim.** When the reserve is missed the sponsor keeps the NFT and still earns, and
  the drawn ticket takes the largest share of the pot.
- **Technical.** With `result == CashWon`,
  `cashAmount = Math.mulDiv(grossPot, CASH_WINNER_BPS, BPS)` where
  `CASH_WINNER_BPS = 8000`, and
  `sponsorAmount = grossPot - protocolFee - cashAmount`. All three shares are taken from
  **gross**, so the sponsor's remainder is exactly 15% before rounding. The NFT becomes
  releasable to `sponsorRecipient`.
- **Source.** `packages/contracts/src/Raffle.sol:452-456`;
  `packages/contracts/src/libraries/RaffleConstants.sol:13`.
- **Function / state.** `winnerProceeds`, `sponsorProceeds`, `protocolFees`,
  `CASH_WINNER_BPS`.
- **Evidence.** `testCashSettlementLeavesBearerClaimAndOwnerRedeemsOnce` (`U`);
  `testFuzzCashSplitAlwaysConservesEightyFifteenFive` (`F`);
  `testFuzzReserveEqualityIsNftAndOneBelowIsCash` (`F`); independent Python model.
- **Status.** Current. **The split is 80/5/15 of gross**, not of a post-fee pot — see
  section 19.
- **Caveats.** Worked example, 80 entries against a 100 reserve: protocol 4 USDC, winning
  ticket 64 USDC, sponsor 12 USDC plus the returned NFT.

### RF-048 — Value is conserved exactly in raw token units in every branch

- **Claim.** Nothing is created or lost to rounding. Sub-unit remainders go to the
  sponsor.
- **Technical.** Both branches assign the sponsor a **subtraction** remainder rather than
  a third independent floor division, so:
  `NftWon: protocolFee + sponsorProceeds == grossPot`;
  `CashWon: protocolFee + winnerProceeds + sponsorProceeds == grossPot`;
  `Refunding: sum of each burned ticket's range × ENTRY_PRICE == grossPot`.
- **Source.** `packages/contracts/src/Raffle.sol:450-456`.
- **Function / state.** `unsettledPot`, `sponsorProceeds`, `protocolFees`,
  `winnerProceeds`.
- **Evidence.** `testFuzzCashSplitAlwaysConservesEightyFifteenFive` (`F`);
  `invariantQuoteAccountingIsExactAndSolvent` (`I`);
  `invariantBranchEconomicsRemainEightyFifteenFiveNinetyFiveFiveOrFullRefund` (`I`).
- **Status.** Current.
- **Caveats.** Because entries are whole dollars, `grossPot` is always a multiple of
  `1_000_000`, so the 5% and 80% floors are exact in practice. The subtraction rule makes
  conservation hold regardless.

### RF-049 — `grossSales` is derived, never stored

- **Claim.** There is no second copy of gross sales that could drift from the entry
  count.
- **Technical.** `grossSales()` returns `uint256(totalEntries) * ENTRY_PRICE` as a view.
  No storage slot mirrors it.
- **Source.** `packages/contracts/src/Raffle.sol:378-381`.
- **Function / state.** `grossSales()`.
- **Evidence.** `invariantQuoteAccountingIsExactAndSolvent` (`I`); SDK economics tests
  (`X`).
- **Status.** Current.
- **Caveats.** `grossSales()` counts everything ever sold. It is **not** the remaining
  pot: after settlement or refunds, use the individual liability slots.

---

# 11. Refund paths

### RF-050 — `enableRefunds()` covers three origins and is permissionless at the deadline

- **Claim.** Every way the raffle can stall ends in full, fee-free refunds that anyone can
  switch on.
- **Technical.** `enableRefunds` dispatches on status.
  From `Active` with `totalEntries == 0`, the deadline is `endTime`, and the **sponsor may
  act early** while anyone else must wait for it.
  From `Active` with entries sold, the deadline is `drawRequestDeadline()`.
  From `Drawing`, the deadline is `callbackDeadline()`.
  In all cases it moves `unsettledPot` into `remainingRefundLiability`, sets `Refunding`,
  and emits `RefundsEnabled`. Before the deadline it reverts `RefundsNotAvailable`; from
  any other status, `InvalidStatus`.
- **Source.** `packages/contracts/src/Raffle.sol:223-248`.
- **Function / state.** `enableRefunds()`, `remainingRefundLiability`, `RefundsEnabled`.
- **Evidence.** `testSoldRaffleHasHardRequestAndCallbackRefundDeadlines` (`U`);
  `testEmptyRaffleUsesRefundingWithoutClosedState` (`U`);
  `testAuthenticatedValidCallbackAtDeadlineIsIgnoredBeforeRefunds` (`A`);
  `testCallbackDeadlineIsHardAtEqualityRegardlessOfOrdering` (`U`).
- **Status.** Current. **There are three origins, not the retired design's three
  different ones**, and there is no `Closed` state — see section 19.
- **Caveats.** A deadline does not mutate state by itself. At and after each boundary the
  refund transition is available; it must still be _called_. Because requests and
  callbacks are excluded at their deadlines, there is no equality race between "resolve"
  and "refund".

### RF-051 — An empty raffle uses zero-liability `Refunding`, not a separate closed state

- **Claim.** A raffle that sells nothing simply ends, and the sponsor gets the NFT back.
- **Technical.** With `totalEntries == 0`, `unsettledPot` is already zero, so
  `enableRefunds` produces `Refunding` with zero liability. `releaseSponsorPrize` is
  available in `Refunding`, returning the NFT to `sponsorRecipient`. The sponsor may
  finalize before `endTime`; anyone may at or after it.
- **Source.** `packages/contracts/src/Raffle.sol:226-231,342-354`.
- **Function / state.** `Status.Refunding`, `releaseSponsorPrize`.
- **Evidence.** `testEmptyRaffleUsesRefundingWithoutClosedState` (`U`).
- **Status.** Current.
- **Caveats.** This is the only sponsor-only timing privilege in the protocol, and it can
  only be exercised when there is no buyer money at stake (`RF-008`).

### RF-052 — Refunds pay each ticket its exact range weight, once, in bounded batches

- **Claim.** A 20-number ticket refunds 20 USDC, in one burn, and cannot be refunded
  twice.
- **Technical.** `refundTickets(uint256[])` requires `Refunding` and a batch length in
  `[1, MAX_REFUND_TICKET_BATCH_SIZE]` where the maximum is 100. For each ID it requires
  caller ownership, adds `lastEntry - firstEntry + 1` to the aggregate, and burns. Then
  `amount = aggregateEntries * ENTRY_PRICE`, `remainingRefundLiability -= amount`, and
  `_transferQuoteExact(msg.sender, amount)`.
- **Source.** `packages/contracts/src/Raffle.sol:296-319`;
  `packages/contracts/src/libraries/RaffleConstants.sol:20`.
- **Function / state.** `refundTickets`, `MAX_REFUND_TICKET_BATCH_SIZE`,
  `InvalidTicketBatchSize`, `TicketsRefunded`.
- **Evidence.** `testWeightedRefundBatchPaysExactRangesAndConsumesOnce` (`U`);
  `testRefundBatchValidationAndMixedOwnershipAreAtomic` (`U`);
  `testFuzzRefundPaysWeightedRangeExactlyOnce` (`F`);
  `testFuzzNoRequestTimeoutPaysFullWeightedRange` (`F`);
  `testPurchaseAndRefundGasDoNotScaleWithEntriesInsideReceipt` (`U`).
- **Status.** Current.
- **Caveats.** The batch is atomic: a duplicate ID fails the second `ownerOf` because the
  first burn cleared the owner, and a foreign ID fails ownership — either reverts the
  whole batch. The 100 bound is on **tickets**, not entries; one ticket may carry any
  `uint128` entry count, so a single call can refund an arbitrarily large amount.

### RF-053 — Refunds charge no fee and create no sponsor proceeds

- **Claim.** On any refund path, buyers get every cent back and neither the sponsor nor
  the protocol earns anything.
- **Technical.** `enableRefunds` writes `remainingRefundLiability = unsettledPot` and
  never touches `protocolFees`, `sponsorProceeds`, or `winnerProceeds`. Those slots are
  written only by `_settleWinningTicket`, which is unreachable from `Refunding`.
- **Source.** `packages/contracts/src/Raffle.sol:243-247,440-465`.
- **Function / state.** `remainingRefundLiability`, `protocolFees`, `sponsorProceeds`.
- **Evidence.** `testFuzzNoRequestTimeoutPaysFullWeightedRange` (`F`);
  `invariantBranchEconomicsRemainEightyFifteenFiveNinetyFiveFiveOrFullRefund` (`I`);
  `invariantQuoteAccountingIsExactAndSolvent` (`I`).
- **Status.** Current.
- **Caveats.** The draw requester's ETH fee is **not** refunded by the protocol; it was
  paid to Chainlink, not into the pot (`RF-030`).

---

# 12. Quote-token accounting

### RF-054 — The accounting identity and the solvency invariant

- **Claim.** Everything the contract owes is tracked in five slots, and its balance
  always covers them.
- **Technical.**
  `accountedQuoteBalance() = unsettledPot + remainingRefundLiability + winnerProceeds +
sponsorProceeds + protocolFees`. The maintained invariant is
  `quoteToken.balanceOf(raffle) >= accountedQuoteBalance()`.
- **Source.** `packages/contracts/src/Raffle.sol:373-376`.
- **Function / state.** `accountedQuoteBalance()`.
- **Evidence.** `invariantQuoteAccountingIsExactAndSolvent` (`I`);
  `testDonationsAndForcedNativeDoNotAlterQuoteAccounting` (`U`); independent Python model.
- **Status.** Current.
- **Caveats.** Surplus arises only from direct donations and never becomes a liability.
  There is no sweep function, so donated quote tokens are unrecoverable — a deliberate
  consequence of having no administrator.

### RF-055 — Outgoing transfers verify both the debit and the credit

- **Claim.** A payout that under-delivers or over-delivers is rejected outright, and the
  claim survives for a retry.
- **Technical.** `_transferQuoteExact(to, amount)` first rejects a protocol destination
  (`InvalidQuoteDestination`), snapshots both the raffle's and the recipient's balances,
  performs `safeTransfer`, then recomputes both saturating deltas and reverts
  `UnsupportedQuoteTokenTransfer(amount, debited, credited)` unless both equal `amount`.
- **Source.** `packages/contracts/src/Raffle.sol:475-492`.
- **Function / state.** `UnsupportedQuoteTokenTransfer`, `InvalidQuoteDestination`.
- **Evidence.** `testNonExactOutboundTokenCannotConsumeWinnerLiability` (`A`);
  `testOutboundClaimFailureRestoresClaimAndAccounting` (`A`);
  `testReentrantQuoteTokenCannotNestWinnerWithdrawal` (`A`);
  `testOverCreditQuoteCannotSpoofGrossAccounting` (`A`).
- **Status.** Current.
- **Caveats.** Checking both sides catches recipient-bonus tokens (credit > debit) and
  sender-rebate tokens (debit < amount) that a one-sided check would miss. It preserves
  an onchain claim across a USDC blacklist event; it cannot force the transfer to
  succeed.

---

# 13. Supported and unsupported assets

### RF-056 — Supported prize: an honest, standards-compliant ERC-721

- **Claim.** The protocol supports normal NFT collections and explicitly does not support
  hostile ones.
- **Technical.** `_validateCreateParams` requires the prize to have code and to answer
  `supportsInterface(type(IERC721).interfaceId)` truthfully inside `try/catch`, and
  rejects the factory, quote token, wrapper, implementation, and any registered raffle as
  a prize. Escrow and both delivery paths add `ownerOf` post-conditions.
- **Source.** `packages/contracts/src/RaffleFactory.sol:125-148`;
  `packages/contracts/src/Raffle.sol:282-284,352`.
- **Function / state.** `UnsupportedPrizeToken`, `NotContract`,
  `UnsafeProtocolDestination`.
- **Evidence.** `testFactoryConstructorAndCreationValidation` (`U`);
  `testNonCompliantPrizeCannotPassPostDeliveryVerification` (`A`);
  `testFactoryRejectsPrizesThatDoNotEscrowAndActivateExactly` (`A`).
- **Status.** Current.
- **Caveats.** ERC-165 support is **self-reported** and `ownerOf` verification routes
  through the same contract that could be lying. An upgradeable, pausable,
  transfer-restricted, burned, or consistently dishonest collection can forge custody
  statements or permanently block delivery, and no contract can assess whether a prize has
  value. Because a resolved result is final (`RF-040`), this is the most material launch
  consideration in the current risk set (`V12` entries `243747`, `243754`).

### RF-057 — Supported payment: one non-rebasing, exact-transfer six-decimal ERC-20

- **Claim.** The intended quote token is official USDC, and the code enforces the shape
  rather than the identity.
- **Technical.** The factory requires code and `decimals() == 6`. Every inbound and
  outbound movement is verified by exact balance delta. The Solidity is **not**
  hard-coded to USDC: the address is a constructor argument, and "official USDC" is
  enforced by deployment validation and human review.
- **Source.** `packages/contracts/src/RaffleFactory.sol:41-63`;
  `packages/contracts/src/Raffle.sol:152-156,475-492`.
- **Function / state.** `quoteToken`, `QUOTE_TOKEN_DECIMALS`.
- **Evidence.** `testFalseReturningAndFeeOnTransferQuotesCannotCreateReceipts` (`A`);
  `testEthereumMainnetChainlinkVrfUsdcAndRangeReceipt` (`K`); deployment validation (`X`).
- **Status.** Current.
- **Caveats.** Circle retains issuer, proxy, pause, and blocklist controls. Exact-delta
  checks prevent silent accounting drift but cannot guarantee transfer liveness. A
  consistently lying token is unsupported and can, in combination with a
  sponsor-selected predicted recipient, be used to strand that sponsor's own proceeds
  (`V12` entry `243755`).

### RF-058 — Explicitly unsupported and unrecoverable

- **Claim.** Some things sent to a raffle are gone. This is disclosed, not hidden.
- **Technical.** Each of the following is outside protocol accounting with no rescue
  path: native currency forced in by `SELFDESTRUCT`; direct quote-token donations;
  unrelated NFTs pushed in with unsafe `transferFrom`; tickets or payouts sent to a
  destination that cannot act; and claims deliberately assigned to a code-less address
  that later becomes a registered clone.
- **Source.** `packages/contracts/src/Raffle.sol:394,413-415,512-520`.
- **Function / state.** `receive()`, `_isKnownProtocolDestination`.
- **Evidence.** `testDonationsAndForcedNativeDoNotAlterQuoteAccounting` (`U`);
  `testFutureCanonicalCloneCanBrickOnlyItsOwnWinnerRedemption` (`A`).
- **Status.** Current.
- **Caveats.** The future-clone case is reproducible but is owner-controlled
  self-stranding, not a third-party exploit: the claimant must themselves choose the
  predicted address. The regression test name states the scope precisely — it bricks
  **only its own** redemption.

---

# 14. External dependencies

### RF-059 — Chainlink VRF v2.5 is the sole randomness source

- **Claim.** There is one oracle, no fallback, and no reroll.
- **Technical.** The wrapper is `immutable`, validated non-zero at construction. There is
  no second source, no alternate resolution path, and no manual override. If no valid
  callback arrives before `callbackDeadline()`, the outcome is refunds, not a retry.
- **Source.** `packages/contracts/src/Raffle.sol:84,182-184,423-438,522-525`.
- **Function / state.** `vrfWrapper()`.
- **Evidence.** `testFeeReadAndRequestFailuresRollBackToActiveThenRefundAtDeadline` (`A`);
  `docs/RANDOMNESS.md`.
- **Status.** Current.
- **Caveats.** An outage, configuration change, coordinator failure, or prolonged
  censorship yields refunds. The contract cannot switch providers or raise its immutable
  300,000 callback limit.

### RF-060 — Ethereum is the target chain

- **Claim.** v1 targets Ethereum mainnet, with Sepolia required first.
- **Technical.** Deployment tooling and fork tests target Ethereum mainnet and Sepolia.
  Thirty request confirmations materially reduce ordinary reorganization risk without
  creating a finality guarantee.
- **Source.** `packages/contracts/script/DeployRaffleFun.s.sol`;
  `packages/contracts/ignition/modules/RaffleFun.ts`; `docs/DEPLOYMENT.md`.
- **Function / state.** —
- **Evidence.** `testEthereumMainnetChainlinkVrfUsdcAndRangeReceipt` (`K`);
  `testEthereumSepoliaChainlinkVrfUsdcAndRangeReceipt` (`K`).
- **Status.** Current. **The retired design targeted Base** — see section 19.
- **Caveats.** Official USDC and Chainlink wrapper addresses are **not** hard-coded in
  Solidity. They are constructor arguments that must be reverified from primary sources
  on release day. Validators and builders determine inclusion near every boundary;
  censorship or a reorganization that removes a request or callback after its cutoff
  prevents replay and can force refunds.

### RF-061 — Pinned toolchain and dependencies

- **Claim.** The build is reproducible from pinned versions.
- **Technical.** Solidity `0.8.36` with an exact pragma;
  `@openzeppelin/contracts@5.6.1`; `@chainlink/contracts@1.5.0`; Node `22.23.2`;
  pnpm `11.18.0`.
- **Source.** `packages/contracts/package.json:27-29`; `package.json:8-9`;
  `packages/contracts/src/Raffle.sol:2`.
- **Function / state.** —
- **Evidence.** Lockfile; `CURRENT-CAMPAIGN.md`.
- **Status.** Current.
- **Caveats.** Dependency and signature checks must be rerun on the frozen release SHA.

---

# 15. Bytecode and gas

### RF-062 — Measured contract sizes at this commit

- **Claim.** Both production contracts sit comfortably inside their code-size limits.
- **Technical.** Measured with `forge build --sizes` at this registry commit:

  | Contract        | Runtime (B) | Initcode (B) | Runtime margin (B) | Initcode margin (B) |
  | --------------- | ----------: | -----------: | -----------------: | ------------------: |
  | `Raffle`        |      17,459 |       18,569 |              7,117 |              30,583 |
  | `RaffleFactory` |       3,973 |       23,476 |             20,603 |              25,676 |

  The factory's runtime is small because clone creation moved the protocol logic into the
  implementation; its initcode is large because the constructor deploys that
  implementation.

- **Source.** `packages/contracts/src/{Raffle,RaffleFactory}.sol`.
- **Function / state.** —
- **Evidence.** `forge build --sizes` at commit `e65e1e5` (`X`).
- **Status.** Current. **The retired design's 309-byte EIP-170 headroom warning no longer
  applies** — see section 19.
- **Caveats.** Runtime margin is against EIP-170 (24,576 B) and initcode margin against
  EIP-3860 (49,152 B). Re-measure on the frozen release SHA.

### RF-063 — Work is constant in entry count on every hot path

- **Claim.** A raffle with a million entries costs the same to buy into, resolve, and
  prove as one with ten.
- **Technical.** Purchase is one payment plus one mint. The callback is one modulo plus
  bounded storage writes. Winner proof is one range load plus two comparisons. Only
  refunds loop, and only over the at-most-100 submitted ticket IDs.
- **Source.** `packages/contracts/src/Raffle.sol:137-169,423-438,467-473,296-319`.
- **Function / state.** —
- **Evidence.** `testCallbackGasDoesNotScaleWithReceiptCount` (`U`);
  `testPurchaseAndRefundGasDoNotScaleWithEntriesInsideReceipt` (`U`);
  `testBothCallbackBranchesStayBelowGasBudget` (`U`); committed gas snapshot (`X`).
- **Status.** Current.
- **Caveats.** Ticket transfers to code-bearing addresses incur one external `isRaffle`
  call to the factory (`RF-025`).

---

# 16. Current status

### RF-064 — Development status: internally audit-ready, not release-ready

- **Claim.** The candidate is complete and internally reviewed, and it is not ready for
  mainnet.
- **Technical.** `CURRENT-CAMPAIGN.md` records the decision verbatim: internally
  audit-ready for independent review; **not mainnet-ready**. `CURRENT-FINDINGS.md` lists
  nine open release-verification gaps (`V1-REL-01` … `V1-REL-09`).
- **Source.** `packages/contracts/audit/CURRENT-CAMPAIGN.md`;
  `packages/contracts/audit/CURRENT-FINDINGS.md`;
  `packages/contracts/audit/RELEASE-CHECKLIST.md`.
- **Function / state.** —
- **Evidence.** The audit ledger itself.
- **Status.** Current.
- **Caveats.** Public material must not describe the protocol as audited, live, or
  production-ready.

### RF-065 — Deployment status: no deployment exists on any network

- **Claim.** Nothing is deployed. No transaction has been broadcast.
- **Technical.** `deployments/` contains only `schema.json`;
  `packages/config/src/deployments.ts` exports an empty record map, so
  `protocolIsConfigured === false` in the web app and every write path is disabled. There
  is no default mainnet deployment command.
- **Source.** `deployments/`; `packages/config/src/deployments.ts`;
  `docs/DEPLOYMENT.md:104`.
- **Function / state.** —
- **Evidence.** Repository state (`X`).
- **Status.** Current.

### RF-066 — Independent audit status: none

- **Claim.** No third party has audited this code.
- **Technical.** Every campaign in `packages/contracts/audit/` is a maintainer-run
  internal review. `V12-REVIEW-2026-08-20.md` is an independent review of a supplied
  third-party export, not an audit of the protocol: it found no confirmed in-scope
  vulnerability among fifteen entries and explicitly states it "is not a mainnet
  go-ahead and does not replace the required independent audit of a frozen release SHA".
- **Source.** `packages/contracts/audit/V12-REVIEW-2026-08-20.md`;
  `CURRENT-FINDINGS.md` (`V1-REL-06`).
- **Function / state.** —
- **Evidence.** The audit ledger itself.
- **Status.** Current.
- **Caveats.** Internal evidence is evidence of testing depth, not proof of correctness.

### RF-067 — Recorded internal campaign results

- **Claim.** The internal campaign is broad, and its totals are pinned to earlier SHAs.
- **Technical.** At implementation SHA `92eccb4` / evidence SHA `e9e0e73`
  (`CURRENT-TEST-MATRIX.md`): Foundry 72 passed; Hardhat 22 passed; independent Python
  model 11 passed; 52 of 52 declared mutants killed; gas suite 57 passed; SDK 14; web 15;
  subgraph 7; production-only coverage 100.00% lines, 100.00% functions, 94.12% branches;
  Slither 47 contracts / 64 detectors / 0 results; Gitleaks 0 leaks. Eight fuzz properties
  passed the 100,000-case audit profile; seven stateful invariants passed the
  256,000-call audit and strict profiles, the latter with `fail_on_revert` and zero
  handler reverts. At SHA `3da958f`, `V12-REVIEW-2026-08-20.md` records Foundry 80
  passed, Hardhat 21 passed, one RPC-gated fork skip.
- **Source.** `packages/contracts/audit/CURRENT-TEST-MATRIX.md`;
  `CURRENT-CAMPAIGN.md`; `V12-REVIEW-2026-08-20.md`.
- **Function / state.** —
- **Evidence.** The audit ledger itself.
- **Status.** Current, with the freshness caveat at the top of this registry.
- **Reproduced at this registry commit.** `forge test` reports **80 passed, 0 failed, 1
  skipped** (81 total; the skip is the RPC-gated fork case) and `hardhat test nodejs`
  reports **21 passing, 0 failing**. These two are the only totals in this fact that
  describe the current source.
- **Caveats.** Three explicit evidence limits: the Ethereum fork case is compiled but was
  **skipped** without an RPC endpoint; **no current Echidna runtime campaign** is claimed
  because the executable was unavailable; and the 52-mutant result covers a declared,
  hand-selected compiling set, not an exhaustive mutation space.

---

# 17. Known residual risks

### RF-068 — Prize-collection dependency (most material)

A future-hostile, upgradeable, pausable, transfer-restricted, burned, or consistently
lying ERC-721 can block the winner's prize after a valid, final result. Settlement still
records the terminal quote allocations, so sponsor and treasury claims remain
independently releasable, and there is intentionally no post-result refund path
(`RF-040`, `RF-056`). Prize admission and collection review are material launch controls.

### RF-069 — USDC issuer controls

Circle can pause, freeze, blocklist, or upgrade USDC. Exact-delta checks preserve onchain
claims across a failed transfer but cannot force one (`RF-057`).

### RF-070 — Ethereum inclusion, ordering, and reorganization

Requests and callbacks must be included strictly before their cutoffs. Censorship or a
reorganization that removes one after its cutoff prevents replay and can force refunds.
Thirty confirmations reduce ordinary reorganization risk without providing mathematical
finality (`RF-029`, `RF-060`).

### RF-071 — Deployer misconfiguration can poison a factory

A factory deployed with a code-less address that later becomes a registered clone as its
treasury can eventually halt creation at that nonce. The intended mainnet validator
rejects a code-less treasury, so this is a deployment control rather than a runtime
attacker path (`V12` entry `243750`, `RF-003`).

### RF-072 — Self-stranding by owners and sponsors

A ticket owner, sponsor, or sponsor recipient can send their own credential or proceeds
to an incapable or predicted-future address and lose reachability. No unauthorized party
is affected. This is undecidable from bytecode and is deliberately unsolved (`RF-025`,
`RF-058`).

### RF-073 — No economic value ceiling

The contracts impose no dollar-denominated or gross-sales cap. Exposure can grow far
beyond the internal assurance level. If launch governance requires a cap it must be
onchain before the final audit; a frontend cap is bypassable (`RF-014`).

### RF-074 — Immutability removes all remediation

Neither the ownerless factory nor any clone can be patched, paused, or upgraded
(`RF-001`, `RF-009`).

### RF-075 — Modulo bias

Mathematically nonzero at the `2^-256` scale. Do not market as perfectly uniform or
provably fair (`RF-039`).

### RF-076 — Irrecoverable surplus and unrelated assets

Forced native value, quote donations, and unrelated NFTs have no rescue path by design
(`RF-058`).

### RF-077 — No protocol privacy

Every purchase, transfer, resolution, settlement, redemption, and refund is public
onchain data, permanently linkable to addresses.

### RF-078 — Legal and gaming regulation

Chance-based promotions can trigger gaming, lottery, consumer, sanctions, tax, privacy,
and advertising obligations that differ by jurisdiction. Jurisdiction-specific review is
an open release blocker (`V1-REL-09`).

### RF-079 — Operational readiness gaps

No production treasury Safe has been selected or reviewed, no monitored Sepolia soak or
incident drill has been performed, no signed deployment record exists, and no written
go/no-go decision has been recorded (`V1-REL-01` … `V1-REL-08`).

---

# 18. Precedent set by this registry

### RF-080 — Which documents are public, and what each is for

- `docs/one-pagers/raffle-fun.md` — one-page orientation for a general audience.
- `docs/articles/raffle-fun-explained.md` — plain-language explanation for readers who
  know NFTs but not Solidity.
- `docs/whitepapers/raffle-fun-technical-whitepaper.md` — the technical reference for
  auditors, protocol engineers, and integrators.

All three are rendered to A4 PDFs by `pnpm docs:pdf`, which stamps this registry's commit
onto every cover so a stale SHA is impossible. The build refuses to run while this
registry mentions the retired protocol.

- **Source.** `docs/pdf/build.mjs:141-186`.
- **Status.** Current.

---

<!-- retired-reference:start -->

# 19. Removed behavior — do not restore

The following existed in earlier generations of this protocol and is **gone**. Historical
audit reports in this repository still describe it. Do not reintroduce any of it into a
public document from those reports.

| Retired behavior                                                      | Replaced by                                                                             |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| Pyth Entropy v2 randomness                                            | Chainlink VRF v2.5 native direct funding (`RF-034`)                                     |
| Base / Base Sepolia target chain                                      | Ethereum mainnet / Sepolia (`RF-060`)                                                   |
| `RaffleLens` read aggregator                                          | Nothing. There is no Lens. Read the raffle directly.                                    |
| `Ownable2Step` factory with treasury setter and creation pause        | An ownerless factory with no administrative surface at all (`RF-001`)                   |
| One `CREATE` deployment per raffle                                    | Fixed-target ERC-1167 clones of one locked implementation (`RF-006`)                    |
| Variable `ticketPrice` and `minimumTickets`                           | Fixed `ENTRY_PRICE` of 1 USDC and `reserveEntries` (`RF-014`, `RF-038`)                 |
| One ERC-721 per ticket, `1..100` per purchase                         | One ticket per purchase holding an inclusive entry range, any positive count (`RF-017`) |
| `Closed` status for zero-sale raffles                                 | Zero-liability `Refunding` (`RF-051`)                                                   |
| Transfer lock during `Drawing`, and on the winning ticket after       | No lock in any status; tickets are bearer claims throughout (`RF-021`)                  |
| `MAX_START_DELAY` scheduled starts                                    | The sale begins at creation, when the prize deposit activates it (`RF-015`)             |
| `DRAW_REQUEST_GRACE_PERIOD` of 3 days                                 | `DRAW_REQUEST_TIMEOUT` of 2 days (`RF-028`)                                             |
| `NFT_REDEMPTION_TIMEOUT` of 30 days and the `NftWon → Refunding` edge | Nothing. A resolved result is final (`RF-040`)                                          |
| Resolution that credited claims inside the callback                   | A separate permissionless `settleWinningTicket` (`RF-041`)                              |
| Cash split computed on a post-fee pot (80/20 of 95%)                  | 80/5/15 of **gross** (`RF-047`)                                                         |
| `recoverProtocolOwnedClaim` cross-raffle recovery dispatcher          | Nothing. It was itself exploitable and was removed.                                     |
| `claimQuote` / `claimQuoteFor` pull-claim ledger                      | Fixed-recipient `releaseSponsorProceeds` / `releaseProtocolFees` (`RF-044`)             |
| `sponsorPrizeRecoveryRecipient` as a distinct role                    | The single immutable `sponsorRecipient` (`RF-044`)                                      |
| `metadataURI` and `MAX_METADATA_URI_LENGTH`                           | Nothing. There is no onchain metadata parameter.                                        |
| A 309-byte EIP-170 headroom constraint on the factory                 | 20,603 bytes of runtime margin (`RF-062`)                                               |

---

<!-- retired-reference:end -->

## Registry maintenance

When production Solidity changes, update the affected fact, its source line references,
and the registry commit SHA at the top of this file **before** updating any public
document. When a fact is retired, record it in section 19 with a pointer to its
replacement, so that a future writer cannot reintroduce it from a historical audit
report.
