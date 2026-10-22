#!/usr/bin/env python3
"""Reconstruct isolated projects for this accounting continuation; never modifies the source project."""
from pathlib import Path
import argparse, shutil
ap=argparse.ArgumentParser()
ap.add_argument('--source',type=Path,default=Path('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001/halmos'))
ap.add_argument('--destination',type=Path,required=True)
a=ap.parse_args(); artifacts=Path(__file__).resolve().parent
assert not a.destination.exists(), 'Use a fresh destination to avoid overwriting any campaign.'
def copy_project(dst):
 dst.mkdir(parents=True)
 for name in ['src','test']: shutil.copytree(a.source/name,dst/name)
 for name in ['foundry.toml','remappings.txt','package.json','hardhat.config.ts']: shutil.copy2(a.source/name,dst/name)
 for name in ['lib','node_modules']: (dst/name).symlink_to((a.source/name).resolve(),target_is_directory=True)
 (dst/'test/foundry/symbolic/SupplementarySymbolic.t.sol').write_bytes((artifacts/'HARNESS-original-preserved.sol').read_bytes())
copy_project(a.destination)
for branch in ['cash-original','nft-original','nft-linear-reference','complete','complete-nft']:
 dst=a.destination/'branches'/branch; copy_project(dst)
 if branch=='nft-linear-reference': (dst/'test/foundry/symbolic/SupplementarySymbolic.t.sol').write_bytes((artifacts/'HARNESS-linear-reference.sol').read_bytes())
 if branch in ['complete','complete-nft']: (dst/'test/foundry/symbolic/CompleteSymbolic.t.sol').write_bytes((artifacts/'HARNESS-complete.sol').read_bytes())
print(a.destination)
