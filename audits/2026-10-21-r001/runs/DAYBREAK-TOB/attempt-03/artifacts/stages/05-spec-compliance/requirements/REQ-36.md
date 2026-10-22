## REQ-36 — Callback records result only

> "Callback records result only."
> — `DESIGN.md:L2, sentence 12`

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** “Callback records result only.” requires every callback that passes the raffle's callback-validity gates to persist the raffle outcome in raffle storage, while leaving winning-ticket proof, liability allocation, ticket burning, and asset delivery to later operations.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107
function rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external {
  address vrfWrapperAddr = address(i_vrfV2PlusWrapper);
  if (msg.sender != vrfWrapperAddr) {
    revert OnlyVRFWrapperCanFulfill(msg.sender, vrfWrapperAddr);
  }
  fulfillRandomWords(_requestId, _randomWords);
}
```

- The inherited external gateway rejects every caller other than the configured wrapper before dispatching to the raffle override (`VRFV2PlusWrapperConsumerBase.sol:L101-L107`). The base constructor fixes that wrapper in the immutable `i_vrfV2PlusWrapper` (`VRFV2PlusWrapperConsumerBase.sol:L40-L47`), and the factory validates that the configured address has code before deploying the shared implementation with it (`RaffleFactory.sol:L65-L91`).

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

- The single rejection branch covers an in-flight request, a non-`Drawing` lifecycle state, a request-ID mismatch, any word count other than one, and a callback at or after the deadline; each rejected case returns before the result writes (`Raffle.sol:L509-L516`).
- The only accepted fallthrough derives a one-based entry from the callback word and persists `winningEntry`, `resolvedAt`, and the terminal `NftWon`/`CashWon` result before emitting `RaffleResolved` (`Raffle.sol:L518-L523`). The interface defines `Status` as the authoritative lifecycle and economic result and defines those two terminal outcomes (`IRaffle.sol:L20-L33`); it also exposes all three persisted values through generated getters (`IRaffle.sol:L490-L504`).
- The complete accepted handler contains no ticket lookup, liability allocation, burn, token transfer, or external user call (`Raffle.sol:L509-L523`). Those operations begin only in the separately callable settlement and redemption paths: `settleWinningTicket` and `redeemWinningTicket` call `_settleWinningTicket` (`Raffle.sol:L303-L345`), and that helper later writes the settlement and liability fields (`Raffle.sol:L533-L557`).

---

**Paths walked:**

- Deployment → wrapper binding: `RaffleFactory` requires deployed wrapper code, constructs one locked `Raffle` implementation with that wrapper, and records it as `raffleImplementation` (`RaffleFactory.sol:L65-L91`). `Raffle` validates the wrapper as nonzero and passes it to the inherited constructor (`Raffle.sol:L155-L165`, `L607-L613`), which stores the immutable interface used by the callback gateway (`VRFV2PlusWrapperConsumerBase.sol:L40-L47`). Canonical raffles are fixed-target clones of that implementation and are initialized through the factory (`RaffleFactory.sol:L97-L121`; `Clones.sol:L23-L62`). ✓
- Request setup → callback prerequisites: `requestDraw` requires `Active`, an ended sale, at least one sold entry, and an open request window, then writes `Drawing`, `drawRequestedAt`, and `_requestInFlight`; after the wrapper request returns, it stores `vrfRequestId` and clears `_requestInFlight` (`Raffle.sol:L240-L260`). The inherited request helper asks the wrapper for one word and returns its request ID (`VRFV2PlusWrapperConsumerBase.sol:L76-L89`). ✓
- Unauthorized external callback: `rawFulfillRandomWords` reverts unless `msg.sender` is the immutable configured wrapper, so this path never reaches the raffle handler (`VRFV2PlusWrapperConsumerBase.sol:L101-L107`). Excluded from valid callbacks.
- Authenticated but in-flight, wrong-state, wrong-ID, wrong-length, or late callback: the combined guard emits `VrfCallbackIgnored` and returns before any result-state assignment (`Raffle.sol:L509-L516`). Excluded from valid callbacks.
- Valid callback: with every guard predicate false, the handler has one unbranched fallthrough. It consumes the sole word, computes `resolvedEntry`, stores the entry and resolution timestamp, stores exactly one of the two terminal result statuses, and emits the resolution event (`Raffle.sol:L518-L523`). ✓
- Duplicate callback after resolution: the first accepted callback changes `status` away from `Drawing` at `Raffle.sol:L521`; a later callback therefore takes the rejection branch at `Raffle.sol:L511-L515` and cannot overwrite the result. ✓
- Post-callback settlement and delivery: the callback does not call `_settleWinningTicket`; its only two call sites are `settleWinningTicket` and `redeemWinningTicket` (`Raffle.sol:L303-L315`). Liability allocation occurs inside the helper (`Raffle.sol:L533-L557`), while ticket burning and NFT/cash delivery occur in redemption (`Raffle.sol:L309-L345`). ✓ — these are later entrypoints, not callback work.

---

**Searched:**

- Frozen implementation inventory → read all five first-party production files under `target/packages/contracts/src` and every one of the 31 files named by `target/dependency-hashes.json`; all 31 computed SHA-256 values matched the manifest.
- `\bfulfillRandomWords\b` over that 36-file scope → 5 matching lines: the raffle override at `Raffle.sol:L509`, base documentation at `VRFV2PlusWrapperConsumerBase.sol:L53` and `L92`, the virtual declaration at `L99`, and the authenticated dispatch at `L106`.
- `\brawFulfillRandomWords\b` over that scope → 1 matching line, the external gateway definition at `VRFV2PlusWrapperConsumerBase.sol:L101`; there is no alternate in-scope gateway.
- `^\s*(winningEntry|resolvedAt|status)\s*=` over that scope → 8 matching lines, all in `Raffle.sol`: lifecycle writes at `L165`, `L205`, `L252`, `L299`, and `L428`, followed by the callback's only `winningEntry`, `resolvedAt`, and terminal-status writes at `L519-L521`.
- `^\s*(_requestInFlight|vrfRequestId|drawRequestedAt|totalEntries)\s*=` over that scope → 5 matching lines, all in `Raffle.sol`: `totalEntries` at `L230` and request coordination at `L253-L260`.
- `\b_settleWinningTicket\s*\(` over that scope → 3 matching lines: calls at `Raffle.sol:L305` and `L315`, plus the helper definition at `L533`; none is in the callback.
- `\b(_settleWinningTicket|_transferQuote|safeTransfer|safeTransferFrom|transferFrom|ownerOf|winnerProceeds|sponsorProceeds|protocolFees|settlementComplete|winningTicketId|winnerRecipient|winnerRedeemed|prizeClaimed)\b` within `Raffle.sol:L509-L523` → 0 hits.
- `VrfCallbackIgnored|RaffleResolved` over that scope → 4 matching lines: emissions at `Raffle.sol:L514` and `L523`, and event declarations at `IRaffle.sol:L102` and `L108`.

---

**How the verdict was reached:** This is `implemented`, not `partial`, because callback acceptance has one fallthrough and every locally valid callback reaches all three persistent result-record writes at `Raffle.sol:L518-L523`; every alternative branch is rejected before those writes at `Raffle.sol:L509-L516`. It is not merely an event-only implementation: `winningEntry`, `resolvedAt`, and `status` are state variables (`Raffle.sol:L114-L124`) and are assigned before the event (`Raffle.sol:L518-L523`). It is not `contradicted`: settlement, liability allocation, ticket burning, and delivery are absent from the complete handler and occur only through later entrypoints (`Raffle.sol:L303-L345`, `L533-L557`). The authentication, request-ID, word-shape, lifecycle, and deadline checks define which callback is valid; they do not replace or bypass persistence (`VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `Raffle.sol:L509-L523`).

---

**Open questions:** None for this requirement.
