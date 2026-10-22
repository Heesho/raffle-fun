"""Temporary-fixture checks only; never publishes actual final artifacts or stops a process."""
from pathlib import Path
import ast,copy,datetime,hashlib,json,subprocess,tempfile,types
from publication_integrity import publish_stage,verify_seal,PAYLOADS,OUTPUTS,require,atomic_create
from finalization_gates import verify_required_lanes,verify_gate_receipt_binding
from reconciliation_integrity_policy import qualify
D=Path(__file__).resolve().parent;A=D.parent.parent;sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();checks=[]
def rejected(name,fn):
 try:fn()
 except (ValueError,RuntimeError,KeyError,FileNotFoundError,PermissionError):checks.append(name);return
 raise RuntimeError('Did not reject: '+name)
with tempfile.TemporaryDirectory(prefix='raffle-finalizer-check-') as raw:
 t=Path(raw).resolve();stage=t/'stage';dest=t/'destination';stage.mkdir();dest.mkdir();inp=t/'input';inp.write_text('input\n')
 for name in PAYLOADS:(stage/name).write_text(name+'\n')
 seal=stage/'FINAL-RECONCILIATION-SEAL.json';seal.write_text(json.dumps({'artifacts':{n:sha(stage/n) for n in PAYLOADS},'finalization_input_hashes':{str(inp):sha(inp)}}))
 manifest={'destination':str(dest),'input_hashes':{str(inp):sha(inp)},'outputs':{n:sha(stage/n) for n in OUTPUTS}}
 mp=stage/'PUBLICATION.json';mp.write_text(json.dumps(manifest));publish_stage(stage,dest);verify_seal(dest/seal.name);checks.append('exact five outputs and four sealed payloads publish')
 publish_stage(stage,dest);checks.append('exact partial/full publication resume is idempotent')
 bad=copy.deepcopy(manifest);bad['outputs'].pop('FINAL-RECEIPT-INTEGRITY.json');mp.write_text(json.dumps(bad));rejected('missing fifth output rejected',lambda:publish_stage(stage,dest));mp.write_text(json.dumps(manifest))
 other=t/'unrelated-input';other.write_text('other');bad=copy.deepcopy(manifest);bad['input_hashes']={str(other):sha(other)};mp.write_text(json.dumps(bad));rejected('wrong resume input set rejected',lambda:publish_stage(stage,dest));mp.write_text(json.dumps(manifest))
 ap=t/'atomic-stage';atomic_create(ap,b'complete');atomic_create(ap,b'complete');rejected('exclusive staged differing bytes rejected',lambda:atomic_create(ap,b'different'));checks.append('atomic complete staged bytes and idempotent recovery')
 inp.write_text('changed');rejected('changed input rejected',lambda:publish_stage(stage,dest));inp.write_text('input\n')
 rp=t/'receipt.json';rp.write_text('{}');sp=t/'typed-seal.json';sp.write_text(json.dumps({'completionReceipt':{'path':str(rp),'sha256':sha(rp)}}));verify_gate_receipt_binding(sp,rp,sha(rp),t);checks.append('typed exact receipt binding accepted')
 sp.write_text(json.dumps({'unrelated_prose':sha(rp)}));rejected('digest in prose rejected',lambda:verify_gate_receipt_binding(sp,rp,sha(rp),t))
 sp.write_text(json.dumps({'completionReceipt':{'path':str(t/'different.json'),'sha256':sha(rp)}}));rejected('digest bound to wrong path rejected',lambda:verify_gate_receipt_binding(sp,rp,sha(rp),t))
state=json.loads((D/'state.json').read_text());baseline=json.loads((D/'REQUIRED-FINALIZATION-GATES.json').read_text())
rejected('actual pending source gate rejects',lambda:verify_required_lanes(state,baseline))
fixture=copy.deepcopy(state);fixture['expected_lanes']=[];verify_required_lanes(fixture,baseline);checks.append('fixture complete required sets accepted without changing actual state')
missing=copy.deepcopy(fixture);missing.pop('required_method_gate_lanes');rejected('missing required baseline list rejected',lambda:verify_required_lanes(missing,baseline))
missing=copy.deepcopy(fixture);missing.pop('semantic_qualification_pending');rejected('missing pending list rejected',lambda:verify_required_lanes(missing,baseline))
for q in state['method_semantic_qualifications']+state['post_source_workflow_qualifications']+state['received_late_source_receipt_dispositions']:
 verify_gate_receipt_binding(q['seal_path'],q['receipt_path'],q['receipt_sha256'],A)
checks.append('all five currently qualified real receipts have typed path+hash bindings')
r=json.loads((D/'RECEIPT-INTEGRITY-HELPER-RESULT-07.json').read_text());limits=json.loads((D/'KNOWN-HISTORICAL-BINDING-LIMITS.json').read_text());qualify(r,limits,27,739);checks.append('exact four historical mismatch policy accepted with false integrity flag retained')
bad=copy.deepcopy(r);bad['errors'].append({'code':'unknown','path':'x','detail':'x'});rejected('additional integrity error rejected',lambda:qualify(bad,limits,27,739))
bad=copy.deepcopy(r);bad['gaps'].append({'code':'unknown'});rejected('additional metadata gap rejected',lambda:qualify(bad,limits,27,739))
rr=subprocess.run(['python3','-O',str(D/'finalize_register.py')],capture_output=True,text=True)
require(rr.returncode!=0 and 'refuses optimized Python' in rr.stderr,'Optimized finalizer did not refuse');checks.append('optimized Python finalizer fails before publication')
# Extract only the process-query function; mock all process operations.
tree=ast.parse((D/'stop_receipt_watch.py').read_text());fn=next(x for x in tree.body if isinstance(x,ast.FunctionDef) and x.name=='process');code=compile(ast.Module(body=[fn],type_ignores=[]),'<process-fixture>','exec')
def query(returncode,out='',err='',kill_error=None):
 def kill(pid,signal):
  if kill_error:raise kill_error
 ns={'pid':123,'require':require,'subprocess':types.SimpleNamespace(run=lambda *a,**k:types.SimpleNamespace(returncode=returncode,stdout=out,stderr=err)),'os':types.SimpleNamespace(kill=kill)};exec(code,ns);return ns['process']()
require(query(1,kill_error=ProcessLookupError())=='','Absent process rejected');checks.append('ps absent plus kill0 ESRCH accepted')
rejected('ps query failure rejected',lambda:query(2))
rejected('ps stderr rejected',lambda:query(1,err='failure'))
rejected('ps absent but PID alive rejected',lambda:query(1))
rejected('kill0 permission failure rejected',lambda:query(1,kill_error=PermissionError()))
for name in ['finalize_register.py','publication_integrity.py','receipt_integrity.py','reconciliation_integrity_policy.py','finalization_gates.py','stop_receipt_watch.py']:
 compile((D/name).read_text(),str(D/name),'exec')
checks.append('all six helper sources compile')
p=D/'FINALIZATION-HELPER-HARDENING-CHECK-02.json';require(not p.exists(),'Check receipt already exists')
p.write_text(json.dumps({'checked_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'checks_passed':checks,'actual_final_publication_or_process_stop':False,'script_sha256':sha(Path(__file__)),'helper_sha256':{n:sha(D/n) for n in ['finalize_register.py','publication_integrity.py','receipt_integrity.py','reconciliation_integrity_policy.py','finalization_gates.py','stop_receipt_watch.py']}},indent=2)+'\n');print(json.dumps({'checks':len(checks),'receipt':str(p),'sha256':sha(p)}))
