## REQ-14 — Exactly one prize escrowed at creation

> "Exactly one ERC721 prize is escrowed atomically at creation."
> — `DESIGN.md:L2, sentence 4`

**Verdict:** partial · confidence: high

---

**What this demands of an implementation:** A `createRaffle` call may complete successfully only if the new raffle has one configured `(prizeToken, prizeTokenId)` pair and that exact NFT is in the raffle's custody before creation is published. A zero-prize result, more than one protocol-designated prize, or a successful creation whose escrow step was skipped or merely asserted by an untrusted callee violates the quoted requirement. Deployment, initialization, registration, transfer, activation, verification, and publication must form one all-or-nothing creation operation.

---

**Where enforcement lives:**

The public creation type carries one scalar token address and one scalar token ID, not an array or quantity:

```solidity
// target/packages/contracts/src/interfaces/IRaffleFactory.sol:L20-L25
struct CreateRaffleParams {
    address sponsorRecipient;
    address prizeToken;
    uint256 prizeTokenId;
    uint128 reserveEntries;
    uint64 endTime;
}
```

The factory has one creation entrypoint. On its only non-reverting path it deploys one clone, initializes it with the one pair, registers it, makes one prize-token transfer call, checks the token's `ownerOf` response and the clone's status, and only then emits `RaffleCreated` (`target/packages/contracts/src/RaffleFactory.sol:L97-L148`):

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L97-L106
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

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L109-L134
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

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L136-L147
emit RaffleCreated(
    raffleId,
    raffle,
    msg.sender,
    params.sponsorRecipient,
    params.prizeToken,
    params.prizeTokenId,
    quoteToken,
    protocolTreasury,
    params.reserveEntries,
    params.endTime
);
```

Clone initialization is factory-only and one-time; every successful branch writes exactly one token address and ID and finishes in `AwaitingPrize` (`target/packages/contracts/src/Raffle.sol:L176-L205`). Its address-screening callees either return a Boolean or cause initialization to revert; none supplies an alternate success branch that skips those assignments (`target/packages/contracts/src/Raffle.sol:L181-L205`, `L593-L605`):

```solidity
// target/packages/contracts/src/Raffle.sol:L176-L180
function initialize(RaffleInitParams calldata params) external override {
    if (initialized) revert AlreadyInitialized();
    if (msg.sender != factory) revert OnlyFactory();
    initialized = true;
```

```solidity
// target/packages/contracts/src/Raffle.sol:L197-L205
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

The receiver accepts only a callback naming the configured token ID, from the configured prize-token address, identifying the sponsor as `from` and the factory as `operator`. A successful callback changes `AwaitingPrize` to `Active`, so a second callback cannot pass the same gate (`target/packages/contracts/src/Raffle.sol:L416-L430`):

```solidity
// target/packages/contracts/src/Raffle.sol:L416-L430
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

For the included OpenZeppelin reference implementation, `safeTransferFrom` calls `transferFrom` and then the receiver hook; `transferFrom` updates ownership and verifies the prior owner, while a wrong receiver result or receiver revert aborts the call (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135`, `L216-L245`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`). That is the fully enforced path for a token with those semantics.

The gap is that the sponsor-selected prize is not bound to that implementation. Factory validation requires deployed code and accepts the token's own ERC-165 answer; it does not establish the behavior of `safeTransferFrom` or `ownerOf` (`target/packages/contracts/src/RaffleFactory.sol:L154-L177`, `L181-L185`):

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L154-L177
function _validateCreateParams(CreateRaffleParams calldata params) private view {
    _requireContract(params.prizeToken);
    if (params.sponsorRecipient == address(0)) revert ZeroAddress();
    if (
        params.prizeToken == address(this) || params.prizeToken == quoteToken || params.prizeToken == vrfWrapper
            || params.prizeToken == raffleImplementation || isRaffle[params.prizeToken]
    ) {
        revert UnsafeProtocolDestination(params.prizeToken);
    }
    if (
        params.sponsorRecipient == address(this) || params.sponsorRecipient == quoteToken
            || params.sponsorRecipient == vrfWrapper || params.sponsorRecipient == params.prizeToken
            || params.sponsorRecipient == raffleImplementation || isRaffle[params.sponsorRecipient]
    ) {
        revert UnsafeProtocolDestination(params.sponsorRecipient);
    }

    bool supports721 = false;
    try IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
        supports721 = supported;
    } catch {
        revert UnsupportedPrizeToken(params.prizeToken);
    }
    if (!supports721) revert UnsupportedPrizeToken(params.prizeToken);
```

`IERC721` supplies declarations and behavioral prose but no executable implementation for the sponsor-selected address (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L11-L55`). Consequently, an accepted-as-ERC721 contract can return `true` to the check at `RaffleFactory.sol:L172-L177`, invoke the public receiver with the tuple accepted at `Raffle.sol:L421-L430`, and return the clone address from the `ownerOf` call checked at `RaffleFactory.sol:L129-L134`, without the target containing any independent custody fact that distinguishes those reports from a real transfer. The local `Active` transition proves that the callback tuple was accepted; it does not prove that the external token changed an ownership ledger (`target/packages/contracts/src/Raffle.sol:L421-L430`).

Creation is guarded against a nested `createRaffle` call because the entrypoint has `nonReentrant` (`target/packages/contracts/src/RaffleFactory.sol:L97`), whose modifier sets the guard before the body and restores it afterward (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L94-L105`). This closes the reentrant multiple-creation branch but does not authenticate the prize token's ownership report.

---

**Paths walked:**

- `createRaffle` → `_validateCreateParams` → `_requireContract`: a code-less token, unsafe protocol address, reverting/false ERC-165 response, zero reserve, invalid end time, or excessive duration reverts before clone publication; none is a successful zero-prize creation (`target/packages/contracts/src/RaffleFactory.sol:L97-L104`, `L154-L185`). ✓
- `createRaffle` → `Clones.clone`: the used clone overload creates one fixed-target proxy and reverts if creation returns the zero address (`target/packages/contracts/src/RaffleFactory.sol:L105-L106`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`). ✓
- `createRaffle` → `Raffle.initialize`: only the immutable factory can initialize a fresh clone, and every returning path records the sole scalar prize pair before setting `AwaitingPrize`; repeated or non-factory initialization reverts (`target/packages/contracts/src/Raffle.sol:L176-L205`). ✓
- `createRaffle` → a standards-compliant `safeTransferFrom` → `onERC721Received`: the nominal path moves the selected ID, accepts only the configured callback tuple, changes status once, then passes both factory postconditions before `RaffleCreated` (`target/packages/contracts/src/RaffleFactory.sol:L127-L147`; `target/packages/contracts/src/Raffle.sol:L416-L430`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135`). ✓
- Prize transfer reverts, receiver tuple is wrong, receiver returns incorrectly, `ownerOf` reports a different owner, or the clone is not `Active`: the uncaught external-call failure or explicit postcondition revert aborts `createRaffle`; the event is located after both checks (`target/packages/contracts/src/RaffleFactory.sol:L127-L147`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L32-L47`). ✓
- Prize-token callback → second prize callback: the first accepted callback writes `Active`, while every accepted callback requires `AwaitingPrize`; the second attempt reverts (`target/packages/contracts/src/Raffle.sol:L421-L430`). ✓
- Prize-token callback → reentrant `createRaffle`: the factory guard is already `ENTERED`, so the inherited guard reverts the nested protected call (`target/packages/contracts/src/RaffleFactory.sol:L97`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L88-L105`). ✓
- Accepted-as-ERC721 contract → self-reported callback and ownership: `_validateCreateParams` accepts code plus a `true` interface response, the receiver authenticates only caller/arguments/status, and the final custody check trusts that same external contract's `ownerOf` return (`target/packages/contracts/src/RaffleFactory.sol:L154-L185`, `L127-L134`; `target/packages/contracts/src/Raffle.sol:L421-L430`). This path can return from `createRaffle` without enforceable ERC-721 custody in the supplied target. ✗ — the zero-prize gap.

---

**Searched:**

- Complete permitted scope → all five production files and all 31 files named by `target/dependency-hashes.json` were read in full; all 31 dependency SHA-256 values matched the manifest.
- `createRaffle|CreateRaffle` → 4 production hits and 0 dependency hits: the parameter struct and interface declaration at `IRaffleFactory.sol:L20-L25,L104`, the implementation at `RaffleFactory.sol:L97`, and its private validator at `RaffleFactory.sol:L154`.
- `function createRaffle|\.createRaffle\(` → 2 production hits: the interface declaration and implementation; no in-scope wrapper or caller creates a raffle through another path (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L104`; `target/packages/contracts/src/RaffleFactory.sol:L97`).
- `initialize\(` → 3 production hits and 0 dependency hits: the interface declaration, the sole factory call, and the implementation (`target/packages/contracts/src/interfaces/IRaffle.sol:L308`; `target/packages/contracts/src/RaffleFactory.sol:L110`; `target/packages/contracts/src/Raffle.sol:L176`).
- `\bprizeToken\s*=(?!=)` and `\bprizeTokenId\s*=(?!=)` → one assignment each, both in clone initialization (`target/packages/contracts/src/Raffle.sol:L200-L201`).
- `prizeToken|prizeTokenId` → 67 production hits and 0 dependency hits; the only creation-time transfer and postcondition are at `RaffleFactory.sol:L127-L134`, while later prize uses are winner/sponsor release paths at `Raffle.sol:L329-L337,L395-L406`.
- `safeTransferFrom` → 2 production hits and 15 dependency hits. The production hits are the one prize deposit at `RaffleFactory.sol:L128` and an unrelated quote-token purchase at `Raffle.sol:L224`; no second prize deposit call exists.
- `onERC721Received` → 2 production hits and 13 dependency hits. Production contains one receiver implementation at `Raffle.sol:L416` and its returned selector at `L430`; dependency hits are interface, comments, and the generic OpenZeppelin callback machinery.
- `ownerOf` → 5 production hits and 9 dependency hits. The creation-time prize check is only `RaffleFactory.sol:L129`; the other production hits concern ticket ownership or later prize delivery (`Raffle.sol:L320,L335,L359,L405`).
- `status = Status.AwaitingPrize|status = Status.Active` → exactly 2 production hits: initialization at `Raffle.sol:L205` and accepted prize callback at `Raffle.sol:L428`.
- `nonReentrant|ReentrancyGuard` → 15 production hits and 28 dependency hits; `createRaffle` is protected at `RaffleFactory.sol:L97`, and the inherited modifier implementation was read at `ReentrancyGuard.sol:L69-L105`.
- `escrow|Escrow|deposit|Deposit|fund|Fund` → 88 production hits. The relevant creation hits resolve to the same transfer, receiver, postconditions, error, and events cited above; no alternate prize-funding entrypoint was found.
- Concrete prize implementation search (`contract ... ERC721`, `abstract contract ERC721`, `interface IERC721`) → the scope contains the raffle's inherited ticket implementation, the generic abstract OpenZeppelin `ERC721`, and ERC-721 interfaces, but no implementation fixed as the sponsor-selected prize (`target/packages/contracts/src/Raffle.sol:L28`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L19`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L11`).

---

**How the verdict was reached:** The local path is materially implemented: there is one scalar prize pair, one deposit call, a one-shot exact-tuple receiver gate, two postconditions, reentrancy protection, and publication only after those checks (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L20-L25`; `target/packages/contracts/src/RaffleFactory.sol:L97-L147`; `target/packages/contracts/src/Raffle.sol:L176-L205,L416-L430`). That rules out `absent` and `contradicted`. It is not fully `implemented`, however, because successful creation ultimately relies on three claims made by the sponsor-selected external address—ERC-165 support, transfer/callback behavior, and `ownerOf`—and the frozen target contains no concrete implementation or independent ownership observation behind them (`target/packages/contracts/src/RaffleFactory.sol:L154-L185,L127-L134`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L11-L55`). A conforming token path satisfies the requirement, while an accepted self-reporting path can pass every local branch without enforceable custody. That path-specific split is `partial`, rather than `implemented` or `undecidable`.

---

**Open questions:**

- The concrete sponsor-selected prize-token bytecode and any upgrade controls are outside the frozen target. Inspecting a deployed prize determines whether the self-reporting path is realized for that raffle; it does not add universal enforcement to `createRaffle`.
