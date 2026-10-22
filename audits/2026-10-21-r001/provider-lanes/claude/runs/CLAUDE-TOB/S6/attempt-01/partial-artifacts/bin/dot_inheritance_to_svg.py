"""Render the in-scope subgraph of a Slither inheritance-graph DOT file to SVG and Mermaid (stdlib only).

Usage: python3 -I dot_inheritance_to_svg.py <in.dot> <out.svg> <out.mmd> Root1 [Root2 ...]
Edges in Slither's DOT point from a derived contract to its immediate base, labelled with declaration order.
"""

import re
import sys
from collections import defaultdict

src, out_svg, out_mmd, *roots = sys.argv[1:]
text = open(src).read()

edge_re = re.compile(r'^c\d+_(\w+) -> c\d+_(\w+)(?: \[ label="(\d+)" \])?;', re.M)
edges = [(a, b, int(lbl) if lbl else 1) for a, b, lbl in edge_re.findall(text)]
children = defaultdict(list)
for a, b, lbl in edges:
    children[a].append((b, lbl))

# Reachable subgraph from the roots
seen, stack = set(), list(roots)
while stack:
    n = stack.pop()
    if n in seen:
        continue
    seen.add(n)
    stack.extend(b for b, _ in children.get(n, []))
sub = [(a, b, l) for a, b, l in edges if a in seen and b in seen]

# Longest-path layering: derived contracts on top
layer = {r: 0 for r in roots}
changed = True
while changed:
    changed = False
    for a, b, _ in sub:
        if a in layer and layer.get(b, -1) < layer[a] + 1:
            layer[b] = layer[a] + 1
            changed = True
rows = defaultdict(list)
for n, l in layer.items():
    rows[l].append(n)

# Barycenter ordering (a few sweeps) to reduce crossings
order = {}
for l in sorted(rows):
    rows[l].sort()
    for i, n in enumerate(rows[l]):
        order[n] = i
parents = defaultdict(list)
for a, b, _ in sub:
    parents[b].append(a)
for _ in range(6):
    for l in sorted(rows)[1:]:
        rows[l].sort(key=lambda n: sum(order[p] for p in parents[n]) / max(1, len(parents[n])))
        for i, n in enumerate(rows[l]):
            order[n] = i

IN_SCOPE = {"Raffle", "RaffleFactory", "IRaffle", "IRaffleFactory"}
is_iface = lambda n: n.startswith("I") and n[1:2].isupper()

BOX_W, BOX_H, GAP_X, GAP_Y, MARGIN = 190, 34, 26, 70, 30
width = max(len(r) for r in rows.values()) * (BOX_W + GAP_X) + 2 * MARGIN
height = len(rows) * (BOX_H + GAP_Y) + 2 * MARGIN + 40
pos = {}
for l, ns in rows.items():
    row_w = len(ns) * (BOX_W + GAP_X) - GAP_X
    x0 = (width - row_w) / 2
    for i, n in enumerate(ns):
        pos[n] = (x0 + i * (BOX_W + GAP_X), MARGIN + 40 + l * (BOX_H + GAP_Y))

svg = [
    f'<svg xmlns="http://www.w3.org/2000/svg" width="{int(width)}" height="{int(height)}" font-family="Helvetica,Arial,sans-serif" font-size="12">',
    '<defs><marker id="arrow" viewBox="0 0 10 10" refX="10" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
    '<path d="M 0 0 L 10 5 L 0 10 z" fill="#555"/></marker></defs>',
    f'<rect x="0" y="0" width="{int(width)}" height="{int(height)}" fill="white"/>',
    f'<text x="{MARGIN}" y="{MARGIN}" font-size="14" font-weight="bold">Inheritance graph (Slither inheritance-graph --include-interfaces, in-scope subgraph); arrow = "inherits from", label = declaration order</text>',
]
for a, b, l in sub:
    ax, ay = pos[a]; bx, by = pos[b]
    x1, y1 = ax + BOX_W / 2, ay + BOX_H
    x2, y2 = bx + BOX_W / 2, by
    svg.append(f'<line x1="{x1:.0f}" y1="{y1:.0f}" x2="{x2:.0f}" y2="{y2:.0f}" stroke="#555" stroke-width="1.2" marker-end="url(#arrow)"/>')
    mx, my = x1 + (x2 - x1) * 0.25, y1 + (y2 - y1) * 0.25
    svg.append(f'<circle cx="{mx:.0f}" cy="{my:.0f}" r="8" fill="#fff" stroke="#999"/><text x="{mx:.0f}" y="{my + 4:.0f}" text-anchor="middle" font-size="10">{l}</text>')
for n, (x, y) in pos.items():
    fill = "#ffe8cc" if n in IN_SCOPE else "#eef2f7"
    dash = ' stroke-dasharray="5,3"' if is_iface(n) else ""
    weight = "bold" if n in IN_SCOPE else "normal"
    svg.append(f'<rect x="{x:.0f}" y="{y:.0f}" width="{BOX_W}" height="{BOX_H}" rx="5" fill="{fill}" stroke="#333"{dash}/>')
    svg.append(f'<text x="{x + BOX_W / 2:.0f}" y="{y + BOX_H / 2 + 4:.0f}" text-anchor="middle" font-weight="{weight}">{n}</text>')
ly = height - 18
svg.append(f'<rect x="{MARGIN}" y="{ly - 11}" width="14" height="14" fill="#ffe8cc" stroke="#333"/><text x="{MARGIN + 20}" y="{ly}">in scope</text>')
svg.append(f'<rect x="{MARGIN + 90}" y="{ly - 11}" width="14" height="14" fill="#eef2f7" stroke="#333"/><text x="{MARGIN + 110}" y="{ly}">dependency (context only)</text>')
svg.append(f'<rect x="{MARGIN + 290}" y="{ly - 11}" width="14" height="14" fill="#fff" stroke="#333" stroke-dasharray="5,3"/><text x="{MARGIN + 310}" y="{ly}">interface</text>')
svg.append("</svg>")
open(out_svg, "w").write("\n".join(svg) + "\n")

mmd = ["graph BT"]
for n in sorted(seen):
    shape = f'{n}(["{n}"])' if is_iface(n) else f'{n}["{n}"]'
    mmd.append(f"  {shape}")
for a, b, l in sub:
    mmd.append(f"  {a} -->|{l}| {b}")
mmd.append("  classDef scope fill:#ffe8cc,stroke:#333,font-weight:bold;")
mmd.append("  class " + ",".join(sorted(seen & IN_SCOPE)) + " scope;")
open(out_mmd, "w").write("\n".join(mmd) + "\n")
print(f"nodes={len(seen)} edges={len(sub)} layers={len(rows)} -> {out_svg}, {out_mmd}")
