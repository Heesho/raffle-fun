## `createRaffle` in packages/contracts/src/RaffleFactory.sol (L97-L148)

Citation key (all paths under `packages/contracts/`). A bare `Lnn` means `RF`.

| Key | File |
| --- | --- |
| `RF` | `src/RaffleFactory.sol` |
| `R` | `src/Raffle.sol` |
| `IRF` | `src/interfaces/IRaffleFactory.sol` |
| `IR` | `src/interfaces/IRaffle.sol` |
| `RC` | `src/libraries/RaffleConstants.sol` |
| `RG` | `node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol` (v5.5.0) |
| `CL` | `node_modules/@openzeppelin/contracts/proxy/Clones.sol` (v5.5.0) |
| `I721` / `I165` | `node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol` / `.../utils/introspection/IERC165.sol` |
| `OZ721` / `U721` | `node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol` / `.../ERC721/utils/ERC721Utils.sol` (v5.5.0) |

`OZ721` is cited only as a reference for what a standards-following prize token does. The prize contract is
arbitrary sponsor-chosen code. Its source is not in the project, and it is modeled as adversarial.

---

**Purpose:**

This is the only way a raffle comes into existence, and the only writer of the factory registry. In order, it:

1. screens the sponsor's parameters (L98-L104);
2. deploys an ERC-1167 clone of the locked implementation (L106);
3. initializes the clone (L109-L121). `Raffle.initialize` accepts only the factory as caller (R L178), so no other path can configure a clone;
4. registers the clone (L123-L125). These are the only writes to `raffleById`, `idByRaffle` and `isRaffle`, and L105 is the only write to `raffleCount`, per a grep over `src`;
5. has the sponsor-chosen prize contract move `prizeTokenId` from `msg.sender` into the clone (L128);
6. asks the prize contract (L129) and then the clone (L132) whether that happened.

Every clone's protocol-destination screen reads the registry this function writes (R L601, R L603). Every
clone's prize-delivery path (R L334, R L404) assumes the escrow this function verified. Without
`createRaffle` there are no initialized clones and no registry.

---

**Inputs & Assumptions:**

- `params.sponsorRecipient` (address, IRF L21): receives sponsor proceeds and the returned prize. **Trust: untrusted** (chosen by the sponsor).
  - Checked non-zero (L156).
  - Checked not equal to the factory, `quoteToken`, `vrfWrapper`, the prize token, `raffleImplementation`, or a registered raffle (L163-L169).
  - **Not checked here** against the clone about to be created. That check exists only in `Raffle.initialize` (R L193-L195 → R L599 `destination == address(this)`).
- `params.prizeToken` (address, IRF L22): **Trust: untrusted.** Arbitrary code chosen by the sponsor.
  - Must have code (L155 → L184).
  - Must not be same-factory plumbing (L157-L162).
  - Must self-report `supportsInterface(type(IERC721).interfaceId) == true` (L171-L177).
  - **Not checked here** against `msg.sender` or `protocolTreasury`. Both are rejected only in `Raffle.initialize` (R L187-L192, through `destination == prizeToken_` at R L600).
- `params.prizeTokenId` (uint256, IRF L23): not validated by the factory. The prize contract defines what it means. Stored at R L201 and matched at R L422.
- `params.reserveEntries` (uint128, IRF L24): must be non-zero (L178). There is no upper bound. Stored at R L203 and used at R L521.
- `params.endTime` (uint64, IRF L25): must fall in `(block.timestamp, block.timestamp + 30 days]` (L100-L104, RC L30). Stored at R L204.
- Implicit `msg.sender`: becomes `sponsor` (L112) and the `from` of the prize transfer (L128). **Trust: semi-trusted.**
  - `createRaffle` performs no check on it.
  - `Raffle.initialize` rejects it if it is zero, the clone, the factory, `quoteToken`, the wrapper, the prize token, the implementation, or (when it has code) a registered raffle (R L181-L189, R L599-L604).
- Implicit `msg.value`: always zero. The function is not `payable` (L97), and RF declares no `receive`, `fallback`, `payable` or `onERC721Received` (grep: no match).
- Implicit clock: `block.timestamp` (L99).
- Implicit storage: `raffleCount` (L45), `isRaffle` (L54, read at L159 and L166), and the factory's guard slot (RG L36-L37).
- Implicit immutables (trusted, fixed by the constructor): `raffleImplementation` (L42, set at L89-L91), `protocolTreasury` (L39, L87), `quoteToken` (L33, L85), `vrfWrapper` (L36, L86).
- Implicit external state: the prize contract's ownership and approval records for `prizeTokenId`.

Preconditions on entry, and what establishes each:

- **Factory guard not entered.** Checked by `nonReentrant` (RG L88-L100).
- **`raffleImplementation` has code.** Established by the constructor at L89: `new Raffle(...)` either deploys or reverts. `Clones.clone` does not check this (CL L28-L30). `src` contains no `selfdestruct` (grep), so the code stays.
- **`msg.sender` owns `prizeTokenId` and has approved the factory to move it.** Enforced, if at all, only by the prize contract (black box). For an OZ-like token this is OZ721 L121-L124 and L179-L187. **Nothing in RF checks it.**

---

**Outputs & Effects:**

- **Returns** `raffle`, the new clone address (L106).
- **Factory storage writes:**
  - `raffleCount` (L105);
  - `raffleById[raffleId]` (L123);
  - `idByRaffle[raffle]` (L124);
  - `isRaffle[raffle]` (L125);
  - the guard slot, set to ENTERED and then back to NOT_ENTERED (RG L99, RG L105).
- **Contract creation:** one ERC-1167 proxy via CREATE with value 0 (L106; CL L47-L61).
- **Clone storage writes through `Raffle.initialize`:** `initialized` (R L179), the configuration `sponsor` through `endTime` (R L197-L204), and `status = AwaitingPrize` (R L205).
- **Clone storage write during the prize callback:** `status = Active` (R L428). It happens inside the L128 call frame.
- **External state change:** the prize contract's ownership record for `prizeTokenId`. Expected to move from the sponsor to the clone, but this is a black box.
- **Events, in log order:**
  1. whatever the prize contract emits during L128 (an OZ-like token emits `Transfer`, OZ721 L242);
  2. `PrizeDeposited` from the clone (R L429);
  3. `TicketPurchased` from the clone (R L236), if entries were bought inside L128;
  4. `RaffleCreated` from the factory (L136-L147), last.
- **No native value moves.** The function is non-payable, and `Clones.clone` is called with value 0.
- **Postconditions when the call returns.** Every failure path reverts the whole frame, so these also hold at the transaction boundary:
  - `raffleById[raffleCount] == raffle`, `idByRaffle[raffle] == raffleCount`, and `isRaffle[raffle] == true`.
  - The clone is initialized with exactly the values in the event.
  - At L129, the prize contract answered `ownerOf(prizeTokenId) == raffle`.
  - The clone reported `status == Active` at L132.
  - **Not postconditions:** the clone's `totalEntries`, `ticketCount`, USDC balance and native balance. None of them is read.

---

**Block-by-Block:**

```solidity
// L97
function createRaffle(CreateRaffleParams calldata params) external override nonReentrant returns (address raffle) {
```
- **What:** A non-payable external entry point. `nonReentrant` reverts if the factory guard is ENTERED (RG L88-L92), sets it to ENTERED (RG L99), and restores NOT_ENTERED after the body (RG L105).
- **Why here:** After construction, `createRaffle` is the factory's only state-changing function. L154-L185 are `private view`, and the rest are public getters. So this one guard covers all of the factory's state-changing code during the untrusted call at L128.
- **Assumes:**
  - The ReentrancyGuard base constructor set the guard slot to NOT_ENTERED (RG L58-L60). It runs as part of RF's constructor (inheritance at RF L21).
  - If the body reverts, the ENTERED write is unwound with the rest of the frame, so the guard cannot be left stuck.
- **Establishes:** no nested `createRaffle` on this factory while this frame is live. Until it returns, `raffleCount`, `raffleById`, `idByRaffle` and `isRaffle` change only through this frame.
- **Does not establish:** any protection for the factory's view getters (`isRaffle`, `raffleImplementation`, and the rest have no guard), for the new clone, or for other clones. Each clone has its own guard slot (R L28 inherits ReentrancyGuard).
- **Depended on by:** L105 (a nested call cannot allocate the same ID twice) and L123-L125.

```solidity
// L98  (callee body: L154-L179, L183-L185)
_validateCreateParams(params);
```
- **What:** Screens the prize token and the sponsor recipient, asks the prize contract whether it supports IERC721, and rejects a zero reserve.
- **Paths through the callee.** Every path except full success reverts, and there is no early return.
  1. L155 → L184: `params.prizeToken.code.length == 0` → `NotContract`.
  2. L156: `sponsorRecipient == address(0)` → `ZeroAddress`.
  3. L157-L162: the prize token equals the factory, `quoteToken`, `vrfWrapper` or `raffleImplementation`, or `isRaffle[prizeToken]` is true → `UnsafeProtocolDestination`.
  4. L163-L169: the sponsor recipient equals the factory, `quoteToken`, `vrfWrapper`, the prize token or `raffleImplementation`, or `isRaffle[sponsorRecipient]` is true → `UnsafeProtocolDestination`.
  5. L171-L176: `try IERC165(prizeToken).supportsInterface(0x80ac58cd)`.
     - `supportsInterface` is declared `view` (I165 L24), so this is a STATICCALL. The prize contract cannot write state here.
     - If the callee reverts, the `catch` raises `UnsupportedPrizeToken` (L174-L175).
     - Return data that does not decode as a `bool` fails in the factory's own frame, not in the `catch`. That also reverts.
     - All available gas minus 1/64 is forwarded. The 30 000-gas expectation in I165 L22 is not imposed.
  6. L177: the decoded value is `false` → `UnsupportedPrizeToken`.
  7. L178: `reserveEntries == 0` → `ZeroReserveEntries`.
- **Why here:** It is the first statement, before any write. The only untrusted code it reaches is the read-only STATICCALL in path 5.
- **Assumes:** that `supportsInterface == true` predicts how the contract will behave under `safeTransferFrom`, `ownerOf` and `transferFrom`. **Nothing establishes this.** It is the contract's own claim.
- **Establishes:**
  - The prize token has code at this moment, claims ERC-721 support, and is not the factory, the quote token, the wrapper, the implementation, or a registered same-factory raffle.
    - Without L159, a registered raffle would pass L172-L177: it is itself an ERC-721 ticket collection (R L28 inherits OZ ERC721, whose `supportsInterface` returns true for IERC721, OZ721 L45-L50).
  - The sponsor recipient is non-zero, outside that same set, and not the prize token.
  - `reserveEntries >= 1`.
- **Does not establish:**
  - any check on `msg.sender`;
  - `prizeToken != protocolTreasury`;
  - `sponsorRecipient != <new clone>`. The clone does not exist yet, and the `isRaffle` reads at L159 and L166 see the registry before L125.

  All three are covered only inside `Raffle.initialize` (block L107-L121 below). Raffle clones from other factory deployments are not rejected as prize tokens, because L159 consults only this factory's registry.
- **Depended on by:** L109-L121 and L128. `Raffle.initialize`'s zero-address checks (R L181-L186) can never fire because of L155, L156, RF L68, and `msg.sender` never being zero. L128 calls the prize token that this block screened.

```solidity
// L99-L104
uint256 currentTime = block.timestamp;
if (params.endTime <= currentTime) revert InvalidEndTime(currentTime, params.endTime);
uint256 saleDuration = uint256(params.endTime) - currentTime;
if (saleDuration > RaffleConstants.MAX_SALE_DURATION) {
    revert SaleDurationTooLong(saleDuration, RaffleConstants.MAX_SALE_DURATION);
}
```
- **What:** Limits the sale end to `(now, now + 30 days]` (RC L30).
- **Why here:** It runs before any write and is pure arithmetic.
- **Assumes:** `block.timestamp` is the reference clock. L101 cannot underflow, because L100 has already rejected `endTime <= now`.
- **Establishes:** `endTime > block.timestamp` for the rest of this transaction. Inside the L128 window, that has three consequences:
  - `buyEntries`' sale-open check passes (R L216);
  - `requestDraw` reverts with `RaffleNotEnded` (R L242), so `Active → Drawing` cannot happen;
  - `enableRefunds` on an empty raffle reverts for every caller except `sponsor` (R L280-L284).

  So after L128, the clone's status can only be `AwaitingPrize`, `Active`, or `Refunding`, and `Refunding` only through a call whose `msg.sender` is the sponsor.
- **Depended on by:** what the check at L132 means, and the clone's deadlines (R L458-L460, R L463-L465).

```solidity
// L105
uint256 raffleId = ++raffleCount;
```
- **What:** Allocates the next one-based ID with a checked increment. `raffleCount` starts at 0, so the first ID is 1.
- **Why here:** It is written before the first external CALL (L109), so the ID and the counter are settled before any other contract runs.
- **Assumes:** nothing else increments `raffleCount` during this frame. That holds because of the L97 guard and because L105 is the only write in `src` (grep).
- **Establishes:** `raffleId` is unique across successful creations. If any later step reverts, the increment unwinds with the frame. So at transaction boundaries `raffleCount` counts only completed creations, as IRF L132-L133 states.
- **Depended on by:** L117 (the clone stores it at R L202), L123, L124 and L137.

```solidity
// L106
raffle = Clones.clone(raffleImplementation);
```
- **What:** CREATEs an ERC-1167 proxy whose runtime code DELEGATECALLs `raffleImplementation` (CL L32-L34 → CL L47-L62).
- **Paths through the callee:**
  - `value == 0`, so the balance check at CL L48-L50 never fires.
  - If CREATE returns 0, the call reverts with `FailedDeployment` (CL L59-L61).
  - Otherwise it returns the new address. No path returns without either a deployed clone or a revert.
- **Why here:** after validation and ID allocation, and before initialization.
- **Assumes:** `raffleImplementation` has code. RF L89 establishes this. CL L28-L30 states that the library does not check.
- **Establishes:** `raffle` had no code and a zero nonce before this frame. Otherwise CREATE fails and CL L59-L61 reverts. Its storage is therefore empty:
  - `initialized == false`;
  - `status == AwaitingPrize` (enum value 0, IR L23);
  - its guard slot reads 0, which RG L112-L114 treats as "not entered".

  The proxy's init code runs no implementation code, so no external logic executes here.
- **Also true:** the address is the CREATE address of (factory, factory nonce), so it can be computed before the transaction. `createRaffle` never reads the clone's pre-existing native, quote-token or NFT balances. There is no such read between L106 and L148.
- **Depended on by:** L109 (initialize's `initialized` guard, R L177), L123-L125 and L128.

```solidity
// L107-L121
// The fresh fixed-target clone can initialize only once; this function is nonReentrant and atomic.
// slither-disable-next-line reentrancy-no-eth
IRaffle(raffle).initialize(IRaffle.RaffleInitParams({
    sponsor: msg.sender, sponsorRecipient: params.sponsorRecipient, protocolTreasury: protocolTreasury,
    prizeToken: params.prizeToken, prizeTokenId: params.prizeTokenId, raffleId: raffleId,
    reserveEntries: params.reserveEntries, endTime: params.endTime }));
```
- **What:** A CALL into the clone, which runs `Raffle.initialize` (R L176-L206) against the clone's storage.
- **Paths through `Raffle.initialize`** (read in full). Every failure path reverts and there is no early return, so a partial configuration cannot persist.
  1. R L177: `initialized` is true → `AlreadyInitialized`. **Cannot fire here**, because the clone is fresh (L106).
  2. R L178: `msg.sender != factory` → `OnlyFactory`. **Cannot fire here.** `factory` is an implementation immutable set to the `msg.sender` of the Raffle constructor (R L161), which is this factory at RF L89. DELEGATECALL preserves `msg.sender == factory`.
  3. R L179 sets `initialized = true`.
  4. R L181-L186: zero-address checks on sponsor, sponsorRecipient, protocolTreasury and prizeToken. **Cannot fire here:** `msg.sender` is never zero, and L156, RF L68 and L155 cover the rest (an address with code is non-zero).
  5. R L187-L189: `_isProtocolDestination(sponsor, prizeToken)`. **Can fire.** For example, `msg.sender == params.prizeToken` (R L600), which `createRaffle` does not check.
  6. R L190-L192: `_isProtocolDestination(protocolTreasury, prizeToken)`. **Can fire** in two cases:
     - `params.prizeToken == protocolTreasury` (R L600). L157-L162 do not check this.
     - `protocolTreasury` equals this clone's address (R L599). The constructor screens the treasury only against the factory, quote token and wrapper (RF L80-L83) and the implementation (RF L90).
  7. R L193-L195: `_isProtocolDestination(sponsorRecipient, prizeToken)`. **Can fire** when `params.sponsorRecipient` equals the new clone (R L599), which L163-L169 cannot test.
  8. R L197-L205 write the configuration and `status = AwaitingPrize`.
- **Inside `_isProtocolDestination`** (R L593-L605), the checks run in this order:
  1. Compare against `address(this)` (the clone), `factory`, `quoteToken`, `i_vrfV2PlusWrapper` and `prizeToken_` (R L599-L600).
  2. If none matched, STATICCALL `factory.raffleImplementation()` (R L601). Because `||` short-circuits, this call only happens when the earlier comparisons all fail.
  3. If still unmatched and the destination has code, STATICCALL `factory.isRaffle(destination)` (R L602-L604).

  Those getters (RF L42, L54) have no guard, so they answer while the factory guard is ENTERED. At this moment `isRaffle(raffle)` is still false, because L125 has not run. The clone-itself case is covered by `destination == address(this)`. No untrusted code runs during `initialize`: its only calls go to the factory.
- **Why here:**
  - It runs after the clone exists and before L128, so `prizeToken`, `prizeTokenId`, `sponsor` and `status == AwaitingPrize` are already set when the prize contract's callback reaches R L421-L424.
  - It runs before L123-L125, so every registered clone is an initialized one.
  - The slither annotation at L108 marks the registry writes that follow this external call. Per the path list above, the callee reaches only trusted code.
- **Assumes:** the code behind the clone is the implementation built at RF L89. The target address is fixed in the proxy code (CL L54-L56).
- **Establishes:**
  - The clone's configuration is `(sponsor = msg.sender, sponsorRecipient, protocolTreasury, prizeToken, prizeTokenId, raffleId, reserveEntries, endTime)`.
  - `initialized == true`, so no later `initialize` call by anyone succeeds (R L177).
  - The sponsor, the treasury and the recipient are each distinct from the clone, from the prize token, and from same-factory plumbing.
- **Depended on by:** the acceptance check in `Raffle.onERC721Received` during L128 (R L421-L424), the check at L132, and every later clone function that reads the configuration.

```solidity
// L123-L125
raffleById[raffleId] = raffle;
idByRaffle[raffle] = raffleId;
isRaffle[raffle] = true;
```
- **What:** Registers the clone under its ID.
- **Why here:** after `initialize`, so registration implies initialization, and before the untrusted CALL at L128, so every factory write comes first.
- **Assumes:** `raffle` is new (L106), so `idByRaffle[raffle] == 0` and `isRaffle[raffle] == false` beforehand, and `raffleId` has not been used (L105).
- **Establishes, at transaction boundaries:**
  - For every `1 <= i <= raffleCount`: `raffleById[i] != 0`, `idByRaffle[raffleById[i]] == i`, and `isRaffle[raffleById[i]] == true`.
  - L125 is the only write to `isRaffle` in `src` (grep), so `isRaffle[x]` is true only for clones created here.
- **Window:** throughout the L128 frame, `isRaffle(raffle)`, `raffleById(raffleId)`, `idByRaffle(raffle)` and `raffleCount()` already report the new clone, even though neither L129 nor L132 has run.
  - IRF L136-L139 describes `isRaffle` as "True only for a successfully created canonical clone". That holds at transaction boundaries, not inside L128.
  - During L128, every other clone's `_isProtocolDestination` (R L603) already treats the new clone as protocol plumbing. Ticket transfers to it (R L497-L500) and quote payouts to it (R L564-L566) revert.
- **Depended on by:** every clone's destination screening (R L601-L604), and L159 and L166 in later creations.

```solidity
// L127-L128
IERC721 prize = IERC721(params.prizeToken);
prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
```
- **What:** A CALL into the sponsor-chosen prize contract: the 3-argument `safeTransferFrom(from = msg.sender, to = raffle, tokenId = params.prizeTokenId)` (I721 L73), with value 0 and all gas minus 1/64. No return value is expected, so "success" only means "did not revert". The factory is the operator.
- **Callee:** external black box.
- **Reference behavior** (OZ721; applies to a standards-following token only):
  1. `transferFrom` calls `_update(to, tokenId, auth = factory)` (OZ721 L121).
  2. `_checkAuthorized` requires the factory to be the owner, the token's approved address, or an approved operator (OZ721 L179-L187, L164-L168).
  3. The previous owner must equal `from` (OZ721 L122-L124).
  4. The per-token approval is cleared (OZ721 L227) and the owner is set (OZ721 L240).
  5. `checkOnERC721Received(operator = factory, from, to = raffle, tokenId, "")` runs (OZ721 L135; U721 L25-L49). It calls `Raffle.onERC721Received` and requires the selector back (U721 L34-L36).
- **`Raffle.onERC721Received`** (R L416-L431, read in full; no `nonReentrant`):
  - It reverts with `UnexpectedPrize` unless all of these hold: `status == AwaitingPrize`, `msg.sender == prizeToken`, `tokenId == prizeTokenId`, `from == sponsor`, `operator == factory` (R L421-L426).
  - Otherwise it sets `status = Active` (R L428), emits `PrizeDeposited` (R L429), and returns the selector (R L430).
  - It does not read the prize contract's ownership records.
  - Of its inputs, only `msg.sender` is authenticated by the EVM, and `msg.sender` is the prize contract itself. `operator`, `from` and `tokenId` are arguments chosen by whoever calls it, which here is the prize contract.
- **Outcomes not excluded:**
  1. **Revert.** The whole creation unwinds, including L105-L125.
  2. **Hook without transfer.** The prize contract calls `Raffle.onERC721Received` with `(factory, msg.sender, prizeTokenId)` without changing its own ownership record. The clone becomes `Active` (R L428).
  3. **Return without calling the hook.** The clone stays `AwaitingPrize`, and L132 reverts.
  4. **Re-entry:**
     - into `RF.createRaffle` → `ReentrancyGuardReentrantCall` (RG L88-L92);
     - into the RF view getters → allowed;
     - into the new clone:
       - `initialize` → `AlreadyInitialized` (R L177);
       - `onERC721Received` → as described above, and only once, because a second call sees `Active` (R L422);
       - after `Active`: `buyEntries` (R L209-L237; open because `endTime > now`, R L216), and ticket approvals and transfers;
       - `enableRefunds`, only if a call reaches R L282 with `msg.sender == sponsor`. That moves the clone to `Refunding`, which L132 rejects;
       - `requestDraw` → blocked (R L242);
     - into other clones → whatever their own guards and status allow.

     Any contract reached during this window reads `isRaffle(raffle) == true` (L125).
  5. **Gas.** It can consume the forwarded gas. The remaining 1/64 must cover L129-L147.
- **Why here:** It is the last state-changing step. Every factory storage write is already done (L105, L123-L125). The steps after it (L129, L132) are STATICCALLs, followed by the event.
- **Assumes:** that the prize contract moves `prizeTokenId` from `msg.sender` to `raffle`, and calls the hook with `operator = factory` and `from = msg.sender`. **Nothing in RF or R establishes either one independently of the prize contract.**
- **Establishes:** nothing on its own. The factory learns what happened only through L129 and L132.
- **Also true:** `from` is always `msg.sender` (L128), and RF makes no other ERC-721 transfer call. So `createRaffle` can only move a token out of `msg.sender`. For an OZ-like token, OZ721 L122-L124 also requires `from` to be the current owner.

```solidity
// L129-L131
if (prize.ownerOf(params.prizeTokenId) != raffle) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
```
- **What:** A STATICCALL (`ownerOf` is `view`, I721 L39) asking the prize contract who owns the token.
- **Callee:** external black box. The same contract whose transfer is being checked supplies the answer.
- **Outcomes not excluded:**
  - It returns `raffle` regardless of its own records.
  - It reverts, and the creation unwinds.
  - It returns `raffle` now and a different answer in a later transaction. R L335 and R L405 query the same contract again at delivery time.
- **Why here:** after L128 returns, so a standards-following token has finished updating ownership. Because it is a STATICCALL it cannot change state, so the state at L148 equals the state when L128 returned.
- **Establishes:** "the prize contract reports `raffle` as owner at this moment." For an OZ-like token (OZ721 L61-L63, L426-L432) that is custody. For arbitrary code it is only the prize contract's own claim.
- **Depended on by:** the "funded" meaning of `RaffleCreated` (IRF L30), and downstream by `redeemWinningTicket` and `releaseSponsorPrize`.

```solidity
// L132-L134
if (IRaffle(raffle).status() != IRaffle.Status.Active) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
```
- **What:** A STATICCALL (IR L504 is `view`) to the clone's public getter for `status` (R L124).
- **Why here:** after L128 and L129, as a final check on the clone's own record.
- **Establishes:** R L428 is the only assignment of `Status.Active` in `src` (grep), and the clone was `AwaitingPrize` at L121. So `Active` here means:
  - `Raffle.onERC721Received` completed during L128, with `msg.sender == params.prizeToken` and arguments `(operator = this factory, from = msg.sender, tokenId = params.prizeTokenId)` (R L421-L424);
  - nothing moved the clone out of `Active` afterwards. L99-L104 rule out `Drawing`, and `Refunding` fails this check.
- **Does not establish:**
  - that the prize contract changed any ownership record. It shows only that the prize contract, as `msg.sender`, called the hook with matching arguments;
  - that the clone has no sold entries. `buyEntries` is reachable inside L128 once R L428 has run, and `totalEntries` and `ticketCount` are not read.
- **Also true:** if a prize contract passes an `operator` other than the factory, or a `from` other than the sponsor, R L423 reverts, so no raffle can be created for that token.
- **Depended on by:** the "active" claim of `RaffleCreated` (IRF L30), and every clone function gated on `Active` (R L215, R L241, R L279).

```solidity
// L136-L147
emit RaffleCreated(raffleId, raffle, msg.sender, params.sponsorRecipient, params.prizeToken,
    params.prizeTokenId, quoteToken, protocolTreasury, params.reserveEntries, params.endTime);
```
- **What:** The factory event (IRF L41-L52). `raffleId`, `raffle` and `sponsor` are indexed.
- **Why here:** last, after every check.
- **Establishes:** the emitted values equal the clone's stored configuration:
  - the same expressions feed `Raffle.initialize` (L112-L119 → R L197-L204);
  - `quoteToken` equals the clone's immutable `quoteToken` (R L162). Both come from the same constructor argument, used at RF L89 and stored at RF L85;
  - `protocolTreasury` is the value L114 passed.
- **Log order:** `PrizeDeposited` (R L429) and any `TicketPurchased` (R L236) emitted inside L128 come before `RaffleCreated`.

---

**Cross-Function Dependencies:**

- **Callee `nonReentrant`** (external-source-available, RG L69-L106):
  - It blocks a nested `createRaffle`.
  - The guard is per-contract storage (RG L36-L37). It does not cover the factory's view getters, the new clone, or other clones.
  - A revert anywhere in the body also unwinds the ENTERED write, so there is no path that leaves the guard stuck.
- **Callee `_validateCreateParams`** (internal, RF L154-L179): seven paths, listed in block L98. Only one does not revert. The caller depends on it for: prize-token code, prize-token and recipient plumbing exclusion, the prize token's IERC721 claim, a non-zero recipient, and a non-zero reserve. **It does not cover** the sponsor, `prizeToken != protocolTreasury`, or `sponsorRecipient != new clone`.
- **Callee `_requireContract`** (internal, RF L183-L185): checks `code.length != 0` at call time only. It does not pin behavior or a code hash.
- **Callee `IERC165.supportsInterface` on `params.prizeToken`** (external-black-box, L172):
  - It is a STATICCALL with uncapped gas.
  - Only a well-formed `true` lets execution continue.
  - The answer is a self-report and establishes no behavior.
- **Callee `Clones.clone`** (external-source-available, CL L32-L62): on its only non-reverting path, it returns a fresh address with empty storage. It does not check implementation code; RF L89 covers that.
- **Callee `Raffle.initialize`** (external-source-available, R L176-L206, run against the clone's storage):
  - It sets `initialized`, the configuration, and `AwaitingPrize`. All its failure paths revert.
  - It is where three checks that `createRaffle` itself lacks live:
    - the sponsor is not plumbing and not the prize token (R L187-L189);
    - the treasury is not the prize token, the clone, or a registered raffle (R L190-L192);
    - the recipient is not the clone (R L193-L195).
- **Callee `Raffle._isProtocolDestination`** (external-source-available, R L593-L605, reached from `initialize`):
  - It compares against fixed addresses, then STATICCALLs `factory.raffleImplementation()` (short-circuited).
  - For destinations with code, it then STATICCALLs `factory.isRaffle()`.
  - The `isRaffle` check is gated on code length (R L602), so an address with no code is never looked up in the registry.
- **Callees `RaffleFactory.raffleImplementation()` / `isRaffle()`** (internal getters, RF L42 / L54): the clone re-enters them by STATICCALL during `initialize` while the factory guard is ENTERED. They have no guard and answer from current storage, in which the new clone is not registered yet.
- **Callee `IERC721.safeTransferFrom(address,address,uint256)` on `params.prizeToken`** (external-black-box, L128):
  - It is the only frame in `createRaffle` where untrusted code can change state.
  - It is expected to move the token from `msg.sender` to the clone and to call the hook with `operator = factory`.
  - Not excluded: calling the hook without a ledger change, re-entry into the clone or into other clones, revert, and gas burn.
- **Callee `Raffle.onERC721Received`** (external-source-available, R L416-L431, called by the prize contract during L128):
  - It is the only writer of `Active` (R L428).
  - It authenticates only `msg.sender == prizeToken`. `operator`, `from` and `tokenId` are supplied by the caller.
  - It has no guard and reads no ownership.
- **Callee `IERC721.ownerOf` on `params.prizeToken`** (external-black-box, L129): a STATICCALL answered by the contract being verified. Its answer does not bind the later answers at R L335 and R L405.
- **Callee `Raffle.status()`** (external-source-available, getter R L124, called at L132): `Active` means `onERC721Received` completed in this transaction with matching arguments and no sponsor-initiated `Refunding` followed. It says nothing about the prize ledger or about sold entries.
- **Callers:**
  - There is no caller in `src`. Grepping for `createRaffle` finds only RF L97 and IRF L104.
  - Any EOA or contract can call it, and frontends submit it.
  - Callers assume what IRF L30 and IRF L101-L103 promise: the clone is "initialized, registered, funded, and active" atomically. The "funded" part rests on L129 and L132 only.
- **Shared state:**
  - `raffleCount` (L45): written only at L105.
  - `raffleById` and `idByRaffle` (L48, L51): written only at L123-L124.
  - `isRaffle` (L54): written only at L125. Read at L159 and L166, and by every clone through R L603, including the new clone during `initialize`.
  - `raffleImplementation` (L42, immutable): read at L106, L159 and L166, and by every clone at R L601.
  - The factory guard slot (RG L36-L37).
  - Clone storage: `initialized`, the configuration and `status`, written by R L179 and R L197-L205; `status = Active`, written by R L428 inside L128.
  - The prize contract's ownership record for `prizeTokenId`: external. Written during L128, and read again at R L335 and R L405.
- **Invariant couplings:**
  1. **Registry and destination screening.** Every clone's `_isProtocolDestination` uses `isRaffle` (R L603). It runs for ticket recipients (R L498) and quote payouts (R L565). So the set of rejected destinations grows by one at each L125. That growth happens in the middle of the transaction, before L128.
  2. **Escrow and prize delivery.** `redeemWinningTicket` (R L334-L337) and `releaseSponsorPrize` (R L404-L405) use the same black-box pair that `createRaffle` checked: `transferFrom` followed by an `ownerOf` check. The design requirement "Exactly one ERC721 prize is escrowed atomically at creation" (DESIGN.md L2) is established at creation only to the extent of L129 and L132.
  3. **How long `AwaitingPrize` lasts.**
     - For clones this factory creates, `AwaitingPrize` is visible only inside the `createRaffle` transaction (set at R L205, rejected at L132). So for those clones, `onERC721Received` can succeed only inside the L128 frame.
     - Anyone can deploy their own ERC-1167 proxy pointing at `raffleImplementation`. Such a proxy can never be initialized (R L178). It keeps `status == AwaitingPrize` and `prizeToken == address(0)`, so its `onERC721Received` can never pass `msg.sender == address(prizeToken)` (R L422). It is also not in `isRaffle`.
  4. **Time.** The bound at L100-L104 is what keeps `requestDraw` (R L242) and non-sponsor `enableRefunds` (R L282) closed during L128. That limits the states L132 can observe.
  5. **Sponsor identity.** `msg.sender` (L112) is the only `from` that `onERC721Received` accepts (R L423), and the only address allowed to cancel an empty raffle before `endTime` (R L282).
  6. **Trust statements.** DESIGN.md L2 says arbitrary prize contracts are untrusted. IR L14-L15 and IRF L16 describe prizes as honest and standards-compliant. L129 and L132 together amount to custody only under the second description.

---

**Open Questions:**

- **Treasury vs. future clone addresses.** Unclear; need to inspect the deployment tooling. `foundry.toml` L4 names a `script` directory that is not in the workspace. The question is whether `protocolTreasury_` could equal one of the factory's future clone CREATE addresses. The constructor screens it only at RF L80-L83 and RF L90. If it did:
  - R L190-L192 would revert the `createRaffle` that deploys at that nonce;
  - that revert also unwinds the factory's nonce increment, so every later `createRaffle` would compute the same clone address.

  This is a configuration choice made by the trusted deployer.
- **Which trust model applies to the prize contract.** Unclear. DESIGN.md L2 lists arbitrary prize contracts as untrusted, while IR L14-L15 and IRF L16 say supported prizes are honest and standards-compliant. Under the first model, L129 and L132 are both answered or triggered by the party being verified (assumptions 1-3 in the record).
- **`isRaffle` during the prize callback.** Unclear; need the design intent and the list of integrators that consult `isRaffle`. The question is whether `isRaffle(raffle) == true` during the L128 frame (L125 runs before L128) is intended, given IRF L138's wording "True only for a successfully created canonical clone".
- **Entries sold during creation.** Unclear; need the design intent. Entries can be bought inside the L128 frame (after R L428, before L132). L132 does not read `totalEntries`, and the sponsor's early-cancel path requires `totalEntries == 0` (R L280-L282). Off-chain consumers would also see `TicketPurchased` logs before `RaffleCreated` in the same transaction; the indexer source is not in the workspace.
- **EIP-7702.** Unclear; need to confirm whether the deployment chain supports EIP-7702 delegation designators. Configured networks are Sepolia and Ethereum mainnet (`hardhat.config.ts` L44-L57), compiled for `cancun` (`foundry.toml` L8). Where 7702 is supported, an externally owned account carries non-empty code. It would then pass `_requireContract` (L184) as `params.prizeToken`, and the code-gated `isRaffle` query (R L602) as sponsor or recipient. The code it runs can be re-pointed after creation, which bears on assumption 2 in the record (durable custody).
