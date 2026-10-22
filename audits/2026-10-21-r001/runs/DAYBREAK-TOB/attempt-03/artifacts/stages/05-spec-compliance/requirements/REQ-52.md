## REQ-52 — Canonical dependencies and untrusted prize/recipient inputs

> "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted."
> — DESIGN.md:L2, sentence 16

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** The quote token and Chainlink wrapper must be deployment-selected dependencies shared by the raffles, rather than sponsor-selected values that vary at creation. For the supplied checkable condition, a sponsor must be able to provide a prize-contract address without that address first belonging to a trusted prize allowlist; the runtime gate may require the ERC-721 interface and may reject addresses that are protocol plumbing. A ticket recipient likewise remains caller-selected rather than becoming a trusted protocol dependency. This is the concrete meaning checked for the verbatim statement, "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted." (`DESIGN.md:L2`, sentence 16).

---

**Where enforcement lives:**

The factory fixes the quote token and wrapper in immutable fields, validates the constructor-supplied contracts, and deploys one `Raffle` implementation with those same two addresses (`target/packages/contracts/src/RaffleFactory.sol:L32-L42`, `L65-L91`):

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L65-L67, L85-L91
constructor(address quoteToken_, address vrfWrapper_, address protocolTreasury_) {
    _requireContract(quoteToken_);
    _requireContract(vrfWrapper_);
    // ...
    quoteToken = quoteToken_;
    vrfWrapper = vrfWrapper_;
    protocolTreasury = protocolTreasury_;

    address implementation = address(new Raffle(quoteToken_, vrfWrapper_));
    // ...
    raffleImplementation = implementation;
}
```

The implementation stores the quote token as an immutable and passes the validated wrapper into its inherited wrapper-consumer constructor (`target/packages/contracts/src/Raffle.sol:L55-L58`, `L151-L165`). That base constructor stores the wrapper in the immutable `i_vrfV2PlusWrapper` field (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L34-L47`). `RaffleInitParams` contains the sponsor, recipients, prize, reserve, and end time, but contains no per-raffle quote-token or wrapper field (`target/packages/contracts/src/interfaces/IRaffle.sol:L36-L54`). The factory's `Clones.clone` callee builds a minimal proxy whose bytecode delegates to the supplied fixed implementation address (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L24-L62`), so creation has no branch that substitutes either canonical dependency.

Prize selection flows directly from sponsor input. `CreateRaffleParams.prizeToken` is an address supplied to the public creation ABI (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L14-L26`, `L99-L104`). `createRaffle` forwards that address into initialization, casts that same address to `IERC721`, and invokes it to escrow the selected token (`target/packages/contracts/src/RaffleFactory.sol:L97-L128`):

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L97-L98, L109-L120, L127-L128
function createRaffle(CreateRaffleParams calldata params) external override nonReentrant returns (address raffle) {
    _validateCreateParams(params);
    // ...
    IRaffle(raffle).initialize(
        IRaffle.RaffleInitParams({
            // ...
            prizeToken: params.prizeToken,
            prizeTokenId: params.prizeTokenId,
            // ...
        })
    );
    // ...
    IERC721 prize = IERC721(params.prizeToken);
    prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
```

The validator requires deployed code, rejects only known protocol-plumbing destinations, and accepts the prize-interface branch only when the candidate itself reports support for `IERC721`; it reads no trusted identity registry (`target/packages/contracts/src/RaffleFactory.sol:L154-L179`):

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L154-L177
function _validateCreateParams(CreateRaffleParams calldata params) private view {
    _requireContract(params.prizeToken);
    // ...
    if (
        params.prizeToken == address(this) || params.prizeToken == quoteToken || params.prizeToken == vrfWrapper
            || params.prizeToken == raffleImplementation || isRaffle[params.prizeToken]
    ) {
        revert UnsafeProtocolDestination(params.prizeToken);
    }
    // ...
    bool supports721 = false;
    try IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
        supports721 = supported;
    } catch {
        revert UnsupportedPrizeToken(params.prizeToken);
    }
    if (!supports721) revert UnsupportedPrizeToken(params.prizeToken);
    // ...
}
```

The arbitrary prize call is surrounded by observable postconditions rather than an identity allowlist: the raffle receiver accepts only the configured token and token ID, from the configured sponsor, with the factory as operator, while it is awaiting the prize (`target/packages/contracts/src/Raffle.sol:L416-L430`); after the external transfer returns, the factory requires the prize's `ownerOf` report to name the clone and the clone to report `Active` (`target/packages/contracts/src/RaffleFactory.sol:L127-L134`). `createRaffle` is protected by the inherited `nonReentrant` modifier (`target/packages/contracts/src/RaffleFactory.sol:L21`, `L97`), whose callee marks the guard entered before the body and restores it afterward (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`, `L88-L105`).

Ticket recipients are also caller-selected. `buyEntries` accepts an address, rejects zero, and safe-mints the ticket to the supplied recipient (`target/packages/contracts/src/Raffle.sol:L209-L235`). Every mint or inherited transfer dynamically reaches Raffle's `_update` override, which rejects known same-factory protocol destinations and otherwise delegates to the ERC-721 ledger update (`target/packages/contracts/src/Raffle.sol:L491-L502`). The inherited safe-mint callee updates ownership and then checks contract-recipient acceptance (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L269-L290`); its receiver utility skips the callback for a code-less recipient, but for a contract calls `onERC721Received` and requires the selector, bubbling a revert or rejecting an invalid response (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L18-L48`). Thus recipient code is invoked as external, potentially untrusted code rather than used as a canonical dependency.

---

**Paths walked:**

- Factory deployment → `_requireContract(quoteToken_)` / `_requireContract(vrfWrapper_)` → six-decimal quote-token check → immutable assignments → `new Raffle(quoteToken_, vrfWrapper_)`: the two dependency addresses are fixed once, and the implementation receives the same values (`target/packages/contracts/src/RaffleFactory.sol:L58-L91`). ✓
- `Clones.clone(raffleImplementation)` → fixed-target minimal-proxy creation: the only creation call uses the immutable implementation, and the clone library embeds that implementation address in the proxy bytecode (`target/packages/contracts/src/RaffleFactory.sol:L105-L106`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L62`). ✓
- `createRaffle(params)` → `_validateCreateParams(params)`: a candidate with no code reverts; a candidate equal to the factory, quote token, wrapper, implementation, or an existing same-factory raffle reverts; a reverting/false ERC-165 response reverts; every other candidate that reports `IERC721` support proceeds without an identity-list lookup (`target/packages/contracts/src/RaffleFactory.sol:L154-L179`, `L181-L185`). ✓
- `createRaffle(params)` → clone `initialize`: the factory forwards the sponsor's `params.prizeToken`; `initialize` is factory-only and one-time, performs local destination checks, and stores that exact address as `IERC721` (`target/packages/contracts/src/RaffleFactory.sol:L109-L121`; `target/packages/contracts/src/Raffle.sol:L176-L205`). ✓
- `createRaffle(params)` → arbitrary prize `safeTransferFrom` → clone `onERC721Received` → factory postconditions: the callback must carry the exact configured tuple, and returning control is followed by `ownerOf` and `Active` checks (`target/packages/contracts/src/RaffleFactory.sol:L123-L134`; `target/packages/contracts/src/Raffle.sol:L416-L430`). ✓
- `createRaffle` modifier path → `ReentrancyGuard._nonReentrantBefore` → body/external prize calls → `_nonReentrantAfter`: a nested call to the protected creation entrypoint encounters the entered-state check (`target/packages/contracts/src/RaffleFactory.sol:L97`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73`, `L88-L105`). ✓
- `buyEntries(recipient, entryCount)` → nonzero/destination screening → `_safeMint`: an EOA recipient takes the no-code branch with no callback; a contract recipient receives `onERC721Received` and must return the selector (`target/packages/contracts/src/Raffle.sol:L209-L235`, `L497-L502`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L279-L290`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`). ✓
- Inherited ticket `transferFrom` → overridden `_update`: all ordinary transfers retain Raffle's protocol-destination screen (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L125`; `target/packages/contracts/src/Raffle.sol:L497-L502`). Inherited `safeTransferFrom` first takes that transfer path and then invokes receiver acceptance (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L127-L136`). ✓
- Callers of `createRaffle`: the scoped search found only the external implementation and its interface declaration (`target/packages/contracts/src/RaffleFactory.sol:L97`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L104`), so there is no in-scope wrapper that adds a trusted-prize gate. ✓

---

**Searched:**

- Scope coverage → read all five production files and all 31 paths in `target/dependency-hashes.json` in full; the manifest contains exactly 31 entries and all 31 SHA-256 checks returned `OK`.
- `\b(allowlist|allow-list|whitelist|white-list|trustedPrizes?|permittedPrizes?|approvedPrizes?|supportedPrizes?|allowedPrizes?|prizeRegistry|prizeAllowlist)\b` (case-insensitive) across the five production files and 31 pinned dependencies → 0 hits.
- `onlyOwner|hasRole|AccessControl|DEFAULT_ADMIN_ROLE|PRIZE_ROLE|PRIZE_ADMIN` across the same 36 files → 0 hits.
- `mapping...prize|collection...=>` across the same 36 files → 0 prize/collection identity-map hits. The production mappings found are three raffle registry mappings (`target/packages/contracts/src/RaffleFactory.sol:L48-L54`) and the ticket-range mapping (`target/packages/contracts/src/Raffle.sol:L138-L139`), none of which approves prize identities.
- `createRaffle\s*\(` across the same 36 files → exactly 2 hits: implementation at `target/packages/contracts/src/RaffleFactory.sol:L97` and ABI declaration at `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L104`; 0 in-scope callers or wrappers.
- `type(IERC721).interfaceId` across the same 36 files → exactly 2 hits: the creation gate at `target/packages/contracts/src/RaffleFactory.sol:L172` and OpenZeppelin ERC-721's own interface report at `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L47`.
- `params.prizeToken` in `RaffleFactory.sol` and `Raffle.sol` → 23 line hits: validation, propagation, storage, transfer, custody checks, and event fields; the decisive propagation/storage sites are `target/packages/contracts/src/RaffleFactory.sol:L109-L128`, `L154-L177` and `target/packages/contracts/src/Raffle.sol:L181-L205`.
- Prize-token address comparisons → 2 lines in the one protocol-plumbing condition, covering factory, quote token, wrapper, implementation, and registered raffles (`target/packages/contracts/src/RaffleFactory.sol:L158-L159`); no comparison to a curated external prize address was found.
- Recipient enforcement vocabulary (`buyEntries`, `_safeMint`, `_update`, `_isProtocolDestination`, `checkOnERC721Received`, `onERC721Received`) → the caller-selected mint is at `target/packages/contracts/src/Raffle.sol:L209-L235`, the override at `L497-L502`, the inherited safe-mint path at `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L269-L290`, and the receiver branch at `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`.
- Relevant modifiers and bases → `createRaffle` and `buyEntries` both use `nonReentrant` (`target/packages/contracts/src/RaffleFactory.sol:L97`; `target/packages/contracts/src/Raffle.sol:L209-L213`); the modifier and both internal guard branches were read at `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L105`.

---

**How the verdict was reached:** This is `implemented`, not `partial`, because the sole creation entrypoint always takes the same sponsor-supplied `prizeToken` through code-presence, protocol-sink, and ERC-721-interface gates and then uses that address for initialization and escrow (`target/packages/contracts/src/RaffleFactory.sol:L97-L134`, `L154-L179`). The false and reverting interface branches reject nonconforming candidates; the true branch does not consult a trusted identity list (`target/packages/contracts/src/RaffleFactory.sol:L171-L177`). No alternate caller, modifier, base contract, constructor, type bound, or mapping adds such a list. The address exclusions at `RaffleFactory.sol:L158-L159` are a denylist of the protocol's own plumbing, not a curated set of trusted prize contracts, so they do not make the implementation `stronger-than-spec` or contradict the supplied "does not require a trusted prize-contract allowlist" check.

The other halves of the trust boundary align as well: quote token and wrapper are constructor-fixed and absent from per-raffle initialization (`target/packages/contracts/src/RaffleFactory.sol:L32-L42`, `L65-L91`; `target/packages/contracts/src/interfaces/IRaffle.sol:L36-L54`), while ticket recipients remain caller-selected and contract recipients are handled through the ERC-721 receiver callback path (`target/packages/contracts/src/Raffle.sol:L209-L235`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L25-L48`). The code cannot prove that constructor inputs are official deployments: it checks code presence and quote-token decimals, and explicitly assigns official-USDC verification to deployment tooling (`target/packages/contracts/src/RaffleFactory.sol:L58-L78`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L6-L9`). That is consistent with these being trusted canonical dependencies and does not make the supplied no-prize-allowlist condition undecidable.

---

**Open questions:**

- None for the supplied checkable condition. Concrete deployed quote-token/wrapper identity and the behavior of any sponsor-selected prize implementation are outside the frozen source; the source explicitly makes canonical quote-token identity a deployment-tooling responsibility (`target/packages/contracts/src/RaffleFactory.sol:L58-L78`; `target/packages/contracts/src/interfaces/IRaffleFactory.sol:L6-L9`). Those external facts are not needed to establish that raffle creation has no trusted prize-contract allowlist.
