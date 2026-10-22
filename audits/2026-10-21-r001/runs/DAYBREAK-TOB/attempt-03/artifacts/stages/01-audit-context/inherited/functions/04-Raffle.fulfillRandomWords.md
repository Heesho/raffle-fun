## `fulfillRandomWords` in `target/packages/contracts/src/Raffle.sol` (L509-L524)

**Purpose:** This is the internal terminal-state handler for an authenticated Chainlink wrapper callback. It rejects callbacks that arrive before request persistence, outside the `Drawing` state, for another request, with a word count other than one, or at/after the exclusive callback deadline; an accepted callback maps one word into the sold one-based entry space and records either `NftWon` or `CashWon` without settling liabilities or transferring an asset (`target/packages/contracts/src/Raffle.sol:L504-L524`). The only source-visible dispatch into this internal override is the inherited `rawFulfillRandomWords`, which first requires `msg.sender` to equal the immutable wrapper (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L99-L107`).

**Inputs & Assumptions:**

- `requestId` (`uint256`): the request identifier supplied by the configured wrapper through `rawFulfillRandomWords`. Trust: **trusted only under the configured-wrapper assumption**. The gateway authenticates the caller address, and this function independently requires equality with `vrfRequestId` for acceptance (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L106`; `target/packages/contracts/src/Raffle.sol:L511-L515`).
- `randomWords` (`uint256[] memory`): ABI-decoded callback words supplied by that wrapper. Trust: **trusted only for randomness quality**; the function validates the array length but cannot establish how the word was generated (`target/packages/contracts/src/Raffle.sol:L508-L518`). `requestDraw` asks for exactly one word, and the inherited request helper forwards that count to the external wrapper (`target/packages/contracts/src/Raffle.sol:L255-L257`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L88`).
- Implicit input: `_requestInFlight`, which is true only around the external wrapper request and is cleared only after the returned request ID has been stored (`target/packages/contracts/src/Raffle.sol:L141-L142`, `L252-L260`).
- Implicit inputs: `status`, `vrfRequestId`, `drawRequestedAt`, `totalEntries`, and `reserveEntries`, plus `block.timestamp` (`target/packages/contracts/src/Raffle.sol:L79-L85`, `L109-L124`, `L509-L521`).
- Success precondition: `_requestInFlight == false`, `status == Status.Drawing`, `requestId == vrfRequestId`, `randomWords.length == 1`, and `block.timestamp < callbackDeadline()`. The guard establishes all five by returning whenever any one is false (`target/packages/contracts/src/Raffle.sol:L509-L516`).
- Success precondition: `totalEntries > 0`. `requestDraw` rejects zero entries before it writes `Drawing`, and `buyEntries` is the sole source-visible writer of `totalEntries` and requires `Active`, so the entry count cannot be increased through that path after the draw transition (`target/packages/contracts/src/Raffle.sol:L215-L220`, `L226-L233`, `L240-L254`).
- Success precondition: the request timestamp and request identifier are persisted before acceptance. `requestDraw` writes `Drawing`, `drawRequestedAt`, and `_requestInFlight = true` before calling the wrapper, then stores the returned ID before clearing `_requestInFlight`; therefore a callback during the request call is ignored, while a later callback can satisfy the persistence gate (`target/packages/contracts/src/Raffle.sol:L252-L260`, `L509-L515`).
- Assumption: the configured wrapper binds the ID returned by `requestRandomWordsInNative` to a later callback and supplies the intended unpredictable word. The target contains the wrapper interface and consumer gateway, not the deployed wrapper implementation; the factory checks only that the configured address has code, while its documentation assigns official-wrapper verification to deployment configuration (`target/packages/contracts/src/RaffleFactory.sol:L58-L67`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L68-L81`).
- Assumption: callback-time `block.timestamp` is representable as `uint64`. The accepted path explicitly narrows it without a local range check (`target/packages/contracts/src/Raffle.sol:L520`). Nothing found in the target establishes a general `block.timestamp <= type(uint64).max` condition.

**Outputs & Effects:**

- The function returns no value. Every rejected decoded callback emits `VrfCallbackIgnored(receivedRequestId, expectedRequestId, currentStatus)` and returns without writing raffle result storage (`target/packages/contracts/src/Raffle.sol:L509-L516`; event fields at `target/packages/contracts/src/interfaces/IRaffle.sol:L98-L102`).
- An accepted callback writes a one-based `winningEntry`, writes the narrowed callback timestamp to `resolvedAt`, and changes `status` from `Drawing` to `NftWon` when `totalEntries >= reserveEntries` or to `CashWon` otherwise (`target/packages/contracts/src/Raffle.sol:L518-L521`).
- An accepted callback emits `RaffleResolved(requestId, resolvedEntry, status)` after all three result writes (`target/packages/contracts/src/Raffle.sol:L518-L523`; event semantics at `target/packages/contracts/src/interfaces/IRaffle.sol:L104-L108`).
- The function does not write `vrfRequestId`, `drawRequestedAt`, `_requestInFlight`, any ticket range, or any quote-token liability, and it makes no token or arbitrary-recipient call; its only Solidity function call is the internal view `callbackDeadline()` (`target/packages/contracts/src/Raffle.sol:L509-L524`). Settlement and liability allocation occur later in `_settleWinningTicket` (`target/packages/contracts/src/Raffle.sol:L528-L558`).
- Postcondition after acceptance: `1 <= winningEntry <= totalEntries`, `resolvedAt` records the accepted callback block timestamp subject to the `uint64` representation assumption, and `status` is terminal for draw resolution (`target/packages/contracts/src/Raffle.sol:L518-L523`; terminal status meanings at `target/packages/contracts/src/interfaces/IRaffle.sol:L20-L33`).

---

**Block-by-Block:**

```solidity
// L509-L516
function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    if (
        _requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1
            || block.timestamp >= callbackDeadline()
    ) {
        emit VrfCallbackIgnored(requestId, vrfRequestId, status);
        return;
    }
```

- **What:** Applies one short-circuit rejection branch to every ABI-decodable callback dispatched by the authenticated gateway (`target/packages/contracts/src/Raffle.sol:L509-L516`).
- **Why here:** It precedes `randomWords[0]`, the modulo, and every result write, so a zero-length array, a zero divisor from an unaccepted lifecycle, or an ineligible callback cannot reach resolution (`target/packages/contracts/src/Raffle.sol:L511-L519`).
- **Assumes:** Caller authentication already occurred in `rawFulfillRandomWords`; the local handler does not read `msg.sender` (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L106`; `target/packages/contracts/src/Raffle.sol:L509-L524`).
- **Establishes:** Reaching L518 means the request call has returned and its ID was persisted, the raffle is still drawing, the callback ID matches, exactly one word is indexable, and the callback is strictly before its deadline (`target/packages/contracts/src/Raffle.sol:L252-L260`, `L509-L518`).
- **Depended on by:** The modulo and array access at L518, and all result writes at L519-L521 (`target/packages/contracts/src/Raffle.sol:L518-L521`).

The rejection branch covers each of these source-visible cases:

- `_requestInFlight == true`: a callback made during `requestRandomnessPayInNative` is ignored before `vrfRequestId` has to match; `requestDraw` sets the flag before the external request and clears it after storing the returned ID (`target/packages/contracts/src/Raffle.sol:L252-L260`, `L511-L515`).
- `status != Drawing`: callbacks before the draw, after refunds are enabled, or after an earlier accepted callback are ignored; `enableRefunds` writes `Refunding`, while acceptance writes `NftWon` or `CashWon` (`target/packages/contracts/src/Raffle.sol:L289-L300`, `L511-L521`).
- `requestId != vrfRequestId`: an authenticated callback for another identifier is ignored and the event records both received and expected identifiers (`target/packages/contracts/src/Raffle.sol:L511-L515`; `target/packages/contracts/src/interfaces/IRaffle.sol:L98-L102`).
- `randomWords.length != 1`: both an empty and a multi-word decoded array are ignored before indexing; malformed ABI calldata instead fails decoding before this internal handler runs (`target/packages/contracts/src/Raffle.sol:L504-L518`; gateway signature at `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L106`).
- `block.timestamp >= callbackDeadline()`: the callback is ignored at and after the deadline. `callbackDeadline()` is `drawRequestedAt + 2 days` once a request timestamp exists, and the timeout constant is two days (`target/packages/contracts/src/Raffle.sol:L462-L465`, `L511-L515`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L35-L36`).

Because the conditions are joined by Solidity short-circuit `||`, an earlier true condition prevents evaluation of later conditions, including the `callbackDeadline()` call; every decoded rejection nevertheless has the same event-and-return effect (`target/packages/contracts/src/Raffle.sol:L510-L516`).

```solidity
// L518
uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
```

- **What:** Reduces the accepted word modulo the number of sold entries and shifts the zero-based remainder to the one-based global entry numbering (`target/packages/contracts/src/Raffle.sol:L518`).
- **Why here:** It runs only after exact word-count, lifecycle, request-ID, persistence, and timing validation (`target/packages/contracts/src/Raffle.sol:L509-L518`).
- **Assumes:** `totalEntries` is nonzero and frozen for this draw. `requestDraw` rejects zero before entering `Drawing`, and purchases require `Active` (`target/packages/contracts/src/Raffle.sol:L215-L220`, `L240-L254`). It also assumes the authenticated word has the intended randomness quality; that property is supplied by the external wrapper trust boundary, not derived locally (`target/packages/contracts/src/RaffleFactory.sol:L58-L67`; `target/packages/contracts/src/Raffle.sol:L518`).
- **Establishes:** The remainder is in `[0,totalEntries-1]`, so `resolvedEntry` is in `[1,totalEntries]`; because `totalEntries` is a `uint128`, the explicit cast preserves every possible result (`target/packages/contracts/src/Raffle.sol:L85`, `L518`).
- **Depended on by:** `winningEntry` storage, the resolution event, and `_requireWinningTicket`, which later checks the selected number against a ticket's stored range (`target/packages/contracts/src/Raffle.sol:L519`, `L523`, `L577-L585`).

```solidity
// L519-L521
winningEntry = resolvedEntry;
resolvedAt = uint64(block.timestamp);
status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;
```

- **What:** Commits the selected entry and resolution time, then makes the reserve comparison the authoritative terminal economic result (`target/packages/contracts/src/Raffle.sol:L519-L521`).
- **Why here:** The result values are written only after the callback has passed every gate; the terminal status is written after the entry and timestamp it describes (`target/packages/contracts/src/Raffle.sol:L509-L521`). There is no external call between these writes (`target/packages/contracts/src/Raffle.sol:L518-L523`).
- **Assumes:** `reserveEntries` is the once-configured threshold. Initialization is one-time and factory-only; the factory rejects zero reserve and passes it to initialization, which stores it (`target/packages/contracts/src/Raffle.sol:L176-L179`, `L197-L205`; `target/packages/contracts/src/RaffleFactory.sol:L109-L120`, `L178-L179`).
- **Establishes:** The `totalEntries >= reserveEntries` branch yields `NftWon`; the complementary branch yields `CashWon`, matching the enum's declared meanings (`target/packages/contracts/src/Raffle.sol:L521`; `target/packages/contracts/src/interfaces/IRaffle.sol:L28-L31`). The change away from `Drawing` also makes a later duplicate callback take the ignore branch (`target/packages/contracts/src/Raffle.sol:L511-L515`, `L521`).
- **Depended on by:** `_settleWinningTicket` accepts only these two result states and validates a proposed range against `winningEntry`; redemption and sponsor-prize release branch on the recorded result (`target/packages/contracts/src/Raffle.sol:L311-L339`, `L395-L405`, `L533-L555`, `L579-L584`). `resolvedAt` is exposed through its generated getter and has no source-visible internal reader (`target/packages/contracts/src/Raffle.sol:L114-L118`; `target/packages/contracts/src/interfaces/IRaffle.sol:L488-L496`).

```solidity
// L523
emit RaffleResolved(requestId, resolvedEntry, status);
```

- **What:** Logs the accepted request ID, selected entry, and already-stored terminal result (`target/packages/contracts/src/Raffle.sol:L519-L523`).
- **Why here:** The log follows the writes and therefore describes the state committed by the accepted callback (`target/packages/contracts/src/Raffle.sol:L519-L523`).
- **Assumes:** Off-chain consumers treat `RaffleResolved` as the accepted resolution event and `VrfCallbackIgnored` as a non-resolution event; the interface documents those distinct meanings (`target/packages/contracts/src/interfaces/IRaffle.sol:L98-L108`).
- **Establishes:** An on-chain log for the accepted branch; it does not allocate liabilities or transfer the prize (`target/packages/contracts/src/Raffle.sol:L523`, `L528-L558`).
- **Depended on by:** No in-scope Solidity function reads logs; the interface defines the event for external observers (`target/packages/contracts/src/interfaces/IRaffle.sol:L104-L108`).

---

**Cross-Function Dependencies:**

- **Caller `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords` (external-source-available):** This is the external gateway. It resolves the immutable wrapper address, reverts when `msg.sender` differs, and otherwise dynamically dispatches to this override (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L99-L107`). The gateway establishes caller-address authentication only; request identity, length, lifecycle, and timing are established by `fulfillRandomWords` (`target/packages/contracts/src/Raffle.sol:L509-L516`).
- **Callee `callbackDeadline` (internal):** Returns zero before `drawRequestedAt` is set and otherwise returns `drawRequestedAt + DRAW_CALLBACK_TIMEOUT`; this handler depends on it to define the exclusive last acceptable callback time (`target/packages/contracts/src/Raffle.sol:L462-L465`, `L511-L515`; `target/packages/contracts/src/libraries/RaffleConstants.sol:L35-L36`).
- **Upstream `requestDraw`:** Requires `Active`, sale end, nonzero entries, and the request window; it then writes `Drawing`, records the timestamp, raises `_requestInFlight`, makes the wrapper request for one word, stores the returned ID, and lowers `_requestInFlight` (`target/packages/contracts/src/Raffle.sol:L240-L260`). This ordering is the persistence protocol consumed by the callback guard (`target/packages/contracts/src/Raffle.sol:L511-L515`).
- **Callee of upstream request, `requestRandomnessPayInNative` (external-black-box at its wrapper call):** The inherited helper quotes the price and sends value plus callback gas, confirmations, word count, and extra arguments to `i_vrfV2PlusWrapper.requestRandomWordsInNative`, returning its ID (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L88`). The target exposes only the wrapper interface for that external call, so the callback's word provenance and returned-ID/callback-ID association remain wrapper assumptions (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L68-L81`).
- **Configuration path:** The factory requires the wrapper address to contain code, stores it, and deploys the fixed Raffle implementation with it; the base constructor stores that address as `i_vrfV2PlusWrapper`, which the callback gateway later authenticates (`target/packages/contracts/src/RaffleFactory.sol:L65-L67`, `L85-L91`; `target/packages/contracts/src/Raffle.sol:L155-L162`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L40-L47`, `L101-L106`).
- **Shared-state writer `buyEntries`:** The callback depends on the contiguous global-entry count and ticket ranges built by purchases. Each purchase starts at `totalEntries + 1`, ends at `totalEntries + entryCount`, stores that range, and advances `totalEntries`; purchases require `Active`, so this coverage is fixed after `requestDraw` writes `Drawing` (`target/packages/contracts/src/Raffle.sol:L215-L233`, `L252`).
- **Competing terminal path `enableRefunds`:** While `Drawing`, it reverts strictly before `callbackDeadline()` and writes `Refunding` at or after the deadline; the callback accepts strictly before the same deadline and ignores at or after it (`target/packages/contracts/src/Raffle.sol:L289-L300`, `L511-L515`). The two paths therefore use complementary sides of the same timestamp boundary (`target/packages/contracts/src/Raffle.sol:L290-L291`, `L512`).
- **Downstream `_settleWinningTicket` and `_requireWinningTicket`:** Settlement accepts only `NftWon` or `CashWon`, and the range helper requires the caller-supplied ticket range to contain the stored `winningEntry`; settlement then allocates the untouched `unsettledPot` into terminal liabilities (`target/packages/contracts/src/Raffle.sol:L533-L558`, `L577-L585`).
- **Downstream `redeemWinningTicket`:** Redemption accepts the two terminal results, optionally settles, requires current ticket ownership, burns the ticket, and delivers the NFT or stored cash proceeds (`target/packages/contracts/src/Raffle.sol:L309-L345`). It relies on this callback for both the terminal result and winning entry (`target/packages/contracts/src/Raffle.sol:L311-L315`, `L538`).
- **Downstream `releaseSponsorPrize`:** `CashWon` makes the sponsor prize releasable, while `NftWon` does not; the alternate `Refunding` path is established by `enableRefunds`, not this callback (`target/packages/contracts/src/Raffle.sol:L395-L405`, `L521`).

**Shared state and invariant couplings:**

- `status` is the coordination word: `requestDraw` writes `Drawing`, this callback writes one of the two resolved states, and `enableRefunds` can write `Refunding` only on the other side of the deadline (`target/packages/contracts/src/Raffle.sol:L252`, `L289-L300`, `L511-L521`).
- `_requestInFlight` and `vrfRequestId` couple an external request's return ordering to callback acceptance: the flag blocks resolution during the call, and the equality check admits only the ID stored after it returns (`target/packages/contracts/src/Raffle.sol:L252-L260`, `L511-L515`).
- `totalEntries` couples purchase coverage to winner selection. The purchase path builds adjacent one-based ranges and advances the total; the callback selects within `[1,totalEntries]`; later settlement proves a stored range contains that entry (`target/packages/contracts/src/Raffle.sol:L226-L233`, `L518`, `L579-L584`).
- `reserveEntries` and `totalEntries` jointly determine the terminal asset branch, while this function leaves `unsettledPot` unchanged for later allocation (`target/packages/contracts/src/Raffle.sol:L79-L91`, `L521`, `L539-L555`).
- `winningEntry`, `resolvedAt`, and the terminal `status` are committed in the same callback execution before `RaffleResolved`; no external interaction occurs between them (`target/packages/contracts/src/Raffle.sol:L518-L523`).

---

**Open Questions:**

- unclear; need to inspect the deployed Chainlink wrapper implementation and deployment evidence to establish that the configured code is the intended wrapper and that its returned request IDs are bound to later unbiased callback words. The in-target factory checks code presence, and the in-target dependency provides only the wrapper interface for the request operation (`target/packages/contracts/src/RaffleFactory.sol:L58-L67`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFV2PlusWrapper.sol:L68-L81`).
- unclear; need to inspect the deployed wrapper's fulfillment/retry semantics to know whether it can or will attempt another callback after this handler emits `VrfCallbackIgnored` and returns successfully (`target/packages/contracts/src/Raffle.sol:L509-L516`).
- unclear; need to inspect deployment-chain timestamp bounds to establish that `block.timestamp` remains representable as `uint64` when `resolvedAt` is written; no local bound precedes the explicit conversion (`target/packages/contracts/src/Raffle.sol:L520`).
