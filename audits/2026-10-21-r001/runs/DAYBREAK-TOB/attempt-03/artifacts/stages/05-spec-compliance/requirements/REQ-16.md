## REQ-16 — One ERC-721 prize escrowed before creation returns

> "Exactly one ERC721 prize is escrowed atomically at creation."
> — DESIGN.md:L2, sentence 4

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** “Exactly one ERC721 prize is escrowed atomically at creation.” (`DESIGN.md:L2, sentence 4`) requires the successful raffle-creation path to bind one specified `(prizeToken, prizeTokenId)` pair to the new raffle and to finish only after that token ID is in the raffle's custody. The supplied checkable formulation is: “The specified prize enters escrow before the raffle-creation operation returns successfully.” A failed transfer, rejected receipt, failed custody report, or failed activation must therefore prevent a successful return and roll back the creation transaction.

The creation ABI represents the prize with one address and one scalar token ID, not an array or batch (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L14-L25`).

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L97-L107
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

- `createRaffle` is the sole production implementation of raffle creation and is guarded by `nonReentrant` (`target/packages/contracts/src/RaffleFactory.sol:L97`). The modifier sets the guard before the body and clears it only after the body, so a prize-token callback cannot start a nested creation (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L88-L105`).
- The factory passes the same single `params.prizeToken` and `params.prizeTokenId` into initialization and into the one prize-transfer call (`target/packages/contracts/src/RaffleFactory.sol:L109-L120`, `L127-L128`).
- After that external call returns, the factory asks the configured token for the exact token ID's owner and rejects any answer other than the new raffle; it separately requires the clone to have reached `Active` (`target/packages/contracts/src/RaffleFactory.sol:L127-L134`). `RaffleCreated` is emitted only after both postconditions (`target/packages/contracts/src/RaffleFactory.sol:L136-L147`).

```solidity
// target/packages/contracts/src/Raffle.sol:L176-L205
function initialize(RaffleInitParams calldata params) external override {
    if (initialized) revert AlreadyInitialized();
    if (msg.sender != factory) revert OnlyFactory();
    initialized = true;

    if (
        params.sponsor == address(0) || params.sponsorRecipient == address(0)
            || params.protocolTreasury == address(0) || params.prizeToken == address(0)
    ) {
        revert ZeroAddress();
    }
    if (_isProtocolDestination(params.sponsor, params.prizeToken)) {
        revert UnsafeProtocolDestination(params.sponsor);
    }
    if (_isProtocolDestination(params.protocolTreasury, params.prizeToken)) {
        revert UnsafeProtocolDestination(params.protocolTreasury);
    }
    if (_isProtocolDestination(params.sponsorRecipient, params.prizeToken)) {
        revert UnsafeProtocolDestination(params.sponsorRecipient);
    }

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

Initialization is factory-only and one-time, stores the exact prize pair, and leaves the clone in `AwaitingPrize` (`target/packages/contracts/src/Raffle.sol:L176-L205`).

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

The receiver accepts only the initialized token contract and token ID, from the initialized sponsor, with the factory as operator, while the clone is waiting for its prize; that one accepted callback is the only production write of `Status.Active` (`target/packages/contracts/src/Raffle.sol:L416-L430`). Because it changes the status, another receiver callback on the same creation path fails the `AwaitingPrize` condition (`target/packages/contracts/src/Raffle.sol:L421-L425`, `L428`).

For the supplied OpenZeppelin ERC-721 reference implementation, `safeTransferFrom` first performs `transferFrom` and then invokes the receiver check (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L128-L135`); the utility rejects a wrong selector and bubbles receiver reverts (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L47`). The interface itself requires the token to exist, be owned by `from`, be authorized for the caller, and invoke the receiver for a contract recipient (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L42-L53`). The factory's later `ownerOf` comparison remains the final custody postcondition even for a conforming ERC-721 implementation with different internal ordering (`target/packages/contracts/src/RaffleFactory.sol:L127-L134`).

---

**Paths walked:**

- `createRaffle` → `_validateCreateParams`: a code-less prize address, unsafe protocol destination, failed or false ERC-165 response, zero reserve, invalid end time, or overlong sale duration reverts before a successful creation (`target/packages/contracts/src/RaffleFactory.sol:L98-L104`, `L154-L184`). ✓ — no failing validation branch returns a raffle.
- `createRaffle` → `Clones.clone` → `Raffle.initialize`: clone deployment either returns a nonzero instance or reverts (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`); initialization only accepts the immutable factory once and records the same prize pair in `AwaitingPrize` (`target/packages/contracts/src/Raffle.sol:L176-L205`). ✓
- `createRaffle` → `IERC721.safeTransferFrom` → `Raffle.onERC721Received`: on a conforming ERC-721 success path, the single specified token is transferred and the receiver accepts only the exact configured deposit tuple (`target/packages/contracts/src/RaffleFactory.sol:L127-L128`; `target/packages/contracts/src/Raffle.sol:L416-L430`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L128-L135`). ✓
- Transfer revert or rejected callback: there is no `try/catch` around `safeTransferFrom`, so a token revert or `UnexpectedPrize` revert exits `createRaffle` without a successful return (`target/packages/contracts/src/RaffleFactory.sol:L127-L134`; `target/packages/contracts/src/Raffle.sol:L421-L425`). ✓
- Transfer returns without the specified token reporting the raffle as owner: `ownerOf(params.prizeTokenId) != raffle` reverts (`target/packages/contracts/src/RaffleFactory.sol:L127-L131`). ✓
- Transfer returns without the exact callback having activated the clone: `status() != Active` reverts (`target/packages/contracts/src/RaffleFactory.sol:L132-L134`); `onERC721Received` is the only production assignment to `Active` (`target/packages/contracts/src/Raffle.sol:L416-L430`). ✓
- Both postconditions hold: only then does execution reach `RaffleCreated` and the named return from `createRaffle` (`target/packages/contracts/src/RaffleFactory.sol:L129-L148`). ✓
- Prize-token reentry → `createRaffle`: the outer call already holds the factory's `nonReentrant` guard, and the guard rejects a nested protected call (`target/packages/contracts/src/RaffleFactory.sol:L97`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L88-L105`). ✓

All clone deployment, registry writes, receipt-state writes, and the external token transfer occur inside the same uncaught `createRaffle` call (`target/packages/contracts/src/RaffleFactory.sol:L97-L148`). Consequently, a revert on any later transfer or postcondition branch unwinds the creation transaction rather than leaving a successfully created, unescrowed raffle.

---

**Searched:**

- Coverage → all five production files under `target/packages/contracts/src` and all 31 files named by `target/dependency-hashes.json:L2-L32` were read in full; every dependency's SHA-256 matched its manifest value.
- `createRaffle\s*\(` in the five production files → 2 hits: the implementation at `target/packages/contracts/src/RaffleFactory.sol:L97` and interface declaration at `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L104`; `\.createRaffle\s*\(` → 0 production hits, so there is no in-scope wrapper or alternate caller path.
- `prize\s*\.\s*safeTransferFrom` → 1 production hit, `target/packages/contracts/src/RaffleFactory.sol:L128`.
- `safeBatchTransferFrom|batchTransfer|batch.*prize|prize.*\[\]` → 0 production hits. The dependency sweep found one `safeBatchTransferFrom` occurrence, only an ERC-1155 error comment in `target/packages/contracts/node_modules/@openzeppelin/contracts/interfaces/draft-IERC6093.sol:L156`; no ERC-721 batch-transfer implementation or call exists in the declared closure.
- `\.ownerOf\s*\(` → 3 production hits: creation custody verification at `target/packages/contracts/src/RaffleFactory.sol:L129` and later prize-delivery checks at `target/packages/contracts/src/Raffle.sol:L335`, `L405`.
- `onERC721Received|IERC721Receiver` → 4 production hits: import and inheritance at `target/packages/contracts/src/Raffle.sol:L11`, `L28`, the receiver implementation at `L416`, and returned selector at `L430`. The dependency closure's executable receiver dispatch is `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L33-L36`.
- `status\s*=\s*Status\.AwaitingPrize` → 1 production hit at `target/packages/contracts/src/Raffle.sol:L205`; `status\s*=\s*Status\.Active` → 1 production hit at `target/packages/contracts/src/Raffle.sol:L428`.
- `PrizeEscrowVerificationFailed` → 3 production hits: declaration at `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L97` and the ownership/status reverts at `target/packages/contracts/src/RaffleFactory.sol:L130`, `L133`.
- `supportsInterface|type\(IERC721\)\.interfaceId` → 1 production hit, the prize-admission check at `target/packages/contracts/src/RaffleFactory.sol:L172`.
- `nonReentrant|modifier\s+` → `createRaffle` has `nonReentrant` at `target/packages/contracts/src/RaffleFactory.sol:L97`; the modifier implementation was followed through `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L105`.
- Vocabulary sweep `ownerOf|balanceOf|custod|escrow`, plus `deposit|fund|register|activate`, led to the transfer/postcondition block (`target/packages/contracts/src/RaffleFactory.sol:L123-L147`), the exact receiver gate (`target/packages/contracts/src/Raffle.sol:L409-L430`), and no alternate production creation route.

---

**How the verdict was reached:** This is `implemented`, not `partial`, because every target-visible branch that returns successfully from the sole creation implementation has passed one transfer of the one configured token ID, the exact receiver gate, the post-transfer `ownerOf == raffle` check, and the `status == Active` check before publication or return (`target/packages/contracts/src/RaffleFactory.sol:L97-L148`; `target/packages/contracts/src/Raffle.sol:L416-L430`). The branches where validation, clone deployment, initialization, safe transfer, receiver acceptance, ownership reporting, or activation fails all revert and therefore do not produce a successful raffle creation (`target/packages/contracts/src/RaffleFactory.sol:L98-L134`; `target/packages/contracts/src/Raffle.sol:L176-L205`, `L421-L425`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L61`). The single scalar prize tuple and single prize-transfer call satisfy “Exactly one ERC721 prize is escrowed atomically at creation.” (`DESIGN.md:L2, sentence 4`); no batch or alternate creator path was found.

---

**Open questions:**

- No source-level open question remains for a prize contract that satisfies the stated ERC-721 premise. The concrete sponsor-selected prize implementation is not part of the target: the factory admits it through an ERC-165 self-report (`target/packages/contracts/src/RaffleFactory.sol:L171-L177`) and observes custody through that same external contract's `ownerOf` report (`target/packages/contracts/src/RaffleFactory.sol:L127-L131`). A deployment using code that falsely claims ERC-721 support or lies in `ownerOf` cannot be validated from this source closure; the ERC-721 interface defines `ownerOf` as the ownership query (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L9-L11`, `L32-L39`). This external conformance boundary does not create an uncovered successful path for the requirement's stated ERC-721 subject.
