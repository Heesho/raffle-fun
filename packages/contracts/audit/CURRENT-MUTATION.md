# Current v1 mutation campaign

This campaign targets the active Ethereum v1 sequential range-ticket candidate. It is a
focused, hand-selected security mutation set, not an exhaustive search and not an
independent audit.

> **Superseded evidence:** this campaign is preserved for the exact source identity
> below. It predates the timeout remediation, official Chainlink consumer-base
> migration, and bearer-redemption redesign. Its score does not validate the current
> working source; regenerate the catalog and results from the final release SHA.

## Candidate identity and isolation

- source commit at campaign start: `92eccb4beda71175dfeab4fa2282fbcfaab075c4`
- candidate source SHA-256: `54c42b664eb7b74c5a352b70a64a6553b6ba496b40e880c4869c1c8df9178d9a`
- candidate source files: 16 Solidity files under `packages/contracts/src`
- Foundry oracle SHA-256: `f84324f7d98ddbd83cac39433edefb5a368f5ad36606b5c97f527a2f8a430dd7`
- Foundry oracle files: 8 Solidity files under `packages/contracts/test`

The runner copies the active source and test trees into an isolated disposable Git
worktree, proves the baseline, applies one exact source mutation at a time, and restores
each file. Missing or ambiguous snippets are invalid definitions; compiler failures are
reported separately and never counted as kills.

```sh
python3 -B scripts/current_mutation.py
python3 -B scripts/current_mutation.py \
  --output audit/current-mutation-survivor-rerun.json --ids M-24 M-28
```

Every candidate and mutant uses:

```sh
forge test -q --no-match-contract EthereumForkTest
```

## Coverage of the declared set

The 52 mutations exercise:

- sequential ticket IDs, separately stored inclusive ranges, adjacency, and overflow;
- sale boundaries, indefinite post-sale draw availability, accepted-callback timeout,
  final-result refund exclusion, and empty-raffle closure;
- Chainlink wrapper authentication, in-flight/lifecycle/request/word guards, winner
  selection, 30 confirmations, and reserve equality;
- the NFT 95/5 and cash 80/15/5 economics, settlement-time allocation, pot consumption,
  winning-range proof, ticket burn, and recorded winner ID;
- fixed winner, sponsor, and protocol destinations, permissionless releases, and prize
  ownership postconditions;
- inclusive weighted refunds, owner authorization, batch bounds, liability decrement,
  and ticket consumption;
- factory pause, quote/prize validation, atomic escrow, clone initialization, maximum
  sale duration, registry sink checks, and implementation locking.

## Results

| Metric              | Result |
| ------------------- | -----: |
| defined             |     52 |
| compiled and killed |     52 |
| survived            |      0 |
| compile errors      |      0 |
| invalid definitions |      0 |
| declared score      |   100% |

During catalog migration, two updated definitions initially matched two source sites and
were correctly rejected as invalid. They were narrowed, killed in a focused 2/2 rerun,
and then included in the clean canonical 52/52 run above. The canonical evidence is
`audit/current-mutation-results.json`; the focused definition check is
`audit/current-mutation-survivor-rerun.json`.

## Scope limit

A 100% declared score means every mutation in this reviewed catalog was killed. It does
not prove that every possible bug or mutation class was enumerated. The final release SHA
still requires independent review and a clean-checkout reproduction of this campaign.
