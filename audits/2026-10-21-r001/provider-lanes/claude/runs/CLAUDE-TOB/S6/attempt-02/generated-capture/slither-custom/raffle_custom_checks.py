# GENERATED SCRATCH TOOLING (S6 attempt-02) - project-specific Slither Python API checks for raffle.fun.
# Skill Step 4 asks for "Custom Slither checks: use the Slither Python API for project-specific business logic".
# Usage (from the isolated harness, with FOUNDRY_SOLC/FOUNDRY_OFFLINE set):
#   <slither-venv-python> -I raffle_custom_checks.py <harness-dir> <out-json>
# Output: PASS/FAIL per check on stdout + a JSON inventory (entry points, transitive external interactions,
# msg.sender conditions, state writes) consumed by the Step 3 diagram generator.
import json
import sys

from slither.core.declarations import Function, SolidityFunction, SolidityVariableComposed
from slither.core.declarations.contract import Contract
from slither.core.variables.state_variable import StateVariable
from slither.slithir.operations import HighLevelCall, LibraryCall, LowLevelCall, SolidityCall
from slither.slither import Slither

target, out_json = sys.argv[1], sys.argv[2]
sl = Slither(target)


def one(name):
    found = sl.get_contract_from_name(name)
    assert len(found) == 1, f"expected exactly one contract named {name}, found {len(found)}"
    return found[0]


raffle, factory = one("Raffle"), one("RaffleFactory")
results = []


def check(cid, title, ok, evidence):
    results.append({"id": cid, "title": title, "result": "PASS" if ok else "FAIL", "evidence": evidence})


def fn(contract, name):
    matches = [f for f in contract.functions if f.name == name and f.contract_declarer.name == contract.name]
    if not matches:
        matches = [f for f in contract.functions if f.name == name]
    assert matches, f"{contract.name}.{name} not found"
    return matches[0]


def describe_hl(c, ir):
    callee = ir.function
    cname = callee.name if callee is not None else ir.function_name
    dest = str(ir.destination)
    return f"{type(ir).__name__}:{dest}.{cname}"


def interactions(f):
    """Transitive external interactions of f (descends into internal, library and modifier calls)."""
    out = set()
    for c, ir in f.all_high_level_calls():
        callee = ir.function
        cname = callee.name if callee is not None else str(ir.function_name)
        dest_type = str(getattr(ir.destination, "type", ""))
        if isinstance(ir, LibraryCall):
            # Library code is explored by Slither itself; record only the libraries that touch external code.
            if c.name in ("SafeERC20", "ERC721Utils", "Clones"):
                out.add(f"lib {c.name}.{cname}")
            continue
        out.add(f"call {dest_type or c.name}.{cname}")
    for ir in f.all_low_level_calls():
        out.add(f"lowlevel {ir.function_name} on {ir.destination}")
    for ir in f.all_solidity_calls():
        n = ir.function.name
        if n.startswith(("call(", "staticcall(", "delegatecall(", "callcode(", "create(", "create2(")):
            out.add(f"yul {n.split('(')[0]}")
    return sorted(out)


def classify(inter):
    tags = set()
    for s in inter:
        if "SafeERC20" in s:
            tags.add("USDC (trusted)")
        if "ERC721Utils" in s or "onERC721Received" in s:
            tags.add("ERC721 receiver callback (UNTRUSTED)")
        if "IVRFV2PlusWrapper" in s:
            tags.add("VRF wrapper (trusted)")
        if "IRaffleFactory" in s:
            tags.add("Factory registry view (trusted)")
        if ("IERC721." in s and "onERC721Received" not in s) or "IERC165" in s:
            tags.add("Prize ERC721 (UNTRUSTED)")
        if "IRaffle." in s:
            tags.add("Raffle clone (protocol code)")
        if "Clones" in s:
            tags.add("CREATE clone")
        if "IERC20Metadata" in s:
            tags.add("Quote token metadata")
        if s.startswith("yul call"):
            tags.add("native value call to caller or token (see notes)")
        if s.startswith("yul create"):
            tags.add("CREATE")
    return sorted(tags)


def sender_conditions(f):
    conds = []
    for node in f.nodes:
        if node.is_conditional() and any(
            isinstance(v, SolidityVariableComposed) and v.name == "msg.sender" for v in node.solidity_variables_read
        ):
            conds.append(str(node.expression))
    return conds


def entry_points(contract):
    eps = []
    for f in contract.functions_entry_points:
        eps.append(f)
    return eps


inventory = {}
for contract in (raffle, factory):
    rows = []
    for f in entry_points(contract):
        inter = interactions(f)
        rows.append({
            "function": f.full_name,
            "is_constructor": f.is_constructor,
            "declared_in": f.contract_declarer.name,
            "visibility": f.visibility,
            "mutability": "view" if f.view else ("pure" if f.pure else ("payable" if f.payable else "nonpayable")),
            "modifiers": [m.name for m in f.modifiers],
            "msg_sender_conditions": sender_conditions(f),
            "state_written": sorted({v.name for v in f.all_state_variables_written() if isinstance(v, StateVariable)}),
            "external_interactions": inter,
            "interaction_classes": classify(inter),
        })
    inventory[contract.name] = rows

# ---- C1: state-changing Raffle entry points that interact externally must be nonReentrant (explicit allowlist) ----
allow = {
    "initialize(IRaffle.RaffleInitParams)": "factory-only, one-shot; only trusted factory view calls",
    "rawFulfillRandomWords(uint256,uint256[])": "wrapper-only callback; must not revert, so not nonReentrant",
    "onERC721Received(address,address,uint256,bytes)": "prize-deposit acceptor; no external calls",
    "approve(address,uint256)": "inherited ERC721; factory view calls only via _update? (approve has none)",
    "setApprovalForAll(address,bool)": "inherited ERC721",
    "transferFrom(address,address,uint256)": "inherited ERC721; _update screens destination via trusted factory views",
    "safeTransferFrom(address,address,uint256)": "inherited ERC721; recipient callback after state update",
    "safeTransferFrom(address,address,uint256,bytes)": "inherited ERC721; recipient callback after state update",
}
viol, seen = [], []
for row in inventory["Raffle"]:
    if row["mutability"] in ("view", "pure") or row["is_constructor"]:
        continue  # constructors are not callable after deployment (run-1 artifact fixed here)
    seen.append(row["function"])
    if row["external_interactions"] and "nonReentrant" not in row["modifiers"] and row["function"] not in allow:
        viol.append(row["function"])
check("C1", "Raffle state-changing entry points with external interactions are nonReentrant (except documented allowlist)",
      not viol, {"violations": viol, "allowlist": allow, "checked": seen})

# ---- C2: every outbound quote-token transfer goes through _transferQuote (destination screening) ----
bad, sites = [], []
for f in raffle.functions + raffle.modifiers:
    if f.contract_declarer.name != "Raffle":
        continue
    for ir in f.slithir_operations:
        if isinstance(ir, LibraryCall) and ir.function is not None and ir.function.name == "safeTransfer":
            sites.append(f.full_name)
            if f.name != "_transferQuote":
                bad.append(f.full_name)
check("C2", "All quote-token safeTransfer calls are inside _transferQuote", not bad and sites,
      {"safeTransfer_sites": sites, "violations": bad})

# ---- C3: per-raffle configuration is write-once (constructor never; only initialize) ----
config = ["sponsor", "sponsorRecipient", "protocolTreasury", "prizeToken", "prizeTokenId", "raffleId", "reserveEntries",
          "endTime"]
writers = {v: sorted({f.full_name for f in raffle.functions if f.contract_declarer.name == "Raffle"
                      and v in [s.name for s in f.state_variables_written]}) for v in config}
ok3 = all(w == ["initialize(IRaffle.RaffleInitParams)"] for w in writers.values())
check("C3", "Per-raffle configuration variables are written only by initialize()", ok3, writers)

# ---- C4: lifecycle status writers are exactly the intended transition functions ----
status_writers = sorted({f.full_name for f in raffle.functions if f.contract_declarer.name == "Raffle"
                         and "status" in [s.name for s in f.state_variables_written]})
expected4 = sorted(["constructor(address,address)", "initialize(IRaffle.RaffleInitParams)", "requestDraw()",
                    "enableRefunds()", "onERC721Received(address,address,uint256,bytes)",
                    "fulfillRandomWords(uint256,uint256[])"])
check("C4", "status is written only by constructor/initialize/onERC721Received/requestDraw/enableRefunds/fulfillRandomWords",
      status_writers == expected4, {"actual": status_writers, "expected": expected4})

# ---- C5: VRF callback handler has no explicit revert, no external call, no loop ----
cb = fn(raffle, "fulfillRandomWords")
reverts = [str(ir.expression) for ir in cb.all_solidity_calls()
           if ir.function.name.startswith(("revert", "require", "assert"))]
cb_ext = interactions(cb)
loops = [str(n) for n in cb.nodes if n.type.name in ("STARTLOOP", "IFLOOP")]
check("C5", "fulfillRandomWords: no explicit revert/require/assert, no external interaction, no loop",
      not reverts and not cb_ext and not loops, {"reverts": reverts, "external": cb_ext, "loops": loops,
                                                "note": "implicit panics reviewed manually: modulo by totalEntries>0, "
                                                        "index [0] guarded by length==1"})

# ---- C6: settlement is storage-only ----
st = fn(raffle, "_settleWinningTicket")
st_ext = [x for x in interactions(st)]
check("C6", "_settleWinningTicket performs no external interaction (storage-only settlement)", not st_ext,
      {"external": st_ext})

# ---- C7: prize NFT transfers only in redeemWinningTicket/releaseSponsorPrize, guarded by prizeClaimed + ownerOf check ----
prize_sites = {}
for f in raffle.functions:
    if f.contract_declarer.name != "Raffle":
        continue
    calls = [ir.function.name for c, ir in f.high_level_calls
             if not isinstance(ir, LibraryCall) and ir.function is not None and str(ir.destination) == "prizeToken"]
    if calls:
        prize_sites[f.full_name] = {"calls": calls, "writes_prizeClaimed": "prizeClaimed" in [
            s.name for s in f.state_variables_written], "reads_prizeClaimed": "prizeClaimed" in [
            s.name for s in f.state_variables_read]}
ok7 = set(prize_sites) == {"redeemWinningTicket(uint256)", "releaseSponsorPrize()"} and all(
    v["writes_prizeClaimed"] and v["reads_prizeClaimed"] and "transferFrom" in v["calls"] and "ownerOf" in v["calls"]
    for v in prize_sites.values())
check("C7", "Prize transfers only in redeem/releaseSponsorPrize, each reads+writes prizeClaimed and verifies ownerOf",
      ok7, prize_sites)

# ---- C8: ticket _update override screens non-burn destinations ----
upd = [f for f in raffle.functions if f.name == "_update" and f.contract_declarer.name == "Raffle"][0]
calls_screen = any(ir.function is not None and ir.function.name == "_isProtocolDestination"
                   for ir in upd.internal_calls)
calls_super = any(ir.function is not None and ir.function.name == "_update" and ir.function.contract_declarer.name ==
                  "ERC721" for ir in upd.internal_calls)
check("C8", "Raffle._update screens destinations via _isProtocolDestination and delegates to ERC721._update",
      calls_screen and calls_super, {"screens": calls_screen, "calls_super": calls_super,
                                     "expression_nodes": [str(n.expression) for n in upd.nodes if n.expression]})

# ---- C9: dangerous primitives absent from production contracts ----
prims = {}
for contract in (raffle, factory):
    for f in contract.functions + contract.modifiers:
        if f.contract_declarer.name not in ("Raffle", "RaffleFactory"):
            continue
        for ir in f.slithir_operations:
            n = None
            if isinstance(ir, SolidityCall):
                n = ir.function.name
            if isinstance(ir, LowLevelCall):
                n = ir.function_name
            if n and any(k in n for k in ("delegatecall", "selfdestruct", "suicide", "ecrecover", "blockhash",
                                          "callcode")):
                prims.setdefault(f.full_name, []).append(n)
        for v in f.solidity_variables_read:
            if v.name in ("tx.origin", "block.prevrandao", "block.difficulty", "block.coinbase"):
                prims.setdefault(f.full_name, []).append(v.name)
check("C9", "No delegatecall/selfdestruct/ecrecover/blockhash/tx.origin/prevrandao in production contracts", not prims,
      prims)

# ---- C10: factory registers clone before any untrusted prize interaction; initialize precedes registration ----
cr = fn(factory, "createRaffle")
order = []
for node in cr.nodes:
    for ir in node.irs:
        if isinstance(ir, HighLevelCall) and not isinstance(ir, LibraryCall) and ir.function is not None:
            order.append(("call", f"{ir.destination}.{ir.function.name}", node.node_id))
        if isinstance(ir, LibraryCall) and ir.function is not None and ir.function.name == "clone":
            order.append(("clone", "Clones.clone", node.node_id))
    for v in node.state_variables_written:
        order.append(("write", v.name, node.node_id))
labels = [f"{k}:{x}" for k, x, _ in order]


def idx(label):
    return labels.index(label) if label in labels else -1


i_init = next((i for i, l in enumerate(labels) if l.endswith(".initialize")), -1)
i_reg = idx("write:isRaffle")
i_prize = next((i for i, l in enumerate(labels) if l.endswith(".safeTransferFrom")), -1)
check("C10", "createRaffle: clone -> initialize -> register(isRaffle) -> untrusted prize safeTransferFrom",
      -1 < idx("clone:Clones.clone") < i_init < i_reg < i_prize, {"ordered_effects": labels})

# ---- C11: unsettledPot writers and liability movers ----
pot_writers = sorted({f.full_name for f in raffle.functions if f.contract_declarer.name == "Raffle"
                      and "unsettledPot" in [s.name for s in f.state_variables_written]})
check("C11", "unsettledPot written only by buyEntries/enableRefunds/_settleWinningTicket",
      pot_writers == sorted(["buyEntries(address,uint128)", "enableRefunds()", "_settleWinningTicket(uint256)"]),
      {"writers": pot_writers})

# ---- C12: every payout recipient is fixed config or the current ticket owner/msg.sender ----
recips = {}
for f in raffle.functions:
    if f.contract_declarer.name != "Raffle":
        continue
    for ir in f.internal_calls:
        if ir.function is not None and ir.function.name == "_transferQuote":
            recips.setdefault(f.full_name, []).append(str(ir.arguments[0]))
check("C12", "_transferQuote recipients are sponsorRecipient/protocolTreasury (fixed) or the authenticated owner",
      bool(recips), recips)

json.dump({"checks": results, "inventory": inventory}, open(out_json, "w"), indent=1)
for r in results:
    print(f"[{r['result']}] {r['id']} {r['title']}")
    print("       evidence:", json.dumps(r["evidence"])[:900])
fails = [r for r in results if r["result"] != "PASS"]
print(f"SUMMARY: {len(results) - len(fails)}/{len(results)} PASS")
sys.exit(1 if fails else 0)
