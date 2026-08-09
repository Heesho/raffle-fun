# Static analysis

Review date/reviewer: 2026-08-09, internal Codex adversarial review. Production scope
was `Raffle.sol`, `RaffleFactory.sol`, `RaffleLens.sol`, first-party interfaces, and
constants; dependency and test findings were reviewed separately.

## Tools and results

| Tool          | Version / pinned source                            | Result                                                                                                       |
| ------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Slither       | 0.11.6                                             | 49 contracts, 64 detectors, 0 final findings                                                                 |
| Aderyn        | 0.6.8, upstream SHA256-verified macOS arm64 binary | 88 detectors; 3 high-pattern and 6 low-pattern groups manually reviewed                                      |
| Semgrep       | 1.170.0                                            | 50 community Solidity rules at rules commit `40b8c63f75dc7c22c8a77482d73bfb864b146f7e`; 17 findings reviewed |
| Solhint       | 6.2.3                                              | 0 errors; style/gas warnings accepted                                                                        |
| Solidity      | 0.8.36                                             | canonical and Hardhat production builds emitted no production compiler error                                 |
| Gitleaks      | 8.30.1                                             | full history and final source-only worktree scans passed after exact public-address fingerprints             |
| pnpm audit    | pnpm 11.18.0                                       | no high/moderate/critical advisory; one low dev-only advisory                                                |
| bytecode size | Forge 1.2.3                                        | all contracts under EIP-170/EIP-3860; factory margin 265 B                                                   |

Required Slither printers were executed and manually inspected: `human-summary`,
`contract-summary`, `function-summary`, `vars-and-auth`, `entry-points`, `call-graph`,
and `inheritance-graph`. Generated graph files were kept outside the repository.

## Aderyn accepted results

| Detector and source                                                                  | Impact/exploitability assessment                                                                                                           | Compensating evidence / re-review trigger                                     |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| `arbitrary-transfer-from`, `Raffle.sol:341`                                          | False positive: this is ERC-721 `super.transferFrom`; OpenZeppelin checks owner/operator approval.                                         | ERC-721 unit/regression tests; re-review on OZ or override change.            |
| `eth-send-unchecked-address`, `Raffle.sol:155-183`                                   | Intended excess return only to `msg.sender`; failure reverts the full request and guard blocks reentry.                                    | rejected-refund rollback test; re-review on native accounting change.         |
| `reentrancy-state-change`, `Raffle.sol:120-132,169-172`                              | Calls are under `nonReentrant`; request sets `Drawing` and in-flight before Entropy. Ticket transfer is intentionally bearer-transferable. | hostile ERC-20/receiver/Entropy tests; re-review on guard or callback change. |
| `centralization-risk`, `RaffleFactory.sol:24,128,141`                                | Accepted future-policy owner; cannot mutate existing raffle.                                                                               | ownership/admin tests and threat model.                                       |
| `costly-loop` / `require-revert-in-loop`, `Raffle.sol:132,243`, `RaffleLens.sol:123` | Deliberately atomic and bounded to 100/100/64. Forgiving partial burns would complicate accounting.                                        | maximum gas tests; re-review if bounds increase.                              |
| `unchecked-return`, `Raffle.sol:329`                                                 | `_requireOwned` is called only for its revert side effect in `tokenURI`, matching OZ semantics.                                            | nonexistent-token unit test.                                                  |
| `uninitialized-local-variable`, `Raffle.sol:132,243`                                 | Solidity initializes loop counters to zero; idiomatic and safe.                                                                            | compiler semantics; re-review on compiler change.                             |
| `large-numeric-literal`, `RaffleConstants.sol:14`                                    | Style only.                                                                                                                                | exact arithmetic fuzz tests.                                                  |

## Semgrep accepted results

Sixteen findings were performance/style patterns: nonpayable constructors, state
`+=`, checked bounded loop increments, and nested-if suggestions in `Raffle.sol`,
`RaffleFactory.sol`, and `RaffleLens.sol`. Changing these for marginal gas would reduce
clarity or alter rejection behavior; measured bounded operations are far below Base's
limit. The sole security pattern, `arbitrary-send-erc20` at `Raffle.sol:341`,
misclassified OpenZeppelin ERC-721 `super.transferFrom` as ERC-20 and is the same false
positive reviewed above. Re-review trigger: transfer override, loop bound, compiler,
or OpenZeppelin change.

## Solhint accepted warnings

Production warnings are naming/order/function-length, strict-inequality gas hints,
event indexing, and struct-packing suggestions. Test warnings additionally cover
intentional low-level calls, Halmos/Echidna naming conventions, and harness style.
None changes authorization, custody, solvency, or liveness. No detector class is
globally suppressed.

## Unavailable or inconclusive tools

- Mythril 0.24.8 supports Python 3.7-3.10; the isolated runtime is Python 3.12. It was
  not executed and remains a nonblocking supplemental gap because Slither, Aderyn,
  Semgrep, independent fuzzers, mutation, and Halmos completed.
- SMTChecker compiled but reported extensive unsupported dependency features; see
  `SYMBOLIC-CHECKS.md`.
- Certora is not configured.

## Commands

```text
slither . --exclude-dependencies --fail-medium
slither . --exclude-dependencies --print <required printers>
aderyn . -i <production files> -o /tmp/raffle-aderyn-report.json
semgrep scan --config /tmp/semgrep-rules/solidity --metrics off <production files>
pnpm exec solhint 'src/**/*.sol' 'test/**/*.sol'
gitleaks git --redact --no-banner .
forge build --sizes
pnpm audit --audit-level high
```
