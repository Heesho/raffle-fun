## `redeemWinningTicket` in `target/packages/contracts/src/Raffle.sol` (L309-L346)

**Purpose:** Completes the winner side of a resolved raffle. It optionally proves and settles the supplied winning ticket, requires the caller to be that ticket's current owner, records the owner as the winner, burns the transferable ticket claim, and delivers either the escrowed ERC-721 prize or the allocated quote-token proceeds (`Raffle.sol:L309-L345`). The public interface describes settlement-plus-redemption as one atomic operation whose delivery failure reverts the burn and redemption state changes (`IRaffle.sol:L333-L338`).

**Inputs & Assumptions:**

- `ticketId` (`uint256`): caller-selected ticket identifier. Trust: **untrusted**. Before settlement, its historical entry range must contain `winningEntry`; after settlement, it must equal the recorded `winningTicketId` (`Raffle.sol:L314-L318`, `Raffle.sol:L579-L584`).
- `msg.sender`: arbitrary external caller. Trust: **untrusted**. The caller must equal the exact current owner returned by the raffle ticket ledger; an approved address or operator is not sufficient (`Raffle.sol:L320-L321`).
- Implicit lifecycle input: `status` must be `NftWon` or `CashWon`, and `winnerRedeemed` must be false (`Raffle.sol:L310-L312`). The terminal status and `winningEntry` are written together only on an accepted randomness callback (`Raffle.sol:L509-L523`).
- Implicit settlement input: `settlementComplete`, `winningTicketId`, `unsettledPot`, `winnerProceeds`, `sponsorProceeds`, and `protocolFees` determine whether settlement runs and which liabilities are available (`Raffle.sol:L314-L318`, `Raffle.sol:L533-L557`).
- Implicit ticket-ledger input: inherited ERC-721 ownership, balance, and approval state determine whether `ownerOf` succeeds and what `_burn` removes (`ERC721.sol:L28-L34`, `ERC721.sol:L61-L63`, `ERC721.sol:L303-L307`). Historical `_ticketRanges` are not removed by a burn (`Raffle.sol:L138-L139`, `Raffle.sol:L451-L455`).
- Implicit NFT-delivery input: `prizeClaimed`, `prizeToken`, and `prizeTokenId` identify the one prize and its disposition state (`Raffle.sol:L69-L73`, `Raffle.sol:L132-L133`, `Raffle.sol:L329-L337`). Initial escrow is established by the factory's safe transfer plus post-transfer ownership and raffle-status checks (`RaffleFactory.sol:L127-L134`). Continued standard ownership and transfer behavior is an explicit trust assumption for the sponsor-selected prize contract (`IRaffle.sol:L12-L15`); beyond its interface, the deployed prize implementation is not present in `target/`.
- Implicit quote-delivery input: `quoteToken` is the immutable token called on the cash path (`Raffle.sol:L57-L58`, `Raffle.sol:L339-L342`). Exact, fee-free, non-rebasing transfer semantics are assumed by the protocol (`IRaffle.sol:L12-L15`, `Raffle.sol:L560-L566`); `SafeERC20` establishes only that the low-level call did not revert or return an explicit false value (`SafeERC20.sol:L30-L36`, `SafeERC20.sol:L176-L199`).
- Precondition: the supplied ticket is the winning ticket. If settlement has not occurred, `_requireWinningTicket` establishes this from the stored inclusive range and `winningEntry`; if settlement has occurred, equality with `winningTicketId` establishes it (`Raffle.sol:L314-L318`, `Raffle.sol:L538`, `Raffle.sol:L579-L584`).
- Precondition: the winning ticket still exists. `ownerOf` establishes this immediately before the owner check by reverting for an unowned or burned token (`Raffle.sol:L320`; `ERC721.sol:L61-L63`, `ERC721.sol:L426-L431`).
- Precondition: no protected raffle entrypoint is already executing. The inherited `nonReentrant` modifier checks and sets the shared guard before the body and restores it after successful completion (`Raffle.sol:L309`; `ReentrancyGuard.sol:L69-L72`, `ReentrancyGuard.sol:L88-L105`).

**Outputs & Effects:**

- Returns `cashAmount == 0` for `NftWon`; for `CashWon`, returns the complete `winnerProceeds` value consumed by this call (`Raffle.sol:L327-L339`, `Raffle.sol:L341-L343`).
- If settlement was incomplete, may first write `settlementComplete`, `winningTicketId`, `unsettledPot`, `winnerProceeds` on the cash branch, `sponsorProceeds`, and `protocolFees`, and emits `WinningTicketSettled` (`Raffle.sol:L314-L315`, `Raffle.sol:L533-L557`).
- Writes `winnerRecipient = winner` and `winnerRedeemed = true` before either asset-delivery interaction (`Raffle.sol:L320-L325`).
- Burns the ticket: clears its single-token approval, decrements the owner's balance, sets its owner to zero, and emits the inherited ERC-721 `Transfer(winner,address(0),ticketId)` event (`Raffle.sol:L325`, `Raffle.sol:L497-L502`; `ERC721.sol:L216-L245`, `ERC721.sol:L303-L307`). The historical range remains stored because the burn path does not write `_ticketRanges` (`Raffle.sol:L138-L139`, `Raffle.sol:L451-L455`).
- `NftWon` writes `prizeClaimed = true`, calls the configured prize's `transferFrom(address(this), winner, prizeTokenId)`, then calls `ownerOf(prizeTokenId)` and requires it to report `winner` (`Raffle.sol:L329-L337`). It uses `transferFrom`, so this function does not itself require an ERC-721 receiver callback from a contract winner (`IERC721.sol:L76-L91`).
- `CashWon` reads the allocated winner liability, requires it to be nonzero, clears it before the transfer, screens the destination, and calls the immutable quote token through `SafeERC20.safeTransfer` (`Raffle.sol:L338-L343`, `Raffle.sol:L564-L567`; `SafeERC20.sol:L30-L36`).
- Emits `WinningTicketRedeemed` only after the selected delivery call and, for the NFT branch, the ownership verification (`Raffle.sol:L345`). The event carries zero cash plus the prize address/token ID for `NftWon`, or cash plus zero prize fields for `CashWon` (`Raffle.sol:L327-L345`; `IRaffle.sol:L131-L145`).
- Does not change `status`; the function operates under the terminal result captured at entry (`Raffle.sol:L311-L312`, `Raffle.sol:L329-L343`). Sponsor and protocol liabilities remain independently releasable after settlement (`Raffle.sol:L375-L391`; `IRaffle.sol:L346-L352`).
- Every explicit revert and every propagated callee revert aborts the current call. When inline settlement was attempted, a later ownership or delivery revert also aborts those settlement writes because all steps are in this one external call (`Raffle.sol:L314-L345`; `IRaffle.sol:L333-L335`).

---

**Block-by-Block:**

```solidity
// L309-L312
function redeemWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
    if (winnerRedeemed) revert WinningTicketAlreadyRedeemed();
    Status result = status;
    if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);
```

- **What:** Enters the shared reentrancy guard, rejects a second redemption, snapshots `status`, and admits only the two resolved outcomes (`Raffle.sol:L309-L312`; `ReentrancyGuard.sol:L69-L72`).
- **Why here:** These checks precede settlement, ownership reads, burns, and external asset calls, so no redemption work starts outside a terminal result or after a successful redemption (`Raffle.sol:L310-L312`). The local `result` is also the branch discriminator used later at `L329` and emitted at `L345`.
- **Assumes:** `status` is the authoritative result. The accepted callback writes `winningEntry`, `resolvedAt`, and the terminal status in the same block (`Raffle.sol:L518-L523`), and no redemption line writes it (`Raffle.sol:L309-L346`).
- **Establishes:** For every continuing path, `winnerRedeemed == false` at this point and `result` is exactly `NftWon` or `CashWon` (`Raffle.sol:L310-L312`).
- **Depended on by:** The one-time state writes at `L323-L325`, the result branch at `L329-L343`, and the event fields at `L345`.

```solidity
// L314-L318
if (!settlementComplete) {
    _settleWinningTicket(ticketId);
} else if (ticketId != winningTicketId) {
    revert WinningTicketMismatch(ticketId, winningTicketId);
}
```

- **What:** Divides execution into an inline-settlement path and an already-settled path (`Raffle.sol:L314-L318`).
- **Why here:** The function establishes the supplied ticket's relationship to `winningEntry` before treating its owner as the winner (`Raffle.sol:L314-L321`).
- **Assumes:** On the already-settled path, `settlementComplete` implies `winningTicketId` was written by `_settleWinningTicket`. That helper sets both in the same straight-line write block (`Raffle.sol:L551-L555`), and no other production function writes either variable (`Raffle.sol:L120-L127`, `Raffle.sol:L533-L557`).
- **Establishes:** On continuation, terminal liabilities are allocated and `ticketId == winningTicketId`. Inline settlement establishes both by validating the range and recording the ID; the other path checks the recorded ID directly (`Raffle.sol:L314-L318`, `Raffle.sol:L538-L555`).
- **Depended on by:** The owner lookup at `L320`, which otherwise would authorize the owner of an arbitrary ticket, and the branch-specific liability/prize delivery at `L329-L343`.

The inline callee has these complete paths:

- If settlement became complete, the callee reverts (`Raffle.sol:L534`).
- If `status` is not terminal, it reverts; the caller has already checked the same captured result, and no call occurs between the caller's check and this check (`Raffle.sol:L311-L315`, `Raffle.sol:L535-L536`).
- If the stored ticket range does not contain `winningEntry`, `_requireWinningTicket` reverts (`Raffle.sol:L538`, `Raffle.sol:L579-L584`). An ID never minted has the mapping's zero range, while a resolved `winningEntry` is one-based (`Raffle.sol:L451-L455`, `Raffle.sol:L518-L519`), so that path fails the upper-bound comparison at `L582`.
- For `NftWon`, it floors the 5% protocol fee and assigns the entire remainder to the sponsor; the return value remains its default zero (`Raffle.sol:L539-L545`; `RaffleConstants.sol:L11-L18`; `Math.sol:L200-L216`).
- For `CashWon`, it floors both the 5% protocol fee and the 80% winner allocation, assigns the remainder to the sponsor, and stores the winner allocation in `winnerProceeds` (`Raffle.sol:L539-L549`; `RaffleConstants.sol:L11-L18`; `Math.sol:L200-L216`).
- Both success paths mark settlement complete, record the winning ticket, zero `unsettledPot`, store sponsor and protocol liabilities, and emit `WinningTicketSettled` (`Raffle.sol:L551-L557`).

```solidity
// L320-L325
address winner = ownerOf(ticketId);
if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);

winnerRecipient = winner;
winnerRedeemed = true;
_burn(ticketId);
```

- **What:** Resolves the ticket's current owner, requires the caller to be that owner, records the winner and one-time redemption flag, then destroys the ticket claim (`Raffle.sol:L320-L325`).
- **Why here:** Ownership is read after winning-ticket identity is established, so the beneficiary is the current bearer at redemption rather than the buyer, settler, or owner at draw time (`Raffle.sol:L314-L325`; `IRaffle.sol:L326-L338`). The owner check immediately precedes state mutation; there is no external call between `ownerOf` and `_burn` (`Raffle.sol:L320-L325`).
- **Assumes:** ERC-721 ownership state is internally consistent. `ownerOf` delegates to `_requireOwned`, which reads `_owners` and rejects zero (`ERC721.sol:L61-L63`, `ERC721.sol:L146-L148`, `ERC721.sol:L426-L431`). Ticket mint, transfer, and burn all pass through `Raffle._update` and then `ERC721._update` (`Raffle.sol:L497-L502`; `ERC721.sol:L216-L245`).
- **Establishes:** `winnerRecipient` is the exact owner observed at `L320`, `winnerRedeemed` is true, and the winning ticket has no owner after `_burn` (`Raffle.sol:L320-L325`; `ERC721.sol:L303-L307`). `_burn` supplies `auth = address(0)`, but the caller-specific owner check at `L321` was already performed; `_burn` itself performs no authorization check (`ERC721.sol:L293-L307`).
- **Depended on by:** Both delivery branches use `winner`; the early flag and burn precede their external calls (`Raffle.sol:L329-L343`). Later calls are rejected at `L310`, and later ticket ownership reads revert because `_owners[ticketId]` is zero (`ERC721.sol:L240`, `ERC721.sol:L426-L431`).

The burn dispatches through the raffle override even though `_burn` is inherited. A zero destination bypasses the protocol-destination screen, then `super._update` clears the ticket approval, decrements the winner's balance, writes the zero owner, and emits `Transfer`; `_burn` rejects a zero previous owner (`Raffle.sol:L497-L502`; `ERC721.sol:L216-L245`, `ERC721.sol:L303-L307`). No receiver or other external contract is called on this burn path (`ERC721.sol:L216-L245`).

```solidity
// L327-L337
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
```

- **What:** Initializes the event's prize fields, then on the NFT result consumes the one-time prize disposition flag, transfers the configured token from raffle custody to the ticket owner, and verifies the reported owner (`Raffle.sol:L327-L337`).
- **Why here:** `prizeClaimed`, `winnerRedeemed`, and the ticket burn are in effect before the external transfer call (`Raffle.sol:L323-L334`). The ownership query follows the transfer so a normal return from `transferFrom` is not the only delivery signal (`Raffle.sol:L334-L337`).
- **Assumes:** The external prize contract honors ERC-721 ownership and authorization semantics and reports actual ownership from `ownerOf`. This is specified as a protocol trust assumption (`IRaffle.sol:L12-L15`) and screened initially only by code presence, ERC-165 reporting, successful escrow, and an ownership query (`RaffleFactory.sol:L154-L177`, `RaffleFactory.sol:L127-L134`). Nothing in the redemption function can establish that an arbitrary implementation's returned owner corresponds to an honest ownership ledger; beyond `IERC721`, its implementation is unavailable in `target/`.
- **Establishes:** On successful return, `prizeClaimed == true` and `prizeToken.ownerOf(prizeTokenId)` reported the recorded `winner` after the transfer (`Raffle.sol:L331-L337`). For a standards-compliant prize, the raffle no longer owns the configured prize (`IERC721.sol:L33-L39`, `IERC721.sol:L76-L91`).
- **Depended on by:** The final event uses the populated prize address and ID (`Raffle.sol:L345`), and `prizeClaimed` excludes any later NFT disposition through this function or `releaseSponsorPrize` (`Raffle.sol:L310`, `Raffle.sol:L330-L331`, `Raffle.sol:L395-L405`).

The external `transferFrom` may revert or invoke other code before returning; the source of the configured prize is not available. The raffle's shared `nonReentrant` guard rejects callbacks into every raffle entrypoint carrying that modifier while this call is active (`Raffle.sol:L309`, `Raffle.sol:L209-L212`, `Raffle.sol:L240`, `Raffle.sol:L276`, `Raffle.sol:L304`, `Raffle.sol:L349`, `Raffle.sol:L375`, `Raffle.sol:L385`, `Raffle.sol:L395`; `ReentrancyGuard.sol:L88-L105`). Inherited ticket approval and transfer entrypoints do not carry this modifier (`ERC721.sol:L92-L136`), although the winning ticket has already been burned before the prize call (`Raffle.sol:L325-L334`). A revert from the transfer or the verification query aborts this call, including its inline settlement, recorded winner, flag writes, and burn (`Raffle.sol:L314-L337`; `IRaffle.sol:L333-L335`).

```solidity
// L338-L343
} else {
    cashAmount = winnerProceeds;
    if (cashAmount == 0) revert NoWinnerProceeds();
    winnerProceeds = 0;
    _transferQuote(winner, cashAmount);
}
```

- **What:** On the cash result, loads the entire allocated winner claim, rejects an empty claim, clears the liability, and transfers that amount to the current ticket owner (`Raffle.sol:L338-L343`).
- **Why here:** The liability is cleared before entering the quote-token contract, while the outer reentrancy guard remains entered (`Raffle.sol:L309`, `Raffle.sol:L341-L342`; `ReentrancyGuard.sol:L94-L105`).
- **Assumes:** `winnerProceeds` is the cash allocation for this `winningTicketId`. `_settleWinningTicket` writes both under the same cash branch and completes settlement immediately afterward (`Raffle.sol:L545-L555`). Nothing else can allocate this bucket, and this line is its only zeroing writer (`Raffle.sol:L99-L100`, `Raffle.sol:L548`, `Raffle.sol:L341`).
- **Assumes:** A successful call to the configured quote token moves exactly `cashAmount` units without rebasing or a transfer fee. This is established by the declared canonical-token trust model, not by balance-delta checks (`IRaffle.sol:L12-L15`, `Raffle.sol:L560-L566`).
- **Establishes:** On successful return, `winnerProceeds == 0`, and `SafeERC20` observed either a returned `true` or a non-reverting no-return call to a token address containing code (`Raffle.sol:L339-L342`; `SafeERC20.sol:L30-L36`, `SafeERC20.sol:L176-L199`). Under the canonical-token assumption, the winner received `cashAmount`.
- **Depended on by:** `accountedQuoteBalance` no longer includes the winner liability after successful payment (`Raffle.sol:L468-L470`), and the final event reports `cashAmount` (`Raffle.sol:L345`).

`_transferQuote` first rejects a known protocol destination, then invokes the token (`Raffle.sol:L564-L567`). Its destination classifier compares the current winner against the raffle, factory, quote token, wrapper, prize token, implementation, and—when the winner currently has code—the factory registry (`Raffle.sol:L593-L604`). Every ticket mint and ownership transfer previously passed the same classifier through `Raffle._update` (`Raffle.sol:L497-L502`), and the cash payout repeats the check at delivery time (`Raffle.sol:L565`). The registry calls have source available: `raffleImplementation` is immutable and `isRaffle` is a factory mapping written during creation (`RaffleFactory.sol:L41-L54`, `RaffleFactory.sol:L105-L125`).

The quote-token call is an external black box at deployment. `SafeERC20` bubbles a revert, rejects explicit false, and accepts empty return data only when the token address has code (`SafeERC20.sol:L176-L199`). Any such rejection aborts the prior winner state writes, burn, and any inline settlement in this call (`Raffle.sol:L314-L342`; `IRaffle.sol:L333-L335`).

```solidity
// L345-L346
emit WinningTicketRedeemed(ticketId, winner, result, cashAmount, deliveredPrizeToken, deliveredPrizeTokenId);
}
```

- **What:** Records the burned ticket, recipient, terminal result, delivered cash amount, and delivered NFT identity (`Raffle.sol:L345`; `IRaffle.sol:L131-L145`).
- **Why here:** It is emitted only after the external delivery operation has returned and, for the NFT branch, the ownership query matched (`Raffle.sol:L334-L345`).
- **Assumes:** Consumers interpret the branch-specific zero fields according to `result`: NFT redemption leaves the named return variable at zero, while cash redemption leaves the initialized prize fields at zero (`Raffle.sol:L327-L345`).
- **Establishes:** A successfully committed redemption has a corresponding `WinningTicketRedeemed` log after the inherited burn `Transfer` log; inline settlement also emitted `WinningTicketSettled` earlier (`Raffle.sol:L315`, `Raffle.sol:L325`, `Raffle.sol:L557`, `Raffle.sol:L345`; `ERC721.sol:L240-L242`).
- **Depended on by:** Off-chain consumers that track completed winner claims; the on-chain one-time gates use storage rather than this event (`Raffle.sol:L310`, `Raffle.sol:L324`, `Raffle.sol:L330-L331`).

---

**Cross-Function Dependencies:**

- **Callee `_settleWinningTicket` (internal, `Raffle.sol:L533-L558`):** Called only when `settlementComplete` is false (`Raffle.sol:L314-L315`). The caller depends on it to reject a non-winning range, allocate all terminal quote liabilities, set `settlementComplete`, and bind `winningTicketId` to the supplied ID (`Raffle.sol:L538-L555`). Its `NftWon` and `CashWon` paths differ only in winner allocation: NFT assigns gross minus fee to the sponsor, while cash stores the floored winner amount and assigns the remainder to the sponsor (`Raffle.sol:L539-L549`). Both write all common settlement state before emitting (`Raffle.sol:L551-L557`).
- **Callees `_requireWinningTicket` and `ticketRange` (internal, `Raffle.sol:L451-L455`, `Raffle.sol:L579-L585`):** Read the historical mapping without reading ERC-721 ownership. They establish range containment only; ticket existence and current ownership are established later by inherited `ownerOf` (`Raffle.sol:L320`). Because ranges survive burns (`Raffle.sol:L138-L139`), the caller does not treat range containment alone as an ownership proof.
- **Callee `Math.mulDiv` (internal library, `Math.sol:L200-L276`):** Settlement depends on its default floor division for the 5% protocol and 80% cash-winner calculations (`Raffle.sol:L540`, `Raffle.sol:L546`; `RaffleConstants.sol:L11-L18`). Sponsor proceeds are computed as the residual, preserving the gross allocation across the branch (`Raffle.sol:L543-L548`).
- **Callee `ownerOf` (internal inherited implementation, `ERC721.sol:L61-L63`, `ERC721.sol:L426-L431`):** Establishes that the winning ticket presently exists and returns its current owner. It does not establish caller authority by itself; `redeemWinningTicket` requires `msg.sender == winner` at `Raffle.sol:L321`.
- **Callees `_burn`, `Raffle._update`, and `ERC721._update` (internal inherited/overridden chain, `Raffle.sol:L497-L502`; `ERC721.sol:L216-L245`, `ERC721.sol:L303-L307`):** The caller depends on this chain to clear approval, update balance and ownership, and reject a nonexistent token. Because `_burn` passes no `auth`, the explicit caller-owner equality at `Raffle.sol:L321` is the authorization boundary for redemption.
- **Callees `prizeToken.transferFrom` and `prizeToken.ownerOf` (external-black-box, `Raffle.sol:L334-L336`; `IERC721.sol:L33-L39`, `IERC721.sol:L76-L91`):** The function sends `(from = raffle, to = winner, tokenId = configured prizeTokenId)` and then asks the same contract for the token owner. Revert, nonstandard internal callbacks, gas exhaustion, and an ownership value other than `winner` are not excluded by the interface; each prevents this redemption call from completing. A returned `winner` is relied on under the stated honest standards-compliant prize assumption (`IRaffle.sol:L12-L15`).
- **Callee `_transferQuote` (internal, `Raffle.sol:L564-L567`):** The cash branch depends on it to reject current known protocol sinks and dispatch the complete winner claim to the quote token (`Raffle.sol:L339-L342`). It calls `_isProtocolDestination` before the token interaction (`Raffle.sol:L565-L566`).
- **Callee `_isProtocolDestination` plus factory getters (internal plus external-source-available, `Raffle.sol:L593-L604`):** Compares the winner against fixed protocol addresses and, for a current contract address, consults the canonical factory's `isRaffle` registry. The factory implementation getter and registry have source available and are fixed/written at `RaffleFactory.sol:L41-L54`, `RaffleFactory.sol:L105-L125`.
- **Callee `SafeERC20.safeTransfer` / `quoteToken.transfer` (internal wrapper plus external-black-box, `SafeERC20.sol:L30-L36`, `SafeERC20.sol:L176-L199`):** The wrapper establishes acceptable call-level completion, not amount-delta semantics. The caller depends on the immutable deployed token satisfying the protocol's canonical USDC assumptions (`IRaffle.sol:L12-L15`).
- **Modifier `nonReentrant` (internal inherited guard, `ReentrancyGuard.sol:L69-L72`, `ReentrancyGuard.sol:L88-L105`):** Covers optional settlement, owner/burn state changes, both external asset interactions, verification, and the final event (`Raffle.sol:L309-L345`). All raffle claim/release entrypoints use the same guard, while inherited ticket transfer and approval entrypoints do not (`Raffle.sol:L304-L309`, `Raffle.sol:L349-L395`; `ERC721.sol:L92-L136`).
- **Callers:** The function is an external entrypoint declared in `IRaffle` (`IRaffle.sol:L333-L338`). Any address may invoke it, but only the exact current owner of the established winning ticket can continue past `Raffle.sol:L320-L321`; no internal production caller was found. An approved ticket operator cannot redeem on the owner's behalf because the function compares `msg.sender` directly rather than using inherited ERC-721 authorization (`Raffle.sol:L321`; `ERC721.sol:L164-L187`).
- **Shared state — result selection:** `fulfillRandomWords` is the writer of `winningEntry`, `resolvedAt`, and terminal `status` (`Raffle.sol:L509-L523`). Redemption reads but does not change these fields (`Raffle.sol:L311-L312`, `Raffle.sol:L329-L345`).
- **Shared state — settlement and quote liabilities:** `settleWinningTicket` and the inline path both reach `_settleWinningTicket` (`Raffle.sol:L304-L315`, `Raffle.sol:L533-L557`). `releaseSponsorProceeds` and `releaseProtocolFees` can consume their allocations independently after settlement (`Raffle.sol:L375-L391`); cash redemption alone consumes `winnerProceeds` (`Raffle.sol:L339-L342`). `accountedQuoteBalance` sums all outstanding buckets (`Raffle.sol:L468-L470`).
- **Shared state — ticket ownership:** `buyEntries` mints the ticket and stores its range (`Raffle.sol:L226-L236`); inherited ERC-721 entrypoints can transfer it through `Raffle._update` (`ERC721.sol:L114-L136`; `Raffle.sol:L497-L502`); `refundTickets` and this function burn tickets in mutually exclusive lifecycle states (`Raffle.sol:L349-L365`, `Raffle.sol:L310-L325`). Settlement never reads or freezes ownership (`Raffle.sol:L528-L539`), so ownership may change after settlement and before redemption through the inherited transfer surface.
- **Shared state — prize disposition:** Factory creation establishes initial raffle custody (`RaffleFactory.sol:L127-L134`). In `NftWon`, only this redemption path can pass its status check and set `prizeClaimed`; `releaseSponsorPrize` can set the same flag only in `CashWon` or `Refunding` (`Raffle.sol:L329-L337`, `Raffle.sol:L395-L405`). On `CashWon`, sponsor-prize release and winner cash redemption are independent branches guarded by separate state (`Raffle.sol:L338-L343`, `Raffle.sol:L395-L405`).
- **Invariant coupling:** Successful inline settlement replaces `unsettledPot` with terminal liabilities whose sum equals the prior gross pot; cash redemption then removes exactly `winnerProceeds` from tracked liabilities before paying it (`Raffle.sol:L539-L555`, `Raffle.sol:L339-L342`, `Raffle.sol:L468-L470`). Successful NFT redemption leaves quote liabilities unchanged and consumes the separate escrowed-prize claim (`Raffle.sol:L329-L337`).
- **Invariant coupling:** A successful redemption binds `winnerRecipient`, the burned ticket's last owner, and the asset recipient to the same `winner` local (`Raffle.sol:L320-L345`). Ticket settlement binds the ticket ID to the winning range, but intentionally does not bind an address; current ownership at redemption supplies that binding (`Raffle.sol:L314-L321`, `Raffle.sol:L528-L538`).

---

**Open Questions:**

- unclear; the deployed sponsor-selected prize implementation is not present in `target/`, so its actual `transferFrom` callback behavior and whether `ownerOf` represents a standards-compliant ownership ledger cannot be inspected. The available code establishes only ERC-165 reporting and initial post-escrow ownership, while the interface states the honest ERC-721 assumption (`RaffleFactory.sol:L127-L134`, `RaffleFactory.sol:L171-L177`; `IRaffle.sol:L12-L15`).
- unclear; the deployed immutable quote-token implementation is not present in `target/`, so exact fee-free, non-rebasing balance movement cannot be verified from its code. Those semantics are an explicit protocol assumption, and `SafeERC20` checks call/return behavior rather than recipient balance deltas (`IRaffle.sol:L12-L15`; `SafeERC20.sol:L176-L199`).
- unclear; an arbitrary contract may be the current ticket owner, and NFT delivery uses `transferFrom` rather than `safeTransferFrom`, so this path does not establish that the winner contract implements `IERC721Receiver` or can subsequently operate the prize (`Raffle.sol:L320-L334`; `IERC721.sol:L76-L91`).
