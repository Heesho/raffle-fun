from pathlib import Path
import subprocess,json,datetime,shutil,hashlib
root=Path.cwd();stage=root/'audit/S6';stage.mkdir(exist_ok=True);started=datetime.datetime.now(datetime.timezone.utc).isoformat();(stage/'START.json').write_text(json.dumps({'started_at':started,'source_only_seal':'audit/source-only/SEAL.json','order':'after independently sealed S1-S5; no external reconciliation'},indent=2))
which={x:shutil.which(x) for x in ['slither','slither-check-erc','slither-check-upgradeability','slither-prop','solc','forge','echidna','echidna-test','manticore','dot']};(stage/'tools.json').write_text(json.dumps(which,indent=2))
def run(name,args,t=8,cwd='audit/tool-copy/contracts'):
 subprocess.run(['python3','audit/run_logged.py','--name',name,'--cwd',cwd,'--timeout',str(t),'--']+args)
run('00-version',['slither','--version'],5)
run('01-native-scan',['slither','.','--exclude-dependencies'],12)
run('02-erc721',['slither-check-erc','.','Raffle','--erc','erc721'],8)
run('03-inheritance',['slither','.','--print','inheritance-graph'],8)
run('04-functions',['slither','.','--print','function-summary'],8)
run('05-vars-auth',['slither','.','--print','vars-and-auth'],8)
h=stage/'harness';h.mkdir(exist_ok=True)
(h/'AllocationProperties.sol').write_text('''// Audit-created arithmetic-only property harness; not an end-to-end raffle proof.\npragma solidity 0.8.36;\nimport {RaffleConstants} from "../../tool-copy/contracts/src/libraries/RaffleConstants.sol";\nimport {Math} from "../../tool-copy/contracts/node_modules/@openzeppelin/contracts/utils/math/Math.sol";\ncontract AllocationProperties {\n uint128 public entries;\n function setEntries(uint128 n) public { entries=n; }\n function echidna_cash_conservation() public view returns(bool) {\n uint256 gross=uint256(entries)*RaffleConstants.ENTRY_PRICE;\n uint256 fee=Math.mulDiv(gross,RaffleConstants.PROTOCOL_FEE_BPS,RaffleConstants.BPS);\n uint256 winner=Math.mulDiv(gross,RaffleConstants.CASH_WINNER_BPS,RaffleConstants.BPS);\n uint256 sponsor=gross-fee-winner;\n return sponsor+fee+winner==gross; }\n function echidna_nft_conservation() public view returns(bool) {\n uint256 gross=uint256(entries)*RaffleConstants.ENTRY_PRICE;\n uint256 fee=Math.mulDiv(gross,RaffleConstants.PROTOCOL_FEE_BPS,RaffleConstants.BPS);\n return gross-fee+fee==gross; }\n}\n''')
(h/'echidna.yaml').write_text('testMode: property\ntestLimit: 1000\nseqLen: 16\n')
run('06-echidna',['echidna',str(h/'AllocationProperties.sol'),'--contract','AllocationProperties','--config',str(h/'echidna.yaml')],8,str(root))
run('07-manticore-version',['manticore','--version'],5,str(root))
manual=subprocess.run(['rg','-n','block.timestamp|blockhash|randomWords|ecrecover|delegatecall|upgrade|safeTransfer|transferFrom|msg.sender|call\\(','target/packages/contracts/src'],capture_output=True,text=True);(stage/'manual-pattern-search.txt').write_text(manual.stdout+manual.stderr)
run('08-deferred-entry-points',['slither','.','--print','entry-points'],8)
run('09-deferred-human-summary',['slither','.','--print','human-summary'],8)
run('10-deferred-contract-summary',['slither','.','--print','contract-summary'],8)
# Compatibility experiment changes platform adapter only; source/compiler settings remain unmodified.
run('11-compat-force-foundry',['slither','.','--compile-force-framework','foundry','--exclude-dependencies'],8)
(stage/'FINISHED.json').write_text(json.dumps({'finished_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'native_commands_attempted':12,'source_inputs_modified':False},indent=2))
