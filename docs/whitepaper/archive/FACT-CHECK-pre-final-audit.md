# Whitepaper fact-check record

This file records the source-of-truth review performed before writing
`raffle-fun-whitepaper.pdf`. Every load-bearing claim in the whitepaper traces to a
row in this file. The deployed-code path outranks every other source. Where an older
document disagreed with the contracts, the contracts won and the discrepancy is
recorded below.

An earlier draft of this review was performed at commit `4dc7eeb9`. Mid-review, the
production-hardening commit `a2120f5` ("Harden raffle settlement and recovery
lifecycle") was merged to `main` at the author's direction, and the entire review was
redone against it. The differences are material and are listed under "Discrepancies
and revisions" below.

## Reviewed snapshot

| Item | Value |
| --- | --- |
| Git commit | `a2120f5e163dc3641d9864773febbfedca047edb` |
| Branch | `claude/raffle-fun-whitepaper-38fb93`, identical to `origin/main` at review time |
| Working tree | clean apart from the untracked `docs/whitepaper/` deliverables |
| Monorepo version | `0.1.0` (`package.json`) |
| Contracts package version | `0.1.0`; contract headers carry `@custom:version 1.0.0` |
| Solidity compiler | `0.8.36`, EVM target `cancun`, optimizer on, 1,000 runs, `via_ir = false` (`foundry.toml`, `hardhat.config.ts`) |
| OpenZeppelin | `@openzeppelin/contracts` 5.6.1 and `@openzeppelin/contracts-upgradeable` 5.6.1 |
| Pyth Entropy SDK | `@pythnetwork/entropy-sdk-solidity` 2.2.1 (`getFeeV2(uint32)` / `requestV2(uint32)` / `IEntropyConsumer`) |
| Configured chains | `packages/config/src/chains.ts` wires Base Sepolia (default), Base, and local Foundry at this commit. The whitepaper states the product's target networks as Ethereum mainnet and Base at the author's direction; see discrepancy 8. |
| Deployment status | **Undeployed.** `deployments/` contains only `schema.json`. No testnet or mainnet address is recorded anywhere in the repository. |
| Audit status | **No independent audit.** Internal testing, fuzzing, invariants, Slither, and review only (`SECURITY.md`, `README.md`). |
| Document generation date | 2026-08-09 |
| Whitepaper document version | 1.0 |

## Verification commands run at this commit

| Command | Result |
| --- | --- |
| `forge build && forge test` (Foundry, default profile) | 69 tests passed, 0 failed (unit, security, fuzz at 1,000 runs, and 9 stateful invariants at 256 runs x 64 calls) |
| `pnpm coverage` (forge coverage + gate script) | Production coverage 96.88% lines, 90.00% branches, 96.55% functions; passes the committed gate of at least 95% lines / 90% branches |
| `pnpm test:hardhat` (Node 22.23.2) | 5 tests passed: deployment-record validation x2, Ignition deployment, full create/buy/transfer/draw/claim journey, and the grace-expiry / bounded-refund / claim-for recovery journey |

All monetary worked examples in the whitepaper were recomputed with the SDK math
(`packages/sdk/src/math/economics.ts`), which mirrors the contract formulas, and
cross-checked against the Foundry worked-example tests listed below.

## Protocol constants at the reviewed commit

`packages/contracts/src/libraries/RaffleConstants.sol`:

| Constant | Value | Meaning |
| --- | --- | --- |
| `BPS` | 10,000 | basis-point denominator |
| `PROTOCOL_FEE_BPS` | 500 | 5% fee, charged only on verified-randomness resolution |
| `CASH_WINNER_BPS` | 8,000 | winner's 80% share of the post-fee pot in the cash branch |
| `MAX_TICKETS_PER_PURCHASE` | 100 | per-transaction mint bound |
| `MAX_REFUND_CREDIT_BATCH_SIZE` | 100 | per-transaction refund-credit bound |
| `MAX_START_DELAY` | 7 days | latest allowed sale start after creation |
| `MAX_SALE_DURATION` | 30 days | longest allowed sale window |
| `DRAW_REQUEST_GRACE_PERIOD` | 3 days | post-close window for the one draw request |
| `DRAW_CALLBACK_TIMEOUT` | 2 days | wait after an accepted request before timeout finalization |
| `MAX_METADATA_URI_LENGTH` | 2,048 bytes | metadata URI bound |
| `MAX_VERIFIED_QUOTE_TOKENS` (factory) | 32 | allowlist registry bound |
| `MAX_BATCH_SIZE` (lens) | 100 | lens batch-read bound |

## Claim-by-claim table

Legend: R = `packages/contracts/src/Raffle.sol`, F = `RaffleFactory.sol`,
L = `RaffleLens.sol`, I = `interfaces/IRaffle.sol`, IF = `interfaces/IRaffleFactory.sol`,
C = `libraries/RaffleConstants.sol`, U = `test/foundry/unit/Raffle.t.sol`,
S = `test/foundry/security/RaffleSecurity.t.sol`, Z = `test/foundry/fuzz/RaffleFuzz.t.sol`,
V = `test/foundry/invariant/RaffleInvariant.t.sol`.

### Lifecycle and states

| Whitepaper claim | Source | Notes |
| --- | --- | --- |
| Lifecycle states are exactly Uninitialized, AwaitingPrize, Active, DrawRequested, Resolved, Cancelled, Refunding | I `RaffleState` enum | Matches ABI |
| Terminal outcomes are exactly None, NftAwarded, CashFallback, NoSales, CancelledBeforeSale, DrawNotRequested, DrawTimedOut | I `RaffleOutcome` enum | `None` is the pre-terminal placeholder |
| A clone starts in AwaitingPrize after factory initialization | R `initialize` | |
| Initialization is restricted to the canonical factory whose stored implementation matches the clone's own bytecode-embedded implementation address | R `initialize` factory + `raffleImplementation()` check | U `testCloneInitializationRejectsUnauthorizedAndZeroAddressConfiguration` |
| The clone becomes Active only when the exact expected prize arrives from the sponsor via the factory | R `onERC721Received` | Binds state, token contract, token ID, `from == sponsor`, `operator == factory` |
| After the escrow transfer the factory additionally verifies the clone is Active and `ownerOf(prizeTokenId)` is the clone | F `_verifyPrizeEscrow` | Rejects dishonest ERC-721s; U `testFactoryCreationInitializesRegistryAndEscrowsExactPrize` |
| State transitions never move backward | V `invariantStateTransitionsNeverMoveBackward` | Also `docs/STATE-MACHINE.md` |
| Creation, registration, event, escrow, and escrow verification happen in one transaction; any failure reverts everything | F `createRaffle` | U `testPrizeTransferFailureRevertsCompleteCreationTransaction` |

### Creation inputs

| Whitepaper claim | Source | Notes |
| --- | --- | --- |
| Creation inputs are exactly: prizeToken, prizeTokenId, quoteToken, sponsorPrizeRecoveryRecipient, ticketPrice, minimumTickets, startTime, endTime, metadataURI | IF `CreateRaffleParams` | |
| A zero recovery recipient defaults to the sponsor; otherwise it is fixed forever at creation | F `createRaffle` normalization | U `testDesignatedRecoveryRecipientAndPermissionlessFixedPrizeClaim` |
| startTime of 0 means "now"; a past startTime reverts; startTime more than 7 days ahead reverts; endTime must exceed startTime; sale duration above 30 days reverts | F `createRaffle` | `StartTimeInPast`, `StartTimeTooDistant`, `InvalidEndTime`, `SaleDurationTooLong`; U `testFactoryEnforcesStartAndSaleDurationBounds` |
| Ticket price and minimum tickets must be nonzero | F `_validateCreateParams` | `ZeroTicketPrice`, `ZeroMinimumTickets` |
| Metadata URI is capped at 2,048 bytes | C, F `_validateCreateParams` | `MetadataURITooLong` |
| The payment token must be on the factory allowlist at creation time; the prize must be a deployed contract that affirmatively reports ERC-721 support via ERC-165 | F `_validateCreateParams` | `QuoteTokenNotVerified`, `UnsupportedPrizeToken`; an ERC-165 revert now rejects the prize |
| Allowlist changes affect only future creation; removal never alters an existing raffle | F, U `testQuoteTokenAllowlistGatesCreationButRemovalDoesNotAlterExistingRaffle` | |
| Clone addresses are deterministic EIP-1167 CREATE2 addresses salted by chain ID, raffle ID, sponsor, quote token, prize contract, and prize token ID | F `_raffleSalt`, `predictRaffleAddress` | |
| Ticket collection name is "Raffle Fun Ticket #N", symbol "RFT-N" | F `createRaffle` | |

### Purchases and tickets

| Whitepaper claim | Source | Notes |
| --- | --- | --- |
| Sales accepted only while Active and startTime <= now < endTime (inclusive start, exclusive end) | R `buyTickets` | U `testSaleBeforeStartRevertsAndAtStartSucceeds`, `testSaleImmediatelyBeforeEndSucceedsButAtAndAfterEndReverts` |
| 1 to 100 tickets per purchase transaction; no per-account cap | R, C | `InvalidQuantity` |
| The advertised ticket price is the total paid; cost = ticketPrice x quantity with an overflow guard | R `buyTickets` | `GrossAmountOverflow`; U `testGrossPurchaseOverflowIsRejectedBeforeTokenInteraction` |
| The contract requires its balance to grow by exactly the gross amount; fee-on-transfer and false-returning tokens revert | R balance-delta check | `UnsupportedQuoteToken`; S `testFalseReturningQuoteTokenIsRejected`, U `testFeeOnTransferQuoteTokenIsRejected` |
| Tickets are sequential ERC-721 IDs starting at 1; each purchase mints a contiguous range to the chosen recipient | R `buyTickets` | U `testPurchaseValidationAndContiguousTicketIds` |
| Every ticket has equal odds; `oddsFor` = balance x 1e18 / totalTickets | R `oddsFor` | U `testOddsUseOneEighteenPrecision` |
| Tickets transfer freely while Active; are frozen during DrawRequested; after a failed draw each ticket stays frozen until its refund is credited; resolved or credited tickets transfer as souvenirs | R `_update` override | `TicketTransfersFrozen`, `RefundTicketFrozen`; U `testUnrequestedDrawDeadlineFreezesOwnersAndConservesFullRefunds` |
| No fee is allocated during sales; the whole payment joins the unsettled pot | R, U `testPurchaseAccumulatesGrossWithoutAllocatingFeeBeforeResolution` | |
| All tickets share the raffle metadata URI | R `tokenURI` | |

### Threshold

| Whitepaper claim | Source | Notes |
| --- | --- | --- |
| The minimum is an outcome threshold, not a sales cap; sales continue to endTime after the minimum is reached | U `testThresholdDoesNotCapSalesBeforeFixedEndTime`, `testHighThresholdHasNoArbitraryCap` | |
| Threshold met at exact equality: totalTickets >= minimumTickets, checked once inside the callback | R `isThresholdMet`, `entropyCallback` | U `testExactThresholdUsesNftAwardedOutcomeAndWorkedExample`; Z `testFuzzThresholdBoundarySelectsExactBranch`; V `invariantResolutionBranchMatchesExactThresholdBoundary` |

### Draw, randomness, and deadlines

| Whitepaper claim | Source | Notes |
| --- | --- | --- |
| Anyone may request the draw after endTime, before the fixed deadline endTime + 3 days, if at least one ticket sold | R `requestDraw`, `requestGraceDeadline` | `RaffleNotEnded`, `NoTicketsSold`, `DrawRequestWindowExpired` |
| The requester attaches at least the current fee from `getFeeV2(callbackGasLimit)`; overpayment becomes a pull-based native refund | R | `InsufficientEntropyFee`; U `testExcessEntropyFeeUsesPullRefund` |
| Exactly one request can ever be made; state moves to DrawRequested and `drawRequestedAt` is stored before the external oracle call | R `requestDraw` | V `invariantAtMostOneRequestAndResolutionExist`; U `testDrawRequirementsAndDuplicateRequest` |
| An in-flight guard ignores any synchronous callback delivered before the sequence number is stored | R `_requestInFlight` | `docs/RANDOMNESS.md` |
| A reverting request leaves the raffle Active and retryable within the window | R (state change inside the reverting transaction) | |
| Callback authenticated by Pyth's `IEntropyConsumer` wrapper; only the configured Entropy contract can deliver | R `getEntropy` + SDK wrapper | |
| Stale, wrong-sequence, duplicate, and post-failure callbacks are ignored with an event | R `entropyCallback` guard | U `testWrongSequenceIgnoredAndDuplicateCallbackCannotChangeResult` |
| Winning ticket = (random mod totalTickets) + 1; inclusive range; last ticket eligible; one-ticket raffle selects ticket 1 | R | Z `testFuzzWinnerAlwaysInInclusiveTicketRange`, `testFuzzLastTicketRemainsEligible`; U `testLastTicketCanWin`, `testOneTicketRaffleAlwaysSelectsTicketOne` |
| Modulo bias is bounded by totalTickets / 2^256 and negligible; the whitepaper does not claim perfect uniformity | Arithmetic on R `entropyCallback` | |
| The callback performs storage updates only; it transfers no asset and calls no token, user, or provider contract | R `entropyCallback` | Callback-gas margin: U `testCallbackGasHasAtLeastTwentyPercentSafetyMargin` |
| The winner is the ticket owner at callback time; later transfers cannot redirect payouts | R snapshot | U `testWinningOwnerSnapshotSurvivesPostResolutionTicketTransfer` |
| If no request completes by the grace deadline, anyone may call `finalizeUnrequestedDraw` to enter Refunding (outcome DrawNotRequested) | R | `DrawRequestGraceActive` before the deadline |
| If an accepted request is unresolved 2 days after `drawRequestedAt`, anyone may call `finalizeTimedOutDraw` to enter Refunding (outcome DrawTimedOut) | R | `CallbackStillPending` before the deadline |
| After the timeout boundary, callback and timeout are both valid; the first included transaction wins and the loser is harmless | R callback guard + `finalizeTimedOutDraw` | U `testCallbackTimeoutBoundaryAndFirstTerminalTransitionWins`; `docs/STATE-MACHINE.md` |
| There is no second request, block-based fallback, admin-chosen result, or alternate oracle | R (absence), `docs/RANDOMNESS.md` | |

### Refunds (failed draws)

| Whitepaper claim | Source | Notes |
| --- | --- | --- |
| Entering Refunding moves the entire unsettled pot into `uncreditedRefundLiability`, charges no fee, selects no winner, and assigns the prize to the fixed recovery recipient | R `_enterRefunding` | V `invariantRefundingConservesGrossAndNeverCreditsProtocolFee` |
| Anyone may credit refunds in batches of 1-100 ticket IDs; each sold ticket is credited exactly one ticketPrice, once, to its current (frozen) owner | R `creditTicketRefunds` | `InvalidRefundTicket`, `TicketRefundAlreadyCredited`; Z `testFuzzFailedDrawRefundsEveryTicketExactlyOnce`; U `testRefundCreditingRejectsInvalidDuplicateAndOversizedBatches` |
| Crediting makes no external call, so one malicious recipient cannot block others | R `creditTicketRefunds` + `_creditQuote` | |
| After all tickets are credited, total refunds equal gross sales exactly | Arithmetic; `docs/ECONOMICS.md` | Refund per ticket = ticketPrice; liability starts at gross |
| Refund ownership is the ticket owner at crediting time; the per-ticket freeze means this equals the owner at failure finalization | R `_update` Refunding branch | U `testUnrequestedDrawDeadlineFreezesOwnersAndConservesFullRefunds` |

### Outcomes and money

| Whitepaper claim | Source | Notes |
| --- | --- | --- |
| BPS = 10,000; protocol fee = 500 bps (5%); cash winner share = 8,000 bps (80% of the distributable pot) | C | |
| protocolFee = floor(grossPot x 500 / 10,000), computed once on the aggregate pot at resolution, only in the two randomness-resolved branches | R `entropyCallback` with `Math.mulDiv` | U `testSettlementFeeUsesAggregateGrossInsteadOfPerPurchaseRounding` |
| Threshold met: winner claims the NFT; sponsor is credited the full 95% distributable pot | R threshold branch | |
| Threshold missed: recovery recipient reclaims the NFT; winner credited floor(distributable x 80%); sponsor credited the remainder including rounding dust | R fallback branch | U `testThresholdMissedWorkedExampleAllocatesExactEightyTwentyDistributableSplit`; Z `testFuzzCashFallbackRoundingAssignsRemainderToSponsor` |
| fee + winnerCash + sponsorCash = grossPot in both resolved branches | R arithmetic | V `invariantAccountedQuoteAlwaysReconcilesAndIsSolvent`, `invariantQuotePaidInEqualsPaidOutPlusContractBalance` |
| Worked example: 120 tickets at 10 USDC, minimum 100 -> pot 1,200; fee 60; sponsor 1,140; winner NFT | SDK `calculateResolutionAmounts(1_200_000_000n, true)` | Same split as `docs/ECONOMICS.md` vectors |
| Worked example: 80 tickets at 10 USDC, minimum 100 -> pot 800; fee 40; winner 608; sponsor NFT-recipient recovery + 152 | SDK `calculateResolutionAmounts(800_000_000n, false)` | Matches the 80/100 vector scaled by 10 |
| No sales: anyone may close after endTime; recovery recipient reclaims prize; no fee, no quote claims | R `closeNoSales` | U `testAnyoneCanCloseNoSalesAfterEnd` |
| Sponsor may cancel only while zero tickets sold; first sale permanently removes that power | R `cancelBeforeSales` | U `testSponsorCannotCancelAfterOneSale` |
| All payouts are pull claims; the callback and refund credits record balances, claimants withdraw later | R `_creditQuote`, claim functions | U `testQuoteClaimsArePullBasedAndSingleUse` |
| `claimQuote(to)` pays the caller's accrual to any nonzero destination except the raffle itself; `claimQuoteFor(account)` may be triggered by anyone but pays only to that account | R | `InvalidQuoteDestination` |
| Outbound claims verify both the raffle's exact debit and the recipient's exact credit; non-exact tokens revert and the claim is preserved | R `_claimQuote` | `UnsupportedQuoteTokenTransfer`; U `testOutboundRecipientFeeAndSenderTaxPreserveQuoteLiability`; mock `AdversarialOutboundERC20` |
| Prize claims work in Resolved, Cancelled, and Refunding; single-use; retryable on failure; `claimPrizeFor()` lets anyone deliver the prize to the recorded claimant only | R `claimPrize`, `claimPrizeFor`, `_claimPrize` | U `testPrizeDestinationFailureDoesNotConsumeRecoveryClaim`, `testDesignatedRecoveryRecipientAndPermissionlessFixedPrizeClaim` |
| Direct token donations are observable unaccounted surplus; forced native currency is surplus; direct native transfers revert | R `unaccountedQuoteSurplus`, `unaccountedNativeSurplus`, `receive()` | U `testDirectQuoteDonationIsSurplusNotImplicitSettlement`, `testForcedNativeCurrencyCannotChangeStateOrCreateRefund` |
| Solvency invariant: token balance >= unsettledPot + uncreditedRefundLiability + totalClaimableQuote | R `accountedQuoteBalance`, `isQuoteSolvent` | V solvency invariants |

### Architecture and administration

| Whitepaper claim | Source | Notes |
| --- | --- | --- |
| The implementation is locked with `_disableInitializers`; clones cannot be upgraded and have no admin, pause, or rescue function | R constructor; U `testImplementationIsLocked` | |
| Factory owner can: change treasury for future raffles, admit or remove up to 32 quote tokens for future creation, pause new creation, transfer ownership in two steps | F owner functions | U `testFactoryAdminAndCreationValidationBranches` |
| Factory owner cannot: alter any existing raffle's token, recovery recipient, economics, deadlines, winner, claims, or code; pause settlement; seize assets | Absence of any such function on R | `docs/THREAT-MODEL.md` |
| Token admission is a hard creation gate at this commit (not merely a discovery label) | F `_validateCreateParams` `QuoteTokenNotVerified` | This reverses the pre-hardening design; see discrepancy 6 |
| Treasury and recovery recipient are captured per-raffle at creation; later factory changes affect only future raffles | R `initialize`, F | |
| The lens is stateless, read-only, registry-gated, batch-bounded at 100, and surfaces deadlines, liabilities, and per-account actions including `entropyFeeAvailable` | L | U lens tests |
| Reentrancy defenses: `ReentrancyGuard` on state-changing paths, checks-effects-interactions, storage-only callback | R | S reentrancy suite |
| The subgraph and frontend are conveniences; the chain is authoritative; the web app rereads onchain state and simulates before every write | `docs/ARCHITECTURE.md`, `docs/WEBAPP.md` | Frontend behavior, not protocol enforcement |

### Testing and review

| Whitepaper claim | Source | Notes |
| --- | --- | --- |
| 69 Foundry tests and 5 Hardhat tests pass at the reviewed commit | Reproduced in this review | |
| Production coverage 96.88% lines, 90.00% branches, 96.55% functions; committed gate at least 95% lines / 90% branches | Reproduced via `pnpm coverage` | Coverage is not a security proof; whitepaper says so |
| Fuzzing at 1,000 runs locally / 10,000 in CI; invariants 256x64 locally / 1,000x256 in CI | `foundry.toml` | |
| Slither and Solhint configured; gas snapshot committed; callback-gas margin asserted at 20% under the 300,000 limit | configs, `.gas-snapshot`, U | |
| Adversarial mocks include false-returning, fee-on-transfer, reentrant, and adversarial-outbound ERC-20s, reentrant ERC-721/receiver, and a mock Entropy | `src/mocks/` | `ForceNative` mock was removed in the hardening commit |
| No independent audit exists | `SECURITY.md` | |

## Discrepancies and revisions found

| # | Discrepancy | Resolution | Affects whitepaper? |
| --- | --- | --- | --- |
| 1 | The first review pass was performed at `4dc7eeb9`, which had no refund or timeout paths, a discovery-only verification label, tolerant ERC-165 handling, no recovery recipient, unbounded sale scheduling, and Solidity 0.8.28 | The hardening commit `a2120f5` was merged to `main` mid-task at the author's direction; the whitepaper and this record describe `a2120f5` only | Yes; the entire document was aligned to the new code |
| 2 | `docs/WEBAPP.md` (pre-hardening) said body text uses Nunito; `globals.css` uses Inter body / Nunito display | Code wins: Inter body, Nunito display; the whitepaper design follows the code | No (design only) |
| 3 | `docs/WEBAPP.md` lists indigo `#1b2a9b`; `globals.css` defines `--brand-navy: #1e2a9b` | Code wins: `#1e2a9b` | No (design only) |
| 4 | Older README text ("no refund branch", "any contract-backed ERC20", "verification controls discovery, not creation") described the pre-hardening design and survives in some prose found in git history | Current README and code agree; whitepaper follows the current code | Yes; refund chapters and admin chapters rewritten |
| 5 | Coverage was 100/100/100 at `4dc7eeb9`; at `a2120f5` it is 96.88 / 90.00 / 96.55 | Whitepaper reports the reproduced numbers at the reviewed commit and the committed gate | Yes; testing chapter uses the new numbers |
| 6 | Pre-hardening, quote-token verification was an advisory discovery label; post-hardening it gates creation | Whitepaper describes admission as a creation gate and notes that delisting never affects existing raffles | Yes; admin-powers and trust chapters |
| 7 | Brand assets carry the wordmark "raffles" while the protocol is "raffle.fun" / "Raffle Fun" | Repository naming used for the document; logo art used unmodified | No |
| 8 | The author directed that the whitepaper present the target networks as Ethereum mainnet and Base, and that the "Plain-English" phrasing be dropped from the title and branding | The document says "targets Ethereum and Base"; the repository configuration at this commit wires Base Sepolia, Base, and local Foundry only, and the deployment tooling targets Base Sepolia. Deployment status remains "undeployed", so no network claim is a deployment claim | Yes: cover, colophon, and network prose |

## Statements intentionally omitted from the whitepaper

- Any deployed contract address, deployment date, or network claim beyond "undeployed
  at the reviewed commit" (no deployment record exists).
- Any user, volume, or traction metric (none exists).
- Any partner, integrator, or audit-firm name (none exists).
- Any roadmap commitment or future-version promise (none is recorded in the
  repository as a commitment).
- Any claim of legal or regulatory compliance in any jurisdiction.
- Any claim that the system is "trustless", "guaranteed" without stated conditions,
  "bulletproof", or that randomness is perfectly unbiased.

## Unresolved items requiring human review

| Item | Owner | Notes |
| --- | --- | --- |
| Jurisdiction-by-jurisdiction legal review of chance-based prize distribution | Legal | The whitepaper carries a disclosure, not an opinion |
| Independent security audit before any mainnet deployment | Security | Required by `docs/DEPLOYMENT.md` gates |
| Final selection of Base mainnet Entropy address, initial verified quote tokens, treasury Safe, and owner Safe | Operations | Deployment-time inputs; none recorded in-repo |
| Callback gas limit re-validation against production bytecode (default 300,000) | Engineering | Required by `docs/RANDOMNESS.md` and `docs/DEPLOYMENT.md` |
| Confirmation of the publication branding ("raffle.fun" vs "raffles" wordmark) | Product | Whitepaper uses repository naming |
