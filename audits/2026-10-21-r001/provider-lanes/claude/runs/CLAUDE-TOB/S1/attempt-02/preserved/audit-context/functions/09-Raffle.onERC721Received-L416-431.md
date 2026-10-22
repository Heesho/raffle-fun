## `onERC721Received` in packages/contracts/src/Raffle.sol (L416-L431)

```solidity
// L409-L431
/// @notice Accepts only the exact configured prize deposited by the factory for the sponsor.
/// @dev Unrelated NFTs forced here with unsafe `transferFrom` remain outside protocol accounting and cannot be
///      rescued.
/// @param operator ERC-721 transfer operator, which must be the canonical factory.
/// @param from Previous owner, which must be the configured sponsor.
/// @param tokenId Transferred token ID, which must match the configured prize.
/// @return selector ERC-721 receiver acceptance selector.
function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)
    external
    override
    returns (bytes4 selector)
{
    if (
        status != Status.AwaitingPrize || msg.sender != address(prizeToken) || tokenId != prizeTokenId
            || from != sponsor || operator != factory
    ) {
        revert UnexpectedPrize(msg.sender, tokenId, from, operator);
    }

    status = Status.Active;
    emit PrizeDeposited(msg.sender, tokenId, from);
    selector = IERC721Receiver.onERC721Received.selector;
}
```

File references below:
- Bare `L…` means Raffle.sol.
- `RF` = `packages/contracts/src/RaffleFactory.sol`.
- `E721` = OZ `token/ERC721/ERC721.sol` (v5.6.0).
- `E721U` = OZ `token/ERC721/utils/ERC721Utils.sol`.
- `RG` = OZ `utils/ReentrancyGuard.sol`.

**Purpose:**

- **It is the only `AwaitingPrize` → `Active` transition.** L428 is the only write of `Status.Active` in `src/`.
  - A grep of `status\s*=` returns L165, L205, L252, L299, L428 and L521.
  - These sale and draw paths are gated on `Active`: `buyEntries` (L215), `requestDraw` (L241) and the `Active`
    branch of `enableRefunds` (L279).
  - Every other mutator rejects `AwaitingPrize` (list under L421-L426).
  - A clone that never passes this function therefore never enters its lifecycle.
- **It is the clone's half of escrow verification.** After the prize transfer, `RaffleFactory.createRaffle` checks
  `prize.ownerOf(prizeTokenId) == raffle` (RF L129) and `status() == Active` (RF L132). L428 is the only writer of
  `Active`, so RF L132 passes only if this function succeeded inside the RF L128 transfer call.
- **It is the clone's receiver for every other ERC-721.** Once the clone has left `AwaitingPrize`, every callback
  reverts at L422, so a safe transfer that runs the callback cannot complete into the clone. Two kinds of arrival
  never reach this function:
  - an unsafe `transferFrom` (NatSpec L410-L411);
  - a transfer to the clone address before it has code, because E721U L32 skips code-less recipients.

---

**Inputs & Assumptions:**

- `operator` (address): the claimed initiator of the transfer. Trust: **untrusted**. It is supplied by
  `msg.sender`.
  - Under an OZ-based ERC-721 it is `_msgSender()` of `safeTransferFrom` (E721 L135; `Context.sol` L17-L18
    returns `msg.sender`).
  - In the factory path that is RaffleFactory, which makes the call at RF L128.
- `from` (address): the claimed previous owner. Trust: **untrusted**. It is supplied by `msg.sender`.
  - Under OZ it is the `from` argument of `safeTransferFrom`, which `transferFrom` has already compared with the
    recorded previous owner (E721 L121-L124).
  - In the factory path it is the `createRaffle` caller (RF L128 passes `msg.sender`).
- `tokenId` (uint256): the claimed token. Trust: **untrusted**. It is supplied by `msg.sender`. In the factory
  path it is `params.prizeTokenId` (RF L128).
- Unnamed `bytes calldata`: never read.
  - RF L128 calls the 3-argument `safeTransferFrom` (IERC721 L73), and OZ forwards `""` for it (E721 L129).
  - Whatever a non-OZ prize passes here is unused.
- Implicit `msg.sender`: the one input whose value the caller cannot choose freely. It is compared with stored
  `prizeToken` (L422). Trust: **untrusted**. The documents disagree:
  - DESIGN.md L2: "arbitrary prize contracts ... are untrusted";
  - IRaffle L14-L15: "Supported prizes are honest, standards-compliant ERC-721s".
- Implicit storage reads: `status` (L124), `prizeToken` (L70), `prizeTokenId` (L73) and `sponsor` (L61). The
  immutable `factory` (L55) is read from the implementation's code.
- Not read: `block.timestamp`, `endTime`, `initialized`, the reentrancy-guard slot, and the prize contract's
  ownership ledger. L416-L431 contains no `ownerOf` call.

Preconditions, and what establishes each:

- **The clone is in `AwaitingPrize` and its configuration is written.**
  - Established by `initialize` (L197-L205). It runs once (L177, L179), only for `factory` (L178), and only
    from RF L109-L121.
  - L183 makes `prizeToken` nonzero.
- **The stored `sponsor`, `prizeToken` and `prizeTokenId` equal what the factory uses for the escrow transfer.**
  - `sponsor`: RF L112 (`msg.sender`) → L197. The transfer's `from` is `msg.sender` at RF L128.
  - `prizeToken`: RF L115 → L200. The transfer target contract is `params.prizeToken` at RF L127.
  - `prizeTokenId`: RF L116 → L201. The transfer's `tokenId` is `params.prizeTokenId` at RF L128.
  - All three come from the same calldata and the same `msg.sender`, within one call frame.
- **`factory` is the RaffleFactory that clones and initializes this raffle.** L161 sets `factory = msg.sender` in
  the constructor. RF L89 deploys the implementation, RF L91 stores it, and RF L106 clones it.
- **The arguments describe an actual transfer of `prizeTokenId` from `sponsor` to this clone, made by the
  factory.** **Nothing found** establishes this.
  - The clone authenticates only `msg.sender` (L422). The other three values come from that same caller
    (L416).
  - The caller can obtain each value: `factory`, `sponsor` and `prizeTokenId` are public getters (L55, L61,
    L73). The prize contract also receives `from`, `tokenId` and the factory, as its own `msg.sender`, in the
    `safeTransferFrom` call itself.
  - Only a prize that follows EIP-721 the way OZ does derives these values from a real transfer (E721
    L133-L135, E721U L33).
- **The clone owns `prizeTokenId` once it is `Active`.** Not checked here.
  - RF L129 checks it once, after RF L128 returns, by calling the same prize contract's `ownerOf` (a `view`
    call, IERC721 L39).
  - Nothing checks it again until the release paths (L335, L405), and those also ask the prize contract.
- **The prize contract is honest and standards-compliant.** **Nothing found** on-chain.
  `RaffleFactory._validateCreateParams` checks only three things:
  - the address has code (RF L155);
  - it is not protocol plumbing (RF L157-L162);
  - it reports ERC-721 support through ERC-165 (RF L171-L177).
- **The sale window is open when the raffle becomes `Active`.** RF L100 (`endTime > block.timestamp`) established
  this earlier in the same transaction. This function checks no time.
- **`msg.sender != address(0)`.** This matters only for a clone that was never initialized, where
  `prizeToken == address(0)`. Nothing in code establishes it; it rests on how the EVM derives the transaction
  sender on the configured L1 networks (`hardhat.config.ts` L38-L57).

---

**Outputs & Effects:**

- **Returns** `IERC721Receiver.onERC721Received.selector` (L430), on success only. An OZ prize compares it at E721U
  L34.
- **Storage write:** `status = Status.Active` (L428). This is the only write.
- **Event:** `PrizeDeposited(prizeToken = msg.sender, prizeTokenId = tokenId, sponsor = from)` at L429, declared at
  IRaffle L62 with all three fields indexed.
  - On success, L422-L423 make the three values equal the stored `prizeToken`, `prizeTokenId` and `sponsor`.
  - The clone emits it before RF L129-L136 run. If the factory then reverts, the log is discarded.
- **Reverts:**
  - `UnexpectedPrize(msg.sender, tokenId, from, operator)` (L425; IRaffle L202) when any of the five comparisons
    fails, including the status comparison. The error does not say which comparison failed and does not carry
    `status`.
  - An OZ prize re-raises this non-empty revert data (E721U L38, L43-L45), so `createRaffle` fails with it.
  - Implicit: a nonzero `msg.value` (the function is not `payable`, L416-L419), and calldata the ABI decoder
    rejects.
- **No external calls.** No USDC or NFT moves, the ticket ledger is unchanged, and the guard slot is not accessed.
- **Postcondition on success:** `status == Active`. No other storage changed.

**Creation-window map.** The clone's path through `RaffleFactory.createRaffle` (RF L97-L148, `nonReentrant`),
showing when L421-L426 can pass:

| Step | RF line | Code that runs | Clone `status` / `prizeToken` | Can L421-L426 pass? |
| --- | --- | --- | --- | --- |
| validate | L98 → L155-L178 | prize `supportsInterface`, a `view` call (IERC165 L24; RF L172) | clone not yet deployed | no clone |
| clone | L106 (`Clones.sol` L57, `create`) | factory | `AwaitingPrize` (zero value) / `0` | only if `msg.sender == 0` |
| initialize | L109-L121 | clone; only `view` calls to the factory getters (L601, L603; IRaffleFactory L130, L139) | `AwaitingPrize` (L205) / set (L200) | no non-factory code runs |
| register | L123-L125 | factory storage writes | unchanged | no external code runs |
| escrow | L128 `prize.safeTransferFrom` (CALL; IERC721 L73) | **arbitrary prize code** | `AwaitingPrize` → `Active` at L428 | **yes; only here, at most once** |
| verify custody | L129 `prize.ownerOf` (`view`; IERC721 L39) | prize code, read-only | unchanged | no; the read-only context makes the L428 store revert |
| verify status | L132 `status()` (`view`; IRaffle L504) | clone getter | must be `Active` | not applicable |
| after the transaction | — | anyone | `Active` or later | no; nothing writes `AwaitingPrize` again |

Consequences, each with its source:

- **The window is confined to one frame.** On a clone the factory creates, `AwaitingPrize` with a nonzero
  `prizeToken` exists only inside the RF L128 call frame.
  - At most one such clone exists per factory at a time, because of the factory guard (RF L97).
  - A revert anywhere in `createRaffle` undoes the `create` at `Clones.sol` L57, so the window never persists.
- **Success implies exactly one acceptance.** Every successful `createRaffle` means this function succeeded
  exactly once during RF L128: RF L132 requires `Active`, and L428 is its only writer.

---

**Block-by-Block:**

```solidity
// L416-L420
function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)
    external
    override
    returns (bytes4 selector)
```

- **What:** The IERC721Receiver hook (IERC721Receiver.sol L22-L27; Raffle inherits the interface at L28). It is
  external, non-payable and non-view, and has no modifier.
- **Why here:** An EIP-721 safe transfer calls this selector on a recipient that has code (E721U L32-L33).
  - The clone has no `fallback`. `receive()` (L171) is the only special function in `src/`, and the OZ bases and
    VRF consumer base declare none.
  - So a different receiver selector, such as a legacy 3-argument hook, reverts.
- **Assumes:** No parameter is trusted. `msg.sender` reaches the body unchanged through the ERC-1167 proxy's
  DELEGATECALL (`Clones.sol` L54-L56 bytecode, `5af4`).
- **No `nonReentrant`:** The body makes no external call (L421-L430), so this function cannot be re-entered while
  it runs. See the reentrancy entry under Cross-Function Dependencies for what the missing guard does and does
  not change.

```solidity
// L421-L426
if (
    status != Status.AwaitingPrize || msg.sender != address(prizeToken) || tokenId != prizeTokenId
        || from != sponsor || operator != factory
) {
    revert UnexpectedPrize(msg.sender, tokenId, from, operator);
}
```

- **What:** The call succeeds only when all five equalities hold. The `||` chain short-circuits from left to right,
  and every failing combination produces the same revert.
- **Why here:** All checks run before the single write.
- **What each comparison constrains:**
  1. **`status == AwaitingPrize`.**
     - This makes acceptance one-shot. `AwaitingPrize` is written only at L205, inside the one-shot `initialize`
       (L177-L179), and nothing writes it after L428.
     - The implementation always fails here. Its constructor set `Refunding` (L165), and `initialize` cannot run
       on it (L164, L177).
     - A clone created outside the factory keeps zero storage. So it is `AwaitingPrize` (enum value 0,
       IRaffle L23), and it fails comparison 2 instead.
  2. **`msg.sender == address(prizeToken)`.**
     - This is the only comparison against a value the caller cannot supply. `prizeToken` is written only at L200
       and is nonzero (L183).
     - In a clone that was never initialized, `prizeToken == address(0)`.
     - `prizeToken` cannot be any of these:
       - the factory, quote token, VRF wrapper, implementation or a registered raffle (RF L158-L159);
       - the sponsor (L187 via L600).
  3. **`tokenId == prizeTokenId`.** The left side is a value the caller supplies.
  4. **`from == sponsor`.** The left side is a value the caller supplies. `sponsor` is nonzero (L182).
     - A prize that runs the callback from OZ `_safeMint` passes `from == address(0)` (E721 L289), so it fails
       here.
  5. **`operator == factory`.** The left side is a value the caller supplies; the right side is the immutable.
- **Distinct addresses:** In a passing call, `operator`, `from` and `msg.sender` are three different addresses.
  - `sponsor ≠ factory`: L187 via L599.
  - `sponsor ≠ prizeToken`: L187 via L600.
  - `prizeToken ≠ factory`: RF L158.
- **Assumes:** Comparisons 3-5 reflect a real transfer made by the factory. **Nothing found** enforces this.
  - The compared values come from the same `msg.sender` that comparison 2 authenticates.
  - An honest OZ-style prize passes exactly `(factory, sponsor, prizeTokenId)` for the RF L128 transfer (E721
    L128-L135, E721U L33, `Context.sol` L17-L18), after updating its ledger (E721 L134 → L240).
  - A prize contract that does not report truthfully can still supply the matching values, because each one is
    public (L55, L61, L73) or arrives in its own `safeTransferFrom` calldata.
- **Establishes:**
  - For an honest prize: the callback belongs to the factory's RF L128 transfer of the configured token from the
    sponsor. Comparisons 3-5 cross-check what the factory stored at `initialize` (RF L112-L116) against what the
    prize reports for the RF L128 transfer. Both sides derive from the same calldata and `msg.sender`.
  - For an arbitrary prize contract: only comparisons 1 and 2 bind. The clone is in `AwaitingPrize`, and the
    caller is the configured prize contract.
- **Depended on by:**
  - L428;
  - RF L132, through L428;
  - every `Active`-gated function (L215, L241, L279), which reads `Active` as "prize is escrowed"
    (IRaffle L24-L25).
- **No other mutator is mid-call during `AwaitingPrize`.** Each of these rejects `AwaitingPrize` before any
  external call:
  - `buyEntries` L215;
  - `requestDraw` L241;
  - `enableRefunds` L293;
  - `_settleWinningTicket` L536 (L534 passes first, because `settlementComplete` is written only at L551);
  - `redeemWinningTicket` L312;
  - `refundTickets` L350;
  - `releaseSponsorProceeds` L377 (`sponsorProceeds` is nonzero only after L554);
  - `releaseProtocolFees` L387 (`protocolFees` is nonzero only after L555);
  - `releaseSponsorPrize` L397;
  - `initialize` L177;
  - `fulfillRandomWords`, which ignores the call (L511).

  The ticket ERC-721 functions also fail in this state. No ticket exists yet, because `buyEntries` is the only
  minter and requires `Active`.
  - `transferFrom` and `safeTransferFrom` revert with `ERC721NonexistentToken` (E721 L181-L182). Before that they
    make only `view` calls to the factory (L498 → L601, L603).
  - `approve` reverts at E721 L386 → L429.
  - `setApprovalForAll` succeeds. It writes `_operatorApprovals` and makes no external call (E721 L409-L417).

```solidity
// L428
status = Status.Active;
```

- **What:** Activates the raffle.
- **Why here:** This write comes after every check. Only a log and the return value follow it, so the prize
  contract observes `Active` as soon as this call returns.
- **Assumes:** L422-L423 passed. No other condition applies.
- **Establishes:**
  - `status == Active`.
  - This function cannot succeed again (comparison 1).
  - RF L132 can now pass.
  - `buyEntries` is open: L215 passes, and L216 passes because `endTime > block.timestamp` (RF L100).
  - The sponsor's untimed `enableRefunds` path is open (L279-L284).
  - `requestDraw` stays closed while `block.timestamp < endTime` (L242).
- **Depended on by:** RF L132, L215, L241 and L279. Every later lifecycle transition starts from the state
  written here (L252 from `Active`; L299 from `Active`/`Drawing`; L521 from `Drawing`).

```solidity
// L429
emit PrizeDeposited(msg.sender, tokenId, from);
```

- **What:** A log only. After L422-L423 its fields equal `(prizeToken, prizeTokenId, sponsor)`.
- **Assumes:** Nothing beyond L422-L423. IRaffle L58 documents it as "the factory deposits the configured prize".
  That deposit is the caller's own report (see L421-L426).

```solidity
// L430
selector = IERC721Receiver.onERC721Received.selector;
```

- **What:** The acceptance value. OZ requires an exact match (E721U L34) and otherwise reverts with
  `ERC721InvalidReceiver` (L36).
- **Depended on by:** A conforming prize's `safeTransferFrom`. A prize that ignores the return value can do so; the
  clone has no way to observe that.

---

**Cross-Function Dependencies:**

- **Callees: none.** L416-L431 makes no internal or external call. Reading the immutable `factory` is not a call,
  and the function emits one log.

- **Caller (external-black-box): the prize contract's `safeTransferFrom`, invoked at RF L128.** The prize contract
  is code the sponsor chooses. When it runs, the factory is its `msg.sender` and the factory guard is engaged. The
  clone is already registered (RF L123-L125), its status is `AwaitingPrize`, and its guard slot is 0. The outcomes
  not excluded, and the result of each:
  - **(a) It never calls back.** The status stays `AwaitingPrize`, and RF L132 reverts the creation.
  - **(b) It calls back with `(factory, sponsor, prizeTokenId)` after its ledger moves the token.** This is the
    intended path, in the OZ order (E721 L134, then L135).
  - **(c) It calls back with the matching values, whether or not its ledger changed, and answers RF L129 with the
    clone.**
    - L421-L426, RF L129 and RF L132 all pass.
    - The clone and the factory cannot tell this apart from (b), because the prize contract is the only source of
      both answers.
  - **(d) It calls back with values that do not match.**
    - The call reverts with `UnexpectedPrize`, and an OZ prize re-raises it (E721U L43-L45).
    - A prize that catches the revert can call again with the matching values while the status is still
      `AwaitingPrize`.
  - **(e) It calls back a second time after success.** The second call reverts at comparison 1, and the prize can
    catch that revert.
  - **(f) It continues running after the callback returns, still inside RF L128.**

    At this point the clone is `Active`, `endTime > block.timestamp` (RF L100), no ticket exists, and the clone
    guard slot is unengaged. The prize contract can reach:
    - **`buyEntries`.** L215-L216 pass. The payer needs a USDC allowance to the new clone (L224). Tickets can be
      minted before RF L129-L136 run, so their `TicketPurchased` logs come before `RaffleCreated`.
    - **Ticket ERC-721 functions:** `transferFrom`, `safeTransferFrom` and `approve` on tickets minted in this
      window, and `setApprovalForAll`.
    - **`enableRefunds`, only when `msg.sender == sponsor` (L282).** The prize contract cannot be the sponsor (L187
      via L600), so this requires a contract sponsor that it can drive. Success leaves `Refunding`, and RF L132
      then reverts the creation.

    `requestDraw` reverts at L242, and every other mutator reverts at the gates listed under L421-L426. RF L132
    checks only `status`, so purchases and approvals made in this window survive a successful creation.
  - **(g) It answers `ownerOf(prizeTokenId) != raffle` at RF L129.** The creation reverts.
  - **(h) It calls the clone from inside a read-only context.** The L428 store reverts. RF L129 and RF L172 are
    `view` calls, so the prize contract cannot activate the clone from within them.

- **Reference behaviour (external-source-available): OZ `ERC721.safeTransferFrom` and
  `ERC721Utils.checkOnERC721Received`.**
  - Read in full: E721 L115-L136, L164-L187, L216-L245, L279-L290, L383-L432; E721U L25-L49.
  - They are not callees of this function. They define what "honest, standards-compliant" (IRaffle L14-L15) means
    for the values L422-L423 compare:
    - `operator = _msgSender()` (E721 L135; `Context.sol` L17-L18);
    - `from` is checked against the previous owner (E721 L122-L124);
    - the ledger is updated (E721 L240) before the callback (E721 L135);
    - a code-less recipient gets no callback (E721U L32);
    - a wrong return value raises `ERC721InvalidReceiver` (E721U L34-L36);
    - an empty revert raises `ERC721InvalidReceiver` (E721U L39-L41), and a non-empty revert is re-raised
      unchanged (E721U L43-L45).

- **Caller (trusted, indirect): `RaffleFactory.createRaffle` (RF L97-L148).**
  - What its RF L132 check means comes from this function. L428 is the only `Active` writer, so passing RF L132
    means comparisons 1-5 passed once during RF L128.
  - It does **not** mean that:
    - a transfer happened (RF L129 asks the prize contract separately);
    - no tickets were sold during creation (case f);
    - the custody reported at RF L129 still holds later.

- **Other callers:** Anyone, at any time. Every call reverts except during the "escrow" row of the window map.
  - The clone's own tickets never reach this function. `_update` (L497-L500) rejects `to == address(this)` (L599)
    before `checkOnERC721Received` runs, on both the mint path (E721 L288 → L289) and the transfer path (E721 L134
    → L135).
  - Tickets of another registered raffle are rejected by that raffle's `_update` through `isRaffle`
    (L602-L603). This clone is registered at RF L125, before its `AwaitingPrize` window opens.

- **Reentrancy guard (OZ `ReentrancyGuard`; read RG L36-L37, L58-L60, L69-L73, L94-L114).**
  - This function neither reads nor writes the guard slot.
  - A fresh clone's slot is 0. The constructor write at RG L59 runs only in the implementation, and RG L112-L113
    compare only against 2, so 0 counts as "not entered".
  - No guarded clone function can be on the stack while the status is `AwaitingPrize` (see L421-L426). So the
    missing guard does not let this function observe another clone function's intermediate state.
  - The interval between L428 and RF L129 belongs to the prize contract's frame, which resumes after this function
    returns. A guard scoped to this function would already be released at its exit (RG L102-L105). Clone calls
    made in that interval see the guard as not entered.

- **Shared state:**
  - `status`:
    - Written: L165, L205, L252, L299, L428, L521.
    - Read: L422; L215 and L241 through L574; L279, L289, L293, L311, L396, L511, L514, L521, L523, L535; RF L132
      through the getter.
  - `prizeToken`:
    - Written: L200.
    - Read: L332, L334, L335, L404, L405, L406, L422, L498, L565.
  - `prizeTokenId`:
    - Written: L201.
    - Read: L333, L404, L405, L406, L422.
  - `sponsor`:
    - Written: L197.
    - Read: L282, L423.
  - `factory` (immutable, L55, set at L161):
    - Read: L178, L423, L598, L599.
  - The prize contract's ledger (external): queried at RF L129, L335 and L405. Never read here.

- **Invariant couplings:**
  1. **Every custody fact comes from the prize contract.**
     - The clone accepts on the prize contract's report (L422-L423).
     - The factory checks custody once, through the same contract (RF L129).
     - The release paths transfer and verify through the same contract (L334-L336, L404-L405).
     - The clone never grants approval over the prize. Its only calls on `prizeToken` are `transferFrom` (L334,
       L404) and `ownerOf` (L335, L405). For an honest prize, custody therefore lasts until a release path runs.
     - Nothing observes custody independently of the prize contract.
  2. **One activation per clone.**
     - `AwaitingPrize` is written once (L205, one-shot L177-L179) and left once (L428).
     - Every later transition starts from a state this function cannot produce again. This fixes the order
       `AwaitingPrize` → `Active` → {`Drawing` → `NftWon`/`CashWon`, or `Refunding`}.
  3. **`Active` at creation does not mean "no sales yet".** Tickets can be minted during case (f). The prize
     contract decides the log order of the prize `Transfer`, `PrizeDeposited` and any `TicketPurchased`, all of
     which precede `RaffleCreated` (RF L136).
  4. **No time check here.** The sale window's correctness at activation rests on RF L100-L104, which run earlier
     in the same transaction.

- **Documentation alignment:**
  - **"Deposited" is reported, not observed.** L409 says the function "Accepts only the exact configured prize
    deposited by the factory for the sponsor". The code accepts the configured caller reporting the configured
    `(tokenId, from, operator)`. Whether a deposit happened is that caller's own claim.
  - **`UnexpectedPrize` covers more than a mismatch.** IRaffle L197 describes it as a mismatch with "the
    configured factory prize deposit". The same error is raised for any callback once the clone has left
    `AwaitingPrize` (comparison 1).
  - **The documents disagree on prize trust.**
    - IRaffle L14-L15, IRaffle L40 and IRaffleFactory L16 assume honest, standards-compliant prizes.
    - DESIGN.md L2 calls arbitrary prize contracts untrusted.
    - The on-chain gate is only code presence, the plumbing exclusion and an ERC-165 self-report (RF L155-L177).

---

**Open Questions:**

- **Prize-collection policy.** Unclear; need to inspect the deployment and frontend policy for prize collections.
  - The repo has no tests: DESIGN.md L4 says none are provided, and `./test/hardhat` (named at
    `hardhat.config.ts` L9) contains no files. It also has no allowlist.
  - So it cannot be determined whether only conforming, immutable ERC-721s are expected.
  - On-chain, an upgradeable, admin-controlled or non-conforming prize contract is indistinguishable from a
    conforming one (RF L154-L179). Every escrow check (L422-L423, RF L129) rests on that contract's own answers
    (cases c and f).
- **Off-chain indexers.** Unclear; need to inspect them.
  - Do they treat `PrizeDeposited` (L429) or `RaffleCreated` (RF L136) as proof of escrow? Both are emitted on the
    prize contract's report.
  - How do they handle `TicketPurchased` logs emitted inside the creation window, after L428 and before RF L136
    (case f)?
