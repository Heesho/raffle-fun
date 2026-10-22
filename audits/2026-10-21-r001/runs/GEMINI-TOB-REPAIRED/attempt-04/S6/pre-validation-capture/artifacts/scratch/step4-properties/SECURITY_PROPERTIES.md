# Step 4: Security Properties & Verification Specification (`raffle-fun`)

**Target Codebase**: `packages/contracts/src/` (`Raffle.sol`, `RaffleFactory.sol`, `interfaces/IRaffle.sol`, `interfaces/IRaffleFactory.sol`, `libraries/RaffleConstants.sol`)
**Compiler Version**: `solc 0.8.36`

---

## 1. State Machine Transitions & Lifecycle Invariants

| ID | Property | Formal / Code Specification | Verified By |
|---|---|---|---|
| **SM-01** | **Implementation Permanent Lock** | On the master implementation contract `raffleImplementation`, `initialized == true` and `status == Status.Refunding` immediately after construction (`Raffle.sol:144-145`). No external function can transition `raffleImplementation` out of `Refunding` or re-initialize it. | `echidna_implementation_locked`, `invariant_ticketRangesAndStatusLifecycle` |
| **SM-02** | **Clone Single-Initialization & Atomic Escrow** | Each ERC-1167 clone starts with `initialized == false`. Only `factory` can call `initialize()` (`Raffle.sol:178`), setting `initialized = true` and `status = Status.AwaitingPrize` (`Raffle.sol:205`). `RaffleFactory.createRaffle()` (`RaffleFactory.sol:128-134`) atomically escrows the prize NFT via `safeTransferFrom`, which triggers `onERC721Received()` (`Raffle.sol:379`) to transition `status` from `AwaitingPrize` to `Active`. If `status != Status.Active` after `safeTransferFrom`, `createRaffle` reverts with `PrizeEscrowVerificationFailed`. | `echidna_status_transitions_valid`, `custom_slither_checks.py` (Check 3 & Check 4) |
| **SM-03** | **Directed Acyclic Status Graph (DAG)** | Valid state transitions for an initialized clone are strictly restricted to: `AwaitingPrize -> Active`, `Active -> Drawing` (via `requestDraw` when `endTime <= block.timestamp <= drawRequestDeadline` and `totalEntries > 0`), `Active -> Refunding` (via `enableRefunds` when `(block.timestamp >= endTime && totalEntries == 0)` or `block.timestamp > drawRequestDeadline`), `Drawing -> NftWon` (via `fulfillRandomWords` when `block.timestamp <= callbackDeadline` and `totalEntries >= reserveEntries`), `Drawing -> CashWon` (via `fulfillRandomWords` when `block.timestamp <= callbackDeadline` and `totalEntries < reserveEntries`), and `Drawing -> Refunding` (via `enableRefunds` when `block.timestamp > callbackDeadline`). `NftWon`, `CashWon`, and `Refunding` are terminal statuses. | `echidna_status_transitions_valid`, `invariant_ticketRangesAndStatusLifecycle` |
| **SM-04** | **VRF Callback Window & Synchronous Callback Guard** | During `requestDraw()`, `_requestInFlight` is set to `true` before calling `requestRandomnessPayInNative` and cleared to `false` after storing `vrfRequestId` (`Raffle.sol:255-260`). `fulfillRandomWords()` (`Raffle.sol:511-518`) ignores any callback (emitting `VrfCallbackIgnored` without reverting) if `_requestInFlight == true`, `status != Status.Drawing`, `requestId != vrfRequestId`, `block.timestamp > callbackDeadline()`, or `randomWords.length == 0`. | `test_protocolDestinationGuardsAndCallbackIgnore`, `custom_slither_checks.py` (Check 1 & Check 3) |

---

## 2. Access Control & Destination Isolation Properties

| ID | Property | Formal / Code Specification | Verified By |
|---|---|---|---|
| **AC-01** | **Initializer Caller Restriction** | `Raffle.initialize()` reverts with `UnauthorizedInitializer(msg.sender)` if `msg.sender != factory` (`Raffle.sol:178`), or `InvalidInitialization()` if `factory == address(0)` or `initialized == true` (`Raffle.sol:177,179`). | `custom_slither_checks.py` (Check 1 & Check 4) |
| **AC-02** | **VRF Fulfillment Caller Restriction** | `rawFulfillRandomWords()` (`VRFV2PlusWrapperConsumerBase.sol:95-99`) reverts with `OnlyVRFWrapperCanFulfill` unless `msg.sender == address(i_vrfV2PlusWrapper)`. | `vars-and-auth` diagram, `custom_slither_checks.py` (Check 1) |
| **AC-03** | **ERC-721 Prize Deposit Restriction** | `Raffle.onERC721Received()` (`Raffle.sol:368-378`) reverts unless `status == Status.AwaitingPrize`, `msg.sender == address(prizeToken)`, `tokenId == prizeTokenId`, `from == sponsor`, and `operator == factory`. | `vars-and-auth` diagram, `custom_slither_checks.py` (Check 3) |
| **AC-04** | **Winning Ticket & Refund Bearer Ownership** | `redeemWinningTicket(ticketId)` (`Raffle.sol:305`) reverts with `NotTicketOwner` unless `_requireOwned(ticketId) == msg.sender` and `_requireWinningTicket(ticketId)` holds. `refundTickets(ticketIds)` (`Raffle.sol:335`) reverts with `NotTicketOwner` unless `_requireOwned(ticketId) == msg.sender` for every ticket in `ticketIds`. | `testFuzz_nftWonSettlementAndClaims`, `testFuzz_cashWonSettlementAndClaims`, `testFuzz_refundPathsAndSponsorPrizeReclaim` |
| **AC-05** | **Protocol Destination Isolation (`_isProtocolDestination`)** | Neither quote tokens, prize NFTs, nor raffle tickets may be assigned or transferred to any protocol destination (`address(this)`, `factory`, `raffleImplementation`, `quoteToken`, `vrfWrapper`, `prizeToken`, or any clone where `factory.isRaffle(dest) == true`). Enforced in `RaffleFactory` constructor (`RaffleFactory.sol:65-72`), `RaffleFactory._validateCreateParams` (`RaffleFactory.sol:164-184`), `Raffle.initialize` (`Raffle.sol:187-195`), `Raffle._update` (`Raffle.sol:498-501`), and `Raffle._transferQuote` (`Raffle.sol:546-548`). | `echidna_no_protocol_destination_holds_tickets`, `test_protocolDestinationGuardsAndCallbackIgnore`, `custom_slither_checks.py` (Check 2) |

---

## 3. Arithmetic Constraints, Solvency & Precision Invariants

| ID | Property | Formal / Code Specification | Verified By |
|---|---|---|---|
| **AR-01** | **Quote Token Solvency Invariant** | At the end of every transaction, `quoteToken.balanceOf(address(raffle)) >= raffle.accountedQuoteBalance()`, where `accountedQuoteBalance() == unsettledPot + remainingRefundLiability + winnerProceeds + sponsorProceeds + protocolFees` (`Raffle.sol:469-476`). | `echidna_quote_solvency`, `invariant_quoteSolvencyAndAccounting` |
| **AR-02** | **Entry & Gross Sales Conservation** | `grossSales() == totalEntries * ENTRY_PRICE` (`1e6`). While `status` is `AwaitingPrize`, `Active`, or `Drawing`, `unsettledPot == grossSales()` and `remainingRefundLiability == 0`. | `echidna_entry_accounting`, `invariant_quoteSolvencyAndAccounting` |
| **AR-03** | **Contiguous 1-Indexed Ticket Ranges** | If `ticketCount == 0`, `totalEntries == 0`. For `ticketCount > 0`, ticket IDs are sequential `1..ticketCount`, `ticketRange(1).startEntry == 1`, `ticketRange(i).endEntry >= ticketRange(i).startEntry`, `ticketRange(i).startEntry == ticketRange(i-1).endEntry + 1` for all `i > 1`, and `ticketRange(ticketCount).endEntry == totalEntries`. | `echidna_ticket_ranges_contiguous`, `invariant_ticketRangesAndStatusLifecycle` |
| **AR-04** | **Exact Settlement Split Conservation** | Once `settlementComplete == true` in `NftWon` or `CashWon`, `unsettledPot == 0`, `remainingRefundLiability == 0`, and `(winnerProceeds + sponsorProceeds + protocolFees) + totalClaimedQuote == grossSales()`. Specifically: in `NftWon`, `protocolFee = (grossSales * 100) / 10_000`, `winnerProceeds = 0`, `sponsorProceeds = grossSales - protocolFee`; in `CashWon`, `protocolFee = (grossSales * 100) / 10_000`, `winnerProceeds = (grossSales * 5_000) / 10_000`, `sponsorProceeds = grossSales - protocolFee - winnerProceeds` (`Raffle.sol:400-416`). Dust is never lost or trapped. | `echidna_settlement_conservation`, `testFuzz_nftWonSettlementAndClaims`, `testFuzz_cashWonSettlementAndClaims` |
| **AR-05** | **Refund Liability Conservation** | When `status == Status.Refunding`, `unsettledPot == 0` and `remainingRefundLiability + totalRefundedQuote == grossSales()`. Each burned ticket `i` refunds `(endEntry - startEntry + 1) * ENTRY_PRICE` and decrements `remainingRefundLiability` by that exact amount (`Raffle.sol:338-341`). | `echidna_refund_liability_conservation`, `testFuzz_refundPathsAndSponsorPrizeReclaim` |
| **AR-06** | **Winning Entry Bounds & Ticket Inclusion** | Upon VRF fulfillment, `winningEntry = uint128((randomWords[0] % totalEntries) + 1)` (`1 <= winningEntry <= totalEntries`). When `settlementComplete == true`, `1 <= winningTicketId <= ticketCount` and `ticketRange(winningTicketId).startEntry <= winningEntry <= ticketRange(winningTicketId).endEntry`. | `echidna_winning_ticket_bounds`, `testFuzz_nftWonSettlementAndClaims` |

---

## 4. External Interaction Safety Properties

| ID | Property | Formal / Code Specification | Verified By |
|---|---|---|---|
| **EX-01** | **Reentrancy Protection Across All External State-Modifying Flows** | All 9 user-callable state-modifying functions in `Raffle` (`buyEntries`, `requestDraw`, `enableRefunds`, `settleWinningTicket`, `redeemWinningTicket`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`) and `RaffleFactory.createRaffle` use OpenZeppelin `nonReentrant`. | `custom_slither_checks.py` (Check 1) |
| **EX-02** | **Non-Callback ERC-721 Prize Delivery Verification** | Outbound prize transfers (`redeemWinningTicket` at `Raffle.sol:313-315` and `releaseSponsorPrize` at `Raffle.sol:362-364`) use `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` (not `safeTransferFrom`) followed by `if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient)`, preventing untrusted `onERC721Received` callback griefing or reentrancy while verifying ownership change. | `testFuzz_nftWonSettlementAndClaims`, `testFuzz_cashWonSettlementAndClaims` |
| **EX-03** | **Returnbomb-Safe Native Fee Refund in `requestDraw`** | In `Raffle.requestDraw()` (`Raffle.sol:264-270`), any excess `msg.value - requestPrice` is returned via inline assembly `call(gas(), refundRecipient, excess, 0, 0, 0, 0)` with `outsize = 0`, preventing a malicious contract caller from returnbombing the transaction with megabytes of returndata. | Manual Review & Step 1 Slither `assembly` verification |
| **EX-04** | **Pull-Over-Push Claim Isolation** | Winner redemption (`redeemWinningTicket`), sponsor proceeds (`releaseSponsorProceeds`), protocol fees (`releaseProtocolFees`), and sponsor prize recovery (`releaseSponsorPrize`) are independent pull-style actions so that a revert or blacklisting on one recipient never blocks any other party's claim. | `testFuzz_nftWonSettlementAndClaims`, `testFuzz_cashWonSettlementAndClaims` |

---

## 5. Standards Conformance Properties

| ID | Property | Formal / Code Specification | Verified By |
|---|---|---|---|
| **SC-01** | **ERC-721 & ERC-165 Conformance** | `Raffle` conforms to EIP-721 (`IERC721`, `IERC721Metadata`) and EIP-165 (`IERC165`), overriding `name()` and `symbol()` as `pure` functions so ERC-1167 clones return valid metadata (`"raffle.fun Ticket"`, `"RAFFLE"`), and implements `IERC721Receiver` to accept the escrowed prize NFT. | Step 2 `slither-check-erc` (`erc721` & `erc165`) |
| **SC-02** | **Factory Registry Bijection** | For every `id` in `1..factory.raffleCount()`, `raffle = factory.raffleById(id)` is a non-zero deployed clone address satisfying `factory.isRaffle(raffle) == true` and `factory.idByRaffle(raffle) == id`. | `echidna_factory_registry_bijection`, `invariant_ticketRangesAndStatusLifecycle` |
