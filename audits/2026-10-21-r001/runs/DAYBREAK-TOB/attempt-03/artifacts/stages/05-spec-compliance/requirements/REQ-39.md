## REQ-39 — Permissionless storage-only settlement and atomic owner redemption

> "Settlement is permissionless, storage-only; redemption requires current ticket owner, burns claim atomically, and must revert all effects on delivery failure."
> — DESIGN.md:L2, sentence 13

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** A standalone settlement must be callable without an actor-specific permission, prove the supplied winning ticket, and leave only internal result/accounting state (plus observability), without delivering the quote token or prize NFT and without invoking untrusted code. Redemption must use the ticket ledger's owner at the time of the call, reject every other caller, consume that ticket by burning it in the same transaction as delivery, and preserve none of the optional settlement, redemption flags, burn, or liability changes if NFT or quote-token delivery fails. The supplied checkable condition resolves “storage-only” as prohibiting token/NFT delivery and untrusted external calls, not as prohibiting the settlement event.

---

**Where enforcement lives:**

The public settlement entrypoint has only the shared reentrancy modifier and delegates to one private helper; it has no owner, sponsor, factory, role, or caller-identity gate (`target/packages/contracts/src/Raffle.sol:L304-L306`):

```solidity
// target/packages/contracts/src/Raffle.sol:L304-L306
function settleWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
    cashAmount = _settleWinningTicket(ticketId);
}
```

The helper accepts only a terminal result, verifies that the historical `uint128` ticket range contains the selected `uint128` winning entry, calculates the two result branches, and writes the allocation buckets and settlement markers. Its only use of `msg.sender` is as event data (`target/packages/contracts/src/Raffle.sol:L533-L558`).

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

`_requireWinningTicket` directly reads the locally stored range through `ticketRange` and compares it with `winningEntry`; neither function makes an external call (`target/packages/contracts/src/Raffle.sol:L451-L455,L579-L585`). Both percentage calculations call the internal pure `Math.mulDiv` implementation (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L216,L271-L277`). Thus the `NftWon` branch and the `CashWon` branch both finish settlement without a token/NFT transfer or recipient callback (`target/packages/contracts/src/Raffle.sol:L538-L558`).

Redemption optionally invokes that same private settlement helper, otherwise requires the recorded winning ticket, then reads the live ERC-721 owner and compares it with `msg.sender` before changing redemption state or burning (`target/packages/contracts/src/Raffle.sol:L309-L325`):

```solidity
// target/packages/contracts/src/Raffle.sol:L309-L325
function redeemWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
    if (winnerRedeemed) revert WinningTicketAlreadyRedeemed();
    Status result = status;
    if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);

    if (!settlementComplete) {
        _settleWinningTicket(ticketId);
    } else if (ticketId != winningTicketId) {
        revert WinningTicketMismatch(ticketId, winningTicketId);
    }

    address winner = ownerOf(ticketId);
    if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);

    winnerRecipient = winner;
    winnerRedeemed = true;
    _burn(ticketId);
```

This is a current-owner check rather than a purchaser or settlement-time-owner check: inherited `ownerOf` returns `_requireOwned(tokenId)`, which reads the current `_owners` entry and reverts if it is zero (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L60-L63,L420-L431`). Ticket transfers update that same owner mapping (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L125,L216-L245`).

The burn is also fully followed. `Raffle._update` permits the zero-address burn destination and delegates to the inherited update (`target/packages/contracts/src/Raffle.sol:L491-L502`). Inherited `_burn` calls `_update(address(0), ticketId, address(0))` and rejects a nonexistent token (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L292-L308`); the inherited update clears approval, decrements the prior owner's balance, stores the zero owner, and emits the burn transfer (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L245`).

After the burn, both delivery branches remain inside the same `redeemWinningTicket` invocation (`target/packages/contracts/src/Raffle.sol:L327-L345`):

```solidity
// target/packages/contracts/src/Raffle.sol:L327-L345
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
} else {
    cashAmount = winnerProceeds;
    if (cashAmount == 0) revert NoWinnerProceeds();
    winnerProceeds = 0;
    _transferQuote(winner, cashAmount);
}

emit WinningTicketRedeemed(ticketId, winner, result, cashAmount, deliveredPrizeToken, deliveredPrizeTokenId);
```

On the NFT branch, a reverting `transferFrom`/`ownerOf` call propagates because there is no `try/catch`, and a normal return that does not report the winner as owner triggers the explicit delivery-verification revert (`target/packages/contracts/src/Raffle.sol:L329-L337`). On the cash branch, `_transferQuote` performs its destination check and then calls `SafeERC20.safeTransfer` (`target/packages/contracts/src/Raffle.sol:L560-L567,L593-L604`). `safeTransfer` reverts on a false token result, while its low-level implementation bubbles a reverting token call (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L29-L37,L176-L199`). No delivery error is caught after the burn, so a failure reverts the entire external invocation, including an inline `_settleWinningTicket` call and every redemption write at `Raffle.sol:L323-L342`.

Both external entrypoints traverse `nonReentrant`. The modifier enters before the body and restores the guard only after the body returns (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L62-L73,L88-L105`). This prevents the prize or quote-token call from reentering either protected path while redemption is between burn and delivery. A fresh clone's initially zero guard slot is not a bypass: the guard rejects only the `ENTERED` value, then writes `ENTERED` before executing the body (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L50-L56,L88-L100`).

The construction path does not substitute another settlement implementation. The factory deploys and records one `Raffle` implementation in its constructor, then `createRaffle` clones that recorded address (`target/packages/contracts/src/RaffleFactory.sol:L85-L92,L97-L110`); the used `Clones.clone` bytecode fixes the delegate target supplied at deployment (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L23-L34,L47-L62`). The settlement helper itself is `private`, and its only two call sites are the standalone settlement and redemption paths (`target/packages/contracts/src/Raffle.sol:L304-L315,L533-L558`).

---

**Paths walked:**

- `settleWinningTicket` → `nonReentrant` → `_settleWinningTicket` → `_requireWinningTicket` → `ticketRange`, `NftWon`: validates terminal status and range, computes the protocol amount internally, writes settlement/accounting state, and emits the settlement event; no asset or untrusted call occurs (`target/packages/contracts/src/Raffle.sol:L304-L305,L533-L545,L551-L558`; `target/packages/contracts/src/Raffle.sol:L579-L585`). ✓
- `settleWinningTicket` → `nonReentrant` → `_settleWinningTicket`, `CashWon`: follows the same local proof, uses the second internal `Math.mulDiv`, writes `winnerProceeds`, and performs the same shared settlement writes without delivery (`target/packages/contracts/src/Raffle.sol:L304-L305,L533-L558`). ✓
- Settlement with an already-complete result, a nonterminal status, or a ticket range that misses `winningEntry`: reverts at the corresponding check before a successful settlement can persist (`target/packages/contracts/src/Raffle.sol:L534-L538,L579-L584`). ✓
- `redeemWinningTicket`, unsettled `NftWon`: performs settlement in the same invocation, reads current ownership, rejects a different caller, sets redemption state, burns, transfers the configured NFT, and verifies reported post-transfer ownership (`target/packages/contracts/src/Raffle.sol:L309-L337`). A caller or delivery revert unwinds the inline settlement too. ✓
- `redeemWinningTicket`, already-settled `NftWon`: first requires `ticketId == winningTicketId`, then applies the same current-owner, burn, transfer, and verification path (`target/packages/contracts/src/Raffle.sol:L314-L337`). ✓
- `redeemWinningTicket`, unsettled `CashWon`: inline settlement creates `winnerProceeds`; after the live-owner check and burn, redemption clears the whole winner bucket and calls the guarded quote-transfer helper (`target/packages/contracts/src/Raffle.sol:L314-L325,L338-L343,L546-L555,L560-L567`). SafeERC20 bubbles a token revert or rejects an explicit false return (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L29-L37,L176-L199`). ✓
- `redeemWinningTicket`, already-settled `CashWon`: requires the recorded ticket, then follows the same owner, burn, clear, and transfer path (`target/packages/contracts/src/Raffle.sol:L316-L325,L338-L343`). ✓
- Non-owner redemption when settlement was incomplete: `_settleWinningTicket` executes first, but `ownerOf` then identifies the live owner and `NotTicketOwner` reverts the same invocation, so the attempted caller leaves neither settlement nor redemption effects (`target/packages/contracts/src/Raffle.sol:L314-L325`). ✓
- Transfer after settlement but before redemption: the winner is obtained from inherited current `_owners` state at redemption, not stored during settlement, so only the transferee can pass the check (`target/packages/contracts/src/Raffle.sol:L316-L325`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L60-L63,L114-L125,L216-L245`). ✓
- NFT transfer revert, NFT ownership-query revert, or post-transfer owner mismatch: the external failure propagates or the explicit verification reverts after the burn; there is no catch (`target/packages/contracts/src/Raffle.sol:L323-L337`). ✓
- Quote transfer revert or false return: the SafeERC20 call bubbles/reverts after the burn and cleared liability, so those earlier writes do not survive (`target/packages/contracts/src/Raffle.sol:L323-L325,L338-L343,L560-L567`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L29-L37,L176-L199`). ✓
- Modifier/base/clone path: both entrypoints use the same storage reentrancy guard, the winning ticket's owner and burn come from the inherited ERC-721 ledger, and the factory's fixed-target clone reaches this concrete implementation (`target/packages/contracts/src/Raffle.sol:L28,L304-L309,L497-L502`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L62-L73,L88-L105`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L60-L63,L216-L245,L292-L308`; `target/packages/contracts/src/RaffleFactory.sol:L85-L92,L97-L110`). ✓

---

**Searched:**

- Frozen code closure → read all five production Solidity files and all 31 files named by `target/dependency-hashes.json`; SHA-256 verification returned `OK` for 31/31 dependency files and no mismatch.
- `settleWinningTicket|_settleWinningTicket|settlementComplete|SettlementAlreadyComplete|WinningTicketSettled` → 13 hits, all in `Raffle.sol` or `IRaffle.sol`: one implementation entrypoint, one private helper, its state/event/error/interface references, and no alternate implementation.
- `_settleWinningTicket\s*\(` → 3 hits: `Raffle.sol:L305` standalone-settlement call, `Raffle.sol:L315` inline-redemption call, and `Raffle.sol:L533` definition.
- `redeemWinningTicket\s*\(` → 2 hits: `Raffle.sol:L309` implementation and `IRaffle.sol:L338` interface declaration; no wrapper or other in-scope caller.
- Settlement helper `Raffle.sol:L533-L558`, vocabulary `transfer|safe|ownerOf|balanceOf|call|delegatecall|staticcall` → 0 hits. A member-invocation search found exactly two hits, both `Math.mulDiv` at `Raffle.sol:L540` and `L546`; the library function is internal pure (`Math.sol:L206-L277`).
- Settlement entrypoint/helper, vocabulary `msg.sender|ownerOf|only|role|auth|permission` → 1 hit, `msg.sender` only in `WinningTicketSettled` event data at `Raffle.sol:L557`; no actor gate.
- `NotTicketOwner|ownerOf\(|_burn\(|PrizeDeliveryVerificationFailed|PrizeAlreadyClaimed|NoWinnerProceeds|safeTransfer\(|transferFrom\(` → located the live-owner check, burn, both delivery branches, quote helper, ERC-721 base implementation, and SafeERC20 implementation; each was opened and followed rather than accepted by name.
- `_burn\s*\(` → 3 hits in the closure: redemption at `Raffle.sol:L325`, refund at `Raffle.sol:L364`, and the single inherited definition at `ERC721.sol:L303`; no alternate winning-claim burn implementation.
- Writes to `winnerRecipient|winnerRedeemed|prizeClaimed|winnerProceeds|settlementComplete|winningTicketId|unsettledPot|sponsorProceeds|protocolFees` → 14 assignment hits. Relevant settlement writes are `Raffle.sol:L548,L551-L555`; relevant redemption writes are `Raffle.sol:L323-L324,L331,L341`. The remaining writes belong to refund or independent sponsor/protocol release paths at `Raffle.sol:L297,L375-L405`; their own status and bucket checks do not create another winning-ticket redemption path (`target/packages/contracts/src/Raffle.sol:L375-L405`).
- `try|catch` in `Raffle.sol` → 0 hits; NFT and quote delivery failures are not swallowed.
- Alternative operation vocabulary in function names, `settle|finalize|allocate|distribute|payout|claim|redeem|withdraw|release|deliver` → 15 declaration/getter hits: the settlement/redeem pair, three independent release functions, their interface declarations, and state getters. No second finalization or winning-prize claim path was found.
- Direct low-level-call vocabulary in `Raffle.sol` → one executable `call`, only the unrelated native excess refund in `requestDraw` at `Raffle.sol:L267`; none in settlement. Redemption uses the typed prize call and SafeERC20 path already traced.
- `raffleImplementation\s*=|upgrade|implementation\s*=` → the only production assignments are construction of `Raffle` and the immutable assignment at `RaffleFactory.sol:L89-L91`; no production upgrade setter was found.
- Direct `Raffle.sol` function inventory → 29 declared functions were enumerated; inherited ERC-721, reentrancy, and VRF base functions were separately read. No unexamined direct settlement/redemption entrypoint remained.

---

**How the verdict was reached:** This is `implemented`, not `partial`, because both settlement result branches are local-only and permissionless, and all four successful redemption combinations (`NftWon`/`CashWon` × already settled/not yet settled) reach the same current-owner check and burn before their delivery-specific checks. Every delivery failure visible to the caller is uncaught and therefore rolls back the entire invocation, including an inline settlement. It is not `contradicted` because no settlement branch transfers an asset or invokes untrusted code, and no redemption branch permits a non-owner to succeed. It is not `stronger-than-spec`: the reentrancy guard and NFT post-transfer ownership verification support the required atomic delivery property rather than imposing a separate actor or claim restriction. The verdict is high-confidence because the private helper's complete caller set, both outcome branches, the inherited ownership/burn implementation, the modifier, the clone construction path, SafeERC20, and the entire pinned dependency closure were read.

---

**Open questions:**

- The concrete sponsor-selected prize-token implementation is not part of the supplied code closure. The in-scope guarantee is exact: a reverting NFT call, a reverting ownership query, or a reported owner other than the winner reverts all redemption effects (`target/packages/contracts/src/Raffle.sol:L323-L337`). A non-standard token that returns normally and falsely reports the winner as owner cannot be distinguished using the supplied `IERC721` interface (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L32-L39,L75-L91`). This limits claims about an off-scope token's honesty, but it does not leave an untraced branch in the Raffle's rollback enforcement.
