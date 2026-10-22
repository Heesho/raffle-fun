#!/usr/bin/env python3
"""Read-only probes of permitted historical configuration and Python model semantics."""
from pathlib import Path
import dataclasses,importlib.util,json,shutil,sys
ROOT=Path(__file__).resolve().parent
BASE=ROOT/'base'
ART=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/TOOL-MUTATION-QUALITY')
shutil.copy2(__file__,ART/'context_probes.py')
config=json.loads((ROOT.parent/'validation/packages/contracts/audit/current-mutations.json').read_text())
invalid=[]
for m in config['mutants']:
    path=BASE/m['path']
    count=path.read_text().count(m['before']) if path.is_file() else -1
    if count!=1: invalid.append({'id':m['id'],'path':m['path'],'match_count':count,'description':m['description']})
(ART/'historical-config-applicability.json').write_text(json.dumps({'definitions':len(config['mutants']),'non_unique_or_missing_patterns':invalid,'historical_results_not_read':True},indent=2)+'\n')
sys.dont_write_bytecode=True
spec=importlib.util.spec_from_file_location('current_protocol_model',BASE/'test/models/current_protocol_model.py')
module=importlib.util.module_from_spec(spec);sys.modules[spec.name]=module;spec.loader.exec_module(module)
model=module.Model(entry_price=1_000_000,reserve_entries=2)
ticket=model.buy('alice',1);model.end_sale();model.request();model.callback(0)
before={'settlement_complete':model.settlement_complete,'unsettled':model.unsettled,'sponsor_claim':model.sponsor_claim,'treasury_claim':model.treasury_claim,'winner_cash':model.winner_cash}
try:
    model.redeem_winner(ticket,caller='outsider')
    raised=None
except ValueError as e: raised=str(e)
after={key:getattr(model,key) for key in before}
result={'scenario':'Rejected nonowner lazy redemption in standalone Python model','raised':raised,'before':before,'after':after,'state_unchanged':before==after,'not_a_solidity_execution':True}
(ART/'python-model-rollback-probe.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
