## REQ-01 — NFT-prize raffle flow

> "Ethereum NFT raffle; immutable factory, ERC-1167 clones with immutable implementation."
> — DESIGN.md:L2, sentence 1

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** The supplied checkable for this record is: "The implemented Ethereum smart-contract system conducts a raffle whose prize is an NFT." Concretely, the implementation must accept an ERC-721 token and token ID as the prize, place that token in raffle custody, sell or otherwise assign raffle entries, select a winning entry, prove the corresponding winning ticket, and deliver the same configured ERC-721 to the winner on the NFT-winning outcome. Per that supplied checkable, this analysis does not separately judge the factory-immutability or clone-immutability clauses in the quoted sentence.

---

**Where enforcement lives:**

The implementation is Solidity/EVM contract code: `Raffle` declares `pragma solidity 0.8.36` and inherits ERC-721 ticket behavior plus the ERC-721 receiver interface (`target/packages/contracts/src/Raffle.sol:L2,L28`). The prize itself is separately typed as `IERC721` and identified by both contract and token ID (`target/packages/contracts/src/Raffle.sol:L69-L73`).

The factory first requires the proposed prize address to contain code, then calls ERC-165 and rejects a contract that does not report the `IERC721` interface (`target/packages/contracts/src/RaffleFactory.sol:L154-L178`):

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L154-L178
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
    if (params.reserveEntries == 0) revert ZeroReserveEntries();
}
```

Creation passes the same prize contract and token ID into the new raffle, then safe-transfers that token from the sponsor and requires both reported custody and `Active` status before creation can return (`target/packages/contracts/src/RaffleFactory.sol:L105-L134`):

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L105-L120
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

`initialize` is one-time and factory-only, stores the configured `IERC721` and token ID, and leaves the clone waiting for that prize (`target/packages/contracts/src/Raffle.sol:L176-L205`). The receiver callback accepts only that exact token contract, token ID, sponsor, and factory operator; only then does it activate the raffle (`target/packages/contracts/src/Raffle.sol:L416-L430`):

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

The active raffle sells positive entry counts before the sale end, assigns each purchase a contiguous global entry range, records the paid pot, and mints one ERC-721 range ticket (`target/packages/contracts/src/Raffle.sol:L209-L236`):

```solidity
// target/packages/contracts/src/Raffle.sol:L223-L236
uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;
quoteToken.safeTransferFrom(msg.sender, address(this), grossAmount);

uint128 firstEntry = totalEntries + 1;
uint128 lastEntry = totalEntries + entryCount;
ticketId = uint256(ticketCount) + 1;

totalEntries = lastEntry;
++ticketCount;
_ticketRanges[ticketId] = TicketRange({ firstEntry: firstEntry, lastEntry: lastEntry });
unsettledPot += grossAmount;

_safeMint(recipient, ticketId);
emit TicketPurchased(msg.sender, recipient, ticketId, firstEntry, lastEntry, entryCount, grossAmount);
```

After the sale, `requestDraw` requires at least one sold entry and requests one random word (`target/packages/contracts/src/Raffle.sol:L240-L260`). The inherited gateway rejects every callback caller other than the configured wrapper before invoking the raffle hook (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L106`). The hook rejects an in-flight, non-drawing, wrong-request, wrong-length, or late callback; on the accepted path it selects a one-based entry and records `NftWon` when the reserve is met (`target/packages/contracts/src/Raffle.sol:L509-L523`):

```solidity
// target/packages/contracts/src/Raffle.sol:L509-L523
function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    if (
        _requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1
            || block.timestamp >= callbackDeadline()
    ) {
        emit VrfCallbackIgnored(requestId, vrfRequestId, status);
        return;
    }

    uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
    winningEntry = resolvedEntry;
    resolvedAt = uint64(block.timestamp);
    status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;

    emit RaffleResolved(requestId, resolvedEntry, status);
}
```

Settlement accepts a ticket only when its stored inclusive range contains `winningEntry` (`target/packages/contracts/src/Raffle.sol:L533-L557,L579-L584`). Redemption then requires the current ticket owner, burns that ticket, and on `NftWon` transfers the exact stored `prizeTokenId` from the raffle to that owner and verifies the token reports the owner afterward (`target/packages/contracts/src/Raffle.sol:L309-L345`):

```solidity
// target/packages/contracts/src/Raffle.sol:L320-L345
address winner = ownerOf(ticketId);
if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);

winnerRecipient = winner;
winnerRedeemed = true;
_burn(ticketId);

address deliveredPrizeToken = address(0);
uint256 deliveredPrizeTokenId = 0;
if (result == Status.NftWon) {
    if (prizeClaimed) revert PrizeAlreadyClaimed();
    prizeClaimed = true;
    deliveredPrizeToken = address(prizeToken);
    deliveredPrizeTokenId = prizeTokenId;
    prizeToken.transferFrom(address(this), winner, deliveredPrizeTokenId);
    if (prizeToken.ownerOf(deliveredPrizeTokenId) != winner) {
        revert PrizeDeliveryVerificationFailed(winner);
    }
} else {
    cashAmount = winnerProceeds;
    if (cashAmount == 0) revert NoWinnerProceeds();
    winnerProceeds = 0;
    _transferQuote(winner, cashAmount);
}

emit WinningTicketRedeemed(ticketId, winner, result, cashAmount, deliveredPrizeToken, deliveredPrizeTokenId);
```

---

**Paths walked:**

- `RaffleFactory.createRaffle` → `_validateCreateParams`: a successful path requires deployed code and a successful `supportsInterface(type(IERC721).interfaceId)` response; false or reverting responses reject the prize (`target/packages/contracts/src/RaffleFactory.sol:L97-L104,L154-L178`). ✓
- `RaffleFactory.createRaffle` → `Clones.clone` → `Raffle.initialize`: the factory supplies the same `prizeToken` and `prizeTokenId`; initialization rejects repeat calls and non-factory callers before storing them (`target/packages/contracts/src/RaffleFactory.sol:L105-L121`; `target/packages/contracts/src/Raffle.sol:L176-L205`). ✓
- `RaffleFactory.createRaffle` → external prize `safeTransferFrom` → `Raffle.onERC721Received` → factory postconditions: the callback must identify the configured token, ID, sponsor, and factory, and successful creation additionally requires `ownerOf(tokenId) == raffle` and `status == Active` (`target/packages/contracts/src/RaffleFactory.sol:L127-L134`; `target/packages/contracts/src/Raffle.sol:L416-L430`). ✓
- `Raffle.buyEntries`: only `Active` raffles before `endTime` accept a positive entry count; the path creates a nonempty inclusive entry range and mints its ticket (`target/packages/contracts/src/Raffle.sol:L209-L236`). ✓
- `Raffle.requestDraw` → inherited `requestRandomnessPayInNative` → `rawFulfillRandomWords` → `Raffle.fulfillRandomWords`: an authenticated, current, one-word callback selects an entry in `[1,totalEntries]`; the reserve-met branch records `NftWon` (`target/packages/contracts/src/Raffle.sol:L240-L260,L509-L523`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L88,L101-L106`). ✓
- `settleWinningTicket` or redemption's inline settlement → `_settleWinningTicket` → `_requireWinningTicket`: settlement is terminal-status-only and the proposed ticket range must contain the selected entry (`target/packages/contracts/src/Raffle.sol:L304-L318,L533-L557,L579-L584`). ✓
- `redeemWinningTicket`, `NftWon` branch: only `ownerOf(ticketId)` may proceed; the ticket is burned and the exact configured ERC-721/token ID is transferred and checked at the winner (`target/packages/contracts/src/Raffle.sol:L320-L345`). ✓
- `redeemWinningTicket`, `CashWon` branch: it pays quote-token proceeds rather than substituting a different NFT (`target/packages/contracts/src/Raffle.sol:L338-L343`). The configured ERC-721 can then leave custody only through `releaseSponsorPrize`, which is limited to `CashWon` or `Refunding` and transfers that same stored token ID to the fixed sponsor recipient (`target/packages/contracts/src/Raffle.sol:L395-L406`). This alternate terminal result does not create a path where an `NftWon` winner receives something other than the configured NFT. ✓

---

**Searched:**

- Full allowed scope → read all five production files (`Raffle.sol`, `RaffleFactory.sol`, `IRaffle.sol`, `IRaffleFactory.sol`, and `RaffleConstants.sol`) and all 31 paths enumerated by `target/dependency-hashes.json:L2-L32`; SHA-256 verification returned `OK` for every listed dependency.
- `createRaffle|initialize|_validateCreateParams` in the five production files → 9 matches: 5 in `RaffleFactory.sol`, 1 in `IRaffleFactory.sol`, 1 in `Raffle.sol`, and 2 in `IRaffle.sol`. The two `createRaffle(` hits are the interface declaration and the factory implementation (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L104`; `target/packages/contracts/src/RaffleFactory.sol:L97`); no second production creation entrypoint or in-scope caller was found.
- `IERC721|supportsInterface|safeTransferFrom|ownerOf|onERC721Received|transferFrom` in the five production files → 29 matches: 18 in `Raffle.sol`, 8 in `RaffleFactory.sol`, and 3 in `IRaffle.sol`. Reading the hits reached the ERC-165 check, escrow call, exact receiver callback, custody postcondition, winning-ticket ownership check, winner delivery, and sponsor-return branch (`target/packages/contracts/src/RaffleFactory.sol:L127-L134,L171-L177`; `target/packages/contracts/src/Raffle.sol:L320-L336,L404-L430`).
- `buyEntries|requestDraw|fulfillRandomWords|winningEntry|NftWon|redeemWinningTicket|releaseSponsorPrize` in the five production files → 34 matches: 15 in `Raffle.sol` and 19 in `IRaffle.sol`. The two `redeemWinningTicket(` hits are the interface declaration and implementation (`target/packages/contracts/src/interfaces/IRaffle.sol:L338`; `target/packages/contracts/src/Raffle.sol:L309`).
- `prize(Token)?\.(safeTransferFrom|transferFrom)|PrizeDeposited|PrizeEscrowVerificationFailed|PrizeDeliveryVerificationFailed|releaseSponsorPrize` in the five production files → 13 line hits. The only actual configured-prize transfer calls are sponsor-to-raffle escrow, raffle-to-winner delivery, and raffle-to-sponsor return (`target/packages/contracts/src/RaffleFactory.sol:L128`; `target/packages/contracts/src/Raffle.sol:L334,L404`).
- `Status\.(AwaitingPrize|Active|Drawing|NftWon|CashWon|Refunding)` in the five production files → 19 line hits: 1 factory postcondition and 18 raffle checks or transitions. The complete lifecycle-relevant sequence is waiting for prize, active sale, drawing, and terminal NFT/cash/refund handling (`target/packages/contracts/src/RaffleFactory.sol:L132`; `target/packages/contracts/src/Raffle.sol:L205,L215,L241,L252,L299,L312,L329,L397,L422,L428,L511,L521,L536,L543`).
- `rawFulfillRandomWords|OnlyVRFWrapperCanFulfill|fulfillRandomWords` in `Raffle.sol` and the inherited Chainlink base → 8 line hits. The base authenticates the wrapper at `L101-L106`, and the application hook enforces request, state, shape, and time at `Raffle.sol:L509-L523`.
- Alternate vocabulary `reward|rewards|rewarded|rewarding|lottery|award|awards|awarded|awarding` in the five production files → 0 hits. Relevant behavior is expressed as `prize`, `winner`, `draw`, `NftWon`, custody calls, and status transitions; those implementations were read rather than accepted by name.
- Dependency callees and bases → `Clones.clone(address)` reaches the bytecode construction and `create` path (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L60`); the ERC-721 interface defines ownership and safe transfer (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L33-L55,L76-L91`); the inherited ticket implementation's `ownerOf`, transfer, mint, and burn paths were read (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L61-L63,L114-L136,L216-L245,L259-L308`); and the VRF callback gateway was read through its caller check (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L106`).

---

**How the verdict was reached:** This is `implemented`, not `partial`, because every successful canonical creation path passes the ERC-721 report check, stores one token contract and token ID, requires that exact deposit callback, and verifies custody before the raffle becomes active (`target/packages/contracts/src/RaffleFactory.sol:L97-L134,L154-L178`; `target/packages/contracts/src/Raffle.sol:L176-L205,L416-L430`). The operational path then sells represented entries, accepts only the authenticated current draw callback, selects a winning entry, proves the containing ticket, and transfers the same configured ERC-721/token ID to the current winning-ticket owner on `NftWon` (`target/packages/contracts/src/Raffle.sol:L209-L260,L509-L523,L533-L557,L579-L584,L309-L345`). The cash and refund outcomes retain the configured asset as an ERC-721 and return it through the single sponsor-prize path; they do not create an `NftWon` branch that substitutes a non-NFT (`target/packages/contracts/src/Raffle.sol:L338-L343,L395-L406`). The property is concrete enough to check, so `undecidable` does not apply, and the implementation does not merely contain NFT-themed names: its interface checks, custody postconditions, entry-range state, callback gates, range proof, and transfer/ownership verification were followed to their callees and terminal branches.

---

**Open questions:**

- The concrete sponsor-selected prize implementation is external to the supplied target. The factory can establish deployed code, a reported ERC-721 interface, the exact receiver tuple, and reported ownership before and after transfers (`target/packages/contracts/src/RaffleFactory.sol:L127-L134,L154-L177`; `target/packages/contracts/src/Raffle.sol:L421-L430,L334-L336,L404-L405`), but source in scope cannot independently prove that an adversarial external contract's ERC-165 and `ownerOf` responses are semantically honest. `IRaffle` explicitly states that supported prizes are assumed to be honest, standards-compliant ERC-721s (`target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`). This external dependency question does not expose a local success path that omits the NFT-prize flow.
