# Whitepaper status

The long-form generated whitepaper is intentionally unpublished. Its source and prior
outputs describe older Base/Pyth, full-deployment, Lens, per-ticket, and different
economic designs. They must not be used for deployment, integration, audit, or
transaction decisions.

The current candidate v1 is documented by:

- [repository overview](../README.md);
- [architecture](ARCHITECTURE.md);
- [lifecycle](STATE-MACHINE.md);
- [economics](ECONOMICS.md);
- [Chainlink VRF](RANDOMNESS.md);
- [security invariants](SECURITY-INVARIANTS.md);
- [threat model](THREAT-MODEL.md);
- [deployment runbook](DEPLOYMENT.md).

The public [one-pager](one-pagers/raffle-fun.md) and
[plain-language article](articles/raffle-fun-explained.md) describe the new mechanism
without serving as release specifications.

`docs/whitepapers/raffle-fun-technical-whitepaper.md`,
`docs/facts/raffle-fun-facts.md`, and `docs/whitepaper/**` are historical or
publication-workspace artifacts until they are regenerated from the finalized,
independently audited v1 commit. The build must remain blocked rather than produce a
polished but incorrect document.

Historical audit reports and whitepapers remain useful only for the exact commits and
architectures they name.
