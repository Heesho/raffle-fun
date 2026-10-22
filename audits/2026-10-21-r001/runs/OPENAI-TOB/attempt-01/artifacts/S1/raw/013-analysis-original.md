## `onERC721Received` in target/packages/contracts/src/Raffle.sol (L416-L431)

**Purpose:** Activates a configured raffle when its prize contract reports the expected factory-operated transfer from the sponsor. The callback changes `AwaitingPrize` to `Active`; entry purchases and draw requests require `Active` (Raffle.sol L421-L430, L215, L241). The factory requires this transition after its prize transfer before creation can complete (RaffleFactory.sol L127-L134).

---

**Inputs & Assumptions:**
- `operator` (address), `from` (address), and `tokenId` (uint256) are untrusted callback arguments. They must equal immutable `factory`, configured `sponsor`, and configured `prizeTokenId`, respectively (Raffle.sol L416, L422-L425). Comparing `operator` to the factory authenticates the argument's value; the actual EVM caller authenticated here is `prizeToken`, not the factory (L422-L423).
- The final `bytes calldata` parameter is unnamed and unused: no content or length policy appears in the body (L416-L431). Its contents do not contribute to acceptance.
- Implicit inputs are `status`, `msg.sender`, `prizeToken`, `prizeTokenId`, `sponsor`, and `factory` (L422-L423). Successful entry requires exactly `AwaitingPrize`, configured token caller, token ID, sponsor/from, and factory/operator (L421-L426). Every guard is evaluated before the only storage write (L428).
- The canonical creation path establishes configuration by calling `initialize` before transfer; initialization is factory-only and one-shot, writes the sponsor/prize fields, and sets `AwaitingPrize` (RaffleFactory.sol L109-L121; Raffle.sol L176-L205). The factory immutable is established by the implementation constructor (Raffle.sol L155-L165). This callback itself does not test `initialized` or a registry entry (L416-L431).
- The assumption that a matching callback represents an actual ERC-721 ownership transfer relies on the selected prize contract's behavior. Honest standards-compliant prizes are a documented domain assumption (IRaffle.sol L12-L15), not established by the callback's comparisons. **Nothing found** in this function establishes actual ownership: there is no `ownerOf` call (Raffle.sol L416-L431). The factory separately checks the token's reported ownership after `safeTransferFrom` returns (RaffleFactory.sol L128-L131); honesty of that report is also external to this callback.
- No timestamp is read here (L416-L431). Canonical creation verifies a future `endTime` before initializing/transferring, and purchases independently enforce the sale deadline (RaffleFactory.sol L99-L104; Raffle.sol L215-L216).

---

**Outputs & Effects:**
- On any mismatch, reverts with `UnexpectedPrize(msg.sender, tokenId, from, operator)` before storage writes or events in this invocation (Raffle.sol L421-L426).
- On success, writes only `status = Status.Active` and emits `PrizeDeposited(msg.sender, tokenId, from)` (L428-L429). The event's three fields are indexed in its declaration (IRaffle.sol L58-L62).
- Returns the ERC-721 receiver acceptance selector through the named `selector` result (Raffle.sol L419, L430-L431). The receiver interface specifies this selector as the transfer acceptance result (IERC721Receiver.sol L13-L20).
- No internal or external runtime calls occur in the body; `.selector` is selector access, not a call (Raffle.sol L421-L431). There is no token transfer, ticket creation, or balance-accounting change in this body (same lines).
- A second invocation after successful activation fails its status guard unless some other execution first changes the state back to `AwaitingPrize`; the inspected writers set that value only during one-shot initialization (Raffle.sol L177-L179, L205, L422, L428; other lifecycle writes L252, L299, L521). This is an acceptance-state property, not evidence about the external token ledger.

---

**Block-by-Block:**

```solidity
// Raffle.sol L421-L426
if (
    status != Status.AwaitingPrize || msg.sender != address(prizeToken) || tokenId != prizeTokenId
        || from != sponsor || operator != factory
) {
    revert UnexpectedPrize(msg.sender, tokenId, from, operator);
}
```
- **What:** Rejects any lifecycle, caller, token ID, previous-owner argument, or operator argument mismatch (L421-L426).
- **Why here:** All acceptance checks precede the state change and deposit event (L428-L429). The failure path has no preceding mutation within this function (L420-L426).
- **Assumes:** The stored identities are the intended configuration, established on the canonical path by factory initialization (RaffleFactory.sol L109-L121; Raffle.sol L197-L205). The meaning of the supplied `from` and `operator` values depends on the prize contract; nothing in these equality checks proves transfer history (L422-L423).
- **Establishes:** All five equalities hold on the continuing path, including `status == AwaitingPrize` (L422-L423).
- **Depended on by:** Activation and `PrizeDeposited` treat those validated values as the configured prize tuple (L428-L429).

```solidity
// Raffle.sol L428-L430
status = Status.Active;
emit PrizeDeposited(msg.sender, tokenId, from);
selector = IERC721Receiver.onERC721Received.selector;
```
- **What:** Activates the raffle, records acceptance, and returns the required selector (L428-L430).
- **Why here:** It occurs only after all checks pass. State is already `Active` when control returns to the prize contract; no external call intervenes between the write and return (L428-L431).
- **Assumes:** The prize contract honors the receiver protocol and surrounding transaction semantics. The selector requirement is documented in IERC721Receiver.sol L13-L20; conformity of an arbitrary sponsor-selected token is not enforced by assigning a selector (Raffle.sol L430).
- **Establishes:** Local successful-return state is `Active`, and the event identifies the configured token, ID and sponsor by the earlier comparisons (L422-L430).
- **Depended on by:** Factory creation's final status check (RaffleFactory.sol L132-L134) and entry/draw lifecycle gates (Raffle.sol L215, L241). The token contract resumes before the factory's post-transfer ownership/status checks; this ordering follows the external call and subsequent checks (RaffleFactory.sol L128-L134).

---

**Cross-Function Dependencies:**
- **Callees:** None. The receiver selector expression does not invoke the interface implementation (Raffle.sol L430). There are no unvisited callee paths originating from this function (L416-L431).
- **Caller:** The expected callback comes from the sponsor-selected prize contract during `RaffleFactory.createRaffle`'s `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` (RaffleFactory.sol L127-L128; receiver protocol IERC721Receiver.sol L13-L14). The concrete arbitrary prize implementation is not identified by these sources; its control flow and honesty remain external assumptions. The callback accepts matching arguments from that configured contract without checking whether a factory transfer is currently in flight (Raffle.sol L421-L430).
- **Creation coupling:** Factory creation initializes and registers the clone before calling the prize contract, then checks reported owner and `Active` state afterward (RaffleFactory.sol L109-L134). The callback checks the transfer tuple; the factory checks those post-call results. These are distinct checks at distinct points in execution, and neither provides source-level evidence of an arbitrary prize contract's honest ownership accounting (same lines; IRaffle.sol L14-L15).
- **Shared state:** Initialization writes the checked sponsor/prize fields and `AwaitingPrize` (Raffle.sol L197-L205). The constructor locks implementation storage in `Refunding` (L164-L165). Subsequent lifecycle functions set `Drawing`, `Refunding`, or either terminal result, rather than re-enabling deposit acceptance (L252, L299, L521). `buyEntries` and `requestDraw` require the activated state (L215, L241), while `enableRefunds` recognizes `Active` and `Drawing` (L279-L294).

---

**Open Questions:**
- Unclear; need to inspect the concrete sponsor-selected prize contract to establish that callback invocation, operator/from arguments, and ownership reporting correspond to a genuine ownership transfer. The project documents honest ERC-721 behavior as a supported-prize assumption but the configured address is arbitrary at creation (IRaffle.sol L14-L15; RaffleFactory.sol L115-L116, L127-L131).
