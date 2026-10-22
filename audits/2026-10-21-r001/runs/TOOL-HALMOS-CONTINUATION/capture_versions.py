from importlib.metadata import version
from pathlib import Path
import hashlib, json, subprocess, sys
r=Path("/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001")
print(json.dumps({"python":sys.version,"halmos":version("halmos"),"z3-solver":version("z3-solver")},indent=2))
for executable,args in [(r/"tools/halmos-venv/bin/z3",["--version"]),(r/"tools/halmos-venv/bin/yices-smt2",["--version"]),(Path.home()/".halmos/solvers/bitwuzla",["--version"]),(Path.home()/".foundry/bin/forge",["--version"])]:
 print(json.dumps({"executable":str(executable),"sha256":hashlib.sha256(executable.read_bytes()).hexdigest()}))
 p=subprocess.run([str(executable),*args],capture_output=True,text=True)
 print(p.stdout,p.stderr,"exit",p.returncode)
