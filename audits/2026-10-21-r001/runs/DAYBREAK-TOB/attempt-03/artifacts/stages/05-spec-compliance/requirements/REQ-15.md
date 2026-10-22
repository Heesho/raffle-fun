## REQ-15 — One ERC721 prize is escrowed atomically at creation

> "Exactly one ERC721 prize is escrowed atomically at creation."
> — `DESIGN.md:L2`, sentence 4

---

**Verdict:** implemented · confidence: medium

---

**What this demands of an implementation:** The words "Exactly one ERC721 prize" require each successfully created raffle to bind one prize-contract address and one token ID, and to move that identified token with ERC721 transfer and receiver semantics. The words "escrowed atomically at creation" require the creation call to succeed only after the clone owns that configured token; a failed transfer, rejected callback, or failed custody check must not leave a durable created raffle.

---

**Where enforcement lives:**

The public creation ABI supplies one scalar prize-token address and one scalar token ID, not a collection or quantity (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L20-L25`):

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

Before cloning, the factory requires code at the selected address and requires that address to report support for the `IERC721` interface; a failed call or a false response reverts (`target/packages/contracts/src/RaffleFactory.sol:L154-L177`):

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L171-L177
bool supports721 = false;
try IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
    supports721 = supported;
} catch {
    revert UnsupportedPrizeToken(params.prizeToken);
}
if (!supports721) revert UnsupportedPrizeToken(params.prizeToken);
```

`createRaffle` is the external, `nonReentrant` creation entrypoint (`target/packages/contracts/src/RaffleFactory.sol:L97-L104`). It creates one fixed-target clone, initializes it with the same singular `(prizeToken, prizeTokenId)` pair, and the clone stores that pair before entering `AwaitingPrize` (`target/packages/contracts/src/RaffleFactory.sol:L105-L121`; `target/packages/contracts/src/Raffle.sol:L176-L205`):

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L105-L121
uint256 raffleId = ++raffleCount;
raffle = Clones.clone(raffleImplementation);
// The fresh fixed-target clone can initialize only once; this function is nonReentrant and atomic.
// slither-disable-next-line reentrancy-no-eth
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
```

After registering that clone, the same `createRaffle` invocation makes exactly one prize-side `safeTransferFrom` call, checks `ownerOf` for the configured ID, and requires the callback-driven clone status to be `Active` before it can emit `RaffleCreated` and return (`target/packages/contracts/src/RaffleFactory.sol:L123-L148`):

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L127-L134
IERC721 prize = IERC721(params.prizeToken);
prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
if (prize.ownerOf(params.prizeTokenId) != raffle) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
if (IRaffle(raffle).status() != IRaffle.Status.Active) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
```

The `IERC721` dependency defines `safeTransferFrom` for one `tokenId` and requires ownership or approval plus ERC721 receiver acceptance for a contract recipient (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L42-L73`). The receiver interface requires the recipient to return its selector or the transfer is reverted (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol:L13-L20`). The clone accepts only the configured token contract, configured token ID, configured sponsor as `from`, factory as `operator`, and the one `AwaitingPrize` state; only that exact callback activates the raffle (`target/packages/contracts/src/Raffle.sol:L416-L430`):

```solidity
// target/packages/contracts/src/Raffle.sol:L421-L430
if (
    status != Status.AwaitingPrize || msg.sender != address(prizeToken) || tokenId != prizeTokenId
        || from != sponsor || operator != factory
) {
    revert UnexpectedPrize(msg.sender, tokenId, from, operator);
}

status = Status.Active;
emit PrizeDeposited(msg.sender, tokenId, from);
selector = IERC721Receiver.onERC721Received.selector;
```

Atomicity is enforced by keeping clone creation, initialization, registration, the external prize transfer, both post-transfer checks, and publication in the single uncaught `createRaffle` call (`target/packages/contracts/src/RaffleFactory.sol:L97-L148`). Any revert therefore unwinds the transaction, including the earlier clone and registry writes. The entrypoint's modifier enters the shared factory guard before its body and exits only afterward (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L88-L105`), preventing the prize-token interaction from completing a nested factory creation.

---

**Paths walked:**

- `createRaffle` → `_validateCreateParams` → `_requireContract` / `supportsInterface`: no-code addresses, reverting ERC165 calls, and false ERC721-support responses all revert before cloning (`target/packages/contracts/src/RaffleFactory.sol:L97-L104`, `L154-L185`). ✓
- `createRaffle` → `Clones.clone` → `Raffle.initialize`: the clone library's selected `clone(address)` path deploys one proxy and reverts on failed deployment (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`); initialization is factory-only and one-time, and records the one prize pair in `AwaitingPrize` (`target/packages/contracts/src/Raffle.sol:L176-L205`). ✓
- `createRaffle` → `IERC721.safeTransferFrom` → `Raffle.onERC721Received`: for an ERC721-conforming prize, the single token ID is transferred from the sponsor and a contract recipient must accept it (`target/packages/contracts/src/RaffleFactory.sol:L127-L128`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L42-L73`). The clone rejects every callback tuple other than the configured token, ID, sponsor, and factory while awaiting the prize (`target/packages/contracts/src/Raffle.sol:L421-L430`). ✓
- Transfer returns without the accepted callback: `status` remains `AwaitingPrize`, so the factory's `Active` postcondition reverts (`target/packages/contracts/src/Raffle.sol:L205`, `L428-L430`; `target/packages/contracts/src/RaffleFactory.sol:L132-L134`). ✓
- Transfer/callback succeeds but reported custody is not the clone: the `ownerOf(configuredId) == raffle` postcondition reverts (`target/packages/contracts/src/RaffleFactory.sol:L127-L131`). ✓
- Prize interaction attempts nested `createRaffle`: the factory entrypoint is `nonReentrant`, and the inherited guard rejects a call while its slot is `ENTERED` (`target/packages/contracts/src/RaffleFactory.sol:L97`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L88-L105`). ✓
- Direct clone reinitialization: `initialized` and `msg.sender == factory` are both checked before configuration writes (`target/packages/contracts/src/Raffle.sol:L176-L179`). ✓
- Factory-constructor deployment: `new Raffle` creates only the shared implementation (`target/packages/contracts/src/RaffleFactory.sol:L85-L91`); its constructor locks that implementation as initialized and `Refunding`, so it cannot take the clone escrow path (`target/packages/contracts/src/Raffle.sol:L151-L166`). ✓
- Later prize movements are outbound redemption/return paths, not alternate creation deposits: they call `prizeToken.transferFrom(address(this), ...)` only in NFT-winner redemption or sponsor-prize release (`target/packages/contracts/src/Raffle.sol:L309-L345`, `L394-L406`). ✓

---

**Searched:**

- Full authorized scope → read all 5 production files and all 31 files named by `target/dependency-hashes.json`; recomputed SHA-256 results were `31 matched, 0 mismatched`.
- `\bcreateRaffle\b` across the five production files → 2 hits: the implementation at `RaffleFactory.sol:L97` and interface declaration at `IRaffleFactory.sol:L104`; no wrapper or second caller.
- `^\s*function\s` in `RaffleFactory.sol` → 3 executable function declarations: `createRaffle` at L97, `_validateCreateParams` at L154, and `_requireContract` at L183; only one external creation entrypoint.
- `new Raffle|Clones\.clone` across the five production files → 2 hits: locked implementation deployment at `RaffleFactory.sol:L89` and the sole clone creation at L106.
- `safeTransferFrom` across the five production files → 2 hits: quote-token collection at `Raffle.sol:L224` and the sole prize-side creation transfer at `RaffleFactory.sol:L128`.
- `prize\.safeTransferFrom|prizeToken\.transferFrom` across the five production files → 3 hits: the one inbound creation transfer at `RaffleFactory.sol:L128` and two later outbound paths at `Raffle.sol:L334` and L404.
- `prizeTokens|prizeTokenIds|prizeIds|prizeAmount|prizeCount|numberOfPrizes|prizeQuantity|rewardToken|awardToken|safeBatchTransferFrom|batchTransfer` across the five production files → 0 hits.
- Creation modifier/base path → one executable `nonReentrant` use on `RaffleFactory.sol:L97`; the modifier and its before/after callees were read at `ReentrancyGuard.sol:L69-L72`, `L88-L105`.
- ERC721 callee surface → read `IERC721.safeTransferFrom` and `ownerOf`, `IERC721Receiver.onERC721Received`, the OpenZeppelin reference transfer/callback ordering, and the clone receiver implementation (`IERC721.sol:L32-L91`; `IERC721Receiver.sol:L11-L28`; `ERC721.sol:L114-L136`; `ERC721Utils.sol:L25-L49`; `Raffle.sol:L416-L430`).

---

**How the verdict was reached:** The implementation binds one scalar `(prizeToken, prizeTokenId)` pair, performs one prize-side ERC721 safe transfer in the only creation entrypoint, accepts only the exact receiver tuple, and refuses to return a created raffle unless both callback activation and token-reported ownership hold (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L20-L25`; `target/packages/contracts/src/RaffleFactory.sol:L97-L148`; `target/packages/contracts/src/Raffle.sol:L416-L430`). It is `implemented`, not `partial`, because every locally successful creation path converges on that transfer and both postconditions; the searches found no second entrypoint, batch/multiple-prize representation, or bypass. It is not `stronger-than-spec`: the ERC165 gate, exact callback, ownership check, and reentrancy guard are the mechanisms that make the quoted single-prize atomic escrow claim hold rather than an unrelated additional constraint.

---

**Open questions:**

- The specification also states, "arbitrary prize contracts and ticket recipients are untrusted." (`DESIGN.md:L2`, sentence 16). The concrete sponsor-selected prize implementation is dynamically external and is not among the supplied production or dependency files, so its truthful ERC165 response, transfer ledger, callback behavior, and `ownerOf` response cannot be independently read here. The target enforces code presence, an ERC721 interface self-report, the exact receiver tuple, and a post-transfer ownership report (`target/packages/contracts/src/RaffleFactory.sol:L127-L134`, `L154-L177`; `target/packages/contracts/src/Raffle.sol:L421-L430`). Thus this verdict establishes protocol-side compliance for the requirement's stated ERC721 prize; confirming that a particular deployed prize contract actually conforms to ERC721 requires that contract's code.
