#!/usr/bin/env python3
"""Separate test-efficacy experiment; modifies disposable variant copies only."""
from pathlib import Path
import concurrent.futures, datetime, difflib, hashlib, json, os, shutil, subprocess, time

ROOT = Path(__file__).resolve().parent
BASE = ROOT / 'base'
ART = Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/TOOL-MUTATION-QUALITY')
ART.mkdir(parents=True, exist_ok=True)
shutil.copy2(__file__, ART / 'run_mutations.py')
VALIDATION = ROOT.parent / 'validation/packages/contracts'
CLEAN = ROOT.parent / 'clean-context/packages/contracts'
def hash_sources(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((root/'src').rglob('*.sol')) if 'mocks' not in p.parts}
before = {'validation':hash_sources(VALIDATION),'clean':hash_sources(CLEAN)}
(ART/'frozen-input-hashes-before.json').write_text(json.dumps(before,indent=2)+'\n')

MUTATIONS = [
 ('M1-fee-400', 'src/libraries/RaffleConstants.sol', 'PROTOCOL_FEE_BPS = 500;', 'PROTOCOL_FEE_BPS = 400;', 'Conservative but wrong 4% protocol allocation'),
 ('M2-owner-check-removed', 'src/Raffle.sol', 'if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);', '// MUTANT: winner caller authorization removed', 'Allow nonowner to trigger winning-ticket burn and payout'),
 ('M3-request-deadline-inclusive', 'src/Raffle.sol', 'if (block.timestamp >= requestDeadline) {', 'if (block.timestamp > requestDeadline) {', 'Allow draw initiation exactly at the exclusive deadline'),
 ('M4-purchase-always-reverts', 'src/Raffle.sol', 'uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;', 'revert ZeroEntryCount();\n        uint256 grossAmount = uint256(entryCount) * ENTRY_PRICE;', 'Disable all valid purchases to probe handler vacuity'),
]
ENV=os.environ.copy()
ENV.update({'FOUNDRY_INVARIANT_RUNS':'64','FOUNDRY_INVARIANT_DEPTH':'64','FOUNDRY_FUZZ_RUNS':'128'})
def execute(name, directory, kind):
    cmd=['forge','test','--root',str(directory),'--no-match-path','**/fork/**','--fuzz-runs','128']
    cmd += ['--match-contract','RaffleInvariantTest'] if kind=='invariant' else ['--no-match-contract','RaffleInvariantTest']
    started=datetime.datetime.now(datetime.timezone.utc).isoformat()
    t=time.monotonic()
    log=ART/f'{name}-{kind}.log'
    with log.open('w') as out:
        out.write('COMMAND: '+json.dumps(cmd)+'\nENV: FOUNDRY_INVARIANT_RUNS=64 FOUNDRY_INVARIANT_DEPTH=64 FOUNDRY_FUZZ_RUNS=128\n')
        out.flush()
        try:
            proc=subprocess.run(cmd,cwd=directory,env=ENV,stdout=out,stderr=subprocess.STDOUT,timeout=150)
            rc=proc.returncode
            status='passed' if rc==0 else 'failed'
        except subprocess.TimeoutExpired:
            rc=None
            status='timeout'
    content=log.read_text()
    if status=='failed' and ('Compiler run failed' in content or 'Error (' in content): status='invalid-mutant-or-build-error'
    result={'variant':name,'suite':kind,'command':cmd,'started_at_utc':started,'duration_seconds':round(time.monotonic()-t,3),'exit_code':rc,'status':status,'log':str(log)}
    print(json.dumps(result),flush=True)
    return result

results=[]
for kind in ['invariant','unit-fuzz-security']:
    results.append(execute('baseline',BASE,kind))
if any(x['status']!='passed' for x in results):
    (ART/'results.json').write_text(json.dumps({'baseline_valid':False,'runs':results},indent=2)+'\n')
    raise SystemExit('Baseline did not pass; mutants not executed.')

def variant_work(mutation):
    name,rel,old,new,purpose=mutation
    dst=ROOT/name
    shutil.copytree(BASE,dst,ignore=shutil.ignore_patterns('node_modules','lib','out','cache','broadcast'))
    for dep in ['node_modules','lib']: (dst/dep).symlink_to((BASE/dep).resolve(),target_is_directory=True)
    p=dst/rel
    original=p.read_text()
    assert original.count(old)==1,(name,original.count(old))
    changed=original.replace(old,new,1)
    p.write_text(changed)
    diff=''.join(difflib.unified_diff(original.splitlines(True),changed.splitlines(True),fromfile='baseline/'+rel,tofile=name+'/'+rel))
    (ART/f'{name}.diff').write_text(diff)
    r=[execute(name,dst,kind) for kind in ['invariant','unit-fuzz-security']]
    return {'name':name,'purpose':purpose,'disposable_root':str(dst),'mutation_file':rel,'before_sha256':hashlib.sha256(original.encode()).hexdigest(),'after_sha256':hashlib.sha256(changed.encode()).hexdigest(),'runs':r}

with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    variants=list(pool.map(variant_work,MUTATIONS))
after={'validation':hash_sources(VALIDATION),'clean':hash_sources(CLEAN)}
assert before==after,'Frozen production sources changed outside this script.'
(ART/'frozen-input-hashes-after.json').write_text(json.dumps(after,indent=2)+'\n')
report={'baseline_valid':True,'baseline_runs':results,'variants':variants,'frozen_sources_unchanged':before==after,'completed_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
(ART/'results.json').write_text(json.dumps(report,indent=2)+'\n')
print('CAMPAIGN_COMPLETE',flush=True)
