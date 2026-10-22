## REQ-45 — Independent post-settlement treasury claim

> "Sponsor and treasury can claim independently after settlement."
> — DESIGN.md:L2, sentence 14

---

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** For this record's treasury-side check, a successful settlement must create the treasury's complete allocated entitlement, and that entitlement must then be releasable without depending on whether the sponsor has released its separate entitlement. The treasury release must transfer the entire treasury bucket to the configured treasury without consuming or gating the sponsor bucket.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/Raffle.sol:L533-L555
function _settleWinningTicket(uint256 ticketId) private returns (uint256 cashAmount) {
    if (settlementComplete) revert SettlementAlreadyComplete();
    Status result = status;
    if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);

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
}
```

- The protocol fee is calculated before the `NftWon`/`CashWon` branch, and both branches converge on the same writes of `settlementComplete`, `sponsorProceeds`, and `protocolFees`; there is no terminal-result branch that marks settlement complete without allocating both buckets (`target/packages/contracts/src/Raffle.sol:L533-L555`).
- `Math.mulDiv(x, y, denominator)` is explicitly floor division (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L206`), matching the fee allocation used at settlement. The configured values are `BPS = 10_000`, `PROTOCOL_FEE_BPS = 500`, and `ENTRY_PRICE = 1_000_000` (`target/packages/contracts/src/libraries/RaffleConstants.sol:L10-L21`).

```solidity
// target/packages/contracts/src/Raffle.sol:L375-L391
function releaseSponsorProceeds() external override nonReentrant returns (uint256 amount) {
    amount = sponsorProceeds;
    if (amount == 0) revert NoSponsorProceeds();
    sponsorProceeds = 0;
    address recipient = sponsorRecipient;
    _transferQuote(recipient, amount);
    emit SponsorProceedsReleased(msg.sender, recipient, amount);
}

function releaseProtocolFees() external override nonReentrant returns (uint256 amount) {
    amount = protocolFees;
    if (amount == 0) revert NoProtocolFees();
    protocolFees = 0;
    address treasury = protocolTreasury;
    _transferQuote(treasury, amount);
    emit ProtocolFeesReleased(msg.sender, treasury, amount);
}
```

- Each external release snapshots its complete bucket, clears only that bucket, and transfers exactly the snapshot to its own configured recipient. The sponsor path never reads or writes `protocolFees`, and the treasury path never reads or writes `sponsorProceeds` (`target/packages/contracts/src/Raffle.sol:L375-L391`).
- `releaseProtocolFees` has no caller, status, winner-redemption, or sponsor-release gate; its only local availability branch is whether the treasury bucket is zero (`target/packages/contracts/src/Raffle.sol:L385-L391`). Consequently the treasury itself or any permissionless keeper can trigger delivery, but the destination remains `protocolTreasury` (`target/packages/contracts/src/Raffle.sol:L389-L391`).
- Clone initialization is factory-only and one-time, rejects a zero or known-protocol treasury destination, and then stores `protocolTreasury` (`target/packages/contracts/src/Raffle.sol:L176-L199`). The factory fixes that treasury in its constructor and passes the same address into clone initialization (`target/packages/contracts/src/RaffleFactory.sol:L64-L91`, `L109-L115`).

```solidity
// target/packages/contracts/src/Raffle.sol:L560-L566
function _transferQuote(address to, uint256 amount) private {
    if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);
    quoteToken.safeTransfer(to, amount);
}
```

- The payout helper rechecks the destination and passes the complete captured amount to `SafeERC20.safeTransfer` (`target/packages/contracts/src/Raffle.sol:L560-L566`). Its destination predicate checks the clone, factory, quote token, wrapper, prize token, implementation, and registered raffles on its two branches (`target/packages/contracts/src/Raffle.sol:L587-L604`).
- `SafeERC20.safeTransfer` reverts when its underlying call reports failure, and its bubbling branch propagates a token revert (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L29-L36`, `L176-L199`). Because neither release catches that revert, a failed delivery also reverts the preceding bucket clear; it cannot consume the entitlement while leaving the transfer incomplete.
- Both release functions use the inherited `nonReentrant` modifier (`target/packages/contracts/src/Raffle.sol:L375-L385`). The modifier enters before the body and resets to `NOT_ENTERED` after a successful body (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L94-L105`), so it prevents nested execution during a transfer but creates no persistent ordering dependency between later sponsor and treasury calls.

---

**Paths walked:**

- `settleWinningTicket` → `_settleWinningTicket` → `NftWon`: the direct permissionless entrypoint has no other branch before the private settlement call (`target/packages/contracts/src/Raffle.sol:L304-L306`); the NFT-result branch computes the sponsor remainder and then writes both independent buckets in the common tail (`target/packages/contracts/src/Raffle.sol:L533-L555`). ✓
- `settleWinningTicket` → `_settleWinningTicket` → `CashWon`: the cash branch additionally writes `winnerProceeds`, then reaches the same sponsor/protocol allocation tail (`target/packages/contracts/src/Raffle.sol:L543-L555`). ✓
- `redeemWinningTicket` → `_settleWinningTicket` when not yet settled: both `NftWon` and `CashWon` first allocate the sponsor/protocol buckets at `L314-L315`; winner delivery follows at `L320-L342`. A delivery revert is not caught, so it unwinds the transaction rather than leaving a completed settlement with missing allocations; a successful redemption leaves both sponsor and treasury buckets available (`target/packages/contracts/src/Raffle.sol:L309-L345`). ✓
- `redeemWinningTicket` after prior settlement: the function skips `_settleWinningTicket` and checks only the recorded winning ticket before winner delivery; it does not read or modify either sponsor or protocol bucket (`target/packages/contracts/src/Raffle.sol:L314-L342`). ✓
- Sponsor release first → treasury release second: sponsor release clears only `sponsorProceeds`; the unchanged `protocolFees` value is later read and transferred in full (`target/packages/contracts/src/Raffle.sol:L375-L391`). ✓
- Treasury release first → sponsor release second: treasury release clears only `protocolFees`; the unchanged `sponsorProceeds` value remains available to the sponsor path (`target/packages/contracts/src/Raffle.sol:L375-L391`). ✓
- Fresh post-settlement zero check: a reachable draw requires at least one sold entry (`target/packages/contracts/src/Raffle.sol:L240-L243`), while each purchase requires a positive count and adds `entryCount * ENTRY_PRICE` to `unsettledPot` (`target/packages/contracts/src/Raffle.sol:L215-L233`). With the fixed price and fee constants (`target/packages/contracts/src/libraries/RaffleConstants.sol:L12-L21`), the first treasury allocation is at least 50,000 raw units, so `NoProtocolFees` does not block a fresh valid settlement claim. After the treasury has released once, the same zero check prevents only a duplicate treasury release; it does not inspect the sponsor bucket (`target/packages/contracts/src/Raffle.sol:L385-L391`). ✓
- `_transferQuote` destination branches: a known protocol sink reverts before the token call; any other destination reaches `safeTransfer` (`target/packages/contracts/src/Raffle.sol:L564-L566`, `L593-L604`). The configured treasury is subjected to the same predicate during one-time initialization (`target/packages/contracts/src/Raffle.sol:L176-L199`). A transfer failure reverts the release, while a successful transfer completes that bucket alone (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L29-L36`, `L176-L199`). ✓
- Modifier path: a nested call while one release is executing is rejected, and the guard resets after a successful call, permitting either release as the next independent transaction or sequential call (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L72`, `L88-L105`). ✓

---

**Searched:**

- Frozen implementation scope → read all five production files and all 31 files named by `target/dependency-hashes.json` in full; all 31 dependency SHA-256 values matched the manifest.
- `settlementComplete|settleWinningTicket|_settleWinningTicket` across the five production files → 10 hits: the interface entrypoint/getter, the stored flag, the direct settlement entrypoint, the redemption caller, the private implementation, its duplicate guard, and its completion write; no third settlement caller was present.
- `sponsorProceeds|protocolFees` across all five production files plus all 31 dependencies → 11 hits, all in `Raffle.sol` or `IRaffle.sol`: two storage declarations, four release reads/clears, one aggregate-balance read, two settlement assignments, and two interface getters.
- `releaseSponsorProceeds|releaseProtocolFees` across the same 36-file scope → exactly 4 hits: two interface declarations and two `Raffle.sol` implementations; no wrapper, alternate entrypoint, or internal caller was present.
- `(sponsorProceeds|protocolFees|settlementComplete)\s*=` across the five production files → exactly 5 writes, all in `Raffle.sol`: sponsor clear at `L378`, protocol clear at `L388`, settlement completion at `L551`, sponsor allocation at `L554`, and protocol allocation at `L555`.
- `claim|claims|claimable|withdraw|withdrawal|collect|payout|release|released` across the five production files → 28 occurrences on 27 lines: `claim` 6, `claims` 3, `claimable` 8, `payout` 2, `release` 6, `released` 3; `withdraw`, `withdrawal`, and `collect` returned 0 hits. The matches exposed no alternative sponsor/treasury withdrawal mechanism beyond the two release entrypoints.
- Release modifiers and base implementation → both entrypoints carry `nonReentrant` at `Raffle.sol:L375` and `L385`; the only matching modifier implementation was `ReentrancyGuard.sol:L69-L105`, whose success path resets the guard.
- `_transferQuote|safeTransfer` call chain across the 36-file scope → the treasury release calls `_transferQuote` at `Raffle.sol:L390`, the helper calls `quoteToken.safeTransfer` at `L566`, and the ERC-20 implementation used by that call is `SafeERC20.sol:L33-L36`, `L176-L199`; the other first-party `_transferQuote` callers are winner redemption, refunds, and sponsor release at `Raffle.sol:L342`, `L369`, and `L380`.
- `protocolTreasury` across the five production files → 22 hits covering the factory's immutable declaration/constructor checks/assignment, the value passed to clone initialization, the clone's zero/destination checks and only assignment, the payout read, and interface documentation/getters; no mutable setter was present.

---

**How the verdict was reached:** This is `implemented`, not `partial`, because both settlement result branches and both settlement callers converge on the same atomic allocation of `sponsorProceeds` and `protocolFees`, while either release order consumes only the selected bucket. It is not `contradicted`: there is no shared claimed flag, combined payout, caller-order gate, or sponsor-release precondition on the treasury path. It is not `stronger-than-spec`: permissionless triggering does not narrow the documented entitlement, because funds are always directed to the configured treasury. The concrete quote-token implementation is outside the target, but the specification expressly states, "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted." (`DESIGN.md:L2, sentence 16`). Under that stated trust boundary, the local accounting and control-flow enforcement is complete.

---

**Open questions:**

- None within the specification's stated canonical quote-token trust model.
