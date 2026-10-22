## REQ-17 — Atomic single-prize escrow

> "Exactly one ERC721 prize is escrowed atomically at creation."
> — `DESIGN.md:L2, sentence 4`

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** The property to preserve is the quoted requirement, "Exactly one ERC721 prize is escrowed atomically at creation." Concretely, one creation call must bind one prize-token address and token ID to one new raffle, transfer that configured token into the new raffle, and publish the raffle only after custody is established. The supplied checkable interpretation is also verbatim: "Raffle creation and prize escrow succeed or revert together, leaving neither a partial raffle nor a partial transfer."

---

**Where enforcement lives:**

The only production implementation of `createRaffle` is a `nonReentrant` external entrypoint. It validates before the first creation-state write, then increments the ID and creates one fixed-target clone (`RaffleFactory.sol:L97-L106`):

```solidity
// RaffleFactory.sol:L97-L106
function createRaffle(CreateRaffleParams calldata params) external override nonReentrant returns (address raffle) {
    _validateCreateParams(params);
    uint256 currentTime = block.timestamp;
    if (params.endTime <= currentTime) revert InvalidEndTime(currentTime, params.endTime);
    uint256 saleDuration = uint256(params.endTime) - currentTime;
    if (saleDuration > RaffleConstants.MAX_SALE_DURATION) {
        revert SaleDurationTooLong(saleDuration, RaffleConstants.MAX_SALE_DURATION);
    }
    uint256 raffleId = ++raffleCount;
    raffle = Clones.clone(raffleImplementation);
```

The factory initializes that clone with exactly one `prizeToken`/`prizeTokenId` pair, writes the three registry entries, makes exactly one creation-time ERC-721 transfer call for that pair, and then requires both reported custody and activation (`RaffleFactory.sol:L109-L134`):

```solidity
// RaffleFactory.sol:L109-L134
IRaffle(raffle)
    .initialize(
        IRaffle.RaffleInitParams({
        sponsor: msg.sender,
        sponsorRecipient: params.sponsorRecipient,
        protocolTreasury: protocolTreasury,
        prizeToken: params.prizeToken,
        prizeTokenId: params.prizeTokenId,
        raffleId: raffleId,
        reserveEntries: params.reserveEntries,
        endTime: params.endTime
    })
    );

raffleById[raffleId] = raffle;
idByRaffle[raffle] = raffleId;
isRaffle[raffle] = true;

IERC721 prize = IERC721(params.prizeToken);
prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
if (prize.ownerOf(params.prizeTokenId) != raffle) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
if (IRaffle(raffle).status() != IRaffle.Status.Active) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
```

`RaffleCreated` is emitted only after those transfer and postcondition checks (`RaffleFactory.sol:L136-L148`). There is no `try`/`catch` around the transfer or either postcondition in the complete entrypoint (`RaffleFactory.sol:L97-L148`), so a transfer revert, a reverting `ownerOf`, either explicit verification revert, or any later revert propagates out of the same call frame. EVM call-frame rollback therefore removes the earlier counter increment, clone creation, initialization, registry writes, receiver transition, and token-state changes together.

The clone initialization is factory-only and one-time, stores the one configured token and ID, and finishes in `AwaitingPrize` (`Raffle.sol:L176-L205`):

```solidity
// Raffle.sol:L176-L180, L197-L205
function initialize(RaffleInitParams calldata params) external override {
    if (initialized) revert AlreadyInitialized();
    if (msg.sender != factory) revert OnlyFactory();
    initialized = true;

    sponsor = params.sponsor;
    sponsorRecipient = params.sponsorRecipient;
    protocolTreasury = params.protocolTreasury;
    prizeToken = IERC721(params.prizeToken);
    prizeTokenId = params.prizeTokenId;
    raffleId = params.raffleId;
    reserveEntries = params.reserveEntries;
    endTime = params.endTime;
    status = Status.AwaitingPrize;
}
```

The receiver accepts only the configured token contract, configured token ID, configured sponsor, and canonical factory operator while the clone is still awaiting its prize. Its sole successful branch changes the status to `Active`; after that transition the same acceptance branch cannot be taken again (`Raffle.sol:L416-L430`):

```solidity
// Raffle.sol:L416-L430
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

The factory's modifier is substantive rather than nominal: `nonReentrant` runs the pre-check before the body and restores the guard afterward, while the pre-check reverts when the same factory guard is already entered (`ReentrancyGuard.sol:L69-L72`, `L88-L105`). Thus sponsor-selected token code reached by validation or transfer cannot nest another successful `createRaffle` while the outer creation has partial registry state (`RaffleFactory.sol:L97`, `ReentrancyGuard.sol:L88-L105`). The selected `Clones.clone` overload uses `create` and explicitly reverts if deployment returns the zero address (`Clones.sol:L32-L33`, `L47-L61`).

For a standards-compliant OpenZeppelin ERC-721 path, `safeTransferFrom` performs the ownership update and then invokes the receiver (`ERC721.sol:L115-L135`); receiver rejection or a bubbled receiver revert causes that transfer call to revert (`ERC721Utils.sol:L32-L45`). The factory does not rely on that implementation name alone: it independently reads `ownerOf` and the clone's `Active` status after the call (`RaffleFactory.sol:L127-L134`).

---

**Paths walked:**

- `createRaffle` → `_validateCreateParams`: missing code, a zero or protocol destination, failed/false ERC-165 response, or zero reserve reverts before `raffleCount` is incremented (`RaffleFactory.sol:L98-L105`, `L154-L179`). ✓
- `createRaffle` → time validation: an expired end time or duration over 30 days reverts before the first creation-state write at `raffleCount` (`RaffleFactory.sol:L99-L105`). ✓
- `createRaffle` → `Clones.clone` → `clone(implementation, 0)`: failed `create` reverts instead of returning a raffle address (`Clones.sol:L32-L33`, `L47-L61`). ✓
- `createRaffle` → `Raffle.initialize`: repeat initialization, a non-factory caller, a zero required address, or an unsafe destination reverts; the successful branch records exactly one prize pair and ends in `AwaitingPrize` (`Raffle.sol:L176-L205`). Because this high-level call is not caught in `createRaffle`, failure rolls back the counter and fresh clone (`RaffleFactory.sol:L105-L121`). ✓
- `createRaffle` → registry writes → `prize.safeTransferFrom`: a transfer revert propagates because the call at `RaffleFactory.sol:L128` is not wrapped by the factory's only `try`/`catch` sites, which are the constructor decimal query and pre-creation ERC-165 query (`RaffleFactory.sol:L71-L74`, `L127-L134`, `L171-L176`). The earlier registry and clone changes therefore do not persist. ✓
- `safeTransferFrom` → `Raffle.onERC721Received`: any mismatch in lifecycle, token contract, token ID, previous owner, or operator reverts (`Raffle.sol:L421-L425`). The exact-match branch alone activates the clone and returns the receiver selector (`Raffle.sol:L428-L430`). ✓
- `safeTransferFrom` returns → ownership postcondition: a reverting `ownerOf` propagates, and a reported owner other than the clone triggers `PrizeEscrowVerificationFailed` (`RaffleFactory.sol:L127-L131`). ✓
- Ownership postcondition passes → lifecycle postcondition: failure to execute the exact receiver transition leaves a status other than `Active` and explicitly reverts (`RaffleFactory.sol:L132-L134`; `Raffle.sol:L421-L430`). ✓
- Both postconditions pass → publication: only then is `RaffleCreated` emitted and the function returns (`RaffleFactory.sol:L136-L148`). ✓
- A second purported creation-time deposit → `onERC721Received`: the first accepted deposit changes `AwaitingPrize` to `Active`, so the lifecycle clause rejects a second accepted callback (`Raffle.sol:L421-L430`). ✓
- Sponsor-selected token reentry → `createRaffle`: the outer entrypoint has already entered the factory guard, and the nested pre-check reverts (`RaffleFactory.sol:L97`; `ReentrancyGuard.sol:L69-L72`, `L88-L105`). ✓
- Callers of `createRaffle`: the 36-file review scope contains only the external implementation and interface declaration (`RaffleFactory.sol:L97`; `IRaffleFactory.sol:L104`); there is no in-scope wrapper or alternate creation path. ✓

---

**Searched:**

- Scope → all five production files were read in full; all 31 paths in `dependency-hashes.json` were read in full, and all 31 SHA-256 values matched the manifest.
- `\bcreateRaffle\b` across the five production files and 31 declared dependencies → 2 matching lines: `RaffleFactory.sol:L97` and `IRaffleFactory.sol:L104`; no caller or second implementation.
- `safeTransferFrom|ownerOf|PrizeEscrowVerificationFailed` across the same scope → 34 matching lines. The creation-relevant enforcement is `RaffleFactory.sol:L128-L133`; the other hits are quote-token transfer code, later prize-release checks, and generic ERC-20/ERC-721 interfaces or helpers.
- `prize.*transfer|transfer.*prize|safeTransferFrom` in production → 6 matching lines. Exactly one is a creation-time prize transfer (`RaffleFactory.sol:L128`); `Raffle.sol:L334` and `L404` are later terminal prize releases, and `Raffle.sol:L224` is the quote-token purchase transfer.
- `onERC721Received|AwaitingPrize|PrizeDeposited|UnexpectedPrize` across the full scope → 22 matching lines. The stateful creation hits are `Raffle.sol:L205`, `L416`, `L422`, `L425`, `L429`, and `L430`; the rest are interface and dependency declarations/documentation.
- `raffleCount|raffleById|idByRaffle|isRaffle|RaffleCreated` across the full scope → 17 matching lines. The creation writes and final publication are `RaffleFactory.sol:L105`, `L123-L125`, and `L136-L147`.
- `nonReentrant|ReentrancyGuard` across the full scope → 43 matching lines. The relevant hits are the factory inheritance and modifier at `RaffleFactory.sol:L21`, `L97`, plus the guard implementation at `ReentrancyGuard.sol:L69-L72`, `L88-L105`.
- `_validateCreateParams|_requireContract|supportsInterface` across the full scope → 14 matching lines. The production call chain is `RaffleFactory.sol:L98`, `L154-L183`; dependency hits define or implement ERC-165.
- `\btry\b|\bcatch\b` in `RaffleFactory.sol` → 4 matching lines, at `L71`, `L73`, `L172`, and `L174`; 0 hits in the complete `createRaffle` body at `L97-L148`.
- `Clones\.clone|function clone\(` in production plus `Clones.sol` → 3 matching lines: the call at `RaffleFactory.sol:L106` and the two selected overloads at `Clones.sol:L32`, `L47`.
- `status = Status\.(AwaitingPrize|Active)|status\(\) != IRaffle\.Status\.Active` in production → 3 matching lines: initialization at `Raffle.sol:L205`, activation at `Raffle.sol:L428`, and the factory postcondition at `RaffleFactory.sol:L132`.
- `atomic|atomically|escrow|escrowed|deposit|fund` across the full scope → 93 matching lines. Those vocabulary hits included comments and unrelated refund/VRF funding paths; the verdict rests on the executable call chain above, not those names.
- `contract .*ERC721` across the full scope → 3 matching lines: the raffle's ticket contract (`Raffle.sol:L28`), the abstract OpenZeppelin reference implementation (`ERC721.sol:L19`), and an interface comment (`IERC721Receiver.sol:L13`). No concrete sponsor-selected prize implementation is present.

---

**How the verdict was reached:** This is `implemented`, not merely a promisingly named atomic function, because the complete successful path was read through clone creation, initialization, registry mutation, the one configured ERC-721 transfer, the receiver's exact-tuple transition, both post-transfer checks, and final event (`RaffleFactory.sol:L97-L148`; `Raffle.sol:L176-L205`, `L416-L430`). Every local failure branch either occurs before creation state or reverts through the uncaught outer call, so EVM rollback leaves neither the clone/registry state nor token/callback state behind. A successful return requires the configured token's `ownerOf` to report the clone and the clone to report `Active` (`RaffleFactory.sol:L127-L134`). This is not `partial`: no source-visible creation branch bypasses either postcondition. It is not `stronger-than-spec`: parameter screening and reentrancy exclusion are mechanisms supporting the quoted one-prize atomicity property, not a different outcome.

---

**Open questions:**

- The concrete sponsor-selected prize implementation is outside the target. The target checks the contract's self-reported ERC-165 support (`RaffleFactory.sol:L171-L177`), invokes the IERC-721 transfer (`RaffleFactory.sol:L127-L128`), and checks one `ownerOf` result (`RaffleFactory.sol:L129-L131`), while the supplied production interface states that supported prizes are honest, standards-compliant ERC-721s (`IRaffle.sol:L12-L15`). Therefore the source establishes transaction atomicity and the observable ERC-721 postconditions, but it cannot establish truthful behavior by a deliberately nonconforming contract that lies in both its callback and `ownerOf`; no such concrete implementation is present in the 36-file scope.
