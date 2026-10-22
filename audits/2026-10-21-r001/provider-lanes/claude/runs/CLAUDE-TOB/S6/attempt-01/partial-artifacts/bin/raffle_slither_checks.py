"""Project-specific Slither API analysis for the raffle.fun in-scope contracts.

Produces (1) a compact function summary, (2) a state-variable authorization map, and
(3) custom business-logic checks (Step 4 of the Trail of Bits secure workflow).

Run from the work directory with Slither's Python:
  $SLPY -I tob-s6-artifacts/bin/raffle_slither_checks.py
"""

import os
import sys

from slither import Slither
from slither.core.declarations import SolidityVariableComposed
from slither.slithir.operations import HighLevelCall, LowLevelCall, InternalCall, LibraryCall

HOME = os.path.expanduser("~")
TARGET = "tob-s6-artifacts/step3/Scope.sol"
SOLC = f"{HOME}/.solc-select/artifacts/solc-0.8.36/solc-0.8.36"
REMAPS = (
    "@openzeppelin/contracts/=packages/contracts/node_modules/@openzeppelin/contracts/ "
    "@chainlink/contracts/=packages/contracts/node_modules/@chainlink/contracts/"
)
SOLC_ARGS = "--optimize --optimize-runs 200 --evm-version cancun --allow-paths ."

sl = Slither(
    TARGET,
    compile_force_framework="solc",
    solc=SOLC,
    solc_remaps=REMAPS,
    solc_args=SOLC_ARGS,
)

contracts = {c.name: c for c in sl.contracts if c.name in ("Raffle", "RaffleFactory")}
MSG_SENDER = SolidityVariableComposed("msg.sender")


def mutability(f):
    if f.pure:
        return "pure"
    if f.view:
        return "view"
    if f.payable:
        return "payable"
    return "nonpayable"


def ext_calls(f):
    out = []
    for c, ir in f.all_high_level_calls():
        if isinstance(ir, LibraryCall):
            continue
        out.append(f"{c.name}.{ir.function_name}")
    for _, ir in f.all_low_level_calls():
        out.append(f"low-level:{ir.function_name}")
    # inline-assembly CALL is invisible to SlithIR; flag functions containing assembly
    if any(n.type.name == "ASSEMBLY" for fn in [f] + list(f.all_internal_calls()) if hasattr(fn, "nodes") for n in fn.nodes):
        out.append("inline-asm")
    return sorted(set(out))


def sender_guard(f):
    return MSG_SENDER in f.all_conditional_solidity_variables_read(include_loop=True)


def has_nonreentrant(f):
    return any(m.name == "nonReentrant" for m in f.modifiers)


print("=" * 100)
print("PART 1: COMPACT FUNCTION SUMMARY (entry points of in-scope contracts, incl. inherited)")
print("=" * 100)
for cname, c in contracts.items():
    print(f"\n## {cname}")
    print("| Function | Declared in | Visibility | Mutability | Modifiers | msg.sender in condition | State vars written (transitively) | External calls (transitively) |")
    print("|---|---|---|---|---|---|---|---|")
    for f in sorted(c.functions_entry_points, key=lambda x: (x.view or x.pure, x.full_name)):
        writes = sorted({v.name for v in f.all_state_variables_written()})
        print(
            f"| `{f.full_name}` | {f.contract_declarer.name} | {f.visibility} | {mutability(f)} | "
            f"{', '.join(m.name for m in f.modifiers) or '-'} | {'yes' if sender_guard(f) else 'no'} | "
            f"{', '.join(writes) or '-'} | {', '.join(ext_calls(f)) or '-'} |"
        )

print()
print("=" * 100)
print("PART 2: STATE VARIABLE AUTHORIZATION MAP (who can write each variable)")
print("=" * 100)
for cname, c in contracts.items():
    print(f"\n## {cname}")
    print("| State variable | Kind | Written by entry points | Entry points with msg.sender condition |")
    print("|---|---|---|---|")
    for v in c.state_variables:
        if v.contract.name not in ("Raffle", "RaffleFactory"):
            # inherited storage: only list ERC721 bookkeeping summarily
            pass
        kind = "constant" if v.is_constant else ("immutable" if v.is_immutable else "storage")
        writers = []
        guarded = []
        for f in c.functions_entry_points:
            if v in f.all_state_variables_written():
                writers.append(f.name)
                if sender_guard(f):
                    guarded.append(f.name)
        ctor = [f.name for f in c.constructors if v in f.all_state_variables_written()]
        w = sorted(set(writers) - {"constructor"})
        if ctor:
            w = ["constructor"] + w
        print(f"| `{v.contract.name}.{v.name}` | {kind} | {', '.join(w) or '-'} | {', '.join(sorted(set(guarded))) or '-'} |")

print()
print("=" * 100)
print("PART 3: CUSTOM BUSINESS-LOGIC CHECKS")
print("=" * 100)
raffle = contracts["Raffle"]
factory = contracts["RaffleFactory"]
results = []


def check(name, ok, detail):
    results.append((name, ok))
    print(f"\n[{'PASS' if ok else 'FLAG'}] {name}\n    {detail}")


# C1: state-changing entry points that make external calls must be nonReentrant (with documented exceptions)
EXEMPT = {
    "initialize": "factory-only, one-shot, only calls trusted factory views",
    "onERC721Received": "callee-side hook; no external calls",
    "rawFulfillRandomWords": "wrapper-only; no external calls",
}
bad = []
info = []
for f in raffle.functions_entry_points:
    if f.view or f.pure or f.is_constructor:
        continue
    calls = ext_calls(f)
    if f.contract_declarer.name == "ERC721":
        # ERC721 standard entry points reach Raffle._update -> factory view calls, and safeTransferFrom calls receiver
        info.append(f"{f.full_name} (ERC721, no guard; calls: {', '.join(calls) or '-'})")
        continue
    if calls and not has_nonreentrant(f) and f.name not in EXEMPT:
        bad.append(f"{f.full_name}: calls {calls}")
check(
    "C1 every Raffle state-changing entry point with external calls is nonReentrant (exemptions documented)",
    not bad,
    ("violations: " + "; ".join(bad)) if bad else
    "OK. Unguarded but exempt: " + "; ".join(f"{k} ({v})" for k, v in EXEMPT.items())
    + ". Unguarded ERC721 entry points: " + "; ".join(info),
)

# C2: every quote-token transfer goes through _transferQuote (protocol-destination screen)
qt_sites = []
for f in raffle.functions_and_modifiers_declared:
    for node in f.nodes:
        for ir in node.irs:
            if isinstance(ir, (HighLevelCall, LibraryCall)) and ir.function_name in ("safeTransfer", "safeTransferFrom", "transfer", "transferFrom"):
                token = ir.arguments[0] if isinstance(ir, LibraryCall) else ir.destination
                to = ir.arguments[1] if isinstance(ir, LibraryCall) else (ir.arguments[1] if len(ir.arguments) > 1 else None)
                qt_sites.append((f.name, ir.function_name, str(token), node.source_mapping.lines[0], node, to))
quote_out = [s for s in qt_sites if s[1] in ("safeTransfer", "transfer") and "quoteToken" in str(s[2])]
quote_in = [s for s in qt_sites if s[1] in ("safeTransferFrom", "transferFrom") and "quoteToken" in str(s[2])]
ok = all(s[0] == "_transferQuote" for s in quote_out)
check(
    "C2 all outgoing quote-token transfers are routed through _transferQuote (runtime destination screen)",
    ok,
    "outgoing USDC call sites: " + ", ".join(f"{s[0]}:{s[1]}@L{s[3]}" for s in quote_out)
    + " | incoming USDC call sites: " + ", ".join(f"{s[0]}:{s[1]}@L{s[3]}" for s in quote_in)
    + " | callers of _transferQuote: " + ", ".join(sorted({f.name for f in raffle.functions_declared
        if any(getattr(ic, 'function', ic).name == '_transferQuote' for ic in f.internal_calls)})),
)

# C3: every prize-NFT outflow is screened like quote-token outflows
prize_out = [s for s in qt_sites if s[1] in ("transferFrom", "safeTransferFrom") and "prizeToken" in str(s[2])]


def screened_before(node, to_var):
    seen, stack = set(), list(node.fathers)
    while stack:
        n = stack.pop()
        if n in seen:
            continue
        seen.add(n)
        for ir in n.irs:
            if isinstance(ir, InternalCall) and ir.function.name in ("_isProtocolDestination", "_transferQuote"):
                if ir.arguments and str(ir.arguments[0]) == str(to_var):
                    return True
        stack.extend(n.fathers)
    return False


screened = []
for fname, _, _, line, node, to in prize_out:
    screened.append((fname, line, str(to), screened_before(node, to)))
check(
    "C3 every prize-NFT outflow re-screens its destination with _isProtocolDestination at transfer time",
    all(s[3] for s in screened),
    "prize outflow sites: " + ", ".join(f"{n}@L{l} to={t} screened-on-path={s}" for n, l, t, s in screened),
)

# C4: lifecycle `status` is written only by the expected functions
allowed_status_writers = {"constructor", "initialize", "onERC721Received", "requestDraw", "enableRefunds", "fulfillRandomWords"}
status_var = next(v for v in raffle.state_variables if v.name == "status")
writers = {f.name for f in raffle.functions_and_modifiers if status_var in f.state_variables_written}
check(
    "C4 `status` is written only by constructor/initialize/onERC721Received/requestDraw/enableRefunds/fulfillRandomWords",
    writers <= allowed_status_writers,
    f"actual writers: {sorted(writers)}",
)

# C5: per-raffle configuration is write-once (only constructor/initialize)
config = ["sponsor", "sponsorRecipient", "protocolTreasury", "prizeToken", "prizeTokenId", "raffleId", "reserveEntries", "endTime"]
viol = {}
for name in config:
    v = next(x for x in raffle.state_variables if x.name == name)
    w = {f.name for f in raffle.functions_and_modifiers if v in f.state_variables_written} - {"constructor", "initialize"}
    if w:
        viol[name] = sorted(w)
check("C5 per-raffle configuration variables are written only in initialize", not viol, f"violations: {viol}" if viol else "OK")

# C6: factory has no privileged / mutable-configuration entry points
f_entry = [f.full_name for f in factory.functions_entry_points if not (f.view or f.pure or f.is_constructor)]
check("C6 RaffleFactory exposes exactly one state-changing entry point (createRaffle)", f_entry == ["createRaffle(IRaffleFactory.CreateRaffleParams)"], f"state-changing entry points: {f_entry}")

# C7: Raffle has no delegatecall/selfdestruct anywhere in its call graph
dangerous = []
for f in raffle.functions_and_modifiers:
    for node in f.nodes:
        for ir in node.irs:
            if isinstance(ir, LowLevelCall) and ir.function_name in ("delegatecall", "callcode"):
                dangerous.append(f"{f.name}:{ir.function_name}")
        if "selfdestruct" in str(node.expression or ""):
            dangerous.append(f"{f.name}:selfdestruct")
check("C7 no delegatecall/callcode/selfdestruct reachable in the Raffle implementation", not dangerous, f"found: {dangerous}" if dangerous else "OK")

# C8: functions reading block.timestamp (deadline surface) - informational inventory
ts = sorted({f.name for f in list(raffle.functions_and_modifiers) + list(factory.functions_and_modifiers)
             if SolidityVariableComposed("block.timestamp") in f.solidity_variables_read})
check("C8 inventory: functions reading block.timestamp (deadline logic only)", True, ", ".join(ts))

print("\nSUMMARY:", ", ".join(f"{n.split()[0]}={'PASS' if ok else 'FLAG'}" for n, ok in results))
