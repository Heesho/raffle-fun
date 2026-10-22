## REQ-41 — redemption irreversibly consumes the winning ticket claim

> "Settlement is permissionless, storage-only; redemption requires current ticket owner, burns claim atomically, and must revert all effects on delivery failure."
> — DESIGN.md:L2, sentence 13

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** A standalone settlement must be callable without an actor authorization check and must only identify the winning ticket and allocate liabilities. A redemption that returns successfully must (1) have been called by that ticket's current owner, (2) destroy or irreversibly consume the ticket claim before returning, and (3) leave no path to redeem it again. If either the NFT or cash delivery fails, the burn, redemption latch, optional inline settlement, and all other redemption writes must revert together.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/Raffle.sol:L304-L305
function settleWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
    cashAmount = _settleWinningTicket(ticketId);
}

// target/packages/contracts/src/Raffle.sol:L533-L557
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

- The external settlement entrypoint has no caller-role or ownership gate; its only modifier is `nonReentrant` (`Raffle.sol:L304-L306`). The private path checks terminal status and the supplied range, calculates amounts, and writes the liability/identity fields without making an asset-transfer call (`Raffle.sol:L533-L557`). `_requireWinningTicket` only reads the stored range and compares it with `winningEntry` (`Raffle.sol:L579-L584`), while the invoked `Math.mulDiv` overload is pure (`Math.sol:L206-L277`).

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

- Both terminal-result branches pass through the same current-ownership comparison, set the one-way `winnerRedeemed` latch, and call `_burn(ticketId)` before delivery (`Raffle.sol:L309-L342`). A second call is rejected by the first guard (`Raffle.sol:L310`), and the only assignment to `winnerRedeemed` sets it to `true` (`Raffle.sol:L324`).
- The NFT branch calls the configured prize contract directly and then verifies its reported owner; a transfer revert, an `ownerOf` revert, or an owner mismatch propagates/reverts because none is caught (`Raffle.sol:L329-L337`). The cash branch clears `winnerProceeds` and calls `_transferQuote`, which invokes `safeTransfer` (`Raffle.sol:L339-L342`, `L560-L566`). `SafeERC20.safeTransfer` reverts on a rejected operation, and its low-level implementation bubbles a token revert (`SafeERC20.sol:L33-L37`, `L176-L199`). Consequently, ordinary EVM transaction rollback includes the earlier settlement, latch, balance, approval, and ownership writes.

```solidity
// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L303-L307
function _burn(uint256 tokenId) internal {
    address previousOwner = _update(address(0), tokenId, address(0));
    if (previousOwner == address(0)) {
        revert ERC721NonexistentToken(tokenId);
    }
}

// target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L244
function _update(address to, uint256 tokenId, address auth) internal virtual returns (address) {
    address from = _ownerOf(tokenId);
    // ... optional authorization check ...
    if (from != address(0)) {
        _approve(address(0), tokenId, address(0), false);
        unchecked {
            _balances[from] -= 1;
        }
    }
    if (to != address(0)) {
        unchecked {
            _balances[to] += 1;
        }
    }
    _owners[tokenId] = to;
    emit Transfer(from, to, tokenId);
    return from;
}
```

- The inherited burn dispatches through Raffle's `_update` override; a zero burn destination bypasses only the nonzero-destination screen and then calls the OpenZeppelin update (`Raffle.sol:L491-L502`). That update clears the approval, decrements the former owner's balance, and stores the zero address as owner (`ERC721.sol:L216-L244`). Later `ownerOf(ticketId)` calls `_requireOwned`, which reverts when `_ownerOf` returns zero (`ERC721.sol:L61-L63`, `L426-L431`).
- The redemption entrypoint is `nonReentrant` (`Raffle.sol:L309`). The modifier marks the shared guard entered before the body and rejects nested protected calls until the body completes (`ReentrancyGuard.sol:L69-L72`, `L88-L105`), so neither the prize nor quote-token external call can reenter a second redemption during delivery.

---

**Paths walked:**

- `settleWinningTicket` → `_settleWinningTicket` → `_requireWinningTicket`: any caller can submit a candidate ticket; the path validates status/range and writes only settlement identity and quote-liability fields before emitting the settlement event (`Raffle.sol:L304-L305`, `L533-L557`, `L579-L584`). ✓
- Unsettled `NftWon` redemption → inline `_settleWinningTicket` → settled ticket owner check → `winnerRedeemed = true` → inherited `_burn` → prize `transferFrom` → post-transfer `ownerOf` verification (`Raffle.sol:L309-L337`; `ERC721.sol:L216-L244`, `L303-L307`). A returning call has no ticket owner and has its latch set. ✓
- Pre-settled `NftWon` redemption → recorded `winningTicketId` equality check → the same owner/latch/burn/delivery path (`Raffle.sol:L314-L337`). No pre-settled branch bypasses the burn. ✓
- Unsettled `CashWon` redemption → inline settlement populates `winnerProceeds` → owner/latch/burn → proceeds cleared → `_transferQuote`/`SafeERC20.safeTransfer` (`Raffle.sol:L314-L325`, `L339-L342`, `L546-L555`, `L560-L566`; `SafeERC20.sol:L33-L37`, `L176-L199`). ✓
- Pre-settled `CashWon` redemption → recorded-ticket check → the same owner/latch/burn/cash-delivery path (`Raffle.sol:L314-L325`, `L339-L342`). No pre-settled branch bypasses the burn. ✓
- NFT delivery failure: a transfer revert or ownership-query revert propagates; a reported owner other than the winner triggers `PrizeDeliveryVerificationFailed` (`Raffle.sol:L334-L337`). Since the call does not catch these failures, the earlier inline settlement, latch, and burn are rolled back. ✓
- Cash delivery failure: `_transferQuote` reaches `SafeERC20.safeTransfer`; a bubbled token revert or an unsuccessful return triggers a revert (`Raffle.sol:L342`, `L564-L566`; `SafeERC20.sol:L33-L37`, `L176-L199`). The earlier inline settlement, latch, proceeds clearing, and burn are rolled back. ✓
- Repeat/reentrant redemption: a later top-level call stops at `winnerRedeemed`, while a nested protected call during either external delivery stops at the entered reentrancy guard (`Raffle.sol:L309-L310`; `ReentrancyGuard.sol:L69-L72`, `L88-L105`). ✓

---

**Searched:**

- Full scope read → all five first-party production Solidity files and all 31 dependency files enumerated by `target/dependency-hashes.json`; all 31 dependency SHA-256 digests matched the manifest.
- `redeemWinningTicket\s*\(` across that 36-file scope → 2 hits: the implementation at `Raffle.sol:L309` and interface declaration at `IRaffle.sol:L338`; no wrapper or in-scope caller provides an alternate redemption path.
- `_burn\s*\(` → 3 hits: inherited definition at `ERC721.sol:L303`, winning redemption at `Raffle.sol:L325`, and refund burning at `Raffle.sol:L364`.
- `winnerRedeemed\s*=` → 1 hit, `Raffle.sol:L324` setting it to `true`; `winnerRedeemed\s*=\s*false` → 0 hits.
- `_owners\[tokenId\]\s*=` → 1 hit, `ERC721.sol:L240`; the burn supplies `to = address(0)` at `ERC721.sol:L304`.
- `function (_?settleWinningTicket)\s*\(` → 3 hits: interface declaration `IRaffle.sol:L331`, external implementation `Raffle.sol:L304`, and private implementation `Raffle.sol:L533`.
- `_requireWinningTicket\s*\(` → 2 hits: its settlement call at `Raffle.sol:L538` and definition at `Raffle.sol:L579`; its body performs only the historical-range comparison (`Raffle.sol:L579-L584`).
- `(modifier nonReentrant|redeemWinningTicket\(uint256 ticketId\).*nonReentrant)` → 3 hits: the redemption modifier use at `Raffle.sol:L309`, `nonReentrant` at `ReentrancyGuard.sol:L69`, and the separately named `nonReentrantView` at `ReentrancyGuard.sol:L83`.
- Mint/remint sweep (`_mint`, `_safeMint`, `ticketCount`) → the only first-party ticket mint call is the purchase path at `Raffle.sol:L235`; it derives the ID as `ticketCount + 1` and increments `ticketCount` (`Raffle.sol:L228-L231`). There is no post-burn remint call, and purchases themselves require `Active` status (`Raffle.sol:L215`).
- Ownership/delivery vocabulary (`ownerOf`, `NotTicketOwner`, `transferFrom`, `safeTransfer`, `delivery`) → the relevant hits resolve to the current-owner gate at `Raffle.sol:L320-L321`, NFT transfer/verification at `L334-L337`, quote transfer helper at `L560-L566`, inherited ERC-721 ownership/burn logic at `ERC721.sol:L61-L63`, `L216-L244`, `L303-L307`, and `SafeERC20` failure handling at `SafeERC20.sol:L33-L37`, `L176-L199`.

---

**How the verdict was reached:** The direct-settlement path is permissionless and contains no asset transfer. Every successful redemption path—pre-settled or inline-settled, NFT or cash—converges before branching on an exact current-owner check, a one-way redemption latch, and the inherited ERC-721 burn. The burn removes ownership, and the latch independently rejects every later redemption. Delivery is attempted only afterward, with failures propagating or being converted to reverts, so EVM rollback restores every preceding write. This is `implemented`, not `partial`, because no terminal-result or settlement-state branch skips consumption; it is not `stronger-than-spec` because the redundant latch and burn enforce the same one-time claim property rather than imposing a distinct undocumented restriction.

---

**Open questions:**

- No open question affects the checkable property that every returning redemption irreversibly consumes the local ticket claim. The concrete external prize and quote-token implementations are outside the target, so their truthfulness beyond the visible call/return and `ownerOf` checks cannot be independently established; this does not create a local path that returns successfully with the raffle ticket still owned or redeemable.
