## REQ-38 — Permissionless settlement

> "Settlement is permissionless, storage-only; redemption requires current ticket owner, burns claim atomically, and must revert all effects on delivery failure."
> — DESIGN.md:L2, sentence 13

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** For this requirement record, the supplied checkable proposition isolates the sentence's settlement access-control clause: after the settlement state preconditions hold, an ordinary call must not depend on the caller being the ticket owner, sponsor, factory, administrator, or an approved operator. Concretely, the raffle may require an unresolved terminal result and a ticket range containing the selected entry, but actor identity must not decide whether the standalone settlement call succeeds. The quoted sentence's separate storage-only and redemption guarantees are outside this record's supplied checkable scope.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/Raffle.sol:L304-L306
function settleWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
    cashAmount = _settleWinningTicket(ticketId);
}
```

- The standalone entrypoint is `external` and applies only `nonReentrant`; it accepts a ticket ID and forwards it to the private settlement helper without comparing `msg.sender` to any actor (`target/packages/contracts/src/Raffle.sol:L304-L306`).

```solidity
// target/packages/contracts/src/Raffle.sol:L533-L558
function _settleWinningTicket(uint256 ticketId) private returns (uint256 cashAmount) {
    if (settlementComplete) revert SettlementAlreadyComplete();
    Status result = status;
    if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);

    _requireWinningTicket(ticketId);
    uint256 grossPot = unsettledPot;
    uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
    uint256 sponsorAmount;

    if (result == Status.NftWon) {
        sponsorAmount = grossPot - protocolFee;
    } else {
        cashAmount = Math.mulDiv(grossPot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS);
        sponsorAmount = grossPot - protocolFee - cashAmount;
        winnerProceeds = cashAmount;
    }

    settlementComplete = true;
    winningTicketId = ticketId;
    unsettledPot = 0;
    sponsorProceeds = sponsorAmount;
    protocolFees = protocolFee;

    emit WinningTicketSettled(ticketId, msg.sender, result, cashAmount, protocolFee, sponsorAmount);
}
```

- The helper's gates are completion state, terminal result, and winning-range validity (`target/packages/contracts/src/Raffle.sol:L533-L540`). Both terminal-result branches then reach the same completion writes (`target/packages/contracts/src/Raffle.sol:L543-L555`). Its only use of `msg.sender` records the settler in the event; it is not a branch or comparison (`target/packages/contracts/src/Raffle.sol:L557`).

```solidity
// target/packages/contracts/src/Raffle.sol:L579-L584
function _requireWinningTicket(uint256 ticketId) private view {
    (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
    uint128 selectedEntry = winningEntry;
    if (selectedEntry < firstEntry || selectedEntry > lastEntry) {
        revert TicketDoesNotContainWinningEntry(ticketId, selectedEntry);
    }
}
```

- The delegated ticket proof compares the selected entry only with the stored historical range (`target/packages/contracts/src/Raffle.sol:L579-L584`). `ticketRange` reads `_ticketRanges` and does not read ERC-721 ownership or approvals (`target/packages/contracts/src/Raffle.sol:L451-L455`).

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72
modifier nonReentrant() {
    _nonReentrantBefore();
    _;
    _nonReentrantAfter();
}
```

- The only modifier on the entrypoint checks whether the fixed guard slot is already entered, writes `ENTERED`, and restores `NOT_ENTERED`; none of those branches reads caller identity (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L88-L105`). Its storage-slot accessor returns the fixed guard slot without an actor-dependent branch (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L112-L118`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:L91-L97`).

---

**Paths walked:**

- Canonical clone call path: `RaffleFactory.createRaffle` creates the clone with `Clones.clone`, initializes it, and registers it (`target/packages/contracts/src/RaffleFactory.sol:L105-L125`). The selected `Clones.clone` overload constructs the fixed ERC-1167 proxy and contains no caller-authorization comparison (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`). A call then reaches `Raffle.settleWinningTicket` → `nonReentrant` → `_settleWinningTicket` → `_requireWinningTicket` → `ticketRange` (`target/packages/contracts/src/Raffle.sol:L304-L305`, `L533-L540`, `L579-L580`, `L451-L455`). ✓
- First guard branch: if the guard is already entered, `nonReentrant` reverts based only on the guard slot; otherwise it enters, executes the body, and restores the slot (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L88-L105`). This execution-state guard is identical for every caller. ✓
- Already-settled branch: `settlementComplete == true` reverts every caller with `SettlementAlreadyComplete` (`target/packages/contracts/src/Raffle.sol:L533-L535`). This is a state precondition, not an actor gate. ✓
- Lifecycle branches: any status other than `NftWon` or `CashWon` reverts every caller; either terminal status proceeds (`target/packages/contracts/src/Raffle.sol:L535-L543`). The accepted callback is what writes `winningEntry` and chooses one of those terminal statuses (`target/packages/contracts/src/Raffle.sol:L509-L523`). ✓
- Candidate-ticket branches: `_requireWinningTicket` rejects a range that does not contain `winningEntry` and accepts a containing range without calling `ownerOf`, `_isAuthorized`, or an approval getter (`target/packages/contracts/src/Raffle.sol:L579-L584`). The underlying range getter reads only `_ticketRanges` (`target/packages/contracts/src/Raffle.sol:L451-L455`). ✓
- Result branches: `NftWon` computes the sponsor remainder; `CashWon` additionally computes and stores winner proceeds. Both converge on `settlementComplete`, `winningTicketId`, pot clearing, sponsor proceeds, protocol fees, and an event that records—rather than authorizes—`msg.sender` (`target/packages/contracts/src/Raffle.sol:L543-L557`). ✓
- Relevant type-bound path: ticket ranges use `uint128` endpoints (`target/packages/contracts/src/Raffle.sol:L33-L39`). Purchase rejects a `uint128` total-entry overflow before recording the sequential range (`target/packages/contracts/src/Raffle.sol:L215-L233`), and resolution derives a one-based entry and narrows it to `uint128` before choosing the terminal status (`target/packages/contracts/src/Raffle.sol:L518-L523`). These bounds determine range validity, not caller eligibility. ✓
- Caller path through redemption: `redeemWinningTicket` may call the same private settlement helper if settlement is incomplete, but its separate redemption flow subsequently requires the current owner (`target/packages/contracts/src/Raffle.sol:L309-L321`). That owner gate does not sit on, wrap, or replace the standalone `settleWinningTicket` entrypoint at `L304-L306`. ✓
- ERC-721 base authorization is not on the settlement call chain. The base checks owner/operator authority only when `_update` receives nonzero `auth` (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L164-L186`, `L216-L222`); standalone settlement neither calls `_update` nor reads `ownerOf` (`target/packages/contracts/src/Raffle.sol:L304-L305`, `L533-L558`, `L579-L584`). ✓
- Constructor and initialization path: the `Raffle` constructor fixes `factory` and locks the implementation's own storage, while `initialize` applies the factory check only to one-time clone setup (`target/packages/contracts/src/Raffle.sol:L155-L178`). The factory constructor fixes configuration and deploys the implementation without creating an owner/admin role (`target/packages/contracts/src/RaffleFactory.sol:L65-L91`). The inherited constructors initialize only the ERC-721 display fields, reentrancy slot, and VRF dependencies (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L39-L42`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L58-L60`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L40-L47`). None is consulted by the settlement helper as caller authority (`target/packages/contracts/src/Raffle.sol:L533-L558`). ✓

---

**Searched:**

- Scope integrity → exactly 5 production files plus the 31 paths in `target/dependency-hashes.json`; all 31 dependency SHA-256 values matched the manifest.
- `settleWinningTicket|_settleWinningTicket` across all 36 scoped files → 5 matching lines: interface declaration at `target/packages/contracts/src/interfaces/IRaffle.sol:L331`; direct entrypoint/call at `target/packages/contracts/src/Raffle.sol:L304-L305`; redemption's private-helper call at `L315`; private helper definition at `L533`. No other wrapper or caller was found.
- `function[[:space:]]+settleWinningTicket` → 2 matching lines: the interface declaration and the implementation (`target/packages/contracts/src/interfaces/IRaffle.sol:L331`; `target/packages/contracts/src/Raffle.sol:L304`).
- `msg.sender|_msgSender(` across all 36 scoped files → 37 matching lines. Within the complete settlement chain, the sole occurrence is the event argument at `target/packages/contracts/src/Raffle.sol:L557`; the entrypoint, state allocator, range validator, and range getter contain no caller comparison (`L304-L305`, `L533-L555`, `L579-L584`, `L451-L455`).
- `msg.sender (==|!=) (sponsor|factory|protocolTreasury)` and the reversed operands → 2 hits: the factory-only initializer at `target/packages/contracts/src/Raffle.sol:L178` and the sponsor's exceptional pre-end empty-raffle refund path at `L282`; neither is reachable from settlement.
- `onlyOwner|onlyRole|hasRole|AccessControl|Ownable|tx.origin` across all 36 scoped files → 0 hits.
- `admin(istrator)?` across all 36 scoped files → 1 hit, the non-enforcing contract comment at `target/packages/contracts/src/Raffle.sol:L25`.
- `^\s*modifier\s+` across all 31 dependencies → 2 hits, `nonReentrant` and `nonReentrantView`, both in `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69` and `L83`; settlement applies only the former (`target/packages/contracts/src/Raffle.sol:L304`).
- `ownerOf(` across all 36 scoped files → 11 matching lines. The first-party calls are prize escrow verification, redemption, refunds, and prize-delivery verification (`target/packages/contracts/src/RaffleFactory.sol:L129`; `target/packages/contracts/src/Raffle.sol:L320`, `L335`, `L359`, `L405`); none occurs in standalone settlement at `target/packages/contracts/src/Raffle.sol:L304-L306` or its helper at `L533-L558`.
- `_requireWinningTicket`, `ticketRange(`, and `_ticketRanges` → `_requireWinningTicket` has exactly its call and definition (`target/packages/contracts/src/Raffle.sol:L538`, `L579`); the relevant `ticketRange` calls are refund and settlement proof plus the getter declaration/definition (`target/packages/contracts/src/Raffle.sol:L362`, `L451`, `L580`; `target/packages/contracts/src/interfaces/IRaffle.sol:L373`); `_ticketRanges` appears only at declaration, purchase write, and getter read (`target/packages/contracts/src/Raffle.sol:L139`, `L232`, `L452`).
- Constructor sweep across all 36 scoped files → 5 constructors: `RaffleFactory`, `Raffle`, `ERC721`, `ReentrancyGuard`, and `VRFV2PlusWrapperConsumerBase` (`target/packages/contracts/src/RaffleFactory.sol:L65`; `target/packages/contracts/src/Raffle.sol:L155`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L39`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L58`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L40`). Each was read through its state writes; none establishes settlement caller authority.
- `permissionless|Anyone may execute|anyone|settler` → comments and event documentation described permissionlessness (`target/packages/contracts/src/Raffle.sol:L25`; `target/packages/contracts/src/interfaces/IRaffle.sol:L117-L124`, `L327-L331`), but these names/comments were not treated as enforcement; the verdict rests on the traced executable paths above.

---

**How the verdict was reached:** This is `implemented`, not `partial`, because the direct external settlement entrypoint reaches both `NftWon` and `CashWon` success branches through the same caller-independent completion, lifecycle, and range gates (`target/packages/contracts/src/Raffle.sol:L304-L305`, `L533-L557`, `L579-L584`). No owner, sponsor, factory, treasury, administrator, or operator check is present in that call chain, and the exhaustive scoped searches found no wrapper that adds one. The owner comparison at `target/packages/contracts/src/Raffle.sol:L320-L321` belongs to the distinct redemption entrypoint; a non-owner does not need that path because the standalone settlement entrypoint remains available at `L304-L306`. This is not `stronger-than-spec`: `nonReentrant` constrains nested execution solely by a guard-slot value and does not authorize one actor over another (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L88-L105`). The terminal-status, incomplete-settlement, and winning-range checks are the settlement state preconditions contemplated by the supplied checkable proposition (`target/packages/contracts/src/Raffle.sol:L533-L540`, `L579-L584`).

---

**Open questions:**

- None for the access-control proposition checked in this record.
