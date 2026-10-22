## `redeemWinningTicket` in packages/contracts/src/Raffle.sol (L309-L346)

Citation key. A bare `Lnnn` is `packages/contracts/src/Raffle.sol`. Other files:
`IRaffle.sol` and `IRaffleFactory.sol` = `packages/contracts/src/interfaces/`; `RaffleFactory.sol` and
`RaffleConstants.sol` = `packages/contracts/src/` (`libraries/` for the latter); `ERC721.sol` (OZ v5.6.0),
`ERC721Utils.sol`, `IERC721.sol`, `SafeERC20.sol`, `ReentrancyGuard.sol`, `Math.sol`, `Clones.sol` =
`packages/contracts/node_modules/@openzeppelin/contracts/...`; `VRFV2PlusWrapperConsumerBase.sol` =
`packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/`. Compiler is solc 0.8.36 with EVM
`cancun` (`foundry.toml` L7-L8). No test directory exists under `packages/contracts/`.

**Purpose:** This is the terminal payout step of a resolved raffle. Three structural facts make it the main
prize path:

- While `status == NftWon`, it is the only code that moves the escrowed prize NFT. The other prize mover,
  `releaseSponsorPrize`, rejects every status except `CashWon` and `Refunding` (L397).
- It is the only code that pays out `winnerProceeds`. That variable is written only at L548 (allocated in
  settlement) and L341 (zeroed here). The only other reader is the view `accountedQuoteBalance` (L469).
- It is the only writer of `winnerRedeemed` and `winnerRecipient` (L323-L324). No other assignment to
  either variable exists in Raffle.sol.

If nobody has called `settleWinningTicket` yet, the function also settles inline (L314-L315). That lets the
ticket owner settle and redeem in one transaction (IRaffle.sol L334-L335). Without this function, an `NftWon`
prize has no way out of the clone, and a `CashWon` 80% allocation stays booked forever.

The design requirement comes from DESIGN.md L2 and IRaffle.sol L333-L335. Only the current ticket owner may
redeem. The burn is atomic with delivery. A failed delivery reverts every effect.

---

**Inputs & Assumptions:**

- `ticketId` (uint256): chosen by the caller. Trust: **untrusted**. Which check validates it depends on
  settlement state:
  - Not yet settled: range containment, through the inline settlement (L315 → L538 → L580-L584).
  - Already settled: equality with the stored `winningTicketId` (L316-L317).
- `msg.sender`: Trust: **untrusted**. It must equal the ticket's current ERC-721 owner (L321). The function
  uses `msg.sender` directly, and Raffle.sol does not override `_msgSender`, so there is no meta-transaction
  path.
- Implicit storage reads:
  - Directly in the body: `winnerRedeemed` (L310), `status` (L311), `settlementComplete` (L314),
    `winningTicketId` (L316), ERC-721 `_owners[ticketId]` (L320 → ERC721.sol L147), `prizeClaimed`
    (L330), `prizeToken` (L332, L334, L335), `prizeTokenId` (L333), `winnerProceeds` (L339).
  - Inside the inline settlement: `winningEntry` (L581), `_ticketRanges[ticketId]` (L452-L454),
    `unsettledPot` (L539).
  - Inside `_transferQuote`: the immutables `factory`, `quoteToken` and `i_vrfV2PlusWrapper` (L598-L600).
- Implicit external reads:
  - NFT branch: `prizeToken.ownerOf` (L335).
  - Cash branch: `factory.raffleImplementation()` (L601) and `factory.isRaffle(winner)` (L603).
- Clock: none. The function never reads `block.timestamp`. Raffle.sol has no redemption deadline, and no
  other function reads `winnerRedeemed`.
- Value: the function is non-payable.

Preconditions, and what establishes each:

1. **`status` is `NftWon` or `CashWon` and stays that way for the whole call.**
   - L312 checks it.
   - It cannot change because no status writer starts from `NftWon` or `CashWon`:

     | Writer | Write | Required starting state |
     | --- | --- | --- |
     | constructor | L165 | n/a (constructor) |
     | `initialize` | L205 | single use, L177/L179 |
     | `requestDraw` | L252 | `Active`, L241 |
     | `enableRefunds` | L299 | `Active` or `Drawing`, L279-L294 |
     | `onERC721Received` | L428 | `AwaitingPrize`, L422 |
     | `fulfillRandomWords` | L521 | `Drawing`, L511 |

2. **`winningEntry` lies in `[1, totalEntries]`.**
   - L518 computes it as `% totalEntries + 1`, in the same branch that sets `NftWon`/`CashWon` (L521).
   - `totalEntries > 0` is guaranteed by `requestDraw` (L243).
   - `totalEntries` cannot change after `endTime` (L216), and it only grows while `Active` (L215).
3. **Exactly one ticket range contains `winningEntry`.** This is established by `buyEntries`:
   - Each ticket gets `[totalEntries+1, totalEntries+entryCount]`, and then `totalEntries` advances
     (L226-L232).
   - Ticket IDs start at 1 (L228), and `entryCount ≥ 1` (L218).
   - IDs that were never minted, including 0, read as `(0,0)` (L452-L454). They cannot contain an entry
     `≥ 1`.
4. **The winning ticket still exists while `winnerRedeemed == false`.**
   - `_burn` is called in two places only: L325 (here, after L324 sets `winnerRedeemed`) and L364
     (`refundTickets`, which is gated to `Refunding` at L350).
   - So in `NftWon`/`CashWon`, only a successful redemption burns the winning ticket.
5. **The clone holds the prize NFT (NFT branch).** Only RaffleFactory.sol L128-L134 establishes this, once,
   at creation. That check is answered by the prize contract itself (L129). Nothing in Raffle stops the
   prize contract from moving the token later. **Nothing found.**
6. **The clone holds at least `winnerProceeds` USDC (cash branch).** Nothing checks this on-chain.
   - `buyEntries` credits the nominal `grossAmount` (L223, L233) after `safeTransferFrom` (L224).
   - That nominal credit equals the actual balance increase only under the fee-free USDC model (L560-L561;
     IRaffle.sol L13-L14).
   - **Nothing found** as an on-chain check.

---

**Outputs & Effects:**

- **Return value `cashAmount`:**
  - `CashWon`: `winnerProceeds` as read at L339.
  - `NftWon`: 0. The named return is never assigned on that path, and L315 discards the value returned by
    `_settleWinningTicket`.
- **Storage writes, in execution order:**
  1. Inline settlement only (L315 → L548-L555):
     - `winnerProceeds` (`CashWon` only, L548)
     - `settlementComplete = true` (L551)
     - `winningTicketId = ticketId` (L552)
     - `unsettledPot = 0` (L553)
     - `sponsorProceeds` (L554)
     - `protocolFees` (L555)
  2. `winnerRecipient = winner` (L323), then `winnerRedeemed = true` (L324).
  3. Ticket ledger, via `_burn` (L325):
     - `_tokenApprovals[ticketId] = 0` (ERC721.sol L227 → L398)
     - `_balances[winner] -= 1`, unchecked (ERC721.sol L229-L231)
     - `_owners[ticketId] = 0` (ERC721.sol L240)
     - `_ticketRanges[ticketId]` is not cleared (L138 comment).
  4. `NftWon`: `prizeClaimed = true` (L331). `CashWon`: `winnerProceeds = 0` (L341).
  5. Reentrancy guard slot: set to ENTERED on entry and back to NOT_ENTERED on exit (ReentrancyGuard.sol
     L99, L105).
- **Events, in order:**
  1. `WinningTicketSettled(ticketId, msg.sender, result, cashAmount, protocolFee, sponsorAmount)` (L557).
     Inline settlement only; the settler recorded is the redeemer.
  2. `Transfer(winner, address(0), ticketId)` from this clone (ERC721.sol L242).
  3. Whatever the prize contract or USDC emits.
  4. `WinningTicketRedeemed(ticketId, winner, result, cashAmount, deliveredPrizeToken,
     deliveredPrizeTokenId)` (L345). For `CashWon` the two prize fields are zero (L327-L328), which matches
     IRaffle.sol L136-L137.
- **External interactions:**
  - `NftWon`:
    - CALL `prizeToken.transferFrom(address(this), winner, prizeTokenId)` (L334). No value and no gas cap
      (no `{gas: ...}` option on the line).
    - Then STATICCALL `prizeToken.ownerOf(prizeTokenId)` (L335). `ownerOf` is `view` in IERC721.sol L39.
  - `CashWon`:
    - STATICCALL `factory.raffleImplementation()` (L601). Skipped if an earlier comparison in L599-L600
      already matched.
    - STATICCALL `factory.isRaffle(winner)` (L603), only when `winner.code.length != 0` (L602).
    - CALL `quoteToken.transfer(winner, cashAmount)` with all remaining gas (SafeERC20.sol L184).
- **Postconditions on success:**
  - Always: `winnerRedeemed` is true, `winnerRecipient == msg.sender`, `settlementComplete` is true,
    `winningTicketId == ticketId`, and ticket `ticketId` no longer exists.
  - `NftWon`: `prizeClaimed` is true, and the prize contract's `ownerOf` returned `winner` at L335.
  - `CashWon`: `winnerProceeds == 0`, and the USDC call reported success.

---

**Block-by-Block:**

```solidity
// L309
function redeemWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
```
- **What:** External entry point, wrapped in the clone-wide reentrancy guard.
- **Why here:** The guard spans both delivery calls (L334, L342) and the inline settlement.
- **Assumes:**
  - The guard slot lives in the clone's own storage. Clones share code but not storage (L24, L152).
  - A fresh clone's slot value of 0 counts as not-entered. `_reentrancyGuardEntered` compares against
    ENTERED = 2 (ReentrancyGuard.sol L51, L113).
- **Establishes:** For the whole body, every other `nonReentrant` function of this clone reverts (L212, L240,
  L276, L304, L349, L375, L385, L395), and this function cannot re-enter itself.
- **Depended on by:** The effects-before-interactions ordering below is a second layer. The guard alone is
  what stops re-entry during L334 from reaching a lifecycle mutator.

```solidity
// L310
if (winnerRedeemed) revert WinningTicketAlreadyRedeemed();
```
- **What:** One-shot gate.
- **Why here:** The cheapest rejection of a repeat redemption, before any settlement work.
- **Assumes:** `winnerRedeemed` is written only at L324.
- **Establishes:** No earlier redemption in this clone succeeded.
- **Depended on by:**
  - Precondition 4. Because the winning ticket still exists, L320 cannot revert for the winning ID.
  - L330 and L340 are unreachable as reverts because of this gate (see below).

```solidity
// L311-L312
Status result = status;
if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);
```
- **What:** Caches the lifecycle state and restricts it to the two outcome states.
- **Why here:** It runs before settlement, which makes the inline settlement's own status check (L535-L536)
  redundant.
- **Assumes:** `NftWon` and `CashWon` are terminal (Precondition 1).
- **Establishes:**
  - `result == status` for the entire call, including while external calls run.
  - Exactly one delivery branch runs. The `else` at L338 means `CashWon`, because only two values pass L312.
- **Depended on by:** The branch at L329 and the event field at L345.
- On the implementation instance, `status == Refunding` (constructor L165). Calls there always revert here.

```solidity
// L314-L318
if (!settlementComplete) {
    _settleWinningTicket(ticketId);
} else if (ticketId != winningTicketId) {
    revert WinningTicketMismatch(ticketId, winningTicketId);
}
```
- **What:** Proves `ticketId` is the winning ticket. Either it settles now, or it matches the earlier
  settlement.
- **Why here:** Before the ownership read, so a non-winning ID is rejected no matter who owns it. Before any
  effect.
- **Assumes:** Precondition 3 (a unique winning ticket). That uniqueness is why both branches accept the
  same single ID.
- **Establishes:**
  - `settlementComplete == true`.
  - `winningTicketId == ticketId`.
  - `_ticketRanges[ticketId]` contains `winningEntry`.
  - On the inline branch, all of `unsettledPot` is allocated (L539-L555). See the callee section.
- **Depended on by:**
  - L320, which needs `ticketId` to exist.
  - The `winnerRedeemed ⇒ settlementComplete` coupling.
  - L339, which needs `winnerProceeds` populated before it is read.
- **Notes:**
  - The inline settlement runs before the ownership check. If a non-owner calls, L321 reverts and the
    settlement rolls back with it.
  - A third party can settle first through `settleWinningTicket` (L304-L306). Because of uniqueness, it can
    only record the same ID.

```solidity
// L320-L321
address winner = ownerOf(ticketId);
if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);
```
- **What:** Reads the current holder of the ticket and requires that holder to be the caller.
- **Why here:** After the ticket is proven to be the winner, and before any write.
- **Assumes:** The bearer model: whoever currently holds the ticket is entitled to the prize (DESIGN.md L2;
  IRaffle.sol L12-L13).
- **Establishes:** `winner == msg.sender`. An approved operator cannot redeem by calling directly.
- **Depended on by:** L323, L334, L335, L342, L345.
- **Notes:**
  - `ownerOf` reverts only when `_owners[ticketId] == 0` (ERC721.sol L61-L63, L426-L432). After L314-L318
    that cannot happen:
    - The ID has a nonzero range, so it was minted. L232 and L235 run in the same transaction.
    - By Precondition 4, it has not been burned.
  - Excluding operators is a call-site restriction only:
    - An approved operator can move the ticket to itself with `transferFrom` (ERC721.sol L115-L125, with
      authorization through `_checkAuthorized` at L179-L187).
    - Ticket transfers have no status gate (Raffle `_update` L497-L502).
    - The operator then passes L321 as the new owner.
  - Tickets stay transferable after resolution (L491-L492). `winner` is whoever holds the ticket in the
    block where this executes.

```solidity
// L323-L325
winnerRecipient = winner;
winnerRedeemed = true;
_burn(ticketId);
```
- **What:** Records the redemption and destroys the claim.
- **Why here:** Before any external call (checks-effects-interactions).
- **Assumes:** `_burn` makes no external call. Confirmed:
  - `Raffle._update` skips `_isProtocolDestination` when `to == address(0)`, because the `&&` at L498
    short-circuits.
  - OZ `_burn` has no receiver callback (ERC721.sol L303-L308).
- **Establishes:** `winnerRedeemed` is true, `winnerRecipient == msg.sender`, the ticket no longer exists,
  and its single-token approval is cleared.
- **Depended on by:** L310 on any later call, and anything that observes this clone during L334/L342.
- `_burn`'s `ERC721NonexistentToken` revert (ERC721.sol L305-L307) is unreachable here. L320 just found an
  owner, and nothing between L320 and L325 makes an external call.

```solidity
// L327-L328
address deliveredPrizeToken = address(0);
uint256 deliveredPrizeTokenId = 0;
```
- **What:** The event's prize fields default to zero for the cash outcome.

```solidity
// L329-L337
if (result == Status.NftWon) {
    if (prizeClaimed) revert PrizeAlreadyClaimed();
    prizeClaimed = true;
    deliveredPrizeToken = address(prizeToken);
    deliveredPrizeTokenId = prizeTokenId;
    prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId);
    if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) {
        revert PrizeDeliveryVerificationFailed(winner);
    }
}
```
- **What:** Marks the prize as claimed and asks the prize contract to move it to `winner`. Then it asks the
  same contract whether `winner` now owns it.
- **Why here:** `prizeClaimed` is written before the external call. `releaseSponsorPrize` uses the same
  order (L403-L404).
- **Assumes:**
  - `prizeClaimed == false` on entry. Its other writer, `releaseSponsorPrize` (L403), cannot run in `NftWon`
    (gate at L397). The write at L331 sits behind L310/L324. So the L330 check is defensive and cannot
    revert.
  - The prize contract honors `transferFrom` called by the token's current owner (the clone) and reports
    truthfully through `ownerOf`. **Nothing in Raffle establishes this.**
    - The prize is arbitrary code chosen by the sponsor (RaffleFactory.sol L115, L127).
    - Admission checks only code presence, `supportsInterface`, and exclusion of protocol addresses
      (RaffleFactory.sol L154-L179).
    - IRaffle.sol L14-L15 assumes "honest, standards-compliant" prizes. DESIGN.md L2 lists them as
      untrusted.
  - `winner` is not a protocol destination. This branch does not re-check it (the cash branch does, at
    L565). It holds anyway because every ticket owner passed `Raffle._update`'s screen when receiving the
    ticket (L498-L499). In particular, the configured prize contract can never own a ticket: L600 compares
    against `prizeToken_`, and `prizeToken` is written at L200 before any mint is possible (mints need
    `Active`, which follows `AwaitingPrize` set at L205).
- **Establishes:** On success, only that `prizeToken.ownerOf(prizeTokenId)` returned `winner` at L335. It
  does not establish that any transfer happened, or that `winner` can move the token.
- **Depended on by:** On the NFT side, the design requirement that every effect reverts when delivery fails
  rests entirely on the comparison at L335.
- **Outcomes not excluded at L334 (black box):**
  - **Revert.** It bubbles and the whole call reverts. L334 is the only way the NFT leaves the clone in
    `NftWon`, so a prize contract that keeps reverting leaves both the NFT and the redemption blocked with
    no end date.
  - **Success with no transfer.**
  - **Transfer to a different address.**
  - **Burning all forwarded gas.**
  - **Behavior that differs from creation time.** The escrow check at RaffleFactory.sol L129 is a one-time
    self-report.
  - **Re-entry.** See Cross-Function Dependencies.
  - **A receiver hook on `winner`.** A non-standard prize contract can call one during `transferFrom`. If
    the winner moves the NFT away inside that hook, L335 fails and the call reverts.
- **Outcomes not excluded at L335:**
  - Returning `winner` whatever the real state is. Redemption then completes with every effect committed
    and no delivery.
  - Returning another address, or reverting. Redemption reverts.
  - Returning data that does not decode as `address`. Redemption reverts in ABI decoding.
- **`transferFrom` vs `safeTransferFrom`:** with `transferFrom`, a standard implementation makes no
  `onERC721Received` call to `winner`. Since `winner == msg.sender` (L321), a contract winner started this
  call itself.
- **If the prize address had no code at L335:** the empty return data would fail ABI decoding of the
  `address` return and revert. Code presence was required at creation (RaffleFactory.sol L155, L184), and
  under `cancun` (foundry.toml L8) SELFDESTRUCT does not remove code from a contract created in an earlier
  transaction.

```solidity
// L338-L343
} else {
    cashAmount = winnerProceeds;
    if (cashAmount == 0) revert NoWinnerProceeds();
    winnerProceeds = 0;
    _transferQuote(winner, cashAmount);
}
```
- **What:** Pays the booked 80% allocation, zeroing it before the transfer.
- **Why here:** Zeroing comes before the token call (checks-effects-interactions).
- **Assumes:**
  - `winnerProceeds > 0`, so the L340 check is defensive.
    - Settlement sets it to `mulDiv(grossPot, 8000, 10000)` (L546-L548).
    - At settlement, `grossPot == unsettledPot == totalEntries * ENTRY_PRICE ≥ 1_000_000` (`buyEntries`
      L218, L223, L233; `requestDraw` L243).
    - The only other zeroing of `unsettledPot` is `enableRefunds` (L297), which leads to `Refunding`.
    - `winnerProceeds` itself is zeroed only at L341, behind L310/L324.
  - The clone holds at least `cashAmount` USDC (Precondition 6).
  - The USDC transfer to `winner` succeeds.
    - Issuer controls such as blocklist or pause are outside the system.
    - On failure the whole call reverts, burn included, so the ticket stays transferable and redemption can
      be retried from another address.
- **Establishes:** `winnerProceeds == 0`, and on return `quoteToken` has reported success.
- **Paths through `_transferQuote` (L564-L567):**
  - (a) `_isProtocolDestination(winner, prizeToken)` returns true → revert `InvalidQuoteDestination`
    (L565).
  - (b) Otherwise `safeTransfer`:
    - A failed call reverts and bubbles its revert data (SafeERC20.sol L189-L192).
    - A `false` return, or any non-empty return that is not `true`, reverts (SafeERC20.sol L196, L34-L35).
    - A `true` return, or an empty return from a token that has code, counts as success (SafeERC20.sol
      L187, L196).
  - Every path that is not a success reverts.
- **Path (a) cannot fire in this function.**
  - The static comparisons in L599-L601 were already applied to `winner` when it received the ticket
    (L498-L499). They use the same immutables and the write-once `prizeToken`.
  - `isRaffle(winner)` can become true after receipt only for an address that had no code when it received
    the ticket (L602) and later became a registered clone. Clones are deployed with CREATE (Clones.sol
    L32-L33, L57) and registered at RaffleFactory.sol L125.
  - No Raffle code calls `redeemWinningTicket`: the only hits are the definition at L309 and IRaffle.sol
    L338, and src contains no `this.` calls. So such an address can never be `msg.sender`.

```solidity
// L345
emit WinningTicketRedeemed(ticketId, winner, result, cashAmount, deliveredPrizeToken, deliveredPrizeTokenId);
```
- **What:** The indexer record of the redemption. It is emitted after delivery, so it appears only when the
  call succeeds.

---

**Cross-Function Dependencies:**

Callees:

- **`nonReentrant` (external-source-available, ReentrancyGuard.sol L69-L73, L88-L106).**
  - One storage slot per clone.
  - Paths: if already entered, revert `ReentrancyGuardReentrantCall` (L89-L91). Otherwise set ENTERED, run
    the body, restore NOT_ENTERED. A revert rolls back the slot write.
  - The caller depends on it so that no guarded mutator of this clone runs during L334 or L342.

- **`_settleWinningTicket` (internal, L533-L558).** Runs only when `!settlementComplete`. Four paths:
  1. `settlementComplete` is already true → revert (L534). Unreachable from L315: L314 checked it and
     nothing writes it in between.
  2. Status is not `NftWon`/`CashWon` → revert (L536). Unreachable from L315: L312 checked it.
  3. `_requireWinningTicket` fails → revert `TicketDoesNotContainWinningEntry` (L582-L584). This is the
     only reachable revert.
  4. Success:
     - `protocolFee = floor(grossPot * 500 / 10_000)` (L540).
     - `NftWon`: `sponsorAmount = grossPot - protocolFee` (L544).
     - `CashWon`: `cashAmount = floor(grossPot * 8_000 / 10_000)` and
       `sponsorAmount = grossPot - protocolFee - cashAmount`; `winnerProceeds = cashAmount` (L546-L548).
       The checked subtraction cannot underflow, because floor(5%) + floor(80%) ≤ grossPot.
     - Then the assignments at L551-L555 and the event at L557.
  - What the caller depends on it for:
    - The containment proof.
    - `winningTicketId` and `settlementComplete`.
    - `winnerProceeds` being populated before L339.
  - It makes no external call and reads no ticket ownership (comment L528-L530; body L533-L558).
  - `sponsorProceeds` (L554) and `protocolFees` (L555) are plain assignments, not increments. They are zero
    before settlement because their only other writers are the release functions, which revert on zero
    (L377, L387) and otherwise set them to zero (L378, L388).
  - L315 discards its return value.

- **`_requireWinningTicket` → `ticketRange` (internal, L579-L585, L451-L455).**
  - Inclusive range-containment check, with two paths: pass or revert.
  - IDs that were never minted return `(0,0)` and fail, because `winningEntry ≥ 1`.

- **`Math.mulDiv` (external-source-available, Math.sol L206-L221).**
  - Pure. It reverts only for a zero denominator or a quotient of 2^256 or more (L219-L221).
  - Here `grossPot ≤ type(uint128).max * 1e6`, so `grossPot * 8000 < 2^256`. That always takes the
    simple-division path (L211-L216), with denominator `BPS = 10_000` (RaffleConstants.sol L12). It never
    reverts.

- **`ERC721.ownerOf` (external-source-available, ERC721.sol L61-L63 → `_requireOwned` L426-L432).**
  - Reverts `ERC721NonexistentToken` when the owner is zero; otherwise returns `_owners[ticketId]`.
  - Raffle overrides neither `ownerOf` nor `_ownerOf`.
  - The caller depends on it for the holder's identity at call time.

- **`ERC721._burn` → `Raffle._update` → `ERC721._update` (ERC721.sol L303-L308; L497-L502; ERC721.sol
  L216-L245).** With `to = 0` and `auth = 0`:
  - No destination screen (L498).
  - No authorization check (ERC721.sol L220).
  - The approval is cleared without reading the owner (ERC721.sol L227 → L385 branch skipped → L398).
  - Unchecked balance decrement (L229-L231). An owner's balance is at least 1 by OZ's documented
    ownership/balance invariant (ERC721.sol L142-L144).
  - Owner zeroed (L240), and `Transfer` emitted (L242).
  - The `previousOwner == 0` revert (L305-L307) is unreachable after L320.

- **`IERC721(prizeToken).transferFrom` (external-black-box).**
  - Sent: `(address(this), winner, prizeTokenId)`, no value, all remaining gas.
  - Assumed: it moves the NFT to `winner`.
  - Not excluded: revert, a silent no-op, a transfer elsewhere, burning all gas, re-entry.
  - Re-entry surface on this clone during the call:
    - Every lifecycle mutator is blocked by the guard.
    - `onERC721Received` reverts unless the status is `AwaitingPrize` (L421-L426).
    - `rawFulfillRandomWords` requires `msg.sender == wrapper` (VRFV2PlusWrapperConsumerBase.sol
      L103-L105), and `fulfillRandomWords` ignores any state other than `Drawing` (L511-L516).
    - The ticket ERC-721 functions `transferFrom`, `safeTransferFrom`, `approve` and `setApprovalForAll`
      (ERC721.sol L93-L136) are unguarded. However, the winning ticket is already burned, and other tickets
      carry no claim in `NftWon`.
  - **Observable state during the call.** View functions on this clone already report
    `winnerRedeemed == true`, `prizeClaimed == true`, `winnerRecipient == winner`, and `ownerOf(ticketId)`
    reverting, all before the prize has moved.

- **`IERC721(prizeToken).ownerOf` (external-black-box).**
  - STATICCALL (IERC721.sol L39 `view`).
  - It is the only evidence of delivery, and no return value is excluded.

- **`_transferQuote` (internal, L564-L567).** Its call chain:
  - `_isProtocolDestination` (internal, L593-L605). Paths:
    - A static comparison matches (L599-L600) → returns true with no external call.
    - Otherwise STATICCALL `factory.raffleImplementation()` (L601).
    - If still false and `winner` has code → STATICCALL `factory.isRaffle(winner)` (L602-L603).
    - An address without code skips the registry query.
  - `IRaffleFactory.raffleImplementation()` and `isRaffle()` (external-source-available). They are an
    immutable getter (RaffleFactory.sol L42, L91) and a mapping getter (RaffleFactory.sol L54), both `view`
    (IRaffleFactory.sol L130, L139). The factory is trusted and these getters do not revert.
  - `SafeERC20.safeTransfer` (external-source-available, SafeERC20.sol L33-L37, L176-L200). Paths are
    listed in the L338-L343 block.
  - `quoteToken.transfer` (external-black-box, trusted canonical USDC). It is assumed to move exactly
    `cashAmount` without fees and to have no hooks. Issuer controls are not excluded, and they revert the
    whole call.

Callers:

- **No internal callers.** A grep of the repository, excluding node_modules, finds only the definition (L309)
  and the interface declaration (IRaffle.sol L338). No test suite exists.
- **External callers.** Any address can call it. It succeeds only for the current owner of the winning
  ticket. Those callers assume it enforces three things: owner-only access, one-shot redemption, and
  all-or-nothing delivery.
- **Entry from a ticket transfer callback.** A recipient contract can call this from its
  `onERC721Received` during an unguarded ticket `safeTransferFrom`:
  - Ownership is updated before the callback (ERC721.sol L133-L135).
  - `checkOnERC721Received` does not re-check ownership afterwards (ERC721Utils.sol L32-L47).
  - So the recipient can redeem inside the callback, and the outer transfer then completes with the ticket
    already burned.
- **Not reachable** while any other `nonReentrant` function of the same clone is running, because the
  guard slot is shared.

Shared state:

- `winnerRedeemed`, `winnerRecipient`: written only here (L323-L324). Exposed through public getters (L97,
  L130).
- `status`: read at L311. Written at L165, L205, L252, L299, L428 and L521.
- `settlementComplete`, `winningTicketId`: read at L314 and L316. Written only in `_settleWinningTicket`
  (L551-L552), which is reached through `settleWinningTicket` (L305) or from here (L315).
- `winningEntry`: read at L581, written at L519. `_ticketRanges`: read at L452, written at L232.
- `unsettledPot`, `sponsorProceeds`, `protocolFees`:
  - Written by the inline settlement (L553-L555).
  - Also written by `buyEntries` (L233), `enableRefunds` (L297), `releaseSponsorProceeds` (L378) and
    `releaseProtocolFees` (L388).
- `winnerProceeds`: written at L548 and L341. Read by `accountedQuoteBalance` (L469).
- `prizeClaimed`: read and written here (L330-L331) and by `releaseSponsorPrize` (L400, L403). Status
  separates the two writers.
- ERC-721 ticket ledger:
  - Here: read at L320, burned at L325.
  - Other writers: `buyEntries` `_safeMint` (L235), `refundTickets` `_burn` (L364), ticket transfers
    (ERC721.sol L115-L136) and approvals (ERC721.sol L93-L107).
- Reentrancy guard slot, one per clone (ReentrancyGuard.sol L36-L37).
- External state:
  - Prize NFT custody, held in `prizeToken`.
  - The clone's USDC balance, held in `quoteToken`.
  - The factory registry `isRaffle`, read only.

Invariant couplings:

1. **Quote-liability conservation.** `accountedQuoteBalance` is defined at L468-L470.
   - Inline settlement moves `unsettledPot` into `winnerProceeds + sponsorProceeds + protocolFees`, with an
     equal total (L539-L555).
   - The cash branch lowers `winnerProceeds` by `cashAmount` and sends the same nominal amount out
     (L339-L342).
   - The NFT branch moves no quote token.
   - Equality with the real balance depends on USDC being fee-free (L560-L561). Nothing checks it on-chain.
2. **Prize custody and `prizeClaimed`.**
   - There are two writers: L331 (here) and L403 (`releaseSponsorPrize`).
   - Status splits them: in `NftWon` only this function can claim the prize; in `CashWon` and `Refunding`
     only `releaseSponsorPrize` can (L397).
   - In `NftWon`, this function is the only way the NFT leaves the clone.
3. **Ticket existence vs redemption.** While the status is `NftWon` or `CashWon`, the winning ticket exists
   exactly when `winnerRedeemed` is false. This rests on the burn sites at L325 and L364 (the latter gated
   by L350).
4. **Redemption implies settlement.** `winnerRedeemed ⇒ settlementComplete`, because L314-L318 run before
   L324 in the same call.
5. **Sponsor proceeds in `NftWon` are decoupled from NFT delivery.**
   - `settleWinningTicket` (L304-L306) is permissionless and independent of redemption.
   - `releaseSponsorProceeds` (L375-L382) and `releaseProtocolFees` (L385-L392) check only for a nonzero
     balance.
   - So the sponsor's 95% and the treasury's 5% become releasable at settlement whether or not L334-L336
     can ever succeed. Nothing links sponsor release to delivery.
   - In `CashWon`, likewise, the winner's cash is independent of `releaseSponsorPrize`.
6. **Bearer claims and ERC-721 approvals.** L321 excludes operators only at the point of the call. ERC-721
   authorization (ERC721.sol L115-L125, L164-L168) lets an operator become the owner first.

---

**Open Questions:**

- **Unclear; need to inspect the intended prize-token admission policy** (deployment documentation or a
  frontend allowlist).
  - IRaffle.sol L14-L15 says supported prizes are "honest, standards-compliant ERC-721s".
  - DESIGN.md L2 says arbitrary prize contracts are untrusted.
  - On-chain admission (RaffleFactory.sol L154-L179) checks only code presence, `supportsInterface` and
    exclusion of protocol addresses.
  - Which statement governs determines whether the self-reported check at L335 is the intended delivery
    boundary. It also determines whether prize contracts with transfer restrictions are meant to be
    supported: proxy upgrades, pausing, transfer validators, or soulbound locks can block the L334 transfer
    permanently.
- **Unclear; need to inspect the target-chain USDC deployment's issuer controls** (blocklist, pause). This
  decides whether a revert at L342 can be permanent for a given winner address. The only recovery inside
  the protocol is moving the ticket to another address (tickets are transferable in every state,
  L491-L492).
- **Unclear; need to inspect whether any off-chain or out-of-scope mechanism handles a winning ticket whose
  holder never redeems** (a lost key, or a contract that cannot make the call). In-scope code has no
  redemption deadline and no alternative claimant:
  - In `NftWon`, L334 is the only way out for the NFT (L397 excludes `NftWon` from `releaseSponsorPrize`).
  - In `CashWon`, nothing else pays out `winnerProceeds`.
- **Unclear; need to inspect whether any external integrator treats `winnerRedeemed`, `prizeClaimed` or
  `winnerRecipient` as proof of delivery.** All three are written before L334, and code running inside the
  prize contract's `transferFrom` can already see them.
