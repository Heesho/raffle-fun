| File (in scope) | % Lines | % Statements | % Branches | % Functions |
|---|---|---|---|---|
| packages/contracts/src/Raffle.sol | 95.95% (237/247) | 92.47% (270/292) | 62.07% (36/58) | 100.00% (31/31) |
| packages/contracts/src/RaffleFactory.sol | 91.80% (56/61) | 93.83% (76/81) | 77.78% (14/18) | 100.00% (4/4) |

These are lower bounds. Under `--ir-minimum`, line attribution misses some revert and assembly statements that tests demonstrably execute. Examples: `Raffle.sol:188`, which `test_H2` reaches (confirmed with a `-vvvv` trace: the revert originates in `Raffle::initialize` via the clone's delegatecall), and `Raffle.sol:267`, the refund `call` exercised by C5. Remaining uncovered statements (Appendix F.5):
- Defensive re-checks in `initialize` that the factory already enforces (`Raffle.sol:185,191,194`).
- `PrizeAlreadyClaimed` in the `NftWon` redemption branch (`Raffle.sol:330`), which is unreachable because `winnerRedeemed` is checked first.
- Delivery verification against a silently failing prize (`Raffle.sol:336`) and the ERC‑165 failure paths (`RaffleFactory.sol:175,177`). Both are exercised by probes P2 and P3 in the separate probe project, which this coverage run does not include.
The stateful campaigns exercise the remaining branches; Echidna's line coverage is given in Section 4.3.
