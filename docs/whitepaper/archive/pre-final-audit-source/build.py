#!/usr/bin/env python3
"""Build the raffle.fun whitepaper PDF from Markdown sections.

Pipeline
--------
1. Concatenate ``sections/*.md`` (sorted) into ``whitepaper.md`` (canonical source).
2. Convert the constrained Markdown dialect into paged HTML using ``template.html``
   and ``print.css``, inlining every SVG diagram from ``../assets/diagrams``.
3. Print pass 1 with headless Chrome (``--generate-pdf-document-outline``).
4. Read the generated PDF outline with pypdf, map every chapter to its page
   number, inject the numbers into the table of contents, and re-print.
   Repeat until the mapping is stable (normally one extra pass).
5. Stamp PDF metadata (title, author, subject) with pypdf.

Markdown dialect (deliberately small and deterministic)
-------------------------------------------------------
- ``# 14 | Requesting the Draw`` chapter heading (h1). Left side becomes the
  small chapter label; ``# | Title`` renders without a label. ``## / ### / ####``
  are ordinary sections.
- ``<!-- h1continue -->`` before a chapter heading suppresses its forced page
  break.
- ``<!-- pagebreak -->`` forces a page break.
- ``<!-- table:breakable -->`` lets the next table split across pages.
- GitHub pipe tables with an alignment row; ``--:`` right-aligns a column.
- ``:::part id="part-i" no="Part I" title="The Idea"`` ... ``:::`` full-page part
  divider; body = description paragraph, then ``- N|Chapter title`` lines.
- ``:::callout kind="risk" title="Important risk"`` ... ``:::`` callout box.
- ``:::figure src="diagrams/x.svg" num="3" title="..." caption="..."`` figure.
- ``:::keep`` ... ``:::`` keeps a block on one page.
- ``:::html`` ... ``:::`` raw HTML passthrough.
- Inline: ``**bold**``, `` `code` ``, ``[text](url)``.

Usage
-----
    python3 build.py [--html-only]

Requires: Google Chrome, pypdf (``pip install pypdf``).
"""

from __future__ import annotations

import html
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DOCROOT = HERE.parent
SECTIONS = HERE / "sections"
BUILD = DOCROOT / "build"
ASSETS = DOCROOT / "assets"
FINAL_PDF = DOCROOT / "raffle-fun-whitepaper.pdf"

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

PDF_TITLE = "raffle.fun - A Whitepaper for Onchain NFT Raffles"
PDF_AUTHOR = "Heesho"
PDF_SUBJECT = (
    "How prize custody, ticket ownership, random selection, payouts, refunds, "
    "and recovery work in the raffle.fun protocol."
)

CALLOUT_LABELS = {
    "sentence": "In one sentence",
    "example": "Example",
    "why": "Why this matters",
    "enforce": "What the contract enforces",
    "noguarantee": "What this does not guarantee",
    "hood": "Under the hood",
    "risk": "Important risk",
    "sponsor": "For sponsors",
    "holder": "For ticket holders",
    "note": "Note",
}


def slugify(text: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return s[:60]


def parse_attrs(header: str) -> dict:
    return dict(re.findall(r'(\w+)="([^"]*)"', header))


def inline(text: str) -> str:
    """HTML-escape then apply inline markdown."""
    out = []
    # protect code spans before escaping the rest
    parts = re.split(r"(`[^`]+`)", text)
    for part in parts:
        if part.startswith("`") and part.endswith("`") and len(part) > 2:
            out.append(f"<code>{html.escape(part[1:-1])}</code>")
        else:
            esc = html.escape(part, quote=False)
            esc = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", esc)
            esc = re.sub(
                r"\[([^\]]+)\]\(([^)\s]+)\)",
                lambda m: f'<a href="{html.escape(m.group(2))}">{m.group(1)}</a>',
                esc,
            )
            out.append(esc)
    return "".join(out)


def load_svg(src: str) -> str:
    path = ASSETS / src
    svg = path.read_text()
    svg = re.sub(r"<\?xml[^>]*\?>", "", svg)
    svg = re.sub(r"<!DOCTYPE[^>]*>", "", svg)
    return svg.strip()


class Converter:
    def __init__(self):
        self.out: list[str] = []
        self.toc: list[dict] = []  # {kind: part|chapter, ...}
        self.h1_continue = False
        self.table_classes: list[str] = []

    # ---------------------------------------------------------------- blocks

    def convert(self, md: str) -> str:
        lines = md.split("\n")
        i = 0
        para: list[str] = []

        def flush_para():
            if para:
                self.out.append(f"<p>{inline(' '.join(para))}</p>")
                para.clear()

        while i < len(lines):
            line = lines[i]
            stripped = line.strip()

            if stripped.startswith("```"):
                flush_para()
                code_lines = []
                i += 1
                while i < len(lines) and not lines[i].strip().startswith("```"):
                    code_lines.append(lines[i])
                    i += 1
                i += 1  # closing fence
                self.out.append(
                    "<pre><code>" + html.escape("\n".join(code_lines)) + "</code></pre>"
                )
                continue

            if stripped.startswith(":::"):
                flush_para()
                i = self.block_directive(lines, i)
                continue

            if stripped == "<!-- pagebreak -->":
                flush_para()
                self.out.append('<div class="pagebreak"></div>')
                i += 1
                continue
            if stripped == "<!-- h1continue -->":
                self.h1_continue = True
                i += 1
                continue
            m_table = re.match(r"^<!-- table:([a-z,]+) -->$", stripped)
            if m_table:
                self.table_classes = m_table.group(1).split(",")
                i += 1
                continue
            if stripped.startswith("<!--"):
                i += 1
                continue

            m = re.match(r"^(#{1,4})\s+(.*)$", line)
            if m:
                flush_para()
                self.heading(len(m.group(1)), m.group(2).strip())
                i += 1
                continue

            if stripped.startswith("|") and i + 1 < len(lines) and re.match(
                r"^\|[\s:|-]+\|?\s*$", lines[i + 1].strip()
            ):
                flush_para()
                i = self.table(lines, i)
                continue

            if re.match(r"^[-*]\s+", stripped) or re.match(r"^\d+\.\s+", stripped):
                flush_para()
                i = self.list_block(lines, i)
                continue

            if stripped == "---":
                flush_para()
                self.out.append("<hr>")
                i += 1
                continue

            if stripped == "":
                flush_para()
                i += 1
                continue

            para.append(stripped)
            i += 1

        flush_para()
        return "\n".join(self.out)

    def heading(self, level: int, text: str):
        if level == 1:
            if "|" in text:
                label, title = [p.strip() for p in text.split("|", 1)]
            else:
                label, title = "", text
            slug = "c-" + slugify(title)
            cls = ' class="h1-continue"' if self.h1_continue else ""
            self.h1_continue = False
            chip = f'<span class="chapno">{html.escape(label)}</span>' if label else ""
            self.out.append(f'<h1 id="{slug}"{cls}>{chip}{inline(title)}</h1>')
            self.toc.append(
                {"kind": "chapter", "no": label, "title": title, "slug": slug,
                 "outline": (label or "") + title}
            )
        else:
            slug = "s-" + slugify(text)
            self.out.append(f"<h{level} id=\"{slug}\">{inline(text)}</h{level}>")

    def table(self, lines, i) -> int:
        header = [c.strip() for c in lines[i].strip().strip("|").split("|")]
        align_cells = [c.strip() for c in lines[i + 1].strip().strip("|").split("|")]
        aligns = ["num" if c.endswith(":") and c.startswith("-") else "" for c in align_cells]
        rows = []
        i += 2
        while i < len(lines) and lines[i].strip().startswith("|"):
            rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
            i += 1
        cls = f' class="{" ".join(self.table_classes)}"' if self.table_classes else ""
        self.table_classes = []
        parts = [f"<table{cls}><thead><tr>"]
        for j, cell in enumerate(header):
            a = f' class="num"' if j < len(aligns) and aligns[j] else ""
            parts.append(f"<th{a}>{inline(cell)}</th>")
        parts.append("</tr></thead><tbody>")
        for row in rows:
            parts.append("<tr>")
            for j, cell in enumerate(row):
                a = f' class="num"' if j < len(aligns) and aligns[j] else ""
                cell_html = inline(cell)
                cell_html = cell_html.replace("[yes]", '<span class="yes">yes</span>')
                cell_html = cell_html.replace("[no]", '<span class="no">no</span>')
                parts.append(f"<td{a}>{cell_html}</td>")
            parts.append("</tr>")
        parts.append("</tbody></table>")
        self.out.append("".join(parts))
        return i

    def list_block(self, lines, i) -> int:
        items: list[tuple[int, str, str]] = []  # (indent, marker, text)
        while i < len(lines):
            m = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", lines[i])
            if not m:
                if lines[i].strip() == "":
                    break
                # continuation line
                if items:
                    items[-1] = (items[-1][0], items[-1][1], items[-1][2] + " " + lines[i].strip())
                    i += 1
                    continue
                break
            items.append((len(m.group(1)), m.group(2), m.group(3)))
            i += 1

        def render(items, depth_indent):
            tag = "ol" if items and items[0][1][0].isdigit() else "ul"
            parts = [f"<{tag}>"]
            j = 0
            while j < len(items):
                indent, marker, text = items[j]
                sub = []
                k = j + 1
                while k < len(items) and items[k][0] > indent:
                    sub.append(items[k])
                    k += 1
                inner = inline(text)
                if sub:
                    inner += render(sub, sub[0][0])
                parts.append(f"<li>{inner}</li>")
                j = k
            parts.append(f"</{tag}>")
            return "".join(parts)

        self.out.append(render(items, items[0][0] if items else 0))
        return i

    def block_directive(self, lines, i) -> int:
        header = lines[i].strip()[3:].strip()
        body: list[str] = []
        i += 1
        depth = 1
        while i < len(lines):
            s = lines[i].strip()
            if s.startswith(":::") and s[3:].strip():
                depth += 1
            elif s == ":::":
                depth -= 1
                if depth == 0:
                    i += 1
                    break
            body.append(lines[i])
            i += 1
        name = header.split()[0] if header else ""
        attrs = parse_attrs(header)

        if name == "html":
            self.out.append("\n".join(body))
        elif name == "keep":
            self.out.append('<div class="keep">')
            sub = Converter()
            sub.toc = self.toc
            self.out.append(sub.convert("\n".join(body)))
            self.out.append("</div>")
        elif name == "callout":
            kind = attrs.get("kind", "note")
            label = attrs.get("title", CALLOUT_LABELS.get(kind, "Note"))
            self.out.append(
                f'<aside class="callout callout-{kind}">'
                f'<span class="callout-label">{html.escape(label)}</span>'
            )
            sub = Converter()
            sub.toc = self.toc
            self.out.append(sub.convert("\n".join(body)))
            self.out.append("</aside>")
        elif name == "figure":
            num = attrs.get("num", "")
            title = attrs.get("title", "")
            caption = attrs.get("caption", "")
            svg = load_svg(attrs["src"])
            cap = f"<figcaption>{inline(caption)}</figcaption>" if caption else ""
            self.out.append(
                "<figure>"
                f'<div class="fig-title"><span class="fig-no">Figure {num}</span>'
                f"{inline(title)}</div>{svg}{cap}</figure>"
            )
        elif name == "part":
            pid = attrs["id"]
            no = attrs["no"]
            title = attrs["title"]
            desc_lines = [l for l in body if l.strip() and not l.strip().startswith("- ")]
            chapters = [l.strip()[2:] for l in body if l.strip().startswith("- ")]
            chap_html = "".join(
                "<div><b>{}</b>{}</div>".format(*(c.split("|", 1)))
                for c in chapters
            )
            slug = "p-" + pid
            self.out.append(
                f'<section class="sheet part {pid}" id="{slug}">'
                f'<img class="part-ticket" src="../assets/logo-raffle-pink.png" alt="">'
                f'<div class="part-no">{html.escape(no)}</div>'
                f"<h2>{inline(title)}</h2>"
                f'<div class="part-desc">{inline(" ".join(d.strip() for d in desc_lines))}</div>'
                f'<div class="part-chapters">{chap_html}</div>'
                "</section>"
            )
            self.toc.append({"kind": "part", "no": no, "title": title, "slug": slug})
        else:
            raise ValueError(f"Unknown directive: {header!r}")
        return i


def build_toc_html(toc: list[dict], pages: dict[str, int] | None) -> str:
    """Two-column part-grouped table of contents."""
    blocks: list[str] = []
    current: list[str] = ['<ol class="toc-list">']
    for entry in toc:
        if entry["kind"] == "part":
            if current:
                blocks.append("".join(current) + "</ol>")
            current = [
                f'<div class="toc-part">{html.escape(entry["no"])}: '
                f'{html.escape(entry["title"])}</div><ol class="toc-list">'
            ]
        else:
            page = pages.get(entry["slug"], "") if pages else ""
            no = html.escape(entry["no"].replace("Chapter ", "").replace("Appendix ", ""))
            current.append(
                f'<li><span class="toc-no">{no}</span>'
                f'<span class="toc-title"><a href="#{entry["slug"]}">'
                f'{html.escape(entry["title"])}</a></span>'
                f'<span class="toc-dots"></span>'
                f'<span class="toc-page">{page}</span></li>'
            )
    if current:
        blocks.append("".join(current) + "</ol>")
    inner = "".join(f'<div class="toc-block">{b}</div>' for b in blocks)
    return f'<div class="toc-cols">{inner}</div>'


def render_html(pages: dict[str, int] | None) -> tuple[str, list[dict]]:
    md = "\n\n".join(
        p.read_text() for p in sorted(SECTIONS.glob("*.md"))
    )
    (HERE / "whitepaper.md").write_text(md)
    conv = Converter()
    body = conv.convert(md)
    toc_html = build_toc_html(conv.toc, pages)
    template = (HERE / "template.html").read_text()
    css = (HERE / "print.css").read_text()
    doc = (
        template.replace("/*CSS*/", css)
        .replace("<!--TOC-->", toc_html)
        .replace("<!--BODY-->", body)
    )
    BUILD.mkdir(exist_ok=True)
    (BUILD / "whitepaper.html").write_text(doc)
    return doc, conv.toc


def chrome_print(out_pdf: Path):
    subprocess.run(
        [
            CHROME,
            "--headless=new",
            "--disable-gpu",
            "--no-pdf-header-footer",
            "--generate-pdf-document-outline",
            "--virtual-time-budget=20000",
            f"--print-to-pdf={out_pdf}",
            (BUILD / "whitepaper.html").as_uri(),
        ],
        check=True,
        capture_output=True,
    )


def outline_pages(pdf: Path, toc: list[dict]) -> dict[str, int]:
    from pypdf import PdfReader

    reader = PdfReader(str(pdf))

    flat: list = []

    def walk(items):
        for it in items:
            if isinstance(it, list):
                walk(it)
            else:
                flat.append(it)

    walk(reader.outline)

    def norm(s: str) -> str:
        return re.sub(r"\s+", "", s).casefold()

    by_title: dict[str, int] = {}
    for dest in flat:
        try:
            page = reader.get_destination_page_number(dest) + 1
        except Exception:
            continue
        by_title.setdefault(norm(dest.title), page)

    pages: dict[str, int] = {}
    for entry in toc:
        if entry["kind"] == "chapter":
            key = norm(entry["outline"])
        else:
            key = norm(entry["title"])
        if key in by_title:
            pages[entry["slug"]] = by_title[key]
        else:
            for title, page in by_title.items():
                if title.startswith(key):
                    pages[entry["slug"]] = page
                    break
    return pages


def stamp_metadata(src: Path, dst: Path):
    from pypdf import PdfReader, PdfWriter

    reader = PdfReader(str(src))
    writer = PdfWriter(clone_from=reader)
    writer.add_metadata(
        {
            "/Title": PDF_TITLE,
            "/Author": PDF_AUTHOR,
            "/Subject": PDF_SUBJECT,
            "/Creator": "raffle.fun whitepaper build (Markdown + Chrome print)",
        }
    )
    with open(dst, "wb") as fh:
        writer.write(fh)


def main():
    html_only = "--html-only" in sys.argv

    _, toc = render_html(pages=None)
    if html_only:
        print(f"HTML written to {BUILD / 'whitepaper.html'}")
        return

    tmp = BUILD / "pass.pdf"
    chrome_print(tmp)
    pages = outline_pages(tmp, toc)
    for attempt in range(3):
        render_html(pages=pages)
        chrome_print(tmp)
        new_pages = outline_pages(tmp, toc)
        if new_pages == pages:
            break
        pages = new_pages

    missing = [e["title"] for e in toc if e["kind"] == "chapter" and e["slug"] not in pages]
    if missing:
        print(f"WARNING: no outline page found for: {missing}")

    stamp_metadata(tmp, FINAL_PDF)

    from pypdf import PdfReader

    n = len(PdfReader(str(FINAL_PDF)).pages)
    print(f"OK: {FINAL_PDF} ({n} pages)")


if __name__ == "__main__":
    main()
