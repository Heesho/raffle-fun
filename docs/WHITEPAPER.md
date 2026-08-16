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

## Pipeline status

The fact and figure generators have been repaired and now run against current Solidity:

```bash
pnpm --filter @raffle-fun/contracts compile   # artifacts must be current
pnpm docs:whitepaper:figures                   # regenerates all 21 figures
```

What was fixed:

- `src/protocol-facts.mjs` no longer parses the removed `ProtocolOwnedClaim` enum or
  requires `recoverProtocolOwnedClaim`. It now **asserts that selector stays absent**,
  validates `NFT_REDEMPTION_TIMEOUT` and the current deadline getters, and reports the
  corrected transfer-lock and three-origin refund model. It also derives a 72-day
  worst-case custody bound from the constants.
- `src/generate-figures.mjs` had four factually wrong elements, all corrected: a ticket
  transferred "mid-draw" (impossible under ES-02), a caption reading "Tickets never
  freeze: transfers stay open in every status", a `recoverProtocolOwnedClaim()` row in the
  claim-architecture figure, and an NFT-branch caption implying the sponsor and treasury
  are paid at resolution rather than on verified delivery.

## Publication is deliberately blocked

`pnpm docs:whitepaper` now refuses to publish, by design:

```text
Refusing to publish: docs/whitepaper/source/sections/ describes a superseded protocol.
  - still mentions "recoverProtocolOwnedClaim" (ES-01 deleted this function)
  - still mentions "ProtocolOwnedClaim" (ES-01 deleted this enum)
  - still mentions "transferable in every" (ES-02 locks transfers in Drawing)
  - never describes the NFT-delivery timeout (ES-03, the third refund origin)
```

Repairing the generators removed the accidental crash that previously stopped the build,
so `src/build.mjs` now carries an explicit guard instead. Without it the pipeline would
happily publish a polished PDF whose prose still describes the pre-2026-08-13 protocol,
which is worse than publishing nothing.

## Remaining work

`ETHSKILLS-REVIEW-2026-08-13.md:103-105` lists regenerating the long-form whitepaper and
diagrams as required before any onchain release. Archiving the stale outputs and repairing
the generators does **not** close that item. What remains:

1. ~~repair `src/protocol-facts.mjs`~~ — **done**;
2. **rewrite `docs/whitepaper/source/sections/*.md`** (2,619 lines) against
   [the fact registry](facts/raffle-fun-facts.md) — this is the bulk of the work and the
   only thing the publication guard is waiting on;
3. ~~update `src/generate-figures.mjs` for the current state machine~~ — **done**;
4. ~~correct `docs/whitepaper/README.md`~~ — **done**;
5. run `pnpm docs:whitepaper` and complete the visual review described in
   [`whitepaper/BUILD.md`](whitepaper/BUILD.md). The PDF validator requires 45-65 A4 pages,
   so step 2 must produce a document of comparable length to the archived one.
