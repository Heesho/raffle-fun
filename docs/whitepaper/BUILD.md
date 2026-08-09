# Building the raffle.fun whitepaper

## Required versions

- Node.js: repository range `>=22.13 <23`; workspace-pinned version `22.23.2`.
- pnpm: `11.18.0` through Corepack, as declared in `package.json`.
- Solidity: `0.8.36`, invoked by the contract build.
- Python 3 with `pypdf`.
- Google Chrome or Chromium with headless PDF output and document outlines. The macOS
  default is `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`.
- Poppler tools: `pdfinfo`, `pdffonts`, `pdftotext`, and `pdfimages`.
- Optional: `qpdf` for an additional structural check; the build records when it is
  unavailable and still reopens with pypdf plus Poppler.

The document uses no remote render assets. Nunito and Inter WOFF2 subsets are stored
under `docs/whitepaper/assets/fonts/` and licensed under SIL Open Font License 1.1.

## Install

```text
corepack enable
corepack pnpm install --frozen-lockfile
python3 -m pip install pypdf
```

On macOS, install optional PDF tools with Homebrew if missing:

```text
brew install poppler qpdf
```

## Build

```text
corepack pnpm docs:whitepaper
```

The command:

1. compiles the contract artifacts;
2. parses Solidity constants and enums and validates compiled ABIs;
3. generates worked arithmetic and 21 original SVG figures;
4. concatenates the structured Markdown sections into `docs/WHITEPAPER.md`;
5. renders self-contained HTML with local fonts and inline SVG;
6. performs a horizontal overflow guard;
7. prints iterative A4 PDF passes until the clickable contents-page numbers stabilize;
8. stamps title, author, subject, reviewed commit, review identity, and date metadata;
9. verifies page count, A4 dimensions, searchable text, placeholders, PDF reopen,
   duplicate page text, embedded fonts, links, bookmarks, and image inventory;
10. atomically publishes only the validated candidate.

Final outputs:

- `output/pdf/raffle-fun-whitepaper.pdf`
- `docs/whitepaper/raffle-fun-whitepaper.pdf`
- `docs/WHITEPAPER.md`

Temporary candidates, HTML, generated facts, validation reports, and rendered review
pages belong under the ignored `docs/whitepaper/build/` directory.

## Build the editable Word companion

```text
corepack pnpm docs:whitepaper:docx
```

This regenerates the contract-derived facts and 21 SVG figures, rasterizes the
figures locally with Chrome, and writes
`docs/whitepaper/raffle-fun-whitepaper.docx`. The DOCX uses US Letter pages so it can
be edited conveniently; the A4 PDF above remains the authoritative designed
publication. The released companion renders to 69 Letter pages with 21 embedded
figure images.

For visual QA, render the DOCX with the repository's document tooling or LibreOffice,
then render every resulting PDF page. The released companion was checked using the
bundled document renderer and Poppler; no blank, clipped, or split figure pages were
accepted.

## Generate facts and diagrams only

```text
corepack pnpm docs:whitepaper:figures
```

Equivalent direct commands:

```text
node docs/whitepaper/src/protocol-facts.mjs
node docs/whitepaper/src/generate-figures.mjs
```

## Manual PDF validation

```text
pdfinfo output/pdf/raffle-fun-whitepaper.pdf
qpdf --check output/pdf/raffle-fun-whitepaper.pdf
pdffonts output/pdf/raffle-fun-whitepaper.pdf
pdftotext output/pdf/raffle-fun-whitepaper.pdf -
pdfimages -list output/pdf/raffle-fun-whitepaper.pdf
node docs/whitepaper/src/validate-pdf.mjs output/pdf/raffle-fun-whitepaper.pdf
```

`qpdf` is optional in the scripted build but recommended for release validation.

## Render every page for visual review

```text
mkdir -p docs/whitepaper/build/pages
pdftoppm -r 190 -png output/pdf/raffle-fun-whitepaper.pdf docs/whitepaper/build/pages/page
```

Create a contact sheet with ImageMagick when available:

```text
magick montage docs/whitepaper/build/pages/page-*.png -thumbnail 220x -tile 5x -geometry +8+8 docs/whitepaper/build/contact-sheet.png
```

Record page dimensions:

```text
pdfinfo -f 1 -l 999 -box output/pdf/raffle-fun-whitepaper.pdf
```

## Regenerate from a clean checkout

1. use Node 22.23.2 and Corepack pnpm 11.18.0;
2. run the frozen-lockfile install;
3. ensure Chrome, Python pypdf, and Poppler are available;
4. run `corepack pnpm docs:whitepaper`;
5. compare the generated PDF hash only when the browser version and creation metadata
   are intentionally controlled, because PDF producer output and timestamps can vary.

## Operating-system caveats

- Set `CHROME=/absolute/path/to/chrome` if Chrome is not in the macOS default path.
- Set `PYTHON=/absolute/path/to/python3` if the default interpreter lacks pypdf.
- Linux Chromium may use a different executable name and PDF producer version.
- Fonts are local, but Chrome may represent variable-font subsets differently across
  releases. The validator requires embedding rather than a specific internal font name.
- A failed candidate or validation never replaces the last validated final PDF.
