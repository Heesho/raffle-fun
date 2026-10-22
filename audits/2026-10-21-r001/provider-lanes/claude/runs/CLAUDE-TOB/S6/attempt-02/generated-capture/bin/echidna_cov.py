# Generated scratch helper (S6 attempt-02): summarize an Echidna covered.*.txt for the production files.
# Reports per-file executed-line ratios and the marks on "depth probe" lines that prove deep lifecycle states were
# reached (settlement, NFT/cash redemption, refunds, prize return, callback resolution, ...).
# Echidna marks: '*' executed (and returned), 'r' reverted, 'e' error, 'o' out of gas.
import re
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8", errors="replace").read().splitlines()
sections, cur = {}, None
for line in text:
    if line.startswith("/") and line.endswith(".sol"):
        cur = line
        sections[cur] = []
        continue
    m = re.match(r"^\s*(\d+)\s*\|\s*([*reo]*)\s*\|(.*)$", line)
    if cur and m:
        sections[cur].append((int(m.group(1)), m.group(2), m.group(3)))

PROBES = {
    "src/Raffle.sol": {
        230: "buyEntries state update",
        253: "requestDraw: status = Drawing",
        263: "requestDraw: excess refund branch",
        281: "enableRefunds: empty-raffle branch",
        286: "enableRefunds: sold-raffle deadline branch",
        290: "enableRefunds: Drawing callback-deadline branch",
        299: "enableRefunds: status = Refunding",
        315: "redeem: settle-on-redeem branch",
        317: "redeem: WinningTicketMismatch branch",
        331: "redeem: NftWon prize delivery",
        339: "redeem: CashWon cash delivery",
        363: "refundTickets: per-ticket accumulation",
        368: "refundTickets: liability decrement",
        378: "releaseSponsorProceeds payout",
        388: "releaseProtocolFees payout",
        403: "releaseSponsorPrize payout",
        428: "onERC721Received: activate",
        514: "fulfillRandomWords: ignored branch",
        518: "fulfillRandomWords: resolution",
        544: "settle: NftWon split",
        546: "settle: CashWon split",
        551: "settle: record",
        565: "_transferQuote destination screen",
        603: "_isProtocolDestination: registry isRaffle query",
    },
    "src/RaffleFactory.sol": {
        105: "createRaffle: id",
        128: "createRaffle: prize escrow",
        136: "createRaffle: event",
    },
}

for name, rows in sections.items():
    short = None
    for key in PROBES:
        if name.endswith("/" + key):
            short = key
    if short is None:
        continue
    executable = [r for r in rows if r[1]]
    print(f"== {short}: {len(executable)} lines carry marks; '*'-executed: {sum(1 for r in rows if '*' in r[1])}")
    marks = {n: mk for n, mk, _ in rows}
    for ln, label in sorted(PROBES[short].items()):
        src = next((s for n, _, s in rows if n == ln), "").strip()
        print(f"   L{ln:<4} [{marks.get(ln, '') or '-':3s}] {label:45s} | {src[:70]}")
