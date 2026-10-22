## `refundTickets` in packages/contracts/src/Raffle.sol (L349-L372)

**Purpose:** Burns a caller-supplied batch of 1 to 100 ERC-721 range tickets owned by `msg.sender` when the raffle is in `Status.Refunding`, decrements `remainingRefundLiability` by the aggregate entry value of those tickets (`aggregateEntries * ENTRY_PRICE`), and transfers that exact quote-token refund amount to `msg.sender`. Without this function, ticket holders would have no mechanism to recover the USDC principal escrowed in `remainingRefundLiability` after a raffle transitions to `Status.Refunding` via `enableRefunds`.

---

**Inputs & Assumptions:**
- `ticketIds` (`uint256[] calldata`): Caller-supplied array of sequential ERC-721 ticket identifiers to burn and refund (`L349`). Trust: **untrusted** (supplied by any external caller; validated for batch bounds at `L351-L354`, existence and non-duplication via `ownerOf` and `_burn` at `L359` and `L364`, and caller ownership at `L360`).
- Implicit inputs:
  - `msg.sender` (`address`): Caller identity checked against `ownerOf(ticketId)` (`L359-L360`), used as the quote-token refund recipient (`L369`), and indexed in `TicketsRefunded` (`L371`). Trust: **untrusted** (Ticket Owner).
  - `REENTRANCY_GUARD_STORAGE` (`bytes32` slot `0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00`): Read and written by the `nonReentrant` modifier (`packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L36-L37, L69-L73, L88-L106`).
  - `status` (`IRaffle.Status`, `L124`): Current lifecycle status read by `_requireStatus(Status.Refunding)` (`L350, L573-L575`).
  - `_owners` (`mapping(uint256 tokenId => address)`, `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L28`): Read by `ownerOf(ticketId)` (`L359`) and read/cleared by `_burn(ticketId)` (`L364`).
  - `_ticketRanges` (`mapping(uint256 ticketId => TicketRange)`, `L139`): Read by `ticketRange(ticketId)` (`L362, L451-L455`) to compute each ticket's entry count.
  - `ENTRY_PRICE` (`uint256`, `L44`, `packages/contracts/src/libraries/RaffleConstants.sol:L20`): Constant `1_000_000` (1 USDC in 6-decimal raw units) multiplied by `aggregateEntries` (`L367`).
  - `remainingRefundLiability` (`uint256`, `L94`): Current aggregate unrefunded quote-token liability read and decremented at `L368` and reread at `L370`.
  - `factory` (`address`, immutable `L55`), `quoteToken` (`IERC20`, immutable `L58`), `i_vrfV2PlusWrapper` (`IVRFV2PlusWrapper`, immutable in `packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L29`), and `prizeToken` (`IERC721`, `L70`): Read by `_transferQuote` (`L369, L564-L567`) and `_isProtocolDestination` (`L593-L605`).
- Preconditions:
  - The reentrancy lock at `REENTRANCY_GUARD_STORAGE` is not `ENTERED` (`2`). Enforced on entry by `nonReentrant` (`ReentrancyGuard.sol:L69-L73, L88-L100`).
  - `status == Status.Refunding`. Enforced on entry by `_requireStatus(Status.Refunding)` (`L350, L573-L575`). On an initialized clone, `Status.Refunding` is established only by `enableRefunds` (`L299`). (On the implementation contract, `status` is set to `Status.Refunding` in `constructor` at `L165`, where no tickets are ever minted so `ownerOf` at `L359` always reverts.)
  - `1 <= ticketIds.length <= 100` (`RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE`). Enforced on entry at `L351-L354`.
  - Every `ticketId` in `ticketIds` exists (was minted in `buyEntries` at `L235` and has not yet been burned), is distinct within `ticketIds`, and has `_owners[ticketId] == msg.sender`. Enforced per element by `ownerOf(ticketId)` (`L359`, `ERC721.sol:L61-L63, L426-L431`), `if (msg.sender != owner) revert NotTicketOwner(...)` (`L360`), and immediate in-loop `_burn(ticketId)` (`L364`, `ERC721.sol:L303-L308`), which sets `_owners[ticketId] = address(0)` (`ERC721.sol:L240`) so any duplicate `ticketId` later in `ticketIds` fails `ownerOf(ticketId)` at `L359` with `ERC721NonexistentToken(ticketId)`.
  - For every existing `ticketId`, its stored `_ticketRanges[ticketId]` satisfies `1 <= firstEntry <= lastEntry` and `uint256(lastEntry) - uint256(firstEntry) + 1` equals the `entryCount` paid when the ticket was minted. Established by `buyEntries` (`L218-L233`), which rejects `entryCount == 0` (`L218`), checks `entryCount <= type(uint128).max - totalEntries` (`L219-L221`), sets `firstEntry = totalEntries + 1` (`L226`) and `lastEntry = totalEntries + entryCount` (`L227`), and writes `_ticketRanges[ticketId]` once (`L232`). No function modifies or deletes `_ticketRanges` after `buyEntries`.
  - `remainingRefundLiability >= amount`. Enforced by Solidity 0.8.36 checked subtraction at `L368`, and established across the lifecycle because each minted ticket adds `(lastEntry - firstEntry + 1) * ENTRY_PRICE` to `unsettledPot` in `buyEntries` (`L223, L226-L233`), `enableRefunds` transfers the entire `unsettledPot` into `remainingRefundLiability` once when entering `Status.Refunding` (`L296-L299`), and each ticket can be burned at most once (`L364`).
  - `msg.sender` is not a prohibited protocol destination under `_isProtocolDestination(msg.sender, address(prizeToken))`. Enforced by `_transferQuote` at `L565` (and previously enforced on ticket mint/transfer in `Raffle._update` at `L498-L500`).
  - `quoteToken` holds at least `amount` balance for `address(this)` and executes a standard, fee-free ERC-20 transfer to `msg.sender` without reverting or returning `false`. Assumed of the trusted canonical 6-decimal `quoteToken` (`RaffleFactory.sol:L65-L85`, `Raffle.sol:L560-L566`) and checked for call success by `SafeERC20.safeTransfer` (`SafeERC20.sol:L33-L37, L176-L200`).

---

**Outputs & Effects:**
- Return value: `amount` (`uint256`), the raw 6-decimal quote-token units refunded to `msg.sender`, equal to `aggregateEntries * ENTRY_PRICE` (`L349, L367`).
- State writes:
  - `REENTRANCY_GUARD_STORAGE`: Set to `ENTERED` (`2`) before execution and `NOT_ENTERED` (`1`) after execution (`ReentrancyGuard.sol:L99, L105`).
  - For each `ticketId` in `ticketIds` (via `_burn(ticketId)` at `L364` -> `Raffle._update` at `L497-L502` -> `ERC721._update` at `ERC721.sol:L216-L245`):
    - `_tokenApprovals[ticketId]` set to `address(0)` (`ERC721.sol:L227, L398`).
    - `_balances[msg.sender]` decremented by `1` per burned ticket (`ERC721.sol:L230`).
    - `_owners[ticketId]` set to `address(0)` (`ERC721.sol:L240`).
    - Note: `_ticketRanges[ticketId]` (`L139`), `ticketCount` (`L88`), and `totalEntries` (`L85`) are **not** modified on burn.
  - `remainingRefundLiability` (`L94`): Decremented by `amount` (`L368`).
- External interactions:
  - `IRaffleFactory(factory).raffleImplementation()` staticcall in `_isProtocolDestination` (`L601`).
  - `IRaffleFactory(factory).isRaffle(msg.sender)` staticcall in `_isProtocolDestination` if `msg.sender` is not one of the direct addresses and `msg.sender.code.length != 0` (`L602-L604`).
  - `quoteToken.safeTransfer(msg.sender, amount)` (`L369, L566`, `SafeERC20.sol:L33-L37, L176-L200`): Low-level `call` to `quoteToken` with `IERC20.transfer(msg.sender, amount)`.
- Events emitted:
  - `IERC721.Transfer(msg.sender, address(0), ticketId)` emitted once per burned ticket inside `ERC721._update` (`ERC721.sol:L242`).
  - `IRaffle.TicketsRefunded(msg.sender, ticketQuantity, aggregateEntries, amount, liabilityAfter)` emitted once at `L371`.
- Postconditions on success:
  - All `ticketIds` in the batch have `_owners[ticketId] == address(0)` and `_tokenApprovals[ticketId] == address(0)` and cannot be refunded, transferred, or redeemed again.
  - `remainingRefundLiability` is reduced by `aggregateEntries * ENTRY_PRICE`.
  - `accountedQuoteBalance()` (`L468-L470`) is reduced by `amount`.
  - `msg.sender` has received `amount` of `quoteToken` (under standard fee-free `quoteToken` semantics).

---

**Block-by-Block:**

```solidity
// L349-L354
    function refundTickets(uint256[] calldata ticketIds) external override nonReentrant returns (uint256 amount) {
        _requireStatus(Status.Refunding);
        uint256 ticketQuantity = ticketIds.length;
        if (ticketQuantity == 0 || ticketQuantity > RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE) {
            revert InvalidTicketBatchSize(ticketQuantity, RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE);
        }
```
- **What:** Acquires the `nonReentrant` lock, verifies that the raffle is in `Status.Refunding`, and enforces that `ticketIds` contains between 1 and `MAX_REFUND_TICKET_BATCH_SIZE` (`100`) elements.
- **Why here:** Fails fast before any storage reads of per-ticket mappings or state mutations, and bounds the loop iteration count at `L357` to at most 100 tickets.
- **Assumes:** `RaffleConstants.MAX_REFUND_TICKET_BATCH_SIZE` (`100` at `RaffleConstants.sol:L27`) is small enough that 100 loop iterations fit within block gas limits.
- **Establishes:** `status == Status.Refunding`, reentrancy lock is `ENTERED` (`2`), and `1 <= ticketQuantity <= 100`.
- **Depended on by:** The loop at `L357-L365` (which relies on `ticketQuantity >= 1` so `aggregateEntries > 0` and on `status == Status.Refunding` so `remainingRefundLiability` was initialized by `enableRefunds` at `L296-L299`).

```solidity
// L356-L365
        uint256 aggregateEntries = 0;
        for (uint256 index; index < ticketQuantity; ++index) {
            uint256 ticketId = ticketIds[index];
            address owner = ownerOf(ticketId);
            if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner);

            (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
            aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;
            _burn(ticketId);
        }
```
- **What:** Iterates through each supplied `ticketId`, verifies that it currently exists and is owned by `msg.sender`, adds its inclusive entry count `lastEntry - firstEntry + 1` to `aggregateEntries`, and burns the ERC-721 ticket.
- **Why here:** Burning each ticket inside the loop (`L364`) immediately sets `_owners[ticketId] = address(0)` (`ERC721.sol:L240`) before the next loop iteration and before any external call at `L369`. This guarantees that duplicate `ticketId` entries in `ticketIds` revert at `ownerOf(ticketId)` (`L359`) on the second occurrence, without requiring an auxiliary deduplication array or sorting requirement.
- **Assumes:** For every minted `ticketId` where `ownerOf(ticketId)` succeeds, `_ticketRanges[ticketId]` holds `1 <= firstEntry <= lastEntry <= totalEntries` such that `uint256(lastEntry) - uint256(firstEntry) + 1` does not underflow and equals the `entryCount` purchased in `buyEntries` (`L218-L233`).
- **Establishes:** Every `ticketId` in `ticketIds` was distinct, existed on entry, was owned by `msg.sender`, and is now burned (`_owners[ticketId] == address(0)`). `aggregateEntries` equals the exact sum of entries across those burned tickets, with `1 <= aggregateEntries <= totalEntries <= type(uint128).max`.
- **Depended on by:** Refund calculation and liability deduction at `L367-L368`, quote transfer at `L369`, and event emission at `L371`.

```solidity
// L367-L371
        amount = aggregateEntries * ENTRY_PRICE;
        remainingRefundLiability -= amount;
        _transferQuote(msg.sender, amount);
        uint256 liabilityAfter = remainingRefundLiability;
        emit TicketsRefunded(msg.sender, ticketQuantity, aggregateEntries, amount, liabilityAfter);
```
- **What:** Computes the quote-token refund `amount`, deducts `amount` from `remainingRefundLiability`, transfers `amount` of `quoteToken` to `msg.sender`, and emits `TicketsRefunded`.
- **Why here:** Deducting `remainingRefundLiability` at `L368` after all ticket burns (`L364`) and before the external token call in `_transferQuote` (`L369`) follows checks-effects-interactions so all contract storage (`_owners`, `_balances`, `_tokenApprovals`, `remainingRefundLiability`) reflects the completed refund before external execution begins.
- **Assumes:** `remainingRefundLiability >= amount` (established by `buyEntries` at `L223, L233` and `enableRefunds` at `L296-L298`), and `quoteToken` holds at least `amount` for `address(this)` and transfers without fee or loss.
- **Establishes:** `remainingRefundLiability` is decreased by `amount`, `msg.sender` is screened against `_isProtocolDestination` and receives `amount` of `quoteToken`, and `TicketsRefunded` records the post-refund liability.
- **Depended on by:** Off-chain indexers and solvency accounting via `accountedQuoteBalance()` (`L468-L470`) and `remainingRefundLiability` (`L94`).

---

**Cross-Function Dependencies:**

- **Callee `ReentrancyGuard.nonReentrant` (`_nonReentrantBefore` / `_nonReentrantAfter`, external-source-available, `packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73, L88-L118`):**
  - Reads `REENTRANCY_GUARD_STORAGE` (`0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00`) via `StorageSlot.getUint256Slot` (`StorageSlot.sol:L89-L93`).
  - Reverts with `ReentrancyGuardReentrantCall()` if the slot value is `ENTERED` (`2`) (`ReentrancyGuard.sol:L89-L91`).
  - Sets the slot value to `ENTERED` (`2`) on entry (`ReentrancyGuard.sol:L99`) and `NOT_ENTERED` (`1`) on exit (`ReentrancyGuard.sol:L105`).
  - Note: On a freshly deployed ERC-1167 clone (`RaffleFactory.sol:L106`), the slot is `0` prior to the first `nonReentrant` call because `ReentrancyGuard.constructor` (`ReentrancyGuard.sol:L58-L60`) ran on the implementation contract; `0 != ENTERED` (`2`) still passes `_nonReentrantBeforeView()`.
- **Callee `_requireStatus` (internal, `packages/contracts/src/Raffle.sol:L573-L575`):**
  - Single check: `if (status != expected) revert InvalidStatus(status);` (`L574`).
  - Establishes `status == Status.Refunding` on the only non-reverting path.
- **Callee `ERC721.ownerOf` (external-source-available, `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L61-L63, L146-L148, L426-L431`):**
  - Calls `_requireOwned(tokenId)` (`ERC721.sol:L62`), which reads `owner = _ownerOf(tokenId)` (`_owners[tokenId]`, `ERC721.sol:L147, L427`).
  - If `owner == address(0)`, reverts with `ERC721NonexistentToken(tokenId)` (`ERC721.sol:L428-L430`).
  - Establishes `owner != address(0)` and `owner == _owners[ticketId]` on the non-reverting path.
- **Callee `ticketRange` (internal, `packages/contracts/src/Raffle.sol:L451-L455`):**
  - Reads `_ticketRanges[ticketId]` from storage and returns `(range.firstEntry, range.lastEntry)` (`L452-L454`).
  - Does not itself validate that `ticketId` exists or that `firstEntry <= lastEntry`; `refundTickets` relies on `ownerOf(ticketId)` (`L359`) to prove `ticketId` was minted by `buyEntries` (`L235`), and on `buyEntries` (`L218, L226-L232`) to have written `1 <= firstEntry <= lastEntry`.
- **Callee `ERC721._burn` -> `Raffle._update` -> `ERC721._update` (external-source-available / internal override, `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L245, L303-L308` and `packages/contracts/src/Raffle.sol:L497-L502`):**
  - `ERC721._burn(ticketId)` calls `_update(address(0), ticketId, address(0))` (`ERC721.sol:L304`).
  - `Raffle._update(address(0), ticketId, address(0))` checks `if (to != address(0) && _isProtocolDestination(to, address(prizeToken)))` (`Raffle.sol:L498`); because `to == address(0)`, `_isProtocolDestination` is skipped on burns and control passes to `super._update(address(0), ticketId, address(0))` (`Raffle.sol:L501`).
  - `ERC721._update` reads `from = _ownerOf(ticketId)` (`ERC721.sol:L217`), skips `_checkAuthorized` because `auth == address(0)` (`ERC721.sol:L220`), clears `_tokenApprovals[ticketId] = address(0)` via `_approve(address(0), ticketId, address(0), false)` (`ERC721.sol:L227, L383-L399`), decrements `_balances[from] -= 1` in an `unchecked` block (`ERC721.sol:L229-L231`), sets `_owners[ticketId] = address(0)` (`ERC721.sol:L240`), emits `Transfer(from, address(0), ticketId)` (`ERC721.sol:L242`), and returns `from` (`ERC721.sol:L244`).
  - `ERC721._burn` checks `if (previousOwner == address(0)) revert ERC721NonexistentToken(ticketId)` (`ERC721.sol:L305-L307`).
  - Establishes `_owners[ticketId] == address(0)`, preventing any subsequent `ownerOf(ticketId)` or `_burn(ticketId)` on the same `ticketId` from succeeding.
- **Callee `_transferQuote` (internal, `packages/contracts/src/Raffle.sol:L564-L567`):**
  - Calls `_isProtocolDestination(to, address(prizeToken))` (`L565`); if true, reverts with `InvalidQuoteDestination(to)` (`L565`).
  - Calls `quoteToken.safeTransfer(to, amount)` (`L566`).
- **Callee `_isProtocolDestination` (internal, `packages/contracts/src/Raffle.sol:L593-L605`):**
  - Evaluates whether `destination` equals `address(this)`, `factory`, `address(quoteToken)`, `address(i_vrfV2PlusWrapper)`, `prizeToken_`, or `IRaffleFactory(factory).raffleImplementation()` (`L599-L601`).
  - If none of those match and `destination.code.length != 0`, queries `IRaffleFactory(factory).isRaffle(destination)` (`L602-L604`).
  - Depends on external view calls to the trusted `factory` (`RaffleFactory.sol:L43, L54`).
- **Callee `SafeERC20.safeTransfer` / `IERC20.transfer` on `quoteToken` (external-source-available wrapper at `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L33-L37, L176-L200` invoking external-black-box `quoteToken`):**
  - `SafeERC20._safeTransfer` encodes `IERC20.transfer.selector`, `to`, and `value` and executes `call(gas(), token, 0, 0x00, 0x44, 0x00, 0x20)` (`SafeERC20.sol:L180-L184`).
  - Succeeds if `call` returns `true` and either the 32-byte return data equals `1` (`SafeERC20.sol:L187`) or `returndatasize() == 0` with `extcodesize(token) > 0` (`SafeERC20.sol:L196`); otherwise reverts with the bubbled revert payload (`SafeERC20.sol:L189-L192`) or `SafeERC20FailedOperation(address(token))` (`SafeERC20.sol:L35`).
  - `quoteToken` is trusted canonical 6-decimal USDC (`RaffleFactory.sol:L65-L85`). If `quoteToken.transfer(msg.sender, amount)` reverts (for example, if `msg.sender` is blocklisted by USDC), the entire `refundTickets` call reverts; note that ERC-721 ticket transfers remain enabled in `Status.Refunding` (`Raffle._update` at `L497-L502` does not gate on `status`).
- **Callers:**
  - External entrypoint (`L349`); no internal callers exist in `Raffle.sol` or `RaffleFactory.sol`.
- **Shared state:**
  - `status` (`L124`): Written by `constructor` (`L165`), `initialize` (`L205`), `onERC721Received` (`L428`), `requestDraw` (`L252`), `enableRefunds` (`L299`), and `fulfillRandomWords` (`L521`). Read by `refundTickets` (`L350`), `buyEntries` (`L215`), `requestDraw` (`L241`), `enableRefunds` (`L279, L289`), `redeemWinningTicket` (`L311`), `releaseSponsorPrize` (`L396`), `onERC721Received` (`L422`), `fulfillRandomWords` (`L511`), and `_settleWinningTicket` (`L535`).
  - `remainingRefundLiability` (`L94`): Initialized to `unsettledPot` by `enableRefunds` (`L298`), decremented by `refundTickets` (`L368`), and read by `accountedQuoteBalance` (`L469`).
  - `_ticketRanges` (`L139`): Written by `buyEntries` (`L232`), read by `ticketRange` (`L451-L455`) via `refundTickets` (`L362`) and `_requireWinningTicket` (`L580`).
  - `ERC721` state (`_owners`, `_balances`, `_tokenApprovals`, `_operatorApprovals` in `ERC721.sol:L28-L34`): Minted by `buyEntries` (`L235`), transferred/approved by `ERC721` public methods routed through `Raffle._update` (`L497-L502`), and burned by `redeemWinningTicket` (`L325`) or `refundTickets` (`L364`).
- **Invariant couplings:**
  - **Solvency / Liability Conservation in `Status.Refunding`:** On transition to `Status.Refunding` in `enableRefunds` (`L296-L299`), `unsettledPot` is zeroed and `remainingRefundLiability` is set to the prior `unsettledPot == totalEntries * ENTRY_PRICE`, while `winnerProceeds`, `sponsorProceeds`, and `protocolFees` remain `0` (because `_settleWinningTicket` can only run in `Status.NftWon` or `Status.CashWon` at `L535-L536`). Every unburned ticket `t` in `[1, ticketCount]` represents `entries(t) = lastEntry(t) - firstEntry(t) + 1` entries, and the sum of `entries(t) * ENTRY_PRICE` over all currently unburned tickets equals `remainingRefundLiability` (`accountedQuoteBalance()` at `L468-L470`). `refundTickets` preserves this invariant by burning each refunded ticket in `ticketIds` (`L364`) and subtracting the exact sum of `entries(t) * ENTRY_PRICE` from `remainingRefundLiability` (`L367-L368`) while transferring that exact amount of `quoteToken` out (`L369`).

---

**Open Questions:**
- None. Every callee and state dependency of `refundTickets` is in scope and inspected.
