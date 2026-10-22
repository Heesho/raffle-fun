
---

## Step 5: Manual review areas

Each area was reviewed by searching the code for the relevant patterns (Appendix C greps), then by reading the code paths. Conclusions that rest on behavior are backed by executable tests.

### 5.1 Privacy

| Question | Answer | Evidence |
|---|---|---|
| Are secrets stored on-chain? | No. All state is public: ticket owners and ranges, reserve, pot, recipients. There is no hidden information to protect. | Storage layout (Appendix D) |
| Is commit-reveal needed? | Not for user inputs; unpredictability comes from VRF. **However**, the VRF output is public in the pending fulfillment transaction before it takes effect, and tickets stay tradable meanwhile. This is a reveal-before-commit window. | TOB‑S6‑2, PoC `test_G3` |
| Are privacy assumptions documented? | Partly. The natspec documents bearer tickets but not the reveal window. | `Raffle.sol:22-26`, `IRaffle.sol:12-13` |

### 5.2 Front-running and ordering

| Pattern | Exposure | Assessment |
|---|---|---|
| VRF fulfillment reveal | Pending `fulfillRandomWords` calldata determines `winningEntry = word % totalEntries + 1` (`Raffle.sol:518`). Tickets are transferable during `Drawing` (`Raffle.sol:497-502`). | **TOB‑S6‑2.** A searcher can buy listed winning tickets, or dump losing ones into standing bids, ahead of or bundled with the callback. |
| Sponsor cancellation of an empty raffle | The sponsor's `enableRefunds()` can be ordered before the first `buyEntries` (`Raffle.sol:280-284`) | The buyer's transaction reverts (`InvalidStatus`) and no funds are lost. Spec gap: **TOB‑S6‑4**. |
| `requestDraw` race | Anyone can request; the first succeeds, later ones revert, and `msg.value` is returned by the revert | No value at risk; the randomness cannot be influenced (VRF, 30 confirmations). |
| `requestDraw` vs `enableRefunds`, and callback vs `enableRefunds`, at deadlines | Windows are half-open and complementary | No overlapping instant (tests A2–A4; mutants M01, M02, M08 killed). |
| Last-second purchases near `endTime` | Any buyer, including the sponsor, can push `totalEntries` over `reserveEntries` and switch the outcome type (NFT vs. 80% cash) | By design; buyers cannot pin the outcome type. A sponsor who shill-buys to cross the reserve gets 95% of its own purchase back and moves the raffle from the 15% to the 95% sponsor share. Disclose this in the UI (informational, Section 5.5 notes). |
| Settlement or release front-running | Permissionless, deterministic, fixed recipients | No impact. |
| Price or slippage | Fixed 1 USDC per entry; no AMM; VRF fee priced at `tx.gasprice` and checked twice (`Raffle.sol:249-258`) | No slippage exposure. |

### 5.3 Cryptography and randomness

| Check | Result |
|---|---|
| Weak randomness (`block.timestamp`, `blockhash`, `prevrandao`) | None used for randomness. `block.timestamp` is used only for deadlines (custom check C8 inventory: `buyEntries`, `createRaffle`, `enableRefunds`, `fulfillRandomWords`, `requestDraw`). |
| VRF usage | Chainlink VRF v2.5 wrapper, native payment, `requestConfirmations = 30`, `callbackGasLimit = 300,000`, 1 word (`RaffleConstants.sol:39-42`). Only the wrapper can call back (`VRFV2PlusWrapperConsumerBase.sol:101-107`, test C3). There is one request per raffle and no re-request or cancel path. The callback never reverts (tests C1, C2; fuzzing property P3). |
| Modulo bias | `randomWords[0] % totalEntries` with `totalEntries ≤ 2^128−1`: the bias is at most `totalEntries / 2^256 ≤ 2^-128`, which is negligible. |
| Callback gas | 6,052 gas with warm storage (test C4) and **23,652 gas with the raffle's account and storage cold** (`vm.cool`, probe `tob-s6-artifacts/gas-probe/test/GasProbe.t.sol`). That is under 8% of the 300,000 `callbackGasLimit`, so an out-of-gas callback cannot strand a draw. |
| Signatures / `ecrecover` / hashing of user data | None present. |
| Address predictability | Clones use `CREATE`, so addresses are a function of the factory nonce. This enables TOB‑S6‑1. |

### 5.4 DeFi interactions

| Check | Result |
|---|---|
| Oracle manipulation | No price oracle is consumed. The wrapper's internal LINK/ETH pricing affects only the fee the requester pays, and `msg.value ≥ price` is enforced. |
| Flash loans | Not exploitable. Entries can be bought only while `now < endTime`, and every payout path requires `now ≥ endTime` plus a VRF callback in a later block, or a deadline. A flash-loaned position cannot be exited in the same transaction, and nothing is priced by balances. |
| Protocol assumptions: USDC | Trusted. Pause only delays (refunds have no deadline; the draw needs no USDC). Blocklisting: tickets can be re-routed, but immutable recipients cannot (TOB‑S6‑5). Exact-amount transfers are assumed (documented). |
| Protocol assumptions: VRF wrapper | Trusted. If the wrapper is disabled, unfunded, or late, liveness falls back to refunds after the deadlines (tests A3, A4). |
| Protocol assumptions: prize contracts | Untrusted per `DESIGN.md`, yet escrow and delivery are verified only through the prize's own `ownerOf` and receiver-hook behavior (TOB‑S6‑3, PoCs `test_G4` and `test_H5`). |
| Cross-raffle isolation | Holds for every path except configurations that target not-yet-deployed clone addresses (TOB‑S6‑1). |

### 5.5 Detailed findings

#### TOB‑S6‑1: Protocol-destination screening is time-of-check and skips code-less addresses; prize-NFT outflows are never re-screened

| Severity | Difficulty | Type | Targets |
|---|---|---|---|
| Low | High | Data Validation | `Raffle.sol:593-605` (`_isProtocolDestination`), `Raffle.sol:395-407` (`releaseSponsorPrize`), `Raffle.sol:329-337` (NFT redemption), `Raffle.sol:176-206` (`initialize`), `Raffle.sol:497-502` (`_update`), `RaffleFactory.sol:154-179` |

**Description.** `_isProtocolDestination` consults the factory registry only when the destination already has code:

```solidity
// Raffle.sol:598-604
unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
    || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_
    || destination == canonicalFactory.raffleImplementation();
if (!unsafeDestination && destination.code.length != 0) {
    unsafeDestination = canonicalFactory.isRaffle(destination);
}
```

Clones are deployed with `CREATE` (`Clones.clone`, `RaffleFactory.sol:106`), so every future raffle address is a known function of the factory nonce. Consequences:

- A `sponsorRecipient`, or a ticket recipient, equal to a *future* clone address passes the checks in `RaffleFactory._validateCreateParams`, `Raffle.initialize`, and `Raffle._update`.
- Once a raffle is deployed at that address, the two payout paths diverge:
  - **Quote token:** `_transferQuote` (`Raffle.sol:564-567`) re-screens at payout time and reverts with `InvalidQuoteDestination`. Because `sponsorRecipient` is immutable, the sponsor's share (15% or 95% of gross) is stranded forever in the raffle.
  - **Prize NFT:** `releaseSponsorPrize` (and NFT redemption) do **not** re-screen. `releaseSponsorPrize` moves the prize into the other raffle clone using `transferFrom`, so no receiver hook runs. The NFT then sits outside that clone's accounting with no rescue path.

This violates `DESIGN.md` ("Never move assets between raffle clones"). It is also internally inconsistent: custom Slither check C3 flags that both prize outflow sites lack the runtime screen that C2 confirms for every USDC outflow. In the ticket variant, a winning ticket minted to a future clone address can never be redeemed. In `NftWon` the prize is then frozen while the sponsor and treasury are paid.

Mutation note: removing the runtime USDC screen (mutant M10) is unobservable to the whole specification suite. The screen matters *only* in this scenario, and PoC `test_G1` is the only test that detects M10.

**Deployment variant (same root cause).** The factory constructor screens `protocolTreasury` against the implementation, but not against future clone addresses (`RaffleFactory.sol:80-90`). If the treasury equals the factory's first clone address, every `createRaffle` deploys the clone *at the treasury address*, and that clone's `initialize` rejects `protocolTreasury == address(this)`. The `CREATE` is rolled back and the nonce never advances, so the factory is **permanently unusable** (probe `test_P1_treasuryAtFutureCloneAddressBricksFactory` in `tob-s6-artifacts/gas-probe/test/Probes.t.sol`, passing). This needs a deployer misconfiguration; the deployer is trusted, and deployment tooling should assert it.

**Exploit scenario.** A sponsor's integration (for example, a "raffle-of-raffles" contract or a script that pre-computes the next raffle address to use as its proceeds sink) sets `sponsorRecipient` to the factory's next `CREATE` address. Someone creates the next raffle. When the first raffle ends with the reserve missed, anyone calls `releaseSponsorPrize()`, and the sponsor's NFT is transferred into the unrelated raffle clone, unrecoverably. `releaseSponsorProceeds()` reverts forever. PoCs: `test_G1_PoC_futureCloneSponsorRecipient_movesPrizeIntoAnotherClone` and `test_G2_PoC_ticketMintedToFutureCloneAddressIsStranded`, both passing. Only the party that chose the address loses, so difficulty is High and severity Low; the specification invariant is still broken.

**Recommendations.**
- *Short term:* apply `_isProtocolDestination` at transfer time to every outflow, including `releaseSponsorPrize` and the NFT branch of `redeemWinningTicket`, failing closed. The prize then stays attributable to its own raffle instead of entering another clone; the time-of-use screen is what catches addresses that gained code after configuration. Decide explicitly whether an immutable recipient that later becomes invalid gets a recovery path; today none exists. In the deployment script, assert that `protocolTreasury` is not a predicted factory `CREATE` address.
- *Long term:* deploy clones with `CREATE2` using a salt bound to `msg.sender` and the raffle id, so one party cannot accidentally collide with another's recipient. Document that recipients must not be counterfactual factory addresses. Add a property test for P27 that includes predicted addresses.

#### TOB‑S6‑2: Tickets remain transferable while the VRF result is pending, enabling front-running of the fulfillment

| Severity | Difficulty | Type | Targets |
|---|---|---|---|
| Low | Medium | Timing | `Raffle.sol:497-502` (`_update`), `Raffle.sol:509-524` (`fulfillRandomWords`), `Raffle.sol:240-273` |

**Description.** After `requestDraw`, the winning entry is a pure function of the random word (`Raffle.sol:518`). The coordinator's fulfillment transaction carries the VRF proof from which that word is derived, so the winning ticket can be computed before the callback is mined. `_update` allows transfers in every state, including `Drawing`, as `DESIGN.md` and the natspec intend.

Anyone watching the mempool can therefore:
- buy a winning ticket listed on a marketplace, by ordering a purchase before (or bundling it with) the fulfillment; or
- sell losing tickets into standing bids or collection offers before the result is visible.

This is the scenario Chainlink's VRF security guidance warns about ("don't accept bids/bets/inputs after you have made a randomness request").

**Exploit scenario.** Alice lists her ticket for 0.5 ETH while the draw is pending. A searcher sees the fulfillment transaction, computes `word % totalEntries + 1`, recognizes Alice's ticket as the winner, buys it ahead of the callback, and redeems the NFT. PoC: `test_G3_PoC_vrfRevealFrontRun_buysListedWinningTicketBeforeCallback`, passing.

**Recommendations.**
- *Short term:* in `_update`, reject non-mint, non-burn transfers while `status == Status.Drawing`. Optionally lock from `endTime` until resolution or the refund timeout. If transferability during the draw must stay (per `DESIGN.md`), document the reveal window prominently and have the frontend warn about, or cancel, ticket listings before `endTime`.
- *Long term:* add a property such as "no ticket ownership change between request and resolution" if the lock is adopted.

#### TOB‑S6‑3: `NftWon` payouts do not depend on the prize being deliverable; untrusted prize contracts can pay the sponsor while denying the winner

| Severity | Difficulty | Type | Targets |
|---|---|---|---|
| Medium | High | Undefined Behavior (design) | `Raffle.sol:533-558` (`_settleWinningTicket`), `Raffle.sol:375-392` (releases), `Raffle.sol:329-337` (delivery), `Raffle.sol:416-431` (escrow hook), `RaffleFactory.sol:127-134,171-177` |

**Description.** `DESIGN.md` makes arbitrary prize contracts untrusted, but the escrow and delivery checks are self-reported by the prize:
- the factory checks ERC‑165, the receiver hook, and `ownerOf`;
- the raffle checks `ownerOf` after `transferFrom`.

Settlement (permissionless, storage-only) allocates 95% to the sponsor and 5% to the treasury in `NftWon`, and both can be released immediately, whether or not the NFT can actually reach the winner. Two failure modes follow:

1. *Admin-controlled collections.* A pausable or blocklisting collection, an ERC721‑C transfer validator whose policy changes after escrow, an upgradeable collection, or an expiring asset (e.g., an ENS name) can block delivery after resolution. Redemption reverts atomically, as specified, but the winner has no fallback while the sponsor has been paid. PoC: `test_G4_PoC_frozenPrizeCollection_sponsorPaidWinnerUnpaid`.
2. *Lying contracts.* A malicious "prize" can fake both escrow and delivery. The raffle accepts it and sells entries, the winner "redeems" nothing, and the sponsor collects 95% of the pot. PoC: `test_H5_PoC_lyingPrizeFakesEscrowAndDelivery`.

The second mode cannot be fully prevented on-chain for arbitrary contracts. The first can be mitigated.

**Exploit scenario.** A sponsor deploys their own pausable ERC‑721 collection and raffles a token from it with a low reserve. After the reserve is met and the draw resolves to `NftWon`, the sponsor pauses transfers, calls `settleWinningTicket` and `releaseSponsorProceeds`, and keeps 95% of the pot. The winner's `redeemWinningTicket` reverts for as long as the collection stays paused.

**Recommendations.**
- *Short term:* surface prize-contract risk in the UI (admin roles, pausability, upgradeability, transfer validators, expiry). Document in `DESIGN.md` that buyers carry prize-contract trust.
- *Long term:* gate the `NftWon` sponsor share on delivery. For example, make `releaseSponsorProceeds` in `NftWon` require `winnerRedeemed`, or a permissionless "deliver to current winning-ticket owner" step. If delivery is impossible for a long timeout, give the winner a cash alternative (such as the sponsor share). Alternatively, restrict prizes to a list fixed at factory deployment; this keeps "no administrator".

#### TOB‑S6‑4: Empty-raffle cancellation paths are not in `DESIGN.md`

| Severity | Difficulty | Type | Targets |
|---|---|---|---|
| Informational | Low | Access Controls / Specification | `Raffle.sol:279-284` |

**Description.** For an `Active` raffle with zero entries, `enableRefunds()` allows two things the specification does not describe:
- the **sponsor** may move the raffle to `Refunding` at any time, before `endTime`;
- **anyone** may do so from `endTime`, not from a deadline.

`DESIGN.md` says "No administrator…" and "Refunds open at deadline". The behavior is documented only in `IRaffle` natspec (`IRaffle.sol:322-324`). No funds are at risk, but the sponsor holds a unilateral cancel right and can pre-empt the first purchase (PoC `test_G5`).

**Recommendation.** Either add both paths to `DESIGN.md` (the empty-raffle rule and the sponsor cancel right), or remove the sponsor privilege so empty raffles close only at `endTime`.

#### TOB‑S6‑5: Immutable payout recipients have no recovery path from USDC blocklisting

| Severity | Difficulty | Type | Targets |
|---|---|---|---|
| Informational | High | Configuration | `Raffle.sol:375-392`, `RaffleFactory.sol:39` |

**Description.** `sponsorRecipient` (per raffle) and `protocolTreasury` (for every raffle the factory creates) are immutable. If USDC blocklists either one, its claims are stranded permanently. A blocklisted treasury strands fees across *all* raffles. Claims stay independent, as specified (test `D3`), and ticket holders can route around blocklists because tickets are bearer claims.

**Recommendation.** Document the risk. Consider letting the *recipient itself* redirect its own pending claim (a `msg.sender == recipient` pull to a destination of its choice); this adds no administrator.

#### TOB‑S6‑6: Value sent outside protocol flows is permanently stranded

| Severity | Difficulty | Type | Targets |
|---|---|---|---|
| Informational | Low | Data Validation | `Raffle.sol:171-173`, `Raffle.sol:409-431`, `Raffle.sol:468-470` |

**Description.** `receive()` rejects ETH, but ETH can be forced in through `SELFDESTRUCT` or as a coinbase recipient. Direct USDC transfers and NFTs sent with unsafe `transferFrom` are not tracked. There is no rescue path (natspec acknowledges it for NFTs; PoC `test_G6`). `getBalance()` exposes forced ETH.

**Recommendation.** Document this. Optionally, add a permissionless sweep of USDC surplus (`balanceOf − accountedQuoteBalance()`) to the treasury.

#### TOB‑S6‑7: Security tooling referenced by the package is absent

| Severity | Difficulty | Type | Targets |
|---|---|---|---|
| Informational | N/A | Testing | `package.json:15,22,23`, `foundry.toml:3-6`, `remappings.txt:2` |

**Description.** The package refers to several things that do not exist:
- `slither.config.json` (`pnpm slither`);
- `test/foundry` and `test/hardhat`;
- `scripts/check-coverage.mjs`;
- `ignition/modules/RaffleFun.ts`;
- `lib/forge-std`.

None is present, and `DESIGN.md` states that no tests are provided. `pnpm slither` points at a configuration file that does not exist, so no triage or filtering configuration is under version control, and the in-source suppression of S1‑01 has no recorded rationale.

**Recommendation.**
- Commit the harness from this report (properties, Echidna config, PoCs) and a `slither.config.json` with documented triage.
- Run Slither, Echidna, and the invariant suite in CI.
- Treat a surviving mutant like M10 as a signal to add targeted tests.

#### TOB‑S6‑8: Storage-based `ReentrancyGuard` on a Cancun target

| Severity | Difficulty | Type | Targets |
|---|---|---|---|
| Informational | N/A | Gas / Maintainability | `Raffle.sol:12,28`, `RaffleFactory.sol:7,21` |

**Description.** OpenZeppelin 5.5+ marks `ReentrancyGuard` as deprecated in favor of `ReentrancyGuardTransient` (`ReentrancyGuard.sol:27-29`). Constructors do not run for clones, so the guard slot starts at 0. Each clone's first guarded call pays a zero-to-nonzero `SSTORE` (about 22k gas, with no refund because the original value is 0). Later calls pay a cold `SLOAD`/`SSTORE` pair, a few thousand gas net of the capped refund, which `TSTORE`/`TLOAD` (≈100 gas each) would avoid. Correctness is unaffected (tests F1 and F2).

**Recommendation.** Switch to `ReentrancyGuardTransient` (EIP‑1153 is available on the `cancun` target).

**Other observations (not findings).**
- Ticket `tokenURI` is empty, and `name`/`symbol` are shared by every raffle. Wallets cannot tell raffles apart, so users must verify `factory.isRaffle(address)`.
- Deployment tooling must verify the canonical USDC and wrapper addresses (the constructor checks only code and decimals, `RaffleFactory.sol:58-62`).
- The sponsor can steer the outcome type by buying across the reserve (Section 5.2).
