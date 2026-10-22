## REQ-53 — Trust boundary for canonical dependencies, prize contracts, and ticket recipients

> "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted."
> — DESIGN.md:L2, sentence 16

**Verdict:** partial · confidence: high

---

**What this demands of an implementation:** The quoted trust boundary permits the raffle to rely on the fixed quote token and Chainlink wrapper, but not on a sponsor-selected prize contract or a ticket receiver behaving honestly. Concretely, an arbitrary prize must not be able to make the protocol recognize nonexistent escrow or delivery through its own self-reports, and a later prize failure must not leave buyer-funded value irreversibly released while the winner cannot obtain the NFT. Reverts and reentry from prize code or ticket-receiver callbacks must either roll back the affected operation or remain unable to break raffle accounting, custody, lifecycle, or claim invariants. The supplied checkable narrows the central question to: “No safety invariant depends on a prize contract behaving honestly; reverting or reentrant prize-contract behavior is contained.”

---

**Where enforcement lives:**

The trusted-dependency half is represented as immutable constructor configuration. The factory checks that both supplied addresses contain code, checks the quote token's reported decimals, and then fixes the quote token and wrapper; the source expressly assigns official-USDC identity verification to deployment tooling rather than claiming to prove it onchain (`target/packages/contracts/src/RaffleFactory.sol:L58-L91`). The shared raffle implementation fixes the same quote token and passes the wrapper to the Chainlink base constructor (`target/packages/contracts/src/Raffle.sol:L151-L166`). The Chainlink base stores the wrapper immutably and admits a randomness callback only from that exact address (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L34-L47`, `L101-L107`).

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L65-L92
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

    if (protocolTreasury_ == address(this) || protocolTreasury_ == quoteToken_ || protocolTreasury_ == vrfWrapper_)
    {
        revert UnsafeProtocolDestination(protocolTreasury_);
    }

    quoteToken = quoteToken_;
    vrfWrapper = vrfWrapper_;
    protocolTreasury = protocolTreasury_;

    address implementation = address(new Raffle(quoteToken_, vrfWrapper_));
    if (protocolTreasury_ == implementation) revert UnsafeProtocolDestination(protocolTreasury_);
    raffleImplementation = implementation;
}
```

Ticket-recipient callbacks are handled as an adversarial interaction. `buyEntries` is `nonReentrant`, collects the trusted quote token, records the range and liability, and only then calls `_safeMint` (`target/packages/contracts/src/Raffle.sol:L209-L236`). OpenZeppelin mints before invoking the receiver (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L279-L290`); a missing selector or receiver revert is converted into, or rethrown as, a revert (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L47`). Nested calls to any guarded raffle operation encounter the shared guard's entered state and revert (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L88-L105`). Inherited ticket transfers themselves update authorized ERC-721 ownership before making a receiver callback (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135`, `L164-L186`, `L216-L245`), while Raffle's override screens protocol sinks (`target/packages/contracts/src/Raffle.sol:L491-L502`).

The prize boundary has local checks, but each semantic fact ultimately comes from the same sponsor-selected contract. Admission requires deployed code and a successful, true ERC-165 response (`target/packages/contracts/src/RaffleFactory.sol:L152-L185`). Creation then calls that contract's `safeTransferFrom`, asks that contract for `ownerOf`, and checks only the clone's locally set `Active` status (`target/packages/contracts/src/RaffleFactory.sol:L97-L134`). The clone sets `Active` when the configured prize address calls with the expected token ID, sponsor, and factory values; it does not independently establish that the prize contract changed an ownership ledger (`target/packages/contracts/src/Raffle.sol:L409-L430`).

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

The source states the resulting dependency explicitly rather than treating prizes as fully adversarial:

```solidity
// target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15
/// @dev Ticket IDs are sequential. Each ticket stores one inclusive uint128 entry range and remains a transferable
///      bearer claim until its owner atomically burns it for redemption or refund. The immutable quote token is trusted
///      canonical six-decimal USDC with standard, non-rebasing, fee-free transfers. Supported prizes are honest,
///      standards-compliant ERC-721s.
```

The decisive gap is the split `NftWon` path. Permissionless settlement allocates the whole quote pot to sponsor and protocol liabilities without calling or checking the prize (`target/packages/contracts/src/Raffle.sol:L528-L557`). Those two liabilities can be released independently, with no `prizeClaimed` or `winnerRedeemed` gate (`target/packages/contracts/src/Raffle.sol:L374-L391`). Prize delivery happens only in the winner's later redemption transaction, where the arbitrary prize contract is called and then supplies the `ownerOf` result used as delivery evidence (`target/packages/contracts/src/Raffle.sol:L309-L345`).

```solidity
// target/packages/contracts/src/Raffle.sol:L538-L555
_requireWinningTicket(ticketId);
uint256 grossPot = unsettledPot;
uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
uint256 sponsorAmount;

if (result == Status.NftWon) {
    sponsorAmount = grossPot - protocolFee;
} else {
    cashAmount = Math.mulDiv(grossPot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS);
    sponsorAmount = grossPot - protocolFee - cashAmount;
    winnerProceeds = cashAmount;
}

settlementComplete = true;
winningTicketId = ticketId;
unsettledPot = 0;
sponsorProceeds = sponsorAmount;
protocolFees = protocolFee;
```

```solidity
// target/packages/contracts/src/Raffle.sol:L323-L337
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
}
```

The `nonReentrant` modifier and transaction rollback protect the redemption transaction's burn and flags if `transferFrom` or `ownerOf` reverts (`target/packages/contracts/src/Raffle.sol:L309-L337`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L105`). They do not reverse sponsor or treasury quote-token releases completed in earlier transactions. Nor can an `NftWon` raffle transition to refunds: `enableRefunds` accepts only `Active` and `Drawing`, rejecting every terminal result (`target/packages/contracts/src/Raffle.sol:L276-L300`). A non-reverting malicious prize can instead make `transferFrom` return and report the winner from `ownerOf`, allowing the burn and `winnerRedeemed`/`prizeClaimed` flags to commit without an independently established delivery (`target/packages/contracts/src/Raffle.sol:L323-L345`).

---

**Paths walked:**

- `RaffleFactory.constructor` → `_requireContract(quoteToken_)` / `_requireContract(vrfWrapper_)` → quote `decimals()` → immutable assignments → `new Raffle` → `VRFV2PlusWrapperConsumerBase.constructor`: supplied dependencies are checked for code, quote decimals are checked, and both addresses become fixed. ✓ for fixed trusted dependencies; official address identity remains a deployment-tooling fact expressly acknowledged at `target/packages/contracts/src/RaffleFactory.sol:L58-L91` and `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L34-L47`.
- wrapper callback → `VRFV2PlusWrapperConsumerBase.rawFulfillRandomWords` → `Raffle.fulfillRandomWords`: the base rejects every caller other than the immutable wrapper before entering Raffle's request/status/word/deadline filter. ✓ (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `target/packages/contracts/src/Raffle.sol:L504-L523`).
- `createRaffle` → `_validateCreateParams`: a reverting/false ERC-165 response is rejected before cloning. ✓ for that failure mode (`target/packages/contracts/src/RaffleFactory.sol:L97-L104`, `L152-L178`). A true response is only the arbitrary prize's self-report. ✗ as evidence of honest ERC-721 behavior (`target/packages/contracts/src/RaffleFactory.sol:L171-L177`).
- `createRaffle` → clone/initialize/register → arbitrary prize `safeTransferFrom` → `Raffle.onERC721Received` → arbitrary prize `ownerOf` → clone `status`: a revert from the prize makes the guarded creation call revert, so its in-transaction counter, clone, and registry writes do not survive. ✓ for transaction-local revert containment (`target/packages/contracts/src/RaffleFactory.sol:L97-L134`). A prize can call the receiver with the expected fields, return from `safeTransferFrom`, and make `ownerOf` report the clone, because all three prize-facing facts are supplied by that same untrusted address. ✗ for adversarial escrow (`target/packages/contracts/src/RaffleFactory.sol:L127-L134`; `target/packages/contracts/src/Raffle.sol:L416-L430`).
- prize-code reentry during creation: `createRaffle` itself is protected by the factory's guard (`target/packages/contracts/src/RaffleFactory.sol:L97-L108`). The clone's receiver is not guarded and changes the clone to `Active` (`target/packages/contracts/src/Raffle.sol:L416-L430`), so the prize can call the clone before returning. The only then-reachable business mutation is a valid, paid `buyEntries` if the prize address has quote tokens and allowance; draw is still before `endTime`, refunds are unavailable to the prize before their deadlines, and terminal claim functions reject `Active` (`target/packages/contracts/src/RaffleFactory.sol:L99-L104`; `target/packages/contracts/src/Raffle.sol:L209-L246`, `L276-L345`, `L395-L405`). This reentry is not globally blocked, but the walked branches did not expose an unpaid quote claim or lifecycle shortcut.
- `buyEntries` → trusted quote `safeTransferFrom` → range/accounting writes → `_safeMint` → recipient `onERC721Received`: rejecting or reverting recipients revert the purchase call; reentry into guarded raffle operations fails while the guard is entered. ✓ (`target/packages/contracts/src/Raffle.sol:L209-L236`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L279-L290`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L47`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L105`). Authorized inherited ticket transfers may occur during a callback, but ownership is updated before the callback and no quote liability is modified by the transfer hook (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135`, `L216-L245`; `target/packages/contracts/src/Raffle.sol:L491-L502`).
- `NftWon` → separate `settleWinningTicket` → `releaseSponsorProceeds` / `releaseProtocolFees` → later `redeemWinningTicket`: settlement and quote releases require no successful prize delivery. A prize that passed creation can later revert forever on `transferFrom`, after sponsor and treasury payments are final, while `NftWon` has no refund transition. ✗ (`target/packages/contracts/src/Raffle.sol:L304-L345`, `L374-L391`, `L528-L557`, `L276-L300`).
- `NftWon` → direct `redeemWinningTicket` while not yet settled: `_settleWinningTicket`, burn/flags, and prize delivery occur in one guarded transaction; a prize revert rolls all of those current-transaction effects back. ✓ transaction-locally, but it does not close the separate-settlement path above (`target/packages/contracts/src/Raffle.sol:L309-L345`).
- `CashWon` → `redeemWinningTicket`: the winner receives the trusted quote-token allocation without calling the prize; later prize return can fail only for the sponsor-selected recipient. ✓ for buyer quote claims (`target/packages/contracts/src/Raffle.sol:L338-L343`, `L395-L406`).
- `Refunding` → `refundTickets`: ticket owners burn and receive trusted quote-token refunds independently of `releaseSponsorPrize`. ✓ for buyer refunds (`target/packages/contracts/src/Raffle.sol:L349-L371`, `L395-L406`).
- prize reentry during winner or sponsor delivery: both prize-delivery entrypoints are `nonReentrant`; nested guarded lifecycle, settlement, refund, or payout calls fail (`target/packages/contracts/src/Raffle.sol:L309-L345`, `L395-L406`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L105`). The winning ticket is burned before the NFT call, and inherited transfers of any other ticket still require owner/operator authorization (`target/packages/contracts/src/Raffle.sol:L320-L334`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L124`, `L164-L186`). ✓ for the walked reentrant state-mutation paths; it does not address a prize that simply lies or withholds delivery.
- callers and wrappers: `createRaffle`, `buyEntries`, `redeemWinningTicket`, and `releaseSponsorPrize` have no in-scope production callers beyond their implementation and interface declarations; they are external entrypoints. `onERC721Received` is reached indirectly through the arbitrary prize's `safeTransferFrom`, while `_safeMint` reaches the ticket receiver through OpenZeppelin (`target/packages/contracts/src/RaffleFactory.sol:L97-L134`; `target/packages/contracts/src/Raffle.sol:L209-L236`, `L309-L345`, `L395-L430`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L287-L290`).

---

**Searched:**

- Frozen scope → read `DESIGN.md`, all five first-party production files, and all 31 paths in `target/dependency-hashes.json` in full; 31/31 dependency SHA-256 values matched the manifest.
- `trusted|untrusted|honest|canonical|standards-compliant|official` → 31 production hits, 0 dependency hits. `honest` has exactly 1 hit, the explicit “Supported prizes are honest” assumption at `target/packages/contracts/src/interfaces/IRaffle.sol:L14-L15`; `untrusted` has 0 hits.
- `untrusted|malicious|adversarial` → 0 hits in production and 0 in the 31 dependencies.
- `allowlist|whitelist|approvedPrize|trustedPrize|extcodehash` → 0 hits in production and 0 in the 31 dependencies. No independent prize-code identity mechanism was found.
- `supportsInterface(` → 1 production hit, the prize self-report at `target/packages/contracts/src/RaffleFactory.sol:L172`; 6 dependency hits are interface/base declarations, implementations, or an example.
- `prize.ownerOf|prizeToken.ownerOf` → 3 production hits: post-escrow at `target/packages/contracts/src/RaffleFactory.sol:L129`, winner delivery at `target/packages/contracts/src/Raffle.sol:L335`, and sponsor return at `target/packages/contracts/src/Raffle.sol:L405`; 0 dependency hits for those receiver-qualified patterns.
- `prize.safeTransferFrom|prizeToken.transferFrom` → 3 production hits: escrow at `target/packages/contracts/src/RaffleFactory.sol:L128`, winner delivery at `target/packages/contracts/src/Raffle.sol:L334`, and sponsor return at `target/packages/contracts/src/Raffle.sol:L404`; 0 dependency hits for those receiver-qualified patterns.
- `onERC721Received(` → 1 production hit (`target/packages/contracts/src/Raffle.sol:L416`) and 6 dependency hits covering the receiver interface and OpenZeppelin callback route.
- `_safeMint(` → 1 production hit (`target/packages/contracts/src/Raffle.sol:L235`) and 3 dependency hits in OpenZeppelin's two overloads and internal call.
- `nonReentrant` → 11 production textual hits: 10 state-changing entrypoint applications and the factory's explanatory comment; 21 dependency hits defining or documenting the guard. The protected entrypoints are factory creation and Raffle purchase, draw request, refund activation, settlement, redemption, ticket refund, both quote releases, and sponsor-prize release (`target/packages/contracts/src/RaffleFactory.sol:L97-L108`; `target/packages/contracts/src/Raffle.sol:L209-L212`, `L240`, `L276`, `L304`, `L309`, `L349`, `L375`, `L385`, `L395`).
- caller searches for `createRaffle(`, `buyEntries(`, `redeemWinningTicket(`, and `releaseSponsorPrize(` → 2 hits each, implementation plus interface declaration only. `_validateCreateParams(` → 2 hits, its sole call and definition. `_isProtocolDestination(` → 6 hits, five calls and its definition.
- `onERC721Received(` caller search → 3 directly represented hits in scope: Raffle's implementation, the receiver-interface declaration, and OpenZeppelin's receiver call. The prize deposit reaches it dynamically through `IERC721.safeTransferFrom`, whose required behavior is only an interface contract for the arbitrary implementation (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol:L42-L73`).

---

**How the verdict was reached:** This is not `implemented` because the `NftWon` split-settlement path allows sponsor and protocol quote proceeds to be released before prize delivery, while both escrow and delivery are accepted through behavior and ownership values self-reported by the arbitrary prize. A prize can pass creation, then revert on delivery after those earlier releases, or return successfully and lie from `ownerOf`; the code itself declares honest prizes as an assumption (`target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`; `target/packages/contracts/src/RaffleFactory.sol:L127-L134`; `target/packages/contracts/src/Raffle.sol:L323-L337`, `L528-L555`).

It is `partial`, rather than wholly `contradicted`, because substantial parts of the quoted boundary do hold: quote and wrapper addresses are fixed and treated as trusted dependencies; the wrapper callback is address-authenticated; ticket-receiver failure/reentry is handled by safe-mint rollback and the guard; creation-time prize reverts roll back creation; direct, not-yet-settled redemption rolls back settlement and burn if delivery fails; and `CashWon` winner payments plus `Refunding` ticket payments do not depend on prize behavior (`target/packages/contracts/src/RaffleFactory.sol:L58-L91`, `L97-L134`; `target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L101-L107`; `target/packages/contracts/src/Raffle.sol:L209-L236`, `L309-L371`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L47`). The failure is branch-specific but reaches the economically central NFT-award branch, so `stronger-than-spec`, `absent`, and `undecidable` do not fit.

---

**Open questions:**

- The target contains no deployment record identifying the actual quote-token and wrapper addresses. Canonical identity therefore remains unverified here, exactly as the factory assigns official-USDC verification to deployment tooling (`target/packages/contracts/src/RaffleFactory.sol:L58-L63`). This does not affect the prize-boundary divergence, which follows from source-visible paths for any configured arbitrary prize.
