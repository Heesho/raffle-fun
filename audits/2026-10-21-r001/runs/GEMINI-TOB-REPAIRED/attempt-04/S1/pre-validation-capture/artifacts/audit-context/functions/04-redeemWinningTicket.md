## `redeemWinningTicket` in packages/contracts/src/Raffle.sol (L309-L346)

**Purpose:** Executes the single terminal winning claim for a resolved raffle (`Status.NftWon` or `Status.CashWon`). It lazily settles terminal quote-token liabilities if `settleWinningTicket` has not yet run, verifies that `msg.sender` is the current ERC-721 owner of the winning ticket, burns the winning ticket, records redemption state, and delivers either the escrowed ERC-721 prize (`Status.NftWon`) or the winner's 80% quote-token allocation (`Status.CashWon`). Without this function, the winning ticket holder cannot extract the won NFT or cash prize from the clone.

---

**Inputs & Assumptions:**
- `ticketId` (`uint256`): Sequential ERC-721 ticket identifier claimed as the winning ticket. Trust: **untrusted** (supplied by an arbitrary external caller).
- Implicit inputs:
  - `msg.sender` (`address`): Caller identity, required to match `ownerOf(ticketId)` (`L320-L321`). Trust: **untrusted**.
  - `winnerRedeemed` (`bool`, `Raffle.sol:L130`): Single-redemption guard read at `L310`.
  - `status` (`IRaffle.Status`, `Raffle.sol:L124`): Lifecycle and outcome state read at `L311` and inside `_settleWinningTicket` at `L535`.
  - `settlementComplete` (`bool`, `Raffle.sol:L127`): Lazy-settlement selector read at `L314` and inside `_settleWinningTicket` at `L534`.
  - `winningTicketId` (`uint256`, `Raffle.sol:L121`): Previously proven winning ticket ID read at `L316` when `settlementComplete` is `true`.
  - `winningEntry` (`uint128`, `Raffle.sol:L118`) and `_ticketRanges[ticketId]` (`TicketRange`, `Raffle.sol:L139`): Read inside `_requireWinningTicket` (`L580-L581`) on the `!settlementComplete` path.
  - `unsettledPot` (`uint256`, `Raffle.sol:L91`): Read inside `_settleWinningTicket` (`L539`) on the `!settlementComplete` path.
  - `_owners[ticketId]` (`address`, `ERC721.sol:L28`) and `_balances[winner]` (`uint256`, `ERC721.sol:L30`): Read and mutated by `ownerOf(ticketId)` (`L320`) and `_burn(ticketId)` (`L325`).
  - `prizeClaimed` (`bool`, `Raffle.sol:L133`), `prizeToken` (`IERC721`, `Raffle.sol:L70`), and `prizeTokenId` (`uint256`, `Raffle.sol:L73`): Read on the `Status.NftWon` path (`L330-L335`) and in `_transferQuote` (`L565`).
  - `winnerProceeds` (`uint256`, `Raffle.sol:L100`): Read on the `Status.CashWon` path (`L339`).
  - `factory` (`address`, `Raffle.sol:L55`), `quoteToken` (`IERC20`, `Raffle.sol:L58`), `i_vrfV2PlusWrapper` (`IVRFV2PlusWrapper`, `VRFV2PlusWrapperConsumerBase.sol:L39`): Immutables read in `_transferQuote` and `_isProtocolDestination` (`L565-L566`, `L598-L604`).
  - `REENTRANCY_GUARD_STORAGE` slot (`ReentrancyGuard.sol:L36-L37`): Read and written by the `nonReentrant` modifier (`L309`, `ReentrancyGuard.sol:L69-L73`).
- Preconditions:
  - Reentrancy lock is not in `ENTERED` (`2`) state. Enforced at entry by `nonReentrant` -> `_nonReentrantBefore()` -> `_nonReentrantBeforeView()` (`ReentrancyGuard.sol:L69-L100`).
  - `winnerRedeemed == false`. Enforced at `L310`.
  - `status` is `Status.NftWon` or `Status.CashWon`. Enforced at `L311-L312`. Transition into `Status.NftWon` or `Status.CashWon` is established exclusively by `fulfillRandomWords` (`Raffle.sol:L521`), which runs only when `status == Status.Drawing` (`L511`), a state reachable only via `requestDraw` (`L252`) after verifying `totalEntries != 0` (`L243`).
  - `ticketId` is the unique minted ticket whose inclusive range `[firstEntry, lastEntry]` contains `winningEntry`. Established on the `!settlementComplete` path by `_settleWinningTicket` -> `_requireWinningTicket` (`L315`, `L538`, `L579-L585`), and on the `settlementComplete` path by comparing `ticketId == winningTicketId` (`L316-L318`) after an earlier call to `settleWinningTicket` (`L304-L306`) ran `_settleWinningTicket` (`L533-L558`). Uniqueness of the covering ticket for any `winningEntry` in `[1, totalEntries]` is established by `buyEntries` (`L226-L232`), which assigns contiguous, non-overlapping ranges `[totalEntries + 1, totalEntries + entryCount]` to sequential ticket IDs `1..ticketCount`, and `fulfillRandomWords` (`L518-L519`), which bounds `winningEntry` to `[1, totalEntries]`.
  - `ticketId` currently exists (has not been burned) and `msg.sender == ownerOf(ticketId)`. Enforced at `L320-L321` via `ERC721.ownerOf` (`ERC721.sol:L61-L63`, `L426-L432`) and the `msg.sender != winner` check (`L321`).
  - On the `Status.NftWon` path:
    - `prizeClaimed == false`. Enforced at `L330`. Also structurally guaranteed before redemption because `releaseSponsorPrize` (`L395-L407`), the only other writer of `prizeClaimed`, reverts unless `status` is `Status.CashWon` or `Status.Refunding` (`L397-L399`).
    - `address(this)` currently owns `prizeTokenId` on `prizeToken`, and `prizeToken.transferFrom(address(this), winner, prizeTokenId)` transfers ownership to `winner` without reverting. Initial escrow is established at creation by `RaffleFactory.createRaffle` (`RaffleFactory.sol:L128-L131`) and `Raffle.onERC721Received` (`Raffle.sol:L416-L431`). Continued ownership by `address(this)` until `L334` and non-reverting execution of `transferFrom(address(this), winner, prizeTokenId)` for the current `winner` are assumed of the external `prizeToken` contract (`nothing found` in `Raffle.sol` can prevent an arbitrary external `prizeToken` from reverting, pausing, blacklisting `winner`, or moving tokens outside standard ERC-721 rules prior to `L334`; post-transfer ownership reported by `prizeToken.ownerOf(deliveredPrizeTokenId)` is checked at `L335-L337`).
    - `prizeToken.ownerOf(deliveredPrizeTokenId) == winner` truthfully reflects actual, persistent ownership of the NFT by `winner`. Checked via external `staticcall` at `L335-L337`, but truthfulness of `prizeToken.ownerOf` is assumed of the external `prizeToken` contract (`nothing found` on-chain beyond the return value check at `L335`).
  - On the `Status.CashWon` path:
    - `winnerProceeds > 0`. Enforced at `L340`. Established by `_settleWinningTicket` (`L546-L548`), where `grossPot = unsettledPot >= ENTRY_PRICE = 1_000_000` (established by `buyEntries` at `L223, L233` and `requestDraw` requiring `totalEntries > 0` at `L243`) and `cashAmount = Math.mulDiv(grossPot, 8000, 10_000) >= 800_000`.
    - `winner` is not a protocol destination rejected by `_isProtocolDestination(winner, address(prizeToken))`. Enforced at `L565` inside `_transferQuote`. Also screened when `winner` acquired `ticketId` in `Raffle._update` (`L498-L500`), with `_transferQuote` re-running `_isProtocolDestination` at redemption time (which additionally catches any contract address deployed and registered in `RaffleFactory.isRaffle` after `winner` received the ticket).
    - `quoteToken` holds at least `cashAmount` balance for `address(this)` and executes `transfer(winner, cashAmount)` with standard, fee-free, non-rebasing ERC-20 semantics and without blacklisting `winner`. Bounded liability allocation is established by `buyEntries` (`L223-L224, L233`) and `_settleWinningTicket` (`L539-L555`), where `protocolFee + sponsorAmount + cashAmount == grossPot`; standard fee-free behavior and non-blacklisting of `winner` by `quoteToken` are assumed of the canonical USDC contract (`nothing found` on-chain; `RaffleFactory.constructor` at `RaffleFactory.sol:L66-L78` checks only contract code presence and `decimals() == 6`).

---

**Outputs & Effects:**
- Return value:
  - `cashAmount` (`uint256`): Returns `0` when `status == Status.NftWon` (`L309`, `L329-L337`), or the redeemed `winnerProceeds` amount when `status == Status.CashWon` (`L339`).
- Storage writes:
  - `REENTRANCY_GUARD_STORAGE` slot (`ReentrancyGuard.sol:L36-L37`): Set to `ENTERED` (`2`) on entry (`ReentrancyGuard.sol:L99`) and `NOT_ENTERED` (`1`) on exit (`ReentrancyGuard.sol:L105`).
  - When `settlementComplete == false` on entry (`L314-L315`), `_settleWinningTicket` (`L533-L558`) writes:
    - `winnerProceeds = cashAmount` (`L548`, only when `status == Status.CashWon`, subsequently cleared to `0` at `L341`).
    - `settlementComplete = true` (`L551`).
    - `winningTicketId = ticketId` (`L552`).
    - `unsettledPot = 0` (`L553`).
    - `sponsorProceeds = sponsorAmount` (`L554`).
    - `protocolFees = protocolFee` (`L555`).
  - `winnerRecipient = winner` (`L323`).
  - `winnerRedeemed = true` (`L324`).
  - Inside `_burn(ticketId)` (`L325` -> `ERC721.sol:L303-L308` -> `Raffle.sol:L497-L502` -> `ERC721.sol:L216-L245`):
    - `_tokenApprovals[ticketId] = address(0)` (`ERC721.sol:L227, L398`).
    - `_balances[winner] -= 1` (`ERC721.sol:L230`).
    - `_owners[ticketId] = address(0)` (`ERC721.sol:L240`).
    - (`_ticketRanges[ticketId]` in `Raffle.sol:L139` is intentionally left intact in storage.)
  - When `status == Status.NftWon` (`L329-L337`):
    - `prizeClaimed = true` (`L331`).
  - When `status == Status.CashWon` (`L338-L343`):
    - `winnerProceeds = 0` (`L341`).
- External interactions:
  - When `status == Status.NftWon`:
    - `prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId)` (`L334`): External call to untrusted `prizeToken`.
    - `prizeToken.ownerOf(deliveredPrizeTokenId)` (`L335`): External `staticcall` to untrusted `prizeToken`.
  - When `status == Status.CashWon`:
    - `IRaffleFactory(factory).raffleImplementation()` (`L601` via `_transferQuote` -> `_isProtocolDestination`): External `staticcall` to trusted `factory` (if not short-circuited by earlier comparisons in `L599-L600`).
    - `IRaffleFactory(factory).isRaffle(winner)` (`L603` via `_transferQuote` -> `_isProtocolDestination`): External `staticcall` to trusted `factory` when `!unsafeDestination && winner.code.length != 0`.
    - `quoteToken.safeTransfer(winner, cashAmount)` (`L566` via `_transferQuote`, `SafeERC20.sol:L33-L37, L176-L200`): External `call` to trusted `quoteToken` with `IERC20.transfer(winner, cashAmount)`.
- Events emitted:
  - `WinningTicketSettled(ticketId, msg.sender, result, cashAmount, protocolFee, sponsorAmount)` (`L557`, only when `settlementComplete` was `false` on entry).
  - `Transfer(winner, address(0), ticketId)` (`ERC721.sol:L242`, emitted during `_burn(ticketId)` at `L325`).
  - `WinningTicketRedeemed(ticketId, winner, result, cashAmount, deliveredPrizeToken, deliveredPrizeTokenId)` (`L345`).
- Postconditions on success:
  - `settlementComplete == true` and `winningTicketId == ticketId`.
  - `winnerRedeemed == true` and `winnerRecipient == winner == msg.sender`.
  - `_owners[ticketId] == address(0)` and `_tokenApprovals[ticketId] == address(0)`.
  - `winnerProceeds == 0`.
  - If `status == Status.NftWon`: `prizeClaimed == true`, `cashAmount == 0`, and `prizeToken.ownerOf(prizeTokenId)` returned `winner` at `L335`.
  - If `status == Status.CashWon`: `prizeClaimed` is unchanged, `cashAmount > 0`, and `quoteToken.safeTransfer(winner, cashAmount)` succeeded at `L566`.

---

**Block-by-Block:**

```solidity
// L309-L312
function redeemWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
    if (winnerRedeemed) revert WinningTicketAlreadyRedeemed();
    Status result = status;
    if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);
```
- **What:** Acquires the reentrancy lock, rejects duplicate redemption calls, caches `status` into `result`, and rejects execution unless the raffle has resolved to `Status.NftWon` or `Status.CashWon`.
- **Why here:** Fail-fast guards before reading or mutating settlement or ERC-721 state.
- **Assumes:** `status` can only be `Status.NftWon` or `Status.CashWon` after `fulfillRandomWords` (`L521`) has recorded a valid `winningEntry` in `[1, totalEntries]` (`L518-L519`).
- **Establishes:** `_reentrancyGuardStorageSlot() == ENTERED` (`ReentrancyGuard.sol:L99`), `winnerRedeemed == false`, and `result == Status.NftWon || result == Status.CashWon`.
- **Depended on by:** `_settleWinningTicket` (`L315`), the outcome branch (`L329-L343`), and event emission (`L345`).

```solidity
// L314-L318
    if (!settlementComplete) {
        _settleWinningTicket(ticketId);
    } else if (ticketId != winningTicketId) {
        revert WinningTicketMismatch(ticketId, winningTicketId);
    }
```
- **What:** Either lazily settles the raffle using `ticketId` if `settlementComplete` is `false`, or verifies that `ticketId` matches the already-settled `winningTicketId`.
- **Why here:** Ensures `winningTicketId` is proven against `winningEntry` and terminal quote-token liabilities (`winnerProceeds`, `sponsorProceeds`, `protocolFees`) are populated in storage before ownership checks, ticket burning, and payout reads.
- **Assumes:** If `settlementComplete == true`, a prior call to `_settleWinningTicket` (`L533-L558`) already verified `_requireWinningTicket(winningTicketId)` (`L538`), set `winningTicketId` (`L552`), and allocated `winnerProceeds` (`L548`).
- **Establishes:** `settlementComplete == true`, `winningTicketId == ticketId`, `unsettledPot == 0`, and (if `result == Status.CashWon` and `!winnerRedeemed`) `winnerProceeds == Math.mulDiv(grossPot, 8000, 10_000)`.
- **Depended on by:** `ownerOf(ticketId)` (`L320`), `_burn(ticketId)` (`L325`), and `cashAmount = winnerProceeds` (`L339`).

```solidity
// L320-L321
    address winner = ownerOf(ticketId);
    if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);
```
- **What:** Resolves the current ERC-721 owner of `ticketId` (reverting if unminted or already burned) and requires `msg.sender` to be that exact owner.
- **Why here:** After confirming `ticketId` is the winning ticket (`L314-L318`), and before mutating redemption state or burning `ticketId` (`L323-L325`).
- **Assumes:** `_owners[ticketId]` (`ERC721.sol:L28`) accurately tracks bearer ownership of `ticketId`, and `winner` was screened against `_isProtocolDestination` when `ticketId` was minted or last transferred in `Raffle._update` (`L498-L500`).
- **Establishes:** `winner != address(0)` (`ERC721.sol:L428-L430`) and `msg.sender == winner == _owners[ticketId]`.
- **Depended on by:** `winnerRecipient = winner` (`L323`), `_burn(ticketId)` (`L325`), prize delivery (`L334-L335`, `L342`), and event emission (`L345`).

```solidity
// L323-L325
    winnerRecipient = winner;
    winnerRedeemed = true;
    _burn(ticketId);
```
- **What:** Records `winner` as `winnerRecipient`, marks `winnerRedeemed = true`, and burns the ERC-721 `ticketId` (clearing approvals, decrementing `_balances[winner]`, setting `_owners[ticketId] = address(0)`, and emitting `Transfer(winner, address(0), ticketId)`).
- **Why here:** Placed before the external calls in `L334-L335` and `L342` (checks-effects-interactions), so the winning ticket no longer exists and `winnerRedeemed` is already `true` before external execution begins.
- **Assumes:** `_balances[winner] >= 1` when `_owners[ticketId] == winner` (because `ERC721._update` at `ERC721.sol:L229-L231` performs `_balances[from] -= 1` inside an `unchecked` block; maintained by `ERC721._update` at `ERC721.sol:L230, L236` across all mints and transfers since `Raffle` never calls `_increaseBalance` or overrides `_ownerOf`).
- **Establishes:** `winnerRecipient == winner`, `winnerRedeemed == true`, `_owners[ticketId] == address(0)`, and `_tokenApprovals[ticketId] == address(0)`.
- **Depended on by:** Re-entry and post-redemption transfer protection across all subsequent calls (`L334-L343`) and external callers inspecting `winnerRedeemed`, `winnerRecipient`, or `ownerOf(ticketId)`.

```solidity
// L327-L337
    address deliveredPrizeToken = address(0);
    uint256 deliveredPrizeTokenId = 0;
    if (result == Status.NftWon) {
        if (prizeClaimed) revert PrizeAlreadyClaimed();
        prizeClaimed = true;
        deliveredPrizeToken = address(prizeToken);
        deliveredPrizeTokenId = prizeTokenId;
        prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId);
        if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) {
            revert PrizeDeliveryVerificationFailed(winner);
        }
```
- **What:** On the `Status.NftWon` branch, verifies and sets `prizeClaimed = true`, transfers the escrowed NFT to `winner` via `prizeToken.transferFrom`, and verifies that `prizeToken.ownerOf(deliveredPrizeTokenId) == winner`.
- **Why here:** Executes the external NFT transfer only after all internal state mutations (`winnerRecipient`, `winnerRedeemed`, `_burn(ticketId)`, `prizeClaimed`) have been committed to storage. Uses `transferFrom` rather than `safeTransferFrom` so contract winners that do not implement `IERC721Receiver` do not cause a callback revert, while `ownerOf` verification at `L335` checks post-transfer ownership.
- **Assumes:** `prizeToken` (`external-black-box`, untrusted) has not paused transfers, blacklisted `address(this)` or `winner`, or lost/reassigned `prizeTokenId` since `RaffleFactory.createRaffle` (`RaffleFactory.sol:L128-L131`), and `prizeToken.ownerOf(deliveredPrizeTokenId) == winner` truthfully implies `winner` holds durable ownership of the prize NFT (`nothing found` on-chain beyond the return-value check at `L335`).
- **Establishes:** `prizeClaimed == true`, `deliveredPrizeToken == address(prizeToken)`, `deliveredPrizeTokenId == prizeTokenId`, `cashAmount == 0`, and `prizeToken.ownerOf(prizeTokenId)` returned `winner` immediately after `transferFrom`.
- **Depended on by:** `WinningTicketRedeemed` event emission (`L345`) and atomicity of the redemption transaction (any revert in `L334-L337` rolls back `_burn(ticketId)`, `winnerRedeemed`, and lazy settlement).

```solidity
// L338-L343
    } else {
        cashAmount = winnerProceeds;
        if (cashAmount == 0) revert NoWinnerProceeds();
        winnerProceeds = 0;
        _transferQuote(winner, cashAmount);
    }
```
- **What:** On the `Status.CashWon` branch, loads `winnerProceeds` into the return variable `cashAmount`, reverts if `cashAmount == 0`, zeroes `winnerProceeds`, and transfers `cashAmount` of `quoteToken` to `winner` via `_transferQuote`.
- **Why here:** Zeroes `winnerProceeds` (`L341`) before the external calls inside `_transferQuote` (`L342` -> `L565-L566`), maintaining checks-effects-interactions and updating `accountedQuoteBalance()` (`L468-L470`) before `quoteToken.safeTransfer` executes.
- **Assumes:** `winner` is not a rejected protocol destination (`_isProtocolDestination` at `L565`), `quoteToken` holds at least `cashAmount` for `address(this)`, and `quoteToken` transfers `cashAmount` to `winner` without reverting, taking a fee, or blacklisting `winner` (`nothing found` on-chain for token-level blacklisting or fee-free behavior of `quoteToken`).
- **Establishes:** `winnerProceeds == 0`, `cashAmount > 0`, and `quoteToken.safeTransfer(winner, cashAmount)` completed without reverting.
- **Depended on by:** Function return value `cashAmount` (`L309`) and `WinningTicketRedeemed` event emission (`L345`).

```solidity
// L345-L346
    emit WinningTicketRedeemed(ticketId, winner, result, cashAmount, deliveredPrizeToken, deliveredPrizeTokenId);
}
```
- **What:** Emits `WinningTicketRedeemed` with the outcome-specific prize or cash fields and exits (triggering `_nonReentrantAfter()` at `ReentrancyGuard.sol:L72, L102-L106`).
- **Why here:** Emitted last after all storage updates and external asset transfers have succeeded.
- **Assumes:** Nothing beyond completion of the preceding blocks.
- **Establishes:** Off-chain indexers observe the completed redemption and `_reentrancyGuardStorageSlot()` is reset to `NOT_ENTERED` (`1`).
- **Depended on by:** Off-chain consumers and subsequent `nonReentrant` calls on the same clone.

---

**Cross-Function Dependencies:**

- **Callee `ReentrancyGuard.nonReentrant` (`_nonReentrantBefore` / `_nonReentrantAfter`, external-source-available, `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L118` and `StorageSlot.sol:L93-L97`):**
  - `_nonReentrantBefore` (`ReentrancyGuard.sol:L94-L100`) checks `_reentrancyGuardStorageSlot().getUint256Slot().value == ENTERED` (`2`) (`L89, L113`), reverting with `ReentrancyGuardReentrantCall()` if true, and writes `ENTERED` (`2`) (`L99`). Note that on a fresh ERC-1167 clone (`RaffleFactory.sol:L106`), the slot value before the first `nonReentrant` call is `0` rather than `NOT_ENTERED` (`1`), which still satisfies `value != ENTERED` (`2`).
  - `_nonReentrantAfter` (`ReentrancyGuard.sol:L102-L106`) writes `NOT_ENTERED` (`1`) on normal return.
  - Prevents any external call made during `redeemWinningTicket` (`prizeToken.transferFrom`, `prizeToken.ownerOf`, `quoteToken.safeTransfer`) from re-entering `buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, or `releaseSponsorPrize`.

- **Callee `Raffle._settleWinningTicket` (internal, `packages/contracts/src/Raffle.sol:L533-L558`):**
  - Invoked at `L315` only when `settlementComplete == false`.
  - Checks `if (settlementComplete) revert SettlementAlreadyComplete()` (`L534`) and `if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result)` (`L535-L536`).
  - Calls `_requireWinningTicket(ticketId)` (`L538` -> `L579-L585`), which calls `ticketRange(ticketId)` (`L451-L455`) to read `_ticketRanges[ticketId]` and reverts with `TicketDoesNotContainWinningEntry(ticketId, selectedEntry)` if `winningEntry < firstEntry || winningEntry > lastEntry` (`L582-L584`). Because `winningEntry >= 1` (`L518-L519`) and unminted ticket IDs have `firstEntry == 0, lastEntry == 0`, unminted ticket IDs always revert at `L582-L584`.
  - Computes `protocolFee = Math.mulDiv(grossPot, 500, 10_000)` (`L540`).
  - On `Status.NftWon` (`L543-L544`): sets `sponsorAmount = grossPot - protocolFee`, leaves `cashAmount = 0` and `winnerProceeds = 0`.
  - On `Status.CashWon` (`L545-L549`): sets `cashAmount = Math.mulDiv(grossPot, 8000, 10_000)`, `sponsorAmount = grossPot - protocolFee - cashAmount`, and writes `winnerProceeds = cashAmount` (`L548`).
  - Writes `settlementComplete = true` (`L551`), `winningTicketId = ticketId` (`L552`), `unsettledPot = 0` (`L553`), `sponsorProceeds = sponsorAmount` (`L554`), `protocolFees = protocolFee` (`L555`), and emits `WinningTicketSettled` (`L557`).

- **Callee `Math.mulDiv` (external-source-available, `packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L206-L277`):**
  - Invoked by `_settleWinningTicket` at `L540` (`y = 500`, `denominator = 10_000`) and `L546` (`y = 8000`, `denominator = 10_000`).
  - Computes `floor(x * y / denominator)` using 512-bit product `mul512(x, y)` (`Math.sol:L37-L46, L208`).
  - Reverts via `Panic.panic` (`Math.sol:L220`, `Panic.sol:L50-L56`) only if `denominator <= high`. Since `y < denominator` (`500 < 10_000` and `8000 < 10_000`), `high < y < denominator` holds for every `uint256 x`, so `Math.mulDiv` never panics at `L540` or `L546` and always returns a result `<= grossPot`.

- **Callee `ERC721.ownerOf` / `_requireOwned` / `_ownerOf` (external-source-available, `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L61-L63, L146-L148, L426-L432`):**
  - Invoked at `L320`. Reads `_owners[ticketId]` (`ERC721.sol:L147`) and reverts with `ERC721NonexistentToken(ticketId)` (`ERC721.sol:L429`) if `_owners[ticketId] == address(0)`.
  - Establishes that `ticketId` is currently minted and unburned, and returns its non-zero owner `winner`.

- **Callee `ERC721._burn` -> `Raffle._update` -> `ERC721._update` -> `ERC721._approve` (internal / external-source-available, `ERC721.sol:L303-L308`, `Raffle.sol:L497-L502`, `ERC721.sol:L216-L245`, `ERC721.sol:L383-L399`):**
  - Invoked at `L325` with `ticketId`.
  - `ERC721._burn` calls `_update(address(0), ticketId, address(0))` (`ERC721.sol:L304`).
  - `Raffle._update` (`Raffle.sol:L498-L501`) skips `_isProtocolDestination` because `to == address(0)` and delegates to `ERC721._update`.
  - `ERC721._update` (`ERC721.sol:L217-L244`) reads `from = _owners[ticketId]`, clears `_tokenApprovals[ticketId] = address(0)` via `_approve(address(0), ticketId, address(0), false)` (`L227, L398`), decrements `_balances[from] -= 1` inside `unchecked` (`L229-L231`), writes `_owners[ticketId] = address(0)` (`L240`), and emits `Transfer(from, address(0), ticketId)` (`L242`).
  - `ERC721._burn` checks `if (previousOwner == address(0)) revert ERC721NonexistentToken(tokenId)` (`ERC721.sol:L305-L307`).

- **Callee `prizeToken.transferFrom` and `prizeToken.ownerOf` (external-black-box, `IERC721` at `Raffle.sol:L334-L335`):**
  - Invoked on the `Status.NftWon` branch with `(address(this), winner, deliveredPrizeTokenId)` and `(deliveredPrizeTokenId)`.
  - `prizeToken` is sponsor-supplied and untrusted. Any revert, out-of-gas, or `ownerOf(deliveredPrizeTokenId) != winner` return value reverts the entire `redeemWinningTicket` call (rolling back the ticket burn and lazy settlement).
  - Re-entry into `Raffle` state-changing functions is blocked by `nonReentrant` (`L309`), and `ERC721` ticket transfer functions cannot move `ticketId` because `_owners[ticketId]` is already set to `address(0)` at `L325`.

- **Callee `Raffle._transferQuote` -> `Raffle._isProtocolDestination` -> `SafeERC20.safeTransfer` (internal / external-source-available / external-black-box, `Raffle.sol:L564-L567, L593-L605`, `SafeERC20.sol:L33-L37, L176-L200`):**
  - Invoked on the `Status.CashWon` branch at `L342` with `(winner, cashAmount)`.
  - `_isProtocolDestination(winner, address(prizeToken))` (`L593-L605`) rejects `address(this)`, `factory`, `address(quoteToken)`, `address(i_vrfV2PlusWrapper)`, `address(prizeToken)`, `IRaffleFactory(factory).raffleImplementation()` (`L599-L601`), and (when `winner.code.length != 0`) any address where `IRaffleFactory(factory).isRaffle(winner)` is `true` (`L602-L604`), reverting with `InvalidQuoteDestination(winner)` (`L565`).
  - `quoteToken.safeTransfer(winner, cashAmount)` (`SafeERC20.sol:L33-L37, L176-L200`) performs an assembly `call` to `quoteToken` with `IERC20.transfer(winner, cashAmount)` (`SafeERC20.sol:L184`), reverting if the call fails, returns `false`, or returns empty data when `extcodesize(quoteToken) == 0`.

- **Callers:**
  - External entrypoint (`L309`), callable only when `msg.sender == ownerOf(ticketId)` (`L320-L321`). No internal callers exist in `Raffle.sol` or `RaffleFactory.sol`.

- **Shared state:**
  - `status` (`Raffle.sol:L124`): Written by `constructor` (`L165`), `initialize` (`L205`), `onERC721Received` (`L428`), `requestDraw` (`L252`), `enableRefunds` (`L299`), and `fulfillRandomWords` (`L521`); read by `redeemWinningTicket` (`L311`) and `_settleWinningTicket` (`L535`).
  - `settlementComplete`, `winningTicketId`, `unsettledPot`, `sponsorProceeds`, `protocolFees` (`Raffle.sol:L91, L102, L105, L121, L127`): Written by `_settleWinningTicket` (`L551-L555`, reachable via `settleWinningTicket` at `L304-L306` or `redeemWinningTicket` at `L315`); `unsettledPot` is also written by `buyEntries` (`L233`) and `enableRefunds` (`L297`); `sponsorProceeds` is zeroed by `releaseSponsorProceeds` (`L378`); `protocolFees` is zeroed by `releaseProtocolFees` (`L388`).
  - `winnerProceeds` (`Raffle.sol:L100`): Written by `_settleWinningTicket` (`L548`), zeroed by `redeemWinningTicket` (`L341`), and read by `accountedQuoteBalance` (`L469`).
  - `winnerRecipient`, `winnerRedeemed` (`Raffle.sol:L97, L130`): Written exclusively by `redeemWinningTicket` (`L323-L324`).
  - `prizeClaimed` (`Raffle.sol:L133`): Written by `redeemWinningTicket` (`L331`, in `Status.NftWon`) and `releaseSponsorPrize` (`L403`, in `Status.CashWon` or `Status.Refunding`).
  - `_owners`, `_balances`, `_tokenApprovals` (`ERC721.sol:L28-L32`): Written by `buyEntries` (`L235`), `redeemWinningTicket` (`L325`), `refundTickets` (`L364`), and `ERC721` transfer/approval functions (`ERC721.sol:L93-L136`).

- **Invariant couplings:**
  - **Quote-token solvency invariant (`accountedQuoteBalance() <= quoteToken.balanceOf(address(this))`, `L468-L470`):** When `!settlementComplete`, `_settleWinningTicket` (`L539-L555`) partitions `unsettledPot` into `protocolFees + sponsorProceeds + winnerProceeds == grossPot` (with `winnerProceeds == 0` in `NftWon`) and zeroes `unsettledPot`, preserving `accountedQuoteBalance()`. On the `Status.CashWon` branch, `redeemWinningTicket` zeroes `winnerProceeds` (`L341`) and transfers exactly `cashAmount == winnerProceeds` (`L342`), reducing both `accountedQuoteBalance()` and the clone's USDC balance by `cashAmount`.
  - **Single prize / winner claim invariant:** `winnerRedeemed` (`L310, L324`) and `_burn(ticketId)` (`L325`) ensure the winning ticket is redeemed at most once. `prizeClaimed` (`L330-L331`, `L400-L403`) coupled with disjoint status requirements (`NftWon` in `redeemWinningTicket` vs. `CashWon` or `Refunding` in `releaseSponsorPrize`) ensures `prizeTokenId` is transferred out of the clone at most once.
  - **Independence of sponsor and treasury claims:** Because `redeemWinningTicket` can lazily call `_settleWinningTicket` (`L314-L315`), if `prizeToken.transferFrom` (`L334`) or `quoteToken.safeTransfer` (`L342`) reverts (e.g., because `winner` is blacklisted or `prizeToken` reverts), the lazy settlement in `redeemWinningTicket` also reverts. In that state, `settleWinningTicket(ticketId)` (`L304-L306`) remains independently callable without touching `prizeToken`, `quoteToken`, or `ownerOf(ticketId)`, allowing `sponsorProceeds` and `protocolFees` to be settled and released via `releaseSponsorProceeds` (`L375-L382`) and `releaseProtocolFees` (`L385-L392`) even if `redeemWinningTicket` reverts.

---

**Open Questions:**
- None; all internal and dependency callees (`ReentrancyGuard`, `ERC721`, `Math`, `SafeERC20`, `RaffleFactory`) were inspected in source, and external token contracts (`prizeToken`, `quoteToken`) are bounded by the black-box assumptions recorded above.
