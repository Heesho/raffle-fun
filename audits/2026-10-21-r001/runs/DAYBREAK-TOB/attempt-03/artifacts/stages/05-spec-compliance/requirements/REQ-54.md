## REQ-54 — Untrusted ticket recipients are contained

> "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted."
> — `DESIGN.md:L2, sentence 16`

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** Under the requirement record's supplied checkable criterion, an EOA or adversarial contract may be the initial or later owner of a ticket, and the raffle must not rely on that address accepting a callback, retaining the ticket, refraining from reentry, or successfully receiving its eventual payout. A failed callback or payout must not leave the ticket ledger, range accounting, liability buckets, or redemption flags partly committed. A recipient may decline to exercise or may strand its own bearer claim; the safety requirement is that doing so cannot corrupt or block settlement of the raffle or other independently claimable liabilities. The supplied checkable criterion selects this ticket-recipient facet of the compound quoted sentence; canonical-dependency identity and arbitrary-prize semantic honesty are not separate verdict grounds in this record.

---

**Where enforcement lives:**

Initial ticket delivery is performed only after the purchase inputs and overflow are checked, and the entire purchase is under the shared reentrancy modifier:

```solidity
// target/packages/contracts/src/Raffle.sol:L209-L236
function buyEntries(address recipient, uint128 entryCount)
    external
    override
    nonReentrant
    returns (uint256 ticketId)
{
    _requireStatus(Status.Active);
    if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
    if (recipient == address(0)) revert InvalidRecipient();
    if (entryCount == 0) revert ZeroEntryCount();
    if (entryCount > type(uint128).max - totalEntries) {
        revert TotalEntriesOverflow(totalEntries, entryCount);
    }

    uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
    quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);

    uint128 firstEntry = totalEntries + 1;
    uint128 lastEntry = totalEntries + entryCount;
    ticketId = uint256(ticketCount) + 1;

    totalEntries = lastEntry;
    ++ticketCount;
    _ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
    unsettledPot += grossAmount;

    _safeMint(recipient, ticketId);
    emit TicketPurchased(msg.sender, recipient, ticketId, firstEntry, lastEntry, entryCount, grossAmount);
}
```

`_safeMint` first performs the ownership update and then calls the shared receiver check (`ERC721.sol:L287-L290`). For a code-bearing recipient, that check requires the exact receiver selector; a wrong selector or empty failure becomes `ERC721InvalidReceiver`, and a nonempty recipient revert is bubbled (`ERC721Utils.sol:L25-L48`). Thus no failed receiver callback can return normally past `_safeMint`; its revert unwinds the preceding quote transfer, range/accounting writes, and mint in the same transaction (`Raffle.sol:L223-L236`; `ERC721.sol:L287-L290`; `ERC721Utils.sol:L32-L47`). A code-less recipient takes the no-call branch at `ERC721Utils.sol:L32-L48`, so no recipient behavior is assumed on that path.

The modifier is enforcement rather than a name: it checks whether the fixed guard slot equals `ENTERED`, writes `ENTERED` before the function body, and restores `NOT_ENTERED` only after the body returns (`ReentrancyGuard.sol:L50-L51,L69-L72,L88-L105,L112-L117`). Although clones are created without running the implementation's constructors (`RaffleFactory.sol:L105-L110`), an initially zero clone slot is not the `ENTERED` value `2`; the first protected call writes `2` and later writes `1`, so the guard also operates on a fresh clone (`ReentrancyGuard.sol:L50-L60,L88-L105,L112-L117`). During the `_safeMint` receiver callback, reentry into every protected raffle lifecycle or asset-moving entrypoint therefore reverts (`Raffle.sol:L209-L212,L240-L240,L276-L276,L304-L309,L349-L395`).

All ticket mints and transfers pass through the raffle's `_update` override, which rejects the raffle, its factory, quote token, wrapper, prize token, implementation, and registered same-factory raffle destinations before delegating to the ERC-721 ledger update (`Raffle.sol:L491-L502,L587-L605`). The inherited direct transfer authorizes the caller and applies `_update`; the safe variants then invoke the receiver check (`ERC721.sol:L115-L136,L216-L244`). Consequently, a direct `transferFrom` runs no recipient code, while a `safeTransferFrom` callback runs only after current ownership has been written. If that callback returns successfully, it is allowed to exercise or move its bearer claim; if it fails, the transfer reverts. The safe-transfer function performs no economic write after the callback (`ERC721.sol:L115-L136`).

Winner redemption rereads live ownership, permits only that address to redeem, and writes the burn and claim flags before attempting delivery:

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

    if (result == Status.NftWon) {
        if (prizeClaimed) revert PrizeAlreadyClaimed();
        prizeClaimed = true;
        prizeToken.transferFrom(address(this), winner, prizeTokenId);
        if (prizeToken.ownerOf(prizeTokenId) != winner) {
            revert PrizeDeliveryVerificationFailed(winner);
        }
    } else {
        cashAmount = winnerProceeds;
        if (cashAmount == 0) revert NoWinnerProceeds();
        winnerProceeds = 0;
        _transferQuote(winner, cashAmount);
    }
}
```

The NFT branch uses `transferFrom`, so a standards-compliant prize does not require a ticket-recipient receiver callback, and it explicitly reverts unless the prize reports the winner as owner (`Raffle.sol:L327-L337`; `IERC721.sol:L75-L91`). The cash branch uses `_transferQuote`, which screens protocol sinks and calls the trusted quote token through `SafeERC20.safeTransfer` (`Raffle.sol:L338-L343,L560-L567`). `SafeERC20` bubbles a reverting transfer and itself reverts on `false` or an otherwise unsuccessful call (`SafeERC20.sol:L30-L46,L176-L199`). Any such revert unwinds `winnerRecipient`, `winnerRedeemed`, the burn, `prizeClaimed`, and the cleared cash bucket because those writes and delivery are in the same redemption call (`Raffle.sol:L309-L345`).

Refund delivery has the same ordering: live ownership is checked, tickets are burned, liability is reduced, and only then is the complete refund sent through `_transferQuote` (`Raffle.sol:L349-L370`). A failed quote-token delivery therefore reverts the batch rather than consuming a ticket or liability (`Raffle.sol:L356-L370`; `SafeERC20.sol:L30-L46,L176-L199`).

Finally, settlement itself neither reads the ticket owner nor calls it: `_settleWinningTicket` validates only the stored range and writes the terminal liability buckets (`Raffle.sol:L528-L558`). It is permissionless through `settleWinningTicket` (`Raffle.sol:L303-L306`), while sponsor proceeds and protocol fees are independently releasable after allocation (`Raffle.sol:L374-L391`). A ticket recipient that refuses to act can leave only its own winner claim unexercised; it cannot veto settlement or the other allocated claims (`Raffle.sol:L303-L306,L374-L391,L528-L558`).

---

**Paths walked:**

- `buyEntries` → `_safeMint` → `_mint` → `Raffle._update` → `ERC721._update`, code-less recipient: ownership, range, and accounting are recorded without executing recipient code (`Raffle.sol:L209-L236,L491-L502`; `ERC721.sol:L216-L244,L259-L290`; `ERC721Utils.sol:L32-L48`). ✓
- `buyEntries` → `_safeMint` → `checkOnERC721Received`, contract returns the exact selector: the callback may approve or transfer the ticket after ownership is written, but subsequent redemption and refunds read the then-current owner rather than trusting the original recipient (`ERC721.sol:L216-L244,L287-L290`; `ERC721Utils.sol:L32-L38`; `Raffle.sol:L320-L325,L359-L365`). ✓
- The same mint callback returns a wrong selector, reverts with or without data, or exhausts gas: the receiver check reverts or bubbles; there is no catch in `buyEntries`, so the purchase does not commit (`Raffle.sol:L209-L236`; `ERC721Utils.sol:L32-L47`). ✓
- Inherited `safeTransferFrom` → `transferFrom` → `Raffle._update` → receiver check: authorization and destination screening occur before the callback; a rejecting callback reverts the ownership update, while a successful callback executes with the recipient already current owner and the outer path has no later accounting write (`ERC721.sol:L115-L136,L216-L244`; `Raffle.sol:L491-L502`; `ERC721Utils.sol:L25-L48`). ✓
- Inherited `transferFrom`: this authorized branch deliberately performs no recipient callback, but it still uses the same destination-screened ownership update (`ERC721.sol:L115-L125`; `Raffle.sol:L491-L502`). A recipient unable or unwilling to operate its ticket can strand that bearer claim, but settlement and the sponsor/protocol releases do not call or depend on it (`Raffle.sol:L303-L306,L374-L391,L528-L558`). ✓ for the stated safety property.
- Receiver reentry during `buyEntries`: the guard is already `ENTERED`, so another protected raffle entrypoint fails; inherited approval/transfer operations remain limited by ERC-721 ownership/operator authorization and the destination screen (`Raffle.sol:L209-L212,L491-L502`; `ERC721.sol:L92-L136,L164-L187`; `ReentrancyGuard.sol:L69-L72,L88-L105`). ✓
- Receiver reentry during standalone inherited `safeTransferFrom`: the outer inherited function has no guard, but ownership has already moved and it performs no state write after the receiver check; a nested raffle operation therefore sees live ownership and applies its own checks and guard (`ERC721.sol:L115-L136,L216-L244`; `Raffle.sol:L309-L325,L349-L365`). ✓
- `settleWinningTicket` → `_settleWinningTicket`: no owner lookup, receiver callback, or delivery occurs; an arbitrary caller can allocate liabilities even if the ticket recipient never cooperates (`Raffle.sol:L303-L306,L528-L558`). ✓
- `redeemWinningTicket`, `NftWon`: current owner check → claim/burn writes → prize `transferFrom` → post-transfer `ownerOf` verification. A transfer revert or failed verification reverts the complete redemption (`Raffle.sol:L309-L337`). ✓
- `redeemWinningTicket`, `CashWon`: current owner check → claim/burn writes → winner bucket cleared → trusted quote-token safe transfer. Token-call failure reverts the complete redemption (`Raffle.sol:L309-L325,L338-L345,L560-L567`; `SafeERC20.sol:L30-L46,L176-L199`). ✓
- `refundTickets`: each ID is checked against current ownership and burned, then the aggregate liability is reduced and safely transferred; any ownership, batch, arithmetic, or delivery failure reverts the whole batch (`Raffle.sol:L349-L371`). ✓

---

**Searched:**

- Complete pinned inventory → read all five production files and all 31 paths in `target/dependency-hashes.json`; SHA-256 verification returned `OK` for 31/31 dependencies. The recipient behavior is implemented in `Raffle`, inherited `ERC721`, `ERC721Utils`, `ReentrancyGuard`, and `SafeERC20`; no additional override or wrapper in the remaining production/dependency files changes those paths.
- `onERC721Received|_safeMint|safeTransferFrom` over the five production files plus the 31 manifest paths → 39 matches in seven files: `RaffleFactory.sol` 1, `Raffle.sol` 4, `IERC721Receiver.sol` 3, `ERC721Utils.sol` 4, `IERC721.sol` 6, `ERC721.sol` 15, and `SafeERC20.sol` 6. The ticket-call chain is `Raffle.sol:L235` → `ERC721.sol:L279-L290` → `ERC721Utils.sol:L25-L48`; inherited safe transfers call the same receiver checker at `ERC721.sol:L128-L136`.
- `recipient|receiver|winnerRecipient|sponsorRecipient|protocolTreasury` over the same scope → 135 matches in 11 files. Production recipient writes and reads were classified across initialization, purchase, live-owner redemption/refund, sponsor/protocol releases, errors, and events; the safety-relevant ticket sites are `Raffle.sol:L209-L236,L309-L370,L491-L502,L560-L567`.
- `transferFrom|safeTransfer|_transferQuote|PrizeDeliveryVerificationFailed|SafeERC20FailedOperation` over the same scope → 70 matches in ten files. Relevant delivery implementations were read at `Raffle.sol:L223-L235,L327-L342,L349-L405,L560-L567`, `ERC721.sol:L115-L136,L287-L290,L352-L363`, `ERC721Utils.sol:L25-L48`, and `SafeERC20.sol:L30-L60,L167-L244`.
- `nonReentrant|ReentrancyGuard|_update|_burn` over the same scope → 57 matches in four files: `RaffleFactory.sol` 5, `Raffle.sol` 16, `ERC721.sol` 6, and `ReentrancyGuard.sol` 30. The modifier body, clone-initial-slot case, every raffle-specific asset/lifecycle entrypoint, inherited ownership update, and both burn sites were read (`Raffle.sol:L209-L212,L240-L240,L276-L276,L304-L395,L491-L502`; `ERC721.sol:L216-L244,L303-L308`; `ReentrancyGuard.sol:L50-L60,L69-L117`).
- `_safeMint`, `_transferQuote`, `_settleWinningTicket`, and `checkOnERC721Received` callers → `_safeMint` has one production call (`Raffle.sol:L235`) and resolves through the two inherited overloads (`ERC721.sol:L279-L290`); `_transferQuote` has four callers plus its definition (`Raffle.sol:L342,L369,L380,L390,L564`); `_settleWinningTicket` has two callers plus its definition (`Raffle.sol:L305,L315,L533`); `checkOnERC721Received` has three inherited call sites plus its definition (`ERC721.sol:L135,L289,L362`; `ERC721Utils.sol:L25`).
- `settleWinningTicket|redeemWinningTicket|refundTickets|releaseSponsorPrize` over the same scope → 11 matches in `Raffle.sol` and `IRaffle.sol`; every implementation branch and its internal callee was walked (`Raffle.sol:L303-L406,L528-L567`).
- Raffle and inherited ERC-721 externally callable mutators → enumerated `Raffle.sol:L171-L430` and the inherited approval/transfer entrypoints at `ERC721.sol:L92-L136`. All recipient-executing and recipient-delivery paths are covered above; `initialize` and the raffle's own prize receiver are exact-caller/state gated rather than ticket-recipient hooks (`Raffle.sol:L176-L205,L409-L431`).

---

**How the verdict was reached:** This is `implemented`, not `partial`, because every branch that actually invokes ticket-recipient code uses the same receiver checker and cannot commit after rejection, while each winner/refund delivery branch propagates failure so its preceding burn and liability writes roll back (`ERC721.sol:L128-L136,L287-L290`; `ERC721Utils.sol:L25-L48`; `Raffle.sol:L309-L370`; `SafeERC20.sol:L30-L46,L176-L244`). The unguarded inherited safe-transfer callback is not a missing enforcement path: ownership is already current, the outer function has no post-callback economic mutation, nested raffle operations apply their own authorization/state checks, and recipient failure still reverts the transfer (`ERC721.sol:L115-L136,L216-L244`; `Raffle.sol:L309-L365,L491-L502`). The unsafe `transferFrom` branch invokes no recipient code and can at worst leave that recipient's own bearer claim unused; permissionless storage-only settlement and independent sponsor/protocol releases remain available (`Raffle.sol:L303-L306,L374-L391,L528-L558`). The protocol-destination screen adds defense against known sinks but does not create a competing behavior for this trust-boundary criterion (`Raffle.sol:L491-L502,L587-L605`).

---

**Open questions:** None for the supplied ticket-recipient checkable criterion.
