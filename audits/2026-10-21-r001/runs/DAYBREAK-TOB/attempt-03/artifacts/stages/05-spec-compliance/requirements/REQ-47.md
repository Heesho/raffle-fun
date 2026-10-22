## REQ-47 — No asset movement between raffle clones

> "Never move assets between raffle clones."
> — DESIGN.md:L2, sentence 15

**Verdict:** partial · confidence: high

---

**What this demands of an implementation:** No quote-token balance, prize NFT, or raffle-ticket NFT may be transferred or reallocated from one raffle clone to another. Because the requirement says “Never,” destination classification has to hold when an asset actually moves; checking that a stored recipient is not a clone only when the first raffle is initialized is insufficient if that address can later become a clone.

---

**Where enforcement lives:**

The factory rejects a prize token or sponsor recipient that is already a registered clone when `createRaffle` begins:

```solidity
// packages/contracts/src/RaffleFactory.sol:L154-L169
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
```

The clone repeats destination checks during initialization, then permanently stores the recipient:

```solidity
// packages/contracts/src/Raffle.sol:L181-L205
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
```

The shared classifier recognizes the current clone, factory plumbing, implementation, and any currently registered same-factory clone. Its registry lookup is conditional on the destination already containing code:

```solidity
// packages/contracts/src/Raffle.sol:L593-L604
function _isProtocolDestination(address destination, address prizeToken_)
    private
    view
    returns (bool unsafeDestination)
{
    IRaffleFactory canonicalFactory = IRaffleFactory(factory);
    unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
        || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_
        || destination == canonicalFactory.raffleImplementation();
    if (!unsafeDestination && destination.code.length != 0) {
        unsafeDestination = canonicalFactory.isRaffle(destination);
    }
}
```

That classifier is applied at the moment every ticket ownership update occurs and at the moment every quote-token payout occurs:

```solidity
// packages/contracts/src/Raffle.sol:L497-L502
function _update(address to, uint256 ticketId, address auth) internal override returns (address previousOwner) {
    if (to != address(0) && _isProtocolDestination(to, address(prizeToken))) {
        revert UnsafeProtocolDestination(to);
    }
    previousOwner = super._update(to, ticketId, auth);
}

// packages/contracts/src/Raffle.sol:L564-L567
function _transferQuote(address to, uint256 amount) private {
    if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);
    quoteToken.safeTransfer(to, amount);
}
```

Inherited unsafe and safe ticket transfers both dispatch through the virtual `_update`, and ticket minting does too (`packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135`, `L259-L289`). The quote helper is reached by cash-winner redemption, ticket refunds, sponsor proceeds, and protocol-fee releases (`packages/contracts/src/Raffle.sol:L339-L342`, `L367-L390`). These paths therefore reject an address that has become a registered clone before the transfer executes (`packages/contracts/src/Raffle.sol:L564-L566`, `L593-L604`).

The exception is the sponsor-prize path. It reads the initialization-time recipient and transfers the NFT without calling `_isProtocolDestination` again:

```solidity
// packages/contracts/src/Raffle.sol:L395-L406
function releaseSponsorPrize() external override nonReentrant {
    Status currentStatus = status;
    if (currentStatus != Status.CashWon && currentStatus != Status.Refunding) {
        revert SponsorPrizeUnavailable(currentStatus);
    }
    if (prizeClaimed) revert PrizeAlreadyClaimed();

    address recipient = sponsorRecipient;
    prizeClaimed = true;
    prizeToken.transferFrom(address(this), recipient, prizeTokenId);
    if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);
    emit SponsorPrizeReleased(msg.sender, recipient, address(prizeToken), prizeTokenId);
}
```

`transferFrom`, unlike `safeTransferFrom`, does not require or invoke the recipient's ERC-721 receiver callback (`packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L75-L91`; the supplied implementation performs only `_update` at `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L125`, while its safe overload adds the callback at `L128-L135`). A destination clone therefore cannot reject this extra NFT through `Raffle.onERC721Received`.

---

**Paths walked:**

- `RaffleFactory.createRaffle` → `_validateCreateParams` → `Clones.clone` → `Raffle.initialize` → registry writes → prize `safeTransferFrom`: an already registered clone is rejected as `sponsor`, `sponsorRecipient`, or `prizeToken` before escrow. The factory passes `msg.sender` as `sponsor`, the clone checks that sponsor with `_isProtocolDestination`, and registration precedes the sponsor-to-new-clone prize deposit (`packages/contracts/src/RaffleFactory.sol:L97-L128`; `packages/contracts/src/Raffle.sol:L176-L205`). ✓
- `buyEntries` → `_safeMint` → inherited `_mint` → overridden `_update`: minting a ticket to a currently registered clone reverts (`packages/contracts/src/Raffle.sol:L209-L235`, `L497-L502`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L259-L289`). ✓
- inherited `transferFrom` / both `safeTransferFrom` overloads → overridden `_update`: moving an existing ticket to a currently registered clone reverts before the inherited ledger write; the safe overload's receiver call occurs only after that write path (`packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135`; `packages/contracts/src/Raffle.sol:L497-L502`). ✓
- `redeemWinningTicket`, `CashWon` → `_transferQuote(winner, cashAmount)`: the current owner must be the caller, and the quote transfer rechecks whether that address is now a clone (`packages/contracts/src/Raffle.sol:L309-L342`, `L564-L566`). ✓
- `refundTickets` → `_transferQuote(msg.sender, amount)`: ownership is checked before burning, and the quote transfer rechecks the caller's destination classification (`packages/contracts/src/Raffle.sol:L349-L369`, `L564-L566`). ✓
- `releaseSponsorProceeds` / `releaseProtocolFees` → `_transferQuote`: both stored recipients are reclassified at transfer time, so a recipient that became a clone after initialization causes a revert rather than a cross-clone payment (`packages/contracts/src/Raffle.sol:L374-L391`, `L564-L566`). ✓
- `settleWinningTicket` and `enableRefunds`: these only move amounts among liability fields in the same clone; neither names another clone or invokes a token (`packages/contracts/src/Raffle.sol:L296-L300`, `L528-L558`). ✓
- `redeemWinningTicket`, `NftWon`: the NFT goes only to the exact current ticket owner; known clone destinations cannot acquire the ticket because every mint/transfer reaches `_update` (`packages/contracts/src/Raffle.sol:L314-L337`, `L497-L502`; `packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135`, `L259-L289`). ✓
- Future-clone recipient → `releaseSponsorPrize`: ✗. A sponsor can set raffle A's `sponsorRecipient` to the no-code address at which a later ordinary-`CREATE` clone B will be deployed. At A's creation, `isRaffle[B]` is false and B has no code, so both validation layers accept and store B (`packages/contracts/src/RaffleFactory.sol:L154-L169`; `packages/contracts/src/Raffle.sol:L181-L205`, `L593-L604`). The factory later creates B with `Clones.clone` and records `isRaffle[B] = true` (`packages/contracts/src/RaffleFactory.sol:L105-L125`; `packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L47-L61`). A can reach `Refunding` immediately while empty when its sponsor calls `enableRefunds` (`packages/contracts/src/Raffle.sol:L276-L300`). Anyone can then call A's `releaseSponsorPrize`; it sends A's prize to the now-registered B without a current registry check (`packages/contracts/src/Raffle.sol:L395-L405`). The NFT is an unrelated, unaccounted token in B, and the source explicitly states that NFTs received by unsafe `transferFrom` have no rescue path (`packages/contracts/src/Raffle.sol:L409-L411`).

---

**Searched:**

- Full supplied scope → read all five first-party production files and all 31 paths in `dependency-hashes.json`; independent SHA-256 verification returned `matched=31 mismatched=0`.
- `safeTransferFrom|safeTransfer|transferFrom|\.transfer\(` over the five production files → six hits: executable transfers at `RaffleFactory.sol:L128` and `Raffle.sol:L224`, `L334`, `L404`, `L566`, plus the explanatory comment at `Raffle.sol:L410`. No other first-party token/NFT transfer site was found.
- `_isProtocolDestination|isRaffle|raffleImplementation|UnsafeProtocolDestination|InvalidQuoteDestination` → enforcement at factory validation (`RaffleFactory.sol:L158-L168`), clone initialization (`Raffle.sol:L187-L194`), ticket updates (`Raffle.sol:L497-L501`), quote payouts (`Raffle.sol:L564-L566`), and the classifier (`Raffle.sol:L593-L604`); registry creation is at `RaffleFactory.sol:L123-L125`.
- `sponsorRecipient` in `Raffle.sol` and `RaffleFactory.sol` → 14 hits. The asset-relevant storage assignment is `Raffle.sol:L198`; the only later executable reads are the quote release at `L379` and prize release at `L402`. The former reaches `_transferQuote`; the latter does not.
- `_update\(|_safeMint\(|_burn\(|transferFrom\(|safeTransferFrom\(` → every first-party ticket mint/burn site is at `Raffle.sol:L235`, `L325`, and `L364`, with the single override at `L497-L502`; inherited external transfers and minting route to virtual `_update` at `ERC721.sol:L115-L135`, `L259-L289`, and burns route there with zero destination at `L303-L307`.
- `releaseSponsorPrize|redeemWinningTicket|refundTickets|releaseSponsorProceeds|releaseProtocolFees|buyEntries|createRaffle` → only the interface declarations and implementations listed above; no wrapper or alternate release function bypasses or adds a destination check.
- `rescue|sweep|recover|migrat|reallocat|bridge|forward|withdraw|move assets|cross[- ]raffle` → five hits, all comments or documentation; zero executable rescue, sweep, migration, or cross-raffle function.
- `delegatecall|callcode|selfdestruct|suicide` over all five production files → 0 hits; no production generic-execution or code-replacement path was found.

---

**How the verdict was reached:** The implementation is not `implemented` because destination safety for `releaseSponsorPrize` is based only on initialization-time classification. The same factory can later deploy and register a clone at that stored address, after which the function directly transfers the first clone's prize NFT there. The verdict is `partial`, rather than `contradicted` or `absent`, because the implementation does enforce the invariant for currently known clones at creation, on every ticket ownership update, and at every quote-token payout; the failure is the one reachable NFT-release path that does not repeat the registry check at the time of movement (`packages/contracts/src/RaffleFactory.sol:L154-L169`; `packages/contracts/src/Raffle.sol:L497-L502`, `L564-L566`, `L593-L604`, `L395-L405`).

---

**Open questions:**

- None. The violating path uses two clones registered by the same factory and a standard unsafe ERC-721 `transferFrom`, so it does not depend on whether foreign-factory lookalikes are within the word “clones.”
