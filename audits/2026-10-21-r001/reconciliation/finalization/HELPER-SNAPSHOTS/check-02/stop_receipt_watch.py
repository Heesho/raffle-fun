#!/usr/bin/env python3
"""Stop only our receipt watcher after final reconciliation is sealed."""
from pathlib import Path
import datetime,hashlib,json,os,signal,subprocess,time
from publication_integrity import verify_seal,require,atomic_create
from finalization_gates import verify_required_lanes
D=Path(__file__).resolve().parent;O=D.parent;pid=68662
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
receipt=D/'WATCHER-SHUTDOWN.json';seal=D/'WATCHER-SHUTDOWN-SEAL.json';stage=D/'watcher-shutdown-staging'

def verify_final():
 sp=O/'FINAL-RECONCILIATION-SEAL.json';h=sha(sp);data,artifacts=verify_seal(sp)
 require(data.get('pending_eligible_receipts')==0,'Final seal retains pending source receipts')
 state=json.loads((D/'state.json').read_text());baseline=D/'REQUIRED-FINALIZATION-GATES.json'
 require(sha(baseline)=='e2d5ac0ee0ae113a3c0a3f58a2395f80855c64b775429b7727f903f0c008a246','Gate baseline changed')
 verify_required_lanes(state,json.loads(baseline.read_text()))
 require(data['finalization_input_hashes'][str(D/'state.json')]==sha(D/'state.json'),'State changed since finalization')
 require(sha(sp)==h,'Final seal changed during verification')
 return h,artifacts,sha(D/'state.json')

def process():
 r=subprocess.run(['ps','-p',str(pid),'-o','pid=,command='],capture_output=True,text=True)
 require(not r.stderr.strip(),('Process query emitted error',r.returncode,r.stderr));value=r.stdout.strip()
 if r.returncode==0:
  require(value and value.split(None,1)[0]==str(pid),('Invalid process result',value));return value
 require(r.returncode==1 and not value,('Process query failed',r.returncode,value))
 # ps exit1/empty is absent selection; confirm independently without treating
 # permission or process-query errors as proof of absence.
 try:os.kill(pid,0)
 except ProcessLookupError:return ''
 raise RuntimeError('ps reported absence but PID still exists')

initial=verify_final();before=process();cwd=None
if before:
 require('watch_receipts.py' in before,(pid,before))
 cr=subprocess.run(['lsof','-a','-p',str(pid),'-d','cwd','-Fn'],capture_output=True,text=True,check=True)
 cwd=[l[1:] for l in cr.stdout.splitlines() if l.startswith('n')];require(cwd==[str(D)],('Unexpected process cwd',cwd))
 os.kill(pid,signal.SIGTERM)
 for _ in range(100):
  if not process():break
  time.sleep(.1)
 require(not process(),'Receipt watcher did not terminate')
final=verify_final();require(final==initial,'Final artifacts or state changed during watcher shutdown')
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
payload={'stopped_utc':now,'pid':pid,'verified_before':before,'verified_cwd':cwd,'operation':'SIGTERM' if before else 'already absent','verified_absent':True,'process_absence_checks':['ps exit1 with empty stdout/stderr','kill(pid,0) ProcessLookupError'],'owned_native_bridge_exporter_caffeinate_already_stopped':[82643,24365,12024],'native_lifecycle_receipt':'provider-lanes/gemini/runs/GEMINI-OPENKRITT/native-engine-attempt-03/SOURCE-AND-LIFECYCLE-RECEIPT.json','no_other_process_touched':True,'final_reconciliation_seal_sha256':final[0],'state_sha256':final[2],'remaining_own_persistent_audit_root_writers':0,'this_one_shot_receipt_writer_exits_after_publication':True,'verified_final_artifacts':final[1],'final_artifacts_reverified_after_termination':True}
stage.mkdir(exist_ok=True);sr=stage/receipt.name;ss=stage/seal.name
if sr.exists():
 saved=json.loads(sr.read_text())
 for k in ['pid','verified_absent','final_reconciliation_seal_sha256','state_sha256','verified_final_artifacts','final_artifacts_reverified_after_termination']:
  require(saved.get(k)==payload[k],('Existing shutdown stage differs',k))
 payload=saved
else:
 atomic_create(sr,(json.dumps(payload,indent=2)+'\n').encode())
seal_value={'sealed_utc':payload['stopped_utc'],'artifacts':{receipt.name:sha(sr),'stop_receipt_watch.py':sha(Path(__file__))}};seal_bytes=(json.dumps(seal_value,indent=2)+'\n').encode()
if ss.exists():require(ss.read_bytes()==seal_bytes,'Existing shutdown seal stage differs')
else:
 atomic_create(ss,seal_bytes)
require(verify_final()==final and not process(),'Final state/process changed before shutdown publication')
for src,dst in [(sr,receipt),(ss,seal)]:
 if dst.exists():require(dst.read_bytes()==src.read_bytes(),('Existing shutdown output differs',str(dst)))
for src,dst in [(sr,receipt),(ss,seal)]:
 try:os.link(src,dst)
 except FileExistsError:require(dst.read_bytes()==src.read_bytes(),('Concurrent shutdown output differs',str(dst)))
require(sha(receipt)==seal_value['artifacts'][receipt.name] and seal.read_bytes()==seal_bytes,'Shutdown output verification failed')
print(json.dumps(payload,indent=2))
