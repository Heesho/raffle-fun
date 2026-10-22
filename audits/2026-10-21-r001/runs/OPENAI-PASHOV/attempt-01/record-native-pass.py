from pathlib import Path
import json,datetime,subprocess,hashlib,re
w=Path.cwd();a=w/'audit-artifacts';run=w/'.solidity-auditor/runs/20261021-004900'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
model={'accepted_local_model':'gpt-6-astra','accepted_local_reasoning_effort':'ultra','provider_returned_model':'unknown','fallback_used':False,'actor':'root orchestrator','evidence':'runner-declared root selection; no provider model field available'}
raw=[]
for n in [1,4,5,7,10]:
 text=(a/f'raw/agent-{n}.md').read_text()
 for m in re.finditer(r'^(FINDING|LEAD) \| contract: ([^|]+) \| function: ([^|]+) \| bug_class: ([^|]+) \| group_key: (.+)$',text,re.M):
  raw.append({'agent':n,'kind':m[1],'contract':m[2].strip(),'function':m[3].strip(),'bug_class':m[4].strip(),'raw_group_key':m[5],'raw_report':f'raw/agent-{n}.md'})
key='raffle|releasesponsorproceeds|untrusted-prize-payout'
dedup={'stage_id':'T4.1-dedup','timestamp':now,**model,'raw_records':raw,'canonicalization':[{'tuple':['Raffle','releaseSponsorProceeds'],'raw_labels':['untrusted-prize-payout','prize-transferability-assumption'],'canonical_label':'untrusted-prize-payout','reason':'one vote per label; shorter defect label wins; no memory vocabulary exists'}],'groups':[{'key':key,'kind':'LEAD','agents':[5,7],'agents_count':2,'mechanisms':['Sponsor proceeds can be released before NFT delivery.','NftWon cannot transition to Refunding if a later external prize transfer fails.'],'distinct_raw_fixes':0,'fix_preservation':'not applicable to leads; neither raw response supplies a fix','function_isolation':'only one Contract,function tuple; no cross-function merging','wide_description':'both payout-before-delivery and missing terminal refund fallback retained','function_level_second_pass':'all mechanisms from both raw constituent bodies retained'}],'completeness':{'unique_raw_contract_function':1,'covered_final_contract_function':1,'unique_raw_class_tuples':2,'canonical_groups':1,'silently_dropped':0},'composite_chains':[]}
(a/'dedup-decisions.json').write_text(json.dumps(dedup,indent=2)+'\n')
gates=[
 {'id':'T4.2-gate-1-attack-execution','verdict':'ALLOWS','detail':'The supplied guards allow an ordinary NftWon raffle to settle and release sponsor proceeds before redemption. Invalid prize deposits revert at factory owner/status checks; failed NFT delivery reverts the redemption transaction. No guard reverses an already completed separate sponsor release. This clears only the source-supported ordering, not the unproven external failure.','source':['RaffleFactory.sol:97-134','Raffle.sol:176-205','Raffle.sol:209-236','Raffle.sol:240-272','Raffle.sol:509-523','Raffle.sol:533-557','Raffle.sol:375-380','Raffle.sol:309-336','Raffle.sol:564-566']},
 {'id':'T4.2-gate-2-reachability','verdict':'UNCERTAIN','native_path_interruption_treatment':'ALLOWS','detail':'The payout-before-delivery state is reachable through ordinary purchases, authenticated resolution, and permissionless settlement. The bundle contains no concrete accepted prize implementation that later refuses every valid delivery. This external step remains unproven; no claim that a deployment with it exists.','source':['RaffleFactory.sol:154-178','Raffle.sol:518-521','Raffle.sol:533-557','IRaffle.sol:11-15','DESIGN.md']},
 {'id':'T4.2-gate-3-trigger','verdict':'ALLOWS','detail':'Any unprivileged sponsor can create a raffle; anyone can settle a valid winning range and trigger payment to the fixed sponsorRecipient. No owner/admin action or configuration change is required for the supported part.','source':['RaffleFactory.sol:97','Raffle.sol:304-305','Raffle.sol:375-380']},
 {'id':'T4.2-gate-4-impact','verdict':'UNCERTAIN','disposition':'KEEP_LEAD','detail':'100 entries allocate 95,000,000 units to the sponsor and 5,000,000 to the treasury. A winner would lose prize delivery only if the external prize exhibits the unproven refusal behavior. The bundle proves the accounting and payout order, not concrete material harm. The user requires a concrete source-supported path, so no finding or confidence score is assigned.','source':['Raffle.sol:334-336','Raffle.sol:543-544','Raffle.sol:276-294']}
]
judge={'stage_id':'T4.2-validation','timestamp':now,**model,'group_key':key,'ordered_gates':gates,'fixed_path_order':'construction and configuration → creation and initialization → purchase → request/callback → settlement → payout → redemption/refund; no setters, swaps, or liquidations exist','path_excerpt_artifact':'logs/judge-source-paths.txt','final_kind':'LEAD','confidence':None,'verdict_revisited':False,'lead_promotion':{'stage_id':'T4.3-lead-promotion','cross_contract_echo':False,'multi_agent_convergence':True,'promoted':False,'reason':'User explicitly requires concrete source-supported paths; agreement by two specialists cannot establish the missing external failure. This overrides native convergence-only promotion.'}}
(a/'judge-decisions.json').write_text(json.dumps(judge,indent=2)+'\n')
(a/'logs/completeness.txt').write_text('Completeness: 1 unique (Contract, function) in raw, 1 covered in final.\n')
(a/'logs/pass-summary.txt').write_text('Pass 1/1: 5/12 specialist reports returned; 7 failed: access-control, economic-security, periphery, asymmetry, boundary, trust-gap, flow-gap. Scan coverage INCOMPLETE.\n')
body='''# Run 1 — solidity-auditor

<!--RUN pass=1 of=1 stamp=20261021-004900 sha=9238b6ce8eb7f768c0dcd0cfcef26e1427a03155 agents=5/12-->

Pass 1 of 1 · 2026-10-21 · `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155` · 5/12 agents returned — access-control, economic-security, periphery, asymmetry, boundary, trust-gap, and flow-gap failed through the runtime cybersecurity-risk filter. Coverage is INCOMPLETE.

## Findings

## Leads

<!--F key=raffle|releasesponsorproceeds|untrusted-prize-payout kind=LEAD agents=2-->

- **The sponsor receives proceeds before prize delivery** — `Raffle.releaseSponsorProceeds` — Code smells: Sponsor payment precedes prize delivery; `NftWon` has no refund transition. — A sponsor can receive 95% before prize delivery; the supplied source does not prove a prize contract that later blocks delivery.

<!--/F-->
'''
(run/'run-1.md').write_text(body)
with (run/'scope.tsv').open('ab') as out:subprocess.run(['printf','%s\t%s\n','pass_1_agents','5/12'],stdout=out,check=True)
p=a/'stage-ledger.json';d=json.loads(p.read_text())
for stage in [{'id':'T4.1-dedup','status':'COMPLETE','evidence':'dedup-decisions.json'},*({'id':g['id'],'status':'COMPLETE','verdict':g['verdict'],'evidence':'judge-decisions.json'} for g in gates),{'id':'T4.3-lead-promotion','status':'COMPLETE','evidence':'judge-decisions.json'},{'id':'T4.5-record-pass','status':'COMPLETE','evidence':str(run/'run-1.md')}]:d['stages'].append({**stage,**model})
d['stages'] += [{'id':'T4.4-memory-tag','status':'DISABLED_BY_USER'},{'id':'T4.6-memory-write','status':'DISABLED_BY_USER'},{'id':'T5.1-copy-memory','status':'DISABLED_BY_USER'}]
d['native_single_pass_display_limitation']='Unmodified assembler suppresses the Passes row for one pass and therefore does not display 5/12 specialist degradation. FIRST-PASS.md, run-1.md, scope.tsv, pass-summary.txt, final response, and this ledger disclose it.'
d['final_disposition']={'confirmed_findings':0,'leads':1,'raw_leads':2,'returned_specialists':5,'planned_specialists':12,'native_scan_status':'INCOMPLETE'}
p.write_text(json.dumps(d,indent=2)+'\n')
print((a/'logs/completeness.txt').read_text(),end='')
