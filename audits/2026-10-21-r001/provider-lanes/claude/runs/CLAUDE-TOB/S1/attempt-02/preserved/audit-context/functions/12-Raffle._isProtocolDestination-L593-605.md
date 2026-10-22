## `_isProtocolDestination` in packages/contracts/src/Raffle.sol (L593-L605)

```solidity
// L593-L605
function _isProtocolDestination(address destination, address prizeToken_)
    private
    view
    returns (bool unsafeDestination)
{
    IRaffleFactory canonicalFactory = IRaffleFactory(factory);
    unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
        || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_
        || destination == canonicalFactory.raffleImplementation();
    if (!unsafeDestination && destination.code.length != 0) {
        unsafeDestination = canonicalFactory.isRaffle(destination);
    }
}
```

Paths below are relative to `packages/contracts/`. "VRF base" means
`node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol`. "ERC721", "ERC721Utils",
"Clones" and "ReentrancyGuard" mean the OpenZeppelin v5.5 files under `node_modules/@openzeppelin/contracts/`.
Every callee and inherited dependency named here was read.

---

**Purpose:**

This is Raffle's only denylist predicate. There are five call sites in three functions, and each one turns a
`true` into a revert:

- `initialize` L187, L190 and L193 revert with `UnsafeProtocolDestination` (IRaffle L268). They screen the sponsor,
  the protocol treasury and the sponsor recipient.
- `_update` L498-L500 reverts with `UnsafeProtocolDestination`. It screens the recipient of every ticket mint and
  transfer. Burns skip the screen.
- `_transferQuote` L565 reverts with `InvalidQuoteDestination` (IRaffle L227). It screens the recipient of every USDC
  payout.

The NatSpec (L587) defines the scope as "same-factory protocol plumbing that cannot safely own a ticket or receive a
payout". DESIGN.md L2 says "Never move assets between raffle clones." For tickets and USDC, this function is the only
on-chain mechanism that implements that line.

Without this function, nothing in Raffle stops a ticket from being minted or transferred to, or USDC from being paid
to, any of these: this clone, another clone, the implementation, the factory, USDC, the wrapper or the prize
contract. Neither the factory nor a clone could move such an asset back out:

- RaffleFactory's only state-changing function is `createRaffle` (L97-L148).
- Raffle's asset outflows are L267, L334, L404 and L566, and each goes to a fixed class of recipient.
- No contract in `src` calls another raffle's ticket functions (see coupling 4 below).

---

**Inputs & Assumptions:**

- `destination` (address): the address being screened. Its origin and trust level depend on the call site.

  | Call site | Value | Origin | Trust |
  |---|---|---|---|
  | L187 | `params.sponsor` | `msg.sender` of `createRaffle` (RaffleFactory L112) | semi-trusted |
  | L190 | `params.protocolTreasury` | factory immutable (RaffleFactory L114; L39, set at L87) | trusted |
  | L193 | `params.sponsorRecipient` | chosen by the sponsor (RaffleFactory L113) | untrusted |
  | L498 | `to` | the `recipient` of `buyEntries` (L209, L235), or the `to` of ERC721 `transferFrom`/`safeTransferFrom` (ERC721 L115-L136) | untrusted |
  | L565 | `to` | `msg.sender` (`refundTickets` L369); `ownerOf(ticketId)` (`redeemWinningTicket` L320, L342); stored `sponsorRecipient` (L379-L380); stored `protocolTreasury` (L389-L390) | untrusted, untrusted, untrusted, trusted |

- `prizeToken_` (address): the prize contract, treated as a member of the denylist.
  - At L187, L190 and L193 the argument is `params.prizeToken`, because storage is not written until L200. The
    NatSpec at L588-L589 gives this reason.
  - At L498 and L565 the argument is the stored `address(prizeToken)`.
  - The address is sponsor-chosen code (RaffleFactory L115), validated at RaffleFactory L155-L177.
  - This function only compares it (L600). It never calls it.

- Implicit inputs:
  - `address(this)` (L599). In a clone this is the clone's own address, because the clone runs the implementation's
    code by DELEGATECALL through the 45-byte ERC-1167 runtime (Clones L54-L57).
  - Immutables compiled into the implementation and shared by every clone:
    - `factory` (L55, set at L161);
    - `quoteToken` (L58, set at L162);
    - `i_vrfV2PlusWrapper` (VRF base L35, set at L46 from Raffle L157).
  - Factory state, read by STATICCALL:
    - `raffleImplementation` (RaffleFactory L42), an immutable set at L91;
    - `isRaffle` (RaffleFactory L54), written only at L125 and only to `true`.
  - World state: the code size of `destination` (L602).

- Preconditions, and what establishes each:
  1. **`factory` is the RaffleFactory that deployed this implementation, and it has code.**
     - Established by Raffle L161 (`factory = msg.sender`) together with RaffleFactory L89, where the factory
       constructor deploys the implementation.
     - The Raffle constructor (L155-L166) does not call this function. So no call reaches the factory while the
       factory is still under construction and has no code.
     - Raffle's own check is only `msg.sender != address(0)` (L159). A Raffle deployed by any other account would
       hold a different `factory`. That case is outside the deployed system.
  2. **The immutables match the factory's configuration.**
     - `quoteToken`: RaffleFactory L85, and L89 passes the same value to Raffle L162.
     - The wrapper: RaffleFactory L86, and L89 passes the same value to Raffle L157, which sets VRF base L46.
     - Established by RaffleFactory L89 passing the same arguments it stores.
  3. **`prizeToken_` is this raffle's prize.**
     - Established by the call sites. L187, L190 and L193 pass `params.prizeToken`, which L200 then stores. L498 and
       L565 pass the stored value.
     - L200 is the only write to `prizeToken`. It sits inside the one-shot block guarded by L177-L179.
  4. **`destination` is not the zero address.**
     - This function does not test it. The callers do:
       - `initialize`: L182-L186.
       - Mint: L217 and ERC721 L260.
       - Burn: `to != address(0)` at L498.
       - Transfer: ERC721 L116.
       - `_transferQuote` receives only `msg.sender`, an `ownerOf` result (non-zero via `_requireOwned`, ERC721
         L428-L430), `sponsorRecipient` (non-zero by L182) or `protocolTreasury` (non-zero by L183).
     - In an initialized clone, `_isProtocolDestination(address(0), ...)` returns false. None of the six static
       members is zero (L159, L611, L183/L200, RaffleFactory L89-L91), and address zero has no code.

---

**Outputs & Effects:**

- **Returns** `unsafeDestination`, which is true when either of these holds:
  - `destination` equals `address(this)`, `factory`, `quoteToken`, `i_vrfV2PlusWrapper`, `prizeToken_`, or
    `factory.raffleImplementation()` (L599-L601);
  - `destination` has code and `factory.isRaffle(destination)` is true (L602-L603).
- **No storage writes and no events.** The function is `view` (L595).
- **External interactions:** up to two STATICCALLs to `factory`, plus one EXTCODESIZE. The interface declares both
  getters `view` (IRaffleFactory L130, L139), so the compiler emits STATICCALL. Nothing in the call subtree can write
  state.
- **Paths:**

  | Path | Condition | Calls made | Result |
  |---|---|---|---|
  | A | one of the five local comparisons in L599-L600 matches | none | true |
  | B | no local match, and `raffleImplementation()` matches (L601) | 1 STATICCALL | true |
  | C | no match, and `destination` has no code (L602) | 1 STATICCALL, EXTCODESIZE | false |
  | D | no match, and `destination` has code | 2 STATICCALLs, EXTCODESIZE | `isRaffle(destination)` |

  An EOA recipient, the common case for tickets and payouts, takes path C.
- **Reverts:** the function contains no revert statement. It can revert only in three cases:
  - a STATICCALL reverts;
  - gas runs out;
  - the return data does not ABI-decode to `address` or `bool`.

  With the canonical factory, both getters are compiler-generated (RaffleFactory L42, L54) and have no modifier.
  `nonReentrant` appears only on `createRaffle` (L97).

---

**Block-by-Block:**

```solidity
// L598
IRaffleFactory canonicalFactory = IRaffleFactory(factory);
```
- **What:** casts the `factory` immutable to the interface type. This is not a call.
- **Depended on by:** L601 and L603.

```solidity
// L599-L601
unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
    || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_
    || destination == canonicalFactory.raffleImplementation();
```
- **What:** compares `destination` with five addresses held locally, then with one read from the factory.
- **Why here:** `||` short-circuits from left to right, so the STATICCALL at L601 runs only if all five local
  comparisons are false.
- **Assumes:** Preconditions 1-3.
- **Establishes:** if the result is false, `destination` is none of the six members.
- **Depended on by:** the `!unsafeDestination` guard at L602.
- **Notes:**
  - **Which members vary by clone.**
    - Two members belong to the individual clone: `address(this)` and `prizeToken_`.
    - Four are the same across the whole deployment: `factory`, `quoteToken`, the wrapper and the implementation.
    - So one address can be rejected by one clone and accepted by another. For example, raffle A's prize contract is
      not a member for raffle B, because L600 compares only against B's own prize.
  - **What `address(this)` covers.**
    - During `initialize`, it is the only member that catches the new clone. The clone is registered only after
      `initialize` returns (RaffleFactory L109-L121, then L125).
    - In the implementation instance, it equals `raffleImplementation()`.
  - **`raffleImplementation()` is a constant.** It is a getter for an immutable (RaffleFactory L42, L91), so every
    call returns the same value.
  - **Only one member is sponsor-chosen:** `prizeToken_` (RaffleFactory L115).
  - **Each comparison checks exactly one address.**
    - The wrapper is identified only by `i_vrfV2PlusWrapper`.
    - The quote token is identified only by `quoteToken`.

```solidity
// L602-L604
if (!unsafeDestination && destination.code.length != 0) {
    unsafeDestination = canonicalFactory.isRaffle(destination);
}
```
- **What:** queries the registry, but only for an address that is not yet flagged and has code.
- **Why here:** it runs after the cheaper checks. The code gate saves a STATICCALL for EOAs and other code-less
  addresses (NatSpec L589).
- **Assumes:** every registered raffle has code. This is established by four facts:
  - RaffleFactory L106 (deploy) runs before L125 (register), in the same call frame.
  - Clones L57 deploys with `create`, and L59-L61 revert if the deployed address is zero. The runtime is 45 bytes
    (`602d` at Clones L54).
  - `src` contains no `selfdestruct` (grep).
  - foundry.toml L8 sets `evm_version = "cancun"`. Under EIP-6780, SELFDESTRUCT removes code only in the creation
    transaction.
- **Establishes:** if the function returns false, `destination` is not registered at this instant.
- **Assignment:** L603 runs only when `unsafeDestination` is false. The assignment therefore acts as a logical OR.
- **Refinement of the selection note.** The selection reason implies that the code gate is why the answer can change
  as clones deploy. That is not accurate.
  - At any single instant the gate does not change the answer. Every registered raffle has code, so
    `code.length != 0 && isRaffle(d)` equals plain `isRaffle(d)`. The factory itself uses the ungated form at
    RaffleFactory L159 and L166.
  - The answer changes over time because the registry grows (RaffleFactory L125). It would change in the same way
    without the gate.
  - The gate decides only which path runs (C or D), not the result.
- **EIP-7702:** DESIGN.md L2 names Ethereum as the target chain. A delegated EOA has non-empty code (its delegation
  designator), so it takes path D. `isRaffle` returns false for it, because the only addresses ever registered are
  those returned by `Clones.clone` at RaffleFactory L106.

---

**Cross-Function Dependencies:**

**Callees**

- **`IRaffleFactory(factory).raffleImplementation()`** (external-source-available; RaffleFactory L42).
  - A compiler-generated getter for an immutable. L91 sets it once, to the result of `new Raffle` at L89.
  - Called by STATICCALL (IRaffleFactory L130 declares it `view`).
  - Its only failure mode is running out of gas.
  - This function relies on it to identify the locked implementation. It returns the same address on every call.
- **`IRaffleFactory(factory).isRaffle(destination)`** (external-source-available; RaffleFactory L54).
  - A compiler-generated mapping getter.
  - Written only at RaffleFactory L125, and only to `true`. Grep finds no other write, so an entry is never cleared.
  - Called by STATICCALL (IRaffleFactory L139 declares it `view`).
  - What it returns:
    - True for every clone created by a `createRaffle` that committed.
    - Also true for a clone whose `createRaffle` has passed L125 and is still running. The prize contract runs at
      L128, and the escrow checks at L129-L134 can still revert and roll the registration back. IRaffleFactory L138
      describes the getter as "True only for a successfully created canonical clone". That holds only for committed
      state.
    - False for any address that L106 has not yet produced, including the factory's upcoming CREATE addresses.
- **Factory reentrancy lock.**
  - `createRaffle` holds the lock (L97) while `initialize` runs this function.
  - Neither getter has a guard. OpenZeppelin provides `nonReentrantView` (ReentrancyGuard L83), but the factory does
    not use it. Both STATICCALLs therefore succeed in that context.
  - Both callees are trusted, and STATICCALL blocks state changes anywhere in the call subtree. So these calls
    cannot re-enter with any state effect.

**Callers** (every path was read)

- **`Raffle.initialize`** (L176-L206). Its only caller is `RaffleFactory.createRaffle` (L109-L121).
  - L187 screens the sponsor, L190 the protocol treasury and L193 the sponsor recipient. All three screens run
    before any storage write (L197-L205).
  - The sponsor never receives a payout. Raffle reads `sponsor` only at L282 (early `enableRefunds`) and L423
    (prize-deposit authentication).
  - Of the denylist members, only the prize contract can actually be the caller of `createRaffle`, and L187 rejects
    a prize contract that names itself as the prize. The new clone, the factory, the implementation and registered
    raffles have no code path that calls `createRaffle`:
    - Raffle's external call targets are listed under coupling 4.
    - Neither contract makes `this.` calls (grep).
  - **Overlap with the factory's own checks.**
    - Sponsor recipient: RaffleFactory L163-L169 already checks it against the factory, `quoteToken`, the wrapper,
      the prize, the implementation and `isRaffle` (ungated). L193 adds one member, the new clone
      (`address(this)`).
    - Protocol treasury: the factory constructor checks it against the factory, `quoteToken`, the wrapper and the
      implementation (L80, L90). L190 adds the new clone, the prize and the registered raffles.

- **`Raffle._update`** (L497-L502). It is reached in three ways:
  - Mint: `buyEntries` L235 calls `_safeMint` (ERC721 L279-L290), which calls `_mint` (L259-L267), which calls
    `_update` (L263).
  - Transfer: `transferFrom` (ERC721 L115-L125, calling `_update` at L121), and both `safeTransferFrom` overloads
    (L128-L136, which call `transferFrom` at L134 and then the receiver hook at L135).
  - Burn: `_burn` (ERC721 L304, called from L325 and L364) reaches `_update` with `to == address(0)`. L498 checks
    `to != address(0)` first, so the screen does not run.

  Two ordering facts matter:
  - **The screen runs before ownership and approval checks.** L498 comes before `super._update` at L501, which does
    the checks at ERC721 L217-L222. So anyone can trigger the screen, with any `to` and any token ID, by calling
    `transferFrom`. An unauthorized call then reverts, in `_checkAuthorized` (ERC721 L179-L187) or at ERC721
    L122-L124. The screen is `view`, so this has no state effect.
  - **The screen runs before the receiver hook** (ERC721 L134, then L135; ERC721Utils L32-L33). A code-less
    recipient gets no hook (ERC721Utils L32) and takes path C here.

- **`Raffle._transferQuote`** (L564-L567). It is called from four places:
  - `refundTickets` L369, with `msg.sender`;
  - `redeemWinningTicket` L342, with `winner` (CashWon only);
  - `releaseSponsorProceeds` L380, with `sponsorRecipient`;
  - `releaseProtocolFees` L390, with `protocolTreasury`.

  Each caller zeroes or reduces the liability before the call (L341, L368, L378, L388). A `true` result therefore
  reverts the liability write as well.

**Asset outflows that do not go through this function**

- **NFT to `winner` (L334).** It relies on the `_update` screen that ran when `winner` received the ticket.
- **NFT to `sponsorRecipient` (L404).** It relies on L193, at initialization. The USDC outflow to the same address
  (L380) is screened again at release time, through L565. The NFT outflow is not screened again.
- **Native excess to `msg.sender` (L267).** Not screened.
- **Native fee to the wrapper (VRF base L84).** The wrapper is the intended payee.
- **ERC-721 approvals (ERC721 L93-L107).** These do not move ownership and are not screened.

**Shared state**

- Raffle immutables: `factory` (L55), `quoteToken` (L58), `i_vrfV2PlusWrapper` (VRF base L35).
- Raffle storage: `prizeToken` (L70), read through the callers. Written only at L200.
- RaffleFactory: `raffleImplementation` (L42) and `isRaffle` (L54). `createRaffle` writes `isRaffle` at L125.
- The account code at `destination` (EXTCODESIZE).

**Invariant couplings**

1. **Every registered raffle has code.** The evidence is under L602-L604 above. This is what makes the L602 gate
   safe.

2. **For a given clone and destination, the answer changes only from false to true.**
   - None of the inputs can change in the other direction:
     - `address(this)` is fixed for a clone.
     - `factory`, `quoteToken` and the wrapper are immutables.
     - `prizeToken_` is written once (L200, guarded by L177-L179), and the value passed during `initialize` equals the
       value stored afterwards.
     - `raffleImplementation` is immutable (RaffleFactory L42, L91).
     - `isRaffle` is only ever set to true (L125).
     - Code is never removed (coupling 1).
   - The only false-to-true change is the factory creating and registering a clone at `destination` (RaffleFactory
     L106, L125).
     - CREATE fails when the target already has code or a non-zero nonce (EIP-684), and Clones L59-L61 turn that
       failure into a revert.
     - So `destination` had no code at every earlier evaluation, and those evaluations took path C.
   - Upcoming clone addresses can be computed from public state:
     - CREATE addresses come from the creator's address and nonce.
     - The factory uses CREATE only at L89 (the implementation) and L106 (clones).
     - A reverted `createRaffle` also reverts the nonce increment, so a failed creation leaves the next address
       unchanged.
   - No one holds a private key for a CREATE address. So any address that can flip was, before the flip, an address
     no one controls.

3. **No untrusted code runs while a new clone has code but is not yet registered.**
   - Between RaffleFactory L106 and L125, only `initialize` runs. Its only external calls are this function's
     STATICCALLs to the factory, and `address(this)` covers the clone's own address.
   - Untrusted code first runs at L128 (the prize contract), which is after L125.

4. **What a flip does at each caller.** These are structural effects only.
   - **`_update` (L498): owners are never re-screened.**
     - The owner recorded when the screen passed stays the owner.
     - A clone has no code path that calls another raffle's ticket functions. Raffle's external call targets are:
       - `quoteToken` (L224, L566);
       - the wrapper (L437, L442; also L257 via VRF base L82-L88);
       - `msg.sender`, with empty calldata (L267);
       - `prizeToken` (L334-L335, L404-L405);
       - the factory (L601, L603);
       - ERC-721 receiver hooks on screened recipients (ERC721Utils L33).
     - `prizeToken` can never be a raffle. RaffleFactory L159 rejects registered raffles and the implementation, and
       L155 requires code at creation, which rules out addresses of future clones.
   - **`initialize` (L187-L195): the screened recipients are written once.**
     - `sponsorRecipient` and `protocolTreasury` are set once (L198-L199). They are screened again on every USDC
       release (L565, via L380 and L390).
     - After a flip, every USDC release to that address reverts with `InvalidQuoteDestination`. There is no other
       recipient path, because L379 and L389 read the stored values.
     - `releaseSponsorPrize` (L402-L405) does not call this function. It transfers the NFT to the address even after
       a flip.
   - **`protocolTreasury` and future clone addresses.**
     - RaffleFactory L80 and L90 compare the treasury only against addresses that exist at construction.
     - Suppose the treasury equals the address of a future clone. The flip is then never reached through the factory:
       - That clone's own `initialize` rejects the treasury at L190-L191 through `address(this)` (L599).
       - `createRaffle` reverts, which rolls back the CREATE and the nonce increment.
       - Every later `createRaffle` targets the same address.
   - **`_transferQuote` (L565)** runs at payout time, so it always sees the current registry.

5. **Addresses that are never compared:**
   - `i_linkToken` (VRF base L34, set at L45 from `wrapper.link()`).
   - The wrapper's coordinator, or any other address behind the wrapper.
   - Any address behind `quoteToken` other than `quoteToken` itself. L599-L600 compare against one address each.
   - Other raffles' prize contracts. L600 compares only against this raffle's prize.
   - Clones of the implementation created by anyone other than the factory. Any contract can call `Clones.clone`, and
     such a clone is neither the implementation nor registered.
   - Clones registered in a different RaffleFactory deployment. L603 queries only this deployment's registry. The
     NatSpec at L587 limits the function to "same-factory", but DESIGN.md L2 states "Never move assets between raffle
     clones" with no such limit.
   - By design, `protocolTreasury`, `sponsor` and `sponsorRecipient`. These are the payees the function screens.

6. **The implementation instance.**
   - Its `prizeToken` storage is never written: the constructor does not set it (L155-L166), and `initialize`
     reverts at L177. So `prizeToken_` is zero there.
   - The function is reachable there only through `transferFrom`, because L498 runs before `super._update`. The call
     then reverts, since no token exists.
   - `_transferQuote` is unreachable on the implementation:
     - `refundTickets` reverts at L359, since no tokens exist.
     - `redeemWinningTicket` reverts at L312, since the status is `Refunding`.
     - `releaseSponsorProceeds` and `releaseProtocolFees` revert on zero balances (L377, L387).

---

**Open Questions:**

- Unclear; need to inspect the deployment tooling to see how `protocolTreasury` is chosen relative to the factory's
  future CREATE addresses. RaffleFactory L80 and L90 compare only against addresses that exist at construction. The
  repository has no `packages/contracts/script` directory and no test files (glob returned none), so the tooling is
  not available here.
- Unclear; need design input on whether raffles from a different RaffleFactory deployment count as "raffle clones"
  under DESIGN.md L2. L603 queries only this factory's registry.
- Unclear; need design input on whether `i_linkToken` (VRF base L45) and the wrapper's coordinator were meant to be
  denylist members. Neither is compared.
- Unclear; need design input on why the two outflows to `sponsorRecipient` are screened at different times. USDC is
  screened at release (L380 → L565). The NFT is screened only at initialization (L193, then L402-L405). The
  difference is observable only for an address whose answer flips (coupling 2).
