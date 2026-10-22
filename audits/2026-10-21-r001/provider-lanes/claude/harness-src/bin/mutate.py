#!/usr/bin/env python3
"""Hand-selected semantic mutation campaign (Anthropic lane, r001).

Each mutant changes one operator/statement in a COPY of the production source inside the lane mutation
project. The kill suite is the lane's own properties: LanePropsFuzz (fuzz runs 128) + LaneInvariantTest
(runs 64, depth 64). Production files in the repository and in the validation snapshot are never touched.
"""
import json, shutil, subprocess, sys, time, hashlib
from pathlib import Path

RT = Path('/Users/hishamel-husseini/.codex/visualizations/2026/10/21/01a15d64-4430-7440-b259-192acf9762b5/raffle-audit-r001-claude')
SRC_H = RT / 'validation/claude-harness'
MUT = RT / 'validation/claude-harness-mutation'
OUT = RT / 'tool-out/LANE-MUTATION'

MUTANTS = [
    ("M01", "Raffle.sol", "if (block.timestamp >= endTime) revert SaleEnded", "if (block.timestamp > endTime) revert SaleEnded", "sale end boundary"),
    ("M02", "Raffle.sol", "if (block.timestamp < endTime) revert RaffleNotEnded", "if (block.timestamp <= endTime) revert RaffleNotEnded", "draw opens late"),
    ("M03", "Raffle.sol", "if (block.timestamp >= requestDeadline) {", "if (block.timestamp > requestDeadline) {", "draw window end"),
    ("M04", "Raffle.sol", "|| block.timestamp >= callbackDeadline()", "|| block.timestamp > callbackDeadline()", "callback deadline"),
    ("M05", "Raffle.sol", "deadline = callbackDeadline();\n            if (block.timestamp < deadline)", "deadline = callbackDeadline();\n            if (block.timestamp + 1 < deadline)", "drawing refunds early"),
    ("M06", "Raffle.sol", "deadline = drawRequestDeadline();\n                if (block.timestamp < deadline)", "deadline = drawRequestDeadline();\n                if (block.timestamp + 1 < deadline)", "active refunds early"),
    ("M07", "Raffle.sol", "sponsorAmount = grossPot - protocolFee - cashAmount;", "sponsorAmount = grossPot - cashAmount;", "cash split double-counts fee"),
    ("M08", "Raffle.sol", "sponsorAmount = grossPot - protocolFee;", "sponsorAmount = grossPot;", "nft split double-counts fee"),
    ("M09", "Raffle.sol", "aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;\n            _burn(ticketId);", "aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;", "refund without burn"),
    ("M10", "Raffle.sol", "if (winnerRedeemed) revert WinningTicketAlreadyRedeemed();", "", "no redeem-once guard"),
    ("M11", "Raffle.sol", "status = totalEntries >= reserveEntries ? Status.NftWon", "status = totalEntries > reserveEntries ? Status.NftWon", "reserve boundary"),
    ("M12", "Raffle.sol", "(randomWords[0] % uint256(totalEntries)) + 1", "(randomWords[0] % uint256(totalEntries))", "winning entry off-by-one"),
    ("M13", "Raffle.sol", "selectedEntry < firstEntry || selectedEntry > lastEntry", "selectedEntry < firstEntry || selectedEntry > lastEntry + 1", "winner range check widened"),
    ("M14", "Raffle.sol", "if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);", "", "redeem owner check removed"),
    ("M15", "Raffle.sol", "if (currentStatus != Status.CashWon && currentStatus != Status.Refunding) {", "if (currentStatus == Status.Active) {", "sponsor prize released after NftWon"),
    ("M16", "Raffle.sol", "        uint256 liability = unsettledPot;\n        unsettledPot = 0;", "        uint256 liability = unsettledPot;", "pot not cleared on refunds"),
    ("M17", "Raffle.sol", "        unsettledPot = 0;\n        sponsorProceeds = sponsorAmount;", "        sponsorProceeds = sponsorAmount;", "pot not cleared on settle"),
    ("M18", "Raffle.sol", "        protocolFees = 0;\n        address treasury", "        address treasury", "fees not zeroed on release"),
    ("M19", "Raffle.sol", "if (msg.sender != owner) revert NotTicketOwner(ticketId, msg.sender, owner);", "", "refund owner check removed"),
    ("M20", "Raffle.sol", "if (msg.sender != factory) revert OnlyFactory();", "", "initialize auth removed"),
    ("M21", "Raffle.sol", "_requestInFlight ||", "", "in-flight guard removed (sync callback)"),
    ("M22", "Raffle.sol", "if (prizeClaimed) revert PrizeAlreadyClaimed();\n\n        address recipient = sponsorRecipient;", "\n        address recipient = sponsorRecipient;", "sponsor prize claim-once removed"),
    ("M23", "libraries/RaffleConstants.sol", "PROTOCOL_FEE_BPS = 500;", "PROTOCOL_FEE_BPS = 501;", "fee constant"),
    ("M24", "libraries/RaffleConstants.sol", "DRAW_CALLBACK_TIMEOUT = 2 days;", "DRAW_CALLBACK_TIMEOUT = 3 days;", "callback timeout constant"),
]


def run(cmd, cwd, timeout):
    t = time.time()
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout + r.stderr, time.time() - t
    except subprocess.TimeoutExpired as e:
        return 'timeout', (e.stdout or '') if isinstance(e.stdout, str) else '', time.time() - t


def main():
    if MUT.exists():
        shutil.rmtree(MUT)
    shutil.copytree(SRC_H, MUT, ignore=shutil.ignore_patterns('out', 'cache'))
    OUT.mkdir(parents=True, exist_ok=True)
    env_suite = ['forge', 'test', '--match-contract', 'LanePropsFuzz|LaneInvariantTest', '--fuzz-runs', '128', '--fuzz-seed', '0x4d555441']
    results = []
    # baseline
    code, out, dur = run(env_suite, MUT, 900)
    (OUT / 'baseline.txt').write_text(out)
    results.append({'id': 'BASELINE', 'exit': code, 'duration_s': round(dur, 1)})
    for mid, f, old, new, desc in MUTANTS:
        p = MUT / 'src' / f
        orig = p.read_text()
        if orig.count(old) != 1:
            results.append({'id': mid, 'desc': desc, 'status': 'NOT_APPLIED', 'reason': f'pattern count {orig.count(old)}'})
            continue
        p.write_text(orig.replace(old, new))
        code, out, dur = run(env_suite, MUT, 900)
        p.write_text(orig)
        (OUT / f'{mid}.txt').write_text(out)
        failed = [l.strip() for l in out.splitlines() if l.startswith('[FAIL')]
        if 'Compiler run failed' in out or 'Error (' in out:
            status = 'COMPILE_ERROR'
        elif code == 'timeout':
            status = 'TIMEOUT'
        elif code != 0 and failed:
            status = 'KILLED'
        elif code == 0:
            status = 'SURVIVED'
        else:
            status = f'ERROR(exit {code})'
        results.append({'id': mid, 'file': f, 'desc': desc, 'status': status, 'killed_by': failed[:6], 'duration_s': round(dur, 1)})
        print(mid, status, desc, flush=True)
    # restore check
    for f in ['Raffle.sol', 'RaffleFactory.sol', 'libraries/RaffleConstants.sol']:
        a = hashlib.sha256((MUT / 'src' / f).read_bytes()).hexdigest()
        b = hashlib.sha256((SRC_H / 'src' / f).read_bytes()).hexdigest()
        results.append({'restore_check': f, 'ok': a == b})
    (OUT / 'results.json').write_text(json.dumps(results, indent=1))
    k = sum(1 for r in results if r.get('status') == 'KILLED'); n = sum(1 for r in results if 'status' in r and r['status'] not in ('NOT_APPLIED', 'COMPILE_ERROR'))
    print(json.dumps({'killed': k, 'evaluated': n}))


if __name__ == '__main__':
    main()
