"""Explicit final receipt gates; no text-substring or absent-list defaults."""
from pathlib import Path
import hashlib,json

def require(condition,detail):
    if not condition: raise ValueError(detail)

def verify_required_lanes(state, baseline):
    for key in ('expected_lanes','semantic_qualification_pending','post_source_workflow_pending'):
        require(key in state and isinstance(state[key],list),('Missing mandatory pending list',key))
        require(not state[key],('Pending receipt gate',key,state[key]))
    for key,expected in baseline['required_lane_sets'].items():
        require(key in state and isinstance(state[key],list),('Missing mandatory required list',key))
        require(len(state[key])==len(set(state[key])) and set(state[key])==set(expected),('Required lane baseline changed',key))

def verify_gate_receipt_binding(seal_path,receipt_path,expected,audit_root):
    sp=Path(seal_path).resolve();rp=Path(receipt_path).resolve();a=Path(audit_root).resolve()
    data=json.loads(sp.read_text());records=[]
    # These explicitly supported seal fields bind paths and digests. A digest
    # occurring in prose, unrelated metadata or status fields is insufficient.
    for field in ('completionReceipt','packageArtifacts','artifacts'):
        value=data.get(field)
        if isinstance(value,list): records.extend(x for x in value if isinstance(x,dict))
        elif isinstance(value,dict):
            if 'path' in value and 'sha256' in value:records.append(value)
            else:
                records.extend({'path':k,'sha256':v.get('sha256') if isinstance(v,dict) else v} for k,v in value.items())
    matched=[]
    for x in records:
        if not isinstance(x.get('path'),str) or x.get('sha256')!=expected:continue
        p=Path(x['path'])
        # Absolute records or explicitly documented local/audit-root-relative
        # captures are supported; the effective receipt must be the exact file.
        candidates=[p.resolve()] if p.is_absolute() else [(sp.parent/p).resolve(),(a/p).resolve()]
        if rp in candidates:matched.append(x)
    require(matched,('Gate receipt lacks typed path+hash seal binding',str(sp),str(rp)))
    require(hashlib.sha256(rp.read_bytes()).hexdigest()==expected,('Gate receipt changed',str(rp)))
    return matched
