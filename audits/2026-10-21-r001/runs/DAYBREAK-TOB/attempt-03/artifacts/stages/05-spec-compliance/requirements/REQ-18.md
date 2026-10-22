## REQ-18 — reserve-met result awards the escrowed NFT to the winning ticket

> "Reserve met awards NFT and 95% sponsor / 5% treasury."
> — DESIGN.md:L2, sentence 5

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** A resolved raffle whose sold-entry count meets or exceeds its configured reserve must enter the NFT result, bind the selected winning entry to its unique range ticket, and make the exact ERC-721 token escrowed at creation redeemable by that ticket's current owner. The NFT must not remain available to the sponsor-return branch after the reserve-met result. Per the supplied checkable, this record evaluates that NFT-award property; it does not adjudicate the quote-token percentage clause in the quoted sentence.

---

**Where enforcement lives:**

The factory constructor deploys the one implementation used by its clones (`target/packages/contracts/src/RaffleFactory.sol:L65-L92`). That implementation's constructor fixes `factory` to the deploying factory, initializes the inherited wrapper immutable, and locks the implementation instance itself (`target/packages/contracts/src/Raffle.sol:L151-L166`); the clone library embeds that fixed implementation address in each proxy runtime (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`). Consequently, the clone's one-time `msg.sender == factory` initialization gate resolves to the canonical creating factory (`target/packages/contracts/src/Raffle.sol:L176-L205`).

The factory passes the selected prize contract and token ID into the fresh clone, then transfers that same pair to the clone and requires both reported custody and activation before creation can return (`target/packages/contracts/src/RaffleFactory.sol:L105-L134`). Clone initialization is factory-only and one-time, and stores the exact pair plus the reserve (`target/packages/contracts/src/Raffle.sol:L176-L205`). The receiver callback accepts only that configured token contract and ID, from the configured sponsor, with the factory as operator (`target/packages/contracts/src/Raffle.sol:L416-L430`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L127-L134
IERC721 prize = IERC721(params.prizeToken);
prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
if (prize.ownerOf(params.prizeTokenId) != raffle) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
if (IRaffle(raffle).status() != IRaffle.Status.Active) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
```

The result writer compares the same-width `uint128` values `totalEntries` and `reserveEntries` directly and selects `NftWon` on equality as well as excess (`target/packages/contracts/src/Raffle.sol:L75-L85`, `L518-L523`). Creation rejects a zero reserve (`target/packages/contracts/src/RaffleFactory.sol:L171-L179`), while purchases reject zero entries and any addition beyond the `uint128` limit (`target/packages/contracts/src/Raffle.sol:L215-L230`). The result writer runs only for an authenticated wrapper callback that is current, one-word, in `Drawing`, and before the deadline (`target/packages/contracts/src/Raffle.sol:L509-L523`); the inherited gateway rejects every caller other than the configured wrapper before invoking it (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L106`).

```solidity
// target/packages/contracts/src/Raffle.sol:L509-L523
function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    if (
        _requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1
            || block.timestamp >= callbackDeadline()
    ) {
        emit VrfCallbackIgnored(requestId, vrfRequestId, status);
        return;
    }

    uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
    winningEntry = resolvedEntry;
    resolvedAt = uint64(block.timestamp);
    status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;

    emit RaffleResolved(requestId, resolvedEntry, status);
}
```

The sold ranges are positive, sequential, and non-overlapping: a purchase requires `entryCount != 0`, stores `[totalEntries + 1, totalEntries + entryCount]` under the next ticket ID, and advances `totalEntries` to that range's end (`target/packages/contracts/src/Raffle.sol:L215-L233`). Settlement opens the named helper: the candidate range must actually contain `winningEntry`, and the proven ID is then recorded as `winningTicketId` (`target/packages/contracts/src/Raffle.sol:L533-L555`, `L577-L584`).

```solidity
// target/packages/contracts/src/Raffle.sol:L577-L584
function _requireWinningTicket(uint256 ticketId) private view {
    (uint128 firstEntry, uint128 lastEntry) = ticketRange(ticketId);
    uint128 selectedEntry = winningEntry;
    if (selectedEntry < firstEntry || selectedEntry > lastEntry) {
        revert TicketDoesNotContainWinningEntry(ticketId, selectedEntry);
    }
}
```

Redemption either performs that proof inline or requires the already-recorded winning ticket. It then resolves the ticket's live owner, requires that owner to be the caller, records redemption, burns the ticket, transfers the configured prize from the raffle to that owner, and verifies the token contract now reports that owner (`target/packages/contracts/src/Raffle.sol:L309-L345`). The inherited `ownerOf` opens to `_requireOwned`, which rejects a nonexistent or burned ticket (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L60-L63`, `L420-L432`), and `_burn` opens to the actual ownership update and rejects a nonexistent token (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L303-L307`).

```solidity
// target/packages/contracts/src/Raffle.sol:L314-L337
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
}
```

The competing sponsor-prize release is expressly unavailable in `NftWon`; it accepts only `CashWon` or `Refunding` (`target/packages/contracts/src/Raffle.sol:L395-L406`). `enableRefunds` likewise accepts only `Active` or `Drawing`, so it cannot transition a resolved `NftWon` raffle into the sponsor-return state (`target/packages/contracts/src/Raffle.sol:L276-L300`). All of these external settlement, redemption, refund, and release paths carry `nonReentrant` (`target/packages/contracts/src/Raffle.sol:L276-L309`, `L348-L406`); the opened modifier checks and sets the shared guard before the body and restores it only afterward (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`, `L88-L106`).

---

**Paths walked:**

- `RaffleFactory.createRaffle` → `Clones.clone` → `Raffle.initialize` → prize `safeTransferFrom` → `Raffle.onERC721Received` → factory `ownerOf`/`status` postconditions: the fixed-target clone stores and reports custody of the exact configured prize before creation returns (`target/packages/contracts/src/RaffleFactory.sol:L97-L134`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`; `target/packages/contracts/src/Raffle.sol:L176-L205`, `L416-L430`). ✓
- `Raffle.buyEntries`: only `Active` raffles can add entries; each positive purchase appends the next contiguous range and is the only write to `totalEntries` (`target/packages/contracts/src/Raffle.sol:L209-L235`). Once `requestDraw` writes `Drawing`, purchases cannot change the value used by resolution (`target/packages/contracts/src/Raffle.sol:L240-L260`). ✓
- Configured wrapper → `rawFulfillRandomWords` → `Raffle.fulfillRandomWords`: wrapper identity is checked in the base contract, application guards must all pass, and `totalEntries >= reserveEntries` writes `NftWon` (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L106`; `target/packages/contracts/src/Raffle.sol:L509-L523`). ✓
- Separate settlement: `settleWinningTicket` → `_settleWinningTicket` → `_requireWinningTicket` records only an ID whose stored range contains `winningEntry`; later `redeemWinningTicket` requires that recorded ID and its current owner (`target/packages/contracts/src/Raffle.sol:L303-L321`, `L533-L555`, `L577-L584`). ✓
- Combined settlement/redemption: when settlement has not occurred, `redeemWinningTicket` invokes the same proof first; after the proof it requires live ownership, burns that ticket, transfers `prizeTokenId` from the raffle, and verifies delivery (`target/packages/contracts/src/Raffle.sol:L309-L345`). ✓
- Failure branches: a nonterminal result, wrong settled ticket, non-owner caller, already-redeemed winner, or already-claimed prize reverts before successful delivery; a transfer failure bubbles, and an unexpected post-transfer owner explicitly reverts (`target/packages/contracts/src/Raffle.sol:L309-L342`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L76-L91`). Because the burn, flags, external call, and ownership postcondition are in the same call, such a revert rolls back the attempted redemption. ✓
- Alternate prize disposition: `releaseSponsorPrize` rejects `NftWon`, while `enableRefunds` rejects every status other than `Active` or `Drawing`; no sanctioned branch can return the NFT after the reserve-met terminal result (`target/packages/contracts/src/Raffle.sol:L276-L300`, `L395-L406`). ✓

---

**Searched:**

- Full scoped read → all five first-party production files and all 31 files named by `target/dependency-hashes.json` were read in full; SHA-256 verification returned `OK` for 31/31 dependency files.
- `reserveEntries|NftWon|CashWon` across the five production files and 31 pinned dependencies → implementation-bearing hits at `Raffle.sol:L79,L203,L312,L329,L397,L521,L536,L543`; configuration/ABI hits in `RaffleFactory.sol:L118,L145,L178`, `IRaffle.sol:L28-L31,L43-L52,L107-L137,L337,L354,L442-L444`, and `IRaffleFactory.sol:L18-L24,L39-L50`; no dependency implemented another result path.
- `(reserveEntries|prizeToken|prizeTokenId|winningEntry|winningTicketId|prizeClaimed|winnerRedeemed|settlementComplete|status)\s*=(?!=)` across first-party production code → 15 writes, all in `Raffle.sol`: `L165,L200-L205,L252,L299,L324,L331,L403,L428,L519,L521,L551-L552`. The only reserve write is initialization at `L203`; the only winning-entry/result writes are `L519,L521`; the only winning-ticket write is `L552`.
- `totalEntries\s*=(?!=)` across the five production files and 31 pinned dependencies → exactly one hit, `Raffle.sol:L230`; no callee, base contract, or dependency has a second write.
- `_settleWinningTicket\(|settleWinningTicket\(|redeemWinningTicket\(|releaseSponsorPrize\(` across the full scope → six implementation hits in `Raffle.sol:L304-L305,L309,L315,L395,L533` and three declarations in `IRaffle.sol:L331,L338,L355`; there is no wrapper or second implementation path.
- `(prize|prizeToken)\.(safeTransferFrom|transferFrom|ownerOf)` across the full scope → exactly six first-party call sites: escrow transfer/check at `RaffleFactory.sol:L128-L129`, winner transfer/check at `Raffle.sol:L334-L335`, and sponsor-return transfer/check at `Raffle.sol:L404-L405`. The sponsor-return call was read and is gated away from `NftWon` at `Raffle.sol:L395-L399`.
- `rescue|sweep|recover|withdraw|seize|drain` (case-insensitive) in first-party production code → five comment-only hits: `Raffle.sol:L25,L411`, `RaffleFactory.sol:L19`, `IRaffleFactory.sol:L7`, and `IRaffle.sol:L32`; zero additional executable prize-exit paths.
- `(prize|prizeToken)\.(approve|setApprovalForAll)` across production and pinned dependencies → 0 hits; first-party code creates no prize approval escape path.
- `delegatecall|callcode|selfdestruct` in first-party production code → 0 hits; no first-party delegation or destruction route bypasses the resolved-result gates. The separately read clone library fixes the delegate target into the ERC-1167 runtime (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L51-L62`).

---

**How the verdict was reached:** This is `implemented`, not `partial`, because both supported redemption orderings—permissionless settlement followed by owner redemption, and owner redemption that settles inline—run the same range-containment proof and end at the same `NftWon` transfer of the configured escrowed token (`target/packages/contracts/src/Raffle.sol:L303-L345`, `L533-L558`, `L577-L584`). Equality satisfies the reserve through `>=`, the values cannot change after the raffle enters `Drawing`, the winning-ticket ID cannot be substituted after settlement, and the only sponsor-return function rejects `NftWon` (`target/packages/contracts/src/Raffle.sol:L209-L260`, `L316-L337`, `L395-L406`, `L521`). The code therefore does more than name an NFT outcome: it preserves exact prize identity from creation, proves the ticket, requires its current owner, consumes the ticket, performs delivery, and checks the delivery postcondition (`target/packages/contracts/src/RaffleFactory.sol:L109-L134`; `target/packages/contracts/src/Raffle.sol:L176-L205`, `L309-L345`, `L577-L584`).

---

**Open questions:**

- The concrete sponsor-selected prize implementation is outside the supplied target. The factory checks code presence, a reported ERC-721 interface, initial `ownerOf`, and clone activation (`target/packages/contracts/src/RaffleFactory.sol:L127-L134`, `L154-L177`), while the raffle checks `ownerOf` again after winner delivery (`target/packages/contracts/src/Raffle.sol:L329-L337`). The target interface declares supported prizes to be honest, standards-compliant ERC-721s (`target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`). Establishing the deployed token's behavior beyond those visible calls would require its implementation; this does not leave the local reserve-result allocation undecidable.
