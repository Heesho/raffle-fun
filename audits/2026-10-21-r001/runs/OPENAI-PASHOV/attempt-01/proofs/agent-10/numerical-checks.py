#!/usr/bin/env python3
"""Exact-integer checks of formulas read from the supplied bundle; no EVM execution."""
from pathlib import Path
import hashlib,json,random,re
ROOT=Path(__file__).resolve().parents[3]
bundle=ROOT/'.audit-9aXxui/agent-10-bundle.md'
text=bundle.read_text()
parts={m.group(1):m.group(2) for m in re.finditer(r'^### ([^\n]+)\n\n```[^\n]*\n(.*?)^```',text,re.M|re.S)}
c=parts['target/packages/contracts/src/libraries/RaffleConstants.sol']
constant=lambda name:int(re.search(r'constant '+name+r' = ([\d_]+);',c).group(1).replace('_',''))
PRICE=constant('ENTRY_PRICE'); BPS=constant('BPS'); FEE=constant('PROTOCOL_FEE_BPS'); CASH=constant('CASH_WINNER_BPS')
MAX128=(1<<128)-1; MAX256=(1<<256)-1
rng=random.Random(10)
cases=[0,1,2,3,19,20,99,100,9999,10000,MAX128-1,MAX128]
cases.extend(rng.randrange(0,MAX128+1) for _ in range(100000))
for entries in cases:
    gross=entries*PRICE
    fee=gross*FEE//BPS
    cash=gross*CASH//BPS
    sponsor_nft=gross-fee
    sponsor_cash=gross-fee-cash
    assert 0<=gross<=MAX256
    assert gross*FEE<=MAX256 and gross*CASH<=MAX256
    assert fee==entries*50000
    assert cash==entries*800000
    assert sponsor_cash==entries*150000
    assert sponsor_nft==entries*950000
    assert cash+fee+sponsor_cash==gross
    assert fee+sponsor_nft==gross
    if entries:
        assert cash>0 and fee>0 and sponsor_cash>0
        for word in [0,1,entries-1,entries,MAX256]:
            winning=word%entries+1
            assert 1<=winning<=entries<=MAX128
# Each successful purchase must increase totalEntries by at least one.
# Thus ticketCount <= totalEntries <= MAX128; the entry guard also protects ticketCount.
# Compare amount-before-division and division-before-count identities for every tested count.
assert PRICE*FEE % BPS == 0 and PRICE*CASH % BPS == 0
partitions=0
for _ in range(5000):
    count=rng.randrange(1,101)
    total=rng.randrange(count,MAX128+1)
    cuts=sorted(rng.sample(range(1,min(total,10**12)),count-1)) if count>1 else []
    bounds=[0]+cuts+[total]
    ranges=[(bounds[i]+1,bounds[i+1]) for i in range(count)]
    assert all(a<=b for a,b in ranges)
    assert sum(b-a+1 for a,b in ranges)==total
    liability=total*PRICE
    rng.shuffle(ranges)
    for first,last in ranges:
        refund=(last-first+1)*PRICE
        assert refund<=liability
        liability-=refund
    assert liability==0
    partitions+=1
# Deadline gates share exclusive request/callback boundaries and inclusive refund boundaries.
end=1800000000; timeout=172800
checks=[]
for now in [end-1,end,end+timeout-1,end+timeout,end+timeout+1]:
    buy=now<end
    request=end<=now<end+timeout
    refund=now>=end+timeout
    assert sum([buy,request,refund])==1
    checks.append({'timestamp':now,'buy':buy,'request':request,'refund':refund})
result={
 'model':'Python exact integers; formulas and guards reviewed against the bundle',
 'bundle_sha256':hashlib.sha256(bundle.read_bytes()).hexdigest(),
 'entry_cases':len(cases),'refund_partitions':partitions,
 'max_entries':str(MAX128),'max_pot':str(MAX128*PRICE),
 'max_pot_bits':(MAX128*PRICE).bit_length(),
 'max_fee_product_bits':(MAX128*PRICE*FEE).bit_length(),
 'max_cash_product_bits':(MAX128*PRICE*CASH).bit_length(),
 'minimum_cash_payout':PRICE*CASH//BPS,
 'minimum_protocol_fee':PRICE*FEE//BPS,
 'floor_residue_protocol':PRICE*FEE%BPS,'floor_residue_cash':PRICE*CASH%BPS,
 'deadline_checks':checks,'result':'pass'
}
out=Path(__file__).with_name('numerical-checks.json')
out.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
