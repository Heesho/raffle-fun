# raffle.fun whitepaper source

This directory contains the reproducible source and production pipeline for the
raffle.fun public protocol whitepaper.

## Source layout

- `source/sections/`: canonical structured chapter source, ordered by filename.
- `source/template.html`: cover, review record, clickable contents frame, and body
  shell.
- `source/print.css`: A4 print system, local font embedding, running headers and
  footers, section dividers, tables, figures, and callouts.
- `src/protocol-facts.mjs`: Solidity and compiled-ABI fact generator.
- `src/generate-figures.mjs`: 21 SVG figure generator using compiled facts.
- `src/build.mjs`: root production orchestration.
- `src/validate-pdf.mjs`: PDF metadata, integrity, text, font, link, bookmark, image,
  duplicate-page, and page-size checks.
- `source/build-docx.mjs`: editable Word-companion generator using the same canonical
  Markdown and figures.
- `source/render-diagrams.sh`: local Chrome rasterization for DOCX figure embedding.
- `assets/`: canonical logo copies, licensed local fonts, and generated SVG figures.
- `FACT-CHECK.md`: claim-level provenance and contradiction register.
- `BUILD.md`: installation, build, validation, and visual-review commands.
- `references.md`: primary source register.
- `archive/`: preserved pre-final-audit uncommitted whitepaper source and PDF.

`docs/WHITEPAPER.md` is the generated single-file Markdown publication source. The
ordered section files remain the easier canonical editing format.

`pnpm docs:whitepaper:docx` creates the editable
`docs/whitepaper/raffle-fun-whitepaper.docx` companion. Its pagination is intentionally
independent of the authoritative A4 PDF.

## Fact generation

The facts script parses `RaffleConstants.sol`, parses the `IRaffle.Status` and
`ProtocolOwnedClaim` enums, and checks required functions in compiled Raffle, Factory,
and Lens artifacts. Worked examples are calculated with BigInt from those parsed
constants. The renderer replaces `{{FACT_TOKEN}}` placeholders and fails if any remain.

This avoids a second hand-copied economic constants table in the document pipeline.

## Figures

All 21 diagrams are generated as self-contained SVG with titles, descriptions, vector
text, consistent colors, and a symbol legend. Economic labels read the generated fact
object. The Markdown figure directives provide print titles, captions, and prose
context.

## Pagination

Chrome prints explicit A4 pages. Cover and part dividers use named bare pages. Chapter
headings and deliberate page-break directives control section starts. The first pass
creates the PDF outline; later passes map outline destinations to contents-page numbers
until stable.

## Validation guards

The pipeline checks:

- Solidity and ABI facts;
- unresolved tokens and placeholders;
- horizontal HTML overflow;
- 45-65 A4 pages;
- required metadata and searchable phrases;
- PDF reopen and optional qpdf structure;
- embedded fonts;
- duplicate page text;
- internal link targets, external URL syntax, PDF link annotations, and bookmarks;
- image inventory;
- atomic publication after all candidate checks pass.

Automated checks do not replace visual inspection. Render every page at about 190 DPI,
inspect the contact sheet, and inspect representative text-heavy, table-heavy, and
diagram-heavy pages at 100% and 150% zoom before release.

## Publishing behavior

`pnpm docs:whitepaper` writes a candidate only under the ignored build directory. It
publishes to `output/pdf/raffle-fun-whitepaper.pdf` and the working copy in this
directory only after the complete candidate validation succeeds. Existing archived
whitepaper work is never overwritten.
