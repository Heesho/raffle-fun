:::part id="part-vi" no="Part VI" title="Security and Trust"
What the protocol promises, how the code defends those promises, and what remains outside its power.
- 28|Security Goals
- 29|Security Design Choices
- 30|Administrator Powers
- 31|The Trust and Dependency Map
- 32|Threat Model
- 33|What the Protocol Cannot Guarantee
- 34|Testing and Review
:::

# Chapter 28 | Security Goals

The protocol's security posture reduces to a short list of promises, each of which
is enforced by code and continuously attacked by the automated test suite. In plain
language:

- **The prize leaves escrow at most once**, and only to or by the one recorded
  claimant of the raffle's terminal outcome.
- **Exactly one resolution**: a raffle accepts one randomness sequence and one
  terminal settlement; nothing re-rolls, re-draws, or overwrites a result.
- **Every sold ticket can win**: the selection formula covers ticket 1 through the
  last ticket, inclusively, with equal probability.
- **The books always balance**: the contract's token balance always covers the pot,
  the uncredited refunds, and every recorded claim; claims can be spent once.
- **A failed draw refunds everyone exactly once**: each sold ticket credits its
  exact price to its failure-time holder, and the refund pool equals the pot.
- **Donations change nothing**: assets pushed at the contract outside its flows are
  inert surplus, never a trigger, never anyone's claim.
- **The administrator cannot reach into a live raffle**: no function exists by which
  the factory owner touches an existing raffle's assets, rules, or outcome.
- **Recovery is bounded**: every liveness dependency (the draw request, the
  callback) has a fixed deadline with a permissionless exit.

Appendix E states each of these formally alongside the invariant tests that check
them.

# Chapter 29 | Security Design Choices

:::figure src="diagrams/defense-depth.svg" num="13" title="Defense in depth" caption="Five concentric layers protect the core state-machine rules. An attack must penetrate process controls, the verification suite, architectural isolation, and the defensive coding layer before it can even engage the core invariants. Each layer assumes the ones outside it may fail."
:::

The notable choices, and why each was made:

**Non-upgradeable clones with a locked implementation.** Upgradeability is a
backdoor with good intentions. Removing it converts "trust the team not to change
the rules" into "the rules cannot change." The cost, that bugs cannot be hot-fixed
either, is treated as the price of the promise and mitigated by testing and by
versioned replacement (Chapter 27).

**Factory-only initialization with mutual authentication.** A clone accepts
configuration only from a factory that provably serves the same implementation the
clone runs, closing off look-alike factory attacks.

**Exact escrow validation.** The prize receiver binds contract, token ID, sender,
operator, and state; the factory then re-verifies real ownership. Unrelated NFTs
bounce; dishonest collections fail creation.

**Exact balance deltas on every token movement**, in and out, with SafeERC20
wrappers. Fee-skimming, rebasing, and misreporting tokens produce clean reverts, not
corrupted books.

**Reentrancy guards plus checks-effects-interactions everywhere.** Storage is
settled before any external contract is invoked, and guarded entry points make
nested calls revert. The adversarial test suite includes reentrant tokens, a
reentrant prize collection, and a reentrant ticket receiver.

**A storage-only oracle callback.** The randomness callback writes state and stops.
It transfers nothing and calls no third-party code, so it cannot be griefed by gas
or by hostile recipients, and its gas use is measured in tests with a required
safety margin under the configured limit.

**Bounded work in every transaction.** Purchases mint at most 100 tickets; refund
batches credit at most 100 tickets; lens reads batch at most 100 raffles; metadata
is capped. No loop's length is attacker-controlled without a bound.

**Monotonic state with idempotent rejection.** States move forward only; wrong,
stale, or duplicate callbacks are logged and ignored; double finalization is
structurally impossible.

**Transfer freezes at the two decisive moments** (draw pending, refund pending),
so ownership snapshots cannot be manipulated mid-decision.

**Two-step, multisig-ready ownership.** Factory ownership transfers require the
recipient to accept, preventing loss to a typo; the deployment runbook requires the
final owner to be a multisig.

# Chapter 30 | Administrator Powers

Trust claims should be falsifiable, so this chapter is the complete inventory of
administrative power at the reviewed commit, derived from the code rather than from
policy statements.

:::figure src="diagrams/admin-matrix.svg" num="14" title="The administrator's exact powers" caption="Everything the factory owner can do, everything it cannot, and the blast radius if its key were stolen. The cannot-side holds because the functions do not exist in the deployed code, not because of a promise."
:::

The factory owner **can**: admit or remove payment tokens for future raffle
creation (a bounded list of at most 32); change the treasury address that future
raffles will capture; pause the creation of new raffles; and transfer its own role
via a two-step handshake. Each of these affects only raffles that do not yet exist.

The factory owner **cannot**: modify any existing raffle's price, minimum, times,
deadlines, token, recovery address, fee, or split; select, replace, or influence a
winner; trigger, block, or redo a draw; pause, cancel, upgrade, or settle an
existing raffle; seize or redirect any prize, pot, refund, or claim; or extend its
own reach, because raffles contain no owner role and no function that consults the
factory after initialization.

A compromised owner key is therefore an inconvenience, not a catastrophe: it could
pause new creation, poison the future-raffle token list, redirect future (not
current) fee capture, or hand ownership to the attacker, and all of it is publicly
visible onchain the moment it happens. Every raffle already running, and every claim
inside it, would continue exactly as before.

# Chapter 31 | The Trust and Dependency Map

Every system trusts something. Security is knowing exactly what, and what happens if
that trust fails.

:::figure src="diagrams/trust-map.svg" num="15" title="The trust and dependency map" caption="Three rings of decreasing protocol control. The left ring is enforced by the code onchain; breaking it means breaking the chain or the code itself. The middle ring is real dependencies with designed failure modes. The right ring is beyond the protocol's reach entirely, and is where users must protect themselves."
:::

For each dependency, what can go wrong, what the protocol does about it, and what
remains yours to carry:

- **The underlying network (Ethereum or Base)**: can reorganize recent blocks,
  censor, or halt. The protocol inherits whatever its chain does; deadlines assume
  the chain keeps producing blocks. Mitigation: none possible in-contract; the
  network's own security model applies.
- **Solidity and OpenZeppelin**: a compiler or library bug would undermine any
  contract. Mitigation: pinned, widely used versions (0.8.36, OZ 5.6.1) and a large
  shared blast radius that makes such bugs loudly public. Residual: not zero.
- **Pyth Entropy**: can delay, fail, or in the worst case be compromised. Delay and
  failure are designed for: fixed deadlines convert them into refunds. Compromised
  randomness (a provider able to bias results) is mitigated by Pyth's commit-reveal
  design and reputation, but is a genuine trust assumption for the fairness of the
  draw itself.
- **The chosen ERC-20**: issuer pause, blacklist, or upgrade can delay or block
  specific withdrawals. Mitigation: the admission gate keeps exotic tokens out,
  exact-transfer checks turn misbehavior into clean reverts, and claimants can
  direct claims to alternate addresses. Residual: issuer power is real power.
- **The chosen ERC-721**: can be counterfeit, mutable, or administratively
  controlled. Mitigation: escrow verification proves possession and honest transfer
  mechanics at creation. Residual: authenticity and continued behavior are not
  provable by the raffle.
- **Wallets, RPC, frontend, subgraph, metadata hosts**: all can lie to you or go
  dark; none can alter contract state. Mitigation: the authority hierarchy of
  Chapter 26, live re-reads, and simulation. Residual: a user who signs what a liar
  suggests.
- **The factory owner multisig**: bounded as Chapter 30 describes. Residual: future
  raffle policy and the admitted-token list.

# Chapter 32 | Threat Model

This chapter asks, for each participant in turn: what is the worst they could try,
and what stops them? The table is a summary of the full internal threat model, which
lives in the repository and drives the adversarial test suite.

<!-- table:breakable -->
| Hostile actor | Representative attack | What stops it |
| --- | --- | --- |
| Sponsor | cancel after seeing weak sales | cancellation requires zero tickets sold, forever |
| Sponsor | raffle a counterfeit or self-controlled NFT | not stoppable in-contract; escrow verification proves possession only, and buyers must judge the collection (Chapter 36) |
| Sponsor | win their own raffle with bulk tickets | allowed and visible: purchases are public, odds are diluted openly, and the sponsor pays like anyone else |
| Buyer | pay less than the price via a taxed token | exact inbound balance-delta check reverts the purchase |
| Buyer | reenter the mint via a hostile receiver | reentrancy guard plus checks-effects-interactions |
| Buyer | buy after the close, or in the frozen states | exact state and timestamp checks |
| Ticket trader | snipe ownership between the draw request and the result | transfers are frozen for exactly that interval |
| Winner or claimant | claim twice, or redirect another's claim | claims zero their balance first; claim-for pays only the recorded account |
| Hostile claim recipient | revert on delivery to jam settlement | pull claims: only their own claim is affected, and it survives for retry |
| Payment token | skim, rebase, or misreport transfers | exact in/out delta checks; admission gate; clean reverts |
| Prize collection | lie about ownership at escrow | factory's post-transfer ownership verification fails creation |
| Callback forger | deliver a fake or duplicate random result | Entropy-only authentication, stored-sequence match, monotonic state |
| Draw requester | grief by requesting with the minimum fee then nothing | the request is the useful action; the callback needs nothing further from them |
| Anyone | force value or tokens at the contract to distort accounting | explicit liability accounting; surplus is inert |
| Factory owner | any reach into a live raffle | no such function exists (Chapter 30) |
| Frontend or indexer | display false state to induce bad transactions | authority hierarchy, live re-reads, simulation; ultimately user vigilance |
| Transaction searchers | reorder purchases near the close, or race the timeout boundary | boundaries are exact and public; the race at the callback deadline is deliberately neutral between two valid outcomes |

# Chapter 33 | What the Protocol Cannot Guarantee

This chapter exists so no reader can say the marketing buried the limits. None of
these are edge cases the team plans to fix; they are boundaries of what any smart
contract can promise.

- **Prize authenticity and value.** The contract escrows a token; whether it is the
  "real" artwork, whether its collection is legitimate, whether it holds any value
  next month, are all outside its knowledge.
- **Prize-collection behavior.** An upgradeable or admin-controlled NFT contract
  can freeze, alter, or reassign tokens while they sit in escrow. The raffle would
  still behave correctly; the prize inside it might not.
- **Payment-token issuer power.** Pauses and blacklists can delay or permanently
  block specific withdrawals. Refunds and claims are reserved and wait; the raffle
  cannot mint replacements.
- **Chain liveness and finality.** A halted or deeply reorganized network changes
  or suspends everything, deadlines included.
- **Oracle fairness.** The refund path bounds oracle unavailability, but the
  fairness of an actually delivered draw rests on Pyth's design holding.
- **Key custody.** Lost keys lose claims; there is no recovery desk. The recovery
  address exists precisely so sponsors can pre-commit a safer home for the prize.
- **User-side verification.** The protocol cannot stop a user from signing a
  transaction a counterfeit website suggested.
- **Metadata truthfulness.** Names, images, and descriptions travel outside the
  chain and can mislead; the contract sees none of it.
- **Legality.** Chance-based prize distribution is regulated activity in many
  places. Nothing here is a license, an opinion, or a defense.
- **Economic outcomes.** A legitimate raffle can still be a bad deal. Odds are
  transparent; value is your judgment.

# Chapter 34 | Testing and Review

What was actually done, reproduced at the reviewed commit, and what it does and
does not prove.

The Foundry suite contains 69 tests: unit and boundary tests for every function and
revert; a security suite driving adversarial mocks (reentrant tokens and receivers,
false-returning and fee-skimming tokens, an outbound-tax token, a dishonest-transfer
scenario, forced native value); 7 fuzz tests that hammer the arithmetic, the
selection range, the threshold boundary, and the refund completeness with 1,000
random cases each locally and 10,000 in CI; and 9 stateful invariant tests that
execute tens of thousands of random action sequences (256 runs of depth 64 locally,
1,000 of depth 256 in CI) while continuously asserting solvency, single-resolution,
prize-escrow, refund-conservation, and monotonicity properties. The Hardhat suite
adds 5 integration tests covering the Ignition deployment and two full journeys,
one normal and one through grace expiry, refunds, and claim-for recovery, plus
deployment-record validation. Static analysis (Slither, Solhint) is configured in
CI, gas expectations are snapshot into the repository, and the oracle callback's
measured gas is asserted to keep at least a 20 percent margin under its configured
limit.

Coverage of the production contracts measures 96.88 percent of lines, 90.00 percent
of branches, and 96.55 percent of functions, against a committed gate of at least
95 and 90. Mocks, scripts, and test code are excluded from that figure.

:::callout kind="risk"
None of this is an independent audit, and no quantity of testing proves the absence
of vulnerabilities. The repository's own deployment runbook makes an external
security review a hard gate before production. Until that happens, and until the
contracts are deployed and observed under real conditions, treat every guarantee in
this document as "designed and tested to," not "proven to."
:::
