## REQ-43 — Permissionless settlement and atomic redemption

> "Settlement is permissionless, storage-only; redemption requires current ticket owner, burns claim atomically, and must revert all effects on delivery failure."
> — DESIGN.md:L2, sentence 13

**Verdict:** implemented · confidence: medium

---

**What this demands of an implementation:** Any address must be able to prove the winning ticket and allocate the terminal liabilities without moving an asset. Redemption must use the ticket's owner at redemption time—not the original buyer or an approved operator—as the recipient and authorized caller. A successful redemption must consume that ticket and the corresponding NFT or cash claim in the same transaction. If NFT or cash delivery fails after settlement, accounting writes, redemption flags, the ticket burn, token-side effects, and emitted logs made by that redemption must all be reverted.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/Raffle.sol:L304-L305
function settleWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
    cashAmount = _settleWinningTicket(ticketId);
}

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

- The external settlement entry has no caller or ownership condition; its only modifier is `nonReentrant` (`target/packages/contracts/src/Raffle.sol:L304-L305`). The modifier itself only checks and writes the guard storage slot around the body (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L94-L105`).
- The allocator checks terminal status and winning-range containment, calculates the two result branches, and writes only raffle accounting/result storage before emitting the settlement log (`target/packages/contracts/src/Raffle.sol:L533-L558`). Its range callee reads `_ticketRanges` (`target/packages/contracts/src/Raffle.sol:L451-L455`, `L579-L584`), and `Math.mulDiv` is an internal pure routine (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L216`). There is no token transfer or other external call on either settlement branch.

```solidity
// target/packages/contracts/src/Raffle.sol:L309-L345
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
}
```

- `ownerOf(ticketId)` resolves the inherited current-owner mapping and reverts for a burned or nonexistent ticket (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L61-L63`, `L146-L148`, `L426-L431`). Redemption then requires exact equality between that current owner and `msg.sender`; approval is insufficient (`target/packages/contracts/src/Raffle.sol:L320-L321`).
- The owner/recipient write, redeemed flag, and ticket burn precede either delivery (`target/packages/contracts/src/Raffle.sol:L323-L342`). The success event is after delivery and, on the NFT branch, after the ownership postcondition (`target/packages/contracts/src/Raffle.sol:L334-L345`).
- Raffle's `_update` override permits the zero-address burn and delegates it to the inherited ledger (`target/packages/contracts/src/Raffle.sol:L497-L502`). The inherited update clears approval, decrements the prior owner's balance, writes the owner to zero, and emits the burn transfer; `_burn` additionally rejects a nonexistent ticket (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L244`, `L303-L307`).
- On the NFT branch, a reverting `transferFrom`, a reverting or malformed `ownerOf`, or an owner value other than `winner` produces an uncaught revert (`target/packages/contracts/src/Raffle.sol:L329-L337`). Because settlement (when needed), redemption writes, the burn, the external transfer, and verification are in the same call, that revert rolls back the whole redemption call.

```solidity
// target/packages/contracts/src/Raffle.sol:L339-L342
cashAmount = winnerProceeds;
if (cashAmount == 0) revert NoWinnerProceeds();
winnerProceeds = 0;
_transferQuote(winner, cashAmount);

// target/packages/contracts/src/Raffle.sol:L564-L566
function _transferQuote(address to, uint256 amount) private {
    if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);
    quoteToken.safeTransfer(to, amount);
}

// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L33-L36
function safeTransfer(IERC20 token, address to, uint256 value) internal {
    if (!_safeTransfer(token, to, value, true)) {
        revert SafeERC20FailedOperation(address(token));
    }
}
```

- On the cash branch, the claim is read and checked before being zeroed and delivered (`target/packages/contracts/src/Raffle.sol:L339-L342`). `SafeERC20` executes the call with revert bubbling enabled, bubbles token revert data, and returns failure for false or malformed nonempty return data (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L176-L199`); `safeTransfer` converts that failure into a revert (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L33-L36`). The prior zeroing, burn, flags, and any same-transaction auto-settlement therefore roll back on an observable cash-delivery failure.

---

**Paths walked:**

- Any caller → `settleWinningTicket` → `_settleWinningTicket` → `_requireWinningTicket` → `ticketRange`: the caller is not compared to any role or owner; an `NftWon` result allocates protocol and sponsor storage, while a `CashWon` result additionally allocates `winnerProceeds` (`target/packages/contracts/src/Raffle.sol:L304-L305`, `L533-L558`, `L579-L584`). Both paths make no external call. ✓
- Unsettled result → `redeemWinningTicket` → `_settleWinningTicket` → current-owner check: a nonowner's later `NotTicketOwner` revert also rolls back the settlement performed earlier in that same call (`target/packages/contracts/src/Raffle.sol:L314-L321`, `L533-L558`). ✓
- Previously settled result → supplied ticket differs from `winningTicketId`: redemption reverts before ownership, burn, or delivery (`target/packages/contracts/src/Raffle.sol:L314-L318`). ✓
- Previously settled result → correct ticket → `ownerOf`: only the live owner can proceed; an approved operator cannot redeem, and a nonexistent/burned ticket makes inherited `ownerOf` revert (`target/packages/contracts/src/Raffle.sol:L320-L321`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L61-L63`, `L426-L431`). ✓
- Current owner → local effects → `_burn`: `winnerRecipient` and `winnerRedeemed` are written, then the ERC-721 ticket ledger and approval are consumed before either asset delivery (`target/packages/contracts/src/Raffle.sol:L323-L325`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L244`, `L303-L307`). ✓
- `NftWon` → prize already claimed: the post-burn check reverts, so the earlier owner/flag/burn writes are not retained (`target/packages/contracts/src/Raffle.sol:L323-L331`). ✓
- `NftWon` → `transferFrom` reverts, `ownerOf` reverts, or `ownerOf != winner`: the uncaught external failure or explicit verification error reverts the redemption after the provisional burn and `prizeClaimed` write (`target/packages/contracts/src/Raffle.sol:L329-L337`). ✓
- `CashWon` → zero cash claim: `NoWinnerProceeds` reverts after the provisional burn, restoring it and the redemption flags (`target/packages/contracts/src/Raffle.sol:L323-L325`, `L339-L341`). ✓
- `CashWon` → quote token reverts or returns an unsuccessful value: SafeERC20 bubbles or raises a revert after `winnerProceeds` was provisionally cleared (`target/packages/contracts/src/Raffle.sol:L339-L342`, `L564-L566`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L33-L36`, `L176-L199`). ✓
- Either successful delivery branch → `WinningTicketRedeemed`: the event is reached only after the NFT ownership postcondition or successful SafeERC20 call (`target/packages/contracts/src/Raffle.sol:L329-L345`). ✓
- Reentrant delivery attempt → another guarded raffle entrypoint: both settlement and redemption use the shared guard, whose entered state rejects nested guarded calls (`target/packages/contracts/src/Raffle.sol:L304-L309`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L88-L105`). A rejection propagating out of the delivery call reverts the same redemption. ✓

---

**Searched:**

- Scope enumeration → read all five first-party production files and every one of the 31 Solidity dependencies named by `target/dependency-hashes.json`; recomputed SHA-256 values matched all 31 manifest entries (`31` entries, `0` mismatches).
- `redeemWinningTicket` across the scoped Solidity files → 2 hits: the ABI declaration at `target/packages/contracts/src/interfaces/IRaffle.sol:L338` and the concrete entrypoint at `target/packages/contracts/src/Raffle.sol:L309`; no in-scope wrapper or caller.
- `settleWinningTicket|_settleWinningTicket` across the scoped Solidity files → 5 hits: ABI declaration (`IRaffle.sol:L331`), external entrypoint and its helper call (`Raffle.sol:L304-L305`), the auto-settlement call (`Raffle.sol:L315`), and the private helper definition (`Raffle.sol:L533`).
- `try|catch` in `Raffle.sol` → 0 hits; neither asset-delivery failure is caught or converted into a successful return.
- Writes matching `winnerRecipient =|winnerRedeemed =|prizeClaimed =|winnerProceeds =` in `Raffle.sol` → 6 hits: redemption writes at L323-L324, L331, and L341; cash allocation at L548; the only other `prizeClaimed` write is the sponsor-prize path at L403.
- `_burn(` across Raffle and its ERC-721 base → 3 hits: inherited definition (`ERC721.sol:L303`), winning redemption (`Raffle.sol:L325`), and refunds (`Raffle.sol:L364`). The refund caller is gated to `Refunding`, while redemption requires `NftWon` or `CashWon` (`Raffle.sol:L309-L312`, `L349-L350`).
- `_transferQuote` in `Raffle.sol` → 5 hits: winner delivery at L342, refund at L369, sponsor release at L380, treasury release at L390, and the helper definition at L564; only L342 is the winning-cash redemption route.
- `prizeToken.transferFrom|prize.safeTransferFrom` in first-party source → 3 hits: winner delivery (`Raffle.sol:L334`), sponsor-prize release (`Raffle.sol:L404`), and factory escrow into the raffle (`RaffleFactory.sol:L128`). The sponsor release accepts only `CashWon` or `Refunding`, so it is not an alternate NFT-winner redemption path (`Raffle.sol:L395-L405`).
- `function ownerOf` across the scoped Solidity files → 2 hits: the IERC-721 declaration and the inherited OpenZeppelin implementation (`IERC721.sol:L39`; `ERC721.sol:L61`). Raffle does not override it.
- Vocabulary sweep in `Raffle.sol` plus `IRaffle.sol`: `atomic|atomically` → 4 hits; `deliver|delivery` → 14; `redeem|redemption` → 22; `claim|liabilit` → 47; `settle|settlement` → 31; `owner|ownership` → 33; `burn` → 23; `transfer|payout` → 33. Relevant hits reduce to the entrypoints, state writes, inherited burn, and two delivery callees traced above.
- Modifiers, bases, constructors, and type-bound callees → read `ReentrancyGuard`, inherited `ERC721`, `SafeERC20`, `Math.mulDiv`, factory clone construction/initialization, and the ERC-721/ERC-20 interfaces in full. None adds an alternate redemption entrypoint, caller restriction on settlement, caught failure, or branch around delivery.

---

**How the verdict was reached:** This is `implemented`, not `partial`, because the standalone settlement entry is actor-agnostic and its complete `NftWon` and `CashWon` branches only validate and allocate local liabilities. Every successful redemption path converges on the same live-owner equality check and inherited burn before splitting into two delivery branches. The NFT branch propagates the transfer/read failure and explicitly rejects a failed ownership postcondition; the cash branch propagates token reverts and rejects unsuccessful return values. There is no `try/catch`, low-level success-swallowing wrapper, alternate winner-delivery entrypoint, or caller path bypassing those checks. Since same-call auto-settlement, claim writes, burn, delivery, verification, and final event all remain in one uncaught transaction, any observable delivery revert unwinds all of those effects.

Confidence is medium rather than high because the frozen target contains interfaces, not the concrete sponsor-selected prize or deployed canonical quote-token bytecode. The source-level rollback behavior is established, but a nonconforming prize that returns success and falsely reports `ownerOf(ticketId) == winner`, or a nonconforming quote token that falsely reports transfer success, is not distinguishable locally. The factory checks code, a claimed ERC-721 interface, initial reported custody, and activation (`target/packages/contracts/src/RaffleFactory.sol:L127-L134`, `L154-L177`), while the interface documents honest ERC-721 and standard quote-token semantics as dependency assumptions (`target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`). This limitation does not create a source-visible failure branch in the supplied implementation, so it lowers confidence rather than changing the verdict.

---

**Open questions:**

- Need the deployed sponsor-selected prize implementation to establish that `transferFrom` and `ownerOf` truthfully expose delivery for that token; the supplied target can establish only the uncaught call and postcondition behavior at `target/packages/contracts/src/Raffle.sol:L329-L337`.
- Need the deployed canonical quote-token implementation or deployment provenance to establish exact transfer semantics beyond SafeERC20's call/return checks; the local path and declared dependency assumption are at `target/packages/contracts/src/Raffle.sol:L339-L342`, `L560-L566`, and `target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`.
- `target/` has no Git metadata, so the supplied frozen SHA `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155` could not be independently resolved with `git rev-parse`; all 31 dependency files did match the pinned hash manifest.
