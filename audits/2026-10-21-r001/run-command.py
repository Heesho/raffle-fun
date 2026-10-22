import sys,json,pathlib,subprocess,time,os,datetime,signal,hashlib
out=pathlib.Path(__file__).resolve().parent;f=json.loads((out/'freeze.json').read_text());runtime=pathlib.Path(f['runtime'])
slot=sys.argv[1];timeout=int(sys.argv[2]);cwd=sys.argv[3];cmd=sys.argv[4:]
p=out/'runs'/slot
attempt=1
while (p/f'attempt-{attempt:02}').exists():attempt+=1
p=p/f'attempt-{attempt:02}';p.mkdir(parents=True)
env=os.environ.copy();env['PATH']='/Users/hishamel-husseini/.nvm/versions/node/v22.23.2/bin:/Users/hishamel-husseini/Library/pnpm/.tools/pnpm/11.18.0/bin:/Users/hishamel-husseini/.foundry/bin:/opt/homebrew/bin:'+env['PATH']
def verify():
 issues=[]
 roots=[pathlib.Path(f['repository']),pathlib.Path(f['snapshot'])]
 if str(runtime) in cwd:roots.append(runtime/'validation') if cwd.startswith(str(runtime/'validation')) else None
 for root in roots:
  for name,want in f['files'].items():
   q=root/name
   if not q.is_file() or hashlib.sha256(q.read_bytes()).hexdigest()!=want:issues.append(str(q))
 for name,want in f.get('reachable_dependency_files',{}).items():
  q=runtime/'clean-context'/name
  if not q.is_file() or hashlib.sha256(q.read_bytes()).hexdigest()!=want:issues.append(str(q))
 return issues
before=verify();(p/'integrity-before.json').write_text(json.dumps(before,indent=2));record={'slot':slot,'command':cmd,'cwd':cwd,'timeout_seconds':timeout,'started_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'path_prefix':env['PATH'].split(':')[:4]}
if before:record.update(status='BLOCKED',reason='Frozen bytes mismatch',exit_code=None)
else:
 start=time.monotonic()
 with (p/'stdout.txt').open('wb') as stdout,(p/'stderr.txt').open('wb') as stderr:
  try:
   proc=subprocess.Popen(cmd,cwd=cwd,env=env,stdout=stdout,stderr=stderr,start_new_session=True)
   try:record['exit_code']=proc.wait(timeout=timeout);record['status']='COMPLETE' if proc.returncode==0 else 'INCOMPLETE'
   except subprocess.TimeoutExpired:
    os.killpg(proc.pid,signal.SIGTERM)
    try:proc.wait(timeout=5)
    except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL);proc.wait()
    record.update(exit_code=proc.returncode,status='INCOMPLETE',reason='Timeout')
  except FileNotFoundError as e:record.update(exit_code=127,status='BLOCKED',reason=str(e))
 record['duration_seconds']=time.monotonic()-start
 after=verify();(p/'integrity-after.json').write_text(json.dumps(after,indent=2))
 if after:record.update(status='INCOMPLETE',integrity_failure=after)
record['finished_at']=datetime.datetime.now(datetime.timezone.utc).isoformat();(p/'result.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record))
