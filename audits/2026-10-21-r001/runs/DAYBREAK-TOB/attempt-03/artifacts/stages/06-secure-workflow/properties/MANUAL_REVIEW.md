# S6 manual review: required special areas

## Privacy

The complete production-source search found no secrets, salts, commit/reveal scheme, encryption, or confidential state. Solidity `private` appears only for implementation encapsulation (`_ticketRanges`, `_requestInFlight`, and private helpers); it is not treated as confidential. Sponsors, purchases, range tickets, ownership, liabilities, request IDs, winning entry, and lifecycle state are intentionally public or reconstructible from state/events. Users must assume purchase identity, ticket holdings, and outcomes are publicly observable. No privacy-specific defect was identified.

## Front-running, ordering, and MEV

Entry price is fixed, not AMM-derived, and purchases have no price/slippage dimension. Buyers can observe participation and reserve progress and choose whether to buy near the exclusive end time; this is intrinsic to the public raffle design. Entries are appended deterministically, but a future authenticated VRF word selects an entry only after sales freeze. Permissionless draw, settlement, and release calls cannot select recipients or alter amounts. Timestamp discretion can shift exact availability by roughly a block but the two-day windows and matching exclusive edges are coherent.

One material ordering issue was reproduced: sponsor-selected prize code receives control after its callback activates the clone but before factory postchecks and `RaffleCreated`. It can purchase a ticket in that interval (`Raffle.sol:416-430`; `RaffleFactory.sol:127-147`). This enables pre-publication activity and cheap sponsor-funded apparent demand/odds shaping. It is reported as low severity because the entries are fully paid and observable once the transaction lands, but it violates the expected creation/publication ordering.

## Cryptography, randomness, signatures, and hashes

No first-party `ecrecover`, signature, permit, custom hash, blockhash, or `prevrandao` mechanism exists. Chainlink’s bundled client uses typed `abi.encode` for extra arguments; there is no security-sensitive first-party packed-hash construction. Wrapper caller authentication is an address equality check in the bundled base. The application binds callbacks to state, request ID, one word, in-flight status, and a strict deadline.

The winning entry is `(randomWord % totalEntries) + 1`. It is always in range. Modulo bias exists mathematically when `totalEntries` does not divide `2^256`, but `totalEntries <= 2^128-1`, so the relative deviation is negligible (bounded at roughly `2^-128`) under a uniform 256-bit word. Actual wrapper identity, request-ID binding, unpredictability, retry policy, and word generation are not present in the target and remain deployment/integration assumptions. The `uint64(block.timestamp)` writes are safe for all realistic deployment horizons but have no explicit far-future range guard.

## DeFi, oracle, flash-loan, and protocol assumptions

No DEX, AMM, lending, borrowing, liquidation, vault, price-feed, or flash-loan integration exists. A flash loan provides no local price manipulation surface; buying entries still transfers the fixed quote amount and leaves a bearer ticket. The only price-like external value is the trusted wrapper’s native request fee, recalculated inside the inherited request helper. A higher second quote than `msg.value` reverts atomically after the call; no persistent prior native balance is consumed on success of the overall transaction.

The factory proves only code presence and six decimals for the quote token (`RaffleFactory.sol:65-78`). Correct accounting therefore requires deployment to bind the immutable address to official, fee-free, non-rebasing USDC. A fee-on-transfer counterexample was executed and produced an immediate custody deficit. This is classified as a conditional deployment risk because DESIGN.md expressly trusts canonical USDC.

The sponsor-selected prize is different: DESIGN.md says arbitrary prize contracts are untrusted. ERC-165, callbacks, `transferFrom`, and `ownerOf` are all assertions made by that same adversarial address. The local checks cannot prove genuine NFT custody; a concrete lying implementation activates sales without moving the asset. Delivery also uses unsafe `transferFrom`, skipping contract-recipient acceptance. These are reported findings rather than accepted dependency assumptions.

## Dangerous primitive search

The source/dependency search covered `tx.origin`, delegatecall, selfdestruct, assembly, CREATE2, low-level call forms, signatures, hashes, unchecked blocks, raw VRF callback, and token transfers. First-party production code contains one memory-safe assembly value refund (`Raffle.sol:266-268`) and no delegatecall/selfdestruct/tx.origin/custom-signature primitive. Generic dependency libraries contain low-level/deployment utilities, but the production-selected path uses fixed ERC-1167 `Clones.clone`, not an upgrade delegatecall controller.
