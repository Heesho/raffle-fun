:::part id="part-ix" no="Part IX" title="Contract Architecture" compact="true"
The protocol has a future-policy factory, independent constructor-deployed raffles,
and a read-only registry-authenticated Lens, plus offchain access layers.
- 50|RaffleFactory
- 51|Raffle Deployments
- 52|RaffleLens
- 53|Pyth Entropy Dependency
- 54|SDK
- 55|Subgraph
- 56|Frontend
- 57|Authoritative State
- 58|Architecture Diagram
:::

# Part IX | Contract Architecture

## 50. RaffleFactory

`RaffleFactory` is a non-upgradeable `Ownable2Step` registry and constructor deployer.
Its constructor fixes:

- one quote-token contract;
- one Pyth Entropy v2 contract;
- one nonzero callback gas limit;
- an initial protocol treasury;
- an initial owner.

The factory stores a mutable creation pause and treasury for future raffles, a raffle
counter, ID-to-address and address-to-ID mappings, and the canonical `isRaffle`
registry.

`createRaffle` validates terms, deploys, registers, emits, deposits, and verifies in
one nonreentrant transaction. The factory does not custody ticket proceeds or prizes
after creation.

## 51. Raffle Deployments

Each `Raffle` is an ordinary `CREATE` deployment with constructor-fixed configuration.
It is not an EIP-1167 clone, a proxy, or upgradeable. It inherits OpenZeppelin's
ordinary `ERC721`, not `ERC721Upgradeable`.

Every raffle independently stores its status, ticket count, gross sales, four quote-
accounting components, Entropy sequence and request time, winning ticket, prize claim
flag, metadata URI, and sponsor/treasury quote claims.

The raffle has no owner, administrator, pause, implementation pointer, generic call,
or asset sweep. Factory ownership does not propagate into it.

## 52. RaffleLens

`RaffleLens` is read-only. Its immutable factory identifies canonical raffles. Before
forwarding any read, the Lens checks `factory.isRaffle(raffle)`.

The Lens combines lifecycle, assets, timestamps, liabilities, winning ownership,
dynamic Entropy fee availability, and account-specific action flags. A temporary
Entropy fee-read failure is reported as unavailable rather than hiding all other
state.

`getRaffleStates` accepts at most {{LENS_BATCH_SIZE}} addresses. The Lens owns no assets
and changes no state. A Lens result is a convenience snapshot at one block, not a
transaction guarantee.

## 53. Pyth Entropy Dependency

Each raffle permanently stores the factory's Entropy address and callback gas limit.
The same gas limit is used for `getFeeV2` and `requestV2`. A changed Pyth fee is read at
request time.

Deployment validation must verify the official chain-specific Entropy address and
measure the callback gas limit against exact deployment bytecode. Fork tests are
evidence about pinned historical blocks, not proof that a future address or provider
policy remains correct.

## 54. SDK

The TypeScript SDK synchronizes ABIs from Hardhat artifacts. Its write helpers simulate
contract calls before sending them through a wallet. It covers creation, purchases,
draw request, refunds, empty close, winner redemption, sponsor prize recovery, quote
claims, and protocol-owned recovery.

The SDK validates refund lists for nonempty, positive, unique, bounded ticket IDs
before simulation. SDK checks improve usability but cannot override chain state or
make a failing token transfer succeed.

## 55. Subgraph

The subgraph listens to factory creation and raffle events. It reconstructs sponsors,
recovery recipients, tickets, transfers, burns, request data, status, fees, quote
claims, remaining refund liability, and prize claims.

An indexer can lag, omit a block, use the wrong deployment, or process a reorganization.
The subgraph is for discovery and history. It is never transaction or settlement
authority.

## 56. Frontend

The web application discovers raffles through indexed data, then reads authoritative
state and simulates writes. Missing or wrong-chain deployment configuration disables
writes. The interface presents creation, purchase, draw, refund, winner, recovery, and
quote-claim actions.

The checked-in sandbox is a preview model, not a deployment and not proof of contract
behavior. A website can also be compromised. Users should verify the chain, contract
address, function, value, and destination in the wallet.

## 57. Onchain Versus Indexed State

When data disagrees, use this priority:

1. production Solidity and current onchain state;
2. executable contract tests and generated ABI behavior;
3. a factory-authenticated Lens read;
4. SDK simulations and direct RPC reads;
5. subgraph entities;
6. frontend labels and cached views;
7. prose documents.

The lower layers remain useful, but only the EVM state transition determines whether a
transaction succeeds.

## 58. Architecture Diagram

:::figure src="diagrams/16-contract-architecture.svg" num="17" title="Contract architecture" caption="The factory deploys independent raffles. The Lens and offchain layers read state but do not settle assets. Pyth, USDC, and prize contracts remain external dependencies."
:::
