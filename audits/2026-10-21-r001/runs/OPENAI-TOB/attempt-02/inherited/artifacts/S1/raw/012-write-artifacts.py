import hashlib,json,os,pathlib,subprocess
root=pathlib.Path.cwd()
raw=root/'audit/S1/raw'
analysis_rel='audit/S1/audit-context/functions/11-_validateCreateParams.md'
analysis='''## `_validateCreateParams` in target/packages/contracts/src/RaffleFactory.sol (L154-L179)

**Purpose:** Screens sponsor-selected configuration before the factory increments its counter, creates a clone, or attempts prize escrow. It establishes code presence, specific address exclusions, reported ERC-721 interface support, and a positive reserve; `createRaffle` invokes it first and performs timing and escrow checks later (RaffleFactory.sol:L97-L105, L127-L134, L154-L179).

---

**Inputs & Assumptions:**

- `params` is untrusted calldata passed directly from public `createRaffle`. Its fields are `address sponsorRecipient`, `address prizeToken`, `uint256 prizeTokenId`, `uint128 reserveEntries`, and `uint64 endTime` (RaffleFactory.sol:L97-L98; interfaces/IRaffleFactory.sol:L14-L26). This helper reads the two addresses and reserve; it does not read the token ID or end time (RaffleFactory.sol:L154-L179).
- Implicit inputs are this factory's address, its immutable `quoteToken`, `vrfWrapper`, and `raffleImplementation`, and membership in `isRaffle` (RaffleFactory.sol:L33-L54, L158-L166). Constructor assignments establish the immutable values; successful creation sets registry membership (RaffleFactory.sol:L85-L91, L123-L125).
- Code presence is a delegated precondition, established exclusively by `_requireContract`: it reverts on zero code length and otherwise returns without further inspection (RaffleFactory.sol:L155, L181-L185).
- ERC-721 behavior is an assumption about the arbitrary prize contract. A successful `supportsInterface` response establishes only the reported boolean, not behavioral compliance; nothing found authenticates that assertion in this helper (RaffleFactory.sol:L171-L177). The interface describes the intended standard, but contains no implementation of the sponsor-selected address (IERC165.sol:L15-L24; IERC721.sol:L9-L11).
- A completed creation also needs a future sale end within the permitted duration and a successful prize transfer. Those are established later by `createRaffle`, rather than by this helper (RaffleFactory.sol:L99-L104, L127-L134).

---

**Outputs & Effects:**

The helper has no return value, persistent writes, emitted events, or asset transfers. It either returns normally or fails; its only external interaction is the typed `view` call to `prizeToken.supportsInterface(type(IERC721).interfaceId)` with no attached value (RaffleFactory.sol:L154-L179; IERC165.sol:L24).

On normal return, the prize address had deployed code at the check, neither configured address matched the enumerated prohibited destinations, the sponsor recipient was nonzero, the external call supplied a decoded `true`, and the reserve was nonzero (RaffleFactory.sol:L155-L178, L183-L184). The ABI field width additionally bounds reserve to `uint128`; there is no narrower upper bound here (interfaces/IRaffleFactory.sol:L24; RaffleFactory.sol:L178). These postconditions are validation-time facts; later clone initialization and escrow remain separate operations (RaffleFactory.sol:L105-L134).

---

**Block-by-Block:**

```solidity
// RaffleFactory.sol:L155-L156
_requireContract(params.prizeToken);
if (params.sponsorRecipient == address(0)) revert ZeroAddress();
```

**What:** Rejects a prize address without deployed code and a zero sponsor recipient. **Why here:** These cheap checks precede address classification and the external interface query (L155-L172). **Assumes:** `_requireContract` enforces code presence; its complete body does so on its only successful path (L183-L185). **Establishes:** Positive prize code length and nonzero recipient. **Depended on by:** The external query at L172 and configuration passed to initialization at L113-L115. No code-presence requirement is imposed on the sponsor recipient (L154-L179).

```solidity
// RaffleFactory.sol:L157-L162
if (
    params.prizeToken == address(this) || params.prizeToken == quoteToken || params.prizeToken == vrfWrapper
        || params.prizeToken == raffleImplementation || isRaffle[params.prizeToken]
) {
    revert UnsafeProtocolDestination(params.prizeToken);
}
```

**What:** Excludes this factory, quote token, wrapper, implementation, and already registered same-factory raffles as prize contracts (L158-L161). **Why here:** Those destinations are rejected before they can receive the interface query (L172). **Assumes:** The immutable addresses and local registry represent the intended canonical deployment, established through constructor assignments and creation registration (L85-L91, L123-L125). **Establishes:** A successful path avoids exactly the listed address set. **Depended on by:** `createRaffle` passes this prize address to initialization and uses it for the later transfer and owner query (L115, L127-L130). This is a local registry test, not classification of every externally deployed raffle contract (L54, L159).

```solidity
// RaffleFactory.sol:L163-L169
if (
    params.sponsorRecipient == address(this) || params.sponsorRecipient == quoteToken
        || params.sponsorRecipient == vrfWrapper || params.sponsorRecipient == params.prizeToken
        || params.sponsorRecipient == raffleImplementation || isRaffle[params.sponsorRecipient]
) {
    revert UnsafeProtocolDestination(params.sponsorRecipient);
}
```

**What:** Screens the sponsor recipient against the same plumbing and against the selected prize token (L164-L168). **Why here:** Configuration is screened before clone creation and initialization (L98, L105-L121). **Assumes:** Registry membership is the intended current membership test, supplied by `isRaffle` (L54, L125). **Establishes:** Recipient differs from each enumerated address and has false local registry membership when checked. **Depended on by:** Initialization receives this recipient at L113. The helper does not require recipient consent, an ERC-721 receiver interface, or distinctness from the treasury; no such predicates appear in its full body (L154-L179). Subsequent initialization performs its own destination screening, including the newly created clone's address (Raffle.sol:L193-L195, L593-L604).

```solidity
// RaffleFactory.sol:L171-L177
bool supports721 = false;
try IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
    supports721 = supported;
} catch {
    revert UnsupportedPrizeToken(params.prizeToken);
}
if (!supports721) revert UnsupportedPrizeToken(params.prizeToken);
```

**What:** Queries the sponsor-selected contract and requires a decoded `true` (L171-L177). **Why here:** Address screening has completed, while reserve checking, counter increment, deployment, registration, and escrow have not (L155-L178, L105-L134). **Assumes:** The returned claim corresponds to real ERC-721 support; nothing found establishes that correspondence. **Establishes:** Normal completion of this block requires `supported == true`; caught external-call failures and a decoded `false` both produce `UnsupportedPrizeToken` (L172-L177). This description does not assume every ABI-decoding failure is handled by the catch. **Depended on by:** The caller later invokes `safeTransferFrom` and `ownerOf` at L128-L129.

The implementation behind the prize address is unavailable for this arbitrary runtime input. It is an external black box even though the interface declaration is available. The transmitted argument is the compile-time ERC-721 interface ID and no ETH is sent (L172; IERC165.sol:L24). The typed `view` boundary provides a static call context; a malicious callee can still return an arbitrary boolean, consume gas, fail, or attempt further calls. Successful state-changing effects are excluded by static-call semantics, not by trusting the token's implementation (L172; IERC165.sol:L24). The call has no explicit gas stipend in this source; the interface's less-than-30,000-gas requirement is documentation, not a bound enforced here (IERC165.sol:L22-L24; RaffleFactory.sol:L172).

```solidity
// RaffleFactory.sol:L178
if (params.reserveEntries == 0) revert ZeroReserveEntries();
```

**What:** Rejects a zero reserve. **Why here:** It is the final predicate, following the external interface query (L171-L178). **Assumes:** The ABI supplies the declared `uint128` value (interfaces/IRaffleFactory.sol:L24). **Establishes:** Reserve is in `[1, type(uint128).max]` on success. **Depended on by:** The caller forwards reserve during initialization; the clone stores it and compares final entries against it to select the outcome (RaffleFactory.sol:L118; Raffle.sol:L203, L521).

---

**Cross-Function Dependencies:**

- **`_requireContract` — internal, RaffleFactory.sol:L183-L185:** Complete source read. Zero code length reverts `NotContract(account)`; positive code length returns. It makes no calls and establishes no interface, ownership, or token-identity properties. This is the entire code-presence condition inherited by L155.
- **`IERC165(prizeToken).supportsInterface` — external black box, RaffleFactory.sol:L172; IERC165.sol:L24:** The interface is available, but no concrete arbitrary prize implementation is selected in source. The caller depends on a valid returned boolean and rejects false or a caught call failure (L173-L177). Behavioral ERC-721 compliance remains an unenforced assumption; later `safeTransferFrom` and `ownerOf` checks supply creation-time escrow evidence but remain calls to that same selected contract (L127-L134).
- **Caller:** `createRaffle` is the sole call site in RaffleFactory.sol, is external and marked `nonReentrant`, and invokes validation before its body mutates creation state (L97-L106). It independently checks timing (L99-L104), initializes the clone (L109-L121), registers it (L123-L125), and verifies reported escrow ownership and clone Active status (L127-L134). Thus this helper's success alone is not complete creation success.
- **Shared state:** Immutable dependency addresses come from constructor assignments (L85-L91). `isRaffle` is declared at L54 and set true in creation at L125. This helper reads that mapping twice but never changes it (L159, L166). It does not read the count, ID mappings, treasury, timestamp, or prize ownership (L154-L179).
- **Invariant couplings:** The positive reserve flows into the clone's reserve and outcome comparison (RaffleFactory.sol:L118; Raffle.sol:L203, L521). Recipient exclusion is applied before cloning here and again with clone-specific context during initialization (RaffleFactory.sol:L163-L169; Raffle.sol:L193-L195, L599-L604). Token-standard reporting and escrow completion are separate conditions (RaffleFactory.sol:L171-L177 versus L127-L134).

---

**Open Questions:**

- unclear; need to inspect the concrete sponsor-selected prize implementation to determine whether its `supportsInterface` assertion corresponds to ERC-721 transfer and ownership behavior; the inspected source specifies only the runtime address and typed interface call (RaffleFactory.sol:L172; IERC165.sol:L24).
'''
record={
 'function':'_validateCreateParams','file':'target/packages/contracts/src/RaffleFactory.sol','lines':'L154-L179','analysisFile':analysis_rel,
 'invariants':[
 {'claim':'Normal return requires prizeToken to have positive code length at validation.','evidence':'RaffleFactory.sol:L155, L183-L184'},
 {'claim':'Normal return excludes factory, quote token, wrapper, implementation and current local registered raffles from prizeToken; sponsorRecipient additionally must be nonzero and differ from prizeToken.','evidence':'RaffleFactory.sol:L156-L169'},
 {'claim':'Normal return requires a decoded true ERC-721 supportsInterface response; caught call failures and decoded false reject.','evidence':'RaffleFactory.sol:L171-L177'},
 {'claim':'Normal return requires reserveEntries in [1, type(uint128).max].','evidence':'RaffleFactory.sol:L178; interfaces/IRaffleFactory.sol:L24'},
 {'claim':'The helper writes no persistent state and emits no events; its sole external interaction is the typed view interface query.','evidence':'RaffleFactory.sol:L154-L179; IERC165.sol:L24'}],
 'assumptions':[
 {'claim':'The prize address contains deployed code before the interface query (RaffleFactory.sol:L155, L172).','establishedBy':'RaffleFactory._requireContract, RaffleFactory.sol:L183-L185, on every normal return'},
 {'claim':'A true supportsInterface response corresponds to actual standards-compliant ERC-721 behavior (RaffleFactory.sol:L172-L177; IERC165.sol:L17-L24).','establishedBy':'nothing found'},
 {'claim':'The registry used for address exclusion represents this factory\'s registered clones (RaffleFactory.sol:L159, L166).','establishedBy':'RaffleFactory.createRaffle sets isRaffle[raffle] = true at RaffleFactory.sol:L123-L125 after clone creation at L106'},
 {'claim':'Whole-creation timing and escrow preconditions are enforced outside this helper (RaffleFactory.sol:L154-L179).','establishedBy':'RaffleFactory.createRaffle timing checks at L99-L104 and post-transfer owner/status checks at L127-L134; token-reported ownership remains dependent on the arbitrary prize implementation'}],
 'calls':[
 {'callee':'_requireContract(params.prizeToken)','kind':'internal','propagates':'At RaffleFactory.sol:L155, depends on L183-L185: zero code length reverts NotContract; every successful path establishes positive code length and nothing about interface or ownership behavior.'},
 {'callee':'IERC165(params.prizeToken).supportsInterface(type(IERC721).interfaceId)','kind':'external-black-box','propagates':'RaffleFactory.sol:L172 sends the ERC-721 interface ID without value via the external view signature (IERC165.sol:L24). Decoded true permits progress, decoded false and caught failures reject (L173-L177). Concrete implementation unavailable; truthful standard compliance is not established by the boolean.'}],
 'callers':['RaffleFactory.createRaffle, RaffleFactory.sol:L97-L98; validation precedes timing checks, count increment, cloning and escrow (L99-L134).'],
 'sharedState':['Reads immutable quoteToken, vrfWrapper, raffleImplementation initialized at RaffleFactory.sol:L85-L91; reads isRaffle membership at L159/L166, written by createRaffle at L125.'],
 'openQuestions':['unclear; need to inspect the concrete sponsor-selected prize implementation to determine whether its supportsInterface assertion matches ERC-721 transfer and ownership behavior (RaffleFactory.sol:L172; IERC165.sol:L24).']}
paths=[
'audit/AGENT-RULES.md','audit/S1/native/012-request.json',
'audit/resources/plugins__audit-context-building__agents__function-analyzer.md',
'audit/resources/plugins__audit-context-building__skills__audit-context-building__resources__ANALYSIS_FORMAT.md',
'audit/resources/plugins__audit-context-building__skills__audit-context-building__resources__FUNCTION_MICRO_ANALYSIS_EXAMPLE.md',
'audit/resources/plugins__audit-context-building__skills__audit-context-building__resources__DOMAIN_NOTES.md',
'target/packages/contracts/src/RaffleFactory.sol','target/packages/contracts/src/interfaces/IRaffleFactory.sol',
'target/packages/contracts/node_modules/@openzeppelin/contracts/utils/introspection/IERC165.sol',
'target/packages/contracts/node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol',
'target/packages/contracts/src/Raffle.sol','target/packages/contracts/node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol']
origin='/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/'
manifest=[]
for p in paths:
 b=(root/p).read_bytes()
 item={'path':p,'absolutePath':str(root/p),'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b)}
 if p.startswith('audit/resources/'):
  item['pinnedOriginPath']=origin+pathlib.Path(p).name.replace('__','/')
  item['pinnedRevision']='82fe8226252622fa807643bdca1710901198553a'
 if p.endswith('/Raffle.sol'): item['readLines']='176-206,375-407,505-532,580-614; targeted rg references to _isProtocolDestination'
 if p.endswith('/ReentrancyGuard.sol'): item['readLines']='45-119'
 manifest.append(item)
def write_atomic(path,data):
 path=root/path
 tmp=path.with_name(path.name+'.tmp')
 tmp.write_bytes(data)
 os.replace(tmp,path)
write_atomic(analysis_rel,analysis.encode())
write_atomic('audit/S1/raw/012-analysis-original.md',analysis.encode())
write_atomic('audit/S1/raw/012-resources.json',(json.dumps({'resources':manifest,'acceptedModel':'gpt-6-astra','acceptedEffort':'ultra','providerReturnedModel':'unknown','providerReturnedEffort':'unknown','fallbackEnabled':False},indent=2)+'\n').encode())
response=(json.dumps(record,indent=2)+'\n').encode()
request=json.loads((root/'audit/S1/native/012-request.json').read_text())
for key in request['options']['schema']['required']: assert key in record,key
assert len(record['calls'])==2
write_atomic('audit/S1/raw/012-response-original.json',response)
write_atomic('audit/S1/native/012-response.json',response)
completion={'analysisFile':analysis_rel,'responseFile':'audit/S1/native/012-response.json','resourcesFile':'audit/S1/raw/012-resources.json','originalResponseFile':'audit/S1/raw/012-response-original.json','originalAnalysisFile':'audit/S1/raw/012-analysis-original.md'}
write_atomic('audit/S1/raw/012-completion.json',(json.dumps(completion,separators=(',',':'))+'\n').encode())
print(json.dumps(completion,separators=(',',':')))
