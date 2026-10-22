# RaffleFactory requirement extraction

Source: `target/packages/contracts/src/RaffleFactory.sol` (read in full, lines 1–186).

Requested frozen commit: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155` (supplied by the request; not independently verified).

This report performs the native extraction request only. It contains 34 independently scoped requirements: 5 mandatory and 29 descriptive. It assigns no implementation-compliance verdicts.

## Extraction method and scope

The source's explicit NatSpec prose and behavioral inline comment at L107 are the specification evidence. Each quote is a verbatim sentence or contiguous clause from that file. A compound sentence is repeated where necessary so that each record's checkable field isolates one claim without rewriting the quotation. Repeated statements of the same guarantee are represented once: ownerlessness and immutable configuration at L58 overlap L18–19; fixed implementation and atomicity at L107 overlap L17; the contract-address parameter description at L182 overlaps L181.

The title, author, version, section labels, suppression directive, and parameter label describing prospective configuration are not treated as additional behavioral requirements. The @inheritdoc directives do not themselves state requirements; referenced interface prose was not imported into this single-document extraction. No requirement was inferred from an executable statement, constant value, or error name.

The meaning of 'autonomous' and the scope of 'locked' are unspecified. Generic token, recipient, and reserve validation prose specifies validation and its ordering, but not exact validity predicates. Official dependency identities and deployment-tooling verification need evidence outside this source file. The constructor's metadata limitation is retained as an explicit trust-boundary claim.

## Source reads and searches

- `nl -ba target/packages/contracts/src/RaffleFactory.sol` — read the complete 186-line source file.
- `rg -n '^\s*///|fresh fixed-target' target/packages/contracts/src/RaffleFactory.sol` — located the explicit NatSpec blocks at L15–20, L58–64, L152–153 and L181–182, the behavioral comment at L107, and inheritance directives at L24, L27, L32, L35, L38, L41, L44, L47, L50, L53 and L96.

Only this target source file was read. No tests, compilers, analyzers, scanners, fuzzers, chain calls, network research, historical results, or other worker outputs were used.

## Requirements

### REQ-01 — Atomic creation

> Atomically creates, funds, and registers autonomous fixed-implementation raffle clones.

Source: `target/packages/contracts/src/RaffleFactory.sol:L17`  
Kind: `invariant` · Force: `descriptive`

Checkable: Creation, funding, and registration succeed or revert together, without leaving partial creation state.

### REQ-02 — Clone creation

> Atomically creates, funds, and registers autonomous fixed-implementation raffle clones.

Source: `target/packages/contracts/src/RaffleFactory.sol:L17`  
Kind: `state-machine` · Force: `descriptive`

Checkable: The factory creates raffle clones.

### REQ-03 — Clone funding

> Atomically creates, funds, and registers autonomous fixed-implementation raffle clones.

Source: `target/packages/contracts/src/RaffleFactory.sol:L17`  
Kind: `economic` · Force: `descriptive`

Checkable: The factory funds each newly created raffle; this sentence does not specify the funding asset or amount.

### REQ-04 — Clone registration

> Atomically creates, funds, and registers autonomous fixed-implementation raffle clones.

Source: `target/packages/contracts/src/RaffleFactory.sol:L17`  
Kind: `state-machine` · Force: `descriptive`

Checkable: The factory registers each newly created raffle.

### REQ-05 — Autonomous clones

> autonomous fixed-implementation raffle clones.

Source: `target/packages/contracts/src/RaffleFactory.sol:L17`  
Kind: `other` · Force: `descriptive`

Checkable: Not fully checkable: 'autonomous' does not define which operations must proceed without which actors or dependencies.

### REQ-06 — Fixed clone implementation

> fixed-implementation raffle clones.

Source: `target/packages/contracts/src/RaffleFactory.sol:L17`  
Kind: `invariant` · Force: `descriptive`

Checkable: Each raffle clone retains a fixed implementation target throughout its lifetime.

### REQ-07 — Immutable implementation

> The implementation, canonical six-decimal USDC, treasury, fee, and Chainlink configuration are immutable.

Source: `target/packages/contracts/src/RaffleFactory.sol:L18`  
Kind: `invariant` · Force: `descriptive`

Checkable: The factory's raffle implementation cannot change after deployment.

### REQ-08 — Immutable quote token

> The implementation, canonical six-decimal USDC, treasury, fee, and Chainlink configuration are immutable.

Source: `target/packages/contracts/src/RaffleFactory.sol:L18`  
Kind: `invariant` · Force: `descriptive`

Checkable: The factory's configured canonical USDC address cannot change after deployment.

### REQ-09 — Immutable treasury

> The implementation, canonical six-decimal USDC, treasury, fee, and Chainlink configuration are immutable.

Source: `target/packages/contracts/src/RaffleFactory.sol:L18`  
Kind: `invariant` · Force: `descriptive`

Checkable: The configured protocol treasury cannot change after deployment.

### REQ-10 — Immutable fee

> The implementation, canonical six-decimal USDC, treasury, fee, and Chainlink configuration are immutable.

Source: `target/packages/contracts/src/RaffleFactory.sol:L18`  
Kind: `economic` · Force: `descriptive`

Checkable: The configured protocol fee cannot change after deployment; this sentence specifies no fee value.

### REQ-11 — Immutable Chainlink configuration

> The implementation, canonical six-decimal USDC, treasury, fee, and Chainlink configuration are immutable.

Source: `target/packages/contracts/src/RaffleFactory.sol:L18`  
Kind: `invariant` · Force: `descriptive`

Checkable: The Chainlink configuration cannot change after deployment.

### REQ-12 — No owner

> factory has no owner, pause, upgrade, rescue, or mutable protocol configuration.

Source: `target/packages/contracts/src/RaffleFactory.sol:L19`  
Kind: `access-control` · Force: `descriptive`

Checkable: The factory has no owner role.

### REQ-13 — No pause

> factory has no owner, pause, upgrade, rescue, or mutable protocol configuration.

Source: `target/packages/contracts/src/RaffleFactory.sol:L19`  
Kind: `state-machine` · Force: `descriptive`

Checkable: The factory exposes no mechanism to pause its operation.

### REQ-14 — No upgrade

> factory has no owner, pause, upgrade, rescue, or mutable protocol configuration.

Source: `target/packages/contracts/src/RaffleFactory.sol:L19`  
Kind: `invariant` · Force: `descriptive`

Checkable: The factory has no upgrade mechanism.

### REQ-15 — No rescue

> factory has no owner, pause, upgrade, rescue, or mutable protocol configuration.

Source: `target/packages/contracts/src/RaffleFactory.sol:L19`  
Kind: `access-control` · Force: `descriptive`

Checkable: The factory has no asset-rescue mechanism.

### REQ-16 — No mutable protocol configuration

> factory has no owner, pause, upgrade, rescue, or mutable protocol configuration.

Source: `target/packages/contracts/src/RaffleFactory.sol:L19`  
Kind: `invariant` · Force: `descriptive`

Checkable: No protocol-configuration setting can be changed after factory deployment.

### REQ-17 — Implementation deployment

> Deploys the ownerless factory and its locked raffle implementation with one immutable configuration.

Source: `target/packages/contracts/src/RaffleFactory.sol:L58`  
Kind: `state-machine` · Force: `descriptive`

Checkable: Deploying the factory also deploys its raffle implementation.

### REQ-18 — Locked implementation

> Deploys the ownerless factory and its locked raffle implementation with one immutable configuration.

Source: `target/packages/contracts/src/RaffleFactory.sol:L58`  
Kind: `state-machine` · Force: `descriptive`

Checkable: Not fully checkable: 'locked' does not define which calls or state transitions must be prohibited on the implementation.

### REQ-19 — Six-decimal quote token

> The quote token must report exactly six decimals

Source: `target/packages/contracts/src/RaffleFactory.sol:L59`  
Kind: `invariant` · Force: `mandatory`

Checkable: Factory deployment requires the quote token's reported decimals to equal exactly six.

### REQ-20 — Wrapper deployed code

> the wrapper and quote token must contain deployed code.

Source: `target/packages/contracts/src/RaffleFactory.sol:L59`  
Kind: `invariant` · Force: `mandatory`

Checkable: Factory deployment requires deployed code at vrfWrapper_.

### REQ-21 — Quote-token deployed code

> the wrapper and quote token must contain deployed code.

Source: `target/packages/contracts/src/RaffleFactory.sol:L59`  
Kind: `invariant` · Force: `mandatory`

Checkable: Factory deployment requires deployed code at quoteToken_.

### REQ-22 — Supply official USDC

> Deployment tooling must supply and verify the target chain's official USDC address

Source: `target/packages/contracts/src/RaffleFactory.sol:L60`  
Kind: `trust-boundary` · Force: `mandatory`

Checkable: Deployment tooling supplies the target chain's official USDC address as quoteToken_; establishing this requires tooling and chain-specific deployment evidence.

### REQ-23 — Verify official USDC

> Deployment tooling must supply and verify the target chain's official USDC address

Source: `target/packages/contracts/src/RaffleFactory.sol:L60`  
Kind: `trust-boundary` · Force: `mandatory`

Checkable: Deployment tooling verifies that the supplied quoteToken_ is the target chain's official USDC address.

### REQ-24 — Metadata identity limitation

> cannot prove token identity from metadata.

Source: `target/packages/contracts/src/RaffleFactory.sol:L61`  
Kind: `trust-boundary` · Force: `descriptive`

Checkable: The constructor's token-metadata checks alone do not establish official USDC identity; that identity requires independent chain-specific evidence.

### REQ-25 — Shared trusted quote token

> Target chain's official six-decimal USDC contract trusted by every raffle.

Source: `target/packages/contracts/src/RaffleFactory.sol:L62`  
Kind: `trust-boundary` · Force: `descriptive`

Checkable: Every factory-created raffle uses quoteToken_ as its trusted quote-token contract.

### REQ-26 — Official Chainlink wrapper

> Official Chainlink VRF v2.5 native direct-funding wrapper for the target chain.

Source: `target/packages/contracts/src/RaffleFactory.sol:L63`  
Kind: `trust-boundary` · Force: `descriptive`

Checkable: vrfWrapper_ is the target chain's official Chainlink VRF v2.5 native direct-funding wrapper; official-address identity requires deployment evidence.

### REQ-27 — Shared protocol-fee recipient

> Immutable protocol-fee recipient used by every raffle.

Source: `target/packages/contracts/src/RaffleFactory.sol:L64`  
Kind: `economic` · Force: `descriptive`

Checkable: Every factory-created raffle uses protocolTreasury_ as its protocol-fee recipient.

### REQ-28 — One-time clone initialization

> The fresh fixed-target clone can initialize only once

Source: `target/packages/contracts/src/RaffleFactory.sol:L107`  
Kind: `state-machine` · Force: `descriptive`

Checkable: A newly created clone cannot be successfully initialized more than once.

### REQ-29 — Nonreentrant creation

> this function is nonReentrant

Source: `target/packages/contracts/src/RaffleFactory.sol:L107`  
Kind: `access-control` · Force: `descriptive`

Checkable: createRaffle cannot be reentered while an invocation is executing.

### REQ-30 — Token validation before cloning

> Validates the sponsor-selected token, recipient, reserve, and supported ERC-721 interface before cloning.

Source: `target/packages/contracts/src/RaffleFactory.sol:L152`  
Kind: `ordering` · Force: `descriptive`

Checkable: The sponsor-selected prize token is validated before clone creation; the comment does not define the full token-validity predicate.

### REQ-31 — Recipient validation before cloning

> Validates the sponsor-selected token, recipient, reserve, and supported ERC-721 interface before cloning.

Source: `target/packages/contracts/src/RaffleFactory.sol:L152`  
Kind: `ordering` · Force: `descriptive`

Checkable: The sponsor-selected recipient is validated before clone creation; the comment does not define the recipient-validity predicate.

### REQ-32 — Reserve validation before cloning

> Validates the sponsor-selected token, recipient, reserve, and supported ERC-721 interface before cloning.

Source: `target/packages/contracts/src/RaffleFactory.sol:L152`  
Kind: `ordering` · Force: `descriptive`

Checkable: The sponsor-selected reserve is validated before clone creation; the comment does not specify the permitted reserve range.

### REQ-33 — ERC-721 support validation before cloning

> Validates the sponsor-selected token, recipient, reserve, and supported ERC-721 interface before cloning.

Source: `target/packages/contracts/src/RaffleFactory.sol:L152`  
Kind: `ordering` · Force: `descriptive`

Checkable: The prize token's support for the ERC-721 interface is validated before clone creation.

### REQ-34 — Reject addresses without deployed code

> Reverts unless an address contains deployed code.

Source: `target/packages/contracts/src/RaffleFactory.sol:L181`  
Kind: `error-handling` · Force: `descriptive`

Checkable: _requireContract(account) reverts whenever account contains no deployed code.

## Artifacts

- `REPORT.md`: extraction scope, actual reads/searches, and requirement records.
- `requirements.json`: the schema-bound extraction record returned by this request.

Per-requirement compliance analyses and verdicts were not requested by this extraction stage.
