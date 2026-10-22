from pathlib import Path
import hashlib, json, os
root=Path.cwd()
prose=r'''## `_settleWinningTicket` in target/packages/contracts/src/Raffle.sol (L533-L558)

**Purpose:** Converts the recorded sales pot into terminal winner, sponsor and protocol liabilities exactly once after the randomness handler has selected a winning entry and result. It proves the caller-supplied range ticket before assigning those liabilities, but leaves ownership authorization and asset delivery to redemption. Without this allocation step, the payout functions have no populated balances to consume (Raffle.sol L304-L321, L339-L342, L375-L390, L533-L558).

---

**Inputs & Assumptions:**

- `ticketId` (`uint256`) is untrusted. The public settlement caller can supply any value; redemption passes its caller-supplied value when settlement is pending. Neither route restricts who may submit a proof before this helper runs (Raffle.sol L304-L305, L309-L321).
- Implicit state comprises `settlementComplete`, `status`, `winningEntry`, `_ticketRanges`, and `unsettledPot`. Caller identity is used only as the event's executor; no timestamp, owner lookup, native payment or external balance is consulted by the helper (Raffle.sol L533-L558, L579-L585).
- Entry requires no previous settlement and a result of `NftWon` or `CashWon`, enforced locally before any computation or writes (Raffle.sol L534-L536).
- A real result carries a one-based winning entry. This is established upstream: `requestDraw` rejects zero total entries before entering `Drawing`, and the successful `fulfillRandomWords` path computes `(word % totalEntries) + 1`, records it, and then sets the result status. The ignored callback path returns without establishing a result (Raffle.sol L241-L252, L509-L523). This is essential because the downstream range getter does not validate ticket existence: an unassigned mapping entry returns a zero range (Raffle.sol L451-L455, L579-L585).
- Inclusive ranges form a one-based partition of sold entries. Each purchase requires positive entry count and bounded total entries, derives the next range from the preceding total, assigns a fresh sequential ticket ID and stores the new range before increasing the pot. These are upstream construction facts; the proof helper only compares the supplied interval with the selected entry (Raffle.sol L218-L235, L579-L585).
- The pot represents internally recorded purchases. `buyEntries` adds `entryCount * ENTRY_PRICE` after the token transfer call; settlement uses that stored amount, not the contract's actual token balance. Equality between this ledger and spendable tokens relies on the stated canonical non-rebasing, fee-free token semantics; a token balance delta is not checked in this path (Raffle.sol L223-L233, L539-L540, L560-L566). Nothing found locally establishes actual token backing independently of that token assumption.
- Winner, sponsor and protocol liabilities are zero before the first settlement in the normal lifecycle. They have default-zero declarations, their allocation writes occur only here, their consumer functions only clear them, and `settlementComplete` prevents allocating twice. The helper does not explicitly assert those balances are zero before overwriting sponsor/protocol balances or leaving the NFT winner balance untouched (Raffle.sol L99-L106, L127, L339-L341, L376-L388, L534, L548-L555).
- The arithmetic denominator and rates are fixed: 10,000 basis points, 500 protocol basis points and 8,000 cash-winner basis points. Their sum is at most the denominator, so both remainder expressions stay nonnegative. This is established by constants rather than runtime rate checks (RaffleConstants.sol L12-L18; Raffle.sol L540-L547).

---

**Outputs & Effects:**

- The named return `cashAmount` is zero on the NFT path and `floor(grossPot * 8000 / 10000)` on the cash path. Only the cash path assigns `winnerProceeds` (Raffle.sol L533, L543-L548; Math.sol L200-L215).
- Both paths mark settlement complete, store the proven ticket ID, clear `unsettledPot`, and assign sponsor and protocol balances. They leave status, ownership, redemption status, prize state and winner recipient unchanged (Raffle.sol L548-L555).
- `WinningTicketSettled` records ticket ID, executor, result, winner cash amount, protocol fee and sponsor remainder after all allocation writes (Raffle.sol L557).
- There are no external calls, token transfers or ownership queries in this helper or its range/math callee tree. All callees are internal view/pure functions; no untrusted contract executes between proof, computation and allocation (Raffle.sol L538-L557, L451-L455, L579-L585; Math.sol L37-L46, L143-L150, L206-L277; SafeCast.sol L1157-L1161; Panic.sol L50-L56).
- Let the pre-call recorded pot be `G`, protocol allocation `P`, cash allocation `W`, and sponsor allocation `S`. NFT settlement sets `P=floor(G*500/10000)`, `W=0`, `S=G-P`; cash settlement sets `P=floor(G*500/10000)`, `W=floor(G*8000/10000)`, `S=G-P-W`. Thus `S+P+W=G` exactly, with percentage rounding residue assigned to the sponsor (Raffle.sol L539-L555; RaffleConstants.sol L12-L18; Math.sol L200-L215, L227-L275).
- In the reachable sales ledger, `G` is an integer multiple of 1,000,000, and both percentage products divide exactly by 10,000; general floor-and-remainder behavior still describes the implementation. The fixed price, purchase accumulation and settlement status guard establish this narrower case, while refunds leave the result states and clear the pot (RaffleConstants.sol L21; Raffle.sol L223-L233, L279-L299, L534-L547).

---

**Block-by-Block:**

```solidity
// Raffle.sol L534-L538
if (settlementComplete) revert SettlementAlreadyComplete();
Status result = status;
if (result != Status.NftWon && result != Status.CashWon) revert InvalidStatus(result);
_requireWinningTicket(ticketId);
```

- **What:** Rejects repeat settlement, rejects all non-result states and validates inclusive membership of `winningEntry` in the candidate ticket's stored range (Raffle.sol L534-L538, L579-L585).
- **Why here:** Every failure precedes allocation writes and arithmetic. A call rejected by the first guard does not re-run the proof and is not an idempotent successful settlement (Raffle.sol L534-L555).
- **Assumes:** Terminal status implies a positive selected entry and purchased ranges are valid, established by the successful draw-resolution path and purchase construction. The callee proves membership only; it does not check live ownership or token existence independently (Raffle.sol L218-L235, L518-L521, L451-L455, L579-L585).
- **Establishes:** Subsequent code operates on the one still-unsettled result and a range containing its selected entry. A zero/default range cannot pass for a positive selected entry (Raffle.sol L534-L538, L582-L583).
- **Depended on by:** Allocation uses the captured result and later publishes this ticket as `winningTicketId`; redemption can then validate ticket identity without recomputing membership (Raffle.sol L316-L317, L543-L552).

```solidity
// Raffle.sol L539-L541
uint256 grossPot = unsettledPot;
uint256 protocolFee = Math.mulDiv(grossPot, RaffleConstants.PROTOCOL_FEE_BPS, RaffleConstants.BPS);
uint256 sponsorAmount;
```

- **What:** Snapshots the recorded pot and computes the floor protocol allocation with the three-argument `mulDiv` overload (Raffle.sol L539-L541; Math.sol L206-L215).
- **Why here:** Both terminal outcomes pay the same protocol percentage from the same pot; one computation feeds either branch (Raffle.sol L540-L547).
- **Assumes:** Denominator is nonzero, and the quotient fits `uint256`. Constants 500 and 10,000 establish `protocolFee <= grossPot` for every `uint256 grossPot`; `mulDiv` independently rejects invalid denominators and oversized quotients (RaffleConstants.sol L12-L15; Math.sol L211-L220).
- **Establishes:** `protocolFee` is a determinate nonnegative bounded liability; no allocation state has yet changed (Raffle.sol L539-L548).
- **Depended on by:** Both sponsor-remainder formulas and final fee storage consume this result (Raffle.sol L544-L555).

```solidity
// Raffle.sol L543-L549
if (result == Status.NftWon) {
    sponsorAmount = grossPot - protocolFee;
} else {
    cashAmount = Math.mulDiv(grossPot, RaffleConstants.CASH_WINNER_BPS, RaffleConstants.BPS);
    sponsorAmount = grossPot - protocolFee - cashAmount;
    winnerProceeds = cashAmount;
}
```

- **What:** NFT settlement assigns all post-fee cash to the sponsor; cash settlement allocates the winner percentage and gives the sponsor the exact residual (Raffle.sol L543-L548).
- **Why here:** The prior two-state guard makes the `else` branch specifically `CashWon`. The winner allocation is computed before subtracting it from the sponsor remainder (Raffle.sol L536, L543-L548).
- **Assumes:** Rates fit together; 500+8000 <= 10000 establishes `protocolFee + cashAmount <= grossPot`, including independent floor rounding. The NFT path's unchanged `winnerProceeds` is zero through the first-settlement lifecycle assumption, not a zero assignment in this branch (RaffleConstants.sol L12-L18; Raffle.sol L100, L534, L543-L548).
- **Establishes:** Exact pot conservation for the newly calculated balances. In cash mode `winnerProceeds` now holds the winner allocation; in NFT mode the return value remains its default zero (Raffle.sol L533, L543-L548).
- **Depended on by:** Final balance writes, the settlement event and later cash redemption consume these values (Raffle.sol L339-L342, L554-L557).

```solidity
// Raffle.sol L551-L557
settlementComplete = true;
winningTicketId = ticketId;
unsettledPot = 0;
sponsorProceeds = sponsorAmount;
protocolFees = protocolFee;
emit WinningTicketSettled(ticketId, msg.sender, result, cashAmount, protocolFee, sponsorAmount);
```

- **What:** Publishes one settled result and replaces the unallocated pot with fixed liabilities (Raffle.sol L551-L557).
- **Why here:** Proof and amount computations complete before these assignments; all recorded amounts are in place before the event (Raffle.sol L538-L557).
- **Assumes:** Previously allocated balances are zero, as established by their default storage and one-time settlement lifecycle. There is no additive merge with earlier sponsor or protocol proceeds (Raffle.sol L103-L106, L534, L554-L555).
- **Establishes:** Any later direct settlement reverts, and redemption's settled path accepts only `winningTicketId`. Moving `G` from `unsettledPot` into the three liabilities preserves `accountedQuoteBalance` under the stated zero-preexisting-balances assumption (Raffle.sol L316-L317, L468-L469, L534, L548-L555).
- **Depended on by:** Separate sponsor and protocol releases read and clear their balances; winner redemption reads and clears the cash balance or delivers the NFT. Settlement itself does not reserve entitlement to its executor (Raffle.sol L320-L342, L375-L392, L557).

---

**Cross-Function Dependencies:**

- **Direct callee `_requireWinningTicket` (internal, Raffle.sol L579-L585):** Calls `ticketRange`, reads `winningEntry`, and reverts exactly when the selected entry is smaller than the first entry or larger than the last. Equality at either endpoint succeeds. The sole success path establishes inclusive membership. It makes no owner/existence check; positivity and range construction come from upstream state transitions (Raffle.sol L451-L455, L518-L521, L579-L585).
- **Transitive callee `ticketRange` (internal dispatch of public view function, Raffle.sol L451-L455):** Reads two fields from `_ticketRanges[ticketId]` and returns them without validation or calls. It does not prove that a ticket was minted or still exists. Historical ranges are intentionally retained after burn (Raffle.sol L138-L139, L451-L455).
- **Direct callee `Math.mulDiv(uint256,uint256,uint256)` (internal, Math.sol L206-L277):** Read across all paths. `mul512` first produces the full product. If its high word is zero, ordinary unsigned division returns the floor, with zero denominator still reverting despite `unchecked` (L208-L215). Otherwise `denominator <= high` triggers a panic for division by zero or quotient overflow (L218-L220). The remaining path subtracts the remainder, factors powers of two and uses an odd-denominator modular inverse to compute the exact floor quotient (L227-L275). The caller depends on floor rounding and full-precision arithmetic, not wrapped intermediate products. Both call sites use this three-argument overload, so the separate rounding overload at L282-L284 is not called (Raffle.sol L540, L546).
- **Transitive callee `Math.mul512` (internal, Math.sol L37-L46):** Assembly computes low and high product words from `mul`, `mulmod`, carry correction and subtraction; no further functions are called. The full product representation supports both `mulDiv` paths (Math.sol L37-L46, L208-L219).
- **Transitive panic selector `Math.ternary` and `SafeCast.toUint(bool)` (internal, Math.sol L143-L150; SafeCast.sol L1157-L1161):** On `mulDiv`'s failure path, boolean normalization yields exactly zero or one, so XOR selection returns the division-by-zero code for zero denominator and the under/overflow code otherwise (Math.sol L148, L220; SafeCast.sol L1157-L1161; Panic.sol L32-L34).
- **Transitive callee `Panic.panic` (internal, Panic.sol L50-L56):** Writes the panic selector and code to memory and unconditionally reverts; it never returns a valid amount to the caller (Math.sol L220; Panic.sol L50-L56).
- **Callers:** `settleWinningTicket` delegates unconditionally and returns the allocated cash amount. `redeemWinningTicket` delegates only before settlement; after settlement it checks the stored ID instead. Both public callers declare `nonReentrant`. Redemption then independently resolves the present ticket owner and checks `msg.sender`, so submitting a successful proof does not nominate the winner recipient (Raffle.sol L304-L321).
- **Shared state and invariant coupling:** Purchases create ranges and grow the unsettled pot; callback resolution creates the entry/result; refunds consume the same pot only in Active/Drawing and set Refunding, which settlement rejects; payout functions consume the separate allocated balances after settlement. `accountedQuoteBalance` sums all of these ledger categories. The accounting conservation claim concerns this internal sum; actual token solvency relies on the canonical token semantics stated above (Raffle.sol L223-L235, L279-L299, L339-L342, L375-L392, L468-L469, L509-L523, L534-L555).

---

**Open Questions:**

None for the source-level allocation and its complete direct/transitive callee tree. Actual token backing is recorded explicitly as an external semantic assumption rather than inferred from the pot ledger (Raffle.sol L223-L233, L539-L555, L560-L566).
'''
record={
 'function':'_settleWinningTicket','file':'target/packages/contracts/src/Raffle.sol','lines':'L533-L558','analysisFile':'audit/S1/audit-context/functions/07-_settleWinningTicket.md',
 'invariants':[
 {'claim':'Success requires an unsettled NftWon/CashWon result and inclusive membership of winningEntry in the supplied ticket range.','evidence':'Raffle.sol L534-L538, L579-L585; ticketRange L451-L455.'},
 {'claim':'New allocations sum exactly to the old unsettledPot: protocol floor(5%), cash winner floor(80%) only in CashWon, and sponsor residual.','evidence':'Raffle.sol L539-L555; libraries/RaffleConstants.sol L12-L18; Math.sol L206-L275.'},
 {'claim':'Success stores the winning ID, clears unsettledPot and locks further settlement without transferring assets or reading ticket ownership.','evidence':'Raffle.sol L533-L558; range/math callee tree Raffle.sol L451-L455, L579-L585 and Math.sol L206-L277.'}
 ],
 'assumptions':[
 {'claim':'Winning entry is positive, excluding the default zero interval despite the getter having no existence check.','establishedBy':'Raffle.requestDraw L243, L252 and successful fulfillRandomWords L518-L521; ticketRange L451-L455 returns raw mapping fields.'},
 {'claim':'Purchased ticket ranges uniquely cover sold entries.','establishedBy':'Raffle.buyEntries L218-L235 constructs sequential nonempty bounded inclusive ranges.'},
 {'claim':'Prior winner/sponsor/protocol liabilities are zero when first allocating; NFT branch leaves winnerProceeds untouched.','establishedBy':'Raffle.sol default declarations L99-L106, one-time guard L534, sole allocations L548-L555 and consumers clearing at L341, L378, L388.'},
 {'claim':'Percentage denominators are nonzero and combined allocations cannot exceed grossPot.','establishedBy':'RaffleConstants.sol L12-L18 fixes BPS=10000, protocol=500, cash winner=8000; Math.mulDiv L206-L275 returns floor quotients or reverts.'},
 {'claim':'Recorded quote liabilities have matching spendable token backing under the canonical fee-free non-rebasing transfer assumption.','establishedBy':'nothing found locally establishing an actual balance delta; Raffle.buyEntries L223-L233 records requested transfer amount and Raffle.sol L560-L562 states token semantics.'}
 ],
 'calls':[
 {'callee':'Raffle._requireWinningTicket','kind':'internal','propagates':'Inclusive membership only; reverts outside the range and does not establish ownership or existence independently (Raffle.sol L579-L585).'},
 {'callee':'Raffle.ticketRange (transitive)','kind':'internal','propagates':'Returns stored interval unchanged, including default zero fields; caller needs upstream positive winningEntry (Raffle.sol L451-L455, L518-L521).'},
 {'callee':'Math.mulDiv(uint256,uint256,uint256)','kind':'internal','propagates':'Full-precision floor quotient; low-word division path, high-word validation/panic path and remainder/inverse success path read in full (Math.sol L206-L277; call sites Raffle.sol L540, L546).'},
 {'callee':'Math.mul512 (transitive)','kind':'internal','propagates':'Returns complete high/low product words used by mulDiv branch selection and precision (Math.sol L37-L46, L208).'},
 {'callee':'Math.ternary -> SafeCast.toUint(bool) (transitive)','kind':'internal','propagates':'Normalized 0/1 boolean selects the appropriate panic code on mulDiv failure (Math.sol L143-L150, L220; SafeCast.sol L1157-L1161).'},
 {'callee':'Panic.panic (transitive)','kind':'internal','propagates':'Unconditionally reverts with encoded panic; no invalid quotient returns (Panic.sol L50-L56; Math.sol L219-L220).'}
 ],
 'callers':['Raffle.settleWinningTicket L304-L305: unconditional delegation, nonReentrant.','Raffle.redeemWinningTicket L309-L321: only delegates while unsettled; current-owner authorization follows.'],
 'sharedState':['Ranges and unsettledPot: buyEntries L226-L233; enableRefunds L296-L299.','winningEntry and result: fulfillRandomWords L518-L521.','winnerProceeds, sponsorProceeds, protocolFees: allocation L548-L555 and consumption L339-L342, L375-L392.','settlementComplete/winningTicketId: L551-L552 read by redemption L314-L317; liability sum read by accountedQuoteBalance L468-L469.'],
 'openQuestions':[]
}
paths=[
 'audit/AGENT-RULES.md','audit/S1/native/008-request.json',
 'audit/resources/plugins__audit-context-building__agents__function-analyzer.md',
 'audit/resources/plugins__audit-context-building__skills__audit-context-building__resources__ANALYSIS_FORMAT.md',
 'audit/resources/plugins__audit-context-building__skills__audit-context-building__resources__FUNCTION_MICRO_ANALYSIS_EXAMPLE.md',
 'audit/resources/plugins__audit-context-building__skills__audit-context-building__resources__DOMAIN_NOTES.md',
 'target/packages/contracts/src/Raffle.sol','target/packages/contracts/src/libraries/RaffleConstants.sol',
 'target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol',
 'target/packages/contracts/node_modules/@openzeppelin/contracts/utils/math/SafeCast.sol',
 'target/packages/contracts/node_modules/@openzeppelin/contracts/utils/Panic.sol'
]
origin='/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/'
manifest=[]
for name in paths:
 p=root/name; b=p.read_bytes(); item={'path':str(p),'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b)}
 if name.startswith('audit/resources/'):
  item['pinnedOriginPath']=origin+p.name.replace('__','/')
  item['pinnedRevision']='82fe8226252622fa807643bdca1710901198553a'
 manifest.append(item)
def save(name,data):
 p=root/name
 p.parent.mkdir(parents=True,exist_ok=True)
 if p.exists(): raise RuntimeError('refusing to overwrite '+str(p))
 if not isinstance(data,bytes): data=data.encode()
 temp=p.with_name(p.name+'.tmp')
 with temp.open('xb') as f: f.write(data)
 os.replace(temp,p)
def js(x): return json.dumps(x,indent=2,ensure_ascii=False)+'\n'
save('audit/S1/raw/008-analysis-original.md',prose)
save(record['analysisFile'],prose)
save('audit/S1/raw/008-resources.json',js(manifest))
save('audit/S1/raw/008-errors-original.json',js({'firstError':{'command':'nl -ba target/packages/contracts/src/RaffleConstants.sol && rg -n ... Math.sol && cat DOMAIN_NOTES.md','exitCode':1,'output':'nl: target/packages/contracts/src/RaffleConstants.sol: No such file or directory\n'},'resolution':'Read import at Raffle.sol L17 and corrected path to src/libraries/RaffleConstants.sol. No source changes.'}))
save('audit/S1/raw/008-execution.json',js({'accepted_model':'gpt-6-astra','accepted_effort':'ultra','provider_returned_model':'unknown','provider_returned_effort':'unknown','fallback_enabled':False,'nativeWriteTool':{'status':'BLOCKED','evidence':'No local filesystem Write tool exposed in available tool catalog. functions.exec/exec_command is available.','artifactFallback':'Wrote original prose, manifest and response atomically using exec_command Python filesystem writes; exact Write-tool invocation unsupported.'},'scope':'Source context only; no vulnerability hunt; no peer outputs read.'}))
raw=js(record)
save('audit/S1/raw/008-response-original.json',raw)
save('audit/S1/native/008-response.json',raw)
completion={'analysisFile':record['analysisFile'],'responseFile':'audit/S1/native/008-response.json','resourcesFile':'audit/S1/raw/008-resources.json','completionFile':'audit/S1/raw/008-completion.json'}
save('audit/S1/raw/008-completion.json',js(completion))
print(js(completion),end='')
