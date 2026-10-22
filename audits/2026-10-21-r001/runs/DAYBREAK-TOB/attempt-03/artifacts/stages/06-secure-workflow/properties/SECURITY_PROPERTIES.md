# S6 project-specific security properties

Scope: frozen source commit `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`, evaluated only in the isolated S6 runtime. “Pass” means the property held for the stated test/model; it is not a proof over an absent external implementation. “Fail” means the frozen source admitted a concrete counterexample. “Conditional” identifies a property that depends on a documented deployment assumption.

## Lifecycle, timing, and callback properties

| ID | Property | Check | Result |
|---|---|---|---|
| LIF-01 | A clone can be initialized exactly once and only by its immutable factory. | `test_InitializationIsFactoryOnlyAndOneTime`; manual review of `Raffle.sol:176-205`. | Pass. |
| LIF-02 | The shared implementation is locked and inert in `Refunding`; a successful clone initialization ends in `AwaitingPrize`. | Same unit test; constructor and initializer review at `Raffle.sol:155-166,176-205`. | Pass. |
| LIF-03 | Only the exact configured prize transfer tuple can activate `AwaitingPrize -> Active`. | `test_PrizeWithoutReceiverCallbackIsRejectedAtomically`; callback review at `Raffle.sol:416-430`. | Pass for callback tuple and atomic rollback. |
| LIF-04 | Activation implies genuine persistent custody of the prize rather than only sponsor-selected contract assertions. | `test_Evidence_MaliciousPrizeCanFakeEscrowAndDelivery`; negative property `test_Property_PrizeEscrowRequiresRealRatherThanSelfReportedCustody`. | **Fail:** an adversarial ERC-721 can invoke the expected callback and lie through `ownerOf`. |
| LIF-05 | Purchases are possible only while `Active` and strictly before `endTime`. | `test_SaleAndDrawRequestTimeBoundaries`; `Raffle.sol:215-216`. | Pass. |
| LIF-06 | A sold raffle can request a draw only in `[endTime,endTime+2 days)` and an empty raffle cannot request. | Boundary unit test plus manual review of `Raffle.sol:240-260,458-460`. | Pass. |
| LIF-07 | A callback is accepted only from the immutable wrapper, for the stored request, with exactly one word, while `Drawing`, not in-flight, and strictly before the callback deadline. | `test_SynchronousWrongShapeWrongIdAndDuplicateCallbacksAreContained`, `test_CallbackDeadlineIsExclusiveAndRefundOpensAtBoundary`; inherited gateway at `VRFV2PlusWrapperConsumerBase.sol:101-107`. | Pass under the configured-wrapper identity assumption. |
| LIF-08 | Refunds become available at, not before, the applicable exclusive deadline; a late callback cannot resolve after that point. | Both timing tests; `Raffle.sol:276-300,509-523`. | Pass. |
| LIF-09 | Once a callback chooses `NftWon` or `CashWon`, wrong/duplicate callbacks cannot rewrite the result. | Callback containment test and source state gate. | Pass. |

## Authorization and claim properties

| ID | Property | Check | Result |
|---|---|---|---|
| AUTH-01 | Only the current winning-ticket owner can redeem; settlement cannot redirect the claim. | `test_CurrentOwnerAuthorizationAndPermissionlessFixedDestinationClaims`; `Raffle.sol:304-345`. | Pass. |
| AUTH-02 | ERC-721 owners and approved operators, and no others, control ticket transfer/approval. | `test_ERC721RuntimeConformanceOnClone`; OpenZeppelin authorization review. | Pass. |
| AUTH-03 | Any keeper may settle or release allocated proceeds, but sponsor and protocol funds always go to immutable destinations. | Current-owner/fixed-destination test; `Raffle.sol:375-406`. | Pass, subject to destination safety findings DST-02 and PRIZE-03. |
| AUTH-04 | Only the immutable VRF wrapper reaches the internal callback. | Wrong-caller portion of the callback containment test; base source at lines 101-107. | Pass for address authentication; wrapper correctness remains external. |
| AUTH-05 | Only the sponsor may cancel an empty active raffle before sale end; after deadlines transitions are permissionless. | Manual control-flow review of `Raffle.sol:276-300` and timing tests for permissionless deadline paths. | Pass. |

## Accounting, fees, and range properties

| ID | Property | Check | Result |
|---|---|---|---|
| ACC-01 | Every successful purchase creates one positive, sequential, disjoint range; all ranges partition `1..totalEntries`. | 10,000-run Foundry fuzz test; 256×128-call Foundry invariant; 20,007-call Echidna campaign. | Pass for generated sequences. |
| ACC-02 | During active sales, `unsettledPot == grossSales == totalEntries * ENTRY_PRICE == accountedQuoteBalance`. | Fuzz, Foundry invariant, and Echidna property. | Pass. |
| ACC-03 | With the canonical fee-free quote-token model, actual raffle custody equals recorded liability. | Fuzz, Foundry invariant, and Echidna property using the standard mock. | Pass under the canonical-token assumption. |
| ACC-04 | Refund activation moves the entire unsettled pot into refund liability, and each burned ticket consumes exactly its range length times entry price. | `test_RefundsBurnTicketsAndConserveFullPot`. | Pass. |
| ACC-05 | Terminal settlement replaces the full pot with winner/sponsor/protocol buckets whose sum equals gross, without transferring assets. | NFT and cash settlement tests; `Raffle.sol:533-557`. | Pass. |
| ACC-06 | Reachable fee arithmetic is exact: protocol receives 50,000 raw units per entry; cash winner receives 800,000; sponsor receives the remainder. | 10,000-run pure fuzz test across `uint128` entries and both result branches. | Pass. Because every gross pot is a multiple of 1,000,000, no reachable rounding dust exists. |
| ACC-07 | Claim paths clear the corresponding bucket/flag before an external transfer, and a failed transfer reverts the entire change. | Source CEI review and atomic-revert recipient/token tests. | Pass for honest/standard tokens; malicious prize truthfulness remains failed under PRIZE-02. |
| ACC-08 | Merely returning success from a six-decimal quote token must imply the exact requested balance delta. | `test_Evidence_FeeOnTransferQuoteCreatesCustodyDeficit`. | **Conditional failure:** a 1% fee token records 10,000,000 liability while receiving 9,900,000. Deployment must enforce official fee-free USDC identity. |
| ACC-09 | Active sales have no terminal/refund liabilities or completion flags. | 256×128-call Foundry invariant and Echidna property. | Pass. |

## Ticket ownership, burn, and ERC-721 properties

| ID | Property | Check | Result |
|---|---|---|---|
| TKT-01 | Safe mint to an incompatible contract recipient reverts payment, range, count, liability, and ownership atomically. | `test_IncompatibleTicketRecipientRevertsPurchaseAtomically`. | Pass. |
| TKT-02 | Redemption/refund burns the bearer ticket exactly when its associated claim is consumed. | NFT/cash redemption and refund tests. | Pass. |
| TKT-03 | Historical range data remains available after burns but cannot independently authorize another claim. | Manual review of `_ticketRanges`, current-owner checks, one-time flags, and mutually exclusive states. | Pass. |
| ERC-01 | `Raffle` exposes the required ERC-721 functions, return types, mutability, events, and indexed fields. | Actual `slither-check-erc . Raffle --erc ERC721`. | Pass. |
| ERC-02 | A deployed clone reports ERC-165/ERC-721/metadata support and performs approval, transfer, balance, ownership, and safe-receiver rollback correctly. | `test_ERC721RuntimeConformanceOnClone`. | Pass. |

## Reentrancy and external-call properties

| ID | Property | Check | Result |
|---|---|---|---|
| RE-01 | Quote-token and ticket-receiver callbacks cannot reenter the protected purchase path. | `test_TicketReceiverAndQuoteCallbacksCannotReenterProtectedPurchase`. | Pass. |
| RE-02 | A synchronous VRF callback cannot resolve before the returned request ID is persisted. | Synchronous callback portion of callback containment test. | Pass; callback is ignored while `_requestInFlight` is true. |
| RE-03 | A sponsor-selected prize cannot mutate the newly active clone before `createRaffle` returns and publishes `RaffleCreated`. | `test_Evidence_PrizeCanBuyEntriesBeforeCreateRaffleReturns`. | **Fail:** the prize callback can buy a ticket after activation but before the factory’s post-transfer checks/event. |
| RE-04 | All bounded ticket-refund iterations avoid external calls until the single aggregate quote payout after the loop. | Slither `calls-loop` findings and source review. | Pass. Both reported call paths are infeasible during `_burn`: `to == address(0)` short-circuits the entire `_isProtocolDestination` invocation at `Raffle.sol:498`. |

## Prize, recipient, and destination-isolation properties

| ID | Property | Check | Result |
|---|---|---|---|
| PRIZE-01 | A prize implementation that does not execute the required receiver callback cannot create a raffle, and all creation state rolls back. | `test_PrizeWithoutReceiverCallbackIsRejectedAtomically`. | Pass. |
| PRIZE-02 | Arbitrary sponsor-selected prize code cannot fake escrow or delivery using self-reported ERC-165/callback/`ownerOf` behavior. | Malicious-prize reproduction and negative property campaign. | **Fail.** This violates the DESIGN.md untrusted-prize boundary and is the highest-priority result. |
| PRIZE-03 | Delivery to a contract winner/sponsor recipient checks ERC-721 receiver acceptance and reverts on incompatibility. | `test_Evidence_PrizeTransferSkipsIncompatibleContractReceiverCheck`; `Raffle.sol:329-337,395-406`. | **Fail:** both paths use `transferFrom`, so a contract can receive and strand the prize without a callback. |
| DST-01 | The raffle rejects itself, its factory, implementation, local registered raffles, quote token, wrapper, and prize token as ticket/payout destinations. | `test_SameFactoryRaffleDestinationIsRejected`; source review of `Raffle.sol:587-604`. | Pass for same-factory/local plumbing. |
| DST-02 | Assets never move into a raffle clone created by another factory. | Cross-factory reproduction and negative property `test_Property_AllRaffleClonesAreRejectedDestinations`. | **Fail:** the destination classifier queries only its own factory registry. |
| DST-03 | A permissionless caller cannot redirect sponsor/protocol claims. | Fixed-destination claims test. | Pass. |

## Randomness and integration properties

| ID | Property | Check | Result |
|---|---|---|---|
| VRF-01 | The local consumer binds resolution to wrapper caller, stored request ID, one word, state, and time. | Callback tests and source review. | Pass locally. |
| VRF-02 | The deployed wrapper returns a unique accepted request ID and unpredictable unbiased word bound to that request. | Interface/source review; wrapper implementation absent. | **Unresolved external assumption.** Local source cannot establish deployed identity or implementation behavior. |
| VRF-03 | Mapping a 256-bit uniform word with `% totalEntries + 1` yields a valid one-based entry. | Manual arithmetic review and callback tests. | Pass for range; modulo bias is nonzero in theory but bounded by less than `totalEntries / 2^256` (at most about `2^-128`) and is informational. |

## Controller adaptations

- Foundry was the primary project-native property controller because the repository is Foundry-configured. Final fuzzing used deterministic seed `0x53365f46494e414c5f46555a5a5f53454544`, 10,000 cases per fuzz property. Final invariants used seed `0x53365f46494e414c5f494e56415249414e54`, 256 runs and depth 128.
- Echidna 2.3.3 was installed through the authorized Docker daemon and exercised four stateful properties for 20,007 calls, sequence length 64, seed 1396142931.
- `slither-prop` was attempted but reports `Foundry not yet supported by slither-prop`; independently, the target consumes ERC-20 but is not an ERC-20 implementation, so the ERC-20/Truffle property generator is not applicable. The project-specific matrix above replaces it.
