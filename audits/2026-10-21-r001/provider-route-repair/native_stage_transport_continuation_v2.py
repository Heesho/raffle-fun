#!/usr/bin/env python3
"""Same-conversation stage transport repair. Official CLI only; no new assessment identity."""
import argparse,json,subprocess,sys
from pathlib import Path
import native_leaf_transport_continuation as base
HERE=Path(__file__).resolve().parent
PROMPT='''Continue the exact full native stage task already assigned in this conversation, from its preserved progress, through all required native steps and deliverables to a COMPLETE final response. The preceding turn ended due to a transport interruption or timeout. This is the SAME stage and conversation, not a fresh audit or another reviewer. Read your existing original task and pinned skill/resources if needed; preserve all its requirements. Finish any remaining actual tools/checks and preserve real failures and unresolved gaps rather than claiming unperformed checks passed. Use only this stage workspace, its existing progress and pinned inputs; never read older stages, sibling reports, other attempts, provider lanes, personal memory or outside findings. Do not define/invoke/spawn subagents, change model or call another model through shell/network/plugins/workflows. Keep all original protected source/build/resource inputs unchanged; generated work belongs only in authorized scratch/output directories. Return the complete native final response and deliverable paths, not a progress update.'''

def qualify(config_file):
 c=base.read(config_file);out=Path(c['outputDir']);work=Path(c['workspace']);receipt=base.read(out/'transport-result.json')
 init,t,delegated,_=base.native_events(out/'stdout.ndjson');cid=receipt.get('conversationId')
 if not cid or cid!=init.get('conversation_id') or cid!=t.get('conversation_id'):raise ValueError('Original identity inconsistent')
 if init['init'].get('model')!=base.MODEL or init['init'].get('permission_mode')!='always-proceed':raise ValueError('Original route mismatch')
 error=t.get('error','');eligible=error=='The stream was interrupted. Please continue the task you were working on.' or (error.startswith('API error') and ('operation timed out' in error or 'context deadline exceeded' in error or 'read: connection reset by peer' in error))
 if receipt.get('status')!='failed' or t.get('status')!='ERROR' or not eligible:raise ValueError('Original is not an eligible interrupted stage transport')
 if delegated or receipt.get('delegatedStepIndices') or not receipt.get('protectedInputsUnchanged'):raise ValueError('Original mutated or delegated')
 protected=base.read(c['protectedInputManifest']);base.check_files(work,protected)
 if base.read(out/'protected-inputs-after.json')!=protected:raise ValueError('Original after manifest mismatch')
 launch=base.read(out/'launch.json');argv=launch['argv']
 if argv[argv.index('--model')+1]!=base.MODEL or argv[argv.index('--effort')+1]!='high' or '--conversation' in argv:raise ValueError('Original argv mismatch')
 if base.sha(Path(c['protectedInputManifest']).read_bytes())!=launch['protectedInputManifestSha256'] or base.sha(Path(c['promptFile']).read_bytes())!=launch['promptSha256']:raise ValueError('Original preparation changed')
 files=[Path(config_file),Path(c['protectedInputManifest']),Path(c['promptFile']),out/'launch.json',out/'transport-result.json',out/'stdout.ndjson',out/'native-terminal-result.json',out/'protected-inputs-after.json']
 return c,cid,protected,base.fingerprint(files)

def prepare(config_file):
 original,cid,protected,hashes=qualify(config_file);out=Path(original['outputDir'])/'continuation-01';out.mkdir(exist_ok=False);(out/'prompt.txt').write_text(PROMPT)
 c={'kind':'same-identity-native-stage-transport-continuation','createdUtc':base.utc(),'originalStageConfig':str(config_file),'originalConversationId':cid,'originalEvidenceHashes':hashes,'workspace':original['workspace'],'protectedInputs':protected,'outputDir':str(out),'promptFile':str(out/'prompt.txt'),'promptSha256':base.sha(PROMPT.encode()),'cli':original['cli'],'adapterSha256':base.sha(Path(__file__).read_bytes()),'sharedHelperSha256':base.sha(Path(base.__file__).read_bytes()),'automaticRetry':False,'newStageOrReviewer':False,'outerTimeout':None}
 base.write(out/'config.json',c)
 return {'status':'prepared-no-model-launched','config':str(out/'config.json'),'conversationId':cid,'launchArgv':['python3',str(Path(__file__).resolve()),'run',str(out/'config.json')]}

def run(config_file):
 c=base.read(config_file);qualify(Path(c['originalStageConfig']));out=Path(c['outputDir']);work=Path(c['workspace'])
 if base.fingerprint(c['originalEvidenceHashes'])!=c['originalEvidenceHashes']:raise ValueError('Original evidence changed')
 if base.sha(Path(__file__).read_bytes())!=c['adapterSha256'] or base.sha(Path(base.__file__).read_bytes())!=c['sharedHelperSha256']:raise ValueError('Prepared adapter changed')
 base.check_files(work,c['protectedInputs']);prompt=Path(c['promptFile']).read_text()
 if base.sha(prompt.encode())!=c['promptSha256']:raise ValueError('Continuation prompt changed')
 argv=[c['cli'],'--conversation',c['originalConversationId'],'-p',prompt,'--model',base.MODEL,'--effort','high','--dangerously-skip-permissions','--output-format','stream-json','--print-timeout','0','--log-file',str(out/'native.log')]
 with (out/'invocation.json').open('x') as f:json.dump({'startedUtc':base.utc(),'argv':argv,'cwd':str(work),'configSha256':base.sha(config_file.read_bytes()),'cliSha256':base.sha(Path(c['cli']).read_bytes()),'outerTimeout':None,'automaticRetry':False},f,indent=2)
 r={'status':'failed','originalConversationId':c['originalConversationId'],'continuation':True,'newStageOrReviewer':False}
 try:
  with (out/'stdout.ndjson').open('x') as stdout,(out/'stderr.log').open('x') as stderr:p=subprocess.run(argv,cwd=work,stdin=subprocess.DEVNULL,stdout=stdout,stderr=stderr)
  r['exitCode']=p.returncode;init,t,delegated,tools=base.native_events(out/'stdout.ndjson');base.write(out/'native-terminal-result.json',t);(out/'report.native-response.md').write_text(t.get('response',''))
  r.update(conversationId=t.get('conversation_id'),nativeInit=init['init'],nativeStatus=t.get('status'),usage=t.get('usage'),tools=tools,delegatedStepIndices=delegated)
  if init.get('conversation_id')!=c['originalConversationId'] or t.get('conversation_id')!=c['originalConversationId']:raise ValueError('CLI changed stage conversation identity; does NOT qualify')
  if init['init'].get('model')!=base.MODEL or init['init'].get('permission_mode')!='always-proceed' or delegated:raise ValueError('Selected route/delegation mismatch')
  if p.returncode!=0 or t.get('status')!='SUCCESS' or not t.get('response','').strip():raise ValueError('Continuation transport did not complete')
  r['status']='native-stage-transport-completed'
 except Exception as e:r['error']=str(e)
 finally:
  after={n:base.sha((work/n).read_bytes()) if (work/n).is_file() else None for n in c['protectedInputs']};base.write(out/'protected-inputs-after.json',after);r['protectedInputsUnchanged']=after==c['protectedInputs'];r['originalEvidenceUnchanged']=base.fingerprint(c['originalEvidenceHashes'])==c['originalEvidenceHashes']
  if not r['protectedInputsUnchanged'] or not r['originalEvidenceUnchanged']:r['status']='failed'
  r.update(endedUtc=base.utc(),methodCompletenessIndependentlyVerified=False);base.write(out/'transport-result.json',r)
 return {k:r.get(k) for k in ['status','conversationId','protectedInputsUnchanged','originalEvidenceUnchanged','error']}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('command',choices=['prepare','run']);p.add_argument('config',type=Path);a=p.parse_args();r=prepare(a.config.resolve()) if a.command=='prepare' else run(a.config.resolve());print(json.dumps(r,indent=2));sys.exit(int(r.get('status')=='failed'))
