## REQ-38 — Prize return can move an NFT into a later-created raffle clone

> "Never move assets between raffle clones."
> — `target/DESIGN.md:L2`

**Verdict:** partial · confidence: high

**What this demands of an implementation:** A protocol operation must not transfer an asset from one raffle clone into another. The retained behavior concerns two clones of the same canonical factory, so it does not depend on interpreting this sentence across different factory deployments.

**Undocumented behavior:** A sponsor can select the address of a future clone B as clone A's `sponsorRecipient`. Initialization accepts the address while B is undeployed and unregistered. After B is created, anyone can return A's prize into B through `releaseSponsorPrize` once A is `Refunding` or `CashWon`. That function neither rechecks the destination registry nor requests ERC-721 receiver acceptance. With B configured for a different prize, A's NFT has no recovery path through either raffle. The checks, reachable transition, transfer, and recovery limitations are cited below.

---

**Where enforcement lives:**

Creation checks only the registry's current contents:

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L163-L169
if (
    params.sponsorRecipient == address(this) || params.sponsorRecipient == quoteToken
        || params.sponsorRecipient == vrfWrapper || params.sponsorRecipient == params.prizeToken
        || params.sponsorRecipient == raffleImplementation || isRaffle[params.sponsorRecipient]
) {
    revert UnsafeProtocolDestination(params.sponsorRecipient);
}
```

`createRaffle` invokes this validation at `target/packages/contracts/src/RaffleFactory.sol:L97-L98`, creates a clone at L105-L106, initializes it at L109-L121, and records its registry membership at L123-L125. The initialization separately checks `sponsorRecipient` and then stores it at `target/packages/contracts/src/Raffle.sol:L193-L198`.

The clone's destination helper rejects itself, fixed dependencies, the prize contract, the implementation, and currently registered clones with deployed code:

```solidity
// target/packages/contracts/src/Raffle.sol:L598-L604
IRaffleFactory canonicalFactory = IRaffleFactory(factory);
unsafeDestination = destination == address(this) || destination == factory || destination == address(quoteToken)
    || destination == address(i_vrfV2PlusWrapper) || destination == prizeToken_
    || destination == canonicalFactory.raffleImplementation();
if (!unsafeDestination && destination.code.length != 0) {
    unsafeDestination = canonicalFactory.isRaffle(destination);
}
```

Runtime ticket updates invoke this helper for nonzero recipients (`target/packages/contracts/src/Raffle.sol:L497-L502`). All four quote-payment paths invoke `_transferQuote`, which also invokes it (`target/packages/contracts/src/Raffle.sol:L342,L369,L380,L390,L564-L567`). These paths provide actual protection against already registered same-factory clones.

Prize return has no equivalent runtime check:

```solidity
// target/packages/contracts/src/Raffle.sol:L395-L407
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

The entire function has no caller-authorization check. Its modifier checks and updates a reentrancy storage slot, not destination membership (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73,L88-L105,L112-L118`; slot accessor at `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol:L93-L97`).

---

**Paths walked:**

1. **Choose an undeployed future clone address.** The factory uses `Clones.clone(raffleImplementation)` (`target/packages/contracts/src/RaffleFactory.sol:L105-L106`). The invoked library overload uses EVM `CREATE`, with no sponsor-controlled salt or deployment arguments affecting the address (`target/packages/contracts/node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L34,L47-L61`). Under ordinary EVM `CREATE` address derivation, a sponsor can precompute the address B of a subsequent factory deployment. This is a static inference from the deployment opcode; no address was computed or deployment executed in this review.
2. **Create A with B as its sponsor recipient.** Choose B distinct from A and all fixed excluded addresses. While B is undeployed, its current registry membership is false, and the clone helper skips the registry query because its code length is zero. Both validation layers therefore accept it (`target/packages/contracts/src/RaffleFactory.sol:L154-L169`; `target/packages/contracts/src/Raffle.sol:L181-L205,L598-L604`). The factory escrows A's ordinary supported NFT and checks ownership and active status (`target/packages/contracts/src/RaffleFactory.sol:L127-L134`).
3. **Create B with a different prize and an ordinary recipient.** A later successful `createRaffle` deploys and registers B. No check in this path looks for B appearing in an older raffle's stored sponsor-recipient field (`target/packages/contracts/src/RaffleFactory.sol:L97-L148,L154-L179`). B stores its own prize contract and ID (`target/packages/contracts/src/Raffle.sol:L197-L205`). The two prize configurations can be different token IDs in one ordinary ERC-721 collection.
4. **Enter the release state without a draw.** Keep A empty. Its sponsor may invoke `enableRefunds` before sale end because the empty-raffle branch rejects an early caller only when `msg.sender != sponsor`; the function then sets `Refunding` (`target/packages/contracts/src/Raffle.sol:L276-L300`). Alternatively, anyone can close that empty raffle at sale end. No paid entries, random outcome, callback, or settlement is needed for this path.
5. **Return A's prize to B.** Any caller invokes A's `releaseSponsorPrize`. B's now-true registry membership is never queried. The NFT is transferred from A to B, `prizeClaimed` is set, and the owner check succeeds for a normally transferring NFT (`target/packages/contracts/src/Raffle.sol:L395-L407`). The ordinary ERC-721 implementation's `transferFrom` changes ownership without a receiver call; only the safe-transfer overload invokes that check (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L136,L216-L244`). Thus B's exact-prize-only receiver cannot reject this transfer (`target/packages/contracts/src/Raffle.sol:L416-L430`).
6. **Check recovery through both clones.** A rejects another prize return after `prizeClaimed` is set (`target/packages/contracts/src/Raffle.sol:L400-L404`). B's prize-redemption and sponsor-return functions operate only on B's configured prize ID (`target/packages/contracts/src/Raffle.sol:L329-L337,L395-L405`), which differs from A's prize. The complete raffle function inventory has no external arbitrary-NFT transfer, approval, rescue, or configuration setter (`target/packages/contracts/src/Raffle.sol:L155-L613`). Its inherited ERC-721 approvals and transfers change the raffle's own ticket ownership/approval mappings, not the external prize collection (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L28-L34,L93-L136,L216-L244,L383-L417`). The inherited VRF base adds request/callback handling and balance/token getters, with no asset rescue entrypoint (`target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol:L31-L118`). A's NFT consequently cannot be recovered through either raffle's exposed API.
7. **Check the otherwise similar quote path.** If A instead has sponsor quote proceeds, `releaseSponsorProceeds` routes through `_transferQuote`; that helper sees registered B and reverts (`target/packages/contracts/src/Raffle.sol:L375-L381,L564-L567,L598-L604`). This runtime guard does not protect `releaseSponsorPrize`.

---

**Searched:**

All commands were local source searches. Paths in the following list are relative to the execution root.

- `rg -n -i 'future|predict|counterfactual|predeploy|undeploy'` over `target/DESIGN.md`, `target/packages/contracts/src/Raffle.sol`, `target/packages/contracts/src/RaffleFactory.sol`, `target/packages/contracts/src/interfaces/IRaffle.sol`, `target/packages/contracts/src/interfaces/IRaffleFactory.sol`, and `target/packages/contracts/src/libraries/RaffleConstants.sol`: **0 hits** (exit status 1). Those six documents were also read in full, including implementation NatSpec.
- `rg -n -i 'future|predict|counterfactual|predeploy|undeploy|code.less|same.factory|cross.factory|between raffle|protocol destination|protocol sink|protocol plumbing|unsafe|rescue|sponsorRecipient|releaseSponsorPrize|transferFrom|receiver'` over the same six files: relevant documentation includes the no-cross-clone sentence (`DESIGN.md:L2`), immutable recipient and prize-return descriptions (`IRaffle.sol:L38,L354-L355`), known-plumbing errors (`IRaffle.sol:L225-L227,L266-L268`; `IRaffleFactory.sol:L89-L91`), and the helper's explicit same-factory/code-less scope (`Raffle.sol:L587-L592`). No hit describes a protocol prize return becoming a cross-clone transfer after later deployment.
- `rg -n 'isRaffle|_isProtocolDestination|_transferQuote|releaseSponsorPrize|prizeToken\.(transferFrom|safeTransferFrom)|sponsorRecipient\s*='` over the two implementation files: registry writes at `RaffleFactory.sol:L125`; creation checks at L159,L166; clone initialization checks at `Raffle.sol:L187,L190,L193`; recipient assignment at L198; runtime helper use at L498,L565; both NFT sends at L334,L404 bypass that helper. All returned call sites were read with their enclosing functions.
- `rg -n -i 'rescue|recover|withdraw|sweep|approve|setApproval|delegatecall|selfdestruct|upgrade|setSponsor|changeRecipient|setRecipient|fallback'` over the two implementation files and `VRFV2PlusWrapperConsumerBase.sol`: only the no-rescue/no-upgrade comments at `RaffleFactory.sol:L19` and `Raffle.sol:L24-L25,L411` matched. Inherited ticket approval/transfer functions were separately read in `ERC721.sol:L93-L136,L383-L417` to check whether they could recover an external prize; they cannot.
- Entrypoint/asset-call inventory: `rg -n 'function |constructor\(|receive\(|fallback\(|modifier |transferFrom|safeTransfer|_safeMint|_burn|\.call|call\(|delegatecall|selfdestruct|create\('` over both implementation files, `VRFV2PlusWrapperConsumerBase.sol`, and `ERC721.sol`. It exposes `releaseSponsorPrize` directly at `Raffle.sol:L395`; there is no wrapper or caller that supplies a missing destination check before an external caller reaches it. The only modifier is the storage reentrancy guard described above.

---

**How the verdict was reached:**

This is `partial` because creation, ticket updates, and quote payouts reject existing same-factory protocol destinations, but prize return can transfer to a recipient that becomes a registered clone after the creation checks (`target/packages/contracts/src/RaffleFactory.sol:L163-L169`; `target/packages/contracts/src/Raffle.sol:L193-L198,L395-L407,L497-L502,L564-L567`). It is not an absence of all isolation controls.

The documentation expressly says:

> "Returns the escrowed prize to the immutable sponsor recipient after `CashWon` or `Refunding`."
> — `target/packages/contracts/src/interfaces/IRaffle.sol:L354`

> "Identifies same-factory protocol plumbing that cannot safely own a ticket or receive a payout."
> — `target/packages/contracts/src/Raffle.sol:L587`

> "Unrelated NFTs forced here with unsafe `transferFrom` remain outside protocol accounting and cannot be rescued."
> — `target/packages/contracts/src/Raffle.sol:L410-L411` (comment wrapping removed)

The last passage documents what happens to an unsolicited NFT at the receiving clone. It does not disclose that a canonical protocol prize-release operation can itself create that condition, contrary to the quoted design rule. The finding is that protocol-generated cross-clone transfer, not the already documented lack of rescue for arbitrary unsolicited NFTs.

The setup is sponsor-controlled and the final release is permissionless (`target/packages/contracts/src/RaffleFactory.sol:L97-L121`; `target/packages/contracts/src/Raffle.sol:L395-L407`). This does not establish a way for an unrelated caller to replace an existing raffle's recipient or steal its NFT. The demonstrated consequence is loss of recovery through the raffle APIs for the prize deliberately routed to the later clone.

---

**Open questions:**

- No runtime test, deployment, address calculation, or chain call was performed. The evidence is source-level path reasoning under ordinary EVM `CREATE` semantics and the documented supported-prize assumption: "Supported prizes are honest, standards-compliant ERC-721s." (`target/packages/contracts/src/interfaces/IRaffle.sol:L14-L15`, comment wrapping removed).
- No actual deployment addresses or affected live raffle are established by the supplied source.
- External collection-specific administrative recovery is not assessed. The loss-of-recovery conclusion is limited to the two raffle APIs.
