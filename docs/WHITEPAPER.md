# raffle.fun whitepaper — moved

The long-form whitepaper that used to live at this path has been **archived**. It was
generated from a source tree that predates the current security model, and it should not be
used for deployment, integration, or transaction decisions.

## Read these instead

| Document | For |
| --- | --- |
| [One-pager](one-pagers/raffle-fun.md) | Understand the protocol in about two minutes |
| [Plain-language article](articles/raffle-fun-explained.md) | The complete sponsor and buyer experience, no Solidity required |
| [Technical whitepaper](whitepapers/raffle-fun-technical-whitepaper.md) | Auditors, protocol engineers, researchers, integrators |
| [Fact registry](facts/raffle-fun-facts.md) | The claim-by-claim source of truth behind all three, with contract, function, and test citations |

All four describe commit `5772e54ba89c06646815ed52a881cd8940f094ca`.

## What was archived, and why

| Archived file | Was |
| --- | --- |
| `whitepaper/archive/WHITEPAPER-superseded-2026-08-13.md` | `docs/WHITEPAPER.md` |
| `whitepaper/archive/raffle-fun-whitepaper-superseded-2026-08-13.pdf` | `docs/whitepaper/raffle-fun-whitepaper.pdf` and the byte-identical `output/pdf/raffle-fun-whitepaper.pdf` |
| `whitepaper/archive/raffle-fun-whitepaper-superseded-2026-08-13.docx` | `docs/whitepaper/raffle-fun-whitepaper.docx` |

All three describe commit `f165e4c1d8f5d093fe0a36094f79a29857c26286`. They predate three
changes made by the 2026-08-13 ETHSkills remediation
([`ETHSKILLS-REVIEW-2026-08-13.md`](../packages/contracts/audit/ETHSKILLS-REVIEW-2026-08-13.md)):

1. **`ES-01`** — the `ProtocolOwnedClaim` enum and the `recoverProtocolOwnedClaim`
   cross-raffle recovery dispatcher were **removed**. The archived documents describe them
   as shipped features. They are not.
2. **`ES-02`** — all ticket transfers now lock while randomness is pending, and the selected
   winning ticket stays locked after resolution.
3. **`ES-03`** — NFT-branch proceeds now stay escrowed until delivery is verified, and an
   undelivered NFT result falls back to full ticket refunds after 30 days. This is the third
   refund origin, which the archived documents do not have.

## The build pipeline does not currently run

`pnpm docs:whitepaper`, `pnpm docs:whitepaper:figures`, and `pnpm docs:whitepaper:docx` all
fail at their first step against current Solidity:

```text
Error: whitepaper fact validation failed: enum ProtocolOwnedClaim not found
    at buildFacts (docs/whitepaper/src/protocol-facts.mjs:138)
```

`docs/whitepaper/src/protocol-facts.mjs` still parses the removed `ProtocolOwnedClaim` enum
(line 138) and still requires `recoverProtocolOwnedClaim` in the compiled `Raffle` ABI
(line 167). Its required-constants list also omits `NFT_REDEMPTION_TIMEOUT`, so it has no
representation of the delivery-timeout refund path.

The pipeline itself is otherwise intact and worth keeping — a 21-figure SVG generator, an A4
print system, and a PDF validator covering fonts, internal links, bookmarks, horizontal
overflow, duplicate pages, and page size.

## Regenerating is still an open release blocker

`ETHSKILLS-REVIEW-2026-08-13.md:103-105` lists regenerating the long-form whitepaper and
diagrams as required before any onchain release. Archiving the stale outputs does **not**
close that item. Closing it requires, in order:

1. repair `docs/whitepaper/src/protocol-facts.mjs` — drop the removed enum and function from
   its required sets, and add `NFT_REDEMPTION_TIMEOUT`;
2. rewrite `docs/whitepaper/source/sections/*.md` against
   [the fact registry](facts/raffle-fun-facts.md);
3. update `docs/whitepaper/src/generate-figures.mjs` for the current state machine, which
   has three refund origins rather than two;
4. correct `docs/whitepaper/README.md`, which still documents the fact generator as parsing a
   `ProtocolOwnedClaim` enum;
5. run `pnpm docs:whitepaper` and complete the visual review described in
   [`whitepaper/BUILD.md`](whitepaper/BUILD.md).
