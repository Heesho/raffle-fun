# S6 independently derived findings

## S6-01 — High — An adversarial prize contract can fake escrow and delivery

**Evidence.** The factory accepts sponsor-selected code after only a code check and self-reported ERC-165 response (`RaffleFactory.sol:154-177`). It calls that same address’s `safeTransferFrom`, accepts the callback as activation, and asks that same address’s `ownerOf` whether custody succeeded (`RaffleFactory.sol:127-134`; `Raffle.sol:416-430`). Redemption/return again relies on its `transferFrom` and `ownerOf` (`Raffle.sol:329-337,395-406`). Although `IRaffle.sol:12-15` documents honest prizes, DESIGN.md expressly places arbitrary prize contracts outside trust.

**Impact.** A sponsor can deploy a contract that claims ERC-721 support, invokes the expected receiver callback without moving a real asset, and returns whichever owner the protocol expects. The raffle becomes `Active`; buyers can transfer canonical quote tokens into it; and in the NFT branch sponsor/protocol proceeds can be released even though the advertised prize never existed in protocol custody. This is direct buyer loss and a fraudulent-raffle primitive.

**Reproduction.** `test_Evidence_MaliciousPrizeCanFakeEscrowAndDelivery` passes and proves reported owner equals the clone while the mock’s actual owner remains the sponsor. The desired negative property `test_Property_PrizeEscrowRequiresRealRatherThanSelfReportedCustody` fails as expected.

**Recommendation.** Do not present arbitrary token code as trustlessly verified. Restrict prizes to an allowlisted/attested collection registry with explicit governance and code/upgrade policy, or redesign custody around a trusted adapter/vault whose own ledger is authoritative. UI warnings alone do not repair an on-chain trust claim. Delay proceeds until prize delivery does not prove initial custody against a contract that can lie consistently, but can limit loss; couple any such mitigation with the trusted-collection boundary.

## S6-02 — Medium — Prize delivery skips contract-recipient acceptance

**Evidence.** Both winning redemption and sponsor prize return use `prizeToken.transferFrom`, then only query `ownerOf` (`Raffle.sol:329-337,395-406`). Unlike `safeTransferFrom`, this does not invoke `IERC721Receiver` for a contract recipient.

**Impact.** A smart-contract ticket owner can correctly accept the raffle ticket yet be incompatible with the prize collection. Redemption still burns the winning ticket and transfers the prize into the contract without an acceptance callback. The NFT can be permanently inaccessible even though the design requires delivery failure to revert all effects. The same applies to a contract `sponsorRecipient`.

**Reproduction.** `test_Evidence_PrizeTransferSkipsIncompatibleContractReceiverCheck` shows the receiver gets one callback for the safe-minted ticket and zero for the delivered prize, while `ownerOf` nevertheless becomes the incompatible contract.

**Recommendation.** Use `safeTransferFrom(address(this), recipient, tokenId)` on both delivery paths. Keep checks-effects-interactions and `nonReentrant`; a rejected callback will then atomically restore flags, ticket ownership/burn, and prize custody.

## S6-03 — Low — Destination isolation is scoped to one factory

**Evidence.** `_isProtocolDestination` compares local fixed addresses and queries only `canonicalFactory.isRaffle(destination)` (`Raffle.sol:587-604`). Factory creation applies the same local `isRaffle` mapping (`RaffleFactory.sol:154-168`). Nothing recognizes a clone from another deployment of the same protocol.

**Impact.** A ticket or configured payout/prize relationship can target a different factory’s raffle clone, violating “Never move assets between raffle clones.” Because a raffle has no generic execution/rescue function, a transferred ticket or quote payout can be stranded. Exploitation normally requires the asset owner/sponsor to select the bad destination, so severity is low, but the asserted isolation invariant is false.

**Reproduction.** `test_Evidence_CrossFactoryRaffleDestinationIsAcceptedAndStrandsTicket` passes. The desired property `test_Property_AllRaffleClonesAreRejectedDestinations` fails as expected.

**Recommendation.** Define the deployment boundary explicitly. If multiple factories can exist, use a shared canonical registry, a factory-of-factories, or a verifiable protocol-recipient interface/attestation that every deployment consults. If global recognition is impossible, remove the global claim and make cross-deployment sinks explicit in APIs/UI.

## S6-04 — Low — Prize callback can create pre-publication ticket state

**Evidence.** The factory registers the clone, calls sponsor-selected prize code, and emits `RaffleCreated` only afterward (`RaffleFactory.sol:123-147`). The clone becomes `Active` within `onERC721Received` (`Raffle.sol:416-430`). The factory’s reentrancy guard does not protect the distinct clone guard, so prize code can call `buyEntries` after activation and before the factory call returns.

**Impact.** The sponsor-controlled token can preallocate paid entries and influence apparent participation/reserve progress before the canonical creation event is emitted. The purchase remains paid and its event is on-chain, limiting impact, but event consumers that treat `RaffleCreated` as the beginning of activity observe counterintuitive ordering.

**Reproduction.** `test_Evidence_PrizeCanBuyEntriesBeforeCreateRaffleReturns` produces one entry and one ticket from inside the prize transfer.

**Recommendation.** Separate custody confirmation from sale activation. Keep the clone in `AwaitingPrize` through the token callback and let only the factory finalize `Active` after custody checks, then emit publication in a defined order. Alternatively add a factory-only `activate` step after the external transfer.

## S6-05 — Informational/conditional — Quote accounting requires canonical fee-free token identity

**Evidence.** Constructor validation checks code and `decimals()==6` (`RaffleFactory.sol:65-78`). Purchase records the requested gross immediately after `safeTransferFrom` without measuring balance delta (`Raffle.sol:223-233`). Interface documentation states the canonical-USDC assumption (`IRaffle.sol:12-15`).

**Impact.** A fee-on-transfer/rebasing/malicious six-decimal token can make liabilities exceed custody. This is not exploitable under a correctly configured official fee-free USDC deployment, but source alone does not enforce identity.

**Reproduction.** `test_Evidence_FeeOnTransferQuoteCreatesCustodyDeficit` records 10,000,000 while receiving 9,900,000.

**Recommendation.** Pin and independently verify per-chain official token addresses/code in deployment automation and post-deployment assertions. If arbitrary quote tokens are ever supported, account by balance delta and separately address rebasing/callback behavior.

