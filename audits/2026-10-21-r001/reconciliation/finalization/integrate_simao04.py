from pathlib import Path
import datetime,hashlib,json,re
A=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001');D=A/'reconciliation/finalization';P=A/'runs/GEMINI-SIMAO-REPAIRED/attempt-04/adjudication/native-first-pass';key='GEMINI-SIMAO-REPAIRED/attempt-04';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,o):p.write_text(json.dumps(o,indent=2)+'\n')
r=json.loads((D/'working-register.json').read_text());assert key not in [s['report_key'] for s in r['source_reports']]
v=json.loads((D/'GEMINI-SIMAO-04-RECEIPT-VERIFICATION.json').read_text());assert not v['errors'];assert sha(P/'artifact-integrity-seal.json')==v['seal_sha256']
for x in v['records']:assert sha(Path(x['path']))==x['sha256']
receipt=json.loads((P/'native-completion-receipt.json').read_text());source={'report_key':key,'path':str(P/'FIRST-PASS.md'),'sha256':sha(P/'FIRST-PASS.md'),'seal':str(P/'artifact-integrity-seal.json'),'seal_sha256':sha(P/'artifact-integrity-seal.json'),'seal_verified':True,'all_bound_artifacts_verified':v['record_count'],'distinct_bound_paths':v['distinct_paths'],'frozen_target':'9238b6ce8eb7f768c0dcd0cfcef26e1427a03155','target_binding':'All43 source/build/dependency hashes match frozen clean context;12 original leaf report/receipt hashes match.','native_completion_receipt':str(P/'native-completion-receipt.json'),'source_only':False,'source_only_note':'Post-seal native source-analysis output; external token examples are not independently validated here. No execution proof is adopted from this report.','native_terminal_status':'SUCCESS','qualification':'Scoped native run completion and artifact integrity only. Independent final semantic completeness remains unchecked after root coordinator OpenAI rejection. Not global method qualification or finding validation.','model_route':'Official CLI gemini-4-argon-high, effort high, fresh judge identity distinct from12leaf identities, no delegated judge children; internal checkpoint unknown.'}
r['source_reports'].append(source);idx={x['id']:x for x in r['findings']};lines=(P/'FIRST-PASS.md').read_text().splitlines();gate=(P/'gate-ledger.md').read_text().splitlines();added=[]
def add(target,ident,line,sev,reason,path=P/'FIRST-PASS.md',status='native report finding; post-seal reconciliation differs where stated',extra=None):
 a={'report_key':key,'report_path':str(path),'report_line':line,'original_id':ident,'original_severity':sev,'original_status':status,'reconciled_reason':reason,'proof_status':'Native written argument; no newly executed proof adopted in this reconciliation'}
 if path==P/'FIRST-PASS.md':a['original_title']=lines[line-1]
 if extra:a.update(extra)
 idx[target]['original_attributions'].append(a);added.append({'target':target,**a})
final={
'M-1':(31,'Medium',[('RF-001','Same conditional prize delivery/proceeds root chain; preserve Medium versus prior High/Low classifications. Explicit arbitrary-prize versus honest-prize scope conflict remains.'),('OBS-002','Embedded recipient-blacklist observation remains isolated issuer/payout availability risk.')]),
'M-2':(67,'Medium',[('CLOSED-002','Reserve crossing and sponsor self-purchase are the disclosed payout rule. The example depends on NFT valuation, capital and winning odds; no unauthorized withdrawal or guaranteed-profit defect established.'),('RF-001','Embedded pre-delivery proceeds paragraph belongs to RF-001, not a second distinct accounting root.')]),
'M-3':(83,'Medium',[('CLOSED-002','Uncapped pre-deadline paid entries dilute every prior entry under the published odds rule. Sponsor rebate is the configured seller economics; no fixed odds promise shown. Preserve Medium dissent, not promote design choice to proven theft.')]),
'L-1':(109,'Low',[('CLOSED-004','A funded entry executed before cancellation validly ends the empty-raffle exception. No cancellation priority guarantee exists; preserve Low disagreement.')]),
'L-2':(125,'Low',[('OBS-008','Requester funds actual fee and can lose it on service timeout; operational cost/liveness dependency, not quote-liability insolvency.'),('EVIDENCE-001','Specific gas-price induced service-stall/2day causation remains unproved; local pinned public-fork tests only partially close wrapper compatibility.'),('CLOSED-002','Single-owner CashWon applies the explicit80/15/5split; ticketCount is not distinct participant count.')]),
'I-1':(150,'Informational',[('RF-002','Same sponsor-selected future-clone unsafe-prize-return path; parent honest-ERC721 reproduction remains controlling evidence. Own-recipient loss, not general EOA theft.'),('OBS-004','Future clone can own ticket but cannot originate its redemption/transfer; permissionless settlement does not grant holder call capability.')]),
'I-2':(166,'Informational',[('RF-002','Same reproduced future-clone sponsor prize stranding; preserve Info versus Low disagreement.')]),
'I-3':(192,'Informational',[('OBS-004','Raw transfer skips receiver bookkeeping. Actual contract winner must be able to initiate owner-only redemption or transfer; not assumed from vm.prank.'),('RF-001','Persistent prize refusal has no NFT-outcome refund transition; same conditional root.')]),
'I-4':(208,'Informational',[('CLOSED-002','Reserve cliff is explicit outcome selection, not separately established defect.')]),
'I-5':(224,'Informational',[('OBS-006','Paid callback purchase may precede RaffleCreated; final factory revert rolls back the entire transaction. No free entry or state corruption demonstrated.')]),
'I-6':(240,'Informational',[('OBS-006','Same creation event ordering observation.'),('CONFIG-002','Extreme public reserve may make NFT outcome practically unreachable; configuration risk, no hidden/unilateral theft.')]),
'I-7':(256,'Informational',[('CONFIG-002','Same extreme reserve configuration.'),('ADVISORY-001','Treasury-prize equality is already rejected atomically by clone initialize; earlier factory validation is fail-fast gas/error consistency, not reachable custody defect.')])}
for ident,(line,sev,targets) in final.items():
 assert lines[line-1].startswith('## '+ident+'.')
 for target,reason in targets:add(target,ident,line,sev,reason)
# Preserve all40 exact native raw IDs and their full native inventory row, without inventing missing raw severity.
raw=[]
for number,line in enumerate(gate,1):
 m=re.match(r'\| `(L\d{2}-(?:FINDING|LEAD)-\d+)` \|',line)
 if not m:continue
 ident=m.group(1);cells=[s.strip() for s in re.split(r'(?<!\\)\|',line)[1:-1]];raw.append({'id':ident,'line':number,'cells':cells,'native_row':line})
assert len(raw)==40 and len({x['id'] for x in raw})==40
rf1={'L02-FINDING-1','L03-LEAD-2','L04-LEAD-1','L05-LEAD-2','L08-LEAD-3','L09-FINDING-1','L10-FINDING-1'}
quote={'L10-LEAD-1','L11-LEAD-4'};econ={'L03-FINDING-1','L07-FINDING-2','L07-LEAD-1','L03-LEAD-1','L07-LEAD-3','L11-LEAD-2'}
for x in raw:
 ident=x['id'];group=x['cells'][3]
 if ident in rf1:targets=['RF-001']
 elif ident in quote:targets=['OBS-002']
 elif ident in econ:targets=['CLOSED-002']
 elif ident in {'L07-FINDING-1','L08-LEAD-2'}:targets=['CLOSED-004']
 elif '_isProtocolDestination' in group:targets=['RF-002','OBS-004']
 elif 'releaseSponsorPrize' in group:targets=['RF-002']
 elif ident=='L02-LEAD-2':targets=['OBS-004']
 elif 'requestDraw' in group:targets=['OBS-008','EVIDENCE-001']
 elif ident in {'L05-LEAD-4','L09-LEAD-2','L12-LEAD-2'}:targets=['OBS-006']
 elif ident in {'L06-LEAD-1','L11-LEAD-3'}:targets=['CONFIG-002']
 elif ident=='L12-LEAD-3':targets=['ADVISORY-001']
 else:raise AssertionError(ident)
 x['targets']=targets
 for target in targets:add(target,ident,x['line'],None,'Exact native raw observation preserved. Reconciled disposition follows corresponding final-ID mechanism; raw FINDING/LEAD type is not independent proof or consensus.',path=P/'gate-ledger.md',status=x['cells'][2].strip('`'),extra={'native_inventory_row':x['native_row'],'native_group_key':group,'raw_source_location':x['cells'][1],'native_raw_anchor':x['cells'][4],'native_resolved_anchor':x['cells'][5]})
# Preserve twelve unnumbered lead summaries by explicit source ordinal, including their original native member IDs.
lead_targets=[['RF-002','OBS-004'],['RF-002'],['OBS-002','RF-001'],['RF-001'],['OBS-004','RF-001'],['OBS-008','CLOSED-002'],['CLOSED-002'],['CLOSED-004'],['CLOSED-002'],['OBS-006'],['OBS-006','CONFIG-002'],['CONFIG-002','ADVISORY-001']]
for n,targets in enumerate(lead_targets,1):
 for target in targets:add(target,f'Unverified leads item {n} (source ordinal; no native final ID)',286+n,'Unrated lead','Native retained lead and stated limit preserved; no additional root or executable proof inferred.',status='native unverified lead')
for ident,target in [('M-1','RF-001'),('M-2','CLOSED-002'),('M-3','CLOSED-002'),('L-1','CLOSED-004'),('L-2','CLOSED-002'),('I-1','RF-002'),('I-2','RF-002')]:
 idx[target].setdefault('model_disagreements',[]).append({'report_key':key,'original_id':ident,'rating':final[ident][1],'resolution':next(reason for t,reason in final[ident][2] if t==target)})
corrections=[
'Native source links sometimes retain concatenation offsets; native gate-ledger resolves these. Final M-1 mitigation Option B mislabels Raffle.sol:388/398 versus actual375/385. DESIGN trust text is line2, not native line5 reference.',
'ENS expiry/ERC721C/mainnet examples are native hypotheses; this reconciliation did not inspect their deployed bytecode, administrative settings or duration-dependent transfer rules and does not adopt them as executed production proofs.',
'Native report M-2/M-3 economic examples do not independently establish a violated advertised fixed-odds or no-sponsor-buy promise. Rebate changes marginal cost but all purchased entries must be funded; capital, prize value and final ownership matter.',
'Adding nonReentrant only to onERC721Received does not prevent a subsequent buyEntries after the callback returns within prize.safeTransferFrom. The separate factory activation proposal is an architecture change requiring regression review.',
'Native L-2 proposed ticketCount >1 does not identify distinct participants: one actor can buy two tickets. Minimum gas price/re-request proposals require wrapper and randomness fairness analysis; no ready patch adopted.',
'Native M-1 payout guard by itself leaves protocolFees ungated in its sample diff and cannot establish prize truthfulness. A complete deadline/refund policy must cover both unsettled and settled NftWon accounting and deliberate winner non-redemption. No OptionC snippet is approved.',
'Full native method semantic completeness remains unchecked; source observation reconciliation is not replacement of the rejected root coordinator gate.'
]
for q in r['assurance_issues']:
 if q['id']=='AQ-009':q.setdefault('post_seal_corrections',[]).append({'report_key':key,'items':corrections})
r['working_updated_utc']=now;r['counts'].update(source_report_paths=len(r['source_reports']),distinct_first_pass_hashes=len({s['sha256'] for s in r['source_reports']}),original_attributions_preserved_and_added=sum(len(x['original_attributions']) for x in r['findings']))
state=json.loads((D/'state.json').read_text());pending='GEMINI-SIMAO/attempt-04 explicit-High leaves and native assembly';assert pending in state['expected_lanes'];state['expected_lanes'].remove(pending);state.setdefault('received_scoped_artifact_receipts',[]).append({'lane':key,'source_adopted':True,'method_semantic_qualification':'unchecked','native_status':'SUCCESS'});state.setdefault('semantic_qualification_pending',[]).append(key);state['updated_utc']=now;r['current_reconciliation_state'].update(updated_utc=now,pending_lanes=state['expected_lanes'],scoped_receipts_with_semantic_qualification_pending=state['semantic_qualification_pending']);r.setdefault('late_scoped_source_artifacts',[]).append(source)
dump(D/'working-register.json',r);dump(D/'working-original-id-index.json',[{'target':x['id'],**a} for x in r['findings'] for a in x['original_attributions']]);dump(D/'state.json',state)
J=D/'GEMINI-SIMAO-04-RECONCILIATION.json';MD=D/'GEMINI-SIMAO-04-RECONCILIATION.md';S=D/'GEMINI-SIMAO-04-RECONCILIATION-SEAL.json';assert not any(p.exists() for p in [J,MD,S])
dump(J,{'reconciled_utc':now,'source_report':source,'receipt_verification':str(D/'GEMINI-SIMAO-04-RECEIPT-VERIFICATION.json'),'native_final_counts':{'High':0,'Medium':3,'Low':2,'Informational':7},'native_raw_inventory':raw,'append_attributions':added,'post_seal_corrections':corrections,'new_production_root_causes':0,'independent_final_method_semantic_acceptance':False,'owner_acceptance':'not requested or inferred','reconciliation_is_separate_from_native_method_gate':True})
MD.write_text('''# Gemini Simao attempt-04 post-seal reconciliation

The scoped artifact seal and all90 referenced hashes (82 distinct paths), including43 frozen inputs and12 original leaf report/receipt pairs, were independently verified. FIRST-PASS.md is `0ef7933f0a78a897c2c0ddec092501f056668c461a5231ff5958e7f0f6aeb937`. The judge completed native SUCCESS using the explicit High route. Its independent final method semantic review remains unchecked after the root coordinator's OpenAI rejection. This reconciliation adopts sealed observations only and does not replace that gate or claim global completion.

The native report lists3Medium,2Low and7Informational entries. Its40 raw IDs and12 final IDs, source anchors,12 unnumbered lead summaries and disagreements are preserved in the paired JSON and working register. These are report/observation counts, never votes or independent defect counts. No new production root cause is established.

M-1 maps to RF-001: prize delivery can fail while previously released sponsor proceeds remain paid. The Medium rating is preserved beside earlier conditional High and Low/integration interpretations. Arbitrary untrusted prizes and honest continually transferable prizes remain different assumptions. The incoming ENS/expiry/ERC721C examples were not independently verified as deployed-token proofs. Existing executed counterfeit and paused-mock evidence remains the practical basis, without assuming any real collection's behavior.

M-2, M-3 and I-4 preserve a substantive disagreement. Sponsor-paid entry purchases, dilution before the deadline and the reserve-triggered cash/NFT split follow the disclosed economics. The sponsor rebate and worked cash example are real consequences of those rules; no fixed-odds promise, prohibited sponsor participation or unauthorized withdrawal was established. The register retains CLOSED-002 and the native Medium ratings rather than treating agreement or strong wording as proof. L-1 similarly preserves Low versus CLOSED-004: a paid entry before an empty cancellation legitimately ends the exception. L-2 splits into caller-funded VRF/service risk and the specified single-owner cash split. Specific multi-day gas-stall causation remains unproved.

I-1 and I-2 map to RF-002, with Informational versus Low retained: a deliberately selected future clone can strand the sponsor's own prize. The existing honest-ERC721 root reproduction supports that restricted sequence. Ticket ownership by such a clone does not make owner-only redemption callable. I-3 retains this recipient-capability issue and RF-001's prize-refusal branch. I-5/I-6 preserve paid creation-callback event ordering, with full outer-transaction rollback on final failure. I-6/I-7 preserve public extreme-reserve configuration risk; treasury-prize equality already reverts atomically during initialize.

No mitigation snippet is approved or applied. A mere callback nonReentrant modifier does not prevent a later call after that callback returns; ticketCount is not a count of distinct owners; a delivery guard must address both payout cohorts, unsettled/settled accounting, winner inaction and dishonest token reports. The final method completeness gap and these corrections stay explicit. No new exploit experiment, source change or owner acceptance occurred.
''')
dump(S,{'sealed_utc':now,'artifacts':{J.name:sha(J),MD.name:sha(MD),'GEMINI-SIMAO-04-RECEIPT-VERIFICATION.json':sha(D/'GEMINI-SIMAO-04-RECEIPT-VERIFICATION.json'),'integrate_simao04.py':sha(Path(__file__))},'native_seal_sha256':source['seal_sha256'],'working_register_snapshot_sha256':sha(D/'working-register.json'),'working_register_remains_mutable':True,'no_final_method_or_global_acceptance':True})
print(json.dumps({'report_paths':r['counts']['source_report_paths'],'distinct_firstpass_hashes':r['counts']['distinct_first_pass_hashes'],'attribution_links':r['counts']['original_attributions_preserved_and_added'],'new_root_causes':0,'seal_sha256':sha(S)}))
