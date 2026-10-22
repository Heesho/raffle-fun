> **Provenance (added by the runner when saving; everything from the first heading down is the workflow's report, verbatim).**
> - Workflow: `spec-to-code-compliance:spec-compliance` (Trail of Bits plugin); run `wf_5507b8b7-46f`, task `wfhsuuawa`.
> - Args: `{"path": "packages/contracts/src", "spec": "DESIGN.md"}`.
> - Completed 2026-10-21: 19 agents (0 errors, 0 empty results), 427 tool uses, about 56 minutes.
> - The workflow's report agent tried to write `spec-compliance/REPORT.md`, but that write was refused ("Subagents should return findings as text, not write report files."). It returned the report as text instead, reproduced here unchanged.
> - Per-requirement analyses written by the workflow: `spec-compliance/requirements/` (10 files).

# Spec compliance: packages/contracts/src

- Documents: `DESIGN.md`, and the NatSpec in `packages/contracts/src`.
- Code: `Raffle.sol`, `RaffleFactory.sol`, `interfaces/IRaffle.sol`, `interfaces/IRaffleFactory.sol`, `libraries/RaffleConstants.sol`. Where the code relies on OpenZeppelin or Chainlink, those files were read too.
- Paths are relative to `packages/contracts/src` unless a package path is given. `@openzeppelin/...` and `@chainlink/...` are under `packages/contracts/node_modules`.
- Per-requirement analysis is in `spec-compliance/requirements/`.

## Summary

Only 10 of the 248 extracted requirements were checked, so this report cannot say whether the code as a whole does what the documents say. Of the 10:

- 8 hold.
- 1 is contradicted (REQ-23).
- 1 holds only partly (REQ-38).

The other 238 have no verdict. Their status is unknown, not compliant (see "Not checked").

Neither divergence lets anyone take another party's assets. Both concern what a sponsor can do with its own raffle, and both are low severity.

1. **REQ-38 (partial, low). Needs a code fix.** `releaseSponsorPrize` sends the prize NFT without checking at payout time whether the destination is a raffle clone (`Raffle.sol:L404`). A sponsor can set `sponsorRecipient` to the address of a clone the factory has not deployed yet. Once that clone exists, anyone can move the prize into it, and it stays there for good. Only the sponsor can set this up, and only the sponsor loses.
2. **REQ-23 (contradicted, low). Most likely a documentation fix.** The sponsor alone can close an unsold raffle before `endTime` and get the prize back (`Raffle.sol:L282`). DESIGN.md allows no such power, but the NatSpec documents it as intended: "empty-raffle cancellation authority" (`IRaffle.sol:L37`). No buyer funds can be involved.

The two documents also contradict each other on whether prize contracts are trusted (Documentation problems, item 2). That contradiction decides what the REQ-35 "holds" verdict is worth.

## Divergences, worst first

### 1. REQ-38: a prize NFT can be moved into another raffle clone

Verdict: partial. Confidence: high. Severity: low.

**What the document requires.** DESIGN.md: "Never move assets between raffle clones." The test applied: "No code path in a raffle or the factory moves USDC, prize NFTs or tickets from one raffle clone to another, or lets one clone's holdings pay another clone's liabilities; no payout can go to another clone."

**What the code does.** USDC payouts and ticket movements are checked against the factory's clone registry at the moment they happen:

- Every USDC payout goes through `_transferQuote` (`Raffle.sol:L564-L567`).
- Every ticket mint or transfer goes through `_update` (`Raffle.sol:L497-L502`).

The prize return is not checked. `releaseSponsorPrize` runs `prizeToken.transferFrom(address(this), recipient, prizeTokenId);` (`Raffle.sol:L404`), where `recipient` is the stored `sponsorRecipient`. That address is checked only when the raffle is created (`RaffleFactory.sol:L163-L169`, `Raffle.sol:L193-L195`). Both checks reject only clones that already exist:

- The factory looks the address up in `isRaffle` (`RaffleFactory.sol:L166`).
- `_isProtocolDestination` consults the registry only for an address that has code: `if (!unsafeDestination && destination.code.length != 0)` (`Raffle.sol:L602`). The NatSpec says so: "Code-less addresses are not queried in the registry." (`Raffle.sol:L589`).

Clones are deployed with `create` (`@openzeppelin/contracts/proxy/Clones.sol:L57`). A clone's address depends only on the factory's address and nonce, so it can be computed before the clone exists.

**How it is reached:**

1. Sponsor S creates raffle A and sets `sponsorRecipient` to the address a later clone deployment will produce.
   - It passes `RaffleFactory.sol:L166`, because the address is not registered yet.
   - It passes `Raffle.sol:L193`, because the address has no code and L602 skips the registry.
   - It is stored at `Raffle.sol:L198`, the field's only write.
2. Anyone, S included, calls `createRaffle` until clone B is deployed at that address. B is registered at `RaffleFactory.sol:L125`.
3. A reaches `CashWon` or `Refunding`. If A has no entries, S can force `Refunding` at once through the exemption in divergence 2 (`Raffle.sol:L282`).
4. Anyone calls `A.releaseSponsorPrize()`. There is no caller check (`Raffle.sol:L395-L400`).
   - L404 moves the prize from A to B, and L405 passes because B now owns it.
   - A plain `transferFrom` calls no receiver hook (`@openzeppelin/contracts/token/ERC721/ERC721.sol:L115-L125`), so B's `onERC721Received` guard (`Raffle.sol:L416-L431`) never runs.

**What follows:**

- **The NFT is stranded in B.** B's only NFT outflows (`Raffle.sol:L334`, `L404`) move B's own configured `prizeTokenId`. The source says such NFTs "remain outside protocol accounting and cannot be rescued" (`Raffle.sol:L410-L411`).
- **In `CashWon`, S also loses its USDC share.**
  - Released after B exists, `releaseSponsorProceeds` reverts at `Raffle.sol:L565`, and `sponsorRecipient` can never change.
  - Released before B exists, the USDC lands at B's future address (see the narrower routes below).
- **Nobody gains.** B has no code path that can move or use what it received.
- **Only the sponsor can create the precondition.** Only the `createRaffle` caller chooses `sponsorRecipient` (`RaffleFactory.sol:L112-L113`), and nobody lands on an unused CREATE address by accident.

That is why the severity is low. It is still a code path that breaks an invariant the document states.

**Two narrower routes through the same gap.** Both need the payout or ticket move to happen before the clone at that address is deployed.

- **USDC.** Proceeds released to the address before B exists pass the check (`Raffle.sol:L380`, then L565). They end up inside B but outside B's accounted balance (`Raffle.sol:L468-L470`).
- **Tickets.** A ticket minted or transferred to the address passes `Raffle.sol:L498`, and `@openzeppelin/contracts/token/ERC721/utils/ERC721Utils.sol:L32` skips the receiver hook for an address with no code. Once B is deployed it owns the ticket and can never redeem or refund it, because both actions require `msg.sender` to be the owner (`Raffle.sol:L321`, `L360`). The loser is the ticket holder who chose that recipient.

Whether these two routes count as violations depends on whether "another clone" includes an address that becomes a clone only after the transfer. DESIGN.md does not say.

**Where to fix it.** Check `recipient` in `releaseSponsorPrize` before `Raffle.sol:L404`, the same way `_transferQuote` does at L565. That keeps the invariant but does not save the sponsor's prize:

- The prize would stay stuck in A instead of B.
- `sponsorRecipient` cannot change after `Raffle.sol:L198`.
- Each raffle has "no administrator or rescue path" (`Raffle.sol:L24-L25`).

A payout-time check also cannot close the two pre-deployment routes above.

### 2. REQ-23: the sponsor can cancel an unsold raffle before `endTime`

Verdict: contradicted. Confidence: high, narrowed by the refuter (see below). Severity: low.

**What the document requires.** DESIGN.md: "No administrator, mutable configuration or upgrade." The test applied: "No account (deployer, sponsor, treasury or other) has privileged control over the factory or raffles: no owner/role, pause, cancel, rescue, parameter setter or forced withdrawal." DESIGN.md also says: "Refunds open at deadline."

**What the code does.**

```solidity
// Raffle.sol:L280-L284 (enableRefunds, status == Active)
if (totalEntries == 0) {
    deadline = endTime;
    if (msg.sender != sponsor && block.timestamp < deadline) {
        revert RefundsNotAvailable(deadline, block.timestamp);
    }
```

- While a raffle is `Active` and has no entries, only the sponsor can call `enableRefunds` before `endTime`.
- The call sets `Refunding` (`Raffle.sol:L299`), which is terminal. No status writer accepts `Refunding` as a starting state (`Raffle.sol:L177`, `L241`, `L292-L293`, `L422`, `L511`).
- Anyone can then call `releaseSponsorPrize` (`Raffle.sol:L395-L407`), which returns the prize to `sponsorRecipient`.

Together this is a cancel. Every raffle has the power from creation until its first sale: `createRaffle` returns with the raffle `Active` (`Raffle.sol:L428`, reached through the escrow at `RaffleFactory.sol:L128`), and `totalEntries` stays 0 until the first `buyEntries` (`Raffle.sol:L230`).

**What follows:**

- The sponsor can withdraw a listed prize at any time before the first sale.
- No buyer funds are ever at stake, because `unsettledPot` grows only together with `totalEntries` (`Raffle.sol:L230`, `L233`).
- A purchase that lands after the cancel costs the buyer only gas. It reverts at `Raffle.sol:L215`, before any USDC is pulled at L224. This includes a purchase the sponsor front-runs.
- The power ends at the first sale. From then on, the sold-raffle branch (`Raffle.sol:L285-L288`) applies the same deadline to every caller.
- Every other clause of the test holds: no owner or role, pause, rescue, setter, forced withdrawal or upgrade. Neither the deployer nor the treasury holds a role (see REQ-24 and REQ-25 in the matrix).

**The behaviour is intended.** The NatSpec grants it explicitly:

- `IRaffle.sol:L37`: "@param sponsor Prize depositor and empty-raffle cancellation authority."
- `IRaffle.sol:L322-L323`: "Also closes an empty raffle immediately for the sponsor and after sale end for anyone."
- `IRaffle.sol:L410` and `IRaffleFactory.sol:L33`: "pre-end empty-raffle refund authority."

**The refuter's correction.** The divergence survived refutation, but on a narrower basis:

- L282 contradicts the test supplied with the requirement, which names "sponsor" and "cancel".
- It does not clearly contradict DESIGN.md's own words, "No administrator". DESIGN.md never defines the term, and the source describes each raffle as having "no administrator or rescue path" (`Raffle.sol:L24-L25`) while granting this power.
- The DESIGN.md sentence L282 contradicts most directly is "Refunds open at deadline.", since the sponsor alone can open refunds before `endTime`.
- Confidence that L282 breaks "No administrator" itself is medium, not high.
- The requirement drawn from "Refunds open at deadline." was not among those checked.

**Where to fix it.**

- If the pre-sale cancel is intended, as the NatSpec says, fix the documents. DESIGN.md should name the exception in both sentences.
- If it is not intended, remove `msg.sender != sponsor &&` at `Raffle.sol:L282`.

## Alignment matrix

| ID | Requirement (verbatim) | Source | Verdict | Conf. | Line that decides it |
|---|---|---|---|---|---|
| REQ-38 | "Never move assets between raffle clones." | DESIGN.md L2 | **partial** | high | `Raffle.sol:L404` sends the prize with no destination check; `L602` skips the registry for addresses without code |
| REQ-23 | "No administrator, mutable configuration or upgrade." (administrator clause) | DESIGN.md L2 | **contradicted** | high (refuter: medium against the DESIGN.md text alone) | `Raffle.sol:L282` exempts the sponsor from the `endTime` gate |
| REQ-22 | "remainder must be allocated without loss" | DESIGN.md L2 | implemented | high | `Raffle.sol:L544`, `L547`: the sponsor gets the residual, so the parts sum to `grossPot`; `L553` zeroes the pot in the same call |
| REQ-24 | "No administrator, mutable configuration or upgrade." (mutable-configuration clause) | DESIGN.md L2 | implemented | high | `Raffle.sol:L176-L179`, `L197-L204`: the only writer is `initialize`, which runs once and only for the factory; immutables at `RaffleFactory.sol:L33-L42`; constants at `RaffleConstants.sol:L12-L36` |
| REQ-25 | "No administrator, mutable configuration or upgrade." (upgrade clause) | DESIGN.md L2 | implemented | high | `RaffleFactory.sol:L42`, `L91`, `L106`; `Clones.sol:L54-L57` writes the target into the clone bytecode as a PUSH20 literal; `src` has no `delegatecall` or `selfdestruct` |
| REQ-33 | "redemption requires current ticket owner" | DESIGN.md L2 | implemented | high | `Raffle.sol:L320-L321` compares a live `ownerOf` with raw `msg.sender`; `L314-L318` ties the ticket to the winning ticket |
| REQ-35 | "must revert all effects on delivery failure" | DESIGN.md L2 | implemented | high | `Raffle.sol:L334-L336`: NFT call without try/catch, then an ownership re-check; `L342` → `L566` → `SafeERC20.sol:L33-L37`; `Raffle.sol` has no try/catch |
| REQ-44 | "transaction decisions must reread current chain state" | DESIGN.md L2 | implemented (on-chain half only) | medium | `Raffle.sol:L320`, `L359`: live `ownerOf`; `L249`, `L257-L258`: live VRF price; no client code exists to check |
| REQ-009 | "Global entry price: exactly 1,000,000 raw six-decimal quote-token units, or one USDC." | `RaffleConstants.sol:L20` | implemented | high | `RaffleConstants.sol:L21` constant; the only charge is `Raffle.sol:L223` and the only refund is `L367` |
| REQ-010 | "Decimal precision required from the immutable quote token." | `RaffleConstants.sol:L23` | implemented | high | `RaffleConstants.sol:L24` (`= 6`); `RaffleFactory.sol:L71-L78` reverts unless `decimals()` equals it |

REQ-23, REQ-24 and REQ-25 test the three clauses of the same DESIGN.md sentence, each with its own test.

**What the "implemented" verdicts depend on:**

- **REQ-35.** NFT delivery is confirmed by the prize contract's own `ownerOf` (`Raffle.sol:L335`). A hostile prize contract could report a delivery that never happened. Whether such contracts are in scope is exactly where the two documents disagree (Documentation problems, item 2).
- **REQ-44.** Only the on-chain half was checked: every entry point decides from storage, `block.timestamp` and live external reads. The sentence is mainly about clients, and the tree contains no client code.
- **REQ-009 and REQ-010.** "One USDC" holds only if the quote token really is USDC. On-chain the code checks only that the token has code and reports six decimals. Confirming it is USDC is left to deployment tooling (`RaffleFactory.sol:L60-L61`), which is not in the tree.
- **REQ-22.** The internal amounts always sum exactly, but they match the tokens actually held only under the documented token model, "standard, non-rebasing, fee-free transfers" (`IRaffle.sol:L13-L14`). On reachable inputs, rounding down truncates nothing, because the pot is always `n × 1,000,000` (`Raffle.sol:L223`, `L233`).

## Undocumented behavior

**Anyone can trigger `releaseSponsorPrize`, and it skips the recipient's ERC-721 acceptance hook** (`Raffle.sol:L395-L407`). Severity: low.

- **Who can call it.** Any address, once status is `CashWon` or `Refunding` (`L396-L399`). There is no caller check; the only `msg.sender` in the function is in the event at `L406`. `Refunding` includes an empty raffle the sponsor cancelled (divergence 2).
- **How it delivers.** It uses a plain `transferFrom` (`L404`), not `safeTransferFrom`, so `onERC721Received` is never called on `sponsorRecipient`. The only check is an `ownerOf` read afterwards (`L405`). By contrast, prize escrow uses `safeTransferFrom` (`RaffleFactory.sol:L128`), and ticket mints use `_safeMint` (`Raffle.sol:L235`).
- **One shot.** `prizeClaimed` is set before the transfer (`L403`) and checked at `L400`, so one successful delivery is final.
- **No destination check at payout time.** This is the gap behind divergence 1.
- **What the documents say.** They describe a return to the sponsor's side:
  - `IRaffle.sol:L354`: "Returns the escrowed prize to the immutable sponsor recipient after `CashWon` or `Refunding`."
  - `IRaffle.sol:L32`: "the sponsor may recover the prize NFT"
  - DESIGN.md: "Refund outcome pays 100% per entry and returns prize."

  Only an event parameter says a third party can trigger the return (`IRaffle.sol:L174`: "Address that triggered the permissionless release."). Nothing says the hook is skipped.
- **When it matters.** Only when `sponsorRecipient` is a contract.
  - A recipient that records incoming NFTs only in `onERC721Received` gets this one unrecorded, at a moment a stranger picks, and the claim flag blocks a retry. Whether it can recover the NFT depends on its own code, which is outside the tree.
  - A recipient that cannot handle ERC-721s at all loses the NFT either way. A safe transfer would revert and leave the NFT in escrow, where it would be just as stuck: the recipient cannot change (`Raffle.sol:L198`), and there is no rescue path (`Raffle.sol:L24-L25`).
  - EOAs are unaffected.
- **The winner's delivery.** It also uses a plain `transferFrom` (`Raffle.sol:L334`), but there the recipient must be the caller (`L320-L321`). Only the sponsor-side delivery can be triggered by a third party.

## Documentation problems

1. **Sponsor cancellation: DESIGN.md and the NatSpec disagree.** This was recorded against REQ-23, and the fix belongs in the documents.
   - DESIGN.md says "No administrator, mutable configuration or upgrade." and "Refunds open at deadline." with no exception.
   - The NatSpec makes the sponsor an "empty-raffle cancellation authority" (`IRaffle.sol:L37`; also `IRaffle.sol:L322-L323`, `L410`, `IRaffleFactory.sol:L33`).
   - The same source says each raffle has "no administrator or rescue path" (`Raffle.sol:L24-L25`). The authors evidently do not count the sponsor's pre-sale cancel as administration. DESIGN.md does not define "administrator".
2. **The documents contradict each other on whether prize contracts are trusted.**
   - DESIGN.md: "arbitrary prize contracts and ticket recipients are untrusted."
   - `IRaffle.sol:L14-L15`: "Supported prizes are honest, standards-compliant ERC-721s."

   This matters because delivery and escrow are confirmed through the prize contract's own `ownerOf` (`Raffle.sol:L335`, `L405`; `RaffleFactory.sol:L129`). Under DESIGN.md's model, a hostile contract that fakes those reads is in scope, and nothing in the code can detect it. Under the NatSpec's model, it is simply unsupported. The requirement drawn from this DESIGN.md sentence was not checked. The documents need to pick one model.
3. **"Refunds open at deadline." does not say which deadline.** The code uses three:
   - `endTime` for an empty raffle (`Raffle.sol:L281`).
   - `endTime` + 2 days for a sold raffle with no draw request (`L286`, `L459`).
   - Request time + 2 days once a draw has been requested (`L290`, `L464`).

   On top of these is the sponsor's early exception (`L282`). `IRaffle.sol:L322-L323` describes the code's behaviour; DESIGN.md does not.
4. **Rounding is specified only for the protocol fee.** DESIGN.md says "Rounding is floor on aggregate protocol fee; remainder must be allocated without loss." It does not say who receives a remainder, or how the 80% winner share is rounded. The code also rounds the winner share down (`Raffle.sol:L546`) and gives what is left to the sponsor (`L547`). The NatSpec says so: "The cash-winner allocation is rounded down; the sponsor receives the remaining raw units." (`IRaffle.sol:L328`). On reachable inputs nothing changes (see REQ-22), so this is a documentation fix only.
5. **Files the documents depend on are not in the tree.**
   - "transaction decisions must reread current chain state" is aimed mainly at clients. There is no client code, and "current" (latest, safe or finalized block) is undefined.
   - `package.json:L15`, `L23` and `L25` reference `scripts/check-coverage.mjs`, `ignition/modules/RaffleFun.ts` and `scripts/write-deployment.ts`, and none of them exists. The deploy-time USDC identity check that `RaffleFactory.sol:L60-L61` assigns to tooling therefore cannot be verified.
   - The source does show that a factory deployed behind a proxy could not create raffles: `Raffle.sol:L161` records the deployer as `factory`, and `L178` rejects every other caller.
6. **"redemption requires current ticket owner" leaves two points open.** It does not say whether the owner must be the caller or only the recipient, or whether approved operators may redeem. The code requires the caller to be the owner (`Raffle.sol:L321`), and the NatSpec agrees (`IRaffle.sol:L270`, `L333`). This is minor, and the NatSpec settles it.

## Not checked

**238 of the 248 extracted requirements have no verdict.** Their status is unknown, not compliant.

- From the DESIGN.md series REQ-01 to REQ-44, 36 requirements: REQ-01 to REQ-21, REQ-26 to REQ-32, REQ-34, REQ-36, REQ-37, and REQ-39 to REQ-43.
- From the REQ-001 to REQ-204 series, 202 requirements: REQ-001 to REQ-008 and REQ-011 to REQ-204. The two members of this series that were checked quote NatSpec in `RaffleConstants.sol`.

**No checked requirement quotes these DESIGN.md statements:**

- "Ethereum NFT raffle; immutable factory, ERC-1167 clones with immutable implementation."
- "One purchase mints a transferable ERC721 ticket representing a contiguous inclusive range."
- "Exactly one ERC721 prize is escrowed atomically at creation."
- "Reserve met awards NFT and 95% sponsor / 5% treasury."
- "Reserve missed awards 80% gross to winner, 15% sponsor, 5% treasury."
- "Refund outcome pays 100% per entry and returns prize."
- "Rounding is floor on aggregate protocol fee"
- "Request window [sale end, end+2days); callback accepted strictly before request timestamp+2days."
- "Refunds open at deadline."
- "Callback records result only."
- "Settlement is permissionless, storage-only" and "burns claim atomically"
- "Sponsor and treasury can claim independently after settlement."
- "Quote token and Chainlink wrapper are trusted canonical dependencies; arbitrary prize contracts and ticket recipients are untrusted."
- "Frontend discovery is advisory"

Evidence gathered for other requirements touches some of these. For example, REQ-22's arithmetic walks the 95/5 and 80/15/5 splits at `Raffle.sol:L540-L547`. That evidence supports the requirement it was gathered for; it is not a verdict on these statements. "One entry costs 1,000,000 units of canonical six-decimal USDC." is covered in substance by REQ-009 and REQ-010, which check the NatSpec version of the same rule.

Nothing else is missing:

- No requirement check failed outright.
- Both documents were read.
- No divergence was left unverified by failed refutation agents.

## Considered and dropped

- None. Refutation knocked down no divergence. The one refutation that changed anything narrowed REQ-23's basis and confidence (divergence 2) without dropping it.
