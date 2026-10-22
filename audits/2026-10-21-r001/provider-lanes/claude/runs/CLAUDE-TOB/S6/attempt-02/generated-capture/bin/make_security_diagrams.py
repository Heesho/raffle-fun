# Generated scratch helper (S6 attempt-02): build Graphviz diagrams for skill Step 3 from preserved raw printer data.
#  * function-summary-access-map.dot : function-summary printer (visibility, modifiers, cyclomatic complexity)
#    + vars-and-auth msg.sender conditions + transitive external interactions (Slither API inventory).
#  * vars-and-auth-map.dot : vars-and-auth printer (state variables written per function, msg.sender conditions).
# Usage: python make_security_diagrams.py <parsed-printer-tables.json> <custom-checks.json> <out-dir>
import html
import json
import os
import sys

parsed = json.load(open(sys.argv[1]))
inv = json.load(open(sys.argv[2]))["inventory"]
out = sys.argv[3]
os.makedirs(out, exist_ok=True)


def esc(s):
    return html.escape(str(s), quote=True)


def fs_row(contract, signature):
    rows = [r for r in parsed["function_summary"][contract]["functions"] if r["Function"] == signature]
    # Prefer the implementation row (has modifiers or highest CC) over interface-declaration rows.
    rows.sort(key=lambda r: (r["Modifiers"] != "[]", int(r["Cyclomatic Complexity"] or 0)), reverse=True)
    return rows[0] if rows else None


def va_rows(contract, name):
    return [r for r in parsed["vars_and_auth"][contract] if r["Function"] == name]


SHORT_AUTH = {
    "rawFulfillRandomWords(uint256,uint256[])": "msg.sender == VRF wrapper",
    "initialize(IRaffle.RaffleInitParams)": "msg.sender == factory; !initialized",
    "onERC721Received(address,address,uint256,bytes)": "AwaitingPrize; msg.sender == prizeToken; from == sponsor; operator == factory",
    "enableRefunds()": "deadline passed, or sponsor on empty Active raffle",
    "redeemWinningTicket(uint256)": "msg.sender == ownerOf(winning ticket)",
    "refundTickets(uint256[])": "msg.sender == ownerOf(each ticket)",
    "approve(address,uint256)": "ERC721 owner/operator (_approve auth)",
    "setApprovalForAll(address,bool)": "caller sets own approvals",
    "transferFrom(address,address,uint256)": "ERC721 owner/approved (_checkAuthorized)",
    "safeTransferFrom(address,address,uint256)": "ERC721 owner/approved (_checkAuthorized)",
    "safeTransferFrom(address,address,uint256,bytes)": "ERC721 owner/approved (_checkAuthorized)",
    "receive()": "always reverts (DirectNativeTransfer)",
    "createRaffle(IRaffleFactory.CreateRaffleParams)": "anyone (msg.sender becomes sponsor; must own prize)",
}
PERMISSIONLESS = "permissionless (anyone)"

# External parties (trust per DESIGN.md: USDC + VRF wrapper trusted; prize contracts + recipients untrusted)
PARTIES = {
    "usdc": ("Canonical USDC (trusted)\nSafeERC20 transfer/transferFrom", "#e8f0fe", "#1a56db"),
    "vrf": ("Chainlink VRF v2.5 wrapper (trusted)\ncalculate/requestRandomWordsInNative", "#e8f0fe", "#1a56db"),
    "registry": ("RaffleFactory registry views (trusted)\nraffleImplementation() / isRaffle()", "#e8f0fe", "#1a56db"),
    "prize": ("Prize ERC-721 contract (UNTRUSTED)\ntransferFrom / ownerOf / supportsInterface / safeTransferFrom", "#fde8e8", "#c81e1e"),
    "receiver": ("Ticket recipient contract (UNTRUSTED)\nonERC721Received callback", "#fde8e8", "#c81e1e"),
    "native": ("msg.sender (UNTRUSTED)\nnative excess-fee refund call{value} (all gas)", "#fde8e8", "#c81e1e"),
    "clone": ("Raffle clone (protocol code)\ninitialize() / status()", "#f3f4f6", "#374151"),
    "create": ("CREATE: ERC-1167 clone\n(Clones.clone)", "#f3f4f6", "#374151"),
}


def party_edges(row):
    classes = set(row["interaction_classes"])
    f = row["function"]
    edges = set()
    if "USDC (trusted)" in classes:
        edges.add("usdc")
    if "VRF wrapper (trusted)" in classes:
        edges.add("vrf")
    if "Factory registry view (trusted)" in classes:
        edges.add("registry")
    if "Prize ERC721 (UNTRUSTED)" in classes:
        edges.add("prize")
    if "ERC721 receiver callback (UNTRUSTED)" in classes:
        edges.add("receiver")
    if "Raffle clone (protocol code)" in classes:
        edges.add("clone")
    if "CREATE clone" in classes or "CREATE" in classes:
        edges.add("create")
    if f == "requestDraw()":
        edges.add("native")  # Raffle.sol:262-270 inline-assembly refund of excess msg.value to msg.sender
    return sorted(edges)


def fill_for(row):
    f = row["function"]
    if f == "receive()":
        return "#e5e7eb"
    if "nonReentrant" in row["modifiers"]:
        return "#d1fae5"
    if row["declared_in"] in ("ERC721",):
        return "#dbeafe"
    return "#fef3c7"


lines = [
    'digraph "function_summary_access_map" {',
    '  graph [rankdir=LR, fontname="Helvetica", fontsize=12, labelloc=t, nodesep=0.25, ranksep=1.6,',
    '         label="raffle.fun — Slither function-summary + vars-and-auth authorization + transitive external interactions\\n'
    'green = nonReentrant · amber = caller-gated without nonReentrant · blue = inherited ERC-721 auth · grey = always reverts · red parties = untrusted (DESIGN.md)"];',
    '  node [shape=plain, fontname="Helvetica", fontsize=10];',
    '  edge [fontname="Helvetica", fontsize=9];',
]
for contract in ("Raffle", "RaffleFactory"):
    lines.append(f'  subgraph "cluster_{contract}" {{ label="{contract} (state-changing entry points)"; style=rounded; color="#6b7280";')
    for row in inv[contract]:
        if row["mutability"] in ("view", "pure") or row["is_constructor"]:
            continue
        f = row["function"]
        fsr = fs_row(contract, f) or {}
        auth = SHORT_AUTH.get(f, PERMISSIONLESS)
        mods = ", ".join(row["modifiers"]) or "—"
        cc = fsr.get("Cyclomatic Complexity", "?")
        nid = f"{contract}__{f.split('(')[0]}" + ("_bytes" if f.endswith("bytes)") and "safeTransferFrom" in f else "")
        label = (f'<<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0" CELLPADDING="3" BGCOLOR="{fill_for(row)}">'
                 f'<TR><TD ALIGN="LEFT"><B>{esc(f)}</B></TD></TR>'
                 f'<TR><TD ALIGN="LEFT">{esc(row["visibility"])} · {esc(row["mutability"])} · declared in {esc(row["declared_in"])} · CC={esc(cc)}</TD></TR>'
                 f'<TR><TD ALIGN="LEFT">modifiers: {esc(mods)}</TD></TR>'
                 f'<TR><TD ALIGN="LEFT">auth: {esc(auth)}</TD></TR></TABLE>>')
        lines.append(f'    "{nid}" [label={label}];')
        row["_nid"] = nid
    lines.append("  }")
lines.append('  subgraph "cluster_ext" { label="External parties reached (transitively)"; style=dashed; color="#9ca3af";')
for key, (label, fill, color) in PARTIES.items():
    lines.append(f'    "P_{key}" [shape=box, style="rounded,filled", fillcolor="{fill}", color="{color}", penwidth=2, label="{label}"];')
lines.append("  }")
for contract in ("Raffle", "RaffleFactory"):
    for row in inv[contract]:
        if "_nid" not in row:
            continue
        for p in party_edges(row):
            color = PARTIES[p][2]
            style = "bold" if color == "#c81e1e" else "solid"
            lines.append(f'  "{row["_nid"]}" -> "P_{p}" [color="{color}", style={style}];')
lines.append("}")
open(os.path.join(out, "function-summary-access-map.dot"), "w").write("\n".join(lines) + "\n")

# ---------------- vars-and-auth map ----------------
GROUPS = {
    "Per-raffle configuration (write-once in initialize)": ["sponsor", "sponsorRecipient", "protocolTreasury",
                                                            "prizeToken", "prizeTokenId", "raffleId",
                                                            "reserveEntries", "endTime", "initialized"],
    "Lifecycle and one-shot flags": ["status", "settlementComplete", "winnerRedeemed", "prizeClaimed",
                                     "winnerRecipient", "winningTicketId"],
    "USDC accounting buckets": ["unsettledPot", "remainingRefundLiability", "winnerProceeds", "sponsorProceeds",
                                "protocolFees"],
    "Draw / VRF": ["vrfRequestId", "drawRequestedAt", "_requestInFlight", "resolvedAt", "winningEntry"],
    "Ticket ledger (ERC-721 + ranges)": ["totalEntries", "ticketCount", "_ticketRanges", "_owners", "_balances",
                                         "_tokenApprovals", "_operatorApprovals"],
}
FUNCS = ["initialize", "onERC721Received", "buyEntries", "requestDraw", "rawFulfillRandomWords", "enableRefunds",
         "settleWinningTicket", "redeemWinningTicket", "refundTickets", "releaseSponsorProceeds", "releaseProtocolFees",
         "releaseSponsorPrize", "transferFrom", "safeTransferFrom", "approve", "setApprovalForAll", "constructor"]
SENDER = {
    "initialize": "msg.sender != factory → revert",
    "onERC721Received": "status/msg.sender/tokenId/from/operator exact match",
    "rawFulfillRandomWords": "msg.sender != vrfWrapperAddr → revert",
    "enableRefunds": "msg.sender != sponsor && now < deadline → revert",
    "redeemWinningTicket": "msg.sender != winner → revert",
    "refundTickets": "msg.sender != owner → revert",
}
writes = {}
for name in FUNCS:
    rows = va_rows("Raffle", name)
    ws = set()
    for r in rows:
        ws |= set(eval(r["State variables written"]))  # printer emits Python-list literals of identifiers
    if name == "rawFulfillRandomWords":
        for r in va_rows("Raffle", "fulfillRandomWords"):
            ws |= set(eval(r["State variables written"]))
    writes[name] = ws
L = [
    'digraph "vars_and_auth_map" {',
    '  graph [rankdir=LR, fontname="Helvetica", fontsize=12, labelloc=t, ranksep=2.2, nodesep=0.12,',
    '         label="raffle.fun Raffle — Slither vars-and-auth: which entry point writes which state variable (incl. internal calls)\\n'
    'edge colour = writer · node note = msg.sender condition reported by the printer (none = permissionless)"];',
    '  node [fontname="Helvetica", fontsize=10];',
    '  edge [arrowsize=0.6];',
]
palette = ["#1f77b4", "#d62728", "#2ca02c", "#9467bd", "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf",
           "#ff7f0e", "#393b79", "#637939", "#8c6d31", "#843c39", "#7b4173", "#3182bd", "#636363"]
L.append('  subgraph "cluster_f" { label="Raffle entry points (and constructor)"; style=rounded; color="#6b7280";')
for i, name in enumerate(FUNCS):
    note = SENDER.get(name, "no msg.sender condition (permissionless)" if name not in ("constructor",) else
                      "implementation only (clones never run it)")
    if name in ("transferFrom", "safeTransferFrom", "approve", "setApprovalForAll"):
        note = "ERC-721 auth via _checkAuthorized/_approve (not a msg.sender == X test)"
    L.append(f'    "F_{name}" [shape=box, style="rounded,filled", fillcolor="#f9fafb", color="{palette[i % len(palette)]}", '
             f'penwidth=2, label="{name}()\\n{note}"];')
L.append("  }")
for gi, (g, vs) in enumerate(GROUPS.items()):
    L.append(f'  subgraph "cluster_g{gi}" {{ label="{g}"; style=filled; fillcolor="#f3f4f6"; color="#9ca3af";')
    for v in vs:
        L.append(f'    "V_{v}" [shape=ellipse, style=filled, fillcolor=white, label="{v}"];')
    L.append("  }")
for i, name in enumerate(FUNCS):
    for v in sorted(writes[name]):
        if any(v in vs for vs in GROUPS.values()):
            L.append(f'  "F_{name}" -> "V_{v}" [color="{palette[i % len(palette)]}"];')
L.append("}")
open(os.path.join(out, "vars-and-auth-map.dot"), "w").write("\n".join(L) + "\n")

# Factory vars-and-auth (small)
F = ['digraph "factory_vars_and_auth" {', '  graph [rankdir=LR, fontname="Helvetica", labelloc=t, '
     'label="RaffleFactory — vars-and-auth (printer): no msg.sender conditions; immutables set only in constructor"];',
     '  node [fontname="Helvetica", fontsize=10];']
for name in ("constructor", "createRaffle"):
    ws = set()
    for r in va_rows("RaffleFactory", name):
        ws |= set(eval(r["State variables written"]))
    F.append(f'  "F_{name}" [shape=box, style="rounded,filled", fillcolor="#f9fafb", label="{name}()\\npermissionless"];')
    for v in sorted(ws):
        F.append(f'  "V_{v}" [shape=ellipse, label="{v}"];')
        F.append(f'  "F_{name}" -> "V_{v}";')
F.append("}")
open(os.path.join(out, "factory-vars-and-auth-map.dot"), "w").write("\n".join(F) + "\n")
print("wrote", [f for f in os.listdir(out) if f.endswith(".dot")])
print({k: sorted(v) for k, v in writes.items()})
