from pathlib import Path
import json,datetime,hashlib,shutil
w=Path.cwd();a=w/'audit-artifacts';p=a/'stage-ledger.json';d=json.loads(p.read_text());now=datetime.datetime.now(datetime.timezone.utc).isoformat();out=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/OPENAI-PASHOV/attempt-01')
assert not (a/'SEAL.json').exists(), 'Never overwrite a sealed pass'
model={'accepted_local_model':'gpt-6-astra','accepted_local_reasoning_effort':'ultra','provider_returned_model':'unknown','provider_returned_reasoning_effort':'unknown','fallback_used':False}
d['stages'] += [dict(id='FIRST-PASS-original-conclusions',status='COMPLETE',evidence='FIRST-PASS.md',**model),{'id':'SEAL-first-pass','status':'COMPLETE','execution':'SHA256 over FIRST-PASS.md and every preserved artifact; atomic seal-file write','evidence':'SEAL.json','external_reconciliation_preceded_seal':False}]
for s in d['stages']:
 s.setdefault('stage_actor','root orchestrator' if not s['id'].startswith('T3-specialist-') else s.get('agent_task'))
 if s.get('status') in ['DISABLED','DISABLED_BY_USER','NOT_REQUESTED','NOT_PERFORMED']:
  s.setdefault('settings',{'model':'not applicable; stage disabled','effort':'not applicable','provider_returned_model':'unknown','provider_returned_effort':'unknown'})
 elif s['id'].startswith(('T5.','TARGET-','EVM-','SEAL-')):
  s.setdefault('settings',{'model':'not applicable; deterministic execution or absent runtime proof','effort':'not applicable','provider_returned_model':'unknown','provider_returned_effort':'unknown'})
 else:s.setdefault('settings',dict(model))
d['finished_at']=now;d['native_status']='INCOMPLETE';d['fallback_policy']={'requested':'disabled','workflow_substitution':'none','retries_with_alternative_model':0,'tool_level_fallback_switch':'not exposed','provider_internal_fallback':'unknown'}
d['external_reconciliation']='NOT_PERFORMED';d['seal']='SEAL.json';d['sealed_report']='FIRST-PASS.md';d['output_directory']=str(out)
p.write_text(json.dumps(d,indent=2)+'\n')
coverage=json.loads((a/'coverage-matrix.json').read_text());report=(a/'full-report.md').read_text();lines=[
'# OPENAI-PASHOV — original first pass',
'',f'Recorded at: **{now}**',
'',f'Target SHA: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`. Pashov pin: `8ce544c9c9affab448d3dc4c79191d052e3a57ec`.',
'', '**Status: INCOMPLETE — 5 of 12 specialists returned final reports.** Access-control, economic-security, periphery, asymmetry, boundary, trust-gap, and flow-gap were blocked by the runtime cybersecurity-risk filter. The workflow did not retry them or substitute models.',
'', 'The returned reports produced **zero confirmed findings and one unscored lead** after native deduplication and validation. This conclusion covers the five returned specialties; it is not a complete 12-specialist scan.',
'', 'This is the original single pass. Prior-project memory and repeated-run finding memory were off. No historical audit, tests, scanner results, accepted-risk lists, source history, peer-cell conclusions, or external reconciliation were consulted.',
'', '## Model provenance',
'', 'Every specialist was launched in a fresh context with explicit local selection `gpt-6-astra` and reasoning effort `ultra`. All 12 spawn calls accepted those arguments. Root orchestration, deduplication, judgment, and report preparation used the runner-declared same selection. Provider-returned model and effort are `unknown`: the available tool responses exposed no such fields. No identity claim relies on model self-identification. No alternative-model retry occurred; no provider-internal fallback switch or telemetry was exposed.',
'', '## Original conclusions',
'', 'The sole lead is `Raffle.releaseSponsorProceeds | untrusted-prize-payout`. The source allows sponsor payment before NFT delivery and provides no refund transition from `NftWon`. With 100 entries and a reserve of 100, settlement allocates 95,000,000 raw USDC units to the sponsor and 5,000,000 to the treasury. The supplied snapshot does not include a prize implementation that passes creation and subsequently refuses valid delivery. This missing step prevents a confirmed exploit claim. `DESIGN.md` treats arbitrary prize contracts as untrusted; `IRaffle.sol` describes honest standards-compliant prizes. This trust-boundary mismatch remains for manual resolution.',
'', 'Agents 5 and 7 independently raised this lead with different class labels. The native deduplication retained the shorter defect label and both mechanisms. Agreement alone did not promote it: the user requires a concrete source-supported path. `dedup-decisions.json` and `judge-decisions.json` preserve that decision and the ordered gate evidence.',
'', 'The math, execution-trace, invariant, first-principles, and numerical-gap reviews covered the source and supplied dependencies. No other candidate survived as a finding or lead. Missing specialist reports remain coverage gaps even where returned specialists considered related properties.',
'', '## Per-file coverage',
'', '| Production file | Returned review coverage | SHA256 of original file |', '|---|---|---|']
for row in coverage['files']:
 relative=Path(row['path']).relative_to(w)
 lines.append(f'| `{relative}` | Agents 1, 4, 5, 7, 10; seven required specialties absent | `{row["sha256"]}` |')
lines += ['', 'Both interfaces were explicitly included despite the default upstream interface exclusion. Every specialist bundle contained all five production files, clean `DESIGN.md`, and all 31 supplied dependency files. The import-closure check resolved all 59 imports across 36 Solidity files. All 31 supplied dependency hashes matched. All 43 target-file hashes remained unchanged.',
'', '## Per-property coverage',
'', 'The table records properties examined by returned specialists. “Reviewed” does not assert the absence of defects. Detailed function lists, conditions, and proof limitations remain in each raw coverage JSON.',
'', '| Property | Scope and observation | Coverage status |', '|---|---|---|']
for prop in coverage['properties']:
 observation=prop['property'].replace('|','/')
 status='LEAD — external failure unproven' if prop['id']=='untrusted-prize-delivery' else 'Reviewed by returned specialists; full native coverage incomplete'
 lines.append(f'| `{prop["id"]}` | {observation} | {status} |')
lines += ['', '## Individual specialist stages', '', '| ID | Specialty | Local model / effort | Provider model | Result |', '|---|---|---|---|---|']
for s in d['stages']:
 if s['id'].startswith('T3-specialist-'):
  n=int(s['id'].split('-')[-1]); result='COMPLETE — final report and coverage preserved' if s['status']=='COMPLETE' else 'BLOCKED — runtime filter; no final report'
  lines.append(f'| {n} | {s["specialty"]} | `gpt-6-astra` / `ultra` | `unknown` | {result} |')
lines += ['', '## Native stage evidence and limits',
'', '- Discovery, explicit scope, full pinned resource loading, bundle preparation, and all 12 fresh-context launches completed. All task completion notifications arrived before deduplication.',
'- Native deduplication, ordered validation, lead disposition, `run-1.md`, and `scope.tsv` completed for the returned reports. All raw candidate tuples are accounted for: one distinct contract/function, one final lead.',
'- The exact pinned `assemble.sh` ran unchanged and exited 0. Its output is `full-report.md`; stdout, stderr, the execution record, and native intermediate TSVs are preserved. Native counting returned 0 findings, 1 lead, and matching confidence-bucket totals.',
'- The unmodified assembler suppresses its Passes row for a one-pass run, so its report alone does not display the 5/12 shortfall. This document, `stage-ledger.json`, `scope.tsv`, `run-1.md`, and the pass summary explicitly record the incomplete coverage.',
'- Bundles were copied and hash-checked before cleanup. The native force-removal command was rejected by local command review; an exact 13-file allowlist was then hash-verified and removed, preserving every archived copy.',
'- Independent arithmetic models passed: agent 1 checked 15,385 totals, 5,000 refund partitions, and 15 deadline cases; agent 5 passed 309,796 assertions over 1,005 partitions; agent 10 checked 100,012 entry counts and 5,000 refund partitions. These are Python models, not EVM proofs.',
'- EVM proof execution and deployment integration remain INCOMPLETE. Failed agents 9 and 11 left isolated proof harnesses, preserved without a successful result claim. The snapshot supplies interfaces and consumer code for canonical USDC and Chainlink, not the deployed implementations or configuration.',
'- Target SHA and harness pin are runner-supplied identifiers. No git history was accessed to attest them independently; exact loaded bytes are identified by SHA256 manifests.',
'- The runtime exposes agent messages and final/error text but does not expose provider model metadata or a downloadable internal subagent tool transcript. Every exposed response and generated filesystem artifact is preserved.',
'', '## Seal and artifacts',
'', '`SEAL.json` records SHA256 hashes for this document and every preserved artifact. `stage-ledger.json` records individual stages, settings, resources, hashes, coverage, and failures. The `raw/`, `bundles/`, `native/`, `native-assembler-intermediates/`, `proofs/`, and `logs/` directories preserve the underlying evidence. Any subsequent correction must be appended in a new artifact; sealed files must not be overwritten. No external reconciliation preceded this seal.',
'', '## Native assembler output — verbatim', '', report.rstrip('\n'), '']
(a/'FIRST-PASS.md').write_text('\n'.join(lines))
# Inventory is made after reports and ledger are final; the seal itself is excluded.
records=[]
for f in sorted(a.rglob('*')):
 if f.is_file() and f.name!='SEAL.json':
  records.append({'path':str(f.relative_to(a)),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'bytes':f.stat().st_size})
seal={'schema':'OPENAI-PASHOV-first-pass-seal-v1','sealed_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'target_sha':d['target_sha'],'harness_pin':d['harness_pin'],'algorithm':'SHA256','first_pass_sha256':next(x['sha256'] for x in records if x['path']=='FIRST-PASS.md'),'native_report_sha256':next(x['sha256'] for x in records if x['path']=='full-report.md'),'stage_ledger_sha256':next(x['sha256'] for x in records if x['path']=='stage-ledger.json'),'external_reconciliation':'NOT_PERFORMED','native_scan_status':'INCOMPLETE','artifact_count':len(records),'artifacts':records,'immutability_rule':'Append corrections in new files; do not overwrite sealed reports or evidence.'}
(a/'SEAL.json.part').write_text(json.dumps(seal,indent=2)+'\n');(a/'SEAL.json.part').rename(a/'SEAL.json')
out.mkdir(parents=True,exist_ok=True)
for src in a.iterdir():
 dst=out/src.name
 if src.is_dir():shutil.copytree(src,dst,dirs_exist_ok=True)
 else:shutil.copy2(src,dst)
checks=[]
for r in records:
 checks.append({'path':r['path'],'match':hashlib.sha256((out/r['path']).read_bytes()).hexdigest()==r['sha256']})
assert all(r['match'] for r in checks)
verification={'verified_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'seal_sha256':hashlib.sha256((out/'SEAL.json').read_bytes()).hexdigest(),'sealed_artifacts_verified':len(checks),'all_match':True,'output':str(out),'note':'This verification file is appended after the seal and is not included in its own manifest.'}
(out/'SEAL-VERIFICATION.json').write_text(json.dumps(verification,indent=2)+'\n');(a/'SEAL-VERIFICATION.json').write_bytes((out/'SEAL-VERIFICATION.json').read_bytes())
print(json.dumps({'output':str(out),'first_pass_sha256':seal['first_pass_sha256'],'seal_sha256':verification['seal_sha256'],'artifacts_verified':len(checks),'status':'SEALED; native scan INCOMPLETE'},indent=2))
