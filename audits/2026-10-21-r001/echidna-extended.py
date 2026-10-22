from pathlib import Path
import json,subprocess
out=Path(__file__).resolve().parent;f=json.loads((out/'freeze.json').read_text());r=Path(f['runtime']);cwd=r/'echidna'
for i,contract in enumerate(['RaffleEchidna','RaffleNftEchidna']):
 cmd=['echidna','test/echidna/RaffleEchidna.sol','--contract',contract,'--config','echidna.yaml','--format','text','--workers','1','--seed',str(2026102101+i),'--test-limit','100000','--seq-len','100','--timeout','1800','--corpus-dir',str(cwd/('extended-100000-'+contract)),'--disable-onchain-sources']
 subprocess.run(['python3',str(out/'run-command.py'),f'TOOL-ECHIDNA-EXTENDED-{i+1}','2000',str(cwd),*cmd],check=True)
