#!/usr/bin/env python3
"""Seal exact completed native output bytes; never adjudicate their findings."""
import argparse, datetime, hashlib, json
from pathlib import Path
P=Path(__file__).resolve().parent
sha=lambda f:hashlib.sha256(Path(f).read_bytes()).hexdigest()
read=lambda f:json.loads(Path(f).read_text())
def metadata(f):
 f=Path(f);return {'path':str(f),'bytes':f.stat().st_size,'sha256':sha(f)}
def exclusive_json(path,value):
 with Path(path).open('x') as f:json.dump(value,f,indent=2);f.write('\n')
def main():
 ap=argparse.ArgumentParser();ap.add_argument('cell',choices=['SIMAO','PASHOV']);ap.add_argument('--preserve-error-artifacts',action='store_true',help='Preserve produced artifact bytes while keeping native ERROR unqualified; no completion approval.');a=ap.parse_args();cell=a.cell
 cfile=P/f'native-high-{cell.lower()}-adjudication-stage-config.json';c=read(cfile);work=Path(c['workspace']);run=Path(c['outputDir']);root=run.parent;dest=root/'native-first-pass';dest.mkdir(exist_ok=True)
 row=next(x for x in read(P/'native-judgment-terminal-metadata.json')['judges'] if x['cell']==cell)
 assert row['terminal']
 terminal=read(run/'native-terminal-result.json')
 checks_without_success={k:v for k,v in row['checks'].items() if k!='nativeTerminalSuccess'}
 if a.preserve_error_artifacts:
  assert cell=='PASHOV' and row['nativeTerminalStatus']=='ERROR' and terminal.get('error')=='The stream was interrupted. Please continue the task you were working on.'
  assert all(checks_without_success.values()), 'all route/protected/process checks must pass'
 else:assert row['allTransportAndProtectedChecksPass'] and all(row['checks'].values()), 'native route/protected checks must all pass'
 assert sha(row['nativeRawTrace'])==row['nativeRawTraceSha256'] and sha(row['strictReceipt'])==row['strictReceiptSha256'], 'terminal metadata changed'
 binding=read(c['requiredBinding']);assert sha(c['requiredBinding'])==row['bindingSha256'];assert len(binding['receipts'])==12 and len({r['conversationId'] for r in binding['receipts']})==12
 protected=read(c['protectedInputManifest']);assert all(sha(work/n)==h for n,h in protected.items())
 leaf_manifest_path=root.parent/'explicit-high-leaves/input-manifest.json';leaf_manifest=read(leaf_manifest_path)
 assert sha(leaf_manifest_path)==binding['inputManifestSha256']
 common_input_status={}
 for n,h in binding['commonInputHashesAtBinding'].items():
  origin=Path(leaf_manifest['leaves'][0]['workspace'])/'.native-leaf-inputs'/Path(n).name
  assert sha(origin)==h
  current=work/n
  if current.exists():assert sha(current)==h
  else:assert cell in ['SIMAO','PASHOV'], 'exact native Turn6/Turn5 allows transient common-input auto-clean'
  common_input_status[n]={'sha256AtBinding':h,'retainedOriginal':metadata(origin),'judgeWorkspaceState':'unchanged' if current.exists() else 'removed-after-native-stage; exact native final turn permits auto-clean'}
 runtime=work.parents[4];frozen=runtime/'clean-context';assert frozen.is_dir(), str(frozen)
 frozen_hashes={str(f.relative_to(frozen)):sha(f) for f in sorted(frozen.rglob('*')) if f.is_file()};assert len(frozen_hashes)==43
 assert all(protected.get(n)==h and sha(work/n)==h for n,h in frozen_hashes.items())
 leaf_bindings=[]
 for r in binding['receipts']:
  assert sha(r['sourceReport'])==r['reportSha256'];assert sha(r['receipt'])==r['receiptSha256']
  assert sha(work/f".native-leaf-results/leaf-{r['number']:02d}.md")==r['reportSha256']
  leaf_bindings.append({k:r[k] for k in ['number','perspective','conversationId','sourceReport','reportSha256','reportBytes','nativeTerminalStatus','strictReceiptStatusPreserved','historicalErrorPreserved','receipt','receiptSha256','coordinatorSemanticValidation']})
 if cell=='SIMAO':sources={'FIRST-PASS.md':work/'raffle-fun-simao-explicit-high-a04.md','gate-ledger.md':work/'adjudication/gate-ledger.md'}
 else:
  calls=row['nativeAssemblerCommandMetadata'];assert calls and any(x['exactPinnedAssemblerReferenced'] and '0' in x['reportedExitCodes'] for x in calls), 'actual unchanged native assembler exit0 required'
  base=work/'.solidity-auditor/runs/2026-10-21-explicit-high-a04'
  assert (base/'full-report.md').read_bytes()==terminal['response'].encode(), 'native final response must equal actual assembler artifact'
  events=[json.loads(l) for l in (run/'stdout.ndjson').read_text().splitlines() if l.strip()];steps=[e['step_update'] for e in events if e.get('step_update')];responses=[x for x in steps if x.get('step_type')=='agent_response'];idx=max(x['step_index'] for x in responses);chunks=[x for x in responses if x['step_index']==idx]
  assert any(x['state']=='DONE' for x in chunks) and ''.join(x.get('text_delta','') for x in chunks)==terminal['response'], 'actual current final DONE response required'
  sources={'FIRST-PASS.md':base/'full-report.md','run-1.md':base/'run-1.md','gate-ledger.md':work/'adjudication/gate-ledger.md'}
 artifacts=[]
 for name,source in sources.items():
  assert source.is_file() and source.stat().st_size>0
  target=dest/name
  if target.exists():assert target.read_bytes()==source.read_bytes(), 'refuse existing different artifact'
  else:
   with target.open('xb') as f:f.write(source.read_bytes())
  artifacts.append({'nativeOriginal':metadata(source),'sealedCopy':metadata(target)})
 now=datetime.datetime.now(datetime.timezone.utc).isoformat();receipt_path=dest/('native-artifact-preservation-receipt.json' if a.preserve_error_artifacts else 'native-completion-receipt.json');seal_path=dest/'artifact-integrity-seal.json'
 receipt={'recordedUtc':now,'cell':cell,'kind':'scoped-native-run-and-artifact-completion-with-unreviewed-final-semantic-completeness','nativeRunCompleted':True,'nativeMethod':c['method'],'nativeTerminalStatus':row['nativeTerminalStatus'],'nativeConversationId':row['conversationId'],'model':'gemini-4-argon-high','effort':'high','scope':'Existing independent Simao/Pashov lane only; no global matrix or rejected-controller task is finalized.','sourceFindingsReadOrJudgedByHost':False,'independentFinalSemanticCompletenessChecked':False,'findingsTruthSeverityProofOrSourceAnchorsApprovedByHost':False,'finalAuditSemanticAcceptanceIssued':False,'remainingLimitation':'Exact native report and gate-ledger bytes are sealed after successful native judgment transport, full pinned resource reads and protected-input checks. The coordinator became unavailable before independent final semantic-completeness review. No claim that every final gate, proof, severity or source anchor is correct is made. Leaf method/output completion approvals predate that unavailability; historical leaf ERROR statuses are preserved.','transportChecks':row['checks'],'nativeUsageSnapshot':row['nativeUsage'],'rawNativeTrace':metadata(row['nativeRawTrace']),'strictNativeReceipt':metadata(row['strictReceipt']),'targetSourceBinding':{'frozenRoot':str(frozen),'files':frozen_hashes,'fileCount':43,'solidityFiles':sum(n.endswith('.sol') for n in frozen_hashes),'allFrozenBytesUnchanged':True,'protectedInputManifest':metadata(c['protectedInputManifest']),'allProtectedBytesUnchanged':True},'nativeResourcesAndPrompt':{'stageConfiguration':metadata(cfile),'prompt':metadata(c['promptFile']),'resourceReadEvidence':metadata(P/'native-adjudication-resource-execution-metadata.json'),'binding':metadata(c['requiredBinding']),'preLensCommonInputHashes':binding['commonInputHashesAtBinding'],'preLensCommonInputPostStageStatus':common_input_status,'leafInputManifest':metadata(leaf_manifest_path)},'leafBindings':leaf_bindings,'artifacts':artifacts,'assemblerEvidence':row['nativeAssemblerCommandMetadata'],'artifactIntegritySeal':str(seal_path)}
 if a.preserve_error_artifacts:
  receipt.update({'kind':'native-ERROR-output-artifact-preservation-NOT-method-completion-qualification','nativeRunSucceeded':False,'nativeRunCompleted':False,'nativeRunTerminal':True,'nativeArtifactsProduced':True,'nativeError':terminal['error'],'strictNativeErrorPreserved':True,'actualPinnedAssemblerExitZeroVerified':True,'finalDoneResponseEqualsAssemblerArtifact':True})
  receipt['remainingLimitation']='Native terminal status remains ERROR (stream interruption), and the original strict failed receipt is unmodified. The same original run nevertheless produced a new final DONE response exactly equal to full-report.md after actual unchanged assembler exit zero. This is artifact-byte preservation only; neither transport success nor final semantic/method completeness is qualified. Independent final semantic review was not performed because the coordinator became unavailable. No finding truth, severity, proof, source-anchor or global completion approval is issued.'
 exclusive_json(receipt_path,receipt)
 seal={'recordedUtc':now,'kind':'artifact-byte-integrity-seal-NOT-final-semantic-acceptance','cell':cell,'receipt':metadata(receipt_path),'sealedArtifacts':[a['sealedCopy'] for a in artifacts],'nativeOriginals':[a['nativeOriginal'] for a in artifacts],'protectedInputManifest':metadata(c['protectedInputManifest']),'nativeLeafBinding':metadata(c['requiredBinding']),'nativeRawTrace':metadata(row['nativeRawTrace']),'strictNativeReceipt':metadata(row['strictReceipt']),'independentFinalSemanticCompletenessChecked':False,'globalAuditCompletionIssued':False}
 exclusive_json(seal_path,seal)
 print(json.dumps({'cell':cell,'firstPass':str(dest/'FIRST-PASS.md'),'receipt':str(receipt_path),'seal':str(seal_path),'semanticAcceptance':False},indent=2))
if __name__=='__main__':main()
