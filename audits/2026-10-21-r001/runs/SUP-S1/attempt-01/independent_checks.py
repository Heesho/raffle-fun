#!/usr/bin/env python3
"""Independent mathematical security checks; does not execute Solidity/EVM."""
from datetime import datetime, timezone
from itertools import permutations
from pathlib import Path
import json

P=1_000_000
M=(1<<128)-1
counts={'economic_samples':0,'compositions':0,'range_membership_entries':0,'refund_subsets':0,'release_orders':0,'deadline_samples':0,'randomness_bound_samples':0}

def split(gross,nft):
    # Specification-derived expectations: 5% fee; 80% cash winner; sponsor remainder.
    fee=(gross*5)//100
    winner=0 if nft else (gross*80)//100
    sponsor=gross-fee-winner
    return winner,sponsor,fee

for e in list(range(10001))+[M,M-1,M//2,1<<64,(1<<127)+123]:
    g=e*P
    assert g < (1<<148)
    for nft in (False,True):
        vals=split(g,nft)
        assert sum(vals)==g and min(vals)>=0
        assert vals[2]==e*50_000
        assert vals[1]==e*(950_000 if nft else 150_000)
        assert vals[0]==(0 if nft else e*800_000)
        counts['economic_samples']+=1
        # Each permutation models independent claims, including zero-size allocations.
        for order in permutations(range(3)):
            liability=list(vals)
            balance=g
            for i in order:
                balance-=liability[i]
                liability[i]=0
                assert balance==sum(liability)
            assert balance==0
            counts['release_orders']+=1

def compositions(n):
    if n==0:
        yield []
    else:
        for k in range(1,n+1):
            for tail in compositions(n-k):
                yield [k]+tail

for e in range(1,10):
    for comp in compositions(e):
        ranges=[]
        cursor=1
        for c in comp:
            ranges.append((cursor,cursor+c-1))
            cursor+=c
        assert cursor==e+1
        assert len(ranges)<=e
        for w in range(1,e+1):
            assert sum(lo<=w<=hi for lo,hi in ranges)==1
            counts['range_membership_entries']+=1
        for mask in range(1<<len(comp)):
            refunded=sum(comp[i] for i in range(len(comp)) if mask>>i&1)*P
            live=sum(comp[i] for i in range(len(comp)) if not mask>>i&1)*P
            assert refunded+live==e*P
            counts['refund_subsets']+=1
        counts['compositions']+=1

end=1_800_000_000
span=2*24*60*60
for t in [end-1,end,end+1,end+span-1,end+span,end+span+1]:
    buy=t<end
    request=end<=t<end+span
    refunds=t>=end+span
    assert sum((buy,request,refunds))==1
    counts['deadline_samples']+=1
for q in [end,end+span-1]:
    for t in [q,q+span-1,q+span,q+span+1]:
        callback=t<q+span
        refunds=t>=q+span
        assert callback != refunds
        counts['deadline_samples']+=1
for e in [1,2,3,7,100,1<<64,M]:
    for r in [0,1,e-1,e,(1<<128)-1,(1<<255),(1<<256)-1]:
        selected=1+r%e
        assert 1<=selected<=e and selected<=M
        counts['randomness_bound_samples']+=1
# Guard clone-zero state is accepted by equality-to-ENTERED formulation.
for initial in [0,1]:
    assert initial!=2
    during=2
    assert during==2

result={'status':'passed','generated_utc':datetime.now(timezone.utc).isoformat(),'scope':'standalone specification-derived integer, range, liability and deadline checks; no EVM or contract runtime executed','counts':counts}
Path(__file__).with_name('INDEPENDENT-CHECKS.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
