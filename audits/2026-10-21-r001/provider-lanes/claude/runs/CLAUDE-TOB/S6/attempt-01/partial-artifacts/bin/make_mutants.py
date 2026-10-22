"""Create single-mutation copies of the in-scope sources under tob-s6-artifacts/mutants/<ID>/src (read-only source)."""
import os, shutil, sys, json
WORK = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(WORK, "packages", "contracts", "src")
OUT = os.path.join(WORK, "tob-s6-artifacts", "mutants")
M = {
  "M01-callback-deadline-inclusive": ("|| block.timestamp >= callbackDeadline()", "|| block.timestamp > callbackDeadline()",
      "VRF callback accepted at drawRequestedAt+2d (spec: strictly before)"),
  "M02-refunds-open-at-sale-end": ("deadline = drawRequestDeadline();\n                if (block.timestamp < deadline)",
      "deadline = endTime;\n                if (block.timestamp < deadline)", "refunds open during the draw-request window"),
  "M03-cash-sponsor-overallocated": ("sponsorAmount = grossPot - protocolFee - cashAmount;", "sponsorAmount = grossPot - cashAmount;",
      "CashWon sponsor share ignores the protocol fee (over-allocation)"),
  "M04-refund-without-burn": ("aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;\n            _burn(ticketId);",
      "aggregateEntries += uint256(lastEntry) - uint256(firstEntry) + 1;", "refunded tickets are not burned (double refund)"),
  "M05-sponsor-reclaims-nft-in-nftwon": ("if (currentStatus != Status.CashWon && currentStatus != Status.Refunding) {",
      "if (currentStatus != Status.CashWon && currentStatus != Status.Refunding && currentStatus != Status.NftWon) {",
      "sponsor can take back the NFT after the reserve was met"),
  "M06-overlapping-ranges": ("uint128 firstEntry = totalEntries + 1;", "uint128 firstEntry = totalEntries;",
      "ticket ranges overlap / entry 0 assigned"),
  "M07-redeem-without-owner-check": ("if (msg.sender != winner) revert NotTicketOwner(ticketId, msg.sender, winner);\n\n        winnerRecipient",
      "\n        winnerRecipient", "anyone can trigger redemption of the winning ticket"),
  "M08-request-window-inclusive": ("if (block.timestamp >= requestDeadline) {", "if (block.timestamp > requestDeadline) {",
      "draw request accepted at endTime+2d (spec: half-open window)"),
  "M09-reserve-strict": ("status = totalEntries >= reserveEntries ? Status.NftWon : Status.CashWon;",
      "status = totalEntries > reserveEntries ? Status.NftWon : Status.CashWon;", "reserve exactly met yields CashWon"),
  "M10-no-runtime-quote-screen": ("if (_isProtocolDestination(to, address(prizeToken))) revert InvalidQuoteDestination(to);\n", "",
      "USDC payouts skip the runtime protocol-destination screen"),
  "M11-prize-release-no-flag": ("address recipient = sponsorRecipient;\n        prizeClaimed = true;", "address recipient = sponsorRecipient;",
      "releaseSponsorPrize does not record the claim"),
  "M12-callback-ignores-request-id": ("|| requestId != vrfRequestId ||", "||",
      "callback for a foreign request id is accepted"),
}
manifest = {}
for mid, (old, new, desc) in M.items():
    d = os.path.join(OUT, mid, "src")
    if os.path.exists(d):
        shutil.rmtree(os.path.join(OUT, mid))
    shutil.copytree(SRC, d)
    for root, _, files in os.walk(d):
        for f in files:
            os.chmod(os.path.join(root, f), 0o644)
    p = os.path.join(d, "Raffle.sol")
    s = open(p).read()
    assert s.count(old) == 1, (mid, s.count(old))
    open(p, "w").write(s.replace(old, new))
    manifest[mid] = desc
json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w"), indent=2)
print("\n".join(f"{k}: {v}" for k, v in manifest.items()))
