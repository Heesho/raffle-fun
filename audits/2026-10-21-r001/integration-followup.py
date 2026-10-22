from pathlib import Path
import subprocess,json
out=Path(__file__).resolve().parent;f=json.loads((out/'freeze.json').read_text());r=Path(f['runtime']);root=r/'validation';runner=out/'run-command.py'
plan=[('TOOL-CONFIG-BUILD',['pnpm','--filter','@raffle-fun/config','build']),('TOOL-CONFIG-TEST',['pnpm','--filter','@raffle-fun/config','test']),('TOOL-SDK-BUILD',['pnpm','--filter','@raffle-fun/sdk','build']),('TOOL-SDK-TYPECHECK',['pnpm','--filter','@raffle-fun/sdk','typecheck']),('TOOL-SDK-TEST',['pnpm','--filter','@raffle-fun/sdk','test']),('TOOL-WEB-TEST',['pnpm','--filter','@raffle-fun/web','test']),('TOOL-WEB-TYPECHECK',['pnpm','--filter','@raffle-fun/web','typecheck']),('TOOL-PYTHON-MODEL',['python3','-m','unittest','discover','-s','packages/contracts/test/models','-v'])]
for slot,cmd in plan:subprocess.run(['python3',str(runner),slot,'180',str(root),*cmd],check=True)
