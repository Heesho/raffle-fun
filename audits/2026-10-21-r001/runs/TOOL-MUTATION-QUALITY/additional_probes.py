#!/usr/bin/env python3
"""Diagnostic followups, separate from the unchanged-existing-suite mutation runs."""
from pathlib import Path
import datetime,json,os,shutil,subprocess,time
ROOT=Path(__file__).resolve().parent
ART=Path('/Users/hishamel-husseini/Documents/projects/raffle-fun/audits/2026-10-21-r001/runs/TOOL-MUTATION-QUALITY')
shutil.copy2(__file__,ART/'additional_probes.py')
PROBE='''// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;
import { RaffleInvariantTest } from "./RaffleInvariant.t.sol";
contract ReachabilityProbeTest is RaffleInvariantTest {
    function testGuidedCashSettlementUsesExistingEconomicInvariant() public {
        handler.buy(3);
        handler.warpToEnd();
        handler.requestDraw();
        handler.fulfill(0);
        handler.settleCandidateWinner(0);
        assertTrue(raffle.settlementComplete(), "guided sequence failed to settle");
        invariantBranchEconomicsRemainEightyFifteenFiveNinetyFiveFiveOrFullRefund();
    }
}
'''
(ART/'ReachabilityProbe.t.sol').write_text(PROBE)
def run(name,variant,args,settings):
    cmd=['forge','test','--root',str(ROOT/variant),*args]
    env=os.environ.copy();env.update(settings)
    start=time.monotonic();code=None;status='timeout'
    with (ART/(name+'.log')).open('w') as f:
        f.write('COMMAND: '+json.dumps(cmd)+'\nENV: '+json.dumps(settings)+'\n');f.flush()
        try:
            code=subprocess.run(cmd,cwd=ROOT/variant,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=90).returncode
            status='passed' if code==0 else 'failed'
        except subprocess.TimeoutExpired: pass
    return {'name':name,'command':cmd,'environment':settings,'exit_code':code,'status':status,'duration_seconds':round(time.monotonic()-start,3)}
r=[]
r.append(run('M1-fee-400-invariant-extended','M1-fee-400',['--match-contract','RaffleInvariantTest','--no-match-path','**/fork/**'],{'FOUNDRY_INVARIANT_RUNS':'512','FOUNDRY_INVARIANT_DEPTH':'64'}))
r.append(run('M4-purchase-always-reverts-strict','M4-purchase-always-reverts',['--match-contract','RaffleInvariantTest','--no-match-path','**/fork/**'],{'FOUNDRY_PROFILE':'audit_strict','FOUNDRY_INVARIANT_RUNS':'16','FOUNDRY_INVARIANT_DEPTH':'64'}))
for variant in ['base','M1-fee-400']:
    p=ROOT/variant/'test/foundry/invariant/ReachabilityProbe.t.sol'
    p.write_text(PROBE)
    r.append(run(variant+'-guided-probe',variant,['--match-contract','ReachabilityProbeTest','--match-test','testGuidedCashSettlementUsesExistingEconomicInvariant'],{}))
(ART/'additional-probes-results.json').write_text(json.dumps({'completed_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'runs':r},indent=2)+'\n')
print(json.dumps(r,indent=2),flush=True)
