## `onERC721Received` in packages/contracts/src/Raffle.sol (L416-L431)

**Purpose:** Acts as the ERC-721 safe-transfer receiver hook on a `Raffle` clone, accepting only the single configured prize NFT transferred from `sponsor` by `factory` while the raffle is in `Status.AwaitingPrize`, and transitioning the raffle lifecycle state to `Status.Active`. Without it, `IERC721.safeTransferFrom` during `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L128`) would revert on the ERC-721 receiver check (`packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L33-L47`), or the clone would accept unsolicited/wrong NFTs via safe transfers or activate before the factory initiates prize escrow.

---

**Inputs & Assumptions:**
- `operator` (`address`): ERC-721 transfer operator reported by the calling token contract. Trust: **untrusted** (supplied in calldata by `msg.sender`).
- `from` (`address`): Previous token owner reported by the calling token contract. Trust: **untrusted** (supplied in calldata by `msg.sender`).
- `tokenId` (`uint256`): Transferred token identifier reported by the calling token contract. Trust: **untrusted** (supplied in calldata by `msg.sender`).
- Unnamed 4th parameter (`bytes calldata`, `L416`): Additional ERC-721 safe-transfer data payload. Trust: **untrusted** (ignored).
- Implicit:
  - `msg.sender` (`address`): External caller invoking the callback; checked against `address(prizeToken)` (`L422`), which is an **untrusted** sponsor-selected contract stored during `initialize` (`L200`).
  - `status` (`IRaffle.Status`, storage at `L124`): Current lifecycle status; must equal `Status.AwaitingPrize` (`L422`).
  - `prizeToken` (`IERC721`, storage at `L70`): Configured ERC-721 prize contract set in `initialize` (`L200`).
  - `prizeTokenId` (`uint256`, storage at `L73`): Configured ERC-721 prize token ID set in `initialize` (`L201`).
  - `sponsor` (`address`, storage at `L61`): Configured raffle sponsor set in `initialize` (`L197`).
  - `factory` (`address`, immutable at `L55`): Canonical `RaffleFactory` address set in `Raffle.constructor` (`L161`).
- Preconditions:
  - The clone has been initialized via `Raffle.initialize` (`L176-L206`) so that `status == Status.AwaitingPrize` (`L205`), `prizeToken != IERC721(address(0))` (`L183`, `L200`), and `sponsor != address(0)` (`L182`, `L197`). Note that `Status.AwaitingPrize` has enum ordinal `0` (`packages/contracts/src/interfaces/IRaffle.sol:L20-L23`), which matches default zero-initialized storage on an uninitialized clone; however, on an uninitialized clone `prizeToken` is `address(0)` and `sponsor` is `address(0)`, so `msg.sender != address(prizeToken)` (`L422`) reverts because an external EVM call cannot have `msg.sender == address(0)`. On the shared implementation contract, `Raffle.constructor` sets `status = Status.Refunding` (`L165`), so `status != Status.AwaitingPrize` (`L422`) always reverts.
  - `prizeToken` (`msg.sender`) only invokes `onERC721Received` with `operator == factory`, `from == sponsor`, and `tokenId == prizeTokenId` as part of an actual ERC-721 transfer of `prizeTokenId` from `sponsor` to `address(this)` initiated by `factory`. Not enforced inside `onERC721Received` itself; in `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L128-L134`), the factory invokes `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` (`L128`) and subsequently checks `prize.ownerOf(params.prizeTokenId) == raffle` (`L129-L131`) and `IRaffle(raffle).status() == IRaffle.Status.Active` (`L132-L134`). Beyond those creation-time checks and `IERC165.supportsInterface(type(IERC721).interfaceId)` (`packages/contracts/src/RaffleFactory.sol:L171-L177`), standards-compliant custody behavior of the untrusted `prizeToken` contract is unestablished (`nothing found`).

---

**Outputs & Effects:**
- Returns `selector = IERC721Receiver.onERC721Received.selector` (`0x150b7a02`) on success (`L430`).
- State writes:
  - `status = Status.Active` (`L428`).
- Events:
  - Emits `PrizeDeposited(msg.sender, tokenId, from)` (`L429`, declared at `packages/contracts/src/interfaces/IRaffle.sol:L62`).
- External interactions: None.
- Postconditions on success:
  - `status == Status.Active` (`L428`). Because no function in `Raffle.sol` ever writes `Status.AwaitingPrize` after `initialize` (`L177`, `L205`), `onERC721Received` can succeed at most once in a clone's lifetime.
  - The caller receives `IERC721Receiver.onERC721Received.selector` (`L430`).

---

**Block-by-Block:**

```solidity
// L421-L426
        if (
            status != Status.AwaitingPrize || msg.sender != address(prizeToken) || tokenId != prizeTokenId
                || from != sponsor || operator != factory
        ) {
            revert UnexpectedPrize(msg.sender, tokenId, from, operator);
        }
```
- **What:** Verifies that the raffle is currently in `Status.AwaitingPrize`, the caller is the configured `prizeToken`, the transferred token ID is `prizeTokenId`, the previous owner `from` is `sponsor`, and the transfer `operator` is `factory`; otherwise reverts with `UnexpectedPrize(msg.sender, tokenId, from, operator)`.
- **Why here:** Guards the state transition to `Status.Active` at `L428` and rejects any safe ERC-721 transfer that is not the canonical factory prize deposit (including transfers in later statuses, wrong ERC-721 contracts, wrong token IDs, direct transfers where `operator != factory`, or transfers from an address other than `sponsor`).
- **Assumes:** `initialize` (`L176-L206`) has already populated `prizeToken` (non-zero, `L183`, `L200`), `prizeTokenId` (`L201`), `sponsor` (non-zero, `L182`, `L197`), and `status = Status.AwaitingPrize` (`L205`), and `Raffle.constructor` (`L161`) has set `factory`; also assumes `msg.sender` (`prizeToken`) truthfully reports `operator`, `from`, and `tokenId`.
- **Establishes:** `status == Status.AwaitingPrize`, `msg.sender == address(prizeToken)`, `tokenId == prizeTokenId`, `from == sponsor`, and `operator == factory` prior to activation.
- **Depended on by:** `L428-L430`, `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L128-L134`), and all downstream functions gated on `Status.Active` (`buyEntries` at `L215`, `requestDraw` at `L241`, `enableRefunds` at `L279`).

```solidity
// L428-L430
        status = Status.Active;
        emit PrizeDeposited(msg.sender, tokenId, from);
        selector = IERC721Receiver.onERC721Received.selector;
```
- **What:** Sets `status` to `Status.Active`, emits `PrizeDeposited`, and assigns the ERC-721 receiver magic selector (`0x150b7a02`) to the return variable `selector`.
- **Why here:** Placed after the guard at `L421-L426`; updating `status` to `Status.Active` immediately ensures that any subsequent or re-entrant call to `onERC721Received` will fail the `status != Status.AwaitingPrize` check at `L422` even though `onERC721Received` does not carry the `nonReentrant` modifier.
- **Assumes:** The guard at `L421-L426` succeeded.
- **Establishes:** `status == Status.Active` and return value `selector == IERC721Receiver.onERC721Received.selector`.
- **Depended on by:** `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L132-L134`), which asserts `IRaffle(raffle).status() == IRaffle.Status.Active` after `prize.safeTransferFrom` returns, and `ERC721Utils.checkOnERC721Received` (`packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L33-L37`) in standard ERC-721 implementations, which requires `retval == IERC721Receiver.onERC721Received.selector`.

---

**Cross-Function Dependencies:**
- **Callees:** No internal or external calls.
- **Callers:**
  - `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L97-L148`) indirectly via `prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId)` at `L128` (in OpenZeppelin `ERC721`, `safeTransferFrom` at `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L128-L136` calls `ERC721Utils.checkOnERC721Received` at `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L33`). `createRaffle` relies on `onERC721Received` to transition `status` from `Status.AwaitingPrize` to `Status.Active` (verified at `packages/contracts/src/RaffleFactory.sol:L132-L134`) and to return `IERC721Receiver.onERC721Received.selector` so `safeTransferFrom` succeeds.
  - Any external caller or ERC-721 contract directly (since `onERC721Received` is `external` at `L416-L418`), which will revert at `L421-L426` unless all five conditions (`status == Status.AwaitingPrize`, `msg.sender == address(prizeToken)`, `tokenId == prizeTokenId`, `from == sponsor`, `operator == factory`) hold.
- **Shared state:**
  - `status` (`L124`): written by `Raffle.constructor` (`L165`), `Raffle.initialize` (`L205`), `Raffle.onERC721Received` (`L428`), `Raffle.requestDraw` (`L252`), `Raffle.enableRefunds` (`L299`), and `Raffle.fulfillRandomWords` (`L521`); read by `_requireStatus` (`L574`, used by `buyEntries` at `L215`, `requestDraw` at `L241`, `refundTickets` at `L350`), `enableRefunds` (`L279`, `L289`), `redeemWinningTicket` (`L311`), `releaseSponsorPrize` (`L396`), `fulfillRandomWords` (`L511`), `_settleWinningTicket` (`L535`), and externally by `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L132`).
  - `prizeToken` (`L70`), `prizeTokenId` (`L73`), `sponsor` (`L61`): written once per clone in `Raffle.initialize` (`L197`, `L200`, `L201`); read in `onERC721Received` (`L422-L423`) and in lifecycle functions (`enableRefunds` at `L282`, `redeemWinningTicket` at `L332-L335`, `releaseSponsorPrize` at `L404-L406`, `_update` at `L498`, `_transferQuote` at `L565`).
  - `factory` (`L55`): immutable written in `Raffle.constructor` (`L161`); read in `initialize` (`L178`), `onERC721Received` (`L423`), and `_isProtocolDestination` (`L598-L599`).
- **Invariant couplings:**
  - Lifecycle progression: `Raffle.initialize` sets `status = Status.AwaitingPrize` (`L205`), and `onERC721Received` is the sole transition out of `Status.AwaitingPrize` into `Status.Active` (`L428`). Because `RaffleFactory.createRaffle` atomically clones (`packages/contracts/src/RaffleFactory.sol:L106`), initializes (`L109-L121`), transfers the prize (`L128`), and asserts `IRaffle(raffle).status() == IRaffle.Status.Active` (`L132-L134`), no registered clone can persist beyond `createRaffle` in `Status.AwaitingPrize`.
  - Prize escrow coupling: `redeemWinningTicket` (`L334-L337`) and `releaseSponsorPrize` (`L404-L405`) assume that once `status` has entered `Status.Active` (and later `Status.NftWon`, `Status.CashWon`, or `Status.Refunding`), the clone holds `prizeTokenId` on `prizeToken` and can transfer it via `prizeToken.transferFrom(address(this), ..., prizeTokenId)`. Notice also that `Raffle` does not override `ERC721.supportsInterface` (`packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L45-L50`) to advertise `type(IERC721Receiver).interfaceId`, relying on `prizeToken.safeTransferFrom` calling `onERC721Received` directly rather than querying `IERC165.supportsInterface(type(IERC721Receiver).interfaceId)`.
  - Unsafe transfer exclusion: as noted in the NatSpec at `L410-L411`, `onERC721Received` only guards `safeTransferFrom` calls that invoke the receiver hook; NFTs transferred via plain `transferFrom` bypass `onERC721Received` entirely.

---

**Open Questions:**
- None; all paths through `onERC721Received` (`L416-L431`) and its caller `RaffleFactory.createRaffle` (`packages/contracts/src/RaffleFactory.sol:L97-L148`) are contained within the in-scope source files.
