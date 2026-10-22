## REQ-48 — Trusted dependencies versus untrusted extension points

> "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted."
> — DESIGN.md:L2, sentence 16

**Verdict:** partial · confidence: high

---

**What this demands of an implementation:** The canonical factory deployment may deliberately rely on one quote token and one Chainlink wrapper, but those identities must be fixed outside sponsor and buyer control. Per-raffle callers must not be able to substitute another payment token or randomness wrapper. Conversely, a sponsor-selected prize contract and a buyer-selected ticket recipient must be handled as adversarial external code: their callbacks and return values cannot be promoted into security-critical facts merely because they claim an interface or return an expected value.

---

**Where enforcement lives:**

The trusted dependency identities are constructor inputs stored in immutable factory fields. Construction checks that both addresses contain code, checks only six-decimal metadata for the quote token, fixes both addresses, and deploys the sole raffle implementation with those same values:

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L65-L78
constructor(address quoteToken_, address vrfWrapper_, address protocolTreasury_) {
    _requireContract(quoteToken_);
    _requireContract(vrfWrapper_);
    if (protocolTreasury_ == address(0)) revert ZeroAddress();

    uint8 quoteDecimals = 0;
    try IERC20Metadata(quoteToken_).decimals() returns (uint8 decimals_) {
        quoteDecimals = decimals_;
    } catch {
        revert UnsupportedQuoteToken(quoteToken_);
    }
    if (quoteDecimals != RaffleConstants.QUOTE_TOKEN_DECIMALS) {
        revert InvalidQuoteTokenDecimals(quoteDecimals, RaffleConstants.QUOTE_TOKEN_DECIMALS);
    }
```

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L85-L91
quoteToken = quoteToken_;
vrfWrapper = vrfWrapper_;
protocolTreasury = protocolTreasury_;

address implementation = address(new Raffle(quoteToken_, vrfWrapper_));
if (protocolTreasury_ == implementation) revert UnsafeProtocolDestination(protocolTreasury_);
raffleImplementation = implementation;
```

The factory explicitly assigns proof of official-USDC identity to deployment tooling rather than trying to infer identity from token metadata (`target/packages/contracts/src/RaffleFactory.sol:L58-L63`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L6-L9`). Thus the source establishes a deployment trust anchor, not the actual mainnet identity of the supplied address.

Per-raffle sponsors have no quote-token or wrapper field to supply. Their creation struct contains only the sponsor recipient, prize token and ID, reserve, and end time (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L14-L26`). `createRaffle` clones the immutable `raffleImplementation` and passes only clone-local fields, including the sponsor-selected prize token, to `initialize`:

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

`Clones.clone` embeds the supplied implementation in the proxy bytecode and delegates to that fixed address (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L62`). The implementation stores `factory` and `quoteToken` as immutables (`target/packages/contracts/src/Raffle.sol:L52-L59`); its constructor fixes the quote token and passes the wrapper to an inherited immutable (`target/packages/contracts/src/Raffle.sol:L151-L166`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L34-L47`). Clone initialization is one-time, factory-only, and has no branch that writes either dependency (`target/packages/contracts/src/Raffle.sol:L176-L205`).

Every quote-token movement uses that immutable field: purchases call it at `target/packages/contracts/src/Raffle.sol:L223-L225`, and every payout funnels through `_transferQuote` at `target/packages/contracts/src/Raffle.sol:L560-L567`. `SafeERC20` validates call success or an optional boolean return but does not verify balance deltas (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L176-L200`, `L212-L244`), so exact fee-free, non-rebasing movement is deliberately on the trusted side of the boundary. Wrapper pricing and requests likewise use the inherited immutable (`target/packages/contracts/src/Raffle.sol:L249-L260`, `L435-L448`), and `rawFulfillRandomWords` rejects every caller other than that immutable wrapper before dispatch (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`).

Ticket recipients are caller-selected at `buyEntries`, but the purchase is guarded while the ticket is safely minted:

```solidity
// target/packages/contracts/src/Raffle.sol:L209-L235
function buyEntries(address recipient, uint128 entryCount)
    external
    override
    nonReentrant
    returns (uint256 ticketId)
{
    _requireStatus(Status.Active);
    if (block.timestamp >= endTime) revert SaleEnded(endTime, block.timestamp);
    if (recipient == address(0)) revert InvalidRecipient();
    if (entryCount == 0) revert ZeroEntryCount();
    if (entryCount > type(uint128).max - totalEntries) {
        revert TotalEntriesOverflow(totalEntries, entryCount);
    }

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
```

The inherited `_safeMint` writes ownership and then invokes the contract recipient (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L279-L290`); the receiver utility requires the exact acceptance selector and reverts or bubbles failure (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`). The active `nonReentrant` modifier brackets that callback (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`, `L94-L105`). Mint and transfer updates additionally reject the factory, implementation, quote token, wrapper, prize token, this raffle, and registered sibling raffles as ticket destinations (`target/packages/contracts/src/Raffle.sol:L491-L502`, `L587-L605`). These paths do not give an arbitrary recipient a dependency role.

The gap is the sponsor-selected prize contract. Although its address is excluded from the quote-token and wrapper identities (`target/packages/contracts/src/RaffleFactory.sol:L154-L169`), acceptance relies on claims made by that same address. It supplies the ERC-165 answer:

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

It then executes the purported safe transfer and supplies the `ownerOf` answer on which factory publication depends:

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L127-L147
IERC721 prize = IERC721(params.prizeToken);
prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
if (prize.ownerOf(params.prizeTokenId) != raffle) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
if (IRaffle(raffle).status() != IRaffle.Status.Active) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}

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

The receiver checks the callback tuple before entering `Active` (`target/packages/contracts/src/Raffle.sol:L409-L431`), but a sponsor-selected contract controls whether it calls that receiver and what its own `ownerOf` returns. Later prize delivery again accepts the selected contract's `transferFrom` execution and `ownerOf` report (`target/packages/contracts/src/Raffle.sol:L327-L337`, `L395-L406`). The production interface makes this trust explicit: “Supported prizes are honest, standards-compliant ERC-721s” (`target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`). Consequently, the prize path does not implement the specification's untrusted-contract side: a contract that returns the expected interface and ownership answers can reach publication without an independently established ERC-721 ledger or transferable prize. It cannot replace the immutable quote token, but it is granted an honesty assumption over the security-critical fact of prize escrow and delivery.

---

**Paths walked:**

- Trusted deployer → `RaffleFactory.constructor` → `_requireContract(quoteToken_)` → `decimals()` success/catch and six-decimal branch → immutable `quoteToken`/`vrfWrapper` writes → `new Raffle(quoteToken_, vrfWrapper_)`: dependencies are fixed for that deployment (`target/packages/contracts/src/RaffleFactory.sol:L65-L91`). ✓
- Sponsor → `createRaffle` → `_validateCreateParams` → fixed-target `Clones.clone` → factory-only `initialize`: the sponsor supplies `prizeToken` but has no quote-token or wrapper parameter (`target/packages/contracts/src/RaffleFactory.sol:L97-L121`, `L152-L179`; `target/packages/contracts/src/Raffle.sol:L176-L205`). ✓
- Clone → `buyEntries` and `_transferQuote`: both inbound and outbound quote movement target the constructor-fixed `quoteToken`; no alternative token parameter reaches either call (`target/packages/contracts/src/Raffle.sol:L223-L225`, `L560-L567`). ✓
- Draw requester → `requestDraw` → `requestRandomnessPayInNative` → configured wrapper; callback → `rawFulfillRandomWords` → exact wrapper-sender comparison (`target/packages/contracts/src/Raffle.sol:L240-L260`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L76-L89`, `L101-L107`). ✓
- Buyer → `buyEntries(recipient, entryCount)` → state/accounting writes → `_safeMint` → optional recipient callback: protocol destinations are screened, rejection reverts, and the purchase guard remains entered across the callback (`target/packages/contracts/src/Raffle.sol:L209-L235`, `L497-L502`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L279-L290`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`). ✓
- Sponsor → `createRaffle(params.prizeToken)` → prize-supplied `supportsInterface(true)` → prize-supplied `safeTransferFrom`/receiver callback → prize-supplied `ownerOf(raffle)` → `RaffleCreated`: the success branch treats one attacker-selected contract's mutually consistent assertions as proof of escrow (`target/packages/contracts/src/RaffleFactory.sol:L127-L147`, `L154-L177`; `target/packages/contracts/src/Raffle.sol:L416-L430`). ✗
- Winner or sponsor release → sponsor-selected `prizeToken.transferFrom` → sponsor-selected `ownerOf(expectedRecipient)`: atomic rollback handles reverts and unexpected reported owners, but the successful report is still trusted (`target/packages/contracts/src/Raffle.sol:L327-L337`, `L395-L406`). ✗

---

**Searched:**

- Scope → all five production files and all 31 paths listed in `target/dependency-hashes.json:L2-L32` were read; the manifest contained 31 entries and all 31 SHA-256 checks matched (0 mismatches).
- `quoteToken|quote-token|quote token|USDC` over that 36-file scope → 81 matching lines in 5 files. Narrowing to executable `IERC20(`, `IERC20Metadata(`, `quoteToken.`, dependency writes, and `address(quoteToken)` produced 6 sites: `RaffleFactory.sol:L71,L85` and `Raffle.sol:L162,L224,L566,L599`.
- `vrfWrapper|vrf wrapper|i_vrfV2PlusWrapper|Chainlink wrapper` → 32 matching lines in 5 files. The write/call chain resolves to `RaffleFactory.sol:L86,L89`, `Raffle.sol:L157,L257,L437-L447,L600-L612`, and `VRFV2PlusWrapperConsumerBase.sol:L35,L43-L46,L68-L88,L101-L106`.
- `prizeToken|prize-token|prize contract|prize token` → 78 matching lines in 4 files. Executable calls resolve to the factory validation/escrow path at `RaffleFactory.sol:L115-L177` and release/receiver paths at `Raffle.sol:L200-L201,L329-L336,L404-L405,L416-L425`.
- `recipient|onERC721Received|checkOnERC721Received|_safeMint|safeTransferFrom` → 98 matching lines in 10 files. The live ticket-recipient callback chain is `Raffle.sol:L209-L235` → `ERC721.sol:L279-L290` → `ERC721Utils.sol:L25-L48`.
- `constructor|initialize|new Raffle|Clones.clone|immutable` → 79 matching lines in 10 files. The relevant construction chain is `RaffleFactory.sol:L65-L91,L105-L121` → `Clones.sol:L47-L62` → `Raffle.sol:L151-L205` → `VRFV2PlusWrapperConsumerBase.sol:L34-L47`.
- Strict writes matching `\b(quoteToken|vrfWrapper|i_vrfV2PlusWrapper|prizeToken)\s*=(?!=)` → 5 hits: `RaffleFactory.sol:L85-L86`, `VRFV2PlusWrapperConsumerBase.sol:L46`, and `Raffle.sol:L162,L200`. Only `prizeToken` is written from clone initialization; quote token and wrapper are written from constructor flow.
- Setter/change/replace/configure function-name variants combined with `quote`, `token`, or `wrapper` → 0 hits in the 36-file scope. The only `quoteToken_`/`vrfWrapper_` parameter declarations are the two constructors at `RaffleFactory.sol:L65` and `Raffle.sol:L155`.
- `createRaffle(`, `.initialize(`, `function initialize`, `new Raffle`, and `clone(` → 11 matching lines in 5 files; the only production caller of clone initialization is `RaffleFactory.sol:L106-L121`, while the remaining hits are declarations or library overloads.

---

**How the verdict was reached:** This is `partial`, not `implemented`, because the fixed quote-token/wrapper and ticket-recipient paths enforce the declared sides of the boundary, but the prize path requires an attacker-selected contract to be honest and treats its interface, callback, transfer, and ownership reports as the facts that activate and publish a raffle. It is not `contradicted` as a whole because no sponsor or buyer can replace the stored quote token or wrapper, all quote flows use the stored token, wrapper callbacks are sender-authenticated, and ticket-recipient callbacks are explicitly handled as external interactions. It is not `absent`: the immutables, factory-only initialization, fixed clone target, destination screening, safe-receiver check, and reentrancy guard are concrete enforcement. The precise missing portion is adversarial treatment of the arbitrary prize contract on the successful self-report branch.

---

**Open questions:**

- The frozen source does not identify a deployed factory or its constructor arguments. Confirming that a concrete `quoteToken_` and `vrfWrapper_` are the official chain deployments requires the deployment records that the source itself assigns to tooling (`target/packages/contracts/src/RaffleFactory.sol:L58-L63`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L6-L9`). This does not change the source-level partial verdict: per-raffle actors cannot substitute those fields, while the prize-contract success path still assumes honesty.
