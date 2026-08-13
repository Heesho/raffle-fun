# Residual risks and accepted assumptions

The 2026-08-13 ETHSkills review removed multiple High/Medium implementation risks, but
one High oracle trust issue remains unresolved: the Entropy provider can selectively
reveal a favorable result when it already owns tickets. The following external and
operational risks also remain.

## Assets

- USDC can blacklist, pause, upgrade, or otherwise change behavior. Exact-delta checks
  preserve onchain liabilities on revert but cannot force an issuer-controlled token
  to transfer.
- A reverting, paused, burned, or frozen prize cannot release NFT-branch quote proceeds;
  full refunds open after 30 days. A malicious/upgraded prize can still lie through
  ERC-165/`ownerOf` or misrepresent its value.
- Unrelated NFTs forced in by unsafe transfer have no rescue path.

## Bearer destinations

Unsafe ERC-721 transfer to an arbitrary non-callable user-selected contract can lock a
ticket. Known current protocol destinations are rejected. Future code-less addresses,
arbitrary bytecode capability, unrelated factory graphs, and lost keys remain
unsupported without a generic seizure-capable rescue path.

## Oracle and chain

- Pyth documents that the provider can know the final word before reveal and may
  selectively withhold it. Transfer locking prevents post-request winner purchases,
  but a provider that already owns tickets can reveal favorable results and accept
  refunds otherwise. Provider pinning prevents silent substitution but does not solve
  selective reveal.
- Modulo mapping has negligible but nonzero mathematical bias for most ticket counts.
- The Base sequencer can order the callback/timeout boundary, delay requests, or censor
  transactions. First-valid-terminal-transition semantics are deterministic given
  inclusion but cannot defeat universal censorship or a halted/reorganized chain.
- Pyth fee/provider gas policy, default provider, and official addresses are external
  configuration that must be reverified at deployment time.

## Code and operations

- `RaffleFactory` runtime is 24,267 bytes, only 309 bytes below EIP-170. Any production
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
