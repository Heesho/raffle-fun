## `_update` in target/packages/contracts/src/Raffle.sol (L497-L502)

**Purpose:** Applies the raffle's destination policy to every ticket ownership update before delegating to inherited ERC-721 authorization, approval clearing, balances, ownership and the Transfer event. Zero-address burns bypass destination screening. The hook has no lifecycle predicate, so lifecycle restrictions remain with purchase and claim callers while inherited ticket transfers remain available across states (Raffle.sol L491-L502; ERC721.sol L115-L125, L216-L245; Raffle.sol L215-L218, L310-L325, L349-L364).

---

**Inputs & Assumptions:**

- `to` (address): untrusted recipient on purchases and external transfers, or the trusted internal zero-address burn sentinel. Purchases pass their recipient to `_safeMint`; transferFrom forwards its recipient; `_burn` supplies zero (Raffle.sol L209-L235; ERC721.sol L115-L121, L259-L289, L303-L304).
- `ticketId` (uint256): purchase-generated sequential ID, or an externally supplied transfer/claim ID. The hook does not validate the ID's range or ticket existence itself (Raffle.sol L228-L235, L309-L325, L349-L364, L497-L502; ERC721.sol L115-L121).
- `auth` (address): trusted internal selection of the authority-check mode. Public transferFrom passes `_msgSender()`, which returns msg.sender; mint and burn pass zero. A zero auth explicitly skips inherited authorization and therefore requires authorization and existence discipline in the calling flow (ERC721.sol L121, L220-L222, L263-L266, L303-L307; Context.sol L17-L19; Raffle.sol L320-L325, L359-L364).
- Implicit inputs are the configured prize token, immutable factory and quote token, wrapper address, recipient's current code length, factory implementation and registry, and inherited ownership/approval/balance mappings. No timestamp, lifecycle status, ticket range or payout amount is read by the hook or its screening/ownership-update callees (Raffle.sol L55-L70, L497-L502, L593-L605; ERC721.sol L28-L34, L110-L111, L146-L187, L216-L245, L383-L399).
- Canonical deployment is a necessary scope assumption for treating the factory getter results as the inspected implementation: the factory deploys Raffle and stores that address, while Raffle captures its constructor caller as factory. The hook itself does not authenticate factory bytecode. Established for this deployment path by RaffleFactory.sol L89-L91 and Raffle.sol L155-L162; an arbitrary independent deployment has no equivalent code-identity check in that constructor.
- Correct existing ownership/balance correspondence is needed by inherited unchecked decrements and increments. The inherited update reads the actual stored owner and performs the paired balance changes; purchase bounds and increments keep issued tickets within the uint128 accounting domain. This is an inductive state invariant, not a fresh balance check in the hook (ERC721.sol L146-L147, L216-L240; Raffle.sol L217-L235).

---

**Outputs & Effects:**

- Returns the previous stored owner supplied by ERC721._update; zero means no prior owner. The return is used by inherited mint, burn and transfer wrappers for their distinct validation rules (Raffle.sol L501; ERC721.sol L217, L244, L122-L124, L263-L266, L304-L307).
- A rejected nonzero destination reverts before inherited authorization or any inherited ownership write. Zero recipients skip the entire destination helper and its factory calls (Raffle.sol L498-L501).
- On a successful inherited update, an existing owner's token approval is cleared without emitting Approval; the old owner's balance is decremented when nonzero, the new owner's balance is incremented when nonzero, the token owner is assigned `to`, and Transfer is emitted. Mint has only the increment; burn has only the decrement; self-transfer clears token approval and has zero net balance change (ERC721.sol L225-L242, L383-L399).
- The hook makes no receiver callback. Its external interactions are the helper's conditional view calls to the canonical factory. Safe wrappers perform recipient callbacks after this hook has completed, while ordinary transferFrom performs no recipient acceptance call (Raffle.sol L598-L604; IRaffleFactory.sol L128-L139; ERC721.sol L115-L136, L287-L289).
- No raffle range or monetary accounting variable is written by this hook or its reviewed callees (Raffle.sol L497-L502, L593-L605; ERC721.sol L216-L245, L383-L399). Historical range persistence is separate from token ownership and burns (Raffle.sol L138-L139, L232, L325, L364).

---

**Block-by-Block:**

```solidity
// Raffle.sol L498-L500
if (to != address(0) && _isProtocolDestination(to, address(prizeToken))) {
    revert UnsafeProtocolDestination(to);
}
```

- **What:** Screens every nonzero prospective owner; burns bypass this predicate (L498-L500).
- **Why here:** Screening precedes inherited authorization and storage mutation; an unsafe destination determines the observed revert before owner/approval checks run (L498-L501; ERC721.sol L217-L227).
- **Assumes:** The configured factory is the canonical source supplying implementation and registry answers. Established through canonical constructor wiring, not by this conditional (RaffleFactory.sol L89-L91; Raffle.sol L155-L162).
- **Establishes:** For a successful nonzero update, `to` is distinct from this raffle, the factory, quote token, wrapper, configured prize token and canonical implementation. If it currently has code, it is also not registered in this factory. The helper returns early through boolean short-circuiting for directly matched addresses; unmatched addresses invoke the implementation getter, and only unmatched addresses with code invoke isRaffle (Raffle.sol L598-L604).
- **Depended on by:** The succeeding ownership write and owner-derived claim recipients. Claim functions read current owner and require that owner to call, while quote payout performs its own destination screening (Raffle.sol L320-L342, L359-L369, L564-L566; ERC721.sol L240).
- **Boundary:** This predicate describes known addresses and registry membership at execution time. It makes no generalized claim that every other address can later initiate redemption; it does not query registry membership for code-less destinations, nor does it invoke a recipient's ERC721 receiver method (Raffle.sol L598-L604; ERC721.sol L135, L289).

```solidity
// Raffle.sol L501
previousOwner = super._update(to, ticketId, auth);
```

- **What:** Passes the same recipient, ticket and auth unchanged into the inherited ownership mechanism and returns the prior owner (L501; ERC721.sol L216-L245).
- **Why here:** Ownership can change only after the preceding destination predicate passes (L498-L501).
- **Assumes:** With nonzero auth, the superclass establishes owner/operator authority; with zero auth, the caller has chosen a privileged internal operation and supplied its own necessary checks. Mint/burn deliberately use the zero path, so authorization is conditional rather than a universal hook postcondition (ERC721.sol L220-L222, L263-L266, L303-L307; Raffle.sol L320-L325, L359-L364).
- **Establishes:** Paired ownership/balance updates, approval clearing for existing owners, Transfer emission, and the previous-owner return. No general token-existence check runs on the zero-auth path inside the superclass; mint and burn enforce their opposite existence requirements after the hook returns (ERC721.sol L216-L245, L263-L266, L304-L307).
- **Depended on by:** transferFrom checks its supplied `from` against the returned previous owner; `_mint` rejects an existing prior owner; `_burn` rejects a missing prior owner. Each wrapper's later revert rolls back the earlier update as part of that call (ERC721.sol L121-L124, L263-L266, L304-L307).

---

**Cross-Function Dependencies:**

- **`_isProtocolDestination` (internal):** Fully inspected at Raffle.sol L593-L605. It performs the explicit equality chain, then code-gated registry lookup. The implementation getter is skipped when an earlier equality already matches. isRaffle is skipped when unsafe is already true or destination has no code. There is no try/catch or alternative result if either invoked getter fails; failure propagates before ownership changes (L598-L604).
- **`RaffleFactory.raffleImplementation` (external-source-available):** Generated getter over the immutable address declared at RaffleFactory.sol L42, assigned from the newly deployed implementation at L89-L91. The view interface is IRaffleFactory.sol L128-L130. Its result extends the direct forbidden-address set (Raffle.sol L601).
- **`RaffleFactory.isRaffle` (external-source-available):** Generated mapping getter declared at RaffleFactory.sol L54; createRaffle writes true after initialization and before prize escrow (L109-L128). The view interface is IRaffleFactory.sol L136-L139. A true result rejects an unmatched destination with code; a false result permits this stage to finish (Raffle.sol L602-L604).
- **`ERC721._update` (internal):** Fully inspected at ERC721.sol L216-L245. It obtains the owner, conditionally checks authorization, conditionally clears approval/decrements old balance, conditionally increments new balance, writes ownership, emits Transfer and returns the old owner. It introduces no external call (L217-L244).
- **`ERC721._ownerOf` (internal):** Returns the ownership mapping directly, including zero for an absent owner. Thus the authority check receives the current stored owner rather than a caller-supplied owner (ERC721.sol L146-L147, L217-L221).
- **`ERC721._checkAuthorized` and `_isAuthorized` (internal):** With nonzero auth, the spender must equal owner, be approved-for-all, or hold the per-token approval. Failure chooses NonexistentToken if owner is zero and InsufficientApproval otherwise. The authority predicate relies on the passed owner being current; that is established by _update calling _ownerOf first (ERC721.sol L164-L187, L217-L221).
- **`ERC721.isApprovedForAll` and `_getApproved` (internal dispatch to source-visible mapping reads):** Return the corresponding operator and token approval mappings; the OR expression short-circuits after owner equality or a successful operator approval (ERC721.sol L110-L111, L153-L167).
- **`ERC721._approve` (internal):** The exact update call passes zero recipient, zero auth and false emitEvent. Accordingly, its owner-read/authentication/event branch is skipped, and only token approval clearing occurs. For the other argument paths visible in the callee, it calls _requireOwned, conditionally validates owner/operator authority, and conditionally emits Approval before assignment (ERC721.sol L227, L383-L399).
- **`ERC721._requireOwned` (internal, conditional branch of _approve):** Reads _ownerOf, rejects zero and returns the owner; this branch is not reached by _update's fixed _approve arguments (ERC721.sol L385-L386, L426-L431).
- **Callers:** buyEntries reaches _mint through _safeMint after entry accounting and payment (Raffle.sol L223-L235; ERC721.sol L259-L289). transferFrom reaches the hook with the actual caller, and safeTransferFrom delegates to transferFrom before its receiver check (ERC721.sol L115-L136; Context.sol L17-L19). redeemWinningTicket and refundTickets first require current ownership, then burn through the hook (Raffle.sol L320-L325, L359-L364; ERC721.sol L303-L307). The inherited internal _transfer also calls this hook with zero auth and checks existence/from afterward, with its safe variants adding the receiver check (ERC721.sol L321-L362).
- **Receiver boundary in callers:** ERC721Utils.checkOnERC721Received makes no call for code-less recipients; for recipients with code, it calls an arbitrary receiver and requires the selector, converting an empty revert to InvalidReceiver and bubbling nonempty revert data (ERC721Utils.sol L25-L49). This is outside the _update call tree; acceptance is established only by safe callers, and callback execution may perform further operations after the update (ERC721.sol L133-L136, L287-L289; ERC721Utils.sol L32-L45).
- **Shared state and coupling:** Existing token approvals are cleared by updates; approval and operator setters can independently change authority state (ERC721.sol L93-L111, L225-L227, L383-L418). Quote payouts reuse the destination helper, while claims rely on current ticket ownership rather than original purchase recipient (Raffle.sol L320-L342, L359-L369, L564-L566). The factory registry provides the same-factory classification, and burns leave the purchase-created historical ranges intact (RaffleFactory.sol L54, L123-L125; Raffle.sol L138-L139, L232, L325, L364).

---

**Open Questions:**

None for the direct hook and its source-visible transitive callees under the canonical factory deployment scope. The conditional authorization and destination-membership boundaries are stated above rather than treated as unconditional guarantees (Raffle.sol L497-L502, L593-L605; ERC721.sol L216-L245).

