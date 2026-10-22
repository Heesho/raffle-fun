from pathlib import Path
import json,hashlib,shutil,datetime
w=Path.cwd();a=w/'audit-artifacts';p=a/'stage-ledger.json';d=json.loads(p.read_text());now=datetime.datetime.now(datetime.timezone.utc).isoformat();b=w/'.audit-9aXxui';run=w/'.solidity-auditor/runs/20261021-004900'
sha=lambda f:hashlib.sha256(Path(f).read_bytes()).hexdigest()
progress={
1:['I completed the full 7,444-line bundle read, including all dependency context. Math review currently shows bounded entry products, exact fee splits at six decimals, safe range sums, and guarded native refunds. I am checking adversarial boundary traces and preparing coverage.'],
2:['Agent 2 has fully read the 7,423-line bundle and all bundled dependency context. I am tracing initialization, callback authority, ticket-owner claims, inherited ERC-721 permissions, and untrusted prize behavior. No target writes or peer reads.'],
4:['Agent 4 execution review is complete. I read all 7,429 bundle lines, including 37 source/design/dependency sections, and preserved audit-artifacts/raw/agent-4.md plus agent-4.coverage.json. No concrete exploit path was confirmed. Coverage records hashes, all declared function signatures, reviewed properties, and limitations; provider_model remains unknown.'],
5:['I read all 7,440 bundle lines, including both interfaces, clean DESIGN.md, and all dependency context. Core accounting, range uniqueness, burn authorization, and deadline transitions currently hold. I am checking whether untrusted-prize delivery refusal produces a reportable path under DESIGN.md versus the source\'s honest-prize assumption; no confirmed invariant finding yet.','Independent invariant model passed 309,796 assertions over 1,005 purchase partitions, uint128 extremes, all payout orders, refund orders, and deadline boundaries. No EVM execution. I will retain one LEAD for the untrusted-prize assumption: releaseSponsorProceeds pays before prize delivery, but supplied source has no concrete prize implementation that proves refusal after escrow. No confirmed findings.','Saved exact native report to audit-artifacts/raw/agent-5.md and complete manifest to audit-artifacts/raw/agent-5.coverage.json. Coverage includes all 37 bundled source/design sections, 404 declared function entries, 26 invariant properties, exact source hashes, requested local model selection, provider_model unknown, and no target modifications. Result: zero confirmed findings and one explicit untrusted-prize LEAD.'],
6:['I am reading the complete specialist bundle and tracing clone initialization, token callbacks, and payout recipients. I will preserve the independent report and coverage artifacts at the assigned paths.'],
7:['I read all 7,432 bundle lines, including all five production files, DESIGN.md, dependency context, and specialist rules. I am tracing first-principles assumptions and concrete attack paths; no confirmed finding yet. Current provider model remains unknown as required.'],
9:['Agent 9 has read the full 7,475-line bundle and all 31 dependency sections. Boundary checks hold for USDC returns, native fees, callback guards, entry limits, and ticket burns. I am assessing the design/source trust mismatch for arbitrary prize contracts versus sponsor payouts before prize delivery; no finding is promoted yet.']}
for n in range(1,13):
 msgs=[{'kind':'MESSAGE','text':msg,'provider_model':'unknown'} for msg in progress.get(n,[])]
 final=a/f'raw/agent-{n}.returned.txt';error=a/f'raw/agent-{n}.runtime-error.txt'
 if final.exists():msgs.append({'kind':'FINAL_ANSWER','text':final.read_text().rstrip('\n'),'provider_model':'unknown'})
 elif error.exists():msgs.append({'kind':'RUNTIME_ERROR','text':error.read_text().rstrip('\n'),'provider_model':'unknown'})
 (a/f'raw/agent-{n}.messages.json').write_text(json.dumps({'note':'Text notifications exposed by collaboration tools; provider transport envelope, usage, model identity and internal tool-call transcript are not exposed.','messages':msgs},indent=2)+'\n')
 s=next(s for s in d['stages'] if s['id']==f'T3-specialist-{n}')
 s['accepted_local_model']='gpt-6-astra';s['accepted_local_reasoning_effort']='ultra';s['provider_returned_model']='unknown';s['provider_returned_effort']='unknown';s['fallback_used']=False;s['messages_artifact']=f'raw/agent-{n}.messages.json';s['messages_sha256']=sha(a/f'raw/agent-{n}.messages.json')
 s['prompt_sha256']=sha(a/f'raw/agent-{n}.prompt.txt')
 s['bundle_read_status']='complete per returned coverage artifact' if n in [1,4,5,7,10] else 'incomplete or unknown; no final coverage artifact'
 if n in [1,4,5,7,10]:
  cov=json.loads((a/f'raw/agent-{n}.coverage.json').read_text());s['coverage_sha256']=sha(a/f'raw/agent-{n}.coverage.json');s['report_sha256']=sha(a/f'raw/agent-{n}.md');s['resources_loaded']=cov['resources_read'];s['bundled_source_resources']=[{'path':r['path'],'sha256':r['sha256'],'access':'embedded in full-read bundle'} for r in d['resources'] if r['category'] in ['production','dependency','design']]
 else:s['coverage_gap']='Specialist has no final report and is not counted as complete, regardless of progress messages or unfinished proof files.'
 if n in [9,11]:s['partial_artifacts']={'path':f'proofs/agent-{n}/','status':'INCOMPLETE','note':'Proof harness and source copies preserved from failed agent; no successful EVM result was returned, and these files are not treated as confirmed findings.'}
# Source-integrity verification is hash-only; it does not reopen any verdict.
baseline=json.loads((a/'logs/target-baseline.json').read_text());checks=[{'path':r['path'],'expected_sha256':r['sha256'],'actual_sha256':sha(w/r['path']),'matches':r['sha256']==sha(w/r['path'])} for r in baseline]
assert all(x['matches'] for x in checks)
(a/'logs/target-final-integrity.json').write_text(json.dumps({'timestamp':now,'all_unchanged':True,'checks':checks},indent=2)+'\n')
# Archive the exact bundles before the native cleanup step.
shutil.copytree(b,a/'bundles',dirs_exist_ok=False)
assert all(sha(f)==sha(a/'bundles'/f.name) for f in b.iterdir() if f.is_file())
shutil.copytree(run,a/'native/20261021-004900',dirs_exist_ok=True)
shutil.copy2(run/'full-report.md',a/'full-report.md');shutil.copy2(run/'scope.tsv',a/'scope.tsv')
# All properties are reported as reviewed, not verified clean.
props=json.loads((a/'raw/agent-5.coverage.json').read_text())['properties_reviewed']
coverage={'overall_status':'INCOMPLETE','successful_specialists':[1,4,5,7,10],'failed_specialists':[2,3,6,8,9,11,12],'files':[{'path':r['path'],'sha256':r['sha256'],'reviewed_by_returned_specialists':[1,4,5,7,10],'overall_coverage':'INCOMPLETE: seven required specialty reports absent'} for r in d['resources'] if r['category']=='production'],'properties':props,'property_evidence':'raw/agent-5.coverage.json; additional per-specialty detail in all five returned coverage artifacts','wording_note':'Agent property results such as holds are source/model observations under stated assumptions, not a whole-protocol security guarantee.'}
(a/'coverage-matrix.json').write_text(json.dumps(coverage,indent=2)+'\n')
d['stages'] += [
 {'id':'T5.2-native-assembler','status':'COMPLETE','execution':'unmodified pinned bash assembler','model':'not applicable','provider_returned_model':'unknown','evidence':'logs/assembler-execution.json','exit_code':0,'native_output_sha256':sha(a/'full-report.md')},
 {'id':'T5.3-native-count-and-print','status':'COMPLETE','execution':'native awk counter and verbatim full-report.md print','evidence':'logs/native-counts.json','findings':0,'leads':1,'count_check':True},
 {'id':'T5.4-file-output-flag','status':'NOT_REQUESTED','note':'Required user artifacts are exported separately; no native --file-output flag was passed.'},
 {'id':'T5.5-preserve-before-cleanup','status':'COMPLETE','evidence':'bundles/; native-assembler-intermediates/; native/; raw/; proofs/','bundle_hash_match':True},
 {'id':'TARGET-integrity','status':'COMPLETE','evidence':'logs/target-final-integrity.json','all_43_files_unchanged':True},
 {'id':'EVM-proof-execution','status':'INCOMPLETE','reason':'No completed EVM proof or compile result was returned. Failed agents 9 and 11 left isolated proof harnesses, preserved without attributing success.'},
 {'id':'EXTERNAL-reconciliation','status':'NOT_PERFORMED','reason':'First-pass isolation; no external or historical conclusions read.'}
]
d['coverage']='coverage-matrix.json';d['resources_loaded_note']='Each successful specialist records exact prompt and bundle hashes plus all bundled source resources; failed specialist loading is not inferred from the supplied prompt.'
d['runtime_transport_limitations']='Collaboration exposes requested spawn settings, task names, progress messages and final/error text, but no provider model/effort/usage fields or downloadable internal subagent tool transcript. All exposed responses and all generated filesystem artifacts are preserved.'
d['completed_native_stages_with_gaps']='Native orchestration, five specialist reports, dedup, four validation gates, lead disposition, run recording, native assembly and preservation completed; seven required specialist stages BLOCKED, so overall native scan is INCOMPLETE.'
d['root_loaded_source_resources'] += [dict(r,loaded_extent='targeted called/inherited paths') for r in d['resources'] if any(r['path'].endswith('/'+v) for v in ['VRFV2PlusWrapperConsumerBase.sol','ReentrancyGuard.sol','SafeERC20.sol','ERC721.sol'])]
d['resource_inventory_extra_target_files']=[r for r in baseline if not any(v['path'].endswith(r['path']) for v in d['resources'])]
d['last_updated_at']=now
p.write_text(json.dumps(d,indent=2)+'\n')
print('All exposed specialist messages preserved; all 43 target file hashes unchanged; bundles archived before cleanup.')
