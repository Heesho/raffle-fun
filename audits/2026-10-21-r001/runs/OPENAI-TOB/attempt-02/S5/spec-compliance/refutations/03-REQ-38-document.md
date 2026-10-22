## REQ-38 — Document-focused refutation review

> "Never move assets between raffle clones."
> — `target/DESIGN.md:L2`

**Verdict:** partial · confidence: high

**Refutation result:** Not refuted. No correction or revised verdict is warranted.

Reviewed the complete specification, the explicitly supplied analysis at `audit/S5/spec-compliance/requirements/03-REQ-38.md`, and the source excerpts cited below. This is a static review; no tests, compilation, behavior-generating tools, chain calls, or network research were used.

---

**What this demands of an implementation:** The instruction "Never move assets between raffle clones." (`target/DESIGN.md:L2`) applies to a protocol-initiated transfer of an escrowed prize from one existing clone to another existing clone. The counterexample needs only two clones from the same factory, not an interpretation extending the requirement to unrelated deployments.

The complete document supplies no qualification that defeats that reading:

- **Force and scope:** "Never move assets between raffle clones." is an independent imperative in the specification's substantive paragraph (`target/DESIGN.md:L2`). It is not presented as a recommendation, roadmap item, example, or initialization-only rule. The preceding sentence, "Sponsor and treasury can claim independently after settlement.", does not grammatically restrict the following prohibition to quote proceeds or settlement (`target/DESIGN.md:L2`).
- **Prize returns:** "Exactly one ERC721 prize is escrowed atomically at creation." and "Refund outcome pays 100% per entry and returns prize." explicitly place the prize and its return within the described system (`target/DESIGN.md:L2`). Neither sentence exempts a returned NFT from "Never move assets between raffle clones." The interface's "Returns the escrowed prize to the immutable sponsor recipient after `CashWon` or `Refunding`." likewise specifies the return destination without granting an exception for clone recipients (`target/packages/contracts/src/interfaces/IRaffle.sol:L354`).
- **Immutable recipient:** "Immutable recipient of sponsor quote proceeds and any returned prize." describes the configured recipient (`target/packages/contracts/src/interfaces/IRaffleFactory.sol:L15`). It does not say an address without code can never subsequently contain a clone, or that recipient screening at creation fulfills the lifetime prohibition. The relevant implementation stores an address (`target/packages/contracts/src/Raffle.sol:L193-L198`) and separately registers later clones (`target/packages/contracts/src/RaffleFactory.sol:L105-L125`).
- **Trust restrictions:** "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted." (`target/DESIGN.md:L2`) does not authorize cross-clone prize transfers. Even the narrower interface premise, "Supported prizes are honest, standards-compliant ERC-721s." (`target/packages/contracts/src/interfaces/IRaffle.sol:L14-L15`, with the NatSpec line break removed), does not defeat this sequence: the supplied ERC-721 `transferFrom` updates ownership without a receiver callback; the callback is added by `safeTransferFrom` (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135,L216-L244`).
- **Forced deposits:** "Unrelated NFTs forced here with unsafe `transferFrom` remain outside protocol accounting and cannot be rescued." (`target/packages/contracts/src/Raffle.sol:L410-L411`, with the NatSpec line break removed) concerns unsolicited assets at the receiver. It does not exempt a sending raffle's configured prize: `releaseSponsorPrize` explicitly transfers its stored `prizeToken` and `prizeTokenId` from itself (`target/packages/contracts/src/Raffle.sol:L402-L405`).
- **Actual versus intended behavior:** "Source, not design prose, determines actual behavior." (`target/DESIGN.md:L4`) identifies how actual behavior is established. It does not withdraw the separate design instruction "Never move assets between raffle clones." (`target/DESIGN.md:L2`).

---

**Where enforcement lives:**

The factory rejects an already registered clone as sponsor recipient, and initialization checks and stores the recipient (`target/packages/contracts/src/RaffleFactory.sol:L154-L169`; `target/packages/contracts/src/Raffle.sol:L181-L199`). The initialization helper consults the registry only when the destination has code (`target/packages/contracts/src/Raffle.sol:L593-L605`).

Runtime checks exist for ticket ownership updates and outgoing quote transfers (`target/packages/contracts/src/Raffle.sol:L497-L502,L564-L567`). Sponsor prize release instead performs:

```solidity
// target/packages/contracts/src/Raffle.sol:L402-L405
address recipient = sponsorRecipient;
prizeClaimed = true;
prizeToken.transferFrom(address(this), recipient, prizeTokenId);
if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient);
```

Its preceding checks concern the raffle status and whether the prize was already claimed, not current recipient identity (`target/packages/contracts/src/Raffle.sol:L395-L400`). The reentrancy modifier checks and updates its guard flag, not the destination (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73,L88-L118`).

---

**Paths walked:**

1. **Configure a future sibling recipient.** Factory creation uses `Clones.clone`, whose implementation uses `CREATE` (`target/packages/contracts/src/RaffleFactory.sol:L105-L106`; `target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L33,L47-L61`). The future-address choice in the supplied analysis follows statically from that deployment mechanism. A nonzero future sibling address, distinct from the fixed forbidden addresses and not yet registered or deployed, passes the recipient checks and is stored in clone A (`target/packages/contracts/src/RaffleFactory.sol:L154-L169`; `target/packages/contracts/src/Raffle.sol:L181-L199,L598-L604`).
2. **Create and register sibling B.** The same creation path initializes each new clone, registers it, deposits its own prize, and verifies active status (`target/packages/contracts/src/RaffleFactory.sol:L97-L134`; `target/packages/contracts/src/Raffle.sol:L416-L430`). Creating B does not revalidate A's previously stored recipient (`target/packages/contracts/src/RaffleFactory.sol:L97-L148`).
3. **Open refunds on empty A.** With A active and no entries sold, its sponsor can enable refunds before sale end; this path sets `Refunding` (`target/packages/contracts/src/Raffle.sol:L276-L300`). This is also expressly described by "Also closes an empty raffle immediately for the sponsor and after sale end for anyone." (`target/packages/contracts/src/interfaces/IRaffle.sol:L323`).
4. **Release A's prize to B.** `Refunding` permits `releaseSponsorPrize`; it transfers to the stored address and checks that address became owner, without registry revalidation (`target/packages/contracts/src/Raffle.sol:L395-L407`). Ordinary supplied ERC-721 transfer semantics do not invoke B's receiver restrictions on this plain `transferFrom` (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L135,L216-L244`; receiver restrictions: `target/packages/contracts/src/Raffle.sol:L416-L430`). Both clones exist when the NFT moves.
5. **Compare protected paths.** Sponsor quote proceeds reach the current destination check through `_transferQuote`; ticket ownership changes also check the current destination (`target/packages/contracts/src/Raffle.sol:L375-L381,L497-L502,L564-L567,L598-L604`). This supports retaining `partial` rather than `absent`.

---

**Searched:**

- Read all of `target/DESIGN.md:L1-L4`. Searched `never|between|clone|asset|refund|trust|source|scope|except|only|should|recommend|future` case-insensitively in that file: matches occur on L2 and L4, with no separate scope or exception clause.
- Inventoried Markdown outside dependencies, tests, and audit/report directories using `rg --files`: the result was `target/DESIGN.md`.
- Searched `_isProtocolDestination|_transferQuote|isRaffle|sponsorRecipient =` in `Raffle.sol` and `RaffleFactory.sol`: five destination-check call sites, four quote-helper callers, the sponsor-recipient assignment, and factory registry checks/write. None is a destination-check call in `releaseSponsorPrize` (`target/packages/contracts/src/Raffle.sol:L187,L190,L193,L198,L342,L369,L380,L390,L498,L565,L603`; `target/packages/contracts/src/RaffleFactory.sol:L54,L125,L159,L166`).
- Searched `supported prizes|standards-compliant|immutable recipient|known protocol|same-factory|code-less|unrelated NFTs|rescued|returns the escrowed prize|also closes an empty` across both implementations and their interfaces. Read the surrounding recipient, prize support, lifecycle, factory registration, transfer, and receiver text cited above. These passages supply no exception for a configured recipient that becomes a sibling clone before release.
- Read the relevant bundled `Clones`, `ERC721`, and `ReentrancyGuard` source paths cited above. The source confirms the deployment mechanism and does not supply a receiver callback or recipient check that would close sponsor prize release.

---

**How the verdict was reached:** The document's unqualified prohibition covers the claimed same-factory NFT transfer. The refund/prize-return provisions, immutable-recipient description, and trust assumptions do not narrow it away. There is enforcement on configuration, quote-transfer, and ticket-update paths, while sponsor prize release omits current destination screening (`target/packages/contracts/src/RaffleFactory.sol:L154-L169`; `target/packages/contracts/src/Raffle.sol:L193-L198,L395-L407,L497-L502,L564-L567`). This is the specific uncovered path alongside enforced paths represented by `partial`; neither refutation nor recategorization is justified.

---

**Open questions:** No unresolved documentary ambiguity affects this result. This review does not establish that any deployed raffle executed the sequence or determine a concrete future deployment address. It relies on static source behavior and the permitted ordinary ERC-721 transfer semantics cited above, not a runtime reproduction. Cross-factory coverage is unnecessary to this counterexample and was not adjudicated.
