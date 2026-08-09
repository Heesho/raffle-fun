# Building the raffle.fun whitepaper

All deliverables regenerate from the Markdown sections in `source/sections/` and
the SVG diagrams in `assets/diagrams/`. The generated files are:

| File | What it is |
| --- | --- |
| `raffle-fun-whitepaper.pdf` | the primary deliverable |
| `raffle-fun-whitepaper.docx` | Word version, generated from the same source |
| `source/whitepaper.md` | the concatenated canonical Markdown (regenerated on every build) |
| `build/whitepaper.html` | the paged HTML the PDF is printed from |
| `build/diagrams-png/*.png` | rasterized diagrams used by the DOCX |

## Required software

- Google Chrome (the PDF is produced by Chrome's print engine; tested with 151).
  The build script expects it at
  `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`; edit `CHROME`
  in `source/build.py` for other platforms.
- Python 3.9+ with `pypdf` (`pip install pypdf`). Used for TOC page-number
  injection and PDF metadata.
- Node.js 18+ with the `docx` npm package (DOCX build only):
  `npm install docx` anywhere, then run the build with
  `NODE_PATH=<that>/node_modules`.
- Poppler (`brew install poppler`) for verification: `pdfinfo`, `pdffonts`,
  `pdftotext`, `pdftoppm`.

No internet connection is needed at build time: fonts (Nunito and Inter latin
variable subsets, SIL OFL 1.1) and the logo are vendored under `assets/`.

## Build the PDF

```bash
cd docs/whitepaper
python3 source/build.py
```

This concatenates `source/sections/*.md` into `source/whitepaper.md`, converts
the constrained Markdown dialect (documented at the top of `build.py`) into
`build/whitepaper.html` with every SVG inlined, prints it with headless Chrome
(`--generate-pdf-document-outline` produces the bookmarks), reads the outline
back with pypdf to fill in the table-of-contents page numbers, re-prints until
stable, and stamps the title/author/subject metadata into
`raffle-fun-whitepaper.pdf`.

`python3 source/build.py --html-only` regenerates just the HTML for quick
layout iteration (open `build/whitepaper.html` in Chrome and use print preview).

## Build the DOCX

```bash
cd docs/whitepaper
./source/render-diagrams.sh                 # SVG -> PNG via headless Chrome
NODE_PATH=/path/to/node_modules node source/build-docx.mjs
```

## Verify

```bash
cd docs/whitepaper
pdfinfo  raffle-fun-whitepaper.pdf                    # metadata + page count
pdffonts raffle-fun-whitepaper.pdf                    # every row must say emb=yes
pdftotext raffle-fun-whitepaper.pdf - | grep -c raffle   # text is searchable
pdftoppm -png -r 180 raffle-fun-whitepaper.pdf /tmp/wp-page   # render all pages
```

Inspect the rendered pages for clipping, bad breaks, and diagram legibility.
The build is deterministic apart from Chrome version differences in line
breaking, so re-rendering after edits and eyeballing changed pages is the
expected workflow.

## Editing guide

- Text lives in `source/sections/*.md`, in reading order by filename. The
  dialect (headings, tables, `:::callout`, `:::figure`, `:::part`, fenced code,
  page-break comments) is documented in `source/build.py`'s docstring.
- Never start a wrapped line with `NN. ` unless you want an ordered list.
- Use ASCII hyphens only; no em dashes or typographic quotes.
- Diagrams are hand-written SVGs in `assets/diagrams/` using the brand palette
  from `apps/web/src/app/globals.css`; marker IDs must stay unique per file
  because all SVGs are inlined into one HTML document.
- Design tokens for the page itself are in `source/print.css`; the cover,
  colophon, and disclaimer are in `source/template.html`.
- Wide tables: precede with `<!-- table:breakable -->` (may split across
  pages) or `<!-- table:breakable,small -->` (also drops the type size).

## Known platform notes

- The Chrome path and the `soffice`-free DOCX validation are macOS-specific;
  on Linux point `CHROME` at `google-chrome` and verify the DOCX with
  LibreOffice (`soffice --headless --convert-to pdf`).
- Chrome shrinks the whole document to fit if any element overflows the page
  width; the build avoids this, but if a future edit reintroduces it, the
  symptom is every page rendering at about two-thirds scale. Find the
  overflowing element (usually an unwrapped code span or an over-wide table)
  rather than compensating with page size.
- `pdftoppm` may warn about "Bad bounding box in Type 3 glyph"; it is harmless
  (a poppler quirk with Chrome's Type 3 font subsets).
