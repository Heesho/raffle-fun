I've written the full report to `TOB-S4-guidelines-advisor.md` in the working directory. I found no critical code bugs; the important work before deployment is in design decisions, documentation and operations. Nothing under `packages/` was modified (checked at the end: no new files, no build folders, dependency hashes unchanged).

**How I checked it:**
- I read all five in-scope files line by line, plus the inherited OpenZeppelin and Chainlink code that affects behavior.
- I compiled a copy outside `packages/` with solc 0.8.36: zero compiler warnings.
- I ran Slither, Aderyn, `slither-check-upgradeability` and forge-lint. None of them reported a real High or Medium issue; every result is triaged in Appendix A.
- Code comments are complete: all 217 functions, events, errors and state variables are documented.
- I wrote 10 proof-of-concept tests and ran them on that copy against mock USDC and a mock Chainlink wrapper. All pass, and they confirm the code matches DESIGN.md: the 95/5 and 80/15/5 splits with nothing left over, 100% refunds, and the exact deadline boundaries.

**High priority (decide or document before deployment):**
- **GA-H1 — NFT winners have no fallback:** if the prize can't be delivered, the winner gets nothing while the sponsor's 95% and the 5% fee are still paid out. Two tests show this:
  - A fake prize contract creates an official-looking, registered raffle without escrowing anything.
  - An honest collection that pauses transfers after creation blocks the winner too.

  This follows directly from the spec ("prize contracts are untrusted" plus "sponsor and treasury claim independently"), so it needs an explicit decision and disclosure. The report gives three options.
- **GA-H2 — DESIGN.md is one paragraph:** for contracts that can never be patched, it needs a state machine, trust and failure modes, invariants and edge cases. It also contradicts the interface on prize trust (DESIGN.md says prizes are untrusted; `IRaffle.sol` says supported prizes are honest).
- **GA-H3 — No deployment verification checklist** for settings that can't be changed after deployment (USDC address, Chainlink wrapper, treasury).
- **GA-H4 — No incident-response or migration plan** for a system with no admin and no pause.

**Medium:**
- **GA-M1:** a pending Chainlink callback reveals the winner, so ticket listings can be front-run while a draw is in progress.
- **GA-M2:** every raffle's tickets have the same name and symbol and no metadata, so scam raffles look identical in wallets.
- **GA-M3:** draws depend on someone paying the Chainlink fee with no reimbursement; if nobody does, everyone gets refunded.
- **GA-M4:** `RaffleCreated` is emitted after the prize-deposit event, which may matter for the subgraph.

There are also 9 low-priority clean-ups (inline assembly, gas, interfaces) and 6 informational notes.

**Limitations:**
- Tests, audit history and CI weren't provided, so I recorded them as a limitation, not a finding. The report gives a project-specific test plan (§10) to check against the full repository.
- The tests used mocks; real USDC pause/blacklist and real Chainlink pricing weren't exercised.
- The run was offline, so I couldn't check upstream security advisories for the libraries or compiler.
- Eight open design questions are listed in §14 because none could be asked during the run.

The test source is in Appendix D of the report. The scratch copies are under `/tmp/tobs4-*`; I didn't delete them because the cleanup command was blocked.