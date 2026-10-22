## `Raffle.onERC721Received` in `target/packages/contracts/src/Raffle.sol` (L416-L431)

**Purpose:** This is the raffle clone's ERC-721 safe-transfer acceptance boundary and its only prize-deposit activation step. `Raffle` advertises `IERC721Receiver` in its inheritance list (`Raffle.sol:L28`), and this function accepts a callback only when its lifecycle state and all four callback identities match the clone's configured prize deposit (`Raffle.sol:L416-L426`). On acceptance it changes the lifecycle from `AwaitingPrize` to `Active`, emits `PrizeDeposited`, and returns the ERC-721 receiver selector (`Raffle.sol:L428-L430`). The factory relies on that transition when it deposits the sponsor's prize and then requires the clone to report `Active` before creation completes (`RaffleFactory.sol:L127-L147`).

---

**Inputs & Assumptions:**

- `operator` (`address`): callback-supplied transfer operator. Trust: **untrusted at this entrypoint**. A normal return establishes only that the supplied value equals the immutable canonical `factory`; the comparison is at `Raffle.sol:L421-L425`.
- `from` (`address`): callback-supplied prior owner. Trust: **untrusted at this entrypoint**. A normal return establishes only that the supplied value equals the stored `sponsor` (`Raffle.sol:L421-L425`).
- `tokenId` (`uint256`): callback-supplied NFT identifier. Trust: **untrusted at this entrypoint**. It must equal `prizeTokenId` (`Raffle.sol:L421-L425`).
- The final `bytes calldata` argument is unnamed and never read, so arbitrary callback data does not affect acceptance (`Raffle.sol:L416-L430`). On the OpenZeppelin three-argument `safeTransferFrom` path used by the factory, the overload supplies empty bytes (`ERC721.sol:L127-L135`).
- Implicit `msg.sender`: the contract making the callback. Trust: **semi-trusted by configuration, externally controlled in execution**. It must equal the stored `prizeToken` address (`Raffle.sol:L421-L425`). The factory permits a sponsor-selected contract after checking code presence and a successful `supportsInterface(IERC721)` response (`RaffleFactory.sol:L154-L177`); the protocol interface separately states the assumption that supported prizes are honest, standards-compliant ERC-721s (`IRaffle.sol:L12-L15`).
- Implicit persistent state: `status`, `prizeToken`, `prizeTokenId`, and `sponsor` are clone storage (`Raffle.sol:L60-L73`, `L123-L124`); `factory` is an implementation immutable (`Raffle.sol:L54-L55`, `L155-L162`). The factory supplies the clone configuration and `initialize` stores it before setting `status = AwaitingPrize` (`RaffleFactory.sol:L105-L121`; `Raffle.sol:L176-L205`).
- Precondition for the canonical factory path: the implementation's immutable `factory` is the deploying `RaffleFactory`. The factory deploys the implementation at `RaffleFactory.sol:L89-L91`, and the implementation constructor records its `msg.sender` at `Raffle.sol:L155-L162`. The clone delegates calls to that fixed implementation (`Clones.sol:L9-L15`, `L32-L62`), so the immutable is shared while `status` and the other mutable fields are read from clone storage.
- Precondition for semantic escrow, beyond equality of callback fields: the configured prize contract must perform a real ERC-721 transfer, invoke the receiver with truthful `operator` and `from` values, honor the returned selector, and report ownership consistently. The receiver itself establishes none of those token-side facts; it only compares supplied values and changes local state (`Raffle.sol:L421-L430`). The OpenZeppelin reference path establishes transfer-before-callback ordering (`ERC721.sol:L114-L135`) and enforces the selector (`ERC721Utils.sol:L25-L48`), while the concrete sponsor-selected token implementation is not present in `target/`. The factory's post-call `ownerOf` check depends on that same external token's report (`RaffleFactory.sol:L127-L134`).

---

**Outputs & Effects:**

- Rejection path: if any of the five conditions differs—lifecycle state, callback caller, token ID, prior owner, or operator—the function reverts with `UnexpectedPrize(msg.sender, tokenId, from, operator)` before any local write (`Raffle.sol:L421-L426`).
- Success path storage write: `status` changes from the gate-established `AwaitingPrize` value to `Active` (`Raffle.sol:L421-L428`). The enum describes those states as waiting for factory escrow and prize-escrowed/available for entry sales, respectively (`IRaffle.sol:L20-L26`).
- Success path event: `PrizeDeposited(msg.sender, tokenId, from)` records the checked token address, configured token ID, and sponsor after the state write (`Raffle.sol:L428-L429`; `IRaffle.sol:L58-L62`).
- Success path return: returns exactly `IERC721Receiver.onERC721Received.selector` (`Raffle.sol:L430`), which is the acceptance value required by the receiver interface (`IERC721Receiver.sol:L13-L27`).
- No NFT movement and no outbound external call occur in this function; token movement belongs to the calling token contract, while this body performs comparisons, one storage write, one event, and one return (`Raffle.sol:L421-L430`).
- During the canonical nested call, `Active` is written before the token's `safeTransferFrom` has returned to the factory; the factory's ownership and status checks occur afterward (`Raffle.sol:L428-L430`; `RaffleFactory.sol:L127-L134`). A revert from the receiver, the token's receiver-selector handling, or either factory postcondition prevents the surrounding `createRaffle` call from reaching `RaffleCreated` (`ERC721Utils.sol:L32-L46`; `RaffleFactory.sol:L129-L147`).

---

**Block-by-Block:**

```solidity
// Raffle.sol:L416-L420
function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata)
    external
    override
    returns (bytes4 selector)
{
```

- **What:** Exposes the standard receiver callback, names the three identity-bearing arguments, deliberately ignores `data`, and declares a `bytes4` acceptance result (`Raffle.sol:L416-L420`).
- **Why here:** This external boundary is what a contract recipient must implement for an ERC-721 safe transfer; the interface requires the callback and exact selector response (`IERC721Receiver.sol:L11-L27`).
- **Assumes:** The invoking token follows ERC-721 callback semantics. The system documents that trust assumption for supported prizes (`IRaffle.sol:L12-L15`), but the concrete token's implementation is external to `target/`.
- **Establishes:** Nothing about custody on entry. It exposes values that the next block checks (`Raffle.sol:L416-L425`).
- **Depended on by:** The token-side safe-transfer acceptance check and the factory's prize-deposit sequence (`ERC721Utils.sol:L25-L48`; `RaffleFactory.sol:L127-L134`).

```solidity
// Raffle.sol:L421-L426
if (
    status != Status.AwaitingPrize || msg.sender != address(prizeToken) || tokenId != prizeTokenId
        || from != sponsor || operator != factory
) {
    revert UnexpectedPrize(msg.sender, tokenId, from, operator);
}
```

- **What:** Rejects unless all five expected values match: `AwaitingPrize`, configured prize contract, configured token ID, configured sponsor, and canonical factory operator (`Raffle.sol:L421-L426`).
- **Why here:** The complete gate precedes the lifecycle write, event, and acceptance return, so no mismatching callback can reach those effects (`Raffle.sol:L421-L430`).
- **Assumes:** For `operator` and `from` to carry their standard meanings, the configured prize contract must populate them faithfully. A token contract controls the calldata it sends; equality checks establish the values supplied, not their historical truth (`Raffle.sol:L416-L425`). The OpenZeppelin reference implementation passes its `_msgSender()` and `from` through the acceptance helper (`ERC721.sol:L128-L135`), and the default `_msgSender()` is `msg.sender` (`Context.sol:L16-L19`).
- **Establishes:** On fallthrough, `status == AwaitingPrize`, `msg.sender == address(prizeToken)`, `tokenId == prizeTokenId`, `from == sponsor`, and `operator == factory` (`Raffle.sol:L421-L426`).
- **Depended on by:** The `Active` state, deposit event, and selector return at `Raffle.sol:L428-L430`, and indirectly by the factory's status postcondition at `RaffleFactory.sol:L132-L134`.

```solidity
// Raffle.sol:L428-L430
status = Status.Active;
emit PrizeDeposited(msg.sender, tokenId, from);
selector = IERC721Receiver.onERC721Received.selector;
```

- **What:** Activates the raffle, records the accepted callback, and returns the required magic value (`Raffle.sol:L428-L430`).
- **Why here:** The gate first establishes exact callback-value matches. The status write then occurs before the event and return, so any code observing the clone after the callback returns sees `Active` if the surrounding transaction continues (`Raffle.sol:L421-L430`).
- **Assumes:** Returning the selector causes the token to accept rather than roll back the transfer. This is enforced by the OpenZeppelin acceptance helper on its success path and rejected otherwise (`ERC721Utils.sol:L32-L46`); behavior of the concrete configured token remains an external assumption.
- **Establishes:** On normal return, the clone is `Active`, `PrizeDeposited` has been emitted in the current call frame, and the return value is the standard selector (`Raffle.sol:L428-L430`). A second successful callback cannot follow without some path restoring `AwaitingPrize`: this function immediately changes it to `Active` and checks `AwaitingPrize` on every entry (`Raffle.sol:L421-L428`); the only assignment of `AwaitingPrize` in `Raffle.sol` is initialization (`Raffle.sol:L205`).
- **Depended on by:** The standard token's selector comparison (`ERC721Utils.sol:L33-L37`) and the factory's `status() == Active` postcondition (`RaffleFactory.sol:L132-L134`).

---

**Cross-Function Dependencies:**

- **Predecessor `RaffleFactory.createRaffle` (source available):** Any external sponsor may enter at `RaffleFactory.sol:L97`. After validation and time bounds, it allocates an ID, deploys a fixed-target clone, and calls `initialize` with `sponsor = msg.sender`, the sponsor-selected `prizeToken` and `prizeTokenId`, and factory-held protocol configuration (`RaffleFactory.sol:L98-L121`). `initialize` writes those exact fields and `AwaitingPrize` (`Raffle.sol:L176-L205`). The factory registers the clone before contacting the prize contract (`RaffleFactory.sol:L123-L128`), so the registry already reports it during the nested callback.
- **Upstream external call `IERC721.safeTransferFrom` (external black box):** The factory calls `params.prizeToken.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` (`RaffleFactory.sol:L127-L128`). Therefore the intended transfer tuple is sponsor to clone for the configured ID, with the factory as the token call's immediate caller. The concrete sponsor-selected prize implementation is unavailable; failure, a callback with other values, no callback, additional nested calls, or inconsistent return/reporting behavior are not excluded by source in `target/`. The factory call is wrapped by `nonReentrant` (`RaffleFactory.sol:L97`), whose modifier spans the body (`ReentrancyGuard.sol:L69-L72`, `L94-L105`).
- **Reference standard path `OpenZeppelin ERC721.safeTransferFrom` (source available, not necessarily the configured token):** The three-argument overload supplies `""`; the four-argument overload first calls `transferFrom` and then `checkOnERC721Received(_msgSender(), from, to, tokenId, data)` (`ERC721.sol:L127-L135`). `transferFrom` routes ownership mutation through `_update` and verifies the previous owner (`ERC721.sol:L114-L124`), while the acceptance helper calls the clone with `(operator, from, tokenId, data)`, requires the exact selector, and bubbles a receiver revert (`ERC721Utils.sol:L25-L48`). Under this path, the callback observes `operator = factory`, `from = createRaffle`'s `msg.sender`, `tokenId = params.prizeTokenId`, empty data, and `msg.sender = params.prizeToken` (`RaffleFactory.sol:L97-L128`; `Context.sol:L16-L19`; `ERC721.sol:L128-L135`).
- **Successor checks in `RaffleFactory.createRaffle` (one external black box and one source-backed read):** After `safeTransferFrom` returns, the factory requires the prize contract's `ownerOf(tokenId)` response to equal the clone and the clone's `status()` to equal `Active` (`RaffleFactory.sol:L129-L134`). Only then does it emit `RaffleCreated` (`RaffleFactory.sol:L136-L147`). The ownership check is still a report from the external prize contract; the status check observes the receiver's local write.
- **Callers:** Any address can invoke the public callback ABI (`Raffle.sol:L416-L420`), but only a call whose `msg.sender` is the configured prize-token address and whose other values satisfy the full gate returns normally (`Raffle.sol:L421-L430`). The intended caller is that prize token during the factory's safe transfer (`RaffleFactory.sol:L127-L128`).
- **Callees:** No internal or external function is invoked by the receiver body; it reads state, compares inputs, writes `status`, emits an event, and assigns a selector (`Raffle.sol:L421-L430`).
- **Shared state:** `initialize` is the predecessor that sets `sponsor`, `prizeToken`, `prizeTokenId`, and `AwaitingPrize` (`Raffle.sol:L197-L205`). `requestDraw` later requires `Active` and moves to `Drawing` (`Raffle.sol:L240-L253`); `enableRefunds` can move `Active` or `Drawing` to `Refunding` (`Raffle.sol:L276-L300`); `fulfillRandomWords` can move `Drawing` to `NftWon` or `CashWon` (`Raffle.sol:L509-L523`). No later path shown restores `AwaitingPrize`.
- **Invariant coupling:** For a successfully committed canonical `createRaffle`, the registry entries, the receiver's `Active` transition, the prize contract's reported owner, and `RaffleCreated` are one nested transaction sequence (`RaffleFactory.sol:L123-L147`). Inside the receiver alone, `Active` proves that the five checked values were presented while status was `AwaitingPrize` (`Raffle.sol:L421-L430`); actual NFT custody depends on the configured token's transfer and ownership-reporting semantics (`RaffleFactory.sol:L127-L134`; `IRaffle.sol:L12-L15`).

---

**Open Questions:**

- unclear; need to inspect each concrete configured prize-token implementation to establish that `safeTransferFrom` updates ownership before the callback, supplies truthful `operator` and `from` values, enforces the returned selector, and makes `ownerOf` reflect persistent custody. The factory admits tokens through code presence and claimed ERC-721 interface support (`RaffleFactory.sol:L154-L177`), while `target/` contains no sponsor-selected token implementation.
