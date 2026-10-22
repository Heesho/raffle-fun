## REQ-37 — Callback records result only

> "Callback records result only."
> — `DESIGN.md:L2, sentence 12`

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** The sentence "Callback records result only." (`DESIGN.md:L2, sentence 12`) requires every callback path to stop at callback authentication/filtering and result-state or result-log recording. The callback must not allocate terminal liabilities, prove or consume a ticket claim, make a quote-token payout, or deliver the prize NFT.

---

**Where enforcement lives:**

The inherited external gateway authenticates the configured wrapper and then makes exactly one internal virtual dispatch:

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

The raffle override contains the complete application callback. Its rejection branch emits an ignored-callback log and returns. Its acceptance branch computes the selected entry, writes the selected entry, resolution timestamp, and terminal result, then emits the resolution log:

```solidity
// target/packages/contracts/src/Raffle.sol:L509-L524
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

The only function called by that override is a storage-only deadline calculation:

```solidity
// target/packages/contracts/src/Raffle.sol:L463-L465
function callbackDeadline() public view override returns (uint256 deadline) {
    if (drawRequestedAt != 0) deadline = uint256(drawRequestedAt) + RaffleConstants.DRAW_CALLBACK_TIMEOUT;
}
```

- `rawFulfillRandomWords` has no modifier; its inline caller check reverts before the hook unless `msg.sender` is the immutable configured wrapper (`VRFV2PlusWrapperConsumerBase.sol:L101-L106`). `fulfillRandomWords` is an internal override with no modifier (`Raffle.sol:L509`).
- The callback does not call a settlement, claim, token, recipient, or low-level-call helper. The accepted branch has only local arithmetic, three result-related storage writes, and one event; the rejected branch has one event and a return (`Raffle.sol:L509-L524`). `callbackDeadline` only reads `drawRequestedAt` and adds the fixed timeout (`Raffle.sol:L463-L465`; `RaffleConstants.sol:L35-L36`).
- Settlement is deliberately exposed later through `settleWinningTicket`, which calls the private allocator (`Raffle.sol:L304-L306`); `_settleWinningTicket` proves the range and writes `winnerProceeds`, `settlementComplete`, `winningTicketId`, `unsettledPot`, `sponsorProceeds`, and `protocolFees` (`Raffle.sol:L533-L558`).
- Claim consumption and winner delivery are later operations: redemption establishes the current owner, marks redemption, burns the ticket, and then transfers either the prize NFT or the cash claim (`Raffle.sol:L309-L345`). Sponsor/protocol payouts and sponsor-prize delivery likewise live in separate release entrypoints (`Raffle.sol:L375-L406`), with quote-token delivery performed by `_transferQuote` (`Raffle.sol:L560-L566`).

---

**Paths walked:**

- Factory constructor → raffle implementation constructor → Chainlink base constructor: the factory validates and stores the wrapper and deploys `new Raffle(quoteToken_, vrfWrapper_)` (`RaffleFactory.sol:L65-L91`). `Raffle` passes `_validatedVrfWrapper(vrfWrapper_)` to the base (`Raffle.sol:L155-L165`), the validator rejects zero and returns the same address (`Raffle.sol:L607-L613`), and the base fixes that wrapper in `i_vrfV2PlusWrapper` (`VRFV2PlusWrapperConsumerBase.sol:L40-L47`). This is the address enforced at the callback gateway (`VRFV2PlusWrapperConsumerBase.sol:L101-L105`). ✓
- Factory creation → clone dispatch: `createRaffle` creates a standard clone of the one stored implementation and initializes it (`RaffleFactory.sol:L97-L121`). `Clones.clone` constructs a fixed-target minimal proxy and reverts if creation fails (`Clones.sol:L32-L62`), so clone callback dispatch reaches the reviewed implementation. ✓
- Malformed callback calldata: Solidity decoding occurs before the override runs; the source explicitly distinguishes malformed ABI data from ABI-decodable wrong-length arrays (`Raffle.sol:L504-L506`). No application callback branch executes. ✓
- Unauthorized external callback: `rawFulfillRandomWords` compares `msg.sender` with `i_vrfV2PlusWrapper` and reverts before internal dispatch (`VRFV2PlusWrapperConsumerBase.sol:L101-L106`). No settlement, claim consumption, payout, or delivery executes. ✓
- Authorized synchronous callback during request creation: `requestDraw` first requires at least one entry, writes `Drawing`, records the request timestamp, and sets `_requestInFlight` before calling the wrapper; it stores the returned ID and clears the flag afterward (`Raffle.sol:L240-L260`). A callback during that external request call takes the `_requestInFlight` rejection branch, emits `VrfCallbackIgnored`, and returns (`Raffle.sol:L509-L515`). ✓
- Authorized callback with non-`Drawing` status, a mismatched request ID, a word count other than one, or a timestamp at/after the exclusive deadline: each condition reaches the same ignored-log-and-return branch (`Raffle.sol:L509-L515`). A duplicate callback is included because the first accepted callback changes `status` away from `Drawing` at `Raffle.sol:L521`. ✓
- Authorized, current, one-word, timely callback: `requestDraw` cannot enter `Drawing` with zero entries (`Raffle.sol:L240-L253`). The only `totalEntries` write follows a `uint128` overflow guard and stores a `uint128` `lastEntry` (`Raffle.sol:L215-L230`); purchases require `Active` (`Raffle.sol:L215`), so they cannot change the divisor in `Drawing`. Consequently the modulo expression selects `1..totalEntries`, which fits `uint128`; the callback then writes only `winningEntry`, `resolvedAt`, and terminal `status`, and emits `RaffleResolved` (`Raffle.sol:L518-L523`). ✓
- Post-callback settlement and claims: a separate permissionless entrypoint invokes `_settleWinningTicket` (`Raffle.sol:L304-L306`, `L533-L558`); separate redemption and release entrypoints burn claims or move ERC-20/ERC-721 assets (`Raffle.sol:L309-L406`, `L560-L566`). There is no control-flow edge from `fulfillRandomWords` to any of them (`Raffle.sol:L509-L524`). ✓
- Callers and callees: the exact `fulfillRandomWords(` search found the raffle override declaration, the base abstract declaration, and the one base dispatch call only (`Raffle.sol:L509`; `VRFV2PlusWrapperConsumerBase.sol:L99-L106`). The override's sole callee is `callbackDeadline`, read above in full (`Raffle.sol:L463-L465`, `L512`). ✓

---

**Searched:**

- Corpus coverage → read all five production files in full: `Raffle.sol`, `RaffleFactory.sol`, `IRaffle.sol`, `IRaffleFactory.sol`, and `RaffleConstants.sol`; read all 31 files named by `target/dependency-hashes.json:L2-L32` in full. Recomputed SHA-256 for each dependency: 31 `MATCH`, 0 `MISMATCH`.
- `rawFulfillRandomWords|fulfillRandomWords` over those 36 files → 6 hits: `Raffle.sol:L509`; base comments at `VRFV2PlusWrapperConsumerBase.sol:L53,L92`; base declaration at `L99`; external gateway at `L101`; internal dispatch at `L106`.
- `fulfillRandomWords\s*\(` over `Raffle.sol` and the Chainlink base → 3 hits: override declaration at `Raffle.sol:L509`, abstract declaration at `VRFV2PlusWrapperConsumerBase.sol:L99`, and the sole call at `VRFV2PlusWrapperConsumerBase.sol:L106`.
- `callbackDeadline\(` over the 36-file corpus → 5 hits: interface declaration at `IRaffle.sol:L381`; draw event use at `Raffle.sol:L272`; refund path use at `L290`; definition at `L463`; callback use at `L512`. The definition at `L463-L465` was read in full.
- `settle|settlement|claim|redeem|refund|payout|proceeds|fees|liabilit|unsettled|winnerRedeemed|prizeClaimed|burn` within `Raffle.sol:L509-L524` → 0 hits.
- `.safeTransfer`, `.safeTransferFrom`, `.transfer`, `.transferFrom`, `call(`, `delegatecall`, `staticcall`, `send(`, and `selfdestruct` within `Raffle.sol:L509-L524` → 0 hits. The same settlement/claim/movement vocabulary within `callbackDeadline` at `Raffle.sol:L463-L465` → 0 hits.
- `winningEntry\s*=|resolvedAt\s*=|status\s*=|emit\s+` within `Raffle.sol:L509-L524` → 5 hits: ignored event at `L514`, result writes at `L519-L521`, and resolved event at `L523`.
- Later-stage function search (`settleWinningTicket`, `_settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, the three `release*` functions, `_transferQuote`) → 8 hits, all outside the callback: `Raffle.sol:L304,L309,L349,L375,L385,L395,L533,L564`.
- Asset-movement/claim-consumption search (`prizeToken.transferFrom|quoteToken.safeTransfer|_burn(`) in `Raffle.sol` → 6 hits, all outside the callback: purchase collection at `L224`, claim burns at `L325,L364`, prize deliveries at `L334,L404`, and quote payout at `L566`.
- Settlement/claim-field mutation search for `settlementComplete`, `winningTicketId`, `winnerProceeds`, `sponsorProceeds`, `protocolFees`, `unsettledPot`, `remainingRefundLiability`, `winnerRedeemed`, and `prizeClaimed` followed by an assignment operator → 16 hits, all outside the callback: `Raffle.sol:L233,L297-L298,L324,L331,L341,L368,L378,L388,L403,L548,L551-L555`.
- Exact `status` assignment search → 6 hits: implementation lock at `Raffle.sol:L165`, initialization at `L205`, draw transition at `L252`, refund transition at `L299`, prize activation at `L428`, and the callback's sole terminal-result write at `L521`.
- Type/state sweep (`totalEntries` assignment or zero check, `type(uint128).max - totalEntries`, `uint128 resolvedEntry`) → 5 hits: overflow guard at `Raffle.sol:L219`, the sole assignment at `L230`, zero checks at `L243,L280`, and bounded callback selection at `L518`.

---

**How the verdict was reached:** This is `implemented`, not `partial`, because every externally reachable gateway/application branch was followed: unauthorized calls revert, malformed ABI never reaches the handler, every authenticated-but-unacceptable callback only logs and returns, and the accepted callback only records the selected entry, resolution time, terminal result, and resolution log (`VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `Raffle.sol:L504-L524`). The sole callback callee is storage-only (`Raffle.sol:L463-L465`). Settlement, claim-state consumption, quote payouts, and NFT delivery occur only through separately invoked functions after resolution (`Raffle.sol:L304-L406`, `L533-L566`). It is not `stronger-than-spec`: authentication and rejection filters control whether a callback result may be recorded; they do not add an undocumented settlement or delivery restriction. Confidence is high because the five production files, all 31 hash-pinned dependencies, the inherited gateway, constructors, fixed clone path, caller, callee, type bounds, and every callback branch were read, and all dependency hashes matched the pinned manifest.

---

**Open questions:**

- None for this requirement.
