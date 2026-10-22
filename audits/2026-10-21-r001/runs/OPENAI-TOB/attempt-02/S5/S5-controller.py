import concurrent.futures,copy,datetime,hashlib,json,os,pathlib,shutil,subprocess,time,traceback

BASE=pathlib.Path('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001')
CWD=BASE/'cells/OPENAI-TOB-continuation'
WORK=CWD/'audit/S5'
OUT=pathlib.Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/OPENAI-TOB/attempt-02/S5')
NATIVE=WORK/'native'
UP=BASE/'upstreams/trailofbits/plugins/spec-to-code-compliance'
CLI='/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex'
NODE='/Users/hishamel-husseini/.nvm/versions/node/v20.19.6/bin/node'
ARGS=json.loads((OUT/'inherited-args.json').read_text())

def now():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def write(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,indent=2)+'\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def journal(v):
    with (OUT/'controller-journal.jsonl').open('a') as f:f.write(json.dumps({'timestamp':now(),**v})+'\n')
def publish():
    shutil.copytree(NATIVE,OUT/'native',dirs_exist_ok=True)
    if (WORK/'spec-compliance').exists():shutil.copytree(WORK/'spec-compliance',OUT/'spec-compliance',dirs_exist_ok=True)
def strict_schema(s):
    s=copy.deepcopy(s)
    if s.get('type')=='object':
        req=set(s.get('required',[]));props={}
        for k,v in s.get('properties',{}).items():
            t=strict_schema(v)
            if k not in req:
                t={'anyOf':[t,{'type':'null'}]}
            props[k]=t
        s['properties']=props;s['required']=list(props);s['additionalProperties']=False
    if s.get('type')=='array':s['items']=strict_schema(s['items'])
    return s
def normalize(v):
    if isinstance(v,dict):return {k:normalize(x) for k,x in v.items() if x is not None}
    if isinstance(v,list):return [normalize(x) for x in v]
    return v
def validate(v,s,p='$'):
    t=s.get('type')
    if t=='object':
        assert isinstance(v,dict),p+' expected object'
        for k in s.get('required',[]):assert k in v,p+'.'+k+' required'
        for k,x in s.get('properties',{}).items():
            if k in v:validate(v[k],x,p+'.'+k)
    if t=='array':
        assert isinstance(v,list),p+' expected array'
        for i,x in enumerate(v):validate(x,s['items'],p+f'[{i}]')
    if t=='string':assert isinstance(v,str),p+' expected string'
    if t=='boolean':assert isinstance(v,bool),p+' expected boolean'
    if 'enum' in s:assert v in s['enum'],p+' enum mismatch'

RESOURCES=json.loads((OUT/'resources-manifest.json').read_text())
RESOURCE_TEXT='\n\n'.join('PINNED RESOURCE '+r['path']+' SHA256 '+r['sha256']+'\n'+pathlib.Path(r['retained']).read_text() for r in RESOURCES if not r['path'].endswith('.js'))

def run_request(request_path):
    req=json.loads(request_path.read_text());rid=req['id'];d=OUT/'requests'/rid;d.mkdir(parents=True,exist_ok=True)
    shutil.copy2(request_path,d/'native-request.json')
    schema=strict_schema(req['options']['schema']);write(d/'native-schema.json',req['options']['schema']);write(d/'cli-schema.json',schema)
    stage=req['options'].get('phase');analysis_access=''
    if stage=='Verify':analysis_access='You may read the exact Full analysis file named by this request, plus target source/spec and the pinned resources. Do not read other alignments or refutations.'
    elif stage=='Report':analysis_access='You may read this S5 native per-requirement analyses under '+str(WORK/'spec-compliance/requirements')+' as the native report requests.'
    else:analysis_access='Do not read previous analysis results or any sibling worker output. This stage gets only its native request and target source/spec.'
    prompt=f'''You are executing one native S5 spec-to-code-compliance workflow request in a fresh independent context. The native workflow and pinned resources below define the task. Do the native task, write requested analysis/report files, and return only the schema-bound JSON record.

Execution root (all original relative paths resolve here): {CWD}
Frozen source target: {CWD/'target'}; requested commit 9238b6ce8eb7f768c0dcd0cfcef26e1427a03155. Target is read-only. Only these target source/spec files are evidence. Local source reads/searches are allowed. Do not run tests, compilers, analyzers, scanners, fuzzers, chain calls, or tools that generate behavior results. No web/network research. No historical tests, findings, accepted risks, other audit cells, corpora, or reconciliation.
Writable output area for native analyses/report only: {WORK/'spec-compliance'}. Native paths such as audit/S5/spec-compliance/requirements/*.md must resolve under this absolute directory. Use shell or apply_patch as the local Write adapter. Do not modify target, controllers, requests, responses, journals, or other outputs.
{analysis_access}
The exact native request follows unchanged; do not reinterpret it as a new discovery task. Agent type spec-to-code-compliance:spec-compliance-checker resolves to the pinned checker resource included below, not to a model fallback. If this request uses that type, follow those checker instructions.
Model routing is fixed by the controller to gpt-6-astra with reasoning_effort=ultra. Do not invoke other models, agents, or external orchestration. No model fallback and no cyber access override. If you genuinely refuse for cybersecurity reasons, state that refusal plainly; do not seek alternate routing. Runtime errors can be repaired, but cannot justify importing forbidden evidence.
The CLI output schema is the exact native schema adapted only for strict structured outputs: optional properties may be null. The controller removes null optional properties and validates against the unchanged native schema. Include actual evidence, searches, and file paths as requested. A refusal must not be disguised as a schema-compliant substantive result.

BEGIN EXACT NATIVE REQUEST PROMPT
{req['prompt']}
END EXACT NATIVE REQUEST PROMPT

BEGIN PINNED RESOURCES
{RESOURCE_TEXT}
END PINNED RESOURCES
'''
    (d/'prompt.txt').write_text(prompt)
    command=[CLI,'exec','--ignore-user-config','--ephemeral','--skip-git-repo-check','-s','danger-full-access','-m','gpt-6-astra','-c','model_reasoning_effort="ultra"','-c','features.multi_agent=false','--json','-C',str(CWD),'--output-schema',str(d/'cli-schema.json'),'-o',str(d/'final-output.json'),'-']
    write(d/'command.json',{'argv':command,'cwd':str(CWD),'stdin':str(d/'prompt.txt'),'model_requested':'gpt-6-astra','effort_requested':'ultra','provider_returned_model':'unknown','provider_returned_effort':'unknown','cyber_access_program_override':None,'fallback_enabled':False,'started_at':now()})
    journal({'type':'cli-start','id':rid,'label':req['options'].get('label'),'phase':stage})
    with (d/'events.jsonl').open('w') as out,(d/'stderr.txt').open('w') as err:
        proc=subprocess.run(command,input=prompt,text=True,cwd=CWD,stdout=out,stderr=err)
    write(d/'completion.json',{'exit_code':proc.returncode,'ended_at':now()})
    if proc.returncode:raise RuntimeError(f'CLI request {rid} exited {proc.returncode}; retained stderr/events require classification; no automatic retry.')
    data=json.loads((d/'final-output.json').read_text());normalized=normalize(data);validate(normalized,req['options']['schema'])
    # Check claimed on-disk deliverables before releasing native dependency barriers.
    for field in ['analysisFile','reportFile']:
        if field in normalized:
            p=pathlib.Path(normalized[field]);p=p if p.is_absolute() else CWD/p
            assert p.is_file(),f'{rid} claimed missing {field}: {p}'
            assert p.resolve().is_relative_to((WORK/'spec-compliance').resolve()),f'{rid} output outside authorized native directory'
    write(d/'normalized-native-response.json',normalized)
    temp=NATIVE/(rid+'-response.json.tmp');write(temp,normalized);temp.replace(NATIVE/(rid+'-response.json'))
    journal({'type':'cli-complete','id':rid,'native_schema_valid':True,'native_response_sha256':sha(NATIVE/(rid+'-response.json')),'provider_returned_model':'unknown','provider_returned_effort':'unknown'})
    return rid

def main():
    command=[NODE,str(CWD/'audit/S5-workflow-host.cjs'),str(UP/'workflows/spec-compliance.js'),'S5',json.dumps(ARGS,separators=(',',':'))]
    write(OUT/'host-command.json',{'argv':command,'cwd':str(CWD),'started_at':now()})
    for script in ['S5-workflow-host.cjs','S5-controller.py']:shutil.copy2(CWD/'audit'/script,OUT/script)
    with (OUT/'host.stdout').open('w') as hout,(OUT/'host.stderr').open('w') as herr:
        host=subprocess.Popen(command,cwd=CWD,stdout=hout,stderr=herr)
        futures={};seen=set();pool=concurrent.futures.ThreadPoolExecutor(max_workers=4)
        try:
            while True:
                for p in sorted(NATIVE.glob('*-request.json')):
                    rid=p.name.split('-')[0]
                    if rid not in seen and not (NATIVE/(rid+'-response.json')).exists():
                        seen.add(rid);futures[pool.submit(run_request,p)]=rid
                for f in list(futures):
                    if f.done():
                        rid=futures.pop(f)
                        try:f.result()
                        except Exception as e:
                            detail={'type':'request-error','id':rid,'error':str(e),'traceback':traceback.format_exc(),'no_automatic_retry':True,'timestamp':now()}
                            write(WORK/'STOP.json',detail);write(OUT/'STOP.json',detail);journal(detail)
                publish()
                if host.poll() is not None:
                    if futures:
                        for f in concurrent.futures.as_completed(futures):
                            try:f.result()
                            except Exception:pass
                    break
                time.sleep(1)
        finally:
            pool.shutdown(wait=True);publish()
    write(OUT/'host-completion.json',{'exit_code':host.returncode,'ended_at':now()})
    journal({'type':'controller-complete','host_exit_code':host.returncode})

if __name__=='__main__':main()
