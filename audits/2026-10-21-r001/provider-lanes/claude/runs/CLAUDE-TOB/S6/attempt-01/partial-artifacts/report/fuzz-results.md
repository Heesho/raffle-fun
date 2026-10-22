| Campaign | Configuration | Calls / runs | Result |
|---|---|---|---|
| Echidna canaries, profile A | 11 reachability canaries (expected to fail) | 38,535 calls | **11/11 falsified** (every deep state reached) |
| Foundry invariant (pre-final wiring) | `invariant_globalProperties`, 2,000 × 150 | 2,000 runs, 300,000 calls | **PASS** |
| Foundry invariant (pre-final wiring) | `invariant_noSpecViolation`, 2,000 × 150 | 2,000 runs, 300,000 calls | **PASS** |
| Foundry canaries | 14 reachability canaries (expected to fail), 256 runs × 120 | — | **14/14 falsified** |

**Total stateful calls under the two properties and the two Foundry invariants: 600,000. No specification violation and no invariant failure was found.** The canaries show the campaigns reach every terminal branch: NFT and cash resolution, NFT and cash redemption, refunds after both timeouts, ignored late callbacks, sponsor early cancel, prize return, fee and sponsor releases, and three concurrent raffles.

Echidna line coverage of the in-scope sources (union of profiles A and B; uncovered lines are listed in Appendix E.8):

- (no coverage files)
