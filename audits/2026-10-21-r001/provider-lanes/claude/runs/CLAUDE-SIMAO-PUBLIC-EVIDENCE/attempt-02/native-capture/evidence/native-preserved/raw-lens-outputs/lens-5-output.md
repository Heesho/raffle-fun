# Lens 5: Cross-Chain and Asynchronous State (raffle.fun: Raffle clone + RaffleFactory)

**Scope:**
- `packages/contracts/src/Raffle.sol`
- `RaffleFactory.sol`
- `interfaces/IRaffle.sol`
- `interfaces/IRaffleFactory.sol`
- `libraries/RaffleConstants.sol`
- `DESIGN.md`

**Out-of-scope sources checked:**
- Chainlink 1.5.0: `VRFV2PlusWrapperConsumerBase.sol`, `IVRFV2PlusWrapper.sol`, `VRFV2PlusClient.sol`
- OpenZeppelin 5.6.1: `ReentrancyGuard.sol`, `ERC721.sol`, `ERC721Utils.sol`, `Clones.sol`

**Result:**
- **FINDINGs: 0.** In every ordering of the VRF request and callback, the raffle ends in a state where all claimants can collect (see the request/callback trace and the LastOut entries below).
- **LEADs: 3.**

## Leads

```
LEAD | contract: Raffle | function: releaseSponsorProceeds | bug_class: cross-asset-escrow-decoupling | group_key: Raffle | releaseSponsorProceeds | cross-asset-escrow-decoupling
smell: In NftWon, `_settleWinningTicket` allocates `sponsorProceeds = grossPot - protocolFee` and `protocolFees` (Raffle.sol:543-544, :554-555). `releaseSponsorProceeds` (:375-382) and `releaseProtocolFees` (:385-392) then pay both out without checking that the NFT can be delivered. The winner's prize has exactly one delivery path: an external `prizeToken.transferFrom` on a contract that DESIGN.md calls untrusted (:334-337). If that call reverts (collection-wide pause, per-address freeze, creator transfer-validator change, upgrade), redemption reverts atomically as designed. But NftWon is terminal (`enableRefunds` reverts at :292-293), and no branch turns an undeliverable prize into cash or refunds. Partial path: (1) 30,000 entries are sold, so the pot is 30,000 USDC; the reserve is met and the raffle resolves NftWon. (2) The prize collection's admin blocks transfers out of the raffle. (3) Anyone settles; 28,500 USDC is released to sponsorRecipient (:378-380) and 1,500 USDC to the treasury (:388-390). (4) Every `redeemWinningTicket` by the winning-ticket owner reverts at :334. The winning-ticket holder carries the whole loss: buyers funded a pot that was fully paid out for a prize that is never delivered.
unverified: (a) The intended trust model is ambiguous. DESIGN.md says "arbitrary prize contracts ... are untrusted" but also "Sponsor and treasury can claim independently after settlement", and IRaffle.sol:14-15 limits support to "honest, standards-compliant ERC-721s". (b) Adversary profit is not established. A sponsor who controls the freeze ends no better off than with an honest outcome, because the NFT leaves the sponsor either way. The exceptions are a sponsor who extorts the winner to unfreeze, or one who can seize the token through an admin function; in the seizure case no escrow ordering helps. So only a grief or an external-freeze path is established, not a profitable theft.
description: The NftWon USDC payout to sponsor and treasury and the NFT delivery to the winner settle independently, so a failed NFT delivery strands the winner after the pot is fully paid out. Gating `releaseSponsorProceeds` on `winnerRedeemed` when `status == NftWon` would link the two, at the cost of making the sponsor's payout depend on the winner acting.
```

```
LEAD | contract: Raffle | function: fulfillRandomWords | bug_class: vrf-result-preview-ticket-sniping | group_key: Raffle | fulfillRandomWords | vrf-result-preview-ticket-sniping
smell: The result is a pure function of the single VRF word: `winningEntry = word % totalEntries + 1` and NftWon/CashWon (Raffle.sol:518-521). Every ticket range is public (`ticketRange` :451-455). Tickets stay transferable while Drawing and after resolution: `_update` (:497-502) only screens destinations, and the NatSpec at :491 says tickets are transferable "in every lifecycle state". Once the oracle's fulfillment transaction, which carries the proof, is visible and before `RaffleResolved` is mined, a watcher can derive the winning ticket ID. The watcher can then fill any resting marketplace order selling that ticket, or sell known-losing tickets into resting bids, before holders can see the result on-chain. Ticket holders with resting orders lose through adverse selection.
unverified: (a) Whether Chainlink's Ethereum VRF nodes broadcast fulfillments through the public mempool or privately. (b) Whether the v2.5 coordinator's `fulfillRandomWords` accepts an observed proof from any caller, which would let a sniper deliver it and trade in one atomic transaction. The coordinator and wrapper sources are not vendored under packages/contracts. (c) Whether this goes beyond generic stale-order NFT MEV, given that the design deliberately keeps tickets transferable. The outcome cannot be re-rolled, because reverting a delivery does not change the proof. This is information leakage only; no protocol-held funds are at risk.
description: Information about the winner leaks before the state change while the tickets it prices are still tradable. Blocking ticket transfers while `status == Drawing` would close only the pre-inclusion window and conflicts with the bearer-claim design.
```

```
LEAD | contract: Raffle | function: releaseSponsorPrize | bug_class: config-time-only-destination-screen | group_key: Raffle | releaseSponsorPrize | config-time-only-destination-screen
smell: DESIGN.md requires "Never move assets between raffle clones." `sponsorRecipient` is screened only at creation: `RaffleFactory._validateCreateParams` checks the `isRaffle` mapping (RaffleFactory.sol:163-169), and `Raffle.initialize` calls `_isProtocolDestination` (Raffle.sol:193), which skips the `isRaffle` query for addresses with no code (:602). Clones are deployed with CREATE (OZ `Clones.clone`: `create(value, 0x09, 0x37)`), so each future raffle address depends only on the factory address and nonce. These addresses can be predicted, and anyone can advance the nonce through the permissionless `createRaffle`. A sponsorRecipient equal to a future clone address therefore passes both screens. After a later `createRaffle` registers a raffle at that address, `releaseSponsorPrize` (:402-405) transfers the prize NFT into that clone without a delivery-time screen, and no function can ever move it out. The USDC path for the same recipient, `_transferQuote`, re-screens at payout (:565) and reverts, which strands `sponsorProceeds` instead. The same skip for code-less addresses in `_update` (:498 → :602) lets a ticket be sent to a future clone address, where it later becomes unreachable.
unverified: No actor other than the sponsor (for sponsorRecipient) or the ticket owner or operator (for tickets) chooses these destinations. Pointing at the raffle's own address is caught (:599, `destination == address(this)`), and a recipient that is already a raffle is caught (RaffleFactory.sol:166; Raffle.sol:602-603). On current evidence this harms only the party who chose the address, so it is not reportable as a finding. It is listed because it is the one reachable state that violates DESIGN.md's cross-clone invariant, and because sibling payout sites screen inconsistently.
description: Re-running `_isProtocolDestination(recipient, address(prizeToken))` before Raffle.sol:404 would make the NFT payout behave like `_transferQuote`, but because sponsorRecipient is immutable the prize would still be stranded rather than moved.
```

## Public audit-evidence summaries

### Lens applicability

- **Single chain.** `packages/contracts/hardhat.config.ts` defines the networks `hardhatEthereum`, `sepolia` and `mainnet`, all with `chainType: "l1"`.
- **No cross-chain machinery.** There is no bridge, messaging layer, peer registry, or global state replicated across chains.
- **The one asynchronous boundary** is Chainlink VRF v2.5 native direct funding: `requestDraw` → wrapper → `rawFulfillRandomWords` → `fulfillRandomWords`.
- **The escrow and callback paths** are:
  - prize `safeTransferFrom` → `onERC721Received`
  - ticket `_safeMint` → recipient hook
  - native excess-refund `call`
  - two-step settlement (settle, then redeem or release)

### Request/callback trace (the single-chain equivalent of the two-chain trace)

The request at time t0 (Raffle.sol:252-259) sets:
- `status = Drawing`
- `drawRequestedAt = t0`
- `vrfRequestId = id`
- `_requestInFlight`, which is set before and cleared after the wrapper call (:254/:260)

| Ordering | Raffle state afterwards | Who can collect |
| --- | --- | --- |
| Callback with the matching id and one word lands at t < t0+2d | `winningEntry`, `resolvedAt`, NftWon/CashWon (:518-521); `enableRefunds` now reverts with InvalidStatus (:292-293) | Settle, redeem and release allocate every claim; solvent |
| No callback by t0+2d (wrapper-side failure, stall, deprecation) | `enableRefunds` at t ≥ t0+2d (:289-291) moves to Refunding with liability equal to the pot (:296-299) | Every ticket is refunded at 100%; prize returns to sponsorRecipient |
| Callback lands at t ≥ t0+2d, or after Refunding | Ignored (:511-515); no state change | Same as row 2 |
| Synchronous callback inside `requestDraw` | Ignored because `_requestInFlight` is set (:511); falls through to row 2 | Same as row 2 |
| Wrong request id or wrong word count | Ignored (:511) | Same as row 2 |

**Value lost in any ordering:** only the draw requester's native VRF fee (rows 2-5). This fee is never reimbursed by design.

**The time windows do not overlap:**
- **Callback vs refunds:** the callback needs `now < drawRequestedAt+2d` (:512, :464); refunds need `now >= callbackDeadline()` (:290-291).
- **Draw request vs refunds for an Active raffle with sales:** the request needs `now < endTime+2d` (:244-246); refunds need `now >= endTime+2d` (:286-287).
- **Sale vs draw request:** both switch at `endTime` (:216 vs :242).

### [Model: ...]

- **[Model: buyEntries]** (Raffle.sol:209-237)
  - The buyer pays `n*1e6` USDC (:223-224) and receives one ticket covering entries [T+1, T+n] (:226-235).
  - `totalEntries`, `ticketCount`, `_ticketRanges` and `unsettledPot += n*1e6` (:233) are all written before the untrusted `_safeMint` hook runs (:235), under `nonReentrant`.
- **[Model: requestDraw]** (:240-273)
  - The requester pays the native fee and receives nothing.
  - Only the excess `msg.value - paidPrice` is returned to `msg.sender`, never the contract balance (:262-270).
  - No USDC total moves.
- **[Model: fulfillRandomWords]** (:509-524)
  - Writes only `winningEntry`, `resolvedAt` and `status`.
  - Makes no transfer, loop or user call, which matches DESIGN's "Callback records result only".
- **[Model: enableRefunds]** (:276-301)
  - Moves `unsettledPot` into `remainingRefundLiability` one for one (:296-298).
- **[Model: _settleWinningTicket]** (:533-558)
  - Splits the pot `n*1e6` into a fee of `n*50,000` plus:
    - CashWon: cash `n*800,000` and sponsor `n*150,000`
    - NftWon: sponsor `n*950,000`
  - The split is exact with no dust, and `unsettledPot` is set to 0.
- **[Model: createRaffle → onERC721Received]** (RaffleFactory.sol:105-134; Raffle.sol:416-431)
  - The sponsor deposits the NFT.
  - The raffle moves from AwaitingPrize to Active only through the exact callback: prizeToken, tokenId, `from = sponsor`, `operator = factory`.
  - The factory then re-checks `ownerOf` and `status` (RaffleFactory.sol:129-134).

### [Why: ...]

- **[Why: Raffle.sol:258]** `paidPrice == quotedFee`.
  - Both values come from `calculateRequestPriceNative` in the same transaction (Raffle.sol:437; VRFV2PlusWrapperConsumerBase.sol:82).
  - The price is documented as based on `tx.gasprice` (IVRFV2PlusWrapper.sol:23-33), and the consumer base forwards exactly that value (:84).
  - The revert at :258 is defensive.
- **[Why: VRFV2PlusWrapperConsumerBase.sol:101-106]** Only the immutable wrapper can deliver randomness.
  - `i_vrfV2PlusWrapper` is an immutable stored in the implementation bytecode, so every clone shares it (:35).
- **[Why: Raffle.sol:518]** The modulo is safe.
  - `totalEntries > 0` is guaranteed by :243 and frozen after `endTime` (:215-216).
  - The result lies in [1, totalEntries] and fits in uint128.
- **[Why: Raffle.sol:521]** The NFT/cash outcome cannot change between request and callback.
  - `reserveEntries` is written once, in `initialize` (:203), and `totalEntries` is frozen.
- **[Why: OZ ReentrancyGuard.sol (5.6.1)]** The guard works in clones without a constructor.
  - It lives in a namespaced slot (`0x9b77…5f00`).
  - A clone starts at 0, which is not the ENTERED value.
- **[Why: RaffleFactory.sol:125 → :128]** No ticket can enter the new clone during creation.
  - `isRaffle[raffle] = true` is set before untrusted prize code runs.
  - So tickets from other raffles cannot be sent into the new clone at that point (Raffle.sol:602-603).
- **[Why: OZ Clones.sol `clone`]** Clone addresses are predictable, but nothing relies on them in advance.
  - CREATE makes the addresses predictable.
  - No protocol flow depends on a pre-computed address. Prize approvals go to the factory, and a USDC approval can be spent only by the approver's own `buyEntries` call (`safeTransferFrom(msg.sender, …)` at :224).

### [Defeat: ...]

- **[Defeat: fulfillRandomWords]** Effective guard: the five-condition ignore check (:510-516) plus the wrapper-only check (consumer base :101-106). The raffle cannot be re-rolled because there is no second request path.

  | Attempt | Outcome |
  | --- | --- |
  | Late callback at t = t0+2d | Ignored (:512) |
  | Callback after `enableRefunds` | Ignored by the status check |
  | Duplicate or stale request id | Ignored (:511); there is only one request per raffle, because `requestDraw` requires Active and Drawing never returns to Active |
  | Callback during the request | Ignored by `_requestInFlight` |
  | Forcing a revert or out-of-gas in the callback | No revert path; the handler uses on the order of tens of thousands of gas against the 300,000 limit (RaffleConstants.sol:39) |

- **[Defeat: requestDraw]** Excess-refund failure reverts only the caller's own transaction.

  | Attempt | Outcome |
  | --- | --- |
  | Call at `endTime - 1` | Reverts with RaffleNotEnded |
  | Call at `endTime + 2d` | Reverts with DrawRequestWindowExpired; refunds open in the same second |
  | Call with zero entries sold | Reverts with NoEntriesSold |
  | Underpayment | Reverts (:250) |
  | Reentry from the excess-refund recipient | Blocked by `nonReentrant`; unguarded ticket transfers are harmless; `rawFulfillRandomWords` is wrapper-only |
  | Blocking the draw | Not possible: anyone can call with a fee at or above the quote. The only blockers are a disabled wrapper or a quote that is too low, and both fall back to refunds |

- **[Defeat: enableRefunds]**

  | Attempt | Outcome |
  | --- | --- |
  | Drawing at t0+2d-1 | Reverts; the callback is still valid |
  | After resolution | Reverts with InvalidStatus, so NftWon and CashWon can never reach Refunding |
  | Empty raffle (sponsor may call at any time, others after `endTime`) racing a `buyEntries` | Whichever lands second reverts; no funds move in either order |

- **[Defeat: onERC721Received]** Guarded by the msg.sender, status and operator checks.

  | Attempt | Outcome |
  | --- | --- |
  | Direct call from a contract other than the prize token | Reverts (msg.sender check) |
  | Later deposit while Active | Reverts (status check) |
  | Operator other than the factory | Reverts (operator check) |
  | Malicious prize contract spoofing the callback and `ownerOf` | Possible, but this is a scam-prize trust issue outside this lens; IRaffle.sol:14-15 limits supported prizes to honest ERC-721s |

- **[Defeat: settleWinningTicket / redeemWinningTicket]** A failed delivery reverts every effect, including the inline settlement (:315, :334-337).

  | Attempt | Outcome |
  | --- | --- |
  | Ticket 0 or a nonexistent ticket | Its range is (0,0), which cannot contain `winningEntry ≥ 1` (:579-585) |
  | Wrong ticket | Exactly one range contains the winning entry |
  | Redemption by an approved operator | Reverts with NotTicketOwner (:321) |
  | Winning ticket burned before settlement | Impossible: tickets are burned only in Refunding or in redeem after settlement |

- **[Defeat: destination screens]**
  - **What the screens cover:** `_update` (:497-502), `_transferQuote` (:564-566) and `initialize` (:187-195) each reject the clone itself, the factory, USDC, the wrapper, the prize token, the implementation and registered raffles.
  - **Gap 1, code-less addresses:** the `isRaffle` lookup is skipped for addresses with no code (:602).
  - **Gap 2, NFT payouts:** `releaseSponsorPrize` (:404) and the NFT delivery in `redeemWinningTicket` (:334) do not screen the recipient at delivery time.
  - **Why the redeem delivery is still safe:** its recipient is `msg.sender`, which cannot be a clone, the factory, USDC, the wrapper or the prize token, because tickets can never be held by those addresses (:498).
  - **Why `releaseSponsorPrize` is not safe:** its recipient is the stored sponsorRecipient. This is LEAD 3.

### [LastOut: ...]

- **[LastOut: L3 NftWon]**
  - A pot of `n*1e6` pays `n*50,000` to the treasury and `n*950,000` to sponsorRecipient. Each is released once and zeroed (:378, :388).
  - After both releases, the balance holds only donations.
  - The NFT is delivered once (`prizeClaimed`, :330-331).
  - Conservation holds. Every claimant can collect as long as the prize contract allows the outgoing transfer (LEAD 1).
- **[LastOut: L3 CashWon]**
  - The treasury gets `n*50,000`, the winner `n*800,000` (zeroed at :341) and the sponsor `n*150,000`; together they equal the pot.
  - The prize returns to sponsorRecipient once (:400-405).
  - A winner whose address USDC has blacklisted can move the ticket to another address and redeem from there.
- **[LastOut: L4/L5 Refunding]**
  - `remainingRefundLiability = n*1e6` (:298).
  - Each burned ticket subtracts exactly `(last - first + 1) * 1e6` (:363-368).
  - Ranges do not overlap and together cover [1, n]. A duplicate ticket ID reverts at the second `ownerOf`, because the first instance was already burned.
  - The last refunder therefore brings the liability to exactly 0 and is paid in full. The prize returns to sponsorRecipient.
- **[LastOut: L6 Empty]**
  - Liability is 0 and the prize is returned. Nothing is stranded.
- **[LastOut: native ETH]**
  - The raffle holds no native balance between transactions, because the excess is returned (:262-270).
  - ETH forced into the contract is untracked and harmless.
  - The only amount never reimbursed is the requester's VRF fee, which is by design.

### Saturation sweep

- **LEAD 1 pattern (one side is paid while the matching delivery can fail):**

  | Site | Status |
  | --- | --- |
  | NftWon: USDC payouts vs NFT delivery | LEAD 1 |
  | CashWon: NFT to sponsor vs USDC to winner | Independent; a failure harms only the sponsor |
  | Refunding: NFT to sponsor vs ticket refunds | Independent; harms only the sponsor |
  | VRF fee vs callback | Affects only the requester; refunds are the fallback |
  | `buyEntries`: USDC in vs ticket mint | Atomic |
  | `createRaffle`: NFT in vs Active status | Atomic and re-checked |

  No second instance has a third-party victim.

- **LEAD 2 pattern (an async outcome is visible while the claims it prices are tradable):**
  - Only ticket transfers during Drawing and after resolution.
  - `settleWinningTicket` and `requestDraw` gain nothing from seeing the result early.

- **LEAD 3 pattern (a destination screened only at configuration time, or skipped for code-less addresses):**

  | Site | Status |
  | --- | --- |
  | sponsorRecipient, NFT payout | LEAD 3 |
  | sponsorRecipient, USDC payout | Reverts, so the funds are stranded |
  | `protocolTreasury` | Factory immutable; a treasury set to a future clone address would be a deployer misconfiguration |
  | Tickets | `_update`, :498 |
  | Winner, refunder and requester payouts | Recipient is `msg.sender`, so not reachable |

### Assessed and not reported

| Candidate | Why it is not reported |
| --- | --- |
| Immutable wrapper with no liveness check in `createRaffle` (RaffleFactory.sol:97-148) | If Chainlink disables or migrates the wrapper, every raffle falls back to refunds at `endTime+2d` or `drawRequestedAt+2d`. That costs time, not funds, and DESIGN.md treats the wrapper as a trusted dependency |
| `getVrfRequestPrice()` under-quotes under `eth_call` with gas price 0 (documented at IRaffle.sol:360 and IVRFV2PlusWrapper.sol:27-28) | The requester's own transaction reverts, and any overpayment is refunded |
| Late-fulfillment boundary censorship (delaying a proof past t0+2d to force refunds) | Requires a roughly two-day VRF stall plus censorship at the block-builder level |
| Reorg of the request block | 30 confirmations (RaffleConstants.sol:42) on L1 proof-of-stake |
| Airdrops, migrations or holder-only actions for the escrowed NFT | These accrue to the clone, which has no sweep; accepted by design (Raffle.sol:410-411 NatSpec; money map "Untracked") |
| Requester whose excess-refund recipient reverts | Harms only the requester |
