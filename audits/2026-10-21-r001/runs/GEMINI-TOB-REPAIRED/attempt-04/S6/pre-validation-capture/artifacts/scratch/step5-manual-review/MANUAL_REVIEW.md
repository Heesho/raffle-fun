# Step 5: Manual Security Review (`raffle-fun`)

**Codebase**: `packages/contracts/src/` (`Raffle.sol`, `RaffleFactory.sol`, `interfaces/IRaffle.sol`, `interfaces/IRaffleFactory.sol`, `libraries/RaffleConstants.sol`) and `DESIGN.md`
**Raw Search Log**: `scratch/step5-manual-review/manual-review-searches.log`

---

## 5.1 Privacy & On-Chain Confidentiality

### Search & Codebase Evidence
- Executed `grep -rnE "private|secret|commit|reveal|password|hidden" packages/contracts/src/`.
- Only two `private` state variables exist across the owned contracts:
  1. `mapping(uint256 ticketId => TicketRange range) private _ticketRanges;` (`src/Raffle.sol:139`), which is intentionally exposed via the public view getter `ticketRange(uint256 ticketId)` (`src/Raffle.sol:451-458`).
  2. `bool private _requestInFlight;` (`src/Raffle.sol:142`), a transient intra-transaction guard set to `true` before `requestRandomnessPayInNative` and cleared to `false` immediately after (`src/Raffle.sol:255-260`).

### Findings & Assessment
- **No On-Chain Secret Misconceptions (`PASS`)**: Neither `Raffle` nor `RaffleFactory` stores secret seeds, private keys, passwords, or hidden reserve values in contract storage. All economic parameters (`reserveEntries`, `endTime`, `ENTRY_PRICE`, `prizeToken`, `prizeTokenId`) are transparent public state variables and emitted in `RaffleCreated` (`src/RaffleFactory.sol:136-147`).
- **No Commit-Reveal Required (`PASS`)**: Winner selection does not depend on user-submitted secrets or commit-reveal schemes; randomness is supplied asynchronously by Chainlink VRF v2.5 after `block.timestamp >= endTime` (`src/Raffle.sol:244`).

---

## 5.2 Front-Running, Transaction Ordering & MEV Analysis

### Search & Codebase Evidence
- Executed `grep -rnE "block\.timestamp|deadline|endTime|slippage|minAmount|requestDraw|settleWinningTicket|enableRefunds" packages/contracts/src/`.

### Concrete Code-Level Findings & Risk Analysis

1. **MR-01 (Low / Architectural Note): Late-Sale Entry Sniping & Reserve-Threshold Information Advantage (`src/Raffle.sol:214-240`)**
   - **Mechanism**: Because `totalEntries` (`src/Raffle.sol:85`) and `reserveEntries` (`src/Raffle.sol:79`) are publicly visible on-chain until `endTime`, a sophisticated participant (or MEV searcher) can monitor `totalEntries` in the final block before `endTime` (`block.timestamp < endTime` at `src/Raffle.sol:215`).
   - **Impact**:
     - If `totalEntries + entryCount >= reserveEntries` and the prize NFT market value significantly exceeds `grossSales`, a late buyer can buy a large batch of entries (up to `MAX_ENTRIES_PER_PURCHASE = 1_000` per call, repeatable in a multicall) right before `endTime` to capture a known share of the probability distribution.
     - Conversely, a sponsor wishing to push a raffle across `reserveEntries` (`CashWon` -> `NftWon`) could self-purchase the remaining entries if doing so is cheaper than losing 51% of existing `grossSales` (`50%` cash winner + `1%` protocol fee) in `CashWon`. Note that in `CashWon`, the sponsor retains the NFT (`releaseSponsorPrize`) plus `49%` of `grossSales`, whereas in `NftWon` the sponsor receives `99%` of `grossSales` and surrenders the NFT.
   - **Mitigation Status**: Fixed `ENTRY_PRICE = 1e6` eliminates AMM price slippage. The protocol intentionally avoids soft-close time extensions to preserve deterministic `endTime` and `drawRequestDeadline` windows (`DESIGN.md`).

2. **MR-02 (Low / Operational Note): Secondary Market Ticket Transfers During `Drawing` or Post-Resolution (`src/Raffle.sol:495-502`)**
   - **Mechanism**: Raffle tickets are standard transferable ERC-721 tokens (`Raffle` inherits `ERC721`). In `Raffle._update(address to, uint256 ticketId, address auth)` (`src/Raffle.sol:495-502`), transfers between non-protocol addresses are permitted in all statuses (`Active`, `Drawing`, `NftWon`, `CashWon`, `Refunding`) until the ticket is burned in `redeemWinningTicket` or `refundTickets`.
   - **Impact**:
     - If a ticket holder lists a ticket on an NFT marketplace while the raffle is in `Drawing` (or after `fulfillRandomWords`), an MEV bot observing the pending or mined `rawFulfillRandomWords` transaction in the mempool knows the exact `winningEntry` (`src/Raffle.sol:518`) and can front-run the seller's cancel order to buy the winning ticket, or sell a non-winning ticket to a stale bid before `fulfillRandomWords` lands.
     - Note also that `settleWinningTicket(uint256 ticketId)` (`src/Raffle.sol:299-302`) only records `winningTicketId`, `winnerProceeds`, `sponsorProceeds`, and `protocolFees` — it does **not** lock `winnerRecipient` until the current owner of `winningTicketId` actually calls `redeemWinningTicket(ticketId)` (`src/Raffle.sol:305-343`), which burns the ticket (`_burn(ticketId)`) and pays `msg.sender`.
   - **Recommendation**: Document clearly for UI/marketplace integrators that secondary market listings of `raffle.fun` tickets should expire prior to `endTime`, or optionally restrict peer-to-peer transfers once `status != Status.Active` if post-sale trading is not needed.

3. **MR-03 (Informational / Benign): Permissionless `requestDraw`, `settleWinningTicket`, and `enableRefunds` Race Conditions (`src/Raffle.sol:242-302`)**
   - **Mechanism**: `requestDraw()`, `settleWinningTicket(ticketId)`, and `enableRefunds()` are permissionless.
   - **Impact**:
     - If two keepers submit `requestDraw()` in the same block, the first transitions `status` from `Active` to `Drawing` and the second reverts cleanly with `InvalidStatus(Status.Active, Status.Drawing)`, refunding unused gas.
     - In `requestDraw()`, any excess `msg.value` above `paidPrice` is refunded directly to `msg.sender` (`address refundRecipient = msg.sender` at `src/Raffle.sol:265`), so another caller cannot steal a requester's native ETH payment.
     - In `settleWinningTicket(ticketId)`, only the unique ticket whose range `[startEntry, endEntry]` contains `winningEntry` passes `_requireWinningTicket(ticketId)` (`src/Raffle.sol:579-585`), so a front-runner calling `settleWinningTicket` with a different `ticketId` reverts with `TicketNotWinner`, and calling it with the true `winningTicketId` simply pays the settlement gas on behalf of the winner without altering any payout amounts or recipients.

---

## 5.3 Cryptography, Randomness & Hashing Analysis

### Search & Codebase Evidence
- Executed `grep -rnE "random|vrf|VRF|keccak256|sha256|ecrecover|ECDSA|encodePacked|blockhash|prevrandao|difficulty" packages/contracts/src/`.
- Zero uses of `blockhash`, `prevrandao`, `block.difficulty`, `ecrecover`, `ECDSA`, or `abi.encodePacked` exist in the owned contracts.

### Concrete Code-Level Findings & Risk Analysis

1. **MR-04 (Verified Safe): Chainlink VRF v2.5 Direct Funding & Modulo Bias Bound (`src/Raffle.sol:509-531`)**
   - **Mechanism**: Winner selection uses Chainlink VRF v2.5 (`VRFV2PlusWrapperConsumerBase`) with `requestConfirmations = 3` (`RaffleConstants.VRF_REQUEST_CONFIRMATIONS`) and `numWords = 1`. Upon callback in `fulfillRandomWords` (`src/Raffle.sol:518`):
     ```solidity
     uint128 resolvedEntry = uint128((randomWords[0] % uint256(totalEntries)) + 1);
     ```
   - **Modulo Bias Calculation**: `randomWords[0]` is uniformly distributed over $[0, 2^{256}-1]$, while `totalEntries` is a `uint128` (`totalEntries <= 2^{128}-1`, and in practice bounded by total USDC supply $\ll 2^{64}$). The statistical distance from a uniform distribution on $\{1, \dots, \text{totalEntries}\}$ is bounded by $\frac{\text{totalEntries}}{2^{256}} < 2^{-128}$, which is cryptographically negligible.

2. **MR-05 (Verified Safe): Synchronous Callback & Replay Protection (`src/Raffle.sol:255-260`, `src/Raffle.sol:509-516`)**
   - **Mechanism**: `rawFulfillRandomWords` (`VRFV2PlusWrapperConsumerBase.sol:95-99`) authenticates `msg.sender == address(i_vrfV2PlusWrapper)`. Inside `Raffle.fulfillRandomWords`:
     ```solidity
     if (
         _requestInFlight || status != Status.Drawing || requestId != vrfRequestId || randomWords.length != 1
             || block.timestamp > callbackDeadline()
     ) {
         emit VrfCallbackIgnored(requestId, vrfRequestId, status);
         return;
     }
     ```
   - **Assessment**: Even if a wrapper attempted a synchronous callback before `requestRandomnessPayInNative` returned, `_requestInFlight == true` causes `fulfillRandomWords` to emit `VrfCallbackIgnored` and return without mutating state. Returning cleanly instead of reverting on late/mismatched callbacks matches Chainlink VRF best practices so wrapper gas accounting is not disrupted.

---

## 5.4 DeFi, External Token & Wrapper Integration Analysis

### Search & Codebase Evidence
- Executed `grep -rnE "safeTransfer|transferFrom|call\(|delegatecall|staticcall|calculateRequestPriceNative|estimateRequestPriceNative|requestRandomnessPayInNative|receive\(\)" packages/contracts/src/`.

### Concrete Code-Level Findings & Risk Analysis

1. **MR-06 (Low / Integration Edge Case): Dual `calculateRequestPriceNative` Evaluation & Wrapper Native Balance Assumption (`src/Raffle.sol:253-257` & `VRFV2PlusWrapperConsumerBase.sol:74-86`)**
   - **Mechanism**: In `Raffle.requestDraw()` (`src/Raffle.sol:253-257`):
     1. `uint256 requiredFee = getVrfRequestPrice();` calls `i_vrfV2PlusWrapper.calculateRequestPriceNative(callbackGasLimit, 1)` (`src/Raffle.sol:437`).
     2. `if (msg.value < requiredFee) revert InsufficientVrfFee(requiredFee, msg.value);`
     3. `(requestId, paidPrice) = requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, 1, extraArgs);`
     4. Inside Chainlink's `VRFV2PlusWrapperConsumerBase.requestRandomnessPayInNative` (`VRFV2PlusWrapperConsumerBase.sol:81-86`), it calls `i_vrfV2PlusWrapper.calculateRequestPriceNative(_callbackGasLimit, _numWords)` a second time, checks `address(this).balance >= requestPrice`, and forwards `{value: requestPrice}` to `i_vrfV2PlusWrapper.requestRandomWordsInNative`.
   - **Assessment**: For standard Chainlink `VRFV2PlusWrapper`, `calculateRequestPriceNative` is a `view` function that returns an identical value across both calls in the same transaction (`tx.gasprice` and wrapper Link/Native feed state do not change between lines 253 and 257), so `paidPrice == requiredFee <= msg.value`. Because `Raffle.receive()` reverts with `DirectNativeTransfer()` (`src/Raffle.sol:171-173`), `Raffle` holds zero idle ETH outside `requestDraw` (unless forced via `selfdestruct`), and `uint256 excess = msg.value - paidPrice` (`src/Raffle.sol:263`) refunds the caller's exact surplus.

2. **MR-07 (Low / Integration Edge Case): `VRFV2PlusWrapperConsumerBase` Constructor Requires `vrfWrapper_.link()` (`VRFV2PlusWrapperConsumerBase.sol:45`)**
   - **Mechanism**: Even though `Raffle` exclusively uses native payment (`requestRandomnessPayInNative`), Chainlink's `VRFV2PlusWrapperConsumerBase` constructor executes `i_linkToken = LinkTokenInterface(i_vrfV2PlusWrapper.link())` (`VRFV2PlusWrapperConsumerBase.sol:45`) when `RaffleFactory` deploys the master `raffleImplementation`.
   - **Impact**: Any `vrfWrapper_` passed to `RaffleFactory` constructor (`src/RaffleFactory.sol:61`) must implement `link() external view returns (address)` at deployment time, or `RaffleFactory` deployment will revert.

3. **MR-08 (Low / Liveness Edge Case): USDC Blacklisting or Non-Receiver Contract on Pull Claims (`src/Raffle.sol:305-365`, `src/Raffle.sol:564-567`)**
   - **Mechanism**:
     - Quote token payouts (`redeemWinningTicket` in `CashWon`, `refundTickets`, `releaseSponsorProceeds`, `releaseProtocolFees`) call `_transferQuote(to, amount)` (`quoteToken.safeTransfer(to, amount)` at `src/Raffle.sol:566`).
     - Prize NFT payouts (`redeemWinningTicket` in `NftWon` at `src/Raffle.sol:334`, `releaseSponsorPrize` in `CashWon`/`Refunding` at `src/Raffle.sol:404`) call `prizeToken.transferFrom(address(this), recipient, prizeTokenId)` (deliberately avoiding `safeTransferFrom` callback griefing!) followed by `if (prizeToken.ownerOf(prizeTokenId) != recipient) revert PrizeDeliveryVerificationFailed(recipient)`.
   - **Assessment**:
     - Pull-over-push isolation ensures that if `sponsorRecipient` or `protocolTreasury` is blacklisted by USDC, it only affects their own `releaseSponsorProceeds()` or `releaseProtocolFees()` call — it never blocks `redeemWinningTicket` or `refundTickets`.
     - If a ticket holder in `CashWon` or `Refunding` is blacklisted by USDC before burning their ticket, they can still transfer their ERC-721 raffle ticket (`transferFrom`) to an unblacklisted address because `Raffle._update` only transfers the ERC-721 ticket and does not touch `quoteToken`! That is a strong liveness benefit of representing entries as transferable ERC-721 bearer tickets.
     - Conversely, `sponsorRecipient` and `protocolTreasury` are immutable once the raffle is initialized (`src/Raffle.sol:198-199`), so if `sponsorRecipient` were blacklisted by USDC, sponsor proceeds for that specific raffle could not be redirected.
