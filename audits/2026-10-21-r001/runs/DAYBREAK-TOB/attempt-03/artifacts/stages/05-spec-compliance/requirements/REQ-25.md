## REQ-25 — Refund prize return targets the escrow source

> "Refund outcome pays 100% per entry and returns prize."
> — DESIGN.md:L2, sentence 7

**Verdict:** partial · confidence: high

---

**What this demands of an implementation:** The supplied checkable definition limits this record to the prize-return clause: whenever an escrow-bearing raffle reaches the refund outcome, the configured ERC-721 prize must be returnable to the party from whom it was escrowed. In the canonical creation path, that party is the `createRaffle` caller: the factory records `msg.sender` as `sponsor` and pulls the prize from `msg.sender` (`target/packages/contracts/src/RaffleFactory.sol:L109-L128`). The separate “pays 100% per entry” clause is outside REQ-25's supplied checkable definition and is not judged here.

---

**Where enforcement lives:**

The factory creates a clone, records the caller and the caller-selected return recipient as different fields, and escrows the prize from the caller:

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L109-L120
IRaffle(raffle)
    .initialize(
        IRaffle.RaffleInitParams({
        sponsor: msg.sender,
        sponsorRecipient: params.sponsorRecipient,
        protocolTreasury: protocolTreasury,
        prizeToken: params.prizeToken,
        prizeTokenId: params.prizeTokenId,
        raffleId: raffleId,
        reserveEntries: params.reserveEntries,
        endTime: params.endTime
    })
    );
```

```solidity
// target/packages/contracts/src/RaffleFactory.sol:L127-L134
IERC721 prize = IERC721(params.prizeToken);
prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
if (prize.ownerOf(params.prizeTokenId) != raffle) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
if (IRaffle(raffle).status() != IRaffle.Status.Active) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
```

The clone persists those identities separately (`target/packages/contracts/src/Raffle.sol:L176-L205`). Its receiver additionally requires the prize transfer's reported `from` to equal `sponsor`, which ties the accepted deposit to the factory caller rather than to `sponsorRecipient` (`target/packages/contracts/src/Raffle.sol:L409-L430`). The interface describes the same distinction: `sponsor` is the prize depositor, while `sponsorRecipient` receives any returned prize (`target/packages/contracts/src/interfaces/IRaffle.sol:L36-L47`).

Every live refund-enabling branch converges on `Status.Refunding`:

```solidity
// target/packages/contracts/src/Raffle.sol:L276-L300
function enableRefunds() external override nonReentrant {
    uint256 deadline;

    if (status == Status.Active) {
        if (totalEntries == 0) {
            deadline = endTime;
            if (msg.sender != sponsor && block.timestamp < deadline) {
                revert RefundsNotAvailable(deadline, block.timestamp);
            }
        } else {
            deadline = drawRequestDeadline();
            if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
        }
    } else if (status == Status.Drawing) {
        deadline = callbackDeadline();
        if (block.timestamp < deadline) revert RefundsNotAvailable(deadline, block.timestamp);
    } else {
        revert InvalidStatus(status);
    }

    uint256 liability = unsettledPot;
    unsettledPot = 0;
    remainingRefundLiability = liability;
    status = Status.Refunding;
    emit RefundsEnabled(msg.sender, liability);
}
```

The prize-release entrypoint accepts that state and performs a transfer plus an ownership check, but it always chooses the separately configured `sponsorRecipient`:

```solidity
// target/packages/contracts/src/Raffle.sol:L395-L406
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

Creation validates that `sponsorRecipient` is nonzero and is not listed protocol plumbing, but never requires it to equal either `msg.sender` or the stored `sponsor` (`target/packages/contracts/src/RaffleFactory.sol:L152-L179`; `target/packages/contracts/src/Raffle.sol:L181-L205`). The `nonReentrant` modifier brackets the release body and rejects nested protected calls, but does not alter its destination (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L62-L73`, `L88-L105`).

---

**Paths walked:**

- `RaffleFactory.constructor` → `new Raffle`: the shared implementation fixes its factory and dependencies and locks only the implementation's own storage as initialized/`Refunding` (`target/packages/contracts/src/RaffleFactory.sol:L65-L91`; `target/packages/contracts/src/Raffle.sol:L151-L166`). That object has no configured escrow; the escrow-bearing path is the clone path below.
- `createRaffle` → `Clones.clone` → `Raffle.initialize`: the factory creates the fixed-target clone and is its one permitted initializer (`target/packages/contracts/src/RaffleFactory.sol:L97-L121`; `target/packages/contracts/src/Raffle.sol:L176-L205`). `sponsor = msg.sender` and `sponsorRecipient = params.sponsorRecipient` remain independent (`target/packages/contracts/src/RaffleFactory.sol:L109-L120`; `target/packages/contracts/src/Raffle.sol:L197-L205`).
- `createRaffle` → prize `safeTransferFrom` → `onERC721Received`: the outgoing owner argument is `msg.sender`, and acceptance requires `from == sponsor`; successful creation then verifies clone ownership and `Active` status (`target/packages/contracts/src/RaffleFactory.sol:L127-L134`; `target/packages/contracts/src/Raffle.sol:L416-L430`). This establishes the escrow source used by the requirement.
- `enableRefunds`, `Active` with zero entries: the sponsor may enter the branch before sale end and anyone may do so at or after sale end; it reaches `Refunding` (`target/packages/contracts/src/Raffle.sol:L276-L300`).
- `enableRefunds`, sold `Active` raffle: at or after the draw-request deadline it reaches `Refunding` (`target/packages/contracts/src/Raffle.sol:L279-L300`).
- `enableRefunds`, `Drawing` raffle: at or after the callback deadline it reaches `Refunding` (`target/packages/contracts/src/Raffle.sol:L289-L300`).
- `Refunding` → `releaseSponsorPrize`, with `sponsorRecipient == sponsor`: the configured recipient is the escrow source, so the transfer and post-transfer ownership check satisfy the assigned property (`target/packages/contracts/src/Raffle.sol:L395-L406`). ✓
- `Refunding` → `releaseSponsorPrize`, with `sponsorRecipient != sponsor`: creation permits this configuration, yet release transfers only to `sponsorRecipient`; no branch transfers to `sponsor` (`target/packages/contracts/src/RaffleFactory.sol:L109-L128`, `L152-L179`; `target/packages/contracts/src/Raffle.sol:L395-L406`). ✗ — the gap.
- Other prize-consumption path: `redeemWinningTicket` transfers the prize only for `NftWon`; it rejects `Refunding`, so it cannot supply an alternative return-to-depositor path (`target/packages/contracts/src/Raffle.sol:L309-L345`).
- Modifier/base path: `releaseSponsorPrize` is an external `nonReentrant` entrypoint (`target/packages/contracts/src/Raffle.sol:L395-L406`), and the inherited guard executes before and after its body (`target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L105`). The inherited OpenZeppelin `ERC721` manages raffle tickets; the prize is instead the external `IERC721` stored in `prizeToken` (`target/packages/contracts/src/Raffle.sol:L28-L29`, `L69-L73`, `L395-L405`).

---

**Searched:**

- Full supplied scope → read all five production files and all 31 Solidity dependencies listed in `target/dependency-hashes.json`; recomputation matched 31 of 31 listed SHA-256 values.
- `refund|refunding` → 64 matches across the supplied Solidity scope. Relevant implementation hits are the refund transition and prize-release state gate in `Raffle.sol:L276-L300` and `L395-L406`; dependency hits in `ReentrancyGuard.sol` concern gas refunds, not raffle outcomes.
- `escrow|return.{0,24}prize|prize.{0,24}(return|release|recover)` → 35 matches. Relevant source paths identify the deposit at `RaffleFactory.sol:L127-L134` and the only refund/cash prize release at `Raffle.sol:L395-L406`.
- `releaseSponsorPrize|SponsorPrizeReleased|SponsorPrizeUnavailable` → 6 matches: the implementation and its three associated symbol sites in `Raffle.sol:L395-L406`, plus the interface's event, error, and function declaration at `IRaffle.sol:L178-L180`, `L292-L294`, and `L354-L355`.
- `releaseSponsorPrize\s*\(` → 2 matches, the interface declaration and implementation only (`target/packages/contracts/src/interfaces/IRaffle.sol:L355`; `target/packages/contracts/src/Raffle.sol:L395`). There is no in-scope wrapper or caller that substitutes another destination.
- `sponsorRecipient` → 26 matches. Its write is separate from `sponsor` (`target/packages/contracts/src/Raffle.sol:L197-L205`), and the prize release reads it at `Raffle.sol:L402-L405`.
- `sponsorRecipient\s*(==|!=)\s*(msg.sender|params.sponsor|sponsor)` and the reversed comparison → 0 matches across the five production files and 31 dependencies. The complete creation validator instead contains only nonzero/protocol-destination checks for the recipient (`target/packages/contracts/src/RaffleFactory.sol:L152-L179`).
- `reclaim|withdraw|rescue|recover` → 6 matches. The only relevant positive hit says the sponsor may recover the prize in `IRaffle.sol:L32`; the `rescue` hits state that no rescue path exists or discuss unrelated forced NFTs (`Raffle.sol:L24-L26`, `L409-L411`; `RaffleFactory.sol:L15-L20`; `IRaffleFactory.sol:L6-L9`).
- `(prizeToken|prize)\.(safeTransferFrom|transferFrom)` → 3 matches: escrow from `msg.sender` (`RaffleFactory.sol:L127-L128`), delivery to an NFT winner (`Raffle.sol:L329-L335`), and refund/cash return to `sponsorRecipient` (`Raffle.sol:L402-L405`). No prize-transfer operation targets `sponsor`.
- Exact `status =` writes → 6 lines: locked implementation `Refunding`, clone `AwaitingPrize`, `Drawing`, live `Refunding`, `Active`, and terminal draw result (`target/packages/contracts/src/Raffle.sol:L164-L165`, `L205`, `L252`, `L299`, `L428`, `L521`). No live transition leaves `Refunding`.

---

**How the verdict was reached:** The release mechanism is real rather than nominal: all three live refund-enabling branches set `Refunding`, and `releaseSponsorPrize` admits that state, transfers the configured prize, and verifies the configured recipient (`target/packages/contracts/src/Raffle.sol:L276-L300`, `L395-L406`). It is not `implemented`, however, because the factory escrows from `msg.sender` while accepting an independent `sponsorRecipient`, and neither creation nor initialization enforces equality between them (`target/packages/contracts/src/RaffleFactory.sol:L109-L128`, `L152-L179`; `target/packages/contracts/src/Raffle.sol:L176-L205`). It is `partial`, rather than `contradicted`, because configurations where those addresses are equal do return the prize to the escrow source; permitted configurations where they differ do not. The mismatch is fixed before the external prize call—its `recipient` argument and ownership comparison both use `sponsorRecipient`—so unknown behavior of a concrete prize implementation does not reduce confidence in this verdict (`target/packages/contracts/src/Raffle.sol:L402-L405`).

---

**Open questions:**

- No open question affects the verdict. The concrete sponsor-selected prize implementation is outside the supplied source, so its actual `transferFrom` and `ownerOf` behavior cannot be established; the production interface explicitly assumes honest, standards-compliant prizes (`target/packages/contracts/src/interfaces/IRaffle.sol:L12-L15`), while the factory only checks reported interface support and creation-time custody (`target/packages/contracts/src/RaffleFactory.sol:L127-L134`, `L171-L177`). The address-selection gap above exists independently of those external semantics (`target/packages/contracts/src/Raffle.sol:L402-L405`).
