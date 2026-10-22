from pathlib import Path
import json,hashlib,os
root=Path.cwd()
prose='''## `createRaffle` in target/packages/contracts/src/RaffleFactory.sol (L97-L148)

**Purpose:** Creates a fixed-target clone, configures it, publishes its canonical identity, and requires both a prize ownership report and an Active lifecycle state before emitting the creation event. These operations form the single factory creation path (RaffleFactory.sol:L97-L148).

---

**Inputs & Assumptions:**
- `params` is untrusted sponsor input containing `address sponsorRecipient`, `address prizeToken`, `uint256 prizeTokenId`, `uint128 reserveEntries`, and `uint64 endTime` (interfaces/IRaffleFactory.sol:L14-L26). `msg.sender` becomes both the stored sponsor and the transfer source (RaffleFactory.sol:L112,L128).
- The immutable implementation, treasury and quote token are trusted deployment inputs/state (RaffleFactory.sol:L33-L42,L65-L92). The implementation's factory identity is established when the factory deploys it and the Raffle constructor stores `msg.sender` (RaffleFactory.sol:L89-L91; Raffle.sol:L155-L166).
- `block.timestamp` is the implicit clock. A future end no more than 30 days away is enforced here, after prize-interface screening (RaffleFactory.sol:L98-L104; libraries/RaffleConstants.sol:L29-L30).
- Successful creation requires the sponsor's selected prize contract to accept a factory-initiated transfer from the sponsor. Ownership and transfer authorization are delegated to that contract; the supplied IERC721 interface describes those requirements but is not its implementation (RaffleFactory.sol:L128; IERC721.sol:L61-L73). An honest ledger and truthful ownership report are assumptions established by **nothing found** in this source; factory checks establish reported ownership and a matching callback, not the external ledger's honesty (RaffleFactory.sol:L129-L134; Raffle.sol:L421-L430; interfaces/IRaffle.sol:L14-L15).
- The guard must start outside an entered invocation. ReentrancyGuard constructor initializes its storage to 1, and the modifier rejects 2 before setting 2 and executing the body (ReentrancyGuard.sol:L50-L59,L69-L73,L88-L105).

---

**Outputs & Effects:**
- Returns the clone address; increments `raffleCount`; sets both ID/address mappings and registration (RaffleFactory.sol:L97,L105-L125).
- Writes clone initialization fields and its initialization latch; sets AwaitingPrize, then relies on the configured prize callback to set Active (Raffle.sol:L176-L206,L416-L431).
- Calls the sponsor-selected prize contract for interface support, transfer and ownership; no native value is attached and Clones receives zero value (RaffleFactory.sol:L128-L129,L172; Clones.sol:L32-L33).
- Emits `RaffleCreated` after both postchecks; successful receiver activation emits `PrizeDeposited` earlier (RaffleFactory.sol:L129-L147; Raffle.sol:L428-L429).
- Failure is not caught around cloning, initialization, transfer, ownership or status checks. Their failure propagates, reverting the creation's count, registration, clone creation and logs under the execution environment's atomic rollback assumption (RaffleFactory.sol:L105-L147). The interface-support call has an explicit catch that substitutes `UnsupportedPrizeToken` (L171-L177).

---

**Block-by-Block:**

```solidity
// RaffleFactory.sol:L97-L98
function createRaffle(CreateRaffleParams calldata params) external override nonReentrant returns (address raffle) {
    _validateCreateParams(params);
```
- **What:** Enters the factory guard and validates prize contract, recipient, reported interface support, and positive reserve.
- **Why here:** Screening precedes allocation of an ID or deployment (L98,L105-L106).
- **Assumes:** Interface support is a report from an arbitrary address, not proof of honest behavior; nothing found establishing more (L172-L177).
- **Establishes:** `_requireContract` rejects zero code; forbidden prize destinations include this factory, quote token, wrapper, implementation and registered raffles. Recipient screening additionally rejects zero and the selected prize (L154-L169,L183-L185). Interface false and caught call failure revert; reserve zero reverts (L171-L178).
- **Depended on by:** Deployment and initialize use these vetted inputs (L106-L121). Sponsor and treasury screening, and comparison of the recipient with the new clone itself, are additionally established inside initialize rather than here (Raffle.sol:L181-L195,L599-L604).

```solidity
// RaffleFactory.sol:L99-L106
uint256 currentTime = block.timestamp;
if (params.endTime <= currentTime) revert InvalidEndTime(currentTime, params.endTime);
uint256 saleDuration = uint256(params.endTime) - currentTime;
if (saleDuration > RaffleConstants.MAX_SALE_DURATION) {
    revert SaleDurationTooLong(saleDuration, RaffleConstants.MAX_SALE_DURATION);
}
uint256 raffleId = ++raffleCount;
raffle = Clones.clone(raffleImplementation);
```
- **What:** Rejects expired/immediate ends and durations above 30 days, allocates the next ID, deploys a clone.
- **Why here:** The order establishes a nonnegative subtraction and validates timing before changing the count (L100-L105).
- **Assumes:** The implementation contains the intended code; `Clones.clone` does not verify implementation code (Clones.sol:L28-L30). The factory's own `new Raffle` and immutable assignment establish its target here (RaffleFactory.sol:L89-L91).
- **Establishes:** The single-argument clone forwards value zero to the two-argument form; assembly embeds the implementation and uses CREATE. Zero-address deployment failure reverts (Clones.sol:L32-L61). Count increment and subtraction use Solidity 0.8 checked arithmetic with no unchecked block (RaffleFactory.sol:L2,L99-L106).
- **Depended on by:** Initialization and registry writes refer to this exact address and ID (L109-L125).

```solidity
// RaffleFactory.sol:L109-L125, initializer fields abbreviated
IRaffle(raffle).initialize(IRaffle.RaffleInitParams({ /* L112-L119 */ }));
raffleById[raffleId] = raffle;
idByRaffle[raffle] = raffleId;
isRaffle[raffle] = true;
```
- **What:** Supplies sponsor identity, selected recipient/prize/reserve/end, fixed treasury and allocated ID; then establishes bidirectional canonical registration (L112-L125).
- **Why here:** The clone is configured before the untrusted transfer, and callbacks during that transfer can already read its registration (L109-L128).
- **Assumes:** Fresh clone storage is separate from implementation storage, which is the clone model documented in Raffle.sol:L151-L152 and implemented by fixed delegate bytecode in Clones.sol:L54-L57. Initialization is restricted to the immutable factory and one execution (Raffle.sol:L177-L179).
- **Establishes:** `initialize` rejects already initialized/wrong caller, zeros, and unsafe sponsor/treasury/recipient destinations before writing configuration and AwaitingPrize (Raffle.sol:L176-L206). `_isProtocolDestination` compares the new clone itself, factory, quote token, wrapper, prize and factory implementation, and checks `isRaffle` only for an otherwise allowed destination with code (Raffle.sol:L593-L604). Short-circuit paths do not query the registry when an earlier comparison already rejects, or when the destination has no code (L599-L604).
- **Depended on by:** Receiver matching uses the stored sponsor, prize, ID, factory and lifecycle; the factory later reads the same clone's status (Raffle.sol:L421-L430; RaffleFactory.sol:L132).

```solidity
// RaffleFactory.sol:L127-L134
IERC721 prize = IERC721(params.prizeToken);
prize.safeTransferFrom(msg.sender, raffle, params.prizeTokenId);
if (prize.ownerOf(params.prizeTokenId) != raffle) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
if (IRaffle(raffle).status() != IRaffle.Status.Active) {
    revert PrizeEscrowVerificationFailed(raffle, params.prizeToken, params.prizeTokenId);
}
```
- **What:** Crosses the untrusted prize boundary, then checks returned ownership and canonical clone lifecycle.
- **Why here:** Identity and registration already exist, while the public creation event waits for both checks (L123-L147).
- **Assumes:** `safeTransferFrom` implements actual transfer/approval rules and `ownerOf` is truthful; **nothing found** establishes either for arbitrary `params.prizeToken`. IERC721.sol:L61-L73 describes intended semantics only. The interface and ownership methods are view calls, while transfer may execute arbitrary mutating callbacks (IERC165.sol:L24; IERC721.sol:L39,L73).
- **Establishes:** The actual prize receiver accepts only AwaitingPrize, exact prize caller/token ID, sponsor `from` and factory `operator`; then it changes status to Active, emits deposit and returns its selector (Raffle.sol:L421-L430). It does not call `ownerOf`; that separate observation occurs in the factory (RaffleFactory.sol:L129).
- **Depended on by:** Event consumers can rely on both observed postconditions at return, conditional on external ownership honesty. `nonReentrant` blocks nested creation on the factory, while public registry reads remain callable and the clone has separate storage (ReentrancyGuard.sol:L88-L117; RaffleFactory.sol:L45-L54,L97; Raffle.sol:L151-L152). No claim that arbitrary prize callbacks cannot call other contracts or the clone follows from this factory guard (same citations).
- **Failure paths:** Transfer revert propagates; ownership revert/invalid return cannot produce a successful comparison; a mismatching owner or non-Active status triggers `PrizeEscrowVerificationFailed` (L128-L134). The two checks establish observations after the external call, not a blanket claim that no callback activity occurred (L128-L134).

```solidity
// RaffleFactory.sol:L136-L147
emit RaffleCreated(raffleId, raffle, msg.sender, params.sponsorRecipient,
    params.prizeToken, params.prizeTokenId, quoteToken, protocolTreasury,
    params.reserveEntries, params.endTime);
```
- **What:** Publishes canonical identity and all creation configuration after both escrow checks (L129-L147).
- **Why here:** A failed postcheck cannot publish a successful creation event under atomic rollback (L129-L147).
- **Assumes:** Indexers respect transaction success and atomic rollback, as given by the orientation's chain-execution assumption.
- **Establishes:** Successful-return event matches the initialized input tuple and registry ID/address (L112-L125,L136-L147).
- **Depended on by:** The interface documents this event as describing initialized, registered, funded and active clones (interfaces/IRaffleFactory.sol:L30-L52).

---

**Cross-Function Dependencies:**
- Internal `_validateCreateParams` / `_requireContract`: full paths inspected; every failed local requirement reverts and only reported interface support is tested (RaffleFactory.sol:L154-L185).
- Internal `ReentrancyGuard.nonReentrant`: before/after helpers, entered-state read and slot helper inspected. `StorageSlot.getUint256Slot` assigns the requested storage slot through assembly (ReentrancyGuard.sol:L69-L117; StorageSlot.sol:L93-L97). This is instance storage, not a global lock.
- Internal `Clones.clone(address)` → `clone(address,uint256)`: zero value, balance check, fixed-target bytecode, CREATE and failure check inspected; no constructor of Raffle runs during clone creation (Clones.sol:L32-L61; Raffle.sol:L151-L152).
- Source-available external `Raffle.initialize` → internal `_isProtocolDestination` → source-available factory generated `raffleImplementation` and conditional `isRaffle`: authorization, configuration and AwaitingPrize dependencies are established on successful initialization only (Raffle.sol:L176-L206,L593-L604; RaffleFactory.sol:L42,L54).
- Black-box external `supportsInterface`, `safeTransferFrom`, `ownerOf`: arbitrary prize address; supplied arguments and checked observations are at RaffleFactory.sol:L172,L128-L129. Interface declarations cannot establish behavior of the chosen implementation (IERC165.sol:L24; IERC721.sol:L39,L73).
- Callback `Raffle.onERC721Received` is source-available, conditionally reached by the unknown token; it establishes activation only on the exact matching path (Raffle.sol:L416-L431).
- Source-available external generated `Raffle.status()` reads the stored lifecycle (Raffle.sol:L124; RaffleFactory.sol:L132).
- Callers are public sponsors; no caller allowlist appears in the external entry (RaffleFactory.sol:L97-L98). Initialization also rejects sponsor identities classified as protocol destinations (Raffle.sol:L187-L189).
- Shared state: factory count and bidirectional registry are declared at RaffleFactory.sol:L45-L54 and written here at L105,L123-L125; `_validateCreateParams` reads registration at L159,L166, and clone destination screening reads it at Raffle.sol:L603. Initialization and deposit callback couple the factory transaction to clone state (Raffle.sol:L176-L206,L416-L431).

---

**Open Questions:**
- unclear; need to inspect each actual sponsor-selected prize implementation to establish transfer authorization, ownership-report fidelity, callback ordering, and ownership persistence beyond the observations at RaffleFactory.sol:L128-L134. Its address is runtime input (interfaces/IRaffleFactory.sol:L20-L26).

**Execution note:** The native instructions request a tool named `Write`. No filesystem `Write` tool is exposed in this runtime; tool discovery found no equivalent local Write endpoint. That exact native tool step is INCOMPLETE. This prose was saved through the available shell file-writing capability; source analysis was performed, and this substitution is recorded rather than represented as a successful Write-tool invocation.
'''
base='target/packages/contracts/'
f='target/packages/contracts/src/RaffleFactory.sol'
r='target/packages/contracts/src/Raffle.sol'
record={'function':'createRaffle','file':f,'lines':'L97-L148','analysisFile':'audit/S1/audit-context/functions/01-createRaffle.md','invariants':[
{'claim':'On successful return, the new ID and clone are registered bidirectionally and isRaffle is true.','evidence':f+':L105-L125'},
{'claim':'End time is strictly future and at most 30 days ahead; reserve is positive.','evidence':f+':L99-L104,L178; target/packages/contracts/src/libraries/RaffleConstants.sol:L29-L30'},
{'claim':'Creation returns only after the prize reports the clone owner and the clone reports Active.','evidence':f+':L128-L134'},
{'claim':'Factory nested creation is rejected by its instance guard; registry publication precedes prize transfer.','evidence':f+':L97,L123-L128; target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L105'}],
'assumptions':[
{'claim':'Clone target contains the intended fixed implementation; Clones does not check code (Clones.sol:L28-L30).','establishedBy':f+':L89-L91 deploys and stores the immutable implementation; Clones.sol:L54-L57 embeds it.'},
{'claim':'Clone initialization is once-only and factory-only, and screens sponsor, treasury and recipient including the new clone itself.','establishedBy':r+':L176-L195,L593-L604'},
{'claim':'Actual transfer enforces sponsor ownership and factory approval; ownership reports truthfully describe an honest persistent prize ledger (factory call/check at L128-L134).','establishedBy':'nothing found'},
{'claim':'Active means the configured prize caller supplied matching token ID, sponsor and factory callback arguments while AwaitingPrize.','establishedBy':r+':L421-L430; factory requires Active at RaffleFactory.sol:L132-L134'}],
'calls':[
{'callee':'_validateCreateParams → _requireContract','kind':'internal','propagates':f+':L154-L185: code presence, screened addresses, reported ERC721 support, positive reserve; every rejected path reverts.'},
{'callee':'ReentrancyGuard.nonReentrant → before/after/entered/slot helpers → StorageSlot.getUint256Slot','kind':'internal','propagates':base+'node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol:L69-L117 and StorageSlot.sol:L93-L97 establish factory instance lock for the body and restore it on success.'},
{'callee':'Clones.clone(address) → clone(address,uint256)','kind':'internal','propagates':base+'node_modules/@openzeppelin/contracts/proxy/Clones.sol:L32-L61 deploys zero-value fixed-target proxy or reverts; no implementation-code verification.'},
{'callee':'Raffle.initialize','kind':'external-source-available','propagates':r+':L176-L206 establishes initialized latch, factory authorization, destination checks, stored configuration and AwaitingPrize on success.'},
{'callee':'Raffle._isProtocolDestination','kind':'internal','propagates':r+':L593-L604 screens same-factory plumbing and queries registration only on nonmatching destinations with code.'},
{'callee':'RaffleFactory.raffleImplementation / isRaffle generated getters','kind':'external-source-available','propagates':f+':L42,L54 read trusted implementation/registry for Raffle.sol:L601-L603; no mutations.'},
{'callee':'IERC165(params.prizeToken).supportsInterface','kind':'external-black-box','propagates':f+':L171-L177 requires a true ERC721 support report; failure/false revert, honesty not established. IERC165.sol:L24 is a declaration only.'},
{'callee':'IERC721(params.prizeToken).safeTransferFrom','kind':'external-black-box','propagates':f+':L128 sends sponsor, clone, token ID without value; assumes real transfer semantics, can revert or execute callbacks; source for selected token unavailable.'},
{'callee':'Raffle.onERC721Received (token callback)','kind':'external-source-available','propagates':r+':L416-L431 checks exact configured caller, token ID, from, operator and AwaitingPrize then activates and emits deposit; token determines whether to invoke it.'},
{'callee':'IERC721(params.prizeToken).ownerOf','kind':'external-black-box','propagates':f+':L129-L131 accepts only returned clone address; truthful external ledger not established; IERC721.sol:L39 is declaration only.'},
{'callee':'Raffle.status generated getter','kind':'external-source-available','propagates':r+':L124 exposes lifecycle; factory L132-L134 requires Active.'}],
'callers':[f+':L97 external entry available to public sponsors; Raffle.sol:L187-L189 additionally screens stored sponsor.'],
'sharedState':[f+':L45-L54,L105,L123-L125 count and registry; read by validation L159,L166 and Raffle.sol:L603.',r+':L176-L206 initializes configuration, latch and status; callback L428 changes status.'],
'openQuestions':['unclear; need to inspect each actual sponsor-selected prize implementation for authorization, ownership honesty and callback ordering; RaffleFactory.sol:L128-L134 only checks reports and clone status.']}
pp=Path(record['analysisFile']);pp.write_text(prose)
Path('audit/S1/raw/002-analysis-original.md').write_text(prose)
files=['audit/AGENT-RULES.md','audit/S1/native/002-request.json',f,r,base+'src/interfaces/IRaffle.sol',base+'src/interfaces/IRaffleFactory.sol',base+'src/libraries/RaffleConstants.sol',base+'node_modules/@openzeppelin/contracts/proxy/Clones.sol',base+'node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol',base+'node_modules/@openzeppelin/contracts/utils/StorageSlot.sol',base+'node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol',base+'node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol']
resources=['plugins__audit-context-building__agents__function-analyzer.md','plugins__audit-context-building__skills__audit-context-building__resources__ANALYSIS_FORMAT.md','plugins__audit-context-building__skills__audit-context-building__resources__FUNCTION_MICRO_ANALYSIS_EXAMPLE.md','plugins__audit-context-building__skills__audit-context-building__resources__DOMAIN_NOTES.md']
files += ['audit/resources/'+n for n in resources]
origin=root.parents[1]/'upstreams/trailofbits'
entries=[]
for p in files:
 b=Path(p).read_bytes();e={'path':str(root/p),'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b)}
 if p.startswith('audit/resources/'):
  e['pinnedOriginPath']=str(origin/p.split('/')[-1].replace('__','/'));e['pinnedRevision']='82fe8226252622fa807643bdca1710901198553a'
 entries.append(e)
manifest={'resources':entries,'requestedModel':'gpt-6-astra','requestedEffort':'ultra','providerReturnedModel':'unknown','providerReturnedEffort':'unknown','fallbackEnabled':False,'nativeWriteToolStep':'INCOMPLETE: no local Write tool exposed; prose persisted via exec_command Python.','readOutputLogs':['audit/S1/raw/002-resource-read.txt','audit/S1/raw/002-callee-read.txt','audit/S1/raw/002-interfaces-read.txt']}
Path('audit/S1/raw/002-resources.json').write_text(json.dumps(manifest,indent=2)+'\n')
b=(json.dumps(record,indent=2)+'\n').encode();Path('audit/S1/raw/002-response-original.json').write_bytes(b)
tmp=Path('audit/S1/native/002-response.json.tmp');tmp.write_bytes(b);os.replace(tmp,'audit/S1/native/002-response.json')
completion={'response':'audit/S1/native/002-response.json','analysis':'audit/S1/audit-context/functions/01-createRaffle.md','resources':'audit/S1/raw/002-resources.json','rawResponse':'audit/S1/raw/002-response-original.json','rawAnalysis':'audit/S1/raw/002-analysis-original.md'}
Path('audit/S1/raw/002-completion.json').write_text(json.dumps(completion,separators=(',',':'))+'\n')
print(json.dumps(completion,separators=(',',':')))
