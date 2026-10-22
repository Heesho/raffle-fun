"""Exact, disclosed historical mismatch policy; never rewrites verifier results."""
import hashlib,json,re
from pathlib import Path

def require(condition, detail):
    if not condition: raise ValueError(detail)

def signature(record):
    m=re.search(r'expected=([0-9a-f]{64}); actual=([0-9a-f]{64})',record.get('detail',''))
    require(record.get('code')=='hash_mismatch' and m, ('Unexpected integrity error',record))
    return (record['code'],record['path'],record['detail'].split('; expected=')[0],m[1],m[2])

def qualify(result, limits, expected_reports, expected_attributions):
    require(not result['gaps'], ('Unresolved metadata gaps',result['gaps']))
    actual=[signature(x) for x in result['errors']]
    expected=[signature(x) for x in limits['known_unresolved_bindings']]
    require(len(actual)==len(set(actual))==4 and set(actual)==set(expected), ('Changed historical mismatch set',actual))
    c=result['counts']
    require(c['source_reports']==c['verified_source_report_hashes']==c['verified_source_seal_hashes']==expected_reports,'Report/seal count mismatch')
    require(c['verified_attributions']==expected_attributions,'Attribution count mismatch')
    for d in limits['diagnostics']:
        require(hashlib.sha256(Path(d['path']).read_bytes()).hexdigest()==d['sha256'], d['path'])
    require(len(result['historical_stream_qualifications'])==2,'Two exact historical prefix records required')
    require(all(x['prefix_independently_verified'] and x['original_whole_file_error_retained'] for x in result['historical_stream_qualifications']),'Unqualified historical prefix')
    return {'qualified_for_reconciliation_publication':True,'all_historical_bindings_intact':False,'original_verifier_ok':result['ok'],'known_historical_mismatch_count':4,'additional_errors':0,'metadata_gaps':0,'qualification':'All adopted source-report/seal hashes and attribution bounds verify. Exactly four separately diagnosed historical binding mismatches remain disclosed; no general error waiver or method-completion inference.'}
