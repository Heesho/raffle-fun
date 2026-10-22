## REQ-42 — Permissionless settlement and atomic owner redemption

> "Settlement is permissionless, storage-only; redemption requires current ticket owner, burns claim atomically, and must revert all effects on delivery failure."
> — DESIGN.md:L2, sentence 13

**Verdict:** implemented · confidence: high

---

**What this demands of an implementation:** “Settlement is permissionless, storage-only” requires an entrypoint with no caller-identity restriction that validates the winning ticket and allocates liabilities without delivering an asset. “Redemption requires current ticket owner” requires ownership to be read from the live ticket ledger when redemption executes, not inferred from the buyer, settler, or a historical owner. “Burns claim atomically” and “must revert all effects on delivery failure” require the ticket burn, redemption flags and liability consumption, and the selected NFT or quote-token delivery to succeed or fail as one transaction. Both `NftWon` and `CashWon`, and both pre-settled and not-yet-settled redemption, are in scope.

---

**Where enforcement lives:**

```solidity
// target/packages/contracts/src/Raffle.sol:L304-L305
function settleWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
    cashAmount = _settleWinningTicket(ticketId);
}

// target/packages/contracts/src/Raffle.sol:L533-L558
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

    emit WinningTicketSettled(ticketId, msg.sender, result, cashAmount, protocolFee, sponsorAmount);
}
```

- The external settlement entrypoint has only `nonReentrant`; that modifier checks and updates a reentrancy flag, not caller identity (`target/packages/contracts/src/Raffle.sol:L304-L305`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73,L88-L105`). Within the helper, `msg.sender` is used only as event data at `Raffle.sol:L557`. Settlement is therefore permissionless.
- The helper validates terminal status and the ticket’s stored range, computes allocations with internal `pure` `Math.mulDiv`, updates the liability fields, and emits an event (`target/packages/contracts/src/Raffle.sol:L533-L558`; `target/packages/contracts/src/Raffle.sol:L577-L585`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol:L199-L206`). Its complete body contains no external call or asset-transfer operation. Thus “storage-only” is satisfied in the economically material sense: settlement proves and records allocations but does not deliver an asset.

```solidity
// target/packages/contracts/src/Raffle.sol:L309-L345
function redeemWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
    if (winnerRedeemed) revert WinningTicketAlreadyRedeemed();
    Status result = status;
    if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);

    if (!settlementComplete) {
        _settleWinningTicket(ticketId);
    } else if (ticketId != winningTicketId) {
        revert WinningTicketMismatch(ticketId, winningTicketId);
    }

    address winner = ownerOf(ticketId);
    if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);

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
    } else {
        cashAmount = winnerProceeds;
        if (cashAmount == 0) revert NoWinnerProceeds();
        winnerProceeds = 0;
        _transferQuote(winner, cashAmount);
    }

    emit WinningTicketRedeemed(ticketId, winner, result, cashAmount, deliveredPrizeToken, deliveredPrizeTokenId);
}
```

- A not-yet-settled redemption first performs the same local allocation; an already-settled redemption must supply the recorded `winningTicketId` (`target/packages/contracts/src/Raffle.sol:L314-L318`). The live inherited `ownerOf` lookup then rejects a nonexistent or burned ticket, and the explicit `msg.sender` comparison admits the current owner only—not an approved operator or the settler (`target/packages/contracts/src/Raffle.sol:L320-L321`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L60-L63,L420-L431`).
- Redemption records the recipient, sets the one-time redemption flag, and calls `_burn` before either delivery branch (`target/packages/contracts/src/Raffle.sol:L323-L325`). The Raffle override permits the zero-address burn and delegates to the inherited update (`target/packages/contracts/src/Raffle.sol:L491-L502`). The inherited burn clears approval, decrements the owner’s balance, writes the token owner to zero, and rejects a nonexistent token (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L216-L245,L292-L308`). This consumes the transferable ticket claim.
- On `NftWon`, redemption sets `prizeClaimed`, calls the configured prize token, and then requires that `ownerOf` report the winner; a reverting transfer, a reverting verification call, or a mismatching owner prevents the function from returning (`target/packages/contracts/src/Raffle.sol:L327-L337`). There is no `try/catch` in `Raffle.sol`, so those failures are not caught or converted into success.
- On `CashWon`, redemption reads the complete winner bucket, rejects zero, clears it, and delegates to `_transferQuote` (`target/packages/contracts/src/Raffle.sol:L338-L343`). `_transferQuote` screens the destination and invokes `SafeERC20.safeTransfer` (`target/packages/contracts/src/Raffle.sol:L560-L567`). `safeTransfer` reverts when its internal call reports failure and requests revert bubbling; `_safeTransfer` bubbles token revert data and accepts only `true` or a successful empty return from a contract (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L29-L37,L167-L200`).
- Both external entrypoints are guarded for their entire bodies (`target/packages/contracts/src/Raffle.sol:L304-L309`). The inherited modifier sets the shared guard before the function body and restores it only after the body returns (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L73,L88-L105`), preventing a delivery-time callback from reentering another guarded settlement, redemption, refund, or release path.

The redemption-specific writes, inherited ticket-ledger mutation, and delivery call all occur inside the single `redeemWinningTicket` call (`target/packages/contracts/src/Raffle.sol:L309-L345`). Under transaction revert semantics, an uncaught external-call revert or the explicit NFT postcondition revert unwinds the earlier allocation (when settlement was inline), redemption accounting, burn, emitted logs, and callee-side token changes. No low-level success value is ignored on either delivery path: the NFT path uses a reverting high-level call plus an ownership postcondition, and the cash path uses the reverting `SafeERC20` wrapper (`target/packages/contracts/src/Raffle.sol:L329-L345`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L33-L37,L176-L200`).

---

**Paths walked:**

- `settleWinningTicket` → `nonReentrant` → `_settleWinningTicket`: any address can enter when the guard is free. An already-complete settlement, a nonterminal status, or a ticket range not containing `winningEntry` reverts; none is converted to success (`target/packages/contracts/src/Raffle.sol:L304-L305,L533-L538,L577-L585`; `target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L88-L100`). ✓
- `_settleWinningTicket`, `NftWon`: computes the protocol allocation and sponsor remainder, then records completion, winning ticket, zero unsettled pot, and both destination buckets; no ownership read, burn, or asset call occurs (`target/packages/contracts/src/Raffle.sol:L539-L557`). ✓
- `_settleWinningTicket`, `CashWon`: additionally computes and stores `winnerProceeds`, then performs the same local completion writes; no asset call occurs (`target/packages/contracts/src/Raffle.sol:L539-L557`). ✓
- `redeemWinningTicket`, not settled: inline settlement runs at `L315`; every later owner, burn, NFT, cash, or postcondition failure reverts that inline allocation together with the redemption (`target/packages/contracts/src/Raffle.sol:L309-L345`). ✓
- `redeemWinningTicket`, already settled: a different ID reverts, while the recorded ID continues to a fresh live-owner lookup (`target/packages/contracts/src/Raffle.sol:L314-L321`). Because settlement never burns the ticket, a transfer after settlement changes who passes this later lookup (`target/packages/contracts/src/Raffle.sol:L533-L558`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L114-L125,L216-L245`). ✓
- `redeemWinningTicket`, nonexistent/burned ticket or non-owner caller: inherited `ownerOf` or the explicit equality check reverts before any redemption accounting write (`target/packages/contracts/src/Raffle.sol:L320-L325`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol:L60-L63,L426-L431`). Approved operators do not pass the `msg.sender == winner` requirement. ✓
- `redeemWinningTicket`, `NftWon`: the common accounting and burn occur first; `PrizeAlreadyClaimed`, a reverting `transferFrom`, a reverting `ownerOf`, or `PrizeDeliveryVerificationFailed` then reverts the transaction rather than leaving the claim consumed (`target/packages/contracts/src/Raffle.sol:L323-L337`). A successful path finishes only after the token reports the current winner as owner. ✓
- `redeemWinningTicket`, `CashWon`: the common accounting and burn occur first; a zero bucket reverts, otherwise the bucket is cleared and `SafeERC20` either completes or reverts/bubbles failure (`target/packages/contracts/src/Raffle.sol:L323-L325,L338-L343,L560-L567`; `target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L33-L37,L176-L200`). ✓
- Duplicate redemption: `winnerRedeemed` is checked before status, settlement, or ownership work and is written on the sole redemption path (`target/packages/contracts/src/Raffle.sol:L309-L310,L323-L325`). ✓
- Other burn and prize-release paths: the only other ticket burn is `refundTickets`, gated to `Refunding`; `releaseSponsorPrize` is available only in `CashWon` or `Refunding`, not `NftWon` (`target/packages/contracts/src/Raffle.sol:L349-L369,L395-L406`). Neither is an alternate winner-redemption path. ✓

---

**Searched:**

- Scope enumeration → exactly 36 files: all five first-party production files under `target/packages/contracts/src` and all 31 paths in `target/dependency-hashes.json`. Every file was read in full. Recomputing SHA-256 for all 31 dependencies produced 31 matches and 0 mismatches.
- `settleWinningTicket` → 5 hits in the explicit 36-file scope: public definition/delegation at `Raffle.sol:L304-L305`, inline call at `L315`, private implementation at `L533`, and ABI declaration at `IRaffle.sol:L331`.
- `redeemWinningTicket` → 2 hits: the executable external definition at `Raffle.sol:L309` and ABI declaration at `IRaffle.sol:L338`; no in-scope wrapper or caller exists.
- `settlementComplete` / `winnerRedeemed` / `winningTicketId` / `winnerRecipient` / `winnerProceeds` / `prizeClaimed` → respectively 5 / 4 / 7 / 3 / 6 / 6 hits. Relevant writes reduce to settlement at `Raffle.sol:L548,L551-L555`, redemption at `L323-L324,L331,L341`, and sponsor-prize release at `L403`; all reads and lifecycle gates were walked.
- `NotTicketOwner|WinningTicketMismatch|WinningTicketAlreadyRedeemed` → 7 hits: four executable reverts at `Raffle.sol:L310,L317,L321,L360` and three error declarations at `IRaffle.sol:L274,L287,L290`. The `L360` use belongs to the separate refund path.
- `_burn\(` → 3 hits: winner redemption at `Raffle.sol:L325`, refunds at `L364`, and the inherited implementation at `ERC721.sol:L303`. No other claim-consumption implementation was found.
- `prizeToken\.transferFrom|prize\.safeTransferFrom` → 3 hits: factory escrow at `RaffleFactory.sol:L128`, winner NFT redemption at `Raffle.sol:L334`, and sponsor-prize release at `Raffle.sol:L404`.
- `_transferQuote\(` → 5 hits: winner cash redemption at `Raffle.sol:L342`, refund/sponsor/protocol calls at `L369,L380,L390`, and the helper at `L564`. The winner call is the only one that consumes `winnerProceeds`.
- `ownerOf\(` → 11 hits across the explicit scope. The relevant chain is `Raffle.sol:L320` → inherited `ERC721.ownerOf` at `ERC721.sol:L61-L63` → `_requireOwned` at `L426-L431`; prize delivery separately checks the external prize’s `ownerOf` at `Raffle.sol:L335`.
- `function _update|function _burn|function ownerOf` → 5 hits: Raffle’s `_update` override, the IERC-721 declaration, and the inherited `ownerOf`, `_update`, and `_burn` implementations (`Raffle.sol:L497`; `IERC721.sol:L39`; `ERC721.sol:L61,L216,L303`).
- `nonReentrant` → 32 textual hits in the explicit scope. Executable relevant hits are both target entrypoints (`Raffle.sol:L304,L309`) and the guard implementation (`ReentrancyGuard.sol:L69-L105`); reading the modifier confirmed it is not authorization.
- `\b(try|catch)\b` in `Raffle.sol` → 0 hits. Delivery reverts are not intercepted.
- `call|delegatecall|staticcall|transfer|safeTransfer|transferFrom` within `_settleWinningTicket` (`Raffle.sol:L533-L558`) → 0 hits. `msg.sender` within that body → 1 hit, solely the `WinningTicketSettled` event at `L557`.
- Case-insensitive `settle|redeem|claim|consume|burn|deliver|payout|withdraw` over the five production files → 102 textual hits. Reviewing those hits found no alternate winner claim entrypoint beyond the settlement, redemption, refund, and fixed-destination release paths cited above.

---

**How the verdict was reached:** `implemented`, rather than `partial`, because every relevant implementation branch enforces the quoted division of responsibility. Both settlement outcomes are permissionless and perform only proof/accounting; both redemption outcomes require the live owner, consume the ticket, update the corresponding one-time accounting, and propagate delivery failure. The same is true whether allocation occurred in an earlier permissionless transaction or is performed inline: in the latter case the allocation is also inside the redemption rollback boundary (`target/packages/contracts/src/Raffle.sol:L304-L345,L533-L558`).

This is not `stronger-than-spec`: settlement does not add an identity gate, and redemption deliberately requires the owner itself rather than also accepting an approved ERC-721 operator (`target/packages/contracts/src/Raffle.sol:L304-L305,L320-L321`). The `nonReentrant` modifier adds execution safety but does not narrow the authorized actor set (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L105`).

The cash-delivery conclusion is made under the target’s explicit canonical-token model: the interface states that the immutable quote token is standard, non-rebasing, and fee-free (`target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`). Within that model, `SafeERC20` proves failure propagation. NFT delivery has an additional source-visible postcondition: the configured prize must report the current ticket owner after transfer (`target/packages/contracts/src/Raffle.sol:L329-L337`). Neither caveat exposes a Raffle branch that retains a burn or redemption accounting after a recognized delivery failure.

---

**Open questions:**

- The concrete sponsor-selected prize implementation is outside the target. The factory checks deployed code, self-reported ERC-721 support, initial transfer, and reported custody (`target/packages/contracts/src/RaffleFactory.sol:L127-L134,L154-L177`), while redemption can observe only `transferFrom` success and the subsequent `ownerOf` result (`target/packages/contracts/src/Raffle.sol:L329-L337`). A contract that lies consistently about ERC-721 semantics cannot be disproved from the supplied interface. This does not change the verified rollback behavior for a revert or ownership mismatch.
- The concrete canonical quote-token implementation is also outside the target. `SafeERC20` verifies call/return behavior, not the recipient’s balance delta (`target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol:L176-L200`); exact fee-free delivery rests on the stated canonical-token assumption at `IRaffle.sol:L12-L15`.
