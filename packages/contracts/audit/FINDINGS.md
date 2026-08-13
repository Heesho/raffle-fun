# Findings

> Historical baseline: entries referring to transferable `Drawing` tickets or
> `recoverProtocolOwnedClaim` describe pre-remediation code. See
> [`ETHSKILLS-REVIEW-2026-08-13.md`](ETHSKILLS-REVIEW-2026-08-13.md).

Review date: 2026-08-09. Affected identity is `a2120f5e163dc3641d9864773febbfedca047edb`
plus the pre-audit simplified-settlement patch fingerprint
`55589ce1fce0bd5579e60df747796575df9b0d96`. The findings therefore do not describe
the untouched `main` tree alone.

## Summary

| ID   | Severity      | Title                                                                      | Status         |
| ---- | ------------- | -------------------------------------------------------------------------- | -------------- |
| H-01 | High          | Unsafe transfer can assign a winning/refund credential to its own raffle   | fixed          |
| H-02 | High          | Predicted new raffle can be configured as its own NFT recovery recipient   | fixed          |
| H-03 | High          | Future code-less raffle address bypasses registered-destination protection | fixed          |
| H-04 | High          | Later raffle address can own fixed prize and fee claims it cannot initiate | fixed          |
| M-01 | Medium        | Predicted new raffle can be configured as its own protocol treasury        | fixed          |
| L-01 | Low           | Clean-checkout CI jobs omit required tool/dependency setup                 | fixed          |
| L-02 | Low           | Deployment record writer validates syntax but not live bindings            | fixed          |
| I-01 | Informational | Arbitrary non-callable user destinations can hold bearer credentials       | accepted scope |

No Critical finding remains. No unresolved High or Medium finding remains.

## H-01 — unsafe self-transfer locks a bearer credential

- Severity/confidence: High / high.
- Files/functions: `src/Raffle.sol`, ERC-721 `transferFrom`, winning and refund redemptions.
- Violated invariant: a protocol-controlled destination must not become a bearer claimant with no initiating selector.
- Preconditions/attacker: any ticket owner or approved operator; unsafe `transferFrom` to the ticket's raffle.
- Minimal sequence: buy ticket 1; transfer ticket 1 to the raffle; resolve ticket 1 or enable refunds; observe that only the raffle owns the burn credential and cannot originate the redemption.
- Impact: permanent supported-prize lock in `NftWon`, or quote/refund lock in `CashWon`/`Refunding`; randomness is not manipulated, but its selected credential is unusable.
- PoC/regression: `testRegressionUnsafeTransferCannotAssignWinningCredentialToRaffle` and `testRegressionTicketsRejectKnownProtocolDestinations`.
- Remediation: override `transferFrom` and reject this raffle, factory, quote token, Entropy, prize token, and registered sibling raffles. OpenZeppelin safe transfers traverse the override.
- Final status: fixed; fuzz, invariant, mutation, symbolic, and static campaigns passed the remediated path.

## H-02 — self-referential recovery recipient locks the prize

- Severity/confidence: High / high.
- Files/functions: `Raffle` constructor, `RaffleFactory.createRaffle`, `claimSponsorPrize`.
- Violated invariant: cash, refund, and empty outcomes must expose the prize to a callable fixed recovery account.
- Preconditions/attacker: sponsor computes the next ordinary `CREATE` address and supplies it as `sponsorPrizeRecoveryRecipient`.
- Minimal sequence: compute the next factory-created address; create with that address as recovery recipient; reach `CashWon`, `Refunding`, or `Closed`; only the raffle itself is authorized and it cannot originate `claimSponsorPrize`.
- Impact: permanent supported-prize lock; no quote or randomness manipulation required.
- PoC/regression: `testRegressionPredictedRaffleCannotBeItsOwnRecoveryRecipient`.
- Remediation: constructor-time validation compares fixed claimants to `address(this)`, the factory, dependencies, prize, and registered siblings.
- Final status: fixed.

## H-03 — future raffle address bypasses the registered-target check

- Severity/confidence: High / high.
- Files/functions: `Raffle.transferFrom`, `recoverProtocolOwnedClaim`.
- Violated invariant: deterministically predictable protocol destinations must retain a bounded permissionless recovery path.
- Preconditions/attacker: a holder sends a ticket to the factory's next code-less `CREATE` address before that raffle is deployed; the future raffle later registers.
- Minimal sequence: predict future raffle B; transfer raffle A's ticket to B while `B.code.length == 0`; create B; settle A; B owns A's bearer right but originally had no redemption selector.
- Impact: supported NFT, winner cash, or refund would be permanently locked at a newly canonical protocol address.
- PoC/regression: `testRegressionFutureRaffleCanRecoverTicketsTransferredBeforeItsDeployment`, covering NFT, cash, and refund credentials.
- Remediation: every raffle exposes a bounded permissionless claim-kind helper that may act only against a registered raffle and routes all recovered assets only to the holder raffle's immutable recovery recipient. Winning and refund kinds use the target's existing bearer rules and 100-entry refund bound.
- Final status: fixed. The helper is selective, not a generic rescue or arbitrary-call mechanism.

## H-04 — later raffle address locks fixed prize and fee claims

- Severity/confidence: High / high because the prize branch permanently locks a supported ERC-721; the fee aspect alone is Medium.
- Files/functions: `RaffleFactory.setProtocolTreasury`, `Raffle.claimSponsorPrize`, `Raffle.claimQuote`, `recoverProtocolOwnedClaim`.
- Violated invariant: a deterministically predictable future protocol address must retain bounded progress for every fixed claim, not only bearer tickets.
- Preconditions/attacker: a sponsor or factory owner computes a later factory `CREATE` address while it is code-less and selects it as an earlier raffle's recovery recipient or treasury; the predicted raffle is subsequently created.
- Minimal sequence: predict raffle C; create raffle A with C as recovery recipient; set C as treasury and create raffle B; create C; close A and resolve B. C then owns A's prize right and B's 5% fee claim but originally had no selector capable of calling either target.
- Impact: permanent supported-prize lock in A and permanent protocol-fee liability lock in B. Winner selection and refunds are unaffected.
- PoC/regression: `testRegressionFutureRaffleCanRecoverFixedClaims`; the pre-fix trace reverted on the absent recovery selector.
- Remediation: extend the registered-target helper with an explicit `ProtocolOwnedClaim` kind for winning tickets, refund tickets, quote claims, and sponsor-prize claims. Every branch calls only its fixed target selector and pays only the holder raffle's immutable recovery recipient.
- Final status: fixed; the helper remains permissionless, bounded, and non-generic.

## M-01 — self-referential treasury locks the protocol fee

- Severity/confidence: Medium / high.
- Files/functions: `Raffle` constructor, `RaffleFactory` constructor and `setProtocolTreasury`, `claimQuoteFor`.
- Violated invariant: a successful branch's accounted treasury liability must remain claimable.
- Preconditions/attacker: factory owner configures the next raffle address as future treasury.
- Minimal sequence: predict the next `CREATE`; set treasury to it; create and resolve the raffle; fee is credited to the raffle; `claimQuoteFor(raffle)` attempts a forbidden quote self-payment and the raffle cannot call `claimQuote`.
- Impact: permanent lock of the 5% protocol-fee liability; prize/refunds/randomness are unaffected.
- PoC/regression: `testRegressionPredictedRaffleCannotBeItsOwnTreasury` and `testRegressionFactoryRejectsKnownProtocolFixedClaimants`.
- Remediation: factory and raffle constructor reject known protocol fixed claimants, including the actual constructor address.
- Final status: fixed.

## L-01 — clean-checkout CI is not reproducible

- Severity/confidence: Low / high.
- Files/functions: `.github/workflows/contracts.yml`, `typescript.yml`, `web.yml`, `.gitleaksignore`.
- Violated invariant: release gates must execute in a clean environment.
- Preconditions: GitHub-hosted job without pre-existing workspace artifacts.
- Sequence/impact: Foundry lacked pnpm-installed imports; Slither lacked Forge; root/web typechecking lacked generated or built workspace outputs; Gitleaks treated historical sandbox ERC-721 addresses as generic secrets. This can hide regressions by keeping required jobs red.
- Regression/evidence: clean dependency install, generated subgraph code, package build ordering, Foundry setup, pinned Slither, and exact line-fingerprint Gitleaks exceptions.
- Final status: fixed locally; remote workflow execution remains required after an authorized push.

## L-02 — deployment records do not prove live configuration

- Severity/confidence: Low / high.
- Files/functions: `scripts/deployment-validation.ts`, `write-deployment.ts`, deployment schema/tests.
- Violated invariant: a record enabling writes must match the intended chain and live immutable bindings.
- Preconditions: operator supplies stale, guessed, or wrong-network addresses with syntactically valid JSON.
- Impact: frontend/indexer could target the wrong factory, token, Entropy, owner, treasury, or Lens. No public record currently exists.
- Regression/evidence: two Hardhat deployment-record tests, three deployment/lifecycle
  integration tests, and the live validator.
- Remediation: validate RPC chain and head, block, runtime code, official chain-specific USDC/Entropy, factory immutables, treasury, owner/pending owner, Lens binding, and mainnet contract-wallet/verification requirements.
- Final status: fixed in tooling; an actual mainnet candidate cannot pass until verified deployment evidence exists.

## I-01 — arbitrary user-selected non-callable destinations

- Severity/confidence: Informational / high; accepted product boundary.
- Scope: a bearer may deliberately use unsafe ERC-721 transfer to any arbitrary contract that cannot initiate a call, including a separately deployed read-only Lens not stored as a factory dependency.
- Impact: that user's winning or refund credential may be unrecoverable.
- Classification: user-selected destination risk explicitly excluded from the supported recovery property; bytecode cannot reliably prove future call capability. The remediation rejects every destination the raffle can identify as its own protocol graph and supplies recovery for future canonical raffles without pretending to solve arbitrary contracts or lost keys.
- Owner decision: retain transferable ERC-721 semantics and no generic rescue. Frontend warnings and safe-transfer defaults are recommended.
