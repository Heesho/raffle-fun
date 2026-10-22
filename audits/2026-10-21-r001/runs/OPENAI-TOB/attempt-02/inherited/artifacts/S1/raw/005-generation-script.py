from pathlib import Path
import hashlib, json, os

root = Path.cwd()
raw = Path('audit/S1/raw')
raw.mkdir(parents=True, exist_ok=True)
analysis_path = Path('audit/S1/audit-context/functions/04-redeemWinningTicket.md')
analysis_path.parent.mkdir(parents=True, exist_ok=True)
prose = r'''## `redeemWinningTicket` in target/packages/contracts/src/Raffle.sol (L309-L346)

**Purpose:** Converts the winning ticket's transferable bearer claim into delivery to its current owner. It optionally performs the liability allocation first, then records the recipient, burns the ticket, and executes either the NFT or cash branch. Permissionless settlement alone allocates claims without paying the winner; this entrypoint consumes that claim (Raffle.sol L304-L346, L533-L558).

Source abbreviations below refer to `target/packages/contracts/src/Raffle.sol` as Raffle, its sibling `RaffleFactory.sol` as Factory, `src/libraries/RaffleConstants.sol` as Constants, and `src/interfaces/IRaffle.sol` as IRaffle. ERC721, SafeERC20, ReentrancyGuard, StorageSlot, Math, Panic and SafeCast refer to the files with those names under `target/packages/contracts/node_modules/@openzeppelin/contracts/`. External prize and quote implementations are not supplied by their interface definitions.

---

**Inputs & Assumptions:**

- `ticketId` (`uint256`) is untrusted calldata. Before settlement its stored inclusive range must contain `winningEntry`; after settlement it must exactly equal `winningTicketId` (Raffle L314-L318, L538, L579-L585). The range check alone does not establish ticket existence: `ticketRange` merely reads historical mapping values, and `ownerOf` separately establishes a live ticket (Raffle L451-L455; ERC721 L61-L63, L426-L431).
- `msg.sender` is untrusted. It must equal the current ERC721 owner, without accepting a per-ticket approval or operator approval as redemption authority (Raffle L320-L321). Ownership can change before redemption because inherited transfer functions remain callable and Raffle's update override does not restrict lifecycle state (ERC721 L115-L136; Raffle L497-L502).
- Implicit storage inputs are `winnerRedeemed`, `status`, `settlementComplete`, `winningTicketId`, current ERC721 ownership, `prizeClaimed`, `prizeToken`, `prizeTokenId`, and `winnerProceeds`; the optional settlement also reads the historical range, `winningEntry`, and `unsettledPot` (Raffle L310-L342, L533-L558, L579-L585).
- Entry requires an unconsumed claim and the `NftWon` or `CashWon` result, enforced locally at Raffle L310-L312. The function reads no clock and sets no redemption deadline (entire body Raffle L309-L346).
- One-based, nonoverlapping ticket ranges come from the positive purchase count and cumulative counters at Raffle L218-L232. The draw selects an entry in `[1,totalEntries]` at Raffle L518-L521; `requestDraw` rejects zero sold entries at L243. The range helper itself does not re-establish positivity (L579-L585).
- Canonical USDC has standard, fee-free, non-rebasing transfer behavior: this is an explicit trust assumption in IRaffle L12-L15 and Raffle L560-L561, not established by SafeERC20. Factory checks code and six reported decimals, and explicitly assigns token identity verification to deployment tooling (Factory L58-L77). Nothing found in redemption establishes actual recipient balance increase.
- The arbitrary configured prize contract's ownership report corresponds to real ownership: nothing found independently establishes this. Redemption checks the same external contract's `ownerOf` after calling its `transferFrom` (Raffle L334-L336). IRaffle L14-L15 states the supported-prize honesty assumption, but the interface cannot enforce an implementation's behavior.
- Atomic rollback on revert is the chain execution assumption supplied by the orientation. Thus failures after local effects undo those effects and the call's subcall effects; the relevant reverting operations are Raffle L330-L342 and the callee rejection paths identified below.

---

**Outputs & Effects:**

- Returns named `cashAmount`: zero in the NFT branch, or the entire nonzero winner allocation in the cash branch (Raffle L309, L329-L342). Calling `_settleWinningTicket` does not assign its returned amount here; cash redemption explicitly reloads `winnerProceeds` at L339.
- Successful redemption writes `winnerRecipient = ownerOf(ticketId)` and `winnerRedeemed = true`, then removes ERC721 ownership, decreases the former owner's ticket balance and clears the token approval (Raffle L323-L325; ERC721 L216-L244, L303-L308, L383-L399). Historical ticket ranges, `ticketCount` and `totalEntries` remain unchanged on this path (Raffle L138-L139, L309-L346, L497-L502).
- NFT success sets `prizeClaimed`, calls `prizeToken.transferFrom(this,winner,prizeTokenId)`, and accepts only a subsequent ownership report equal to the winner (Raffle L329-L337). This is a checked report from the external prize contract, not independent proof of that contract's ledger semantics.
- Cash success sets `winnerProceeds = 0` before `_transferQuote(winner,cashAmount)` (Raffle L339-L342). It does not consume sponsor or protocol balances. If settlement runs in this transaction, it first allocates both balances and zeroes `unsettledPot` (Raffle L551-L555).
- Events include the ticket's ERC721 `Transfer(owner,0,ticketId)` during burn, optional `WinningTicketSettled`, and final `WinningTicketRedeemed(ticketId,winner,result,cashAmount,deliveredPrizeToken,deliveredPrizeTokenId)` after delivery checks (ERC721 L242; Raffle L557, L345). In the cash branch the prize event fields stay zero; in the NFT branch they contain the configured prize (Raffle L327-L333; IRaffle L131-L145).
- The guard sets its per-instance slot to ENTERED before the body and NOT_ENTERED after successful completion (ReentrancyGuard L69-L73, L94-L117). A revert does not leave the intermediate guard or claim writes committed under the orientation's rollback assumption.

---

**Block-by-Block:**

```solidity
// Raffle L309-L312
function redeemWinningTicket(uint256 ticketId) external override nonReentrant returns (uint256 cashAmount) {
    if (winnerRedeemed) revert WinningTicketAlreadyRedeemed();
    Status result = status;
    if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);
```

- **What:** Enters the shared guard, rejects a previously consumed winner, and caches a terminal winning result.
- **Why here:** Establishes the admissible lifecycle and prevents repeated execution before settlement or ownership work (Raffle L310-L315).
- **Assumes:** Guard-slot storage resolves correctly; StorageSlot returns precisely the requested storage location (StorageSlot L93-L97). The guard tests equality to ENTERED, so a clone's initial zero slot is accepted and then written, without requiring its constructor to execute (ReentrancyGuard L94-L117).
- **Establishes:** During this guarded frame, another entrypoint using this same guard fails its before check; this is not a blanket prohibition on unguarded reads or inherited ERC721 methods (ReentrancyGuard L88-L113; ERC721 L93-L136).
- **Depended on by:** The branch at Raffle L329 and all subsequent claim writes.

```solidity
// Raffle L314-L321
if (!settlementComplete) {
    _settleWinningTicket(ticketId);
} else if (ticketId != winningTicketId) {
    revert WinningTicketMismatch(ticketId, winningTicketId);
}
address winner = ownerOf(ticketId);
if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);
```

- **What:** Either validates the winning range and allocates balances, or uses the previously fixed winning ID, then obtains a live current owner and demands that owner as caller.
- **Why here:** Binding the ID precedes ownership authorization, so settlement does not pin a recipient and tickets retain their bearer nature until redemption (Raffle L314-L323, L551-L555).
- **Assumes:** Previously completed settlement bound the ID using `_requireWinningTicket`, established in the sole settlement assignment path (Raffle L538, L551-L552). ERC721 `ownerOf` returns a nonzero owner or reverts; it does not call the external prize contract (ERC721 L61-L63, L146-L148, L426-L431).
- **Establishes:** On continuation, the selected ID is the winning ID, the ticket exists, and caller equals owner. An unauthorized caller can execute the optional settlement internally, but its later ownership failure reverts that transaction's allocations and settlement event (Raffle L315-L321, L551-L557; rollback assumption).
- **Depended on by:** `_burn` deliberately performs no caller authorization of its own, and the payout destination is the owner captured here (ERC721 L303-L308; Raffle L323-L342).

```solidity
// Raffle L323-L328
winnerRecipient = winner;
winnerRedeemed = true;
_burn(ticketId);
address deliveredPrizeToken = address(0);
uint256 deliveredPrizeTokenId = 0;
```

- **What:** Records the final beneficiary, consumes the winner flag and ticket, and defaults the NFT event fields to zero.
- **Why here:** All three claim-consumption effects land before either mutable external asset call; no external call lies between the ownership check and burn on this burn path (Raffle L320-L334; Raffle L497-L502; ERC721 L216-L244, L303-L308).
- **Assumes:** ERC721 ownership and balance accounting agree. ERC721 decrements the owner's balance in an unchecked block; this is established by its shared mint/transfer/burn update discipline rather than a fresh nonzero-balance check (ERC721 L216-L244, L259-L267).
- **Establishes:** The burned ticket has zero owner and cleared single-token approval before callbacks. The zero `to` also bypasses Raffle's destination-screening branch, so burning invokes no factory getter (Raffle L498-L501).
- **Depended on by:** The external prize or quote call cannot see an unconsumed winning ticket via ordinary ownership reads (Raffle L334, L342; ERC721 L426-L431).

```solidity
// Raffle L329-L337
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

- **What:** Consumes the prize flag, calls the arbitrary prize implementation with zero native value and `(from=this,to=winner,tokenId=configuredId)`, then checks its ownership response.
- **Why here:** `prizeClaimed` joins the burned ticket and winner flag before control leaves the raffle; a failed flag check, transfer or postcondition aborts the burn as part of the same transaction (Raffle L323-L337; rollback assumption).
- **Assumes:** A non-reverting transfer and matching ownership report reflect delivery; nothing found provides an independent check. The external contract may revert, return adversarial ownership data, execute custom callbacks or perform other external state changes during transfer (Raffle L334-L336; implementation absent).
- **Establishes:** On success the prize contract reported the winner as owner. The `ownerOf` interface is view, so its query is read-only; it can still reject or supply false data (IERC721 L33-L39). Redemption uses `transferFrom`, not the interface's safe-transfer variants, so this code does not request a recipient acceptance callback (Raffle L334; IERC721 L55-L91).
- **Depended on by:** Final redemption event publication (Raffle L345). The NFT branch leaves the named cash return at zero (Raffle L309, L329-L337).

```solidity
// Raffle L338-L345
} else {
    cashAmount = winnerProceeds;
    if (cashAmount == 0) revert NoWinnerProceeds();
    winnerProceeds = 0;
    _transferQuote(winner, cashAmount);
}
emit WinningTicketRedeemed(ticketId, winner, result, cashAmount, deliveredPrizeToken, deliveredPrizeTokenId);
```

- **What:** For the only remaining admitted result, CashWon, captures a positive full claim, zeroes it and pays the owner before recording redemption.
- **Why here:** The liability is consumed before the quote contract can execute; the event follows the helper's screening and transfer acceptance (Raffle L339-L345, L564-L567).
- **Assumes:** SafeERC20's accepted call result means the trusted quote token transferred exactly the amount. Nothing found in `_transferQuote` checks a before/after balance delta (Raffle L564-L567; SafeERC20 L176-L200).
- **Establishes:** On success `winnerProceeds` is zero and the returned amount equals the pre-payment allocation. Recipient screening or token failure rolls back the claim consumption and burn (Raffle L323-L325, L339-L342, L565-L566; rollback assumption).
- **Depended on by:** `accountedQuoteBalance` no longer includes the paid winner liability, while sponsor and protocol liabilities remain separately claimable (Raffle L375-L392, L468-L470).

---

**Cross-Function Dependencies:**

- **`nonReentrant` (internal modifier):** `_nonReentrantBeforeView` rejects only ENTERED, `_nonReentrantBefore` writes ENTERED, `_nonReentrantAfter` writes NOT_ENTERED, and the slot helper is constant (ReentrancyGuard L69-L117; StorageSlot L93-L97). All raffle asset release entrypoints use this guard (Raffle L309, L349, L375, L385, L395). Unguarded methods remain separately callable; a late randomness handler observes a non-Drawing status and exits (Raffle L509-L516).
- **`_settleWinningTicket` (internal, every path):** rejects an already completed settlement or a non-winning status, validates the range, and reads the gross pot. NftWon allocates `gross - floor(gross*500/10000)` to the sponsor and no cash winner allocation. CashWon allocates `floor(gross*8000/10000)` to the winner and the remainder after that and protocol fees to the sponsor. It then records completion and ID, zeroes the gross liability, stores the two remaining allocations and emits settlement; no asset call or ownership read is made in this helper (Raffle L533-L558; Constants L12-L21). Conservation follows directly from the remainder subtraction; checked subtraction can reject inconsistent arithmetic before writes (Raffle L544-L555).
- **`_requireWinningTicket` and `ticketRange` (internal):** the former rejects only if selected entry is below the first bound or above the last. The latter returns stored historical bounds, including defaults for absent IDs, without ownership checks (Raffle L451-L455, L579-L585). Redemption's subsequent `ownerOf` supplies the missing existence assertion (Raffle L320).
- **`Math.mulDiv` (internal library):** `mul512` computes the high/low product. If high is zero, ordinary division returns the floor and division by zero reverts; otherwise denominator not exceeding high triggers Panic, and the remaining path removes the remainder and computes the exact quotient via a modular inverse (Math L37-L46, L206-L277). The error helper's ternary normalizes its boolean through SafeCast and Panic always reverts (Math L143-L150; SafeCast L1157-L1161; Panic L50-L56). Here denominator is constant 10,000 and rates are 500/8,000 (Constants L12-L18); canonical `grossPot` is at most `uint128.max * 1,000,000` from the purchase counter bound and cumulative gross accounting, keeping both products below 256 bits (Raffle L219-L233). Thus these reachable settlement inputs use the low-product branch; the alternative library paths were also inspected.
- **`ownerOf`, `_burn`, `_update`, `_approve` (internal inherited chain):** `ownerOf` delegates through `_requireOwned` to the ownership mapping and rejects zero; `_burn` invokes virtual `_update(0,id,0)` and rejects a zero previous owner afterward (ERC721 L61-L63, L146-L148, L303-L308, L426-L431). Raffle skips destination screening for zero and delegates to the base update (Raffle L497-L502). The base skips authorization for zero auth, clears per-token approval for a nonzero old owner, decrements that owner's balance, does not increment a zero recipient, writes zero owner and emits Transfer (ERC721 L216-L244). The approval helper's event/auth branch is skipped because both controls are false/zero; it still clears storage (ERC721 L383-L399). Authorization is therefore supplied by Raffle L321, not the burn helper. The nonzero-auth and nonzero-recipient update paths belong to inherited transfers; their authority path checks owner/operator/single-token approval (ERC721 L164-L187, L220-L237).
- **`prizeToken.transferFrom` and `prizeToken.ownerOf` (external black boxes):** the interface supplies signatures only, not the configured implementation. Transfer gets zero native value and the exact NFT tuple; ownership query gets the configured ID and must decode to the winner (Raffle L334-L336; IERC721 L39, L91). Both can fail; the transfer can execute arbitrary code, and the ownership result remains an external report. Earlier factory escrow similarly checks a report from the prize contract (Factory L127-L134).
- **`_transferQuote` / `_isProtocolDestination` (internal):** screening rejects this raffle, its factory, quote token, wrapper, configured prize token, factory implementation and registered same-factory raffle addresses. Disjunction short-circuiting avoids later comparisons/calls once matched; otherwise `raffleImplementation()` is queried, and only a destination with code that remains unclassified is queried through `isRaffle(destination)` (Raffle L564-L567, L593-L605). This screening can reject a current owner; no transfer executes on rejection.
- **Factory getters (external source available):** `raffleImplementation` is an immutable set in the constructor, while `isRaffle` is a public mapping set on creation (Factory L42, L54, L89-L91, L123-L125). These provide same-factory classification, not a proof that every other contract can use received USDC. No native value is passed by the view calls (Raffle L598-L603).
- **`SafeERC20.safeTransfer` / `_safeTransfer` (internal library) and `quoteToken.transfer` (external black box):** the wrapper passes `bubble=true`; the assembly call forwards gas, zero native value and ERC20 `transfer(to,amount)` calldata (SafeERC20 L33-L37, L176-L184). A reverted call bubbles its revert data. A successful call is accepted when the examined return word equals 1, or when return data is empty and the token address has code; otherwise the wrapper reverts (SafeERC20 L187-L199). There is no recipient balance check or exact-length requirement on the first-word-1 path in this code (L184-L196). The quote implementation may reject transfers under its own rules; its standard exact-value accounting is the explicit canonical-token assumption (IRaffle L12-L15; Raffle L560-L566; IERC20 L35-L41).
- **Callers:** This is an external ABI entrypoint for arbitrary callers; only the current owner can pass L321. No internal caller is present in Raffle's source (Raffle L309-L346). Sponsor, buyer, permissionless settler and approved operator identities do not independently authorize redemption (Raffle L304-L321).
- **Shared state and invariant couplings:** `buyEntries` writes ranges/pot/counters; randomness resolution selects entry/result; the two settlement entry paths share allocation and ID writes; payout functions consume their separate sponsor/protocol balances; `releaseSponsorPrize` shares `prizeClaimed` but is restricted to CashWon or Refunding; refunds require Refunding (Raffle L209-L237, L304-L306, L349-L392, L395-L407, L509-L558). Terminal winning results and refund processing therefore use different locally checked paths. The winning ticket may move between settlement and redemption, and the beneficiary is resolved only when L320 executes (Raffle L314-L325; ERC721 L115-L125).

---

**Open Questions:**

- Unclear; need to inspect the actual sponsor-selected prize implementation to establish that its transfer and ownership-report behavior match the supported honest ERC721 assumption. Nothing found in the interface or the paired call/report check independently establishes this (IRaffle L14-L15; Raffle L334-L336).
- Unclear; need to inspect deployment dependency selection and the canonical quote implementation to establish token identity and exact-value transfer behavior. The source deliberately places canonical identity outside its metadata checks, and redemption has no balance-delta verification (Factory L58-L77; Raffle L560-L566; SafeERC20 L176-L200). Live-chain verification is outside this context task.
'''

response = {
 'function':'redeemWinningTicket',
 'file':'target/packages/contracts/src/Raffle.sol',
 'lines':'L309-L346',
 'analysisFile':str(analysis_path),
 'invariants':[
  {'claim':'Successful redemption requires an unconsumed winner, a winning terminal result, the winning ticket ID and caller equal to its current live owner.','evidence':'Raffle.sol L310-L321; L538, L551-L552; ERC721.sol L426-L431'},
  {'claim':'Recipient, redeemed flag and ticket burn precede either mutable external asset call.','evidence':'Raffle.sol L323-L334, L339-L342; ERC721.sol L303-L308, L216-L244'},
  {'claim':'NFT success requires prizeClaimed set and a post-transfer ownership report equal to winner; cash success consumes the entire positive winnerProceeds before transfer.','evidence':'Raffle.sol L329-L342'},
  {'claim':'Optional settlement preserves gross allocation conservation and binds the ID without selecting a recipient or sending assets.','evidence':'Raffle.sol L533-L558; RaffleConstants.sol L12-L21'},
  {'claim':'NFT branch returns zero cash; cash branch returns the consumed amount and zero NFT event fields.','evidence':'Raffle.sol L309, L327-L345'}
 ],
 'assumptions':[
  {'claim':'Winning range represents an existing current owner at redemption.','establishedBy':'Range membership: Raffle.sol L538, L579-L585; existence separately established by L320 and ERC721.sol L426-L431. ticketRange alone merely returns stored bounds at Raffle.sol L451-L455.'},
  {'claim':'Burn is authorized even though its internal helper skips sender authorization.','establishedBy':'Raffle.sol L320-L321 supplies authorization before ERC721.sol L303-L308 calls _update with zero auth; ERC721.sol L220-L222 skips the auth branch.'},
  {'claim':'The prize contract reports real ownership after transfer.','establishedBy':'nothing found; Raffle.sol L334-L336 trusts the same configured external contract for both operations; IRaffle.sol L14-L15 states the supported-prize honesty assumption.'},
  {'claim':'The quote token transfers the exact amount without fees or rebasing and is canonical USDC.','establishedBy':'nothing found as a runtime delivery/identity proof; explicit trust model at IRaffle.sol L12-L15 and Raffle.sol L560-L561; Factory L58-L77 checks metadata and assigns identity verification to deployment tooling.'},
  {'claim':'ERC721 owner balances agree with ownership before unchecked burn decrement.','establishedBy':'Shared ERC721.sol _update accounting L216-L244 and mint checks L259-L267; no independent balance assertion at burn.'}
 ],
 'calls':[
  {'callee':'nonReentrant / guard storage helpers','kind':'internal','propagates':'Rejects ENTERED, sets ENTERED before body and NOT_ENTERED after; zero initial clone storage is accepted. ReentrancyGuard.sol L69-L117; StorageSlot.sol L93-L97.'},
  {'callee':'_settleWinningTicket -> _requireWinningTicket -> ticketRange','kind':'internal','propagates':'Validates winning status/range, allocates gross liabilities and binds ID once; never establishes live ownership or recipient. Raffle.sol L533-L558, L579-L585, L451-L455.'},
  {'callee':'Math.mulDiv -> mul512 / ternary -> SafeCast.toUint / Panic.panic','kind':'internal','propagates':'Floor multiplication/division; zero denominator or excessive quotient rejects. Canonical bounded gross uses the low-product branch. Math.sol L37-L46, L143-L150, L206-L277; SafeCast.sol L1157-L1161; Panic.sol L50-L56; Raffle.sol L219-L233.'},
  {'callee':'ownerOf -> _requireOwned -> _ownerOf','kind':'internal','propagates':'Reads local ticket owner and rejects nonexistent/burned IDs; no prize call. ERC721.sol L61-L63, L146-L148, L426-L431.'},
  {'callee':'_burn -> Raffle._update -> ERC721._update -> _approve','kind':'internal','propagates':'Burn skips destination screening and auth checks, clears per-ticket approval and ownership, decrements owner balance and emits Transfer; caller must authorize first. Raffle.sol L321, L497-L502; ERC721.sol L216-L244, L303-L308, L383-L399.'},
  {'callee':'prizeToken.transferFrom(this,winner,id)','kind':'external-black-box','propagates':'Zero-value mutable call may reject, reenter unguarded interfaces or implement arbitrary behavior; claim state is consumed before it. Raffle.sol L323-L334; IERC721.sol L91.'},
  {'callee':'prizeToken.ownerOf(id)','kind':'external-black-box','propagates':'Read-only query must decode to winner or redemption fails; truthful ownership is not independently established. Raffle.sol L335-L336; IERC721.sol L39.'},
  {'callee':'_transferQuote -> _isProtocolDestination','kind':'internal','propagates':'Rejects known protocol destinations before token call; registry queried only for code-bearing addresses not already classified. Raffle.sol L564-L567, L593-L605.'},
  {'callee':'Factory.raffleImplementation / Factory.isRaffle','kind':'external-source-available','propagates':'Immutable implementation and registration mapping support same-factory destination screening. Factory.sol L42, L54, L89-L91, L123-L125; Raffle.sol L601-L603.'},
  {'callee':'SafeERC20.safeTransfer -> _safeTransfer','kind':'internal','propagates':'Bubbles revert; accepts successful first return word 1 or empty return from code-bearing token, otherwise rejects. Does not measure balances. SafeERC20.sol L33-L37, L176-L200.'},
  {'callee':'quoteToken.transfer(winner,cashAmount)','kind':'external-black-box','propagates':'Receives zero native value and full winner allocation after zeroing liability; exact accounting depends on canonical-token trust assumption. Raffle.sol L339-L342, L560-L566; SafeERC20.sol L176-L196.'}
 ],
 'callers':['External arbitrary caller; current owner must pass Raffle.sol L321; approvals alone do not authorize this entrypoint (L309-L321).'],
 'sharedState':['Winner/result/ranges and settlement allocation: Raffle.sol L209-L237, L304-L306, L509-L558.','Winner recipient/redeemed flag/proceeds, prizeClaimed and ERC721 ownership: Raffle.sol L323-L342, L395-L407; ERC721.sol L216-L244.','Sponsor/protocol separate releases and total accounted liabilities: Raffle.sol L375-L392, L468-L470.'],
 'openQuestions':[
  'unclear; need to inspect the configured prize implementation to establish truthful transfer and ownership-report semantics; paired external calls alone do not establish them (Raffle.sol L334-L336; IRaffle.sol L14-L15).',
  'unclear; need to inspect deployment dependency selection and canonical quote implementation to establish identity and exact-value transfers (Factory.sol L58-L77; Raffle.sol L560-L566). Live-chain verification is outside this context task.'
 ]
}

paths = [
 'audit/AGENT-RULES.md','audit/S1/native/005-request.json',
 'audit/resources/plugins__audit-context-building__agents__function-analyzer.md',
 'audit/resources/plugins__audit-context-building__skills__audit-context-building__resources__ANALYSIS_FORMAT.md',
 'audit/resources/plugins__audit-context-building__skills__audit-context-building__resources__FUNCTION_MICRO_ANALYSIS_EXAMPLE.md',
 'audit/resources/plugins__audit-context-building__skills__audit-context-building__resources__DOMAIN_NOTES.md',
 'target/packages/contracts/src/Raffle.sol','target/packages/contracts/src/RaffleFactory.sol',
 'target/packages/contracts/src/interfaces/IRaffle.sol','target/packages/contracts/src/interfaces/IRaffleFactory.sol',
 'target/packages/contracts/src/libraries/RaffleConstants.sol',
 'target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol',
 'target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol',
 'target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol',
 'target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol',
 'target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol',
 'target/packages/contracts/node_modules/@openzeppelin/contracts/utils/StorageSlot.sol',
 'target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol',
 'target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SafeCast.sol',
 'target/packages/contracts/node_modules/@openzeppelin/contracts/utils/Panic.sol'
]
manifest = []
readlog = []
pinned_root = '/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits'
for p in paths:
 data = Path(p).read_bytes()
 entry = {'path':p,'absolutePath':str(root/p),'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)}
 if p.startswith('audit/resources/'):
  entry['pinnedOriginPath'] = pinned_root + '/' + Path(p).name.replace('__','/')
 manifest.append(entry)
 readlog.append('\nFILE '+p+'\n'+''.join(f'{i:6}\t{line}\n' for i,line in enumerate(data.decode().splitlines(),1)))

def fresh(path, data):
 path = Path(path)
 if path.exists():
  raise RuntimeError('Refusing to replace original: '+str(path))
 path.write_bytes(data)

fresh(raw/'005-analysis-original.md', prose.encode())
fresh(analysis_path, prose.encode())
fresh(raw/'005-resource-read.txt',''.join(readlog).encode())
fresh(raw/'005-resources.json', (json.dumps({'task':'005','accepted_model':'gpt-6-astra','accepted_effort':'ultra','provider_returned_model':'unknown','provider_returned_effort':'unknown','fallback_enabled':False,'resources':manifest},indent=2)+'\n').encode())
request = json.loads(Path('audit/S1/native/005-request.json').read_text())
schema = request['options']['schema']
for required in schema['required']:
 assert required in response
for field in ['invariants','assumptions','calls']:
 for value in response[field]:
  assert all(key in value for key in schema['properties'][field]['items']['required'])
for call in response['calls']:
 assert call['kind'] in schema['properties']['calls']['items']['properties']['kind']['enum']
payload = (json.dumps(response,indent=2)+'\n').encode()
fresh(raw/'005-response-original.json',payload)
native = Path('audit/S1/native/005-response.json')
assert not native.exists()
temp = native.with_suffix('.json.tmp-005')
fresh(temp,payload)
os.replace(temp,native)
completion={'analysisFile':str(analysis_path),'responseFile':str(native),'resourcesFile':str(raw/'005-resources.json'),'rawAnalysisFile':str(raw/'005-analysis-original.md'),'rawResponseFile':str(raw/'005-response-original.json')}
fresh(raw/'005-completion.json',(json.dumps(completion,separators=(',',':'))+'\n').encode())
fresh(raw/'005-validation.txt',b'Required schema keys, nested record keys and call-kind enums checked. Original and published response bytes identical. Prose and resource manifest saved before atomic publication.\n')
assert native.read_bytes() == (raw/'005-response-original.json').read_bytes()
print(json.dumps(completion,separators=(',',':')))
