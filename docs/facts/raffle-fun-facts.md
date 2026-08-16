# raffle.fun internal fact registry

**Purpose.** This is the internal source-of-truth register behind the three public
raffle.fun documents. Every substantive claim in the one-pager, the layman's article,
and the technical whitepaper must trace to a Fact ID here. It exists so that a public
claim can never drift ahead of production Solidity.

**Registry commit.** `5772e54ba89c06646815ed52a881cd8940f094ca`
(branch `claude/raffle-fun-docs-3f9f2b`, working tree clean at capture time).
Unless a fact says otherwise, every "Commit" field refers to this SHA, and every source
line reference is a line number as of this SHA.

**Registry date.** 2026-08-16.

## Precedence rules used to build this registry

1. **Production Solidity wins.** `packages/contracts/src/*.sol` and
   `packages/contracts/src/interfaces/*.sol` are authoritative for onchain behavior.
2. **Current normative documentation is second.** `README.md`, `SECURITY.md`, and
   `docs/{ARCHITECTURE,ECONOMICS,RANDOMNESS,STATE-MACHINE,THREAT-MODEL,SECURITY-INVARIANTS,DEPLOYMENT}.md`
   are treated as normative where they agree with Solidity.
3. **Audit reports are historical evidence only**, valid solely for the commit each one
   names. They are never used to describe current behavior.
4. **Removed behavior is not restored.** See `RF-047` for the specific trap in this
   repository.

## Known stale artifacts in this repository (do not quote as current)

| Artifact                                                                                                          | Why it is stale                                                                                                                                                                                                                                            | Correct current source                                                     |
| ----------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `docs/whitepaper/archive/WHITEPAPER-superseded-2026-08-13.md` (was `docs/WHITEPAPER.md` until 2026-08-16)         | Pinned to commit `f165e4c1d8f5d093fe0a36094f79a29857c26286`; predates the draw-time transfer lock, the NFT-delivery refund fallback, and the removal of `recoverProtocolOwnedClaim`. **Archived 2026-08-16**; `docs/WHITEPAPER.md` is now a redirect stub. | This registry; current Solidity.                                           |
| `docs/whitepaper/archive/raffle-fun-whitepaper-superseded-2026-08-13.{pdf,docx}`                                  | Same superseded generation. The identical `output/pdf/raffle-fun-whitepaper.pdf` was removed as a byte-for-byte duplicate.                                                                                                                                 | This registry; current Solidity.                                           |
| `docs/whitepaper/source/sections/*.md`                                                                            | Source of the archived generation; not yet rewritten.                                                                                                                                                                                                      | This registry; current Solidity.                                           |
| `packages/contracts/audit/INTERNAL-AUDIT.md`                                                                      | Self-marked historical baseline for commit `a2120f5e163dc3641d9864773febbfedca047edb`; describes `recoverProtocolOwnedClaim` as a shipped feature.                                                                                                         | `ETHSKILLS-REVIEW-2026-08-13.md`, then current Solidity.                   |
| `packages/contracts/audit/INDEPENDENT-SPECIFICATION.md`, `FINDINGS.md`, `MUTATION-TESTING.md`, `TEST-CAMPAIGN.md` | Pre-remediation; reference the removed recovery dispatcher.                                                                                                                                                                                                | Current Solidity; `EXTREME-TESTING-2026-08-13.md` for the latest campaign. |
| `docs/whitepaper/README.md`                                                                                       | Says the fact generator parses a `ProtocolOwnedClaim` enum. That enum no longer exists in production Solidity.                                                                                                                                             | Current Solidity.                                                          |

> **The whitepaper build pipeline does not run at this commit.**
> `pnpm docs:whitepaper`, `:figures`, and `:docx` all fail at their first step with
> `whitepaper fact validation failed: enum ProtocolOwnedClaim not found`
> (`docs/whitepaper/src/protocol-facts.mjs:138`). The generator also requires
> `recoverProtocolOwnedClaim` in the compiled `Raffle` ABI (line 167) and omits
> `NFT_REDEMPTION_TIMEOUT` from its required constants. Regenerating the long-form
> whitepaper remains ETHSkills release-blocker item 5
> (`ETHSKILLS-REVIEW-2026-08-13.md:103-105`); see `docs/WHITEPAPER.md` for the repair steps.

## Evidence tag legend

Tags match `docs/SECURITY-INVARIANTS.md`: `U` unit/boundary, `A` adversarial/regression,
`F` fuzz property, `I` stateful invariant, `S` strict fail-on-revert invariant,
`E` Echidna/Medusa, `H` Halmos symbolic, `K` pinned Base fork, `X` SDK/subgraph/frontend/
deployment/static check.

---

# 1. Factory authority

### RF-001 — A Raffle can only be constructed by its declared factory

- **Claim.** Nobody can hand-deploy something that presents itself as a canonical raffle.
- **Technical.** `Raffle`'s constructor reverts with `OnlyFactory()` unless
  `msg.sender == params.factory`. The factory passes `address(this)`.
- **Source.** `packages/contracts/src/Raffle.sol:74`; `packages/contracts/src/RaffleFactory.sol:91-111`.
- **Function / state.** `Raffle.constructor`, immutable `factory`, `IRaffle.OnlyFactory`.
- **Evidence.** `testRaffleConstructorAuthenticatesConfiguredFactory` (`U`); SECURITY-INVARIANTS #1.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** Anyone can deploy an unrelated contract that merely _claims_ to be a raffle.
  Authenticity is established by `RaffleFactory.isRaffle(address)`, not by bytecode shape.
  Integrators must check the registry (see `RF-010`).

### RF-002 — Factory ownership is `Ownable2Step` and controls only two future-facing levers

- **Claim.** The factory owner can change who receives the fee on _new_ raffles, and can
  stop _new_ raffles being created. That is the entire administrative surface.
- **Technical.** `RaffleFactory is Ownable2Step`. `onlyOwner` functions are exactly
  `setProtocolTreasury(address)` and `setCreationPaused(bool)`.
- **Source.** `packages/contracts/src/RaffleFactory.sol:24,128-145`.
- **Function / state.** `protocolTreasury`, `creationPaused`, `owner`, `pendingOwner`.
- **Evidence.** `testFactoryEnforcesBoundedSchedulingAndFutureOnlyAdministration` (`U`);
  `invariantFleetRegistryAndCapturedConfigurationNeverDrift` (`I`); SECURITY-INVARIANTS #17-#20.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** The owner key is an external trust assumption. `docs/DEPLOYMENT.md` requires a
  reviewed multisig, but no owner has been selected or accepted onchain (see `RF-073`).

### RF-003 — A treasury change never affects an existing raffle

- **Claim.** Changing the treasury cannot redirect fees already owed by a live raffle.
- **Technical.** Each `Raffle` captures `protocolTreasury` as an `immutable` at construction
  from the factory's value at that moment. `setProtocolTreasury` writes only the factory's
  storage slot, which is read only by subsequent `createRaffle` calls.
- **Source.** `packages/contracts/src/RaffleFactory.sol:29-30,97,135-137`; `packages/contracts/src/Raffle.sol:35,90`.
- **Function / state.** `RaffleFactory.protocolTreasury` (storage) vs `Raffle.protocolTreasury` (immutable).
- **Evidence.** `testFactoryEnforcesBoundedSchedulingAndFutureOnlyAdministration` (`U`);
  `invariantFleetRegistryAndCapturedConfigurationNeverDrift` (`I`); SECURITY-INVARIANTS #18.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** None onchain. Offchain indexers must read the raffle's own value, not the factory's.

### RF-004 — Creation pause cannot pause an existing raffle

- **Claim.** Pausing does not freeze anyone's tickets, sale, draw, refund, or claim.
- **Technical.** `creationPaused` is read only at the top of `createRaffle`. No `Raffle`
  function reads factory storage except `isRaffle` for destination screening.
- **Source.** `packages/contracts/src/RaffleFactory.sol:71`; `packages/contracts/src/Raffle.sol:478,487`.
- **Function / state.** `createRaffle`, `CreationPaused()`.
- **Evidence.** `testFactoryEnforcesBoundedSchedulingAndFutureOnlyAdministration` (`U`);
  SECURITY-INVARIANTS #17.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** None onchain.

### RF-005 — Factory ownership cannot be renounced

- **Claim.** The factory can never be left without an owner.
- **Technical.** `renounceOwnership()` is overridden `pure` and always reverts with
  `OwnershipRenunciationDisabled()`.
- **Source.** `packages/contracts/src/RaffleFactory.sol:148-150`.
- **Function / state.** `renounceOwnership`, `IRaffleFactory.OwnershipRenunciationDisabled`.
- **Evidence.** ETHSkills `ES-04` regression (`A`); RELEASE-CHECKLIST "ownership renunciation".
- **Commit.** `5772e54`.
- **Status.** Current. Introduced as the fix for ETHSkills finding `ES-04`
  (renouncing while paused would have permanently bricked future creation).
- **Caveats.** Owner key loss still strands the two future-facing levers, though it cannot
  affect any existing raffle.

### RF-006 — Factory-wide dependencies are immutable

- **Claim.** A given factory is permanently bound to one payment token, one randomness
  contract, and one callback gas limit.
- **Technical.** `quoteToken`, `entropy`, `callbackGasLimit` are `immutable` on
  `RaffleFactory`, validated in the constructor (`_requireContract` for the two addresses,
  nonzero for the gas limit).
- **Source.** `packages/contracts/src/RaffleFactory.sol:25-27,55-66,197-199`.
- **Function / state.** `quoteToken()`, `entropy()`, `callbackGasLimit()`.
- **Evidence.** `testFactoryConstructorAndCreationValidation` (`U`); fork checks in
  `BaseFork.t.sol` (`K`); SECURITY-INVARIANTS #8-#10.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** Changing any of them requires deploying a **new factory**. There is no
  migration path for existing raffles. `_requireContract` only proves code exists at the
  address; it does not prove the address is the official USDC or Pyth deployment. That
  check is a deployment-time human/CI responsibility (`RF-073`).

---

# 2. Raffle immutability

### RF-007 — Each Raffle is an ordinary `CREATE` deployment with no upgrade path

- **Claim.** A raffle's rules are fixed the moment it is created and can never be changed
  by anyone, including the protocol team.
- **Technical.** `RaffleFactory.createRaffle` uses `new Raffle(...)` (ordinary `CREATE`).
  There is no proxy, no clone (EIP-1167), no CREATE2 salt, no initializer, no
  `upgradeTo`, no `delegatecall`, and no admin role on `Raffle`.
- **Source.** `packages/contracts/src/RaffleFactory.sol:91-111`; `packages/contracts/src/Raffle.sol:29` (no `Ownable`/`Initializable` in the inheritance list).
- **Function / state.** All 14 `Raffle` config fields are `immutable`
  (`Raffle.sol:32-45`); `raffleMetadataURI` is set once in the constructor.
- **Evidence.** `testFactoryConstructorDeploysAndEscrowsAtomically` (`U`);
  `invariantFleetRegistryAndCapturedConfigurationNeverDrift` (`I`);
  SECURITY-INVARIANTS #2, #20, #34.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** `raffleMetadataURI` is a non-immutable `string` in storage but is written
  only in the constructor and has no setter. Immutability is a property of the _raffle_,
  not of the protocol: a new factory version can always be deployed alongside.

### RF-008 — An existing Raffle has no administrator, pause, rescue, or override

- **Claim.** There is no emergency button on a live raffle.
- **Technical.** `Raffle` exposes no `onlyOwner`/`onlyRole` function, no pause flag, no
  generic asset-sweep, no settlement override, and no reroll. Every state-changing external
  function is gated only by lifecycle status, timestamps, and ticket/claim ownership.
- **Source.** `packages/contracts/src/Raffle.sol:106-299` (complete external mutating surface:
  `buyTickets`, `closeEmptyRaffle`, `requestDraw`, `enableRefunds`, `redeemWinningTicket`,
  `redeemRefundTickets`, `claimQuote`, `claimQuoteFor`, `claimSponsorPrize`, plus ERC-721
  transfer/approval and the Entropy callback).
- **Function / state.** —
- **Evidence.** `invariantStrictStatusAndResolutionAreMonotonic` (`S`);
  SECURITY-INVARIANTS #20, #34, #58; THREAT-MODEL "Admin changes existing raffle".
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** This is a deliberate trade-off: no admin also means no admin remedy if a
  user sends a ticket somewhere unrecoverable (`RF-069`) or if an external dependency
  misbehaves (`RF-066`, `RF-068`).

### RF-009 — Incident response cannot reach an existing raffle

- **Claim.** If a bug is found, the team can stop new raffles and take down the website,
  but cannot patch, pause, or unwind a raffle that already exists.
- **Technical.** Follows from `RF-004` and `RF-008`.
- **Source.** `SECURITY.md:64-70`; `docs/DEPLOYMENT.md:87-91`.
- **Function / state.** `setCreationPaused`.
- **Evidence.** Documented operational posture; SECURITY-INVARIANTS #17, #20.
- **Commit.** `5772e54`.
- **Status.** Current (normative documentation, consistent with Solidity).
- **Caveats.** Users can always bypass the first-party frontend and call verified contracts
  directly, which is a censorship-resistance property and simultaneously means a frontend
  takedown does not protect users from a contract-level bug.

---

# 3. Prize escrow

### RF-010 — Creation, registration, prize deposit, activation, and verification are one atomic transaction

- **Claim.** A raffle cannot exist without its prize already locked inside it.
- **Technical.** `createRaffle` in one transaction: deploys `Raffle` (status
  `AwaitingPrize`), writes `raffleById`/`idByRaffle`/`isRaffle`, emits `RaffleCreated`,
  calls `prizeToken.safeTransferFrom(msg.sender, raffle, prizeTokenId)`, then asserts
  `ownerOf(prizeTokenId) == raffle` **and** `IRaffle(raffle).status() == Active`. Any
  failure reverts the whole transaction, including the deployment and registry writes.
- **Source.** `packages/contracts/src/RaffleFactory.sol:70-125`.
- **Function / state.** `raffleCount`, `raffleById`, `idByRaffle`, `isRaffle`,
  `PrizeEscrowVerificationFailed`.
- **Evidence.** `testFactoryConstructorDeploysAndEscrowsAtomically`,
  `testPrizeTransferFailureRevertsDeploymentAndRegistry`,
  `testFactoryRejectsIncompleteEscrowVerification` (`U`);
  `testFactoryReentrancyDuringPrizeDepositIsBlockedAtomically` (`A`);
  SECURITY-INVARIANTS #3-#6.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** The double check (`ownerOf` _and_ `status`) defends against an ERC-721 that
  returns success without moving the token, and against one that calls the receiver hook
  without updating ownership. A **fully malicious or upgradeable** ERC-721 can still lie to
  both reads (`RF-068`).

### RF-011 — The prize receiver hook accepts exactly one specific deposit

- **Claim.** Only the exact configured NFT, sent by the sponsor through the factory, can
  activate a raffle.
- **Technical.** `onERC721Received` reverts with `UnexpectedPrize` unless all five hold:
  `status == AwaitingPrize`, `msg.sender == address(prizeToken)`,
  `tokenId == prizeTokenId`, `from == sponsor`, `operator == factory`. On success it sets
  `status = Active` and emits `PrizeDeposited`.
- **Source.** `packages/contracts/src/Raffle.sol:359-374`.
- **Function / state.** `onERC721Received`, `Status.AwaitingPrize -> Status.Active`.
- **Evidence.** `testViewsMetadataUnexpectedPrizeAndNativeRejection` (`U`);
  SECURITY-INVARIANTS #21-#24.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** A raffle can never re-enter `AwaitingPrize`, so a second deposit of the same
  token is rejected. An unrelated NFT pushed in with **unsafe** `transferFrom` never invokes
  this hook, is never accounted for, and has no rescue path (`RF-056`).

### RF-012 — The prize leaves escrow at most once

- **Claim.** The NFT can be delivered to exactly one destination, once.
- **Technical.** Both exit paths set a one-way marker before the external transfer.
  `redeemWinningTicket` in the `NftWon` branch sets `prizeClaimed = true` then transfers;
  `claimSponsorPrize` reverts on `prizeClaimed` and sets it before transferring. Both are
  `nonReentrant`.
- **Source.** `packages/contracts/src/Raffle.sol:227-231,284-299`.
- **Function / state.** `prizeClaimed`, `redeemWinningTicket`, `claimSponsorPrize`.
- **Evidence.** `invariantPrizeCanLeaveEscrowOnlyOnceOnAnExplicitClaimPath` (`I`);
  `invariantStrictPrizeEscrowMatchesClaimState` (`S`);
  `echidna_prize_leaves_only_after_claim_marker` (`E`);
  `testWinningTicketBurnPrecedesSafePrizeTransferAndBlocksReentry` (`A`);
  SECURITY-INVARIANTS #26-#28.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** If the external transfer reverts, the whole call reverts and `prizeClaimed`
  is restored to `false`, so the claimant can retry with a different destination.

---

# 4. Ticket purchase

### RF-013 — Buying tickets requires an active sale inside its window

- **Claim.** You can only buy while the sale is open.
- **Technical.** `buyTickets` requires `status == Active`, `block.timestamp >= startTime`,
  and `block.timestamp < endTime`.
- **Source.** `packages/contracts/src/Raffle.sol:112-114`.
- **Function / state.** `SaleNotStarted`, `SaleEnded`, `InvalidStatus`.
- **Evidence.** `testPurchaseAndCloseValidationBranches` (`U`);
  `testFuzzPurchaseAccountingReconciles` (`F`); SECURITY-INVARIANTS #36-#37.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** `block.timestamp` on Base is sequencer-reported; boundary behavior at the
  exact second is subject to block granularity.

### RF-014 — Purchases are bounded and priced as an exact multiple

- **Claim.** One transaction buys between 1 and 100 tickets, and the price shown is the
  total price paid.
- **Technical.** `quantity` must satisfy `1 <= quantity <= MAX_TICKETS_PER_PURCHASE (100)`;
  `recipient != address(0)`; `ticketPrice > type(uint256).max / quantity` reverts with
  `GrossAmountOverflow` before any token interaction; `grossAmount = ticketPrice * quantity`.
  No fee is added at checkout.
- **Source.** `packages/contracts/src/Raffle.sol:115-121`; `packages/contracts/src/libraries/RaffleConstants.sol:23`.
- **Function / state.** `InvalidQuantity`, `InvalidRecipient`, `GrossAmountOverflow`,
  `grossSales`, `unsettledPot`.
- **Evidence.** `testPurchaseAndCloseValidationBranches` (`U`);
  `testFuzzPurchaseAccountingReconciles` (`F`); SECURITY-INVARIANTS #38-#40.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** The 100-ticket bound is per transaction, not per buyer. Buying more requires
  multiple transactions. There is no per-raffle maximum ticket supply.

### RF-015 — Incoming payment is verified by exact balance delta

- **Claim.** If the payment token quietly delivers less than the stated amount, the purchase
  fails instead of issuing under-funded tickets.
- **Technical.** `buyTickets` records `balanceOf(this)` before and after
  `safeTransferFrom`, computes `receivedAmount`, and reverts with `UnsupportedQuoteToken`
  unless `receivedAmount == grossAmount`.
- **Source.** `packages/contracts/src/Raffle.sol:122-126`.
- **Function / state.** `UnsupportedQuoteToken(expectedAmount, receivedAmount)`.
- **Evidence.** `testFeeOnTransferQuoteTokenIsRejectedWithoutCreatingLiability`,
  `testFalseReturningQuoteTokenIsRejected`, `testReentrantQuoteTokenCannotNestPurchase` (`A`);
  `testOverCreditAndSenderRebateTokensCannotSpoofExactAccounting` (`A`);
  SECURITY-INVARIANTS #41-#42.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** This makes fee-on-transfer and rebasing tokens unusable by construction
  (`RF-056`). It does not defend against a token that lies about `balanceOf`.

### RF-016 — Ticket IDs are sequential, contiguous, and start at 1

- **Claim.** Tickets are numbered 1, 2, 3, … with no gaps and no reuse, across all buyers
  and all separate purchases.
- **Technical.** `firstTicketId = totalTickets + 1`; `lastTicketId = totalTickets + quantity`;
  `totalTickets = lastTicketId`; each ID is `_safeMint`ed in a loop.
- **Source.** `packages/contracts/src/Raffle.sol:130-136`.
- **Function / state.** `totalTickets`, `TicketsPurchased`.
- **Evidence.** `testPurchasesMintSequentialTransferableBearerTickets`,
  `testRegressionSeparatePurchasesContinueSequentialTicketIds` (`U`);
  `echidna_ticket_and_sales_accounting` (`E`); SECURITY-INVARIANTS #44-#46.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** Burned tickets leave gaps in _surviving_ IDs but `totalTickets` never
  decreases, so IDs are never reissued.

### RF-017 — `grossSales` always equals `ticketPrice * totalTickets`

- **Claim.** The pot is exactly the number of tickets sold times the ticket price.
- **Technical.** `grossSales += grossAmount` and `unsettledPot += grossAmount` are the only
  writes that increase either value, and both use the same `ticketPrice * quantity`.
- **Source.** `packages/contracts/src/Raffle.sol:128-129`.
- **Function / state.** `grossSales`, `unsettledPot`.
- **Evidence.** `testFuzzPurchaseAccountingReconciles` (`F`);
  `invariantQuotePaidInEqualsPaidOutPlusContractBalance` (`I`);
  `invariantStrictQuoteAccountingReconciles` (`S`);
  `echidna_gross_equals_balance_plus_payouts` (`E`); SECURITY-INVARIANTS #46.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** `grossSales` is cumulative and is never reduced by settlement; it is a sales
  total, not a balance.

### RF-018 — A rejecting or reentrant ticket recipient rolls the whole purchase back

- **Claim.** A contract that refuses the ticket cannot leave the buyer's money in the raffle.
- **Technical.** `_safeMint` invokes `onERC721Received`; a revert propagates. `buyTickets`
  is `nonReentrant`, so a receiver cannot re-enter to nest a purchase.
- **Source.** `packages/contracts/src/Raffle.sol:109,135`.
- **Function / state.** `nonReentrant`, `_safeMint`.
- **Evidence.** `testReentrantReceiverCannotNestTicketPurchase` (`A`);
  `testMultiMintReceiverFailureRollsBackPaymentMintsAndNestedTransfer` (`A`);
  SECURITY-INVARIANTS #43.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** None material.

---

# 5. ERC-721 ticket ownership

### RF-019 — Tickets are ERC-721 tokens minted by the Raffle itself

- **Claim.** A ticket is a normal NFT you hold in your own wallet.
- **Technical.** `Raffle is ... ERC721("raffle.fun Ticket", "RAFFLE")`. The raffle contract
  is simultaneously the escrow, the ticket collection, and the settlement engine.
- **Source.** `packages/contracts/src/Raffle.sol:29,73`.
- **Function / state.** Standard ERC-721 surface; `tokenURI` returns `raffleMetadataURI`
  for any existing ticket.
- **Evidence.** `testPurchasesMintSequentialTransferableBearerTickets` (`U`);
  `testViewsMetadataUnexpectedPrizeAndNativeRejection` (`U`); SECURITY-INVARIANTS #47.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** All tickets in one raffle share a single metadata URI; tickets are not
  individually distinguishable by metadata.

### RF-020 — Ticket ownership is the bearer claim credential

- **Claim.** Whoever holds the ticket at the moment of redemption is the one who can claim.
  There is no separate registry of "who bought it".
- **Technical.** `redeemWinningTicket` and `redeemRefundTickets` both require
  `msg.sender == ownerOf(ticketId)` and then `_burn` the ticket. Purchase history is not
  consulted. Approval is explicitly **not** sufficient — an approved operator is not the
  owner and cannot redeem.
- **Source.** `packages/contracts/src/Raffle.sol:222-226,260-265`.
- **Function / state.** `NotTicketOwner(ticketId, caller, owner)`, `_burn`.
- **Evidence.** `testFuzzCurrentOwnerCanRedeemWinningTicket` (`F`);
  `testRefundRedemptionRequiresActualOwnerAndBoundedBatch` (`U`);
  `testStaleOperatorApprovalsCannotMoveLockedTicketsButResumeForRefunds` (`A`);
  `check_winnerCredentialConsumesAtMostOnce`, `check_refundCredentialConsumesAtMostOnce` (`H`);
  SECURITY-INVARIANTS #49.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** This is the single most important user-facing property and the single
  biggest user-facing risk. Sending a ticket to an address that cannot call
  `redeemWinningTicket` — a lost key, or a contract with no such capability — forfeits the
  claim with no recovery path (`RF-069`).

### RF-021 — Every claim right is consumed by burning

- **Claim.** A ticket cannot be redeemed twice.
- **Technical.** `_burn(ticketId)` precedes every asset transfer in both redemption paths.
  A burned ticket has no owner, so the ownership check fails on a second attempt.
- **Source.** `packages/contracts/src/Raffle.sol:226,264`.
- **Function / state.** `_burn`, `winningTicketRedeemed()`.
- **Evidence.** `check_winnerCredentialConsumesAtMostOnce`,
  `check_refundCredentialConsumesAtMostOnce` (`H`);
  `testFuzzRefundBurnsPayExactlyOnce` (`F`); SECURITY-INVARIANTS #49, #78, #82.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** In `redeemWinningTicket` the burn happens _before_ the external prize
  transfer. If the transfer fails, the entire transaction reverts and the burn is undone.

---

# 6. Transfer locks

### RF-022 — All ticket transfers are frozen while randomness is pending

- **Claim.** Once the draw is requested, nobody can move any ticket until the result is in.
- **Technical.** The `transferFrom` override reverts with `TicketTransferLocked` whenever
  `status == Status.Drawing`, for every token ID.
- **Source.** `packages/contracts/src/Raffle.sol:343-352`.
- **Function / state.** `transferFrom`, `TicketTransferLocked(tokenId, status)`.
- **Evidence.** `testStaleOperatorApprovalsCannotMoveLockedTicketsButResumeForRefunds` (`A`);
  `testFuzzWinningTicketAlwaysUsesInclusiveSoldRange` (`F`);
  SECURITY-INVARIANTS #48; ETHSkills `ES-02`.
- **Commit.** `5772e54`.
- **Status.** Current. This is the partial fix for ETHSkills finding `ES-02`.
- **Caveats.** OpenZeppelin's `safeTransferFrom` overloads route through `transferFrom`, so
  both are covered. `_burn` and `_safeMint` do not, so redemption burns still work during
  later statuses. **This does not solve the underlying oracle problem** — see `RF-046`.

### RF-023 — The selected winning ticket stays locked after resolution

- **Claim.** The winning ticket cannot be sold or moved after the winner is known; only its
  owner at resolution time can redeem it.
- **Technical.** The same override reverts when
  `(status == NftWon || status == CashWon) && tokenId == winningTicketId`. Non-winning
  tickets are freely transferable in those statuses.
- **Source.** `packages/contracts/src/Raffle.sol:345-349`.
- **Function / state.** `winningTicketId`, `TicketTransferLocked`.
- **Evidence.** `testStaleOperatorApprovalsCannotMoveLockedTicketsButResumeForRefunds` (`A`);
  SECURITY-INVARIANTS #48; STATE-MACHINE.md:28-31.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** The purpose is to stop a stale marketplace listing or approval from
  redirecting the prize the instant the result becomes public. A consequence is that the
  winning ticket cannot be resold — the winner must redeem it themselves, though
  `redeemWinningTicket(to)` lets them nominate any safe destination for the asset.

### RF-024 — Refundable tickets become transferable again

- **Claim.** In the refund state, tickets can move freely and be burned by whoever holds them.
- **Technical.** `Status.Refunding` matches neither lock condition, so `transferFrom`
  proceeds normally.
- **Source.** `packages/contracts/src/Raffle.sol:345-349`.
- **Function / state.** `Status.Refunding`.
- **Evidence.** `testRefundTicketsRemainTransferableAndBurnForExactRefund` (`U`);
  SECURITY-INVARIANTS #49, #81.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** In `Refunding`, `winningTicketId` may retain a historical nonzero value from
  a prior `NftWon` resolution, but it confers no special right — every ticket refunds at
  exactly `ticketPrice` (`RF-043`).

### RF-025 — Tickets and payouts reject known protocol destinations

- **Claim.** You cannot send a ticket or a payout into a protocol contract that has no way
  to send it back out.
- **Technical.** `_isKnownProtocolDestination(to)` returns true for the raffle itself, its
  factory, its quote token, its Entropy contract, its prize contract, and — when `to` has
  code — any address for which `IRaffleFactory(factory).isRaffle(to)` is true. It gates
  `transferFrom` (when `to != address(0)`), `_transferQuoteExact`, `redeemWinningTicket`'s
  NFT branch, and `claimSponsorPrize`. `_isConstructorProtocolDestination` applies the same
  test to the recovery recipient and treasury at construction, and
  `setProtocolTreasury` applies it to new treasuries.
- **Source.** `packages/contracts/src/Raffle.sol:80-85,220,293,350,446,470-489`;
  `packages/contracts/src/RaffleFactory.sol:59-61,130-134`.
- **Function / state.** `UnsafeProtocolDestination`, `InvalidQuoteDestination`.
- **Evidence.** `testRegressionTicketsRejectKnownProtocolDestinations`,
  `testRegressionQuotePayoutsRejectKnownProtocolDestinations`,
  `testRegressionFactoryRejectsKnownProtocolFixedClaimants`,
  `testRegressionPredictedRaffleCannotBeItsOwnRecoveryRecipient`,
  `testRegressionPredictedRaffleCannotBeItsOwnTreasury`,
  `testRegressionUnsafeTransferCannotAssignWinningCredentialToRaffle` (`A`);
  `testRejectedWinningAndSponsorPrizeDestinationsPreserveClaims` (`U`);
  SECURITY-INVARIANTS #91-#97.
- **Commit.** `5772e54`.
- **Status.** Current. These are the fixes for internal findings `H-01`–`H-04`, `M-01`,
  and ETHSkills `ES-05`.
- **Caveats.** The `isRaffle` branch only fires when the destination **already has code**.
  An address that is code-less today and becomes a registered raffle later is explicitly
  **unsupported** (`RF-057`). Arbitrary unrelated contracts are not screened at all
  (`RF-069`).

---

# 7. Sale boundaries

### RF-026 — Sale start is inclusive, sale end is exclusive

- **Claim.** The sale is open at exactly `startTime` and closed at exactly `endTime`.
- **Technical.** `block.timestamp < startTime` reverts; `block.timestamp >= endTime` reverts.
  `requestDraw` requires `block.timestamp >= endTime`, so the two windows abut exactly.
- **Source.** `packages/contracts/src/Raffle.sol:113-114,159`.
- **Function / state.** `startTime`, `endTime`.
- **Evidence.** `testPurchaseAndCloseValidationBranches`, `testDrawRequestValidationBranches` (`U`);
  SECURITY-INVARIANTS #36, #53.
- **Commit.** `5772e54`.
- **Status.** Current.

### RF-027 — Scheduling is bounded at creation

- **Claim.** A raffle cannot be scheduled far in the future or run indefinitely.
- **Technical.** `startTime == 0` normalizes to `block.timestamp`; a nonzero start must not
  be in the past (`StartTimeInPast`) and must be within `MAX_START_DELAY` = 7 days
  (`StartTimeTooDistant`); `endTime > startTime` (`InvalidEndTime`); and
  `endTime - startTime <= MAX_SALE_DURATION` = 30 days (`SaleDurationTooLong`).
- **Source.** `packages/contracts/src/RaffleFactory.sol:74-86`;
  `packages/contracts/src/libraries/RaffleConstants.sol:29,32`.
- **Function / state.** `MAX_START_DELAY`, `MAX_SALE_DURATION`.
- **Evidence.** `testFactoryEnforcesBoundedSchedulingAndFutureOnlyAdministration` (`U`);
  SECURITY-INVARIANTS #12-#14.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** These bounds cap how long the sponsor's NFT can sit in escrow before the
  outcome is determined: at most 7 + 30 + 3 + 2 days to a resolution or refund, plus up to
  30 more days if an NFT result is never redeemed.

### RF-028 — Creation parameters are validated

- **Claim.** A raffle cannot be created with a free ticket, an unreachable threshold, an
  unbounded metadata URI, or a prize contract that does not claim to be an ERC-721.
- **Technical.** `_validateCreateParams` requires `prizeToken` to have code, to answer
  `supportsInterface(type(IERC721).interfaceId)` with `true` (a throwing call reverts with
  `UnsupportedPrizeToken`), `ticketPrice != 0`, `minimumTickets != 0`, and
  `bytes(metadataURI).length <= 2048`.
- **Source.** `packages/contracts/src/RaffleFactory.sol:179-194`;
  `packages/contracts/src/libraries/RaffleConstants.sol:44`.
- **Function / state.** `UnsupportedPrizeToken`, `ZeroTicketPrice`, `ZeroMinimumTickets`,
  `MetadataURITooLong`.
- **Evidence.** `testFactoryConstructorAndCreationValidation` (`U`);
  SECURITY-INVARIANTS #11, #15, #16.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** ERC-165 support is self-reported. It proves nothing about honesty or value
  (`RF-068`). `minimumTickets` is unbounded above, so a sponsor can set a threshold that is
  effectively unreachable, guaranteeing the cash branch.

---

# 8. Draw request

### RF-029 — Anyone can request the draw, once, in a three-day window after the sale

- **Claim.** The draw is permissionless — the sponsor cannot refuse to run it — but it must
  happen within three days of the sale ending.
- **Technical.** `requestDraw` requires `status == Active`, `block.timestamp >= endTime`,
  `totalTickets != 0`, and `block.timestamp < requestGraceDeadline()` where
  `requestGraceDeadline() = endTime + DRAW_REQUEST_GRACE_PERIOD (3 days)`. On success it
  sets `status = Drawing`, which makes a second request impossible.
- **Source.** `packages/contracts/src/Raffle.sol:157-186,302-304`;
  `packages/contracts/src/libraries/RaffleConstants.sol:35`.
- **Function / state.** `requestDraw`, `requestGraceDeadline()`, `drawRequestedAt`,
  `entropySequenceNumber`, `DrawRequestWindowExpired`, `NoTicketsSold`.
- **Evidence.** `testDrawRequestValidationBranches` (`U`);
  `invariantAtMostOneRequestAndTerminalChoiceExist` (`I`);
  `testZeroAndRepeatedSequencesRemainSingleRaffleScoped` (`A`);
  SECURITY-INVARIANTS #52-#54.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** The requester pays the Entropy fee in native ETH out of their own pocket and
  is not reimbursed by the protocol. There is no protocol-funded keeper. If nobody
  volunteers within three days, the raffle refunds (`RF-040`).

### RF-030 — The Entropy fee is quoted live, forwarded exactly, and overpayment is returned immediately

- **Claim.** The requester pays exactly the oracle's current price and gets any excess back
  in the same transaction.
- **Technical.** `getEntropyFee()` returns `entropy.getFeeV2(callbackGasLimit)`.
  `requestDraw` reverts with `InsufficientEntropyFee` if `msg.value < fee`, forwards exactly
  `fee` via `requestV2{value: fee}(callbackGasLimit)`, then returns `msg.value - fee` with a
  raw assembly `call` that copies **zero** return data. If that return fails, the entire
  request reverts with `NativeRefundFailed`. The same `callbackGasLimit` is used for both
  the quote and the request.
- **Source.** `packages/contracts/src/Raffle.sol:152-154,165-185`.
- **Function / state.** `getEntropyFee()`, `InsufficientEntropyFee`, `NativeRefundFailed`.
- **Evidence.** `testEntropyDynamicFeeForwardsExactAndImmediatelyReturnsExcess`,
  `testImmediateNativeRefundIgnoresOversizedReturnData`,
  `testRejectedImmediateNativeRefundRevertsEntireEntropyRequest` (`U`);
  `testQuotedFeeCanBeZeroOrBecomeInsufficientWithoutConsumingRequest`,
  `testFeeReadAndRequestFailuresRollBackToActive` (`A`);
  `BaseFork.t.sol` real `getFeeV2(300_000)` / `requestV2(300_000)` encoding (`K`);
  SECURITY-INVARIANTS #10, #55-#57.
- **Commit.** `5772e54`.
- **Status.** Current. The zero-returndata-copy assembly is the fix for ETHSkills `ES-09`.
- **Caveats.** The raffle never holds a native-currency balance;
  `receive()` reverts with `DirectNativeTransfer` (`RF-052`). The observed Base mainnet fee
  quote at fork block 49,752,968 was `10,000,000,000,000` wei, and Pyth may apply a provider
  minimum gas limit above the requested one — the fork run observed a 500,000 effective
  limit against a local callback consumption of 95,078 gas
  (`packages/contracts/audit/FORK-VALIDATION.md:39-43`). Fee levels are external and change.

### RF-031 — A failed fee read or failed request leaves the raffle `Active` and still refundable

- **Claim.** A broken oracle call does not consume the raffle's one draw attempt.
- **Technical.** Status is set to `Drawing` inside the same transaction as the external call;
  if the call reverts, the whole transaction reverts and the status write is undone. The
  three-day grace window continues to run and the refund path stays reachable.
- **Source.** `packages/contracts/src/Raffle.sol:168-171`.
- **Function / state.** `_requestInFlight`, `status`.
- **Evidence.** `testFeeReadAndRequestFailuresRollBackToActive`,
  `testSuccessfulRequestWithoutPersistenceStillHasBoundedRefundRecovery` (`A`);
  SECURITY-INVARIANTS #55.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** A request that succeeds at Entropy but whose transaction is later reorged out
  is an external chain-reorganization concern, not a contract-level one.

---

# 9. Callback authentication and winner selection

### RF-032 — Only the immutable Entropy contract can deliver a callback

- **Claim.** Nobody can fake the random number.
- **Technical.** `Raffle` extends Pyth's `IEntropyConsumer`, whose external entry point
  requires `msg.sender == getEntropy()`. `Raffle.getEntropy()` returns the `immutable`
  `entropy` address.
- **Source.** `packages/contracts/src/Raffle.sol:29,418-420` (plus
  `@pythnetwork/entropy-sdk-solidity/IEntropyConsumer`).
- **Function / state.** `getEntropy()`, `entropyCallback`.
- **Evidence.** `testWrongDuplicateAndLateCallbacksAreHarmless` (`U`);
  `testSynchronousDuplicateAndWrongCallbacksCannotResolveInFlightRequest` (`A`);
  `BaseFork.t.sol` callback-wrapper authentication rejection (`K`);
  SECURITY-INVARIANTS #61.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** This authenticates the _contract_, not the _provider_. See `RF-046`.

### RF-033 — Stale, duplicate, wrong-sequence, and in-flight callbacks are ignored, not reverted

- **Claim.** A late or unexpected callback quietly does nothing rather than breaking.
- **Technical.** `entropyCallback` returns early — emitting `EntropyCallbackIgnored` — when
  `_requestInFlight` is true, `status != Drawing`, or
  `sequence != entropySequenceNumber`. `_requestInFlight` is set before the external
  `requestV2` call and cleared after the returned sequence number is stored, which blocks a
  synchronous callback from settling before the sequence is known.
- **Source.** `packages/contracts/src/Raffle.sol:62,170-173,385-389`.
- **Function / state.** `_requestInFlight`, `EntropyCallbackIgnored`.
- **Evidence.** `testWrongDuplicateAndLateCallbacksAreHarmless` (`U`);
  `testSynchronousDuplicateAndWrongCallbacksCannotResolveInFlightRequest`,
  `testZeroAndRepeatedSequencesRemainSingleRaffleScoped` (`A`);
  `check_timeoutExcludesLateCallback`, `check_resolutionExcludesTimeout` (`H`);
  SECURITY-INVARIANTS #59-#63.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** Returning instead of reverting is deliberate: reverting inside a Pyth callback
  can have provider-side consequences. The trade-off is that an ignored callback is only
  visible as an event.

### RF-034 — The callback performs bounded storage work and makes no external call

- **Claim.** Settlement cannot be blocked or attacked through the callback.
- **Technical.** `entropyCallback` reads `totalTickets` and `unsettledPot`, computes the
  winner and the fee, writes a fixed set of storage slots, and emits `RaffleResolved`. It
  calls no ERC-20, no ERC-721, and no user address. There is no loop.
- **Source.** `packages/contracts/src/Raffle.sol:385-415`.
- **Function / state.** `entropyCallback`.
- **Evidence.** `testCallbackGasHasSafetyMargin` (`U`, asserts the local callback stays
  below 80% of the configured limit);
  measured 95,078 gas on fork (`FORK-VALIDATION.md:41`);
  SECURITY-INVARIANTS #64; RELEASE-CHECKLIST "Callback work is bounded beneath 300,000 gas".
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** The `callbackGasLimit` must still be re-measured against the exact deployed
  bytecode before release (`RELEASE-CHECKLIST.md:91`, unchecked).

### RF-035 — The winner is `(random mod totalTickets) + 1`

- **Claim.** The random number is mapped onto the sold ticket range.
- **Technical.** `resolvedTicketId = (uint256(randomNumber) % totalTickets) + 1`. The result
  is always in `[1, totalTickets]`, never zero.
- **Source.** `packages/contracts/src/Raffle.sol:391`.
- **Function / state.** `winningTicketId`, `resolvedAt`.
- **Evidence.** `testFuzzWinningTicketAlwaysUsesInclusiveSoldRange` (`F`);
  `invariantResolvedWinningTicketIsAlwaysInSoldRange` (`I`);
  `invariantStrictWinnerAndFeeAreBounded` (`S`);
  `echidna_winner_is_in_sold_range` (`E`);
  `check_oneTicketAlwaysSelected` (`H`); SECURITY-INVARIANTS #65-#66.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** **Modulo bias is nonzero** whenever `totalTickets` does not evenly divide
  `2^256`. It is cryptographically negligible for realistic ticket counts and is accepted
  and disclosed as ETHSkills `ES-10`. The protocol must not be described as producing a
  perfectly uniform draw.

---

# 10. NFT-success branch

### RF-036 — Meeting the threshold selects the NFT outcome and leaves the pot escrowed

- **Claim.** If enough tickets sold, the winner gets the NFT — but the sponsor is not paid
  until the NFT has actually been delivered.
- **Technical.** In the callback, `totalTickets >= minimumTickets` sets `status = NftWon`.
  `unsettledPot` is **not** zeroed and **no** claim is credited. The `sponsorCashAmount`
  reported in `RaffleResolved` is informational for this branch. Threshold equality selects
  `NftWon`; one below selects `CashWon`.
- **Source.** `packages/contracts/src/Raffle.sol:401-403,414`.
- **Function / state.** `Status.NftWon`, `unsettledPot`, `minimumTickets`.
- **Evidence.** `testFuzzThresholdBoundarySelectsSingleStatus` (`F`);
  `testNftWinnerBurnsBearerTicketAndProtocolReceivesFivePercent` (`U`);
  SECURITY-INVARIANTS #73-#74; ECONOMICS.md:13-16.
- **Commit.** `5772e54`.
- **Status.** Current. Escrow-until-delivery is the fix for ETHSkills `ES-03`.
- **Caveats.** Between resolution and redemption the full gross pot sits in the raffle. It
  is not the sponsor's yet and not the buyers' yet.

### RF-037 — NFT delivery and the fee/sponsor payout happen atomically

- **Claim.** The sponsor and the treasury get paid at the same instant the winner gets the NFT
  — never before.
- **Technical.** `redeemWinningTicket(to)` in the `NftWon` branch: burns the ticket, sets
  `prizeClaimed = true`, calls `prizeToken.safeTransferFrom(address(this), to, prizeTokenId)`,
  then **verifies** `prizeToken.ownerOf(prizeTokenId) == to` (reverting with
  `PrizeDeliveryVerificationFailed` otherwise). Only then does it compute
  `protocolFee = mulDiv(unsettledPot, 500, 10000)`, zero `unsettledPot`, and credit
  `protocolTreasury` with the fee and `sponsor` with the remainder.
- **Source.** `packages/contracts/src/Raffle.sol:216-244`.
- **Function / state.** `redeemWinningTicket`, `_creditQuote`, `claimableQuote`,
  `PrizeDeliveryVerificationFailed`.
- **Evidence.** `testNftWinnerBurnsBearerTicketAndProtocolReceivesFivePercent` (`U`);
  `testWinningTicketBurnPrecedesSafePrizeTransferAndBlocksReentry`,
  `testRegressionBrokenPrizeCannotReleaseProceedsAndFallsBackToRefunds` (`A`);
  `invariantSuccessfulSettlementAlwaysChargesFivePercent` (`I`);
  SECURITY-INVARIANTS #71, #74.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** The destination `to` must be nonzero and must not be a known protocol
  destination. If it fails, nothing is consumed and the winner can retry elsewhere.

---

# 11. Cash-fallback branch

### RF-038 — Missing the threshold pays the winner cash and returns the NFT to the sponsor side

- **Claim.** If not enough tickets sold, the drawn ticket wins most of the money instead of
  the NFT, and the sponsor keeps the NFT.
- **Technical.** In the callback, `totalTickets < minimumTickets` sets `status = CashWon`,
  zeroes `unsettledPot`, and immediately records all three liabilities:
  `protocolFee = mulDiv(grossPot, 500, 10000)`;
  `distributablePot = grossPot - protocolFee`;
  `winnerCashLiability = mulDiv(distributablePot, 8000, 10000)`;
  `sponsorCashAmount = distributablePot - winnerCashLiability` credited to `sponsor`;
  `protocolFee` credited to `protocolTreasury`.
  The winner later calls `redeemWinningTicket(to)`, which burns the ticket and pays
  `winnerCashLiability` directly. The `sponsorPrizeRecoveryRecipient` separately calls
  `claimSponsorPrize(to)` to withdraw the NFT.
- **Source.** `packages/contracts/src/Raffle.sol:404-412,237-241,284-299`;
  `packages/contracts/src/libraries/RaffleConstants.sol:17,20`.
- **Function / state.** `Status.CashWon`, `winnerCashLiability`, `claimableQuote`,
  `CASH_WINNER_BPS = 8000`.
- **Evidence.** `testCashWinnerBurnsBearerTicketAndFeeStillApplies` (`U`);
  `testFuzzCashRoundingConservesGrossAndFeesBothBranches` (`F`);
  `testFuzzThresholdBoundarySelectsSingleStatus` (`F`);
  SECURITY-INVARIANTS #75-#76; ECONOMICS.md:19-35.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** Both divisions floor. The remainder is assigned to the sponsor
  (`sponsorCashAmount = distributablePot - winnerCashLiability`), which makes the split
  conserve every raw unit exactly. Accepted as ETHSkills `ES-11`.

**Worked reference (matches `docs/ECONOMICS.md:28-35` and `README.md:75-77`):**
80 tickets × 1.00 USDC, threshold 100.
`grossSales = 80.00`; `protocolFee = floor(80.00 × 0.05) = 4.00`;
`distributablePot = 76.00`; `winnerCash = floor(76.00 × 0.80) = 60.80`;
`sponsorCash = 76.00 − 60.80 = 15.20`; plus the NFT to the recovery recipient.

---

# 12. Refund paths

### RF-039 — One function, `enableRefunds()`, covers all three refund origins

- **Claim.** Whatever goes wrong, the same permissionless function opens refunds.
- **Technical.** `enableRefunds()` is callable by anyone and dispatches on status:
  - `Active` (with `totalTickets != 0`) — deadline is `requestGraceDeadline()`
    = `endTime + 3 days`; `requestWasAccepted = false`.
  - `Drawing` — deadline is `callbackDeadline()` = `drawRequestedAt + 2 days`;
    `requestWasAccepted = true`.
  - `NftWon` **and** `!prizeClaimed` — deadline is `nftRedemptionDeadline()`
    = `resolvedAt + 30 days`; `requestWasAccepted = true`.
  - anything else reverts with `InvalidStatus`.
    Before the deadline it reverts with `RefundsNotAvailable`. On success it moves the entire
    `unsettledPot` into `remainingRefundLiability`, zeroes `unsettledPot`, sets
    `status = Refunding`, and emits `RefundsEnabled(finalizer, requestWasAccepted, liability)`.
- **Source.** `packages/contracts/src/Raffle.sol:189-213,302-316`;
  `packages/contracts/src/libraries/RaffleConstants.sol:35,38,41`.
- **Function / state.** `enableRefunds`, `remainingRefundLiability`, `RefundsEnabled`.
- **Evidence.** `testOneFunctionEnablesNoRequestAndCallbackTimeoutRefunds`,
  `testUnredeemedNftResultFallsBackToFullTicketRefunds`,
  `testEnableRefundsRejectsResolvedAndTerminalStatuses` (`U`);
  `testRefundEventsDistinguishMissingRequestFromAcceptedDrawAndNftTimeout` (`A`);
  `check_timeoutExcludesLateCallback` (`H`);
  SECURITY-INVARIANTS #68-#70, #77.
- **Commit.** `5772e54`.
- **Status.** Current. The `NftWon` origin is the fix for ETHSkills `ES-03`.
- **Caveats.** `requestWasAccepted` does **not** distinguish the callback timeout from the
  NFT-delivery timeout — both report `true`. The status at the time of the event
  distinguishes them, and `EXTREME-TESTING-2026-08-13.md:26-28` records the exact event
  semantics as a locked-in regression.

### RF-040 — Refund origin 1: no successful randomness request

- **Claim.** If nobody requests the draw within three days of the sale ending, everyone gets
  their money back.
- **Technical.** From `Active` at `endTime + 3 days`. `unsettledPot` still equals
  `grossSales`, so the entire pot becomes refundable.
- **Source.** `packages/contracts/src/Raffle.sol:193-195`.
- **Evidence.** `testOneFunctionEnablesNoRequestAndCallbackTimeoutRefunds` (`U`);
  SECURITY-INVARIANTS #68.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** Requires `totalTickets != 0`; a zero-sale raffle uses `RF-045` instead.

### RF-041 — Refund origin 2: request accepted but no callback

- **Claim.** If the oracle accepts the request and then never answers, everyone gets their
  money back after two days.
- **Technical.** From `Drawing` at `drawRequestedAt + 2 days`.
- **Source.** `packages/contracts/src/Raffle.sol:196-198`.
- **Evidence.** `testOneFunctionEnablesNoRequestAndCallbackTimeoutRefunds` (`U`);
  `testCallbackDeadlineIsFirstIncludedTransitionNotAutomaticExpiry` (`A`);
  `check_timeoutExcludesLateCallback` (`H`); SECURITY-INVARIANTS #69-#70.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** **The deadline does not automatically change state.** At and after the
  deadline, a valid callback and `enableRefunds()` are both executable; whichever
  transaction is included first wins and the other becomes a no-op. If nobody finalizes
  refunds, a valid callback remains executable indefinitely — `RaffleExtreme.t.sol`
  deliberately tests a callback a year past its deadline.

### RF-042 — Refund origin 3: NFT winner cannot complete delivery

- **Claim.** If the prize NFT becomes undeliverable, buyers get the **entire** pot back —
  the sponsor and the treasury get nothing.
- **Technical.** From `NftWon` with `!prizeClaimed` at `resolvedAt + 30 days`. Because
  `RF-036` left `unsettledPot` untouched and `RF-037` never ran, the full gross pot converts
  to refund liability and no fee or sponsor claim is ever created.
- **Source.** `packages/contracts/src/Raffle.sol:199-201,312-316`.
- **Evidence.** `testUnredeemedNftResultFallsBackToFullTicketRefunds` (`U`);
  `testRegressionBrokenPrizeCannotReleaseProceedsAndFallsBackToRefunds`,
  `testNftDeadlineIsFirstIncludedTransitionNotAutomaticExpiry` (`A`);
  SECURITY-INVARIANTS #70, #72.
- **Commit.** `5772e54`.
- **Status.** Current. Fix for ETHSkills `ES-03`.
- **Caveats.** Same first-included-transition semantics as `RF-041`: a winner who resolves
  their delivery problem on day 31 can still redeem, provided nobody has finalized refunds
  first. This branch also triggers when a winner simply never bothers to redeem — 30 days of
  inaction converts an NFT win into a full buyer refund.

### RF-043 — Refund redemption burns tickets for exactly the purchase price

- **Claim.** Each refunded ticket pays back exactly what it cost, in batches of up to 100.
- **Technical.** `redeemRefundTickets(ticketIds, to)` requires `status == Refunding`,
  `to != address(0)`, and `1 <= ticketIds.length <= 100`. For each ID it requires
  `msg.sender == ownerOf(id)` and burns it. Then `amount = ticketPrice * quantity`,
  `remainingRefundLiability -= amount`, and `_transferQuoteExact(to, amount)`.
- **Source.** `packages/contracts/src/Raffle.sol:247-271`;
  `packages/contracts/src/libraries/RaffleConstants.sol:26`.
- **Function / state.** `redeemRefundTickets`, `remainingRefundLiability`,
  `MAX_REFUND_REDEMPTION_BATCH_SIZE = 100`.
- **Evidence.** `testRefundRedemptionRequiresActualOwnerAndBoundedBatch`,
  `testRefundTicketsRemainTransferableAndBurnForExactRefund` (`U`);
  `testFuzzRefundBurnsPayExactlyOnce` (`F`);
  `testDuplicateAndMixedOwnerRefundBatchesAreFullyAtomic` (`A`);
  `check_refundCredentialConsumesAtMostOnce` (`H`);
  SECURITY-INVARIANTS #78-#81.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** A duplicate or foreign ID reverts the **whole batch** atomically. The SDK
  rejects duplicate/empty/oversized batches before simulation
  (`packages/sdk/src/actions.ts:168-190`). Refunds are per-ticket-price, so a buyer who
  bought at a discount or premium on a secondary market bears that difference.

### RF-044 — No fee and no sponsor proceeds on any refund path

- **Claim.** When a raffle fails, the protocol takes nothing.
- **Technical.** `enableRefunds` never calls `_creditQuote`. Both successful-branch fee
  calculations live only in `entropyCallback`'s `CashWon` arm and in
  `redeemWinningTicket`'s `NftWon` arm.
- **Source.** `packages/contracts/src/Raffle.sol:189-213`.
- **Evidence.** `invariantRefundingNeverChargesProtocolFee` (`I`);
  SECURITY-INVARIANTS #72; ECONOMICS.md:37-39.
- **Commit.** `5772e54`.
- **Status.** Current.

---

# 13. Empty-raffle closure

### RF-045 — A zero-sale raffle can be closed and the NFT returned

- **Claim.** If nobody buys a ticket, the sponsor gets the NFT back.
- **Technical.** `closeEmptyRaffle()` requires `status == Active` and `totalTickets == 0`.
  Before `endTime` only the `sponsor` may call it (`OnlySponsor`); at or after `endTime`
  anyone may. It sets `status = Closed` and emits `EmptyRaffleClosed`. The
  `sponsorPrizeRecoveryRecipient` then calls `claimSponsorPrize(to)`.
- **Source.** `packages/contracts/src/Raffle.sol:142-149`.
- **Function / state.** `Status.Closed`, `TicketsWereSold`, `OnlySponsor`.
- **Evidence.** `testEmptyRaffleClosesEarlyForSponsorAndAfterEndForAnyone` (`U`);
  `testPurchaseAndCloseValidationBranches` (`U`); SECURITY-INVARIANTS #50.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** The early-close privilege lets a sponsor cancel a raffle that has attracted no
  buyers, but only while it has genuinely sold zero tickets. One ticket permanently removes
  the option.

---

# 14. Protocol fee and splits

### RF-046 — The protocol fee is 5% of gross sales, floored, charged only on success

- **Claim.** raffle.fun takes 5% — and only when a raffle actually resolves.
- **Technical.** `PROTOCOL_FEE_BPS = 500`, `BPS = 10_000`.
  `protocolFee = Math.mulDiv(grossPot, 500, 10_000)` (floor). Computed once from the
  aggregate pot, in exactly two places: the `CashWon` arm of the callback, and the `NftWon`
  arm of `redeemWinningTicket`. Never charged on any refund path.
- **Source.** `packages/contracts/src/Raffle.sol:233,393`;
  `packages/contracts/src/libraries/RaffleConstants.sol:14,17`.
- **Function / state.** `PROTOCOL_FEE_BPS`, `claimableQuote[protocolTreasury]`.
- **Evidence.** `invariantSuccessfulSettlementAlwaysChargesFivePercent` (`I`);
  `invariantRefundingNeverChargesProtocolFee` (`I`);
  `testFuzzCashRoundingConservesGrossAndFeesBothBranches` (`F`);
  `invariantStrictWinnerAndFeeAreBounded` (`S`); SECURITY-INVARIANTS #71-#72.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** The rate is a compile-time constant in `RaffleConstants`, baked into every
  deployed raffle. It cannot be changed for an existing raffle by anyone. Changing it for
  future raffles requires deploying new bytecode and a new factory. The buyer never pays it
  separately — it comes out of the pot.

### RF-047 — Value is conserved exactly in every branch

- **Claim.** Every raw unit of USDC that enters a raffle is accounted for.
- **Technical.** In `CashWon`: `protocolFee + winnerCash + sponsorCash == grossPot`, because
  the sponsor receives the subtraction remainder of both floor divisions. In `NftWon` at
  redemption: `protocolFee + sponsorProceeds == grossPot`. In `Refunding`:
  `remainingRefundLiability == unsettledPot` at enablement and decreases by exactly
  `ticketPrice` per burned ticket.
- **Source.** `packages/contracts/src/Raffle.sol:233-236,393-412,208-211,267-268`.
- **Evidence.** `testFuzzCashRoundingConservesGrossAndFeesBothBranches` (`F`);
  `echidna_gross_equals_balance_plus_payouts` (`E`);
  `invariantQuotePaidInEqualsPaidOutPlusContractBalance` (`I`);
  `testAliasedSponsorTreasuryBuyerAndWinnerConserveAllQuote` (`A`);
  SECURITY-INVARIANTS #76.
- **Commit.** `5772e54`.
- **Status.** Current.

---

# 15. Sponsor and treasury claims

### RF-048 — Sponsor-side NFT recovery is restricted to a fixed recipient and three statuses

- **Claim.** Only one pre-declared address can pull the NFT back, and only when the raffle
  did not award it.
- **Technical.** `claimSponsorPrize(to)` requires
  `msg.sender == sponsorPrizeRecoveryRecipient` (immutable, defaulting to the sponsor when
  the create parameter is zero), `status ∈ {CashWon, Refunding, Closed}`, `to != 0`,
  `to` not a known protocol destination, and `!prizeClaimed`.
- **Source.** `packages/contracts/src/Raffle.sol:284-299`;
  `packages/contracts/src/RaffleFactory.sol:88-89`.
- **Function / state.** `sponsorPrizeRecoveryRecipient`, `OnlyPrizeRecoveryRecipient`,
  `SponsorPrizeUnavailable`, `PrizeAlreadyClaimed`.
- **Evidence.** `testSponsorPrizeRecoveryExistsOnlyForCashRefundAndClosed` (`U`);
  `testRejectedWinningAndSponsorPrizeDestinationsPreserveClaims` (`U`);
  SECURITY-INVARIANTS #30, #32-#33.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** Deliberately **not** available in `NftWon` — the prize is the winner's there.
  The recovery recipient is fixed at creation and cannot be changed, so a sponsor who names
  a wrong or unusable address has no remedy.

### RF-049 — Sponsor and treasury proceeds are pull claims

- **Claim.** The protocol never pushes money; each party withdraws its own.
- **Technical.** `_creditQuote(account, amount)` increments `claimableQuote[account]` and
  `totalClaimableQuote`. `claimQuote(to)` pays the caller's own claim to any nonzero,
  non-protocol destination. `claimQuoteFor(account)` is permissionless but can only pay
  `account` to `account` itself. Both zero the claim before transferring.
- **Source.** `packages/contracts/src/Raffle.sol:274-281,423-439`.
- **Function / state.** `claimableQuote`, `totalClaimableQuote`, `NoQuoteClaim`, `QuoteClaimed`.
- **Evidence.** `testBearerSettlementAndQuoteClaimValidationBranches` (`U`);
  `invariantAccountedQuoteIsExactlyTheFourLiabilitiesAndSolvent` (`I`);
  `echidna_quote_liability_identity_and_solvency` (`E`);
  SECURITY-INVARIANTS #83-#85.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** `claimQuoteFor` lets a third party pay gas to settle a passive treasury or
  sponsor, but cannot redirect the funds. One claimant can never block another.

---

# 16. Quote-token accounting

### RF-050 — The accounting identity

- **Claim.** At every moment, the raffle knows exactly what it owes and to whom.
- **Technical.**
  `accountedQuoteBalance() = unsettledPot + remainingRefundLiability + winnerCashLiability + totalClaimableQuote`.
  The raffle's actual USDC balance is always `>=` this value; any excess is a donation and
  never becomes a liability.
- **Source.** `packages/contracts/src/Raffle.sol:325-327`.
- **Function / state.** All four liability accumulators.
- **Evidence.** `invariantAccountedQuoteIsExactlyTheFourLiabilitiesAndSolvent` (`I`);
  `invariantStrictQuoteAccountingReconciles` (`S`);
  `echidna_quote_liability_identity_and_solvency` (`E`);
  `testDirectDonationDoesNotAlterLiabilities` (`U`);
  `invariantFleetAccountingIsLocallyExactAndGloballySolvent` (`I`);
  SECURITY-INVARIANTS #89-#90; ECONOMICS.md:41-50.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** Donated USDC is unrecoverable — there is no sweep function. This is a
  deliberate consequence of having no admin.

### RF-051 — Outgoing transfers verify both the debit and the credit

- **Claim.** If the token would deliver a different amount than owed, the payout reverts and
  the claim survives.
- **Technical.** `_transferQuoteExact(to, amount)` rejects known protocol destinations, then
  snapshots `balanceOf(this)` and `balanceOf(to)` before and after `safeTransfer`, and
  reverts with `UnsupportedQuoteTokenTransfer` unless the raffle was debited by exactly
  `amount` **and** the recipient credited by exactly `amount`. The revert restores the
  ticket burn, the cleared claim, and the decremented liability.
- **Source.** `packages/contracts/src/Raffle.sol:445-462`.
- **Function / state.** `UnsupportedQuoteTokenTransfer(expected, debited, credited)`,
  `InvalidQuoteDestination`.
- **Evidence.** `testNonExactOutboundTokenCannotDestroyQuoteLiabilities` (`A`);
  `testOverCreditAndSenderRebateTokensCannotSpoofExactAccounting` (`A`);
  SECURITY-INVARIANTS #86-#88.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** Checking both sides catches recipient-bonus and sender-rebate tokens that a
  one-sided check would miss. It cannot force a blacklisted or paused token to transfer —
  it only guarantees the onchain claim is preserved for a later retry (`RF-066`).

### RF-052 — The raffle refuses direct native currency

- **Claim.** ETH sent to a raffle is rejected.
- **Technical.** `receive() external payable { revert DirectNativeTransfer(); }`. Native
  value enters only through `requestDraw`, and any excess leaves in the same transaction.
- **Source.** `packages/contracts/src/Raffle.sol:377-379`.
- **Function / state.** `DirectNativeTransfer`.
- **Evidence.** `testViewsMetadataUnexpectedPrizeAndNativeRejection` (`U`);
  `testForcedNativeCurrencyNeverEntersQuoteAccountingOrDrawFees` (`A`);
  SECURITY-INVARIANTS #58.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** Native currency can still be **forced** in via `SELFDESTRUCT` or a coinbase
  payout. Such balance is outside protocol accounting, never affects quote settlement, and
  has no rescue path.

---

# 17. RaffleLens

### RF-053 — RaffleLens is a stateless, registry-authenticated read aggregator

- **Claim.** The lens is a convenience for wallets and never touches money or state.
- **Technical.** `RaffleLens` holds no assets, has no mutating function, and is bound to one
  `immutable factory`. `getRaffleState(raffle, account)` reverts with `UnregisteredRaffle`
  unless `factory.isRaffle(raffle)`. `getRaffleStates` caps the batch at `MAX_BATCH_SIZE = 64`.
  A failing `getEntropyFee()` is caught and reported as
  `entropyFeeAvailable = false` rather than failing the whole read.
- **Source.** `packages/contracts/src/RaffleLens.sol:18-131`.
- **Function / state.** `getRaffleState`, `getRaffleStates`, `RaffleView`,
  `UnregisteredRaffle`, `BatchTooLarge`, `InvalidFactory`.
- **Evidence.** `testLensReportsBearerActionsAndHandlesEntropyFeeFailure` (`U`);
  `testGasBoundedPurchaseRefundAndLensBatches` (`U`);
  SECURITY-INVARIANTS #102-#104.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** The lens is a **separately deployed contract**, so it is not covered by
  `_isKnownProtocolDestination`. A user who unsafe-transfers a ticket to the Lens address
  loses it; this is accepted informational risk `I-01`.
  `RaffleView.canDraw`, `canEnableRefunds`, etc. are computed against `block.timestamp` at
  read time and are advisory, not authoritative.

---

# 18. Supported and unsupported assets

### RF-054 — Supported prize: an honest, standards-compliant ERC-721

- **Claim.** The recovery guarantee assumes the NFT contract behaves normally.
- **Technical.** The protocol requires the prize to answer ERC-165 for `IERC721`, to honor
  `safeTransferFrom` in both directions, and to report `ownerOf` truthfully.
- **Source.** `packages/contracts/src/RaffleFactory.sol:180-187`;
  `packages/contracts/src/Raffle.sol:229-230`; `packages/contracts/src/interfaces/IRaffle.sol:15-16`.
- **Evidence.** `SECURITY.md:73-79`; THREAT-MODEL.md:31-37; SECURITY-INVARIANTS #16, #21-#28.
- **Commit.** `5772e54`.
- **Status.** Current.

### RF-055 — Supported payment: one non-rebasing, exact-transfer ERC-20 (intended: USDC)

- **Claim.** Raffles are priced and settled in a single stablecoin fixed per factory.
- **Technical.** `quoteToken` is a factory-level `immutable`. Both incoming (`RF-015`) and
  outgoing (`RF-051`) transfers verify exact balance deltas. Deployment validation
  additionally requires six decimals and an unpaused token state.
- **Source.** `packages/contracts/src/RaffleFactory.sol:25,41-42`;
  `packages/contracts/scripts/deployment-validation.ts`; `docs/DEPLOYMENT.md:30-33`.
- **Evidence.** `DeploymentValidation.test.ts` (`X`); `BaseFork.t.sol` USDC decimals and
  exact-delta checks (`K`); SECURITY-INVARIANTS #8, #109.
- **Commit.** `5772e54`.
- **Status.** Current. **The contracts are not hard-coded to USDC** — the factory accepts
  any address with code. "USDC" is a deployment-time choice enforced by validation scripts
  and human review, not by the Solidity.
- **Caveats.** Circle can pause, freeze, blacklist, or upgrade USDC. The exact-delta checks
  preserve the onchain claim across such an event but cannot force a transfer.

### RF-056 — Explicitly unsupported

- **Claim.** Some things simply do not work and the protocol says so rather than pretending.
- **Technical / list.**
  - Fee-on-transfer, rebasing, or otherwise non-exact ERC-20s — rejected at runtime by
    `RF-015` / `RF-051`.
  - Malicious or upgradeable ERC-721s that lie about ERC-165 or `ownerOf`.
  - Unrelated NFTs pushed in with unsafe `transferFrom` — never accounted, no rescue.
  - Donated USDC or forced native currency — never a liability, no sweep.
  - Tickets or fixed claims assigned to an address that cannot initiate a call
    (lost key, or a contract with no redemption capability).
  - Tickets or fixed claims assigned to an address that is **code-less now** and becomes a
    registered raffle **later** (see `RF-057` below).
  - A raffle ticket minted by a **different factory** used as a prize (see `RF-074`); the
    same-factory case is rejected at creation.
- **Source.** `packages/contracts/src/Raffle.sol:355-358,376-379`; `SECURITY.md:73-79`;
  `packages/contracts/audit/RESIDUAL-RISKS.md:8-23`.
- **Evidence.** `testFeeOnTransferQuoteTokenIsRejectedWithoutCreatingLiability`,
  `testFalseReturningQuoteTokenIsRejected`,
  `testForcedNativeCurrencyNeverEntersQuoteAccountingOrDrawFees` (`A`);
  `testDirectDonationDoesNotAlterLiabilities` (`U`);
  SECURITY-INVARIANTS #99, #101.
- **Commit.** `5772e54`.
- **Status.** Current.

---

# 19. Removed behavior — do not restore

### RF-057 — `recoverProtocolOwnedClaim` no longer exists

- **Claim.** An earlier design had a cross-raffle recovery dispatcher. It was **removed**
  because it was itself exploitable. Public documentation must not describe it.
- **Technical.** The `ProtocolOwnedClaim` enum, the `recoverProtocolOwnedClaim` dispatcher,
  the SDK action, and the ABI entry were all deleted. `grep` over
  `packages/contracts/src/` at this commit returns no match. The only surviving references
  are (a) historical audit prose and (b) a regression test that asserts the selector is
  **not** callable.
- **Source.** Absence from `packages/contracts/src/Raffle.sol` and
  `packages/contracts/src/RaffleFactory.sol`;
  `packages/contracts/test/foundry/security/RaffleSecurity.t.sol:438` (negative test).
- **Function / state.** —
- **Evidence.** `testRegressionCapturedFutureRaffleCannotExerciseRemovedRecoveryPath` (`A`);
  `ETHSKILLS-REVIEW-2026-08-13.md` finding `ES-01`; SECURITY-INVARIANTS #98, #100;
  RELEASE-CHECKLIST "The unsafe predicted-address cross-raffle recovery dispatcher is removed".
- **Commit.** `5772e54`.
- **Status.** **Removed.** Present in `INTERNAL-AUDIT.md`, `INDEPENDENT-SPECIFICATION.md`,
  `FINDINGS.md`, `MUTATION-TESTING.md`, `TEST-CAMPAIGN.md`, `docs/whitepaper/README.md`, and
  the superseded `docs/WHITEPAPER.md` — all of which are historical.
- **Caveats.** Its removal is _why_ "a future code-less address" is an unsupported
  destination (`RF-056`): the dispatcher was the mechanism that would have resolved that
  case, and it was traded away because a permissionless `CREATE` caller could capture a
  predicted address and abuse it.

---

# 20. External dependencies

### RF-058 — Pyth Entropy v2 is the sole randomness source

- **Claim.** Randomness comes from Pyth Entropy, and its provider must be trusted for
  liveness and honest reveal.
- **Technical.** `Raffle` implements `IEntropyConsumer` against an `immutable IEntropyV2`.
  There is no second oracle, no fallback RNG, and no reroll.
- **Source.** `packages/contracts/src/Raffle.sol:11-12,37,418-420`.
- **Evidence.** `BaseFork.t.sol` live interface and fee reads (`K`);
  `docs/RANDOMNESS.md`; `FORK-VALIDATION.md:25-28`.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** **This is the protocol's most significant unresolved trust assumption.**
  See `RF-065`.

### RF-059 — Base is the target chain family

- **Claim.** raffle.fun is designed for Base.
- **Technical.** Deployment records accept only chain IDs 8453 (Base) and 84532 (Base
  Sepolia). Compiler target is `cancun`, supported on Base since Ecotone. Fork validation
  uses official Base addresses for USDC and Entropy.
- **Source.** `deployments/schema.json` (`chainId` enum `[8453, 84532]`);
  `packages/subgraph/networks.json`; `apps/web/src/lib/env.ts:24-34`;
  `packages/contracts/audit/FORK-VALIDATION.md:25-28`; `README.md:164-181`.
- **Evidence.** `BaseFork.t.sol` pinned-block runs at Base 49,752,968 / Base Sepolia
  45,263,498 and latest-head runs at Base 49,923,565 / Base Sepolia 45,434,095 (`K`);
  `DeploymentValidation.test.ts` (`X`).
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** The Solidity itself is chain-agnostic; the restriction is in tooling and
  validation, not in the contracts.

### RF-060 — Pinned toolchain

- **Claim.** The build is reproducible against specific dependency versions.
- **Technical.** Solidity `0.8.36` (exact pragma, `cancun`); OpenZeppelin Contracts `5.6.1`;
  Pyth Entropy Solidity SDK `2.2.1`; forge-std `37a36ca389095b2f677abb07642634573ba7e265`;
  Node `>=22.13 <23`; pnpm `11.18.0`.
- **Source.** `README.md:162-181`; `docs/DEPLOYMENT.md:11-17`;
  `packages/contracts/foundry.toml`.
- **Evidence.** `AUDIT-BASELINE.md:28-51`; compiler differential runs recorded in
  `DEEP-TESTING-2026-08-13.md:32-33`.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** `README.md:170-175` states Solidity 0.8.36's official per-version bug list is
  empty as of that review. Compiler bug lists must be rechecked on the release date
  (`docs/DEPLOYMENT.md:27`).

---

# 21. Current status

### RF-061 — Development status: pre-release, feature-complete, not release-ready

- **Claim.** The contracts are written and heavily tested, but the project has not shipped.
- **Technical.** `RELEASE-CHECKLIST.md:7` states verbatim: **"Current status: not
  release-ready."** Multiple items remain unchecked across source identity, deployment
  candidate, and external/operational blockers.
- **Source.** `packages/contracts/audit/RELEASE-CHECKLIST.md:7-15,16-27,83-115`.
- **Evidence.** The checklist itself.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Approved public wording.** "Pre-release. Not deployed. Not independently audited."
- **Prohibited wording.** Do not describe raffle.fun as audited, safe, trustless, fair,
  live, production-ready, or guaranteed. `RELEASE-CHECKLIST.md:117-119` states this
  restriction explicitly.

### RF-062 — Deployment status: no public deployment exists

- **Claim.** There is no live raffle.fun on any public network.
- **Technical.** `deployments/` contains only `schema.json` — zero deployment records.
  `packages/config/src/deployments.ts` therefore resolves to an empty map, making
  `apps/web/src/lib/protocol.ts:22` `protocolIsConfigured === false` and disabling all
  frontend writes. `README.md:216-217`: "No public-network deployment is part of repository
  validation." `docs/DEPLOYMENT.md:78-79`: "Mainnet has no default root deployment command."
- **Source.** `deployments/`; `packages/config/src/deployments.ts`;
  `apps/web/src/lib/protocol.ts:19-22`; `README.md:216-217`.
- **Evidence.** `DeploymentRecord.test.ts`, `DeploymentValidation.test.ts` (`X`);
  SECURITY-INVARIANTS #110; `AUDIT-BASELINE.md:104-109`.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** All fork testing reads public chain state through **local** forks. No
  transaction has been broadcast; every audit document states this explicitly.

### RF-063 — Internal review status: an internal adversarial campaign has been completed

- **Claim.** The team has run an extensive internal security campaign — which is evidence,
  not an audit.
- **Technical.** Most recent campaign is `EXTREME-TESTING-2026-08-13.md`, run against
  production contracts at commit `b992b23eabfffb4f5604524951c673f70b920603`, immediately
  preceding the current HEAD's test-only commit. Reported results:

  | Campaign                       | Result                                                           |
  | ------------------------------ | ---------------------------------------------------------------- |
  | Foundry aggregate              | 88 passed, 0 failed, 1 RPC-gated suite skipped                   |
  | Hardhat integration/deployment | 9 passed, 0 failed                                               |
  | Fleet invariants, 3 seeds      | 3,072,000 calls, 0 handler reverts, 0 violations                 |
  | Arithmetic/value fuzzing       | 600,000 cases                                                    |
  | Differential model             | 100,000 lifecycle sequences                                      |
  | Echidna 2.3.3                  | 1,000,747 calls, 12/12 properties                                |
  | Medusa 1.5.1                   | 523,017 calls, 46/46 tests                                       |
  | Gambit 1.0.6 (targeted sample) | 36/36 compiling mutants killed                                   |
  | Halmos 0.3.3 / Z3 4.12.6       | 5 checks, 9 feasible paths, 0 failures                           |
  | Slither 0.11.6                 | 49 contracts, 64 detectors, 0 results                            |
  | Production coverage            | 99.74% lines, 98.78% statements, 94.38% branches, 100% functions |

  An earlier strict-invariant campaign recorded 197,195,776 calls with zero handler reverts
  (`DEEP-TESTING-2026-08-13.md:27`).

- **Source.** `packages/contracts/audit/EXTREME-TESTING-2026-08-13.md:50-66`;
  `DEEP-TESTING-2026-08-13.md:20-45`.
- **Evidence.** The reports themselves; the test suite in `packages/contracts/test/`.
- **Superseded by a newer campaign.** The 2026-08-16 campaign
  (`packages/contracts/audit/CURRENT-*.md`, merged as `38dcf02`) is scoped explicitly to
  production commit `5772e54` and is the current evidence of record. It reports **0
  Critical and 0 High production defects**, one unresolved external High trust assumption
  (`RF-065`), one Medium composition limitation (`RF-074`), and a set of test-quality and
  off-chain gaps. It added six tests, raising the Foundry suite to **94 passed, 0 failed**,
  and cleared a High upstream dependency advisory.
- **Commit.** Campaign commits `b992b23` (extreme), `fe09d47` (deep), `38dcf02` (current);
  protocol commit `5772e54`.
- **Status.** Current, with the caveat that these numbers were produced at the two
  immediately-preceding commits and `RELEASE-CHECKLIST.md:69` requires re-running the full
  aggregate transcript from a clean checkout of the final release commit.
- **Caveats.** `EXTREME-TESTING-2026-08-13.md:100-102`: fuzzing, symbolic execution,
  mutation testing, and high coverage are "evidence, not a mathematical proof". SMTChecker
  was inconclusive; Mythril was never executed (`RESIDUAL-RISKS.md:53-59`). The 2026-08-16
  campaign also found and fixed four **test-quality** defects in the prior suites — most
  notably an ordinary invariant run that spent 17,263 calls on a setup-only action that
  always reverted (`CURRENT-TEST-01`). Earlier campaign call counts should therefore be
  read as upper bounds on useful exploration, not as effective coverage.

### RF-064 — Independent audit status: none

- **Claim.** No external firm has audited raffle.fun.
- **Technical.** `SECURITY.md:5-9`: "Raffle Fun v2 has completed an internal adversarial
  hardening campaign and **remains independently unaudited**."
  `RELEASE-CHECKLIST.md:105` — "Independent external audit of the exact final commit and
  locks" — is **unchecked**.
- **Source.** `SECURITY.md:5-9`; `README.md:221-226`;
  `packages/contracts/audit/RELEASE-CHECKLIST.md:105`;
  `packages/contracts/audit/INTERNAL-AUDIT.md:15-17`.
- **Evidence.** Absence of any external audit report in `packages/contracts/audit/`.
- **Commit.** `5772e54`.
- **Status.** Current.
- **Caveats.** `ETHSKILLS-REVIEW-2026-08-13.md` is a **self-administered** review against a
  published checklist, not an independent engagement. Its own scope note (line 10-11) says:
  "This is an internal remediation review, not an independent audit or a production
  authorization."

---

# 22. Known residual risks

### RF-065 — HIGH, unresolved: Entropy provider selective reveal

- **Claim.** The randomness provider can see the result before anyone else and, if it holds
  tickets in the same raffle, can choose to publish only when it wins.
- **Technical.** Pyth documents that a provider can know the final word before reveal and
  may selectively withhold it. The `Drawing` transfer lock (`RF-022`) closes the
  _post-request acquisition_ vector but does not address a provider that already owned
  tickets before the request. Withholding leads to the two-day callback timeout and a full
  refund (`RF-041`) — so the provider's downside is a refund, and its upside is a win.
- **Quantified.** The 2026-08-16 campaign models the provider's abort option. Owning a
  fraction `f` of tickets against a gross pot `G`, its advantage over always revealing is
  `f·G·(1 − f)`, **maximised at `G/4` when `f = 0.5`** (`CURRENT-FINDINGS.md`,
  `CURRENT-EXT-01`). The model quantifies the capability; it does not remediate it.
- **Named remediation options** (none implemented): provider pinning with monitoring,
  composed entropy, an alternative RNG, independent sources, or bonds/slashing.
- **Source.** `docs/RANDOMNESS.md:40-48`; `packages/contracts/audit/RESIDUAL-RISKS.md:25-31`;
  `packages/contracts/audit/CURRENT-FINDINGS.md` (`CURRENT-EXT-01`, High, unresolved);
  `ETHSKILLS-REVIEW-2026-08-13.md` finding `ES-02` ("Partly fixed ... remains unresolved").
- **Evidence.** Disposition recorded as unresolved in `ES-02`;
  `RELEASE-CHECKLIST.md:30-31` is unchecked.
- **Commit.** `5772e54`.
- **Status.** **Unresolved.** The integration currently uses Entropy's mutable default
  provider. `RELEASE-CHECKLIST.md:88` requires pinning and callback-checking a reviewed
  provider, or replacing the RNG design, before release — also unchecked.
- **Caveats.** Public documents must not claim the draw is provably fair or trustless.

### RF-066 — USDC issuer controls

- **Risk.** Circle can pause, freeze, blacklist, or upgrade USDC. A blacklisted winner,
  sponsor, or treasury cannot be paid.
- **Mitigation.** Exact-delta checks (`RF-051`) preserve the onchain claim across a failed
  transfer, so a later retry works if the freeze is lifted.
- **Source.** `RESIDUAL-RISKS.md:10-12`; `SECURITY.md:73-79`; `ETHSkills ES-07`.
- **Status.** Accepted external assumption.

### RF-067 — Base sequencer ordering, delay, and censorship

- **Risk.** The sequencer can delay a draw request past its three-day window or a callback
  past its two-day window, forcing refunds. It could censor an individual user entirely.
  A halted or reorganized chain has no application-layer escape hatch.
- **Mitigation.** Deadlines are deterministic _given inclusion_; refunds are permissionless.
  Operationally: redundant RPCs, redundant requesters, early alerts.
- **Source.** `RESIDUAL-RISKS.md:33-35`; `ETHSkills ES-08` (accepted);
  `ETHSKILLS-REVIEW-2026-08-13.md:52-58`.
- **Status.** Accepted chain trust assumption.

### RF-068 — Malicious or upgradeable prize NFT

- **Risk.** A collection can lie about ERC-165 and `ownerOf`, be paused or burned after
  escrow, or simply be worth nothing. `RF-010` and `RF-037` verify ownership through the
  same contract that could be lying.
- **Mitigation.** Delivery failure reaches full buyer refunds after 30 days (`RF-042`). No
  smart contract can create value in a fraudulent collection.
- **Source.** `RESIDUAL-RISKS.md:13-15`; `THREAT-MODEL.md:31-37`; `ETHSkills ES-03`.
- **Status.** Accepted external assumption. Prize due diligence is the buyer's.

### RF-069 — Unsafe ticket destinations

- **Risk.** A user can transfer a ticket to an arbitrary contract that cannot call
  `redeemWinningTicket`, or to an address whose key is lost. The claim is then permanently
  forfeit. Known protocol destinations are rejected (`RF-025`) but arbitrary ones cannot be,
  because capability is not inferable from bytecode without breaking ordinary ERC-721
  transferability.
- **Source.** `Raffle.sol:338-342` (explicit dev comment); `RESIDUAL-RISKS.md:17-23`;
  internal finding `I-01` (accepted informational).
- **Status.** Accepted, deliberately unsolved.

### RF-070 — Smart-contract risk and EIP-170 headroom

- **Risk.** The contracts have never been independently audited and have never run in
  production. Separately, `RaffleFactory` runtime is **24,267 bytes — only 309 bytes below
  the EIP-170 limit**, so any production change requires a fresh size gate.
- **Source.** `RESIDUAL-RISKS.md:41-43`;
  `EXTREME-TESTING-2026-08-13.md:74-84`.
- **Status.** Current. Runtime sizes at the last measured campaign: `Raffle` 16,726 B
  (7,850 B margin), `RaffleFactory` 24,267 B (309 B margin), `RaffleLens` 6,954 B
  (17,622 B margin).

### RF-074 — MEDIUM: a raffle ticket from another factory can be stranded as a prize

- **Claim.** If a sponsor uses one raffle's ticket as the prize in a _different_ factory's
  raffle, that ticket can become permanently stuck. Buyers still get their money back.
- **Technical.** `_isKnownProtocolDestination` screens only the raffle's **own** factory
  registry (`RF-025`), so a ticket minted by another factory passes every check at
  creation. If the inner raffle later enters `Drawing`, or the escrowed ticket becomes the
  inner winning ticket, the inner transfer lock (`RF-022`, `RF-023`) blocks it. The outer
  raffle can then complete neither `redeemWinningTicket` nor `claimSponsorPrize`.
- **Source.** `packages/contracts/src/Raffle.sol:483-489` (same-factory registry check only);
  `packages/contracts/audit/CURRENT-FINDINGS.md` (`CURRENT-COMP-01`, Medium).
- **Evidence.** `testCrossFactoryNestedWinnerLockPreservesBuyerRefundButCanStrandPrize` (`A`);
  `testSameFactoryNestedRaffleTicketPrizeRevertsAtomically` (`A`) — the **same-factory**
  case is correctly rejected at creation.
- **Commit.** Protocol `5772e54`; evidence `38dcf02`.
- **Status.** Accepted limitation, pending owner-facing policy.
- **Caveats.** **Quote solvency is not violated**: outer buyers still redeem full
  per-ticket refunds after the 30-day NFT-delivery timeout (`RF-042`). Only the nested
  prize is stranded. The root cause generalises — any ERC-721 that imposes transfer locks
  after escrow can do this, and no receiving factory can detect every such token. The
  campaign's suggested policy is to **document raffle-ticket prizes as unsupported**.

### RF-075 — Losing tickets survive settlement as transferable souvenirs

- **Claim.** After a raffle resolves, the losing tickets still exist in wallets and can
  still be traded — but they are worth nothing.
- **Technical.** Only the winning ticket is burned on redemption (`RF-021`). Non-winning
  tickets are never burned, remain valid ERC-721 tokens, and become transferable again
  once the raffle leaves `Drawing` (`RF-024`).
- **Source.** `packages/contracts/src/Raffle.sol:216-244`;
  `packages/contracts/audit/CURRENT-RESIDUAL-RISKS.md` ("Accepted design limitations").
- **Evidence.** `testPurchasesMintSequentialTransferableBearerTickets` (`U`).
- **Commit.** Protocol `5772e54`; evidence `38dcf02`.
- **Status.** Current, accepted.
- **Caveats.** This is a market-integrity obligation on **interfaces, not the contracts**:
  UIs and marketplaces must not imply a settled raffle's losing tickets carry continuing
  economic value. A buyer on a secondary market can otherwise be sold a worthless token
  that looks identical to a live one.

### RF-076 — The subgraph does not index ignored Entropy callbacks

- **Claim.** A rejected oracle callback is visible onchain but not in the indexer.
- **Technical.** `Raffle` emits `EntropyCallbackIgnored` for wrong-sequence, in-flight,
  stale, and duplicate callbacks (`RF-033`), but the subgraph has no handler or entity for
  it.
- **Source.** `packages/subgraph/schema.graphql`;
  `packages/contracts/audit/CURRENT-FINDINGS.md` (`CURRENT-SUBGRAPH-01`, Low).
- **Evidence.** Absence of a matching entity in the schema.
- **Commit.** Protocol `5772e54`; evidence `38dcf02`.
- **Status.** Current, open.
- **Caveats.** Monitoring must read this event from chain logs directly rather than
  relying on the indexer. It is a monitoring signal, not a lifecycle event, so no
  financial state is misrepresented.

### RF-071 — No protocol privacy

- **Risk.** Sponsor identity, every purchase, ticket ownership and transfers, the selected
  winner, claim amounts, and all timing are public. Frontends and RPCs may additionally
  observe IP and wallet metadata.
- **Source.** `ETHSKILLS-REVIEW-2026-08-13.md:74-80` (CROPS "P").
- **Status.** Current. Public materials must not imply private participation.

### RF-072 — Legal and gaming regulation

- **Risk.** Raffles, lotteries, sweepstakes, and prize promotions are regulated differently
  in every jurisdiction. No legal review has been performed.
- **Source.** `RELEASE-CHECKLIST.md:115` ("Jurisdiction-specific legal, consumer-promotion,
  sanctions, tax, and gaming review") — **unchecked**; `RESIDUAL-RISKS.md:49-51`.
- **Status.** **Outstanding release blocker.**

### RF-073 — Operational readiness gaps

- **Risk.** No signed or live deployment record, no selected owner or treasury Safe, no
  monitored Base Sepolia soak, no production dashboards or alerts, no incident-response or
  migration runbooks, and no staffed bug-bounty process.
- **Source.** `RELEASE-CHECKLIST.md:83-114` (all unchecked);
  `RESIDUAL-RISKS.md:45-51`.
- **Status.** **Outstanding release blockers.**

---

## Registry maintenance

When production Solidity changes, update the affected fact, its source line references, and
the registry commit SHA at the top of this file **before** updating any public document.
When a fact is retired, keep it with `Status: Removed` and a pointer to why — as with
`RF-057` — so that a future writer cannot reintroduce it from a historical audit report.
