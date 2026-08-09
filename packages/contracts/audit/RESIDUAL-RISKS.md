# Residual risks and accepted assumptions

No unresolved Critical, High, or Medium supported-asset finding remains in the
internal campaign. The following risks remain external, operational, or deliberately
outside the scoped recovery property.

## Assets

- USDC can blacklist, pause, upgrade, or otherwise change behavior. Exact-delta checks
  preserve onchain liabilities on revert but cannot force an issuer-controlled token
  to transfer.
- A malicious/upgraded prize can lie through ERC-165/`ownerOf`, burn escrow, reject
  transfer, reenter, or change behavior. The supported property assumes honest,
  available ERC-721 ownership and safe transfer.
- Unrelated NFTs forced in by unsafe transfer have no rescue path.

## Bearer destinations

Unsafe ERC-721 transfer to an arbitrary non-callable user-selected contract can lock a
ticket. Known current protocol destinations are rejected, and same-factory future
canonical raffle addresses have a selective ticket/quote/prize recovery path, but
arbitrary bytecode capability, unrelated factory graphs, and lost keys are not solvable
without a generic rescue or removing ERC-721 transferability.

## Oracle and chain

- Pyth Entropy's default PRNG assumes the provider and validator do not collude. An
  unavailable oracle leads to refunds, not replacement randomness; it does not remove
  the oracle trust assumption on successful draws.
- Modulo mapping has negligible but nonzero mathematical bias for most ticket counts.
- The Base sequencer can order the callback/timeout boundary, delay requests, or censor
  transactions. First-valid-terminal-transition semantics are deterministic given
  inclusion but cannot defeat universal censorship or a halted/reorganized chain.
- Pyth fee/provider gas policy and official addresses are external configuration that
  must be reverified at deployment time.

## Code and operations

- `RaffleFactory` runtime is 24,311 bytes, only 265 bytes below EIP-170. Any production
  change requires a fresh size gate.
- Constructor-deployed raffles are immutable. Incident response can pause only future
  creation and remove frontend exposure; it cannot patch an existing raffle.
- No signed/live deployment record exists. Mainnet ownership, verification, Safe
  policy, monitoring, and smoke-test evidence are pending.
- This is an internal adversarial review, not an independent external audit or formal
  verification.
- A monitored Base Sepolia period, independent audit of the exact final commit and
  dependencies, jurisdiction-specific legal review, operational runbooks, and bug
  bounty/private disclosure readiness remain release blockers.

## Tool limitations

SMTChecker could not model much of the dependency graph; Mythril was unavailable on
the installed Python runtime. Semgrep's community Solidity rules are primarily
pattern/performance checks. Fuzzing, mutation, symbolic execution, static analysis,
coverage, and fork tests reduce risk but cannot enumerate all states or external
behaviors.
