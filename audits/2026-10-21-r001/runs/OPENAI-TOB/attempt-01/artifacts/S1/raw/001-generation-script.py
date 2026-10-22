from pathlib import Path
import json, hashlib, os
root=Path.cwd()
R='target/packages/contracts/src/Raffle.sol'
F='target/packages/contracts/src/RaffleFactory.sol'
O='target/packages/contracts/node_modules/@openzeppelin/contracts/'
C='target/packages/contracts/node_modules/@chainlink/contracts/src/v0.8/vrf/dev/'
E=O+'token/ERC721/ERC721.sol'
G=O+'utils/ReentrancyGuard.sol'
V=C+'VRFV2PlusWrapperConsumerBase.sol'
S=O+'token/ERC20/utils/SafeERC20.sol'
modules=[
('RaffleFactory',F,'Ownerless immutable deployment root: validates sponsor configuration, creates an ERC-1167 clone, initializes and registers it, and verifies prize escrow atomically (L65-L148).'),
('Raffle',R,'Per-clone prize escrow, transferable ERC721 entry-range tickets, lifecycle and deadlines, native-funded draw requests, callback result recording, storage-only settlement and individual asset claims (L176-L605).'),
('IRaffle','target/packages/contracts/src/interfaces/IRaffle.sol','Lifecycle enum, clone configuration struct, events/errors and public raffle API; documents bearer ownership and quote-token assumptions.'),
('IRaffleFactory','target/packages/contracts/src/interfaces/IRaffleFactory.sol','Factory configuration, creation event, validation errors, creation and canonical registry API.'),
('RaffleConstants','target/packages/contracts/src/libraries/RaffleConstants.sol','Fixed price, six decimals, 5% protocol and 80% cash-winner rates, 100-ticket refund limit, 30-day sale limit, two-day request/callback intervals, and fixed VRF gas/confirmation settings.'),
('OpenZeppelin ERC721',E,'Inherited ticket ownership, balances, token/operator approval and authorized transfers; invokes the raffle _update override and ERC721 receiver callbacks.'),
('OpenZeppelin ERC721Utils',O+'token/ERC721/utils/ERC721Utils.sol','Runs untrusted recipient acceptance callbacks after ticket mint or safe transfer and requires the expected receiver selector.'),
('OpenZeppelin ReentrancyGuard',G,'Storage-slot guard shared by guarded functions within one contract instance; clone storage and factory storage are separate.'),
('OpenZeppelin SafeERC20',S,'Low-level quote-token transfers with optional return-value validation and revert propagation; actual token transfer semantics remain an external assumption.'),
('OpenZeppelin Clones',O+'proxy/Clones.sol','CREATE-based fixed-target ERC-1167 deployment used by the factory; constructor-deployed implementation supplies immutable dependencies.'),
('OpenZeppelin Math',O+'utils/math/Math.sol','Full-precision floor multiplication/division used to allocate aggregate protocol and cash-winner liabilities.'),
('Chainlink consumer base',V,'Embeds wrapper/LINK addresses, quotes and pays native request fees, and authenticates external rawFulfillRandomWords before invoking the raffle callback.'),
('Chainlink wrapper interface and client encoding',C+'interfaces/IVRFV2PlusWrapper.sol','Black-box canonical wrapper API for pricing, native payment and request identity; VRFV2PlusClient encodes nativePayment=true extra arguments.'),
('Design and build context','target/DESIGN.md','Independent intended behavior and trust boundaries; production language is Solidity 0.8.36, with pinned dependency versions declared in target/packages/contracts/package.json. Actual behavior is determined by source.')]
entries=[
('constructor',F,'Deployment initiator supplies permanent quote token, wrapper and treasury; deployment validates code/decimals and deploys the locked implementation (L65-L92).'),
('constructor',R,'Canonical factory deployment invokes it for its implementation; independent deployments are possible but are not canonical registered clones (L155-L166).'),
('createRaffle',F,'Any sponsor calls with configuration and prize-transfer approval; nonReentrant and atomically escrows through an arbitrary prize contract (L97-L148).'),
('initialize',R,'External ABI is callable by anyone, but only the immutable factory may succeed and only before initialization (L176-L206).'),
('buyEntries',R,'Any payer with quote-token allowance; chooses recipient and positive entry count while Active and before sale end (L209-L237).'),
('requestDraw',R,'Anyone funding the native wrapper fee after sale end and strictly before end+2 days, with at least one sold entry (L240-L273).'),
('enableRefunds',R,'Anyone after the applicable timeout; for zero-entry Active raffles the sponsor may call before sale end, and anyone may call at/after sale end (L276-L301).'),
('settleWinningTicket',R,'Anyone supplies a range ticket containing the winning entry after NftWon/CashWon; no ownership requirement and no asset transfer (L304-L306, L533-L558).'),
('redeemWinningTicket',R,'Only the current winning-ticket owner may successfully redeem; may first settle and burns atomically with delivery (L309-L346).'),
('refundTickets',R,'Current ticket owners submit 1-100 owned tickets in Refunding; approvals alone do not authorize claiming (L349-L372).'),
('releaseSponsorProceeds',R,'Anyone triggers payment of a nonzero allocated sponsor balance to the fixed sponsorRecipient (L375-L382).'),
('releaseProtocolFees',R,'Anyone triggers payment of a nonzero allocated protocol balance to the fixed protocolTreasury (L385-L392).'),
('releaseSponsorPrize',R,'Anyone triggers the one-time prize return to sponsorRecipient in CashWon or Refunding (L395-L407).'),
('onERC721Received',R,'External caller must be configured prizeToken with exact token ID, sponsor/from and factory/operator while AwaitingPrize; this callback activates sales (L416-L431).'),
('rawFulfillRandomWords',V,'Callable on every raffle via inherited ABI; only immutable wrapper may pass authentication and reach fulfillRandomWords (L101-L107).'),
('receive',R,'Any direct native transfer with empty calldata reaches an unconditional revert (L170-L173); requestDraw is the payable normal path.'),
('approve',E,'Ticket owner or approved-for-all operator delegates transfer permission for one ticket (L93-L95, L383-L401).'),
('setApprovalForAll',E,'Any ticket holder establishes/revokes an operator for its own holdings (L105-L107, L409-L418).'),
('transferFrom',E,'Owner, per-ticket approved address or approved-for-all operator may transfer a ticket; destination screening is applied by Raffle._update in every lifecycle state (L115-L125; Raffle L497-L502).'),
('safeTransferFrom(address,address,uint256)',E,'Same transfer authorization as transferFrom, followed by contract receiver acceptance through the four-argument overload (L128-L136).'),
('safeTransferFrom(address,address,uint256,bytes)',E,'Same transfer authorization, with caller-supplied receiver data passed to untrusted contract recipient (L133-L136).'),
('Raffle view/pure and generated getters',R,'Any caller reads configuration, accounting, historical ranges, result, deadlines, name/symbol, wrapper and VRF fee estimates; functions L436-L486 and public declarations L44-L136.'),
('RaffleFactory generated getters',F,'Any caller reads immutable dependencies/configuration and canonical registry/count (L25-L54).'),
('ERC721 view functions',E,'Anyone reads supportsInterface, balanceOf, ownerOf, getApproved, isApprovedForAll and tokenURI, subject to address/token-existence checks (L45-L111).'),
('Chainlink consumer view functions',V,'Anyone reads i_vrfV2PlusWrapper, native getBalance and getLinkToken (L35, L109-L117).')]
actors=[
('Public callers, buyers and permissionless lifecycle/claim executors','untrusted'),
('Sponsors and sponsor-selected recipients','untrusted'),
('Ticket owners, approved operators and ticket receiver contracts','untrusted'),
('Arbitrary sponsor-selected prize ERC721 contracts','untrusted'),
('Deployment initiator choosing canonical dependencies and treasury','trusted'),
('Canonical immutable factory and registered fixed-implementation clones','trusted'),
('Canonical six-decimal USDC contract under the stated transfer-semantic assumption','trusted'),
('Canonical Chainlink VRF wrapper and authenticated randomness service','trusted'),
('Protocol treasury as a payout recipient without administrative powers','untrusted'),
('Chain execution environment supplying timestamp, transaction ordering and atomic rollback','trusted'),
('Off-chain discovery/indexers and callers deciding which raffle/prize to use','untrusted')]
state=[]
def st(names,file,writers):
 for n in names: state.append({'name':n,'file':file,'writtenBy':writers})
st(['quoteToken','vrfWrapper','protocolTreasury','raffleImplementation'],F,['RaffleFactory.constructor'])
st(['raffleCount','raffleById','idByRaffle','isRaffle'],F,['RaffleFactory.createRaffle'])
st(['factory','quoteToken'],R,['Raffle.constructor (implementation bytecode immutables shared by clones)'])
st(['sponsor','sponsorRecipient','protocolTreasury','prizeToken','prizeTokenId','raffleId','reserveEntries','endTime'],R,['Raffle.initialize'])
st(['initialized'],R,['Raffle.constructor (implementation storage)','Raffle.initialize (clone storage)'])
st(['totalEntries','ticketCount','_ticketRanges'],R,['Raffle.buyEntries'])
st(['unsettledPot'],R,['Raffle.buyEntries','Raffle.enableRefunds','Raffle._settleWinningTicket'])
st(['remainingRefundLiability'],R,['Raffle.enableRefunds','Raffle.refundTickets'])
st(['winnerRecipient','winnerRedeemed'],R,['Raffle.redeemWinningTicket'])
st(['winnerProceeds'],R,['Raffle._settleWinningTicket','Raffle.redeemWinningTicket'])
st(['sponsorProceeds'],R,['Raffle._settleWinningTicket','Raffle.releaseSponsorProceeds'])
st(['protocolFees'],R,['Raffle._settleWinningTicket','Raffle.releaseProtocolFees'])
st(['vrfRequestId','drawRequestedAt','_requestInFlight'],R,['Raffle.requestDraw'])
st(['resolvedAt','winningEntry'],R,['Raffle.fulfillRandomWords'])
st(['winningTicketId','settlementComplete'],R,['Raffle._settleWinningTicket'])
st(['status'],R,['Raffle.constructor','Raffle.initialize','Raffle.onERC721Received','Raffle.requestDraw','Raffle.fulfillRandomWords','Raffle.enableRefunds'])
st(['prizeClaimed'],R,['Raffle.redeemWinningTicket','Raffle.releaseSponsorPrize'])
st(['ERC721._owners','ERC721._balances'],E,['ERC721._update reached through Raffle._update from buyEntries, inherited transfers, refundTickets and redeemWinningTicket'])
st(['ERC721._tokenApprovals'],E,['ERC721._approve reached by approve and ownership updates'])
st(['ERC721._operatorApprovals'],E,['ERC721._setApprovalForAll reached by setApprovalForAll'])
st(['ERC721._name','ERC721._symbol'],E,['ERC721.constructor on implementation; public raffle metadata overrides use fixed strings'])
st(['i_linkToken','i_vrfV2PlusWrapper'],V,['VRFV2PlusWrapperConsumerBase.constructor (implementation bytecode immutables shared by clones)'])
st(['REENTRANCY_GUARD_STORAGE slot value per factory/raffle instance'],G,['ReentrancyGuard.constructor on deployed factory/implementation','_nonReentrantBefore','_nonReentrantAfter'])
st(['Escrowed prize ownership and quote/native balances (external ledger state)'],R,['Factory.createRaffle prize transfer','buyEntries quote transfer','requestDraw native payment and refund','redeemWinningTicket','refundTickets','releaseSponsorProceeds','releaseProtocolFees','releaseSponsorPrize','unsolicited external token/native transfers outside internal accounting'])
candidates=[
('createRaffle',F,'L97-L148: accepts sponsor input, establishes clone identity and registry state, crosses the untrusted prize boundary, and verifies activation and escrow atomically.'),
('buyEntries',R,'L209-L237: couples paid quote amounts, uint128 entry bounds, contiguous ranges, pot growth and untrusted ticket-receiver execution.'),
('requestDraw',R,'L240-L273: controls the request window, lifecycle freeze, native fee funding/refund, request identity and synchronous-callback exclusion.'),
('redeemWinningTicket',R,'L309-L346: binds a winning range to current ownership, consumes the bearer claim and atomically delivers an external NFT or quote payment.'),
('refundTickets',R,'L349-L372: validates an untrusted bounded batch, current ownership and range accounting before burns and reduction of shared refund liability.'),
('fulfillRandomWords',R,'L509-L524: validates request/lifecycle/word count/deadline and determines the winning entry and reserve-dependent terminal result.'),
('_settleWinningTicket',R,'L533-L558: proves the winning range once and conserves the unsettled pot across rounded winner, sponsor and protocol allocations.'),
('enableRefunds',R,'L276-L301: arbitrates empty-sale sponsor authority and request/callback timeouts while moving the whole pot into refund liability.'),
('initialize',R,'L176-L206: enforces factory-only one-time configuration and establishes every clone-specific recipient, prize and lifecycle assumption.'),
('_update',R,'L497-L502: universal ticket mint/transfer/burn hook screens ownership destinations before inherited authorization and shared ERC721 writes.'),
('_validateCreateParams',F,'L154-L179: screens untrusted prize and sponsor-recipient addresses, ERC721 interface responses and the nonzero reserve bound.'),
('onERC721Received',R,'L416-L431: authenticates the configured escrow callback and is the sole normal transition from AwaitingPrize to Active.'),
('_isProtocolDestination',R,'L593-L605: central address policy links initialization, ticket ownership and payout recipients to the canonical factory registry.'),
('releaseSponsorPrize',R,'L395-L407: validates the return branch and one-time prize claim before external transfer and ownership verification.'),
('_transferQuote',R,'L564-L567: common payout boundary screens destinations and invokes the trusted token through SafeERC20 for all quote claims.'),
('releaseSponsorProceeds',R,'L375-L382: clears the allocated sponsor liability before paying its fixed recipient, independently of other claims.'),
('releaseProtocolFees',R,'L385-L392: clears the allocated treasury liability before paying its fixed recipient, independently of other claims.'),
('constructor',F,'L65-L92: permanently binds dependency identities, token precision, treasury and implementation for every future clone.'),
('constructor',R,'L155-L166: binds factory and quote immutables, initializes the wrapper base and locks implementation storage against initialization.'),
('_requireWinningTicket',R,'L579-L585: validates the supplied historical entry range used to assign the single winning ticket and its liabilities.'),
('rawFulfillRandomWords',V,'L101-L107: inherited external authentication boundary restricts randomness delivery to the immutable wrapper.'),
('_update',E,'L216-L250: performs optional owner/operator authorization, clears approvals, and changes ticket owners and balances for every transfer/mint/burn.'),
('transferFrom',E,'L115-L125: binds caller authorization, claimed from-address and nonzero destination to ticket ownership changes.'),
('_approve',E,'L383-L401 four-argument overload: validates approval authority and mutates per-ticket delegation, including clearing it during transfers.'),
('_checkAuthorized',E,'L179-L187: enforces owner, token approval or global operator authority and distinguishes absent tickets from unauthorized callers.'),
('_setApprovalForAll',E,'L409-L418: validates identities and persists holder-wide transfer delegation used by all subsequent transfer authorization.'),
('checkOnERC721Received',O+'token/ERC721/utils/ERC721Utils.sol','L25-L50: crosses the untrusted receiver boundary after mint/safe-transfer state changes and rejects incompatible callbacks.'),
('requestRandomnessPayInNative',V,'L76-L89: requotes the wrapper, forwards exact native request payment and returns the authoritative request ID and fee.'),
('_safeTransferFrom',S,'L212-L249: low-level incoming quote transfer validates external call success and optional return data before purchase accounting proceeds.'),
('_safeTransfer',S,'L176-L199: low-level outgoing quote transfer validates external call success and optional return data for consumed liabilities.'),
('clone',O+'proxy/Clones.sol','L49-L66 two-argument overload: constructs fixed-target proxy bytecode with CREATE and verifies deployment success.'),
('mulDiv',O+'utils/math/Math.sol','L206-L277 three-argument overload: supplies exact floor rounding and bounded full-precision arithmetic for terminal monetary allocation.'),
('_nonReentrantBefore',G,'L94-L100: checks and enters the shared instance guard before guarded lifecycle and asset-transfer operations.'),
('_safeMint',E,'L287-L290 three-argument overload: combines unique-ticket minting with receiver acceptance after ownership becomes visible.'),
('_mint',E,'L259-L267: validates a nonzero recipient and previously absent ticket while invoking the raffle ownership hook.'),
('_burn',E,'L303-L308: consumes an existing ticket without performing caller authorization itself, relying on redemption/refund callers.'),
('_requireOwned',E,'L426-L432: establishes that a ticket currently exists before owner-only claims and token approval paths proceed.'),
('_requireStatus',R,'L573-L575: shared lifecycle precondition for sale, draw and refund entrypoints.'),
('_requireContract',F,'L183-L185: common deployed-code precondition for immutable dependencies and untrusted prize configuration.'),
('_validatedVrfWrapper',R,'L610-L613: establishes the nonzero wrapper input before the inherited constructor makes an external link() query.')]
obj={'modules':[dict(zip(('name','path','role'),v)) for v in modules], 'entrypoints':[dict(zip(('name','file','reachableBy'),v)) for v in entries], 'actors':[dict(zip(('name','trust'),v)) for v in actors], 'state':state,'candidates':[dict(zip(('name','file','why'),v)) for v in candidates], 'language':'Solidity 0.8.36'}
assert len(candidates)==40
serialized=json.dumps(obj,indent=2)+'\n'
prose='''# Orient response 001 — original context record

Scope: target/DESIGN.md, all five production source/interface files, the declared build inputs, and the directly reachable library paths listed in 001-resources.json. This is broad/shallow orientation, not a claim that every dependency function was analyzed in depth. No target files were modified. The ranked structured response below is the complete original response; the first twelve candidates are the next-depth selection.

## System shape and invariants

RaffleFactory fixes the quote token, wrapper, treasury and implementation in its constructor (RaffleFactory.sol L65-L92). Creation validates sponsor input and duration, deploys and initializes one clone, registers its address and ID, transfers the prize and checks its reported owner and Active status in one transaction (L97-L148). Each clone delegates to the same implementation but owns separate storage; the implementation constructor locks its own initialized flag (Raffle.sol L155-L166; Clones.sol L49-L66). There is no owner or mutable administrative configuration in either production contract.

The lifecycle is AwaitingPrize -> Active -> Drawing -> NftWon/CashWon, with Active/Drawing -> Refunding on the relevant empty-sale or deadline conditions (IRaffle.sol L20-L33; Raffle.sol L205, L428, L252, L521, L276-L300). A purchase assigns one contiguous inclusive range, collects entryCount * 1,000,000 quote units, and safely mints one ERC721 ticket (Raffle.sol L209-L237). The sold-entry and ticket counters are lifetime counters; ranges remain stored after burns (L85-L88, L138-L139, L349-L365). Ownership remains transferable in every lifecycle state, subject to the destination policy and inherited ERC721 authorization (L497-L502; ERC721.sol L115-L136, L216-L250).

Draw requests require a nonempty sale, timestamp >= endTime and timestamp < endTime+2 days (Raffle.sol L240-L247, L458-L460). The wrapper callback reaches the result handler only after inherited caller authentication (VRFV2PlusWrapperConsumerBase.sol L101-L107), and is ignored if in-flight, wrong-state, wrong-ID, wrong-length or at/after the callback deadline (Raffle.sol L509-L516). Accepted randomness records an entry, timestamp and result without asset transfer (L518-L523). Refund activation covers the complementary request/callback deadlines and the empty-sale rule (L276-L300).

Settlement establishes the winning range and reallocates the pot into liabilities without reading ticket ownership or transferring assets (Raffle.sol L533-L558). NFT outcome allocates floor(5% gross) to protocol and the remainder to sponsor; cash outcome additionally allocates floor(80% gross) to winner, with the remainder to sponsor (L539-L555). The sum of outstanding tracked liabilities is explicitly exposed by accountedQuoteBalance (L468-L470). Refund activation instead moves the unallocated pot into remainingRefundLiability, and ticket refunds subtract the full entry value (L296-L299, L367-L369).

Redemption and refunds require current ticket ownership rather than transfer approval, then burn before external delivery; a reverted delivery rolls back the transaction (Raffle.sol L309-L345, L349-L371; ERC721.sol L303-L308). Sponsor and treasury claims have independent liability slots and fixed recipients (Raffle.sol L375-L407). Prize release is separate from quote settlement and uses one shared prizeClaimed flag (L329-L336, L395-L405).

## Trust and assumptions to carry forward

- Canonical USDC identity and standard fee-free/non-rebasing transfer behavior are supplied by the deployment trust model. The constructor checks deployed code and six-decimal metadata, and payouts use SafeERC20 call/return validation; onchain proof of canonical identity or exact balance deltas: **nothing found** (RaffleFactory.sol L59-L77; Raffle.sol L223-L224, L560-L566; SafeERC20.sol L176-L249).
- Canonical wrapper identity, fee behavior and randomness service are trusted external inputs. The code binds the provided address and authenticates callbacks against it; independent proof that the address is the official service: **nothing found** (RaffleFactory.sol L66-L67, L85-L89; VRFV2PlusWrapperConsumerBase.sol L40-L47, L76-L107). Timely callback delivery is not guaranteed locally; refund deadlines explicitly accommodate nonresolution (Raffle.sol L289-L291, L509-L515).
- DESIGN.md treats arbitrary prize contracts as untrusted, while IRaffle.sol L13-L15 describes supported prizes as honest standards-compliant ERC721s. Preserve both statements. The actual checks are code presence, supportsInterface, callback tuple, ownerOf and lifecycle checks (RaffleFactory.sol L127-L134, L154-L179; Raffle.sol L416-L430). Full ERC721 honesty or truthful ownerOf behavior is an external semantic assumption; enforcement beyond those observations: **nothing found**.
- Recipient policy recognizes the current raffle, its factory, quote token, wrapper, prize token, implementation and currently registered same-factory clones; it consults the registry for code-bearing destinations (Raffle.sol L593-L605). Universal recipient operability or future ability to initiate an owner-only claim is not proved; **nothing found** beyond destination screening and the safe-mint receiver acceptance call (L235, L497-L502; ERC721Utils.sol L25-L50).
- Permissionless means callers may execute transitions and claims; the code does not schedule or fund those calls itself (Raffle.sol L240-L273, L276-L301, L304-L407). Event discovery is advisory in DESIGN.md; transaction truth remains the current contract state.
- ReentrancyGuard protects functions carrying its modifier within one instance; inherited ticket transfers and approvals, the prize-receiver callback and raw randomness callback have their own checks and do not all enter that guard (Raffle.sol L176-L431; ERC721.sol L93-L136; VRFV2PlusWrapperConsumerBase.sol L101-L107). The clone guard begins from default storage; the guard checks equality to ENTERED, then writes ENTERED and resets to NOT_ENTERED (ReentrancyGuard.sol L88-L113).

## Depth and open questions

The first twelve ranked functions cover creation, purchasing, draw requests, winner delivery, refunds, callback resolution, allocation, timeout arbitration, initialization, ticket ownership updates, input validation and escrow activation. Each depth pass must follow its listed helpers and external-call paths. Rankings 13-40 retain the remaining meaningful guards, transfer paths and reachable dependency operations. Simple generated getters, wrappers, metadata functions and pure encoding pass-throughs are not selected for standalone depth.

The deployed quote token, prize contracts and wrapper implementations are not supplied as deployment-specific source in this target; no assertion is made about their runtime behavior beyond the stated trust model and visible call/check boundaries. A later contextual decision must reconcile the prize trust wording above. Precise interactions among receiver callbacks, unguarded inherited ticket transfers, current ownership and terminal claims warrant per-function tracing; this orientation makes no verdict about them.

## Complete structured response

'''
raw=prose+'```json\n'+serialized+'```\n'
up=Path('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/trailofbits/plugins/audit-context-building/skills/audit-context-building')
loads=[(str(up/'SKILL.md'),'pinned_skill','full'),(str(up/'resources/ANALYSIS_FORMAT.md'),'pinned_resource','full'),(str(up/'resources/DOMAIN_NOTES.md'),'pinned_resource','full'),(str(up/'resources/FUNCTION_MICRO_ANALYSIS_EXAMPLE.md'),'pinned_resource','full'),('audit/S1/native/001-request.json','native_request','full'),('target/DESIGN.md','design','full'),(R,'production_source','full'),(F,'production_source','full'),('target/packages/contracts/src/interfaces/IRaffle.sol','production_interface','full tool read; selected excerpts explicitly re-read after combined-output truncation'),('target/packages/contracts/src/interfaces/IRaffleFactory.sol','production_interface','full'),('target/packages/contracts/src/libraries/RaffleConstants.sol','production_source','full'),('target/packages/contracts/package.json','build_context','full'),('target/packages/contracts/remappings.txt','build_context','full'),('target/packages/contracts/foundry.toml','build_context','full'),(V,'reachable_dependency','full'),(C+'interfaces/IVRFV2PlusWrapper.sol','reachable_dependency','full'),(C+'libraries/VRFV2PlusClient.sol','reachable_dependency','full'),(E,'reachable_dependency','full'),(G,'reachable_dependency','full'),(O+'token/ERC721/utils/ERC721Utils.sol','reachable_dependency','full'),(O+'proxy/Clones.sol','reachable_dependency','L1-L180; reached clone(address,uint256) read in full'),(S,'reachable_dependency','L1-L125 and L176-L252; reached safeTransfer and safeTransferFrom chains read in full'),(O+'utils/math/Math.sol','reachable_dependency','selected mul512 and mulDiv arithmetic excerpts'),(O+'utils/StorageSlot.sol','reachable_dependency','getUint256Slot selected excerpt'),(O+'utils/Context.sol','reachable_dependency','full')]
manifest={'request_id':'001','phase':'Orient','accepted_model':'gpt-6-astra','accepted_effort':'ultra','provider_returned_model':'unknown','provider_returned_effort':'unknown','fallback_enabled':False,'note':'Accepted model/effort are request constraints, not independently reported provider fields. File hashes identify the exact loaded versions; coverage identifies partial reads.','resources':[]}
for p,k,scope in loads:
 p=Path(p); p=p if p.is_absolute() else root/p
 manifest['resources'].append({'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'kind':k,'read_scope':scope})
def atomic(path,text):
 path=root/path; path.parent.mkdir(parents=True,exist_ok=True); temp=path.with_suffix(path.suffix+'.tmp'); temp.write_text(text); os.replace(temp,path)
# Preserve the full original prose and structured response before publishing completion JSON.
atomic(Path('audit/S1/raw/001-orient.md'),raw)
atomic(Path('audit/S1/raw/001-resources.json'),json.dumps(manifest,indent=2)+'\n')
atomic(Path('audit/S1/native/001-response.json'),serialized)
print(json.dumps({'written':['audit/S1/native/001-response.json','audit/S1/raw/001-orient.md','audit/S1/raw/001-resources.json'],'candidates':len(candidates),'modules':len(modules),'entrypoints':len(entries),'state_items':len(state),'resources':len(loads)}))
