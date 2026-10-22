from pathlib import Path
import subprocess, os, json, hashlib, datetime
root=Path(__file__).resolve().parent
workspace=root.parent
native=Path('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/upstreams/pashov/solidity-auditor/references/assemble.sh')
run=workspace/'.solidity-auditor/runs/20261021-004900'
env=dict(os.environ)
env['TMPDIR']=str(root/'assembler-tmp')
env['PATH']=str(root/'assembler-tools')+os.pathsep+env['PATH']
cmd=['bash',str(native),'--dir',str(run)]
result=subprocess.run(cmd,cwd=workspace,env=env,capture_output=True)
(root/'logs/assembler.stdout').write_bytes(result.stdout)
(root/'logs/assembler.stderr').write_bytes(result.stderr)
(root/'logs/assembler-execution.json').write_text(json.dumps({'command':cmd,'exit_code':result.returncode,'script_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'timestamp':datetime.datetime.now(datetime.timezone.utc).isoformat(),'temporary_directory':env['TMPDIR'],'preservation':'rm shim copies native temporary directory verbatim before /bin/rm; native assembler bytes unchanged'},indent=2)+'\n')
print(result.stdout.decode(),end='')
print(result.stderr.decode(),end='')
if result.returncode: raise SystemExit(result.returncode)
awk='''/^## Leads$/  { sec="leads"; next }
/^## /        { sec="";      next }
/^\\[[0-9]+\\]/ { F++; next }
sec=="leads" && /^- \\*\\*/ { L++ }
/Confidence: [0-9]+/ && /^`/ {
  match($0, /Confidence: [0-9]+/)
  c = substr($0, RSTART+12, RLENGTH-12) + 0
  if (c >= 90) A++; else if (c >= 75) B++; else C++
}
END { printf "%d %d %d %d %d\\n", F, L, A, B, C }
'''
count=subprocess.run(['awk',awk,str(run/'full-report.md')],capture_output=True,check=True)
(root/'logs/native-counts.stdout').write_bytes(count.stdout)
F,L,A,B,C=map(int,count.stdout.split())
(root/'logs/native-counts.json').write_text(json.dumps(dict(findings=F,leads=L,confidence_90_100=A,confidence_75_89=B,confidence_below_75=C,count_check=A+B+C==F),indent=2)+'\n')
print(count.stdout.decode(),end='')
