:::part id="part-v" no="Part V" title="Architecture"
The contracts and tools that make up raffle.fun, and which of them you actually have to trust.
- 24|The Contract System
- 25|Architecture Diagram
- 26|What Is Authoritative?
- 27|Deployment and Versioning
:::

# Chapter 24 | The Contract System

raffle.fun is deliberately small: three production contracts onchain, and three
supporting tools off it.

**RaffleFactory** is the front door. It creates raffles, enforces every creation
rule (admitted payment token, valid times, real contracts, verified escrow), keeps
the registry that marks which raffle addresses are genuine, and holds the three
administrative dials described in Chapter 30. It never holds user assets.

**Raffle** is the heart: one contract per raffle, holding that raffle's prize,
money, tickets, and state machine. Each raffle is an **EIP-1167 clone**: a tiny
proxy that borrows its logic from a single locked implementation contract while
keeping fully separate storage. Cloning gives every raffle identical, auditable
behavior at a fraction of the deployment cost, and total isolation: a thousand
raffles share code but nothing else, so no raffle's assets are ever exposed to
another's activity. Crucially, these clones are not upgradeable proxies: the
implementation address is fixed in the clone's bytecode, the implementation itself
is locked against initialization, and no function anywhere can swap logic later.

**RaffleLens** is a stateless convenience: one call returns a raffle's full state,
deadlines, liabilities, and what actions a given wallet could take right now. It
refuses addresses the factory has not registered, so applications built on it cannot
be tricked into rendering a counterfeit raffle. It can only read.

Offchain, the **SDK** (a TypeScript library) carries the contract interfaces and
exact-math helpers so integrators compute the same numbers the contracts do; the
**subgraph** indexes events into a searchable history; and the **web app** is the
official interface. All three are conveniences: the protocol is complete without
them.

# Chapter 25 | Architecture Diagram

:::figure src="diagrams/architecture.svg" num="12" title="The complete system" caption="Everything in one view: the authoritative onchain layer (factory, locked implementation, per-raffle clones, the external token contracts, Pyth Entropy, and the read-only lens) and the replaceable offchain layer (web app, SDK, subgraph, wallets). Arrows are labeled with the only kinds of interaction that exist between the parts."
:::

Reading the diagram top to bottom: users act through wallets and the web app, which
talk to the chain via RPC. Writes go to the factory (creation) or a specific raffle
clone (everything else). The clone holds the two escrowed assets and talks to
exactly one external service, Pyth Entropy, over its request-and-callback channel.
Events flow up from the chain into the subgraph, which feeds discovery and history
back to the app: a one-way street. The lens serves batched reads. Nothing in the
offchain layer can write state, and no onchain component depends on the offchain
layer to function.

# Chapter 26 | What Is Authoritative?

When two sources of information disagree, which one is right? The protocol's answer
is a strict hierarchy, and it is worth internalizing because most practical attacks
are attempts to make you act on a lower layer's lie.

1. **Blockchain state**: the ledger itself. Who owns the prize, who holds which
   ticket, what every balance is. This is the ground truth.
2. **Verified contract code and configuration**: the published source that matches
   the deployed bytecode, and the raffle's fixed parameters. This is what will
   happen to the state.
3. **Transaction simulation**: a dry run of your exact transaction against current
   state, which the official app performs before every signature request.
4. **The subgraph**: indexed history. Fast and searchable, but it can lag the chain
   by blocks or fail entirely, and it is rebuilt, not original.
5. **Frontend presentation**: any website, including the official one. Maximally
   convenient, minimally authoritative, and the only layer an attacker can fake
   cheaply.

The web application is built to respect this hierarchy: lists and history come from
the subgraph, but every fact that matters to a transaction (price, state, claims,
verification status, the entropy fee) is re-read live from the chain immediately
before the wallet is asked to sign, and the transaction is simulated first. A
compromised or counterfeit frontend can still mislead a user into signing something
harmful, which is why the safety checklists in Chapter 38 begin with verifying
addresses.

# Chapter 27 | Deployment and Versioning

At the reviewed commit, the contracts are **not deployed to any network**. The
repository deliberately contains no addresses: its deployment registry holds only a
validation schema, and the tooling refuses to fabricate or copy addresses from
anywhere else. When a deployment happens, it follows a documented runbook: deploy
implementation, factory, and lens; verify the source on the block explorer; transfer
factory ownership to a multisig via a two-step handshake; record every address and
the exact source commit in a validated deployment file; and run a full end-to-end
raffle on the Base Sepolia test network before any production use. The runbook's
non-negotiable gates include an independent security review and legal review, and
mainnet deployment is intentionally excluded from the automated tooling.

Versioning is by replacement, never mutation. A future protocol version means a new
implementation and a new factory deployed beside the old ones. Existing raffles
continue on the code they were created with, forever; nothing about a new version
reaches back. An application may point users at the new factory, but that is a
frontend choice, visible onchain as a different factory address.

:::callout kind="enforce"
Clone configuration is immutable after initialization: no setter functions exist on
a raffle. The implementation contract permanently disables its own initialization.
The factory's constants (fee, splits, deadlines, bounds) are compiled in, so even
the factory owner cannot alter them without deploying an entirely new factory, which
cannot affect existing raffles.
:::
