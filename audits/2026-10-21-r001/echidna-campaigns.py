from pathlib import Path
import json,subprocess
out=Path(__file__).resolve().parent;f=json.loads((out/'freeze.json').read_text());r=Path(f['runtime']);runner=out/'run-command.py';cwd=r/'echidna'
for index,contract in enumerate(['RaffleEchidna','RaffleNftEchidna']):
 cmd=['echidna','test/echidna/RaffleEchidna.sol','--contract',contract,'--config','echidna.yaml','--format','json','--workers','1','--seed',str(2026102101+index),'--test-limit','100000','--seq-len','100','--timeout','180','--corpus-dir',str(cwd/f'fresh-corpus-{contract}'),'--disable-onchain-sources']
 subprocess.run(['python3',str(runner),f'TOOL-ECHIDNA-{index+1}','240',str(cwd),*cmd],check=True)
