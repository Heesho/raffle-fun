# Current residual risks and release blockers

This ledger applies to the uncommitted Ethereum v1 candidate. It distinguishes risks
the contract deliberately contains from work still required before mainnet. Passing
internal tests does not make any item safe for unlimited value.

## Protocol and dependency risks

### VRF availability and configuration

The configured Chainlink VRF v2.5 wrapper and coordinator are external dependencies.
An outage, configuration change, gas-pricing change, coordinator failure, or prolonged
censorship can prevent a callback. The contract cannot switch providers or raise its
immutable 300,000 callback limit. Buyers can enable full refunds two days after an
accepted request, but that recovers entry value rather than producing the intended
draw. A callback and timeout finalization remain a first-included transaction race at
and after the deadline.

Mitigation before release: independently verify the exact wrapper/coordinator,
supported confirmation range, pricing behavior, callback gas margin, and operational
status on release day; monitor every request and deadline; document who funds and
triggers requests.

### Chain reorganization and transaction ordering

Thirty confirmations materially reduces ordinary reorganization risk but does not
create a mathematical finality guarantee. Ethereum validators/builders also determine
transaction ordering near sale and timeout boundaries. Purchases, draw requests,
callbacks, and refund finalizers follow exact timestamp gates and first-included
semantics.

### USDC issuer and proxy controls

The production design assumes the intended six-decimal USDC deployment transfers
exactly and does not rebase. Circle can upgrade, pause, or blocklist through external
issuer controls. A pause or blocklist can leave individual payouts unavailable.
Exact-balance checks prevent silent accounting loss but cannot restore liveness. A
consistently lying or malicious token is unsupported.

### Prize behavior

The factory checks ERC-721 interface support, exact escrow, and ownership
postconditions, but it cannot prove future behavior. Upgradeable, pausable,
transfer-restricted, burned, or dishonest prize contracts can block winner delivery.
A valid random result is final, so a broken prize can block settlement and keep the
quote pot escrowed indefinitely. A malicious NFT able to lie consistently about
ownership is outside the supported model. Prize admission and collection review are
therefore material launch controls, not optional metadata checks.

Winner delivery uses unsafe ERC-721 `transferFrom` intentionally so a contract ticket
owner cannot veto fixed-owner delivery. A winner contract that cannot later transfer
the NFT may strand its own prize. Frontends must warn contract recipients before a
ticket is acquired.

### Credential-owner reachability

Cash and NFT winner settlement are permissionless and fixed to the current ticket owner,
but refund redemption is owner-only because burning the bearer credential must be
authorized by that owner. A ticket held by a destroyed, incapable, or inaccessible
contract can therefore leave its refund permanently unclaimed. The protocol cannot
infer future code or key availability.

### No economic value cap

The contracts intentionally impose no dollar-denominated or gross-sales ceiling.
That avoids artificial protocol limits but means exposure can grow far beyond the
internal assurance level. The `uint128` entry domain is only a machine bound, not a
risk control. If launch governance requires a cap, it must be implemented onchain
before the final audit; a frontend-only cap is bypassable.

### Immutable implementation

Each raffle clone is non-upgradeable. This removes upgrade-admin seizure risk but also
means a discovered bug cannot be patched in place. The factory can pause only new
creation; existing raffles must finish under their deployed code. Incident response is
frontend warnings, monitoring, voluntary user behavior, and migration to a new factory.

### Modulo mapping

`(randomWord % totalEntries) + 1` has mathematically nonzero modulo bias unless the
entry count divides `2^256`. The absolute per-entry probability difference is
`2^-256`, negligible for realistic entry counts, but the design should not be marketed
as perfectly uniform.

### Irrecoverable surplus and unrelated assets

Forced native currency, excess quote donations, and unrelated NFTs sent with unsafe
transfer paths have no rescue mechanism. They are excluded from liabilities. This is
intentional surface-area reduction and should be disclosed.

## Operational and integration risks

- The factory owner and protocol treasury must be independently reviewed contract
  wallets with tested signer, recovery, module, and monitoring policies.
- Deployment records, source verification, runtime hashes, owner acceptance, and
  official dependency addresses must be checked against a finalized release-day block.
- The subgraph is eventually consistent and non-authoritative. Ticket ownership and
  every write must be read/simulated against Ethereum.
- Large values must remain `bigint` end to end. A JavaScript `number` conversion can
  silently corrupt uncapped `uint128` counts.
- The old generated whitepaper is a historical Base/Pyth design and must not be
  published as the current protocol.
- Raffles and prize promotions can trigger gaming, lottery, consumer, sanctions, tax,
  privacy, and advertising obligations that differ by jurisdiction.

## Mainnet blockers

1. Create and freeze the exact final source commit and lockfile.
2. Rerun every build, test, invariant, fuzz, static, ABI, deployment, SDK, subgraph,
   web, fork, gas, and dependency gate from a clean checkout of that SHA.
3. Obtain an independent audit of that exact commit and resolve every Critical/High
   and supported-asset Medium finding.
4. Complete a monitored Sepolia soak across NFT success, cash success, empty raffle,
   the callback timeout, both deadline orderings, weighted partial/full refunds, contract
   ticket owners, and failed/retried prize delivery.
5. Deploy and drill monitoring, incident response, frontend-disable, and new-factory
   migration procedures.
6. Complete legal review and a written value-limit/go-no-go decision.
7. Verify production owner/treasury wallets, Chainlink/USDC dependencies, source,
   runtime bytecode, and signed deployment record before enabling writes.

Until those items are complete, the candidate is audit-ready—not mainnet-ready.
