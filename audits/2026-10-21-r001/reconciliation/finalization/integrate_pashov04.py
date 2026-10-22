from pathlib import Path
import datetime,hashlib,json,re
A=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001');D=A/'reconciliation/finalization';P=A/'runs/GEMINI-PASHOV-REPAIRED/attempt-04/adjudication/native-first-pass';key='GEMINI-PASHOV-REPAIRED/attempt-04';now=datetime.datetime.now(datetime.timezone.utc).isoformat()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,o):p.write_text(json.dumps(o,indent=2)+'\n')
r=json.loads((D/'working-register.json').read_text());assert key not in [s['report_key'] for s in r['source_reports']]
v=json.loads((D/'GEMINI-PASHOV-04-RECEIPT-VERIFICATION.json').read_text());assert not v['errors'];assert sha(P/'artifact-integrity-seal.json')==v['seal_sha256']
for x in v['records']:assert sha(Path(x['path']))==x['sha256']
receipt=json.loads((P/'native-artifact-preservation-receipt.json').read_text());assert receipt['nativeTerminalStatus']=='ERROR'
source={'report_key':key,'path':str(P/'FIRST-PASS.md'),'sha256':sha(P/'FIRST-PASS.md'),'seal':str(P/'artifact-integrity-seal.json'),'seal_sha256':sha(P/'artifact-integrity-seal.json'),'seal_verified':True,'all_bound_artifacts_verified':v['record_count'],'distinct_bound_paths':v['distinct_paths'],'frozen_target':'9238b6ce8eb7f768c0dcd0cfcef26e1427a03155','target_binding':'All43 source/build/dependency hashes match frozen clean context;12 original leaf report/receipt hashes match.','native_completion_receipt':None,'native_artifact_preservation_receipt':str(P/'native-artifact-preservation-receipt.json'),'source_only':False,'source_only_note':'Sealed native source-analysis output; no executable proof newly adopted from this report.','native_terminal_status':'ERROR','qualification':'Artifact byte integrity only. Strict stream-interruption ERROR preserved even though original run produced final DONE/report and exact assembler exit0. No accepted transport success or final method semantic qualification; root coordinator OpenAI rejection is separate.','model_route':'Official CLI gemini-4-argon-high efforthigh; original fresh judge identity and12originalleaves bound; no delegated judge children; internal checkpoint unknown.'}
r['source_reports'].append(source);idx={x['id']:x for x in r['findings']};lines=(P/'FIRST-PASS.md').read_text().splitlines();gate=(P/'gate-ledger.md').read_text().splitlines();added=[]
groups={
'G01':(['RF-001'],'Premature proceeds is the existing conditional prize-delivery/payment root; dishonest prize versus honest transferable token scope remains explicit.'),
'G02':(['RF-001'],'Allocation and release are function fragments of the same root, not two independent economic defects.'),
'G03':(['CLOSED-002'],'Sponsor paid purchases, reserve crossing and dilution follow disclosed economics. Native finding/confidence retained; no fixed odds/no-sponsor promise established.'),
'G04':(['CLOSED-002'],'95% payout above reserve is the configured seller share; requires a product-policy change to cap. No unauthorized fund extraction proved.'),
'G05':(['CONFIG-002'],'Extreme public reserve is a configuration risk and cash-outcome policy, not hidden buyer theft.'),
'G06':(['CONFIG-002'],'Same public extreme reserve; bounding a threshold does not guarantee economic reachability.'),
'G07':(['CLOSED-004'],'A paid entry executed before empty cancellation validly ends that exception. Native finding/confidence disagreement retained.'),
'G08':(['RF-002','OBS-004'],'Unsafe prize return is a recipient capability issue with separately reproduced sponsor-selected future-clone subset; own-recipient loss, not general theft.'),
'G09':(['OBS-008','CLOSED-002'],'Caller pays a disclosed native VRF fee; CashWon is an explicit outcome. Sponsor cannot veto other permissionless callers; withholding alone is not control of the draw.'),
'G10':(['RF-002','OBS-004'],'Counterfactual destination can strand its own chosen custody; permissionless settlement isolates unrelated claims. Native demotion to lead preserved beside Low/Info assessments.'),
'G11':(['EVIDENCE-001'],'Wrapper-only callback guard blocks an ordinary refund recipient; synchronous trusted-wrapper behavior is an unvalidated integration assumption, not proven unprivileged reentrancy.'),
'G12':(['OBS-008','EVIDENCE-001'],'Timeout/refund cost and service availability remain operational dependencies; no attacker-controlled forced timeout demonstrated.'),
'G13':(['OBS-002'],'Issuer can block immutable payout recipient; pull-payment cohorts remain isolated.'),
'G14':(['EVIDENCE-001'],'Synchronous wrapper is not established for supported asynchronous VRF; no production exploit proved.'),
'G15':(['EVIDENCE-001'],'Gas quote depends on eth_call parameters; explicit estimateVrfRequestPrice exists and underpayment reverts atomically. Offchain calls are not invariably zero gas price.'),
'G16':(['ADVISORY-001'],'Initializer already applies sponsor guard atomically; earlier factory check is fail-fast consistency, not active-raffle vulnerability.'),
'G17':(['CONFIG-001'],'Final lead correctly states nonce collision. Gate paragraph incorrectly supposes matching clone registers first: initialize rejects treasury==self before registry. Actual risk is blocked creation at that nonce.')}
conf={'G01':90,'G02':90,'G03':90,'G04':90,'G05':85,'G06':85,'G07':75,'G08':75,'G09':75}
def attr(target,ident,line,path,reason,extra=None):
 a={'report_key':key,'report_path':str(path),'report_line':line,'original_id':ident,'original_severity':None,'original_status':'unqualified native-ERROR artifact observation; not method completion','proof_status':'Native written argument only; no new executed proof adopted','reconciled_reason':reason}
 if extra:a.update(extra)
 idx[target]['original_attributions'].append(a);added.append({'target':target,**a})
# Final assembler IDs are numeric, confidence is not severity.
finalmap={1:('G02',17),2:('G04',45),3:('G03',65),4:('G01',97),5:('G06',115),6:('G05',134),7:('G07',163),8:('G08',199),9:('G09',221)}
for n,(g,line) in finalmap.items():
 assert f'**{n}. ' in lines[line-1]
 for target in groups[g][0]:attr(target,str(n),line,P/'FIRST-PASS.md',groups[g][1],{'original_confidence':conf[g],'native_group_id':g,'original_title':lines[line-1]})
# All17 gate groups and33raw IDs retain exact original IDs and anchors.
groupinventory=[]
for number,line in enumerate(gate,1):
 m=re.match(r'### `(G\d{2})`',line)
 if m:
  g=m.group(1);assert g in groups;groupinventory.append({'id':g,'line':number,'heading':line,'targets':groups[g][0]})
  for target in groups[g][0]:attr(target,g,number,P/'gate-ledger.md',groups[g][1],{'original_confidence':conf.get(g),'native_heading':line,'native_disposition':'finding' if g in conf else 'lead'})
assert len(groupinventory)==17
raw=[]
for number,line in enumerate(gate,1):
 m=re.match(r'\| `(L\d+-\d+)` \|',line)
 if not m:continue
 cells=[s.strip() for s in re.split(r'(?<!\\)\|',line)[1:-1]];g=cells[-1].strip('`');assert g in groups
 x={'id':m.group(1),'line':number,'native_row':line,'cells':cells,'group':g,'targets':groups[g][0]};raw.append(x)
 for target in groups[g][0]:attr(target,x['id'],number,P/'gate-ledger.md',groups[g][1],{'native_inventory_row':line,'original_kind':cells[2].strip('`'),'native_group_id':g,'native_source_anchors':cells[6]})
assert len(raw)==33 and len({x['id'] for x in raw})==33
leadmap=['G17','G10','G14','G15','G16','G13','G11','G12']
for n,g in enumerate(leadmap,1):
 line=257+n;assert lines[line-1].startswith('- **')
 for target in groups[g][0]:attr(target,f'Leads item {n} (source ordinal; no native final ID)',line,P/'FIRST-PASS.md',groups[g][1],{'original_title':lines[line-1],'native_group_id':g,'original_kind':'unscored lead'})
corrections=[
'Confidence scores90/85/75 are native confidence, not severity ratings. Ninefinal entries/17groups/33rawitems are different denominators and no model-vote proof.',
'The report states three implementation files in its scope table; receipt confirms43inputfiles including both interfaces. That does not independently prove all functions or dependencies reviewed.',
'Example fixes use signatures/error names absent from frozen source (external override/one return value/NoSponsorProceeds/ZeroEntryCount/etc). These are uncompiled model sketches, not ready patches.',
'Ban sponsor address purchases is bypassable by another funded address; entry caps and redirected excess fees change the economic product. No policy rewrite approved.',
'Native G09 raw fix asks sponsor-funded or reimbursed VRF fees, but final item9 snippet forbids missed-reserve draws; this changes outcome policy and does not implement that fee remedy.',
'Proposed releaseSponsorPrize fallback reroutes a fixed recipient to sponsor on any safe-transfer failure, changing beneficiary policy and token/reentrancy behavior. No fallback authorized or tested.',
'Native G17 ledger says treasury clone registers before later payout failures; initialize actually rejects treasury==self before registration. Final report lead correctly narrows to blocked factory nonce.',
'Final item9 sponsor-withhold language overstates capability: requestDraw is permissionless; sponsor can abstain but cannot block another funded caller.',
'Final method semantic qualification and strict transport success remain unaccepted after native ERROR. This source reconciliation is not replacement of the rejected coordinator.'
]
for q in r['assurance_issues']:
 if q['id']=='AQ-009':q.setdefault('post_seal_corrections',[]).append({'report_key':key,'items':corrections})
for g in ['G01','G02','G03','G04','G07','G08','G09','G10']:
 for target in groups[g][0]:idx[target].setdefault('model_disagreements',[]).append({'report_key':key,'native_group_id':g,'native_confidence':conf.get(g),'native_disposition':'confirmed finding' if g in conf else 'lead','resolution':groups[g][1],'transport_qualification':'ERROR preserved; artifact only'})
r['working_updated_utc']=now;r['counts'].update(source_report_paths=len(r['source_reports']),distinct_first_pass_hashes=len({s['sha256'] for s in r['source_reports']}),original_attributions_preserved_and_added=sum(len(x['original_attributions']) for x in r['findings']))
state=json.loads((D/'state.json').read_text());pending='GEMINI-PASHOV/attempt-04 explicit-High leaves and native adjudication';assert pending in state['expected_lanes'];state['expected_lanes'].remove(pending);state.setdefault('received_scoped_artifact_receipts',[]).append({'lane':key,'source_adopted':True,'method_semantic_qualification':'unaccepted','native_status':'ERROR'});state.setdefault('semantic_qualification_pending',[]).append(key);state['updated_utc']=now;r['current_reconciliation_state'].update(updated_utc=now,pending_lanes=state['expected_lanes'],scoped_receipts_with_semantic_qualification_pending=state['semantic_qualification_pending']);r.setdefault('late_scoped_source_artifacts',[]).append(source)
dump(D/'working-register.json',r);dump(D/'working-original-id-index.json',[{'target':x['id'],**a} for x in r['findings'] for a in x['original_attributions']]);dump(D/'state.json',state)
J=D/'GEMINI-PASHOV-04-RECONCILIATION.json';MD=D/'GEMINI-PASHOV-04-RECONCILIATION.md';S=D/'GEMINI-PASHOV-04-RECONCILIATION-SEAL.json';assert not any(p.exists() for p in [J,MD,S])
dump(J,{'reconciled_utc':now,'source_report':source,'receipt_verification':str(D/'GEMINI-PASHOV-04-RECEIPT-VERIFICATION.json'),'native_counts':{'final_confidence_scored_entries':9,'unscored_final_leads':8,'canonical_groups':17,'raw_observations':33,'raw_findings':15,'raw_leads':18},'native_raw_inventory':raw,'native_group_inventory':groupinventory,'append_attributions':added,'post_seal_corrections':corrections,'new_production_root_causes':0,'native_transport_success_accepted':False,'independent_final_method_semantic_acceptance':False,'owner_acceptance':'not requested or inferred','reconciliation_is_separate_from_native_method_gate':True})
MD.write_text('''# Gemini Pashov attempt-04 post-seal artifact reconciliation

The distinct artifact seal and93 referenced hashes across83paths were verified without mismatch, including43frozeninputs and12originalleaf report/receipt pairs. FIRST-PASS.md is `8ce7d94cc8b647495014f011ff03c2093cc09e22e255606b44c94c1c1087d802`. The original native run remains strict ERROR after a stream interruption. Its later final DONE response and unchanged native assembler exit0 produced the sealed bytes, but neither transport success nor final method semantic completeness has been accepted. No continuation was issued to erase the error. The root coordinator's separate OpenAI rejection is preserved, not replaced by this reconciliation.

Nine confidence-scored final entries, eight unscored leads,17canonical groups and33raw IDs are preserved separately. Confidence90/85/75 is not severity. No new production root cause or executable proof is adopted. These are sealed hypotheses from an unqualified native run, not a completed required workflow cell.

Final1/4 and G01/G02 merge into RF-001's conditional prize-delivery/proceeds chain. Final2/3 and G03/G04 describe configured sponsor economics and remain disputed against CLOSED-002. Final5/6 preserve public extreme-reserve configuration risk. Final7 remains disputed against CLOSED-004's paid-entry-before-cancellation behavior. Final8 maps to recipient capability and RF-002's separately reproduced sponsor-selected future-clone own-prize loss. Final9 splits between caller-funded VRF/service dependence and the explicitly specified cash outcome. A sponsor can abstain from paying for a draw but cannot veto another permissionless caller.

The counterfactual recipient group G10 remains a native lead; its demotion and own-recipient precondition are retained. G11/G14 synchronous callback hypotheses require trusted-wrapper behavior not established here, and an ordinary refund recipient cannot bypass wrapper authentication. G12 retains service-timeout cost; G13 retains issuer-controlled immutable-recipient blocking; G15 retains gas-quote integration, with explicit estimator and atomic underpayment rejection. G16 is fail-fast validation consistency. G17's final lead correctly describes creation-nonce blockage, while its gate-ledger claim that a matching treasury clone first registers is corrected: initialize rejects treasury==self before registration.

No sample fix is approved. Several snippets use signatures and errors absent from the frozen source. An address-only sponsor ban is not Sybil-resistant; proposed caps, cash-outcome removal and redirected fees change product economics. The item9 snippet does not implement its raw fee-funding remedy. The safe-transfer fallback changes the configured prize beneficiary. The complete supported-asset policy, payout/refund accounting and recipient authority need a separate authorized remediation and re-audit. All prior seals and model disagreements remain intact; no source edit, new exploit experiment or owner acceptance occurred.
''')
dump(S,{'sealed_utc':now,'artifacts':{J.name:sha(J),MD.name:sha(MD),'GEMINI-PASHOV-04-RECEIPT-VERIFICATION.json':sha(D/'GEMINI-PASHOV-04-RECEIPT-VERIFICATION.json'),'integrate_pashov04.py':sha(Path(__file__))},'native_seal_sha256':source['seal_sha256'],'working_register_snapshot_sha256':sha(D/'working-register.json'),'working_register_remains_mutable':True,'native_error_preserved':True,'no_final_method_or_global_acceptance':True})
print(json.dumps({'report_paths':r['counts']['source_report_paths'],'distinct_firstpass_hashes':r['counts']['distinct_first_pass_hashes'],'attribution_links':r['counts']['original_attributions_preserved_and_added'],'new_root_causes':0,'pending_source_receipts':state['expected_lanes'],'seal_sha256':sha(S)}))
