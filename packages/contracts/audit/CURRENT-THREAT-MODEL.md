# Current-Commit Threat Model

**Reviewed source:** `5772e54ba89c06646815ed52a881cd8940f094ca`, independently re-derived 2026-08-16. This is an internal adversarial review, not an independent audit or proof.

## Security objectives

1. A supported prize leaves escrow at most once and only through the result/fallback authorized by lifecycle state.
2. Quote obligations are conserved, solvent, paid at most once, and never released to sponsor/treasury while NFT buyers remain exposed to failed delivery.
3. Ticket ownership remains the sole bearer credential; locks, approvals, overloads, callbacks, and cross-Raffle interactions cannot redirect it.
4. Only one of callback settlement and a timeout fallback creates liabilities.
5. Factory policy cannot mutate an existing Raffle, and creation/deposit/registration is atomic.
6. All loops and callback work remain bounded.
7. Off-chain components reflect but never expand on-chain authorization.

## Actors and capabilities

| Actor                             | Assumed or adversarial capability                                                                       | Security boundary                                                                               |
| --------------------------------- | ------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Sponsor                           | Chooses supported prize, price, threshold, schedule, metadata, recovery account; may also buy tickets   | Cannot administer an existing Raffle or receive NFT-branch proceeds before delivery             |
| Buyer/ticket owner                | Arbitrary EOAs/contracts, approvals, transfers, batching, ordering, native overpayment, callback hooks  | Owns bearer right; responsible for arbitrary incapable destination choices                      |
| Factory owner                     | May pause creation, update future treasury, transfer ownership                                          | Must not affect existing Raffles; renunciation is disabled                                      |
| Pyth/Entropy provider             | Supplies fee, request sequence, and callback randomness; may withhold a reveal after learning outcome   | Authenticated but not assumed unbiased/lively; selective reveal is an external trust assumption |
| Base sequencer/validator/searcher | Reorders/censors transactions, manipulates timestamp within consensus constraints, sees pending actions | Inclusion order decides documented boundary races                                               |
| Circle/USDC administrator         | Can change proxy implementation/policy and may pause/freeze/blocklist                                   | Availability and exact-transfer behavior are external assumptions                               |
| Prize contract administrator      | May pause, burn, freeze, upgrade, or lie if sponsor chooses a malicious asset                           | Only honest standards-compliant ERC-721s are supported                                          |
| Indexer/RPC/frontend              | May lag, reorg, omit events, return stale data, or render hostile metadata                              | Cannot authorize writes; every write must use current chain simulation/state                    |

## Assets and trust boundaries

- One configured ERC-721 prize per Raffle.
- Exact raw USDC liabilities and any unaccounted token surplus.
- ERC-721 tickets, approvals, and ownership history.
- Entropy request fee and forced/unaccounted native currency.
- Factory registry/configuration, deployment records, ABIs, indexer entities, metadata, and UI transaction inputs.

Immutable code reduces governance scope but removes emergency recovery. Forced unrelated ERC-721s, direct quote donations, and forced native currency intentionally have no generic rescue route. This avoids privileged asset extraction but can permanently strand unrelated assets.

## Selective-reveal economic model

Pyth's protocol design discloses that a provider can compute the final result before reveal and therefore has a censorship/selective-reveal opportunity. Transfer locking after request prevents buying or moving the winning credential after the request, but does not remove the option to withhold.

Let a provider own fraction `f` of identically priced tickets, gross pot `G`, and value its favorable winner payoff at `V`. Ignore losing souvenir value and request costs. If every result is revealed, its net expected ticket payoff is:

```text
EV(always reveal) = fV - fG
```

If it reveals only when one of its tickets wins and lets every loss become a full refund:

```text
EV(selective) = f(V - fG)
advantage = EV(selective) - EV(always reveal) = fG(1-f)
```

The option-value advantage is maximized at `f=1/2`, where it is `G/4`, before provider fees, delay, capital costs, censorship cost, or penalties. The same expression applies to a cash payoff `V = winnerCash` in the simplified model. With a colluding sponsor, compare the coalition's resolved prize/proceeds payoff with its timeout-refund/prize-recovery payoff for each outcome; the general advantage is `E[max(resolved payoff, timeout payoff)] - E[resolved payoff]` and can be larger or smaller depending on NFT value and ticket distribution.

Timeouts cap how long funds are unavailable but create the unfavorable-result exit. A longer callback deadline increases the censorship window; a shorter one may increase accidental timeouts. Mempool/private-order visibility and Base sequencer censorship can help enforce withholding. This campaign does not label the issue solved.

Recommendation order, without implementation:

1. Pin and publicly identify a reviewed provider and monitor non-reveal rate/commit rotation.
2. Evaluate transformed user/provider entropy or a commit-reveal composition, including user non-reveal griefing.
3. Compare Chainlink VRF and other RNGs on Base for liveness, callback authentication, cost, and upgrade/governance assumptions.
4. Consider multiple independent sources only with a composition that does not let any one party selectively abort.
5. Explore provider bonds/slashing where non-reveal is objectively attributable.
6. If retaining the design, disclose provider selective reveal as an accepted High external trust assumption and price/limit raffles accordingly.

## Principal attack surfaces and dispositions

| Surface          | Cheapest adversarial strategy                                              | Current control                                                                            | Remaining risk                                                         |
| ---------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| Entropy          | Synchronous/wrong/duplicate/late callback; selective withholding           | in-flight flag, sequence/state checks, authenticated wrapper, timeouts                     | provider withholding and sequencer censorship                          |
| Quote token      | tax/rebase/lie/reenter/freeze/blacklist/upgrade                            | exact incoming/outgoing balance deltas, CEI, reentrancy guard                              | consistent lies and administrator denial of service                    |
| Prize token      | reenter, wrong owner, freeze, burn, upgrade, malformed receiver behavior   | atomic escrow verification, delivery verification, delayed proceeds, buyer refund fallback | prize/recovery can become undeliverable; malicious NFT can lie         |
| Bearer tickets   | stale approval, operator bypass, safe overload, incapable destination      | owner-only redemption, transfer override, status/winner locks, known-protocol denylist     | arbitrary/future incapable destinations                                |
| Lifecycle        | exact-boundary order, year-long non-finalization, duplicate action         | single status, permissionless finalizers, exact comparisons                                | no automatic progress; censorship/liveness                             |
| Factory          | creation reentrancy, partial registry, owner compromise, predicted address | nonReentrant, atomic transaction, future-only controls, ordinary CREATE                    | owner can pause indefinitely; address prediction is nonce-dependent    |
| Composition      | use an inner raffle ticket as outer prize                                  | same-factory destination denial; outer timeout preserves buyer refunds                     | cross-factory nested ticket can become stranded                        |
| Native refund    | reject/reenter/consume gas/returndata bomb                                 | failure reverts entire request; no native liability                                        | requester can grief only its own request; forced native stays stranded |
| Lens/indexer/web | stale state, omitted event, metadata script, wrong chain                   | on-chain checks remain authoritative; bounded Lens                                         | off-chain UX can mislead or disable users                              |

## Boundary races

- At callback timeout: callback first resolves; `enableRefunds` then reverts. Finalizer first enters `Refunding`; callback is ignored. No double liability is created.
- At NFT redemption timeout: verified delivery first releases claims; finalizer then reverts. Finalizer first creates full refunds; redemption then reverts. Buyer funds and sponsor proceeds cannot both be released.
- At request-grace deadline: draw is already closed and refund finalization is open.
- At sale end: purchases are closed; draw or empty closure is open depending on ticket count.

These are ordering semantics, not automatic transitions or fairness guarantees.

## Supported-asset assumptions

Production operation assumes the configured quote asset is the intended six-decimal Circle USDC deployment and the prize is an honest ERC-721. Decimals are deployment policy, not checked inside Raffle. A proxy can change after construction. Exact balance checks make many incompatible behaviors fail atomically, but Circle pause/blocklist can halt refunds and claims, and a malicious `balanceOf` can manufacture observations. A prize may become frozen/burned after escrow; buyer quote funds can fall back after 30 days, but the prize itself may remain unrecoverable.

## Operational and off-chain assumptions

- Deployment records must bind chain ID, block, code, Factory immutable values, owner/pending owner, treasury, quote decimals/policy, and Lens Factory.
- Public RPC data may be stale or rate-limited. Pinned block tests are reproducible evidence; latest-head tests are explicitly observational.
- Subgraphs may lag/reorg and must index ignored callbacks and all terminal transitions if the UI displays them.
- Metadata URIs and fetched content are hostile. Escaping, scheme allowlists, content limits, and no raw HTML/script execution are required off-chain.
- Keepers/participants must call permissionless finalizers. No autonomous on-chain clock exists.

## Out of scope / impossible guarantees

Testing cannot prove Pyth will reveal, Circle will remain available, Base will include a transaction promptly, an arbitrary token will report honestly, an arbitrary recipient will retain code/capability, or user metadata will remain benign. Passing internal tests cannot establish absence of undiscovered defects.

## Current primary references

- Pyth Entropy protocol design and provider reveal/censorship discussion: <https://docs.pyth.network/entropy/protocol-design>
- Pyth Entropy EVM integration: <https://docs.pyth.network/entropy/generate-random-numbers-evm>
- Pyth Entropy chain list and fee/provider guidance: <https://docs.pyth.network/entropy/chainlist>
- Circle official USDC contract addresses: <https://developers.circle.com/stablecoins/usdc-contract-addresses>
- Base official chain IDs and public RPC guidance: <https://docs.base.org/base-chain/quickstart/connecting-to-base>
