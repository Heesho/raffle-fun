# ETHSkills security review — 2026-08-13

## Scope and status

This focused review followed the ETHSkills ship, security, testing, audit, CROPS,
wallet, L2, standards, building-block, and address guidance plus the relevant EVM
audit checklists. It covered production contracts, deployment validation, generated
ABIs, SDK actions, the live UI/sandbox contract model, and release documentation.

No contract was deployed and no onchain write was performed. This is an internal
remediation review, not an independent audit or a production authorization.

## Findings and disposition

| ID    | Severity | Finding                                                                                                                                                | Disposition                                                                                                                                                                                                         |
| ----- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ES-01 | High     | A predicted permissionless `CREATE` raffle address could be captured, then use `recoverProtocolOwnedClaim` to steal claims assigned before deployment. | Fixed: the enum, contract dispatcher, SDK action, and ABI entry were removed. Future code-less destinations are explicitly unsupported.                                                                             |
| ES-02 | High     | Pyth's provider can know the word before reveal; transferable tickets in `Drawing` allowed winner acquisition during that gap.                         | Partly fixed: all transfers lock in `Drawing`, and the selected winner remains locked. Selective reveal by a provider that already owns tickets remains unresolved.                                                 |
| ES-03 | High     | A paused, burned, or otherwise unavailable prize could leave buyers without the NFT while sponsor USDC proceeds remained claimable.                    | Fixed for transfer failure: NFT-branch gross proceeds remain escrowed until verified delivery; after 30 days, full ticket refunds become permissionless. A fully malicious NFT can still lie about ownership/value. |
| ES-04 | High     | Renouncing factory ownership while creation was paused could permanently brick future creation.                                                        | Fixed: `renounceOwnership` always reverts with `OwnershipRenunciationDisabled`.                                                                                                                                     |
| ES-05 | Medium   | Quote payouts could be directed to a sibling raffle or other known protocol sink and become unrecoverable donations.                                   | Fixed: every quote payout rejects known protocol destinations before consuming the ticket or liability.                                                                                                             |
| ES-06 | Medium   | Mainnet deployment records accepted an uncompleted two-step ownership handoff.                                                                         | Fixed: validation requires final owner acceptance and zero pending owner before record publication.                                                                                                                 |
| ES-07 | Medium   | Deployment validation accepted paused or wrong-decimal USDC and allowed an EOA mainnet treasury.                                                       | Fixed: validation requires six decimals, unpaused token state, and contract-wallet owner/treasury on Base mainnet. Issuer upgrade/blacklist risk remains.                                                           |
| ES-08 | Medium   | Base sequencer censorship can force request/callback timeout refunds.                                                                                  | Accepted chain trust assumption; redundant requesters, early alerts, and monitoring remain required.                                                                                                                |
| ES-09 | Low      | Native excess refunds copied unbounded requester returndata.                                                                                           | Fixed with a zero-returndata-copy assembly call and a return-data-bomb regression.                                                                                                                                  |
| ES-10 | Low      | Direct modulo mapping has negligible mathematical bias.                                                                                                | Accepted and disclosed; for realistic ticket counts the advantage is cryptographically negligible.                                                                                                                  |
| ES-11 | Low      | The 5% fee uses floor rounding, leaving sub-unit remainder with the sponsor.                                                                           | Accepted economics; documentation and fuzz accounting already specify exact floor behavior and conservation.                                                                                                        |

## Verification completed in this worktree

- Solidity 0.8.36 exact-pragmas build succeeded under Hardhat and Foundry.
- Foundry: 73 passed, zero failed, one RPC-dependent fork test skipped.
- Stateful invariant suites exercised the NFT delivery-timeout transition, including a
  strict zero-revert campaign in the normal test profile.
- Hardhat: 9 passed, including new deployment-validation tests.
- SDK ABI/subgraph ABI synchronization completed; SDK tests and type checking passed.
- Full monorepo build, lint, type checking, and tests passed.
- Production coverage passed at 99.48% lines, 91.01% branches, and 100% functions.
- Slither analyzed 49 contracts with 64 detectors and reported zero results.
- The updated gas snapshot passed, and production bytecode remained below EIP-170;
  `RaffleFactory` has 309 bytes of runtime headroom.
- Focused regressions cover the removed recovery selector, draw/winner transfer locks,
  broken-prize refunds, protocol payout sinks, ownership renunciation, completed Safe
  handoff validation, USDC state checks, and oversized native refund returndata.

These local results do not satisfy the full release checklist. The RPC-dependent Base
fork test was skipped because no fork URL was configured. The same gates must still be
rerun from a clean checkout of the final commit, followed by independent review.

## CROPS review

### C — Censorship resistance

Existing raffles have no administrator and expose permissionless draw requests,
deadline finalization, refunds, and fixed-account quote claims. However Base sequencer
censorship can delay requests or callbacks, Circle can freeze USDC, and the Entropy
provider can selectively withhold a result. Users can bypass the first-party frontend
and call verified contracts directly, but those chain/token/oracle dependencies remain.

### R — Resilience

Raffles are constructor-deployed and non-upgradeable. Failed randomness reaches full
refunds, and failed NFT delivery now reaches full refunds after 30 days. Existing
raffles survive factory pause or owner loss, but a halted Base chain or frozen USDC has
no application-layer escape hatch. Operational resilience requires redundant RPCs,
requesters, alerts, a reviewed Safe, and a new-factory migration runbook.

### O — Openness

Source, exact compiler/dependency locks, deployment scripts, generated ABIs, and test
campaigns are public in the repository. A production release still requires verified
source, bytecode/source matching, and a signed deployment record; no such live record
exists in this review.

### P — Privacy

There is no protocol privacy. Sponsor identity, purchases, ticket ownership and
transfers, selected winner, claim amounts, and timing are public. Frontends/RPCs may
also observe IP and wallet metadata. The UI and documentation must not imply private
participation.

### S — Security

The design minimizes raffle administration, bounds loops and custody deadlines, uses
pull claims, checks exact ERC-20 balance deltas, locks ownership across the oracle
reveal gap, and preserves refund solvency when prize delivery fails. Remaining
high-impact dependencies are the Entropy selective-reveal model, Circle controls, Base
sequencer/liveness, malicious NFT semantics, Safe operations, and immutable-contract
incident response.

## Required before any onchain release

1. Independently review the exact remediation commit and the Entropy provider/RNG
   architecture. Pinning and checking a provider prevents substitution but does not
   solve selective reveal.
2. Run every release-checklist gate from a clean checkout, including coverage, gas,
   Slither/static analysis, full monorepo tests, and configured Base forks.
3. Complete a monitored Base Sepolia soak for draw lock, cash/NFT settlement, all three
   refund deadlines, broken-prize delivery, payout-destination rejection, and Safe
   ownership acceptance.
4. Reverify official Circle USDC and Pyth addresses/state on release day; require a
   reviewed owner Safe and treasury Safe.
5. Update/regenerate the long-form whitepaper and diagrams. The currently published
   whitepaper predates these state-machine and recovery-selector changes and is a
   release blocker until regenerated and visually reviewed.

## Primary external references

- [ETHSkills](https://ethskills.com/SKILL.md)
- [Pyth Entropy protocol design](https://docs.pyth.network/entropy/protocol-design)
- [Pyth Entropy transformation guidance](https://docs.pyth.network/entropy/transform-entropy-results)
- [Pyth Entropy chain list](https://docs.pyth.network/entropy/chainlist)
- [Circle USDC contract addresses](https://developers.circle.com/stablecoins/usdc-contract-addresses)
- [Solidity compiler bugs by version](https://docs.soliditylang.org/en/latest/bugs.html)
