## `initialize` in target/packages/contracts/src/Raffle.sol (L176-L206)

**Purpose:** Configures a fresh raffle with its sponsor, payout recipients, prize identity, factory identifier, reserve and sale end, then leaves it awaiting prize delivery. The receiver callback subsequently activates sales; initialization alone does not escrow the prize or permit purchases (Raffle.sol:L197-L205, L215-L216, L416-L428).

---

**Inputs & Assumptions:**

- `params` is a calldata `RaffleInitParams`: four addresses, two uint256 identifiers, a uint128 reserve and a uint64 end timestamp (interfaces/IRaffle.sol:L36-L54). Trust is mixed: the sponsor chooses sponsorRecipient, prizeToken, prizeTokenId, reserveEntries and endTime, while the canonical factory supplies sponsor from msg.sender, its immutable treasury, and the incremented identifier (RaffleFactory.sol:L97-L120; interfaces/IRaffleFactory.sol:L14-L26).
- Implicit inputs are the instance's `initialized` flag, immutable `factory` and `quoteToken`, the inherited immutable wrapper, the current instance address, destination code lengths and the factory's implementation and registration getters (Raffle.sol:L177-L178, L593-L604; VRFV2PlusWrapperConsumerBase.sol:L35, L40-L46). The function does not read block.timestamp; date checks occur in its caller (Raffle.sol:L176-L206; RaffleFactory.sol:L99-L104).
- Caller identity is established locally by `msg.sender == factory`; the implementation constructor establishes factory identity as its deployer, and the canonical factory deploys that implementation itself (Raffle.sol:L155-L165, L178; RaffleFactory.sol:L89-L91).
- The fresh-storage precondition is established by `createRaffle` creating a new clone immediately before initialization; Clones uses CREATE with minimal-proxy bytecode, reverts on failed creation, and returns a new instance (RaffleFactory.sol:L105-L121; Clones.sol:L32-L34, L47-L61). Initialization does not reset ticket counts, balances or resolution fields: its writes are limited to initialized and the configuration/status assignments (Raffle.sol:L179, L197-L205).
- Positive reserve, future end time, a maximum 30-day sale, prize code presence and reported ERC-721 support are caller-established conditions, not local validations: `_validateCreateParams` checks the reserve, code and interface report, while `createRaffle` checks the timestamp bounds (RaffleFactory.sol:L98-L104, L154-L178, L183-L184; RaffleConstants.sol:L29-L30).
- Honest, standards-compliant prize behavior is an explicit supported-token assumption; nothing found establishes that behavior through the initializer or the factory's code-presence/interface-response checks (interfaces/IRaffle.sol:L13-L15; Raffle.sol:L181-L205; RaffleFactory.sol:L155, L171-L178). Initialization does not call the prize contract.
- Screening establishes the current finite set of rejected destinations. A screened address being able to control future proceeds, or remaining outside protocol plumbing after initialization, is not established by the comparisons or current code/registry queries: nothing found (Raffle.sol:L187-L195, L593-L604). The function does not require sponsor, sponsorRecipient and protocolTreasury to differ from each other (Raffle.sol:L181-L195).

---

**Outputs & Effects:**

There is no return value or initialization event. On successful return, initialized is true; all eight configuration fields equal the supplied values; status is AwaitingPrize (Raffle.sol:L176-L206). No token or native value is transferred by this function or its helper; the only external interactions are conditional factory getter reads inside the helper (Raffle.sol:L187-L195, L593-L604). Casting prizeToken to IERC721 is a type conversion, not a token call (Raffle.sol:L200).

A failure in validation reverts the call, including the early initialized write; getter failures are not caught (Raffle.sol:L179-L195, L598-L604). This rollback description uses the atomic EVM execution premise supplied in the request's orientation; the cited source locates the relevant write, calls and revert paths. Successful initialization is an intermediate state inside the factory transaction: the factory next registers the clone, requests the NFT transfer, checks reported ownership and Active status, then emits RaffleCreated (RaffleFactory.sol:L123-L147).

---

**Block-by-Block:**

```solidity
// Raffle.sol:L177-L179
if (initialized) revert AlreadyInitialized();
if (msg.sender != factory) revert OnlyFactory();
initialized = true;
```

- **What:** Rejects repeat calls before checking caller identity; only a previously uninitialized instance entered by its immutable factory proceeds (L177-L179).
- **Why here:** Both gates precede configuration reads and writes. The flag is set before any indirect external getter reads, so those reads occur after the instance is marked initialized (L179, L187-L195, L601-L603).
- **Assumes:** Factory identifies the canonical deployment relationship; established by the Raffle constructor and the factory's new Raffle call (Raffle.sol:L161; RaffleFactory.sol:L89).
- **Establishes:** A successful call cannot be repeated. The implementation already has initialized=true from its constructor and therefore fails the first guard (Raffle.sol:L164, L177).
- **Depended on by:** The single assignment of clone-specific configuration and the receiver's use of that configuration (Raffle.sol:L197-L205, L421-L428).

```solidity
// Raffle.sol:L181-L186
if (
    params.sponsor == address(0) || params.sponsorRecipient == address(0)
        || params.protocolTreasury == address(0) || params.prizeToken == address(0)
) {
    revert ZeroAddress();
}
```

- **What:** Rejects a zero value in any of the four address fields (L181-L186).
- **Why here:** Validates those addresses before destination screening and before storing them (L187-L200).
- **Assumes:** Nonzero is only an address constraint; code presence, prize semantics and recipient control require separate evidence (L181-L195; RaffleFactory.sol:L155, L171-L178).
- **Establishes:** All four stored configuration addresses are nonzero on success (L181-L200).
- **Depended on by:** Prize/sponsor matching in the receiver and fixed payout destinations in release functions (L379-L390, L402-L405, L421-L423).

```solidity
// Raffle.sol:L187-L195
if (_isProtocolDestination(params.sponsor, params.prizeToken)) {
    revert UnsafeProtocolDestination(params.sponsor);
}
if (_isProtocolDestination(params.protocolTreasury, params.prizeToken)) {
    revert UnsafeProtocolDestination(params.protocolTreasury);
}
if (_isProtocolDestination(params.sponsorRecipient, params.prizeToken)) {
    revert UnsafeProtocolDestination(params.sponsorRecipient);
}
```

- **What:** Independently screens sponsor, treasury and sponsor recipient; any true result rejects initialization (L187-L195).
- **Why here:** The helper receives the prospective prize address explicitly because storage prizeToken is assigned later (L187-L200; L587-L591).
- **Assumes:** The helper's finite predicate and the canonical getter results are sufficient for the intended destination restriction; its complete path behavior is described below (L593-L604).
- **Establishes:** Each screened address differs from this clone, factory, quote token, wrapper, prospective prize and factory implementation; if the remaining address currently contains code, its factory registration getter must also be false (L599-L604).
- **Depended on by:** Sponsor and treasury payouts use the stored destinations, and sponsor prize release uses sponsorRecipient (L379-L390, L402-L405). This predicate is not a capability test for those recipients (L599-L604).

```solidity
// Raffle.sol:L197-L205
sponsor = params.sponsor;
sponsorRecipient = params.sponsorRecipient;
protocolTreasury = params.protocolTreasury;
prizeToken = IERC721(params.prizeToken);
prizeTokenId = params.prizeTokenId;
raffleId = params.raffleId;
reserveEntries = params.reserveEntries;
endTime = params.endTime;
status = Status.AwaitingPrize;
```

- **What:** Copies configuration and sets the initial lifecycle state (L197-L205).
- **Why here:** All local validation and helper reads finish before any of these eight configuration assignments (L181-L205).
- **Assumes:** Reserve/time/identifier semantics were established upstream; only address constraints are checked locally (L181-L205; RaffleFactory.sol:L98-L120).
- **Establishes:** AwaitingPrize with the exact factory-supplied configuration, without an ownership observation or escrow transfer (L197-L205).
- **Depended on by:** The receiver checks this state and exact prize/sponsor/operator tuple before setting Active; buyEntries requires Active and enforces stored endTime, while fulfillment compares totalEntries with stored reserveEntries (L215-L216, L421-L428, L518-L521).

---

**Cross-Function Dependencies:**

- **Internal callee `_isProtocolDestination` (Raffle.sol:L593-L605):** Read in full. It short-circuits the address comparisons from left to right. A match to this instance, factory, quote token, wrapper or prize returns true without needing the implementation getter; otherwise it queries the factory implementation and compares it. If the resulting predicate is true, it skips the registry. If false and destination.code.length is zero, it also skips the registry and returns false. Only the remaining false/nonzero-code path calls isRaffle(destination), whose boolean becomes the result. Thus registration is checked only on that last path, and no universal statement about all future code or registry states follows (L598-L604).
- **Transitive external-source-available callee `RaffleFactory.raffleImplementation()`:** The generated getter reads an immutable address declared at RaffleFactory.sol:L42 and assigned to the freshly deployed Raffle implementation at L89-L91. Initialization relies on this result to reject the implementation as a recipient; the call occurs only after the preceding OR terms are false (Raffle.sol:L599-L601). There is no additional predicate or external call in this generated getter.
- **Transitive external-source-available callee `RaffleFactory.isRaffle(address)`:** The generated getter reads the mapping declared at RaffleFactory.sol:L54. createRaffle writes true after successful initialization at L123-L125. Initialization depends on this getter for current registration screening of code-bearing destinations; its own clone is rejected separately by address(this), so its not-yet-written registration is not needed for that comparison (Raffle.sol:L599-L604). These getter calls have no try/catch in the helper; call/ABI failures abort initialization (L598-L604).
- **Caller `RaffleFactory.createRaffle`:** Supplies sponsor from the public caller, validates sponsor-selected parameters and time bounds, increments the identifier, clones the immutable implementation, and invokes initialize before registration or prize transfer (RaffleFactory.sol:L97-L128). The initializer itself does not compare supplied treasury to the factory treasury or check identifier uniqueness; those relationships come from the caller's construction of the struct (L105-L120).
- **Shared state and lifecycle:** Configuration feeds prize reception, sale closure, result selection and fixed payout destinations (Raffle.sol:L215-L216, L379-L405, L421-L428, L521). The initialize guard reads initialized, which the implementation constructor also sets; initialize sets AwaitingPrize while the receiver advances it to Active (L164-L165, L177-L179, L205, L428). Initialization's helper is also used for nonzero ticket destinations by _update, with stored prizeToken supplied there (L497-L501).
- **Invariant coupling:** The tuple accepted by onERC721Received is exactly the tuple initialization stored, plus the shared immutable factory (Raffle.sol:L197-L201, L421-L423). Factory transaction completion additionally requires the prize contract to report the raffle as owner and the raffle to report Active; neither property is established by initialize's return alone (RaffleFactory.sol:L128-L134).

---

**Open Questions:**

None for this bounded source-level context record. External prize honesty and future recipient behavior remain explicitly unenforced assumptions above; no execution or chain-state verification is represented as having occurred.

