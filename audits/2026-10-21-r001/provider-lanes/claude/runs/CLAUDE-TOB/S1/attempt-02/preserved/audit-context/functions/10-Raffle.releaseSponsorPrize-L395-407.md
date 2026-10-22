## `releaseSponsorPrize` in packages/contracts/src/Raffle.sol (L395-L407)

Citation key. A bare `Lnnn` is `packages/contracts/src/Raffle.sol`. Other files:
`IRaffle.sol` and `IRaffleFactory.sol` = `packages/contracts/src/interfaces/`; `RaffleFactory.sol` =
`packages/contracts/src/`; `ReentrancyGuard.sol` (OZ v5.5.0 header), `ERC721.sol` (OZ v5.6.0 header), `IERC721.sol`,
`Clones.sol` = `packages/contracts/node_modules/@openzeppelin/contracts/...`; `VRFV2PlusWrapperConsumerBase.sol` =
`packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/`. Compiler is solc 0.8.36 with EVM `cancun`
(`foundry.toml` L7-L8); configured networks are L1 mainnet and Sepolia (`hardhat.config.ts` L44-L57). No `test`,
`script` or `lib` directory exists under `packages/contracts/`.

```solidity
// L394-L407
/// @inheritdoc IRaffle
function releaseSponsorPrize() external override nonReentrant {
    Status currentStatus = status;
    if (currentStatus != Status.CashWon && currentStatus != Status.Refunding) {
        revert SponsorPrizeUnavailable(currentStatus);
    }
    if (prizeClaimed) revert PrizeAlreadyClaimed();

    address recipient = sponsorRecipient;
    prizeClaimed = true;
    prizeToken.transferFrom(address(this), recipient, prizeTokenId);
    if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);
    emit SponsorPrizeReleased(msg.sender, recipient, address(prizeToken), prizeTokenId);
}
```

**Purpose:** This function returns the prize in the two outcomes where the sponsor keeps the NFT: `CashWon`
(reserve missed, so the winner takes cash) and `Refunding` (empty raffle cancelled, or a draw or callback that timed
out). In those two states it is the only code in the clone that moves the escrowed NFT, and it always sends it to
the write-once `sponsorRecipient`.

- The clone calls the prize contract at exactly four sites:
  - L334-L335, in `redeemWinningTicket`. These run only in `NftWon` (L312, L329).
  - L404-L405, here.
- The clone never grants an approval on the prize. Every use of `prizeToken`/`prizeTokenId` in Raffle.sol is at
  L70, L73, L183-L201, L332-L335, L404-L406, L422, L498, L565 and L591-L600. None is an `approve` or
  `setApprovalForAll`.
- The contract has no administrator or rescue path (L24-L25). Without this function, the NFT of a `CashWon` or
  `Refunding` raffle has no way out of the clone.
- Documented intent:
  - IRaffle.sol L354: "Returns the escrowed prize to the immutable sponsor recipient after `CashWon` or
    `Refunding`."
  - IRaffle.sol L32 (doc of `Refunding`) and the event doc at L173-L180.
  - DESIGN.md L2: "Refund outcome pays 100% per entry and returns prize."
- Anyone can call it. The caller chooses when the release happens, not where the prize goes.

---

**Inputs & Assumptions:**

- No parameters.
- `msg.sender`. Trust: **untrusted**. It is never compared with anything. Its only use is as the event's
  `caller` field (L406).
- Implicit storage reads:
  - `status` (L396)
  - `prizeClaimed` (L400)
  - `sponsorRecipient` (L402)
  - `prizeToken` (L404, L405, L406)
  - `prizeTokenId` (L404, L405, L406)
  - the reentrancy guard slot `0x9b779b17…5f00` (ReentrancyGuard.sol L36-L37)
- Implicit external read: `prizeToken.ownerOf(prizeTokenId)` (L405).
- Clock: not read. There is no deadline. The function stays available until it succeeds once.
- Value: non-payable.
- Not read: `settlementComplete`, `winnerRedeemed`, `winnerProceeds`, `sponsorProceeds`,
  `remainingRefundLiability`, and all ticket state. The release therefore does not depend on whether settlement,
  winner redemption or any refund has happened yet.

Preconditions, and what establishes each:

1. **`status` is `CashWon` or `Refunding`, and stays that way.** L397 checks it. It stays because no status
   writer can run from a terminal state:

   | Writer | Write | Required starting state |
   | --- | --- | --- |
   | constructor | L165 | n/a (implementation only) |
   | `initialize` | L205 | `!initialized` (L177) |
   | `requestDraw` | L252 | `Active` (L241) |
   | `enableRefunds` | L299 | `Active` or `Drawing` (L279-L294) |
   | `onERC721Received` | L428 | `AwaitingPrize` (L422) |
   | `fulfillRandomWords` | L521 | `Drawing` (L511) |

   - `CashWon` is written only at L521, and only when `totalEntries < reserveEntries`.
   - In a clone, `Refunding` is written only at L299.

2. **`prizeClaimed == false`.** L400 checks it. In `CashWon` or `Refunding`, the only writer that can run is
   L403 itself. The other writer, L331, sits inside `if (result == Status.NftWon)` (L329), which comes after the
   `NftWon`/`CashWon` gate at L312.

3. **The clone owns `prizeTokenId` on entry.** This is established once, at creation:
   - `RaffleFactory.createRaffle` moves the token in (RaffleFactory.sol L128).
   - It asks the prize contract who owns it (L129).
   - It requires the clone to be `Active` (L132).

   The L129 answer comes from the prize contract itself. After creation, the clone moves or approves the prize
   only at L334 and L404. Nothing guards against the prize contract moving the token on its own (admin transfer,
   burn, upgrade): **nothing found.**

4. **`sponsorRecipient` is nonzero.** Established by Raffle L182 and RaffleFactory.sol L156.

5. **`sponsorRecipient` is not protocol plumbing when the release happens.** This is checked only at creation:
   - Raffle L193 calls `_isProtocolDestination` (L593-L605). It rejects this clone, the factory, USDC, the VRF
     wrapper, the prize token and the implementation (L599-L601). If the address has code, it also rejects any
     clone registered by this factory (L602-L603).
   - RaffleFactory.sol L163-L169 rejects the factory, USDC, the wrapper, the prize token, the implementation, and
     any address with `isRaffle[...] == true`. That last check reads the mapping directly.
   - At release time: **nothing found.** L402-L404 do not screen the address. The L402 block explains why the
     creation-time answer can change.

6. **`prizeToken`, `prizeTokenId` and `sponsorRecipient` never change.** Each has a single writer (L198, L200,
   L201), all inside `initialize`. `initialize` runs once (L177-L179) and is already locked on the implementation
   (L164).

7. **`prizeToken` has code at L404.**
   - Established at creation by RaffleFactory.sol L155 → L184.
   - Under `cancun` (foundry.toml L8), SELFDESTRUCT removes code only from a contract created in the same
     transaction. A prize contract that existed before the creation transaction therefore keeps its code.
   - A prize contract deployed and self-destructed within the creation transaction itself is not excluded.
   - Nothing re-checks this at release. If the code is gone, the compiler's pre-call code-size check turns L404
     into a revert (see the L404 block).

---

**Outputs & Effects:**

- Returns nothing.
- Storage writes:
  - `prizeClaimed = true` (L403). It persists only if L404-L406 complete.
  - Guard slot: set to 2 on entry (ReentrancyGuard.sol L99) and back to 1 on exit (L105).
- External interactions, in order:
  1. CALL `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` (L404). No value is sent. The line
     sets no gas cap, so the call forwards all but 1/64 of the remaining gas (EIP-150).
  2. STATICCALL `prizeToken.ownerOf(prizeTokenId)` (L405). `ownerOf` is declared `view` (IERC721.sol L39), so
     solc uses STATICCALL and the prize contract cannot write state during this read.
- Events, in order:
  1. Whatever the prize contract emits during L404. An OZ-style implementation emits `Transfer`
     (ERC721.sol L242).
  2. `SponsorPrizeReleased(caller = msg.sender, recipient, prizeToken = address(prizeToken), prizeTokenId)`
     (L406). It is declared at IRaffle.sol L178-L180; the first three fields are indexed.
- Reverts:
  - `ReentrancyGuardReentrantCall` (ReentrancyGuard.sol L90)
  - `SponsorPrizeUnavailable(currentStatus)` (L398)
  - `PrizeAlreadyClaimed()` (L400)
  - anything bubbled up from L404, or the compiler's empty revert when `prizeToken` has no code
  - a revert, out-of-gas, or undecodable return at L405
  - `PrizeDeliveryVerificationFailed(recipient)` (L405)
- No USDC moves and no ticket changes. No other storage is written.
- Postconditions on success:
  - `prizeClaimed == true` for good. Both writers (L331, L403) store `true`, and nothing stores `false`.
  - At L405, `prizeToken.ownerOf(prizeTokenId)` returned `sponsorRecipient`.
  - Every later call reverts at L400. That includes the case where the NFT is pushed back into the clone with a
    plain `transferFrom`. L409-L411 already documents that NFTs forced into the clone this way cannot be
    recovered.

Outcome by instance and entry state:

| Instance / state on entry | Result |
| --- | --- |
| Clone, `AwaitingPrize` (exists only inside `createRaffle`, between `initialize` and the L428 write) | revert at L398 |
| Clone, `Active` or `Drawing` | revert at L398 |
| Clone, `NftWon` | revert at L398. The NFT can leave only through `redeemWinningTicket` (L334). |
| Clone, `CashWon` or `Refunding`, `prizeClaimed == false` | continues to L402-L406 |
| Clone, `CashWon` or `Refunding`, `prizeClaimed == true` | revert at L400 |
| Implementation instance | passes L397 (status `Refunding`, L165) and L400 (`prizeClaimed` never written), then reverts at L404 (see that block) |
| ERC-1167 proxy of the implementation not created by the factory | `initialize` requires `msg.sender == factory` (L178), so status stays 0 = `AwaitingPrize` (IRaffle.sol L23). Reverts at L398. |

---

**Block-by-Block:**

```solidity
// L395
function releaseSponsorPrize() external override nonReentrant {
```
- **What:** Permissionless external entry point, wrapped in the clone-wide OZ guard.
- **Why here:** The guard is taken before any state is read and is held across both prize calls (L404-L405).
- **Assumes:** The guard slot is not 2 (ENTERED).
  - A fresh clone's slot is 0. `_reentrancyGuardEntered` compares only against 2 (ReentrancyGuard.sol L112-L114),
    so 0 passes.
  - Each clone has its own slot, because clones keep isolated storage (L152).
- **Establishes:** While L404 runs, every other guarded function of this clone reverts:
  - `buyEntries` (L212)
  - `requestDraw` (L240)
  - `enableRefunds` (L276)
  - `settleWinningTicket` (L304)
  - `redeemWinningTicket` (L309)
  - `refundTickets` (L349)
  - `releaseSponsorProceeds` (L375)
  - `releaseProtocolFees` (L385)
  - this function itself
- **Depended on by:** the re-entry surface described at L404. L403 is a second, independent barrier against
  re-entering this function.

```solidity
// L396-L399
Status currentStatus = status;
if (currentStatus != Status.CashWon && currentStatus != Status.Refunding) {
    revert SponsorPrizeUnavailable(currentStatus);
}
```
- **What:** Lets through only the two outcomes in which the sponsor keeps the NFT.
- **Why here:** It runs first, and it decides which code owns the prize: this function, or the NFT branch of
  `redeemWinningTicket`.
- **Assumes:** Precondition 1, that these statuses are terminal. `currentStatus` is read once and never re-read.
  That is correct because no status writer can run later, including from code that re-enters during L404.
- **Establishes:**
  - **The prize-ownership partition.**
    - In `NftWon`, only `redeemWinningTicket` (L329-L337) can move the prize.
    - In `CashWon` or `Refunding`, only this function can.
    - In `CashWon`, `redeemWinningTicket` takes the cash branch (L338-L343) and does not touch `prizeClaimed`.
    - In `Refunding`, `redeemWinningTicket` reverts at L312.
  - A raffle still waiting for its prize (`AwaitingPrize`) or still running (`Active`, `Drawing`) cannot release.
- **Not established:** This gate does not lock the implementation instance, whose status is `Refunding` (L165).
  That lock comes from L404.
- **How each allowed status is reached:**
  - `CashWon`: only at L521, when `totalEntries < reserveEntries`. `reserveEntries > 0` is enforced at
    RaffleFactory.sol L178.
  - `Refunding`: only at L299 in a clone. While an `Active` raffle has no entries, the sponsor can reach it at any
    time (L282). A sponsor can therefore create a raffle, cancel it with `enableRefunds`, and then release the
    prize, in order.
- **Depended on by:** L400-L404.

```solidity
// L400
if (prizeClaimed) revert PrizeAlreadyClaimed();
```
- **What:** One-shot gate for this path.
- **Assumes:** Precondition 2. Given the partition above, in `CashWon` or `Refunding` only an earlier successful
  call to this function can have set the flag.
- **Establishes:** No earlier release from this clone succeeded.
- **The shared flag:**
  - `prizeClaimed` is also written by `redeemWinningTicket` (L330-L331).
  - Status splits the two writers, and status is terminal. So neither path ever sees a `true` that the other path
    wrote.
  - What keeps winner delivery and sponsor return apart is status. The flag only makes each path one-shot.
  - In `redeemWinningTicket`, the L330 check is also covered by `winnerRedeemed` (L310, L324).

```solidity
// L402
address recipient = sponsorRecipient;
```
- **What:** Copies the write-once destination into a local.
- **Why here:** Before the external call. The local is used at L404, L405 and L406.
- **Assumes:**
  - Preconditions 4-6.
  - `recipient != address(this)`, so the transfer is never a self-transfer. `initialize` rejects it through L193 →
    L599, and both addresses are fixed afterwards.
- **Establishes:** The destination depends neither on `msg.sender` nor on any argument.
- **The screen can give a different answer at release than it did at creation.**
  - Only two inputs to `_isProtocolDestination` change over time:
    - `destination.code.length` (L602). An address can gain code after creation.
    - `canonicalFactory.isRaffle(destination)` (L603). The registry only grows: `isRaffle[raffle] = true` at
      RaffleFactory.sol L125 is its only write.
  - The other comparisons (L599-L601) are against this clone, immutables, the immutable implementation, and the
    write-once prize token. They cannot change.
  - Clones are deployed with CREATE (Clones.sol L57). A clone's address therefore follows from the factory address
    and the factory nonce, and can be computed before the clone exists.
  - Suppose `sponsorRecipient` equals the address of a clone the factory has not yet deployed. It passes both
    creation-time screens:
    - it has no code, so L602 skips the registry query;
    - RaffleFactory.sol L166 reads `false`.

    It becomes a registered clone later.
  - L402-L404 screen nothing. The USDC path to the same address does screen at payout time:
    `releaseSponsorProceeds` (L379-L380) → `_transferQuote` → L565 → `InvalidQuoteDestination`.
  - Recorded as the assumption "`sponsorRecipient` is not a registered clone at release time": **nothing found** at
    release.
  - The registry check covers only this factory's clones (L587-L589, L603).
- **Depended on by:** L404-L406.

```solidity
// L403
prizeClaimed = true;
```
- **What:** Records the prize as released.
- **Why here:** Before the external call (checks-effects-interactions). `redeemWinningTicket` uses the same order
  (L331 before L334).
- **Establishes:**
  - During L404-L405, re-entering this function would revert at L400 even without the guard.
  - The public getter (L133) reports `true` while the NFT has not yet moved.
- **Depended on by:** nothing later in this call. It is the one-shot record for later calls.
- A revert at L404 or L405 undoes this write, so a failed release can be retried.

```solidity
// L404
prizeToken.transferFrom(address(this), recipient, prizeTokenId);
```
- **What:** Asks the sponsor-chosen prize contract to move the NFT from the clone to `recipient`.
- **Why here:** After all checks and after the flag write, with the guard held.
- **Assumes:**
  - Preconditions 3 and 7.
  - The prize contract carries out the request. **Nothing found** establishes this; the contract is a black box.
  - Admission at creation checked only three things: code presence, ERC-165 support for `IERC721`, and that the
    address is not protocol plumbing (RaffleFactory.sol L154-L179).
  - IRaffle.sol L14-L15 assumes "honest, standards-compliant" prizes. DESIGN.md L2 lists arbitrary prize
    contracts as untrusted.
- **Standard behavior, for reference (OZ ERC721.sol L115-L125):**
  - It reverts if `to == 0` (L116-L118). L182 rules that out.
  - It authorizes the clone as the owner (L220-L222 → L164-L167).
  - It reverts with `ERC721IncorrectOwner` if the clone is not the owner (L122-L124).
  - It makes no call to `recipient`. Receiver callbacks happen only in `safeTransferFrom` (L133-L136).
- **`transferFrom`, not `safeTransferFrom`:** Nothing asks the recipient to accept via `onERC721Received`. A
  contract recipient that cannot manage ERC-721s still receives the token. Nothing establishes that the recipient
  can manage it: **nothing found.**
- **Compiler behavior:** `transferFrom` declares no return values (IERC721.sol L91). For a high-level call like
  this, solc 0.8.36 (foundry.toml L7) checks that the target has code (`extcodesize > 0`) before calling, reverts
  if it has none, and ignores any returned bytes. Two consequences:
  - **Implementation instance.** `prizeToken` is never written there; L200 cannot run because of L164 and L177.
    The call target is therefore `address(0)`, which has no code, so the call reverts. This, not the status gate,
    is what locks this function on the implementation.
  - **Prize address without code** (Precondition 7): the call reverts here.
- **Outcomes not excluded (black box):**
  - **Revert.** It bubbles up and L403 is undone. If the revert persists, the NFT has no other exit, because
    `sponsorRecipient` is write-once (L198), the status cannot change, and there is no rescue path (L24-L25).
    Persistent causes include:
    - a paused collection;
    - a recipient on a blocklist or rejected by a transfer validator;
    - a locked token;
    - a token the prize contract has already moved off the clone.
  - **Success without a transfer, or a transfer to a different address.** L405 catches these only if `ownerOf`
    answers honestly.
  - **Gas exhaustion.** The call fails and the transaction reverts.
  - **Behavior that differs from creation time**, for example a proxy upgrade or admin logic. The check at
    RaffleFactory.sol L129 was a one-time self-report.
  - **Re-entry into the clone.** Guarded functions revert. The unguarded entry points behave as follows:
    - `initialize` reverts (L177).
    - `onERC721Received` reverts, because status is not `AwaitingPrize` (L421-L426).
    - `receive` reverts (L171-L173).
    - `rawFulfillRandomWords` requires `msg.sender == wrapper` (VRFV2PlusWrapperConsumerBase.sol L103-L105). The
      prize contract cannot be the wrapper (RaffleFactory.sol L158). A wrapper callback would be ignored anyway,
      because status is not `Drawing` (L511).
    - Ticket `approve`, `setApprovalForAll`, `transferFrom` and `safeTransferFrom` (ERC721.sol L93-L136) stay
      open. The prize contract can never own a ticket (L498-L499 → L600), but it can act as an operator that a
      ticket holder approved. This function reads no ticket state.

    So nothing reachable during L404 can change `status`, `prizeClaimed`, `sponsorRecipient`, `prizeToken` or
    `prizeTokenId`.
  - **A call into `recipient` by a non-standard prize contract.** If `recipient` moves the NFT on before L404
    returns, L405 sees a different owner and the whole call reverts. The sponsor's own recipient can therefore
    block its own release.
- **Establishes:** nothing that can be verified from this line alone.

```solidity
// L405
if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);
```
- **What:** Asks the prize contract who owns the token now.
- **Why here:** Immediately after L404. No other party's code runs in between.
- **Assumes:** `ownerOf` answers truthfully. **Nothing found** establishes this: the prize contract both performs
  the transfer and reports on it.
- **Establishes:** Only that the prize contract returned `recipient`.
- **Outcomes:**
  - It returns `recipient`: the check passes, whatever the real ownership is.
  - It returns any other address: `PrizeDeliveryVerificationFailed(recipient)`, and everything reverts.
  - It reverts, runs out of gas, or returns data that does not decode as an `address` (fewer than 32 bytes, or
    nonzero upper bits): the call reverts.
- **Note:** This is a STATICCALL (IERC721.sol L39), so the prize contract cannot change state during this read.
- **Depended on by:** the event at L406, and what `prizeClaimed == true` means after the transaction.

```solidity
// L406
emit SponsorPrizeReleased(msg.sender, recipient, address(prizeToken), prizeTokenId);
```
- **What:** The indexer record of the release. It is emitted only on success, after L405.
- `address(prizeToken)` and `prizeTokenId` are read from storage again here. Both are write-once (L200-L201).

---

**Cross-Function Dependencies:**

Callees:

- **`nonReentrant` (OZ ReentrancyGuard, external-source-available; ReentrancyGuard.sol L69-L73, L88-L106; read
  in full).**
  - Paths:
    - Slot == 2: revert (L89-L91).
    - Otherwise: write 2 (L99), run the body, write 1 (L105).
  - If the body reverts, the L99 write is undone too.
  - This function depends on it to keep every guarded function of this clone out of the L404 window. It does not
    cover the unguarded entry points listed in the L404 block. None of those write state that this function reads.
- **`IERC721(prizeToken).transferFrom` (external-black-box).**
  - Sent: `(address(this), sponsorRecipient, prizeTokenId)`, no value, all remaining gas minus 1/64.
  - Assumed: it moves the NFT to the recipient.
  - Not excluded: see the L404 block.
  - This function depends on its revert to undo L403.
- **`IERC721(prizeToken).ownerOf` (external-black-box, STATICCALL).**
  - The only evidence of delivery.
  - No return value is excluded.

Sources of the preconditions. These are not called here, but this function's correctness rests on them:

- `fulfillRandomWords` (L509-L524): the only writer of `CashWon` (L521).
- `enableRefunds` (L276-L301): the only writer of `Refunding` in a clone (L299).
- `initialize` (L176-L206):
  - writes `sponsorRecipient`, `prizeToken` and `prizeTokenId` once (L198, L200-L201);
  - runs the nonzero check (L182) and the protocol-destination screen (L193).
- `RaffleFactory._validateCreateParams` (RaffleFactory.sol L154-L179):
  - nonzero recipient (L156);
  - recipient screen (L163-L169);
  - prize has code and reports ERC-721 support via ERC-165 (L155, L171-L177).
- `RaffleFactory.createRaffle` (RaffleFactory.sol L97-L148):
  - escrow (L128);
  - verification that the prize contract itself answers (L129);
  - `Active` check (L132).
- `redeemWinningTicket` (L309-L346): the other `prizeClaimed` writer, limited to `NftWon` (L312, L329).

Callers:

- **No internal call sites.**
  - A grep of `src/` finds only the definition (L395) and the interface declaration (IRaffle.sol L355).
  - `src/` contains no `this.` calls.
  - There are no tests or scripts.
- **External, permissionless.** Keepers, the sponsor, `sponsorRecipient`, or anyone else. They rely on the
  function to enforce three things:
  - the status gate;
  - the one-shot gate;
  - a destination that cannot be redirected.
- **Nested inside `RaffleFactory.createRaffle`.**
  - The prize contract's `safeTransferFrom` (RaffleFactory.sol L128) calls `onERC721Received`, which sets
    `Active` (L428).
  - From there, a call originating from the sponsor can pass `enableRefunds` (L282), after which this function
    becomes callable. The clone's guard is not held during creation.
  - RaffleFactory.sol L132 then reverts the whole creation, because the status is `Refunding`, not `Active`, and
    `Refunding` is terminal.
  - `CashWon` cannot be reached in that window. `requestDraw` needs `block.timestamp ≥ endTime` (L242), and at
    creation `endTime > block.timestamp` (RaffleFactory.sol L100).
- **Sponsor early cancel.** Once `createRaffle` has returned, the sponsor can call `enableRefunds` on the empty
  raffle (L282) and then this function, in the same transaction or a later one. IRaffle.sol L322-L323 documents
  this path.
- **Not reachable** while any other guarded function of this clone is running.

Shared state:

- `status`:
  - read at L396;
  - written at L165, L205, L252, L299, L428 and L521;
  - also read by `RaffleFactory.createRaffle` (RaffleFactory.sol L132).
- `prizeClaimed`:
  - read and written here (L400, L403);
  - read and written by `redeemWinningTicket` (L330, L331);
  - exposed by the public getter at L133.
- `sponsorRecipient`:
  - read here (L402);
  - read by `releaseSponsorProceeds` (L379), which screens it again at L565;
  - written only at L198.
- `prizeToken`, `prizeTokenId`:
  - read at L404-L406, L332-L335, L422, L498 and L565;
  - written only at L200-L201.
- The reentrancy guard slot, one per clone.
- External state:
  - prize NFT custody, held in the prize contract;
  - the factory's `isRaffle` registry, consulted for this recipient only at creation.

Invariant couplings:

1. **Status picks the prize's single exit.**
   - `NftWon`: L334 sends it to the ticket owner who redeems.
   - `CashWon` or `Refunding`: L404 sends it to `sponsorRecipient`.

   Status being terminal is what enforces this; the shared flag only makes each path one-shot. In `NftWon`, if the
   winning ticket is never redeemed, the NFT stays in the clone, and this function cannot serve as a fallback
   (L397).
2. **`prizeClaimed` is a local record, not proof of custody.** It becomes `true` at L403, before the prize
   contract runs. On success it means only that L405 returned the recipient. Actual ownership is recorded in the
   prize contract.
3. **The same recipient is screened for USDC payouts but not for the NFT.**
   - USDC sent to `sponsorRecipient` is screened at payout time (L565). The NFT is not (L402-L404).
   - Suppose the recipient address becomes a registered clone after creation:
     - `releaseSponsorProceeds` reverts permanently, because `isRaffle` is never cleared;
     - this function still sends the NFT to that clone, where it sits outside that clone's accounting
       (L409-L411).
   - DESIGN.md L2 says: "Never move assets between raffle clones."
4. **No coupling to USDC accounting or tickets.** The function reads and writes none of the five terms of
   `accountedQuoteBalance()` (L469) and no ticket state. In `CashWon` it can run before or after settlement and
   redemption. In `Refunding` it can run before or after any refund.
5. **Liveness needs a caller and a cooperative prize contract.** Nothing triggers the function automatically, and
   it has no deadline. If L404 keeps reverting, the NFT stays in the clone and `prizeClaimed` stays `false`
   forever.

Documentation alignment:

- IRaffle.sol L354 and the event doc (L173-L180) match the code: the release happens after `CashWon` or
  `Refunding`, and the prize goes to the immutable sponsor recipient.
- IRaffle.sol L32 says "the sponsor may recover the prize NFT". The code sends it to `sponsorRecipient`, which can
  differ from `sponsor` (they are separate parameters, L182 and L197-L198), and anyone can trigger the release.

---

**Open Questions:**

- **Unclear; need to inspect the intended prize-token admission policy.**
  - IRaffle.sol L14-L15 says supported prizes are "honest, standards-compliant".
  - DESIGN.md L2 says arbitrary prize contracts are untrusted.

  The answer decides two things. First, whether the self-reported `ownerOf` at L405 is meant to be the delivery
  boundary. Second, whether transfer-restricted prizes are in scope: pausable collections, recipient blocklists,
  transfer validators, upgradeable proxies. Any of these can make L404 revert permanently for the fixed
  `sponsorRecipient`.
- **Unclear; need to inspect whether anything off-chain rejects a `sponsorRecipient` that is a not-yet-used CREATE
  address of this factory** (for example, the frontend or deployment tooling).
  - On-chain, the screen runs only at creation (L193, RaffleFactory.sol L166).
  - L404 does not screen again.
  - DESIGN.md L2 says "Never move assets between raffle clones".
- **Unclear; need to inspect the intended recovery if L404 keeps reverting in `CashWon` or `Refunding`.** The
  recipient is fixed at L198, status is terminal, and L24-L25 rules out a rescue path. In-scope code offers no
  alternative destination.
- **Unclear; need to inspect whether integrators or indexers treat `prizeClaimed` or `SponsorPrizeReleased` as
  proof of custody.** `prizeClaimed` reads `true` from L403 onward, before the prize contract runs, and the event
  rests on the prize contract's own answer at L405.
