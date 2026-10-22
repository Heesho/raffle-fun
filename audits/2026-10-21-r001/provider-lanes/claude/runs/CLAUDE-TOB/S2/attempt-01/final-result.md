The entry-point report is at `TOB-S2-entry-point-analyzer.md`. It finds **19 state-changing entry points** across the five in-scope files: 18 on each raffle clone and one on the factory. The interfaces and the constants library add no callable functions.

| Category | Count | Entry points |
|---|---|---|
| Public | 9 | `createRaffle`, `buyEntries`, `requestDraw` (payable), `settleWinningTicket`, `releaseSponsorProceeds`, `releaseProtocolFees`, `releaseSponsorPrize`, `setApprovalForAll`, `receive` (always reverts) |
| Restricted to ticket owners | 6 | `redeemWinningTicket`, `refundTickets`, `approve`, `transferFrom`, both `safeTransferFrom` versions |
| Needs review | 1 | `enableRefunds` |
| Callable only by other contracts | 3 | `initialize` (factory), `onERC721Received` (the prize token, and only during raffle creation), `rawFulfillRandomWords` (the Chainlink randomness service) |

There is no administrator, owner, pause or upgrade function anywhere, which matches `DESIGN.md`.

**Points to review (not findings):**
- **Sponsor early close.** The sponsor can cancel a raffle before its end time, but only while it has no sales; the first purchase removes this permanently. `DESIGN.md` doesn't mention it, though the interface comments do.
- **Anyone can trigger payouts.** `DESIGN.md` says the sponsor and treasury "can claim", but in the code any address can trigger the sponsor, treasury and prize-return payouts. The recipients are fixed, so a third party only controls the timing.
- **Unsafe-address check runs only at the moment of use.** Raffle addresses are predictable in advance. A sponsor who sets their payout address to a raffle that doesn't exist yet passes every check at creation. Once that raffle exists, the sponsor's USDC can never be released, and anyone can push the prize NFT into the other raffle. I confirmed this with a test. Only the sponsor's own configuration can cause it, but it conflicts with the design rule that assets never move between raffles. USDC payouts re-check the address at payout time; NFT deliveries don't.
- **Prize token is trusted in practice.** Both the raffle's activation and the factory's escrow check rely on what the prize contract reports. `DESIGN.md` treats prize contracts as untrusted, while the interface comments assume they are honest.

**How it was checked:**
- **Code reading and Slither.** I read every function and followed each caller check through the inherited OpenZeppelin and Chainlink code. Slither's entry-point list was identical in two independent runs, and the compiled contract interface agreed with it.
- **Access-control tests.** I wrote 11 targeted tests for these checks, using simplified stand-ins for USDC, the prize NFT and the Chainlink service. All 11 pass. They confirm the checks as written in the source, not the behaviour of the real USDC or Chainlink contracts. The test code is included in the report's appendix.
- **No changes under `packages/`.** All builds ran on an identical copy in `/tmp/tob-s2-epa.KGv9n9/`. The source and dependency hashes are unchanged, and the report is the only new file in the working directory.