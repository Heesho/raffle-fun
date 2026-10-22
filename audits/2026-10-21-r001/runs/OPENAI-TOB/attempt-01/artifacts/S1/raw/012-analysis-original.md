## `_validateCreateParams` in target/packages/contracts/src/RaffleFactory.sol (L154-L179)

**Purpose:** Screens sponsor-selected configuration before the factory increments its counter, creates a clone, or attempts prize escrow. It establishes code presence, specific address exclusions, reported ERC-721 interface support, and a positive reserve; `createRaffle` invokes it first and performs timing and escrow checks later (RaffleFactory.sol:L97-L105, L127-L134, L154-L179).

---

**Inputs & Assumptions:**

- `params` is untrusted calldata passed directly from public `createRaffle`. Its fields are `address sponsorRecipient`, `address prizeToken`, `uint256 prizeTokenId`, `uint128 reserveEntries`, and `uint64 endTime` (RaffleFactory.sol:L97-L98; interfaces/IRaffleFactory.sol:L14-L26). This helper reads the two addresses and reserve; it does not read the token ID or end time (RaffleFactory.sol:L154-L179).
- Implicit inputs are this factory's address, its immutable `quoteToken`, `vrfWrapper`, and `raffleImplementation`, and membership in `isRaffle` (RaffleFactory.sol:L33-L54, L158-L166). Constructor assignments establish the immutable values; successful creation sets registry membership (RaffleFactory.sol:L85-L91, L123-L125).
- Code presence is a delegated precondition, established exclusively by `_requireContract`: it reverts on zero code length and otherwise returns without further inspection (RaffleFactory.sol:L155, L181-L185).
- ERC-721 behavior is an assumption about the arbitrary prize contract. A successful `supportsInterface` response establishes only the reported boolean, not behavioral compliance; nothing found authenticates that assertion in this helper (RaffleFactory.sol:L171-L177). The interface describes the intended standard, but contains no implementation of the sponsor-selected address (IERC165.sol:L15-L24; IERC721.sol:L9-L11).
- A completed creation also needs a future sale end within the permitted duration and a successful prize transfer. Those are established later by `createRaffle`, rather than by this helper (RaffleFactory.sol:L99-L104, L127-L134).

---

**Outputs & Effects:**

The helper has no return value, persistent writes, emitted events, or asset transfers. It either returns normally or fails; its only external interaction is the typed `view` call to `prizeToken.supportsInterface(type(IERC721).interfaceId)` with no attached value (RaffleFactory.sol:L154-L179; IERC165.sol:L24).

On normal return, the prize address had deployed code at the check, neither configured address matched the enumerated prohibited destinations, the sponsor recipient was nonzero, the external call supplied a decoded `true`, and the reserve was nonzero (RaffleFactory.sol:L155-L178, L183-L184). The ABI field width additionally bounds reserve to `uint128`; there is no narrower upper bound here (interfaces/IRaffleFactory.sol:L24; RaffleFactory.sol:L178). These postconditions are validation-time facts; later clone initialization and escrow remain separate operations (RaffleFactory.sol:L105-L134).

---

**Block-by-Block:**

```solidity
// RaffleFactory.sol:L155-L156
_requireContract(params.prizeToken);
if (params.sponsorRecipient == address(0)) revert ZeroAddress();
```

**What:** Rejects a prize address without deployed code and a zero sponsor recipient. **Why here:** These cheap checks precede address classification and the external interface query (L155-L172). **Assumes:** `_requireContract` enforces code presence; its complete body does so on its only successful path (L183-L185). **Establishes:** Positive prize code length and nonzero recipient. **Depended on by:** The external query at L172 and configuration passed to initialization at L113-L115. No code-presence requirement is imposed on the sponsor recipient (L154-L179).

```solidity
// RaffleFactory.sol:L157-L162
if (
    params.prizeToken == address(this) || params.prizeToken == quoteToken || params.prizeToken == vrfWrapper
        || params.prizeToken == raffleImplementation || isRaffle[params.prizeToken]
) {
    revert UnsafeProtocolDestination(params.prizeToken);
}
```

**What:** Excludes this factory, quote token, wrapper, implementation, and already registered same-factory raffles as prize contracts (L158-L161). **Why here:** Those destinations are rejected before they can receive the interface query (L172). **Assumes:** The immutable addresses and local registry represent the intended canonical deployment, established through constructor assignments and creation registration (L85-L91, L123-L125). **Establishes:** A successful path avoids exactly the listed address set. **Depended on by:** `createRaffle` passes this prize address to initialization and uses it for the later transfer and owner query (L115, L127-L130). This is a local registry test, not classification of every externally deployed raffle contract (L54, L159).

```solidity
// RaffleFactory.sol:L163-L169
if (
    params.sponsorRecipient == address(this) || params.sponsorRecipient == quoteToken
        || params.sponsorRecipient == vrfWrapper || params.sponsorRecipient == params.prizeToken
        || params.sponsorRecipient == raffleImplementation || isRaffle[params.sponsorRecipient]
) {
    revert UnsafeProtocolDestination(params.sponsorRecipient);
}
```

**What:** Screens the sponsor recipient against the same plumbing and against the selected prize token (L164-L168). **Why here:** Configuration is screened before clone creation and initialization (L98, L105-L121). **Assumes:** Registry membership is the intended current membership test, supplied by `isRaffle` (L54, L125). **Establishes:** Recipient differs from each enumerated address and has false local registry membership when checked. **Depended on by:** Initialization receives this recipient at L113. The helper does not require recipient consent, an ERC-721 receiver interface, or distinctness from the treasury; no such predicates appear in its full body (L154-L179). Subsequent initialization performs its own destination screening, including the newly created clone's address (Raffle.sol:L193-L195, L593-L604).

```solidity
// RaffleFactory.sol:L171-L177
bool supports721 = false;
try IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
    supports721 = supported;
} catch {
    revert UnsupportedPrizeToken(params.prizeToken);
}
if (!supports721) revert UnsupportedPrizeToken(params.prizeToken);
```

**What:** Queries the sponsor-selected contract and requires a decoded `true` (L171-L177). **Why here:** Address screening has completed, while reserve checking, counter increment, deployment, registration, and escrow have not (L155-L178, L105-L134). **Assumes:** The returned claim corresponds to real ERC-721 support; nothing found establishes that correspondence. **Establishes:** Normal completion of this block requires `supported == true`; caught external-call failures and a decoded `false` both produce `UnsupportedPrizeToken` (L172-L177). This description does not assume every ABI-decoding failure is handled by the catch. **Depended on by:** The caller later invokes `safeTransferFrom` and `ownerOf` at L128-L129.

The implementation behind the prize address is unavailable for this arbitrary runtime input. It is an external black box even though the interface declaration is available. The transmitted argument is the compile-time ERC-721 interface ID and no ETH is sent (L172; IERC165.sol:L24). The typed `view` boundary provides a static call context; a malicious callee can still return an arbitrary boolean, consume gas, fail, or attempt further calls. Successful state-changing effects are excluded by static-call semantics, not by trusting the token's implementation (L172; IERC165.sol:L24). The call has no explicit gas stipend in this source; the interface's less-than-30,000-gas requirement is documentation, not a bound enforced here (IERC165.sol:L22-L24; RaffleFactory.sol:L172).

```solidity
// RaffleFactory.sol:L178
if (params.reserveEntries == 0) revert ZeroReserveEntries();
```

**What:** Rejects a zero reserve. **Why here:** It is the final predicate, following the external interface query (L171-L178). **Assumes:** The ABI supplies the declared `uint128` value (interfaces/IRaffleFactory.sol:L24). **Establishes:** Reserve is in `[1, type(uint128).max]` on success. **Depended on by:** The caller forwards reserve during initialization; the clone stores it and compares final entries against it to select the outcome (RaffleFactory.sol:L118; Raffle.sol:L203, L521).

---

**Cross-Function Dependencies:**

- **`_requireContract` — internal, RaffleFactory.sol:L183-L185:** Complete source read. Zero code length reverts `NotContract(account)`; positive code length returns. It makes no calls and establishes no interface, ownership, or token-identity properties. This is the entire code-presence condition inherited by L155.
- **`IERC165(prizeToken).supportsInterface` — external black box, RaffleFactory.sol:L172; IERC165.sol:L24:** The interface is available, but no concrete arbitrary prize implementation is selected in source. The caller depends on a valid returned boolean and rejects false or a caught call failure (L173-L177). Behavioral ERC-721 compliance remains an unenforced assumption; later `safeTransferFrom` and `ownerOf` checks supply creation-time escrow evidence but remain calls to that same selected contract (L127-L134).
- **Caller:** `createRaffle` is the sole call site in RaffleFactory.sol, is external and marked `nonReentrant`, and invokes validation before its body mutates creation state (L97-L106). It independently checks timing (L99-L104), initializes the clone (L109-L121), registers it (L123-L125), and verifies reported escrow ownership and clone Active status (L127-L134). Thus this helper's success alone is not complete creation success.
- **Shared state:** Immutable dependency addresses come from constructor assignments (L85-L91). `isRaffle` is declared at L54 and set true in creation at L125. This helper reads that mapping twice but never changes it (L159, L166). It does not read the count, ID mappings, treasury, timestamp, or prize ownership (L154-L179).
- **Invariant couplings:** The positive reserve flows into the clone's reserve and outcome comparison (RaffleFactory.sol:L118; Raffle.sol:L203, L521). Recipient exclusion is applied before cloning here and again with clone-specific context during initialization (RaffleFactory.sol:L163-L169; Raffle.sol:L193-L195, L599-L604). Token-standard reporting and escrow completion are separate conditions (RaffleFactory.sol:L171-L177 versus L127-L134).

---

**Open Questions:**

- unclear; need to inspect the concrete sponsor-selected prize implementation to determine whether its `supportsInterface` assertion corresponds to ERC-721 transfer and ownership behavior; the inspected source specifies only the runtime address and typed interface call (RaffleFactory.sol:L172; IERC165.sol:L24).
