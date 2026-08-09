#!/usr/bin/env node
/**
 * Build docs/whitepaper/raffle-fun-whitepaper.docx from the same Markdown
 * sections the PDF uses. Diagrams come from build/diagrams-png (run
 * render-diagrams.sh first). Requires the `docx` npm package.
 */
import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const docx = require("docx");
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow,
  TableCell, WidthType, ShadingType, AlignmentType, BorderStyle, ImageRun,
  Footer, PageNumber, TableOfContents, LevelFormat, PageBreak, ExternalHyperlink,
} = docx;

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(HERE, "..");
const PNG = path.join(ROOT, "build", "diagrams-png");

const INK = "10143a";
const INK2 = "454b78";
const INK3 = "676c94";
const NAVY = "1e2a9b";
const PINK = "b81478";
const FONT = "Inter";
const DISPLAY = "Nunito";
const MONO = "Menlo";

const CALLOUT = {
  sentence: ["In one sentence", "FDEAF6", PINK],
  example: ["Example", "E8F2FF", "1B5AA8"],
  why: ["Why this matters", "FFF7DC", "7A4F00"],
  enforce: ["What the contract enforces", "E3F7EE", "0D6B45"],
  noguarantee: ["What this does not guarantee", "FDEAEE", "C8213F"],
  hood: ["Under the hood", "F4F4FB", NAVY],
  risk: ["Important risk", "FDEAEE", "C8213F"],
  sponsor: ["For sponsors", "E9EEFC", NAVY],
  holder: ["For ticket holders", "E9EEFC", NAVY],
  note: ["Note", "F4F4FB", INK3],
};

// ------------------------------------------------------------ inline parsing
function inlineRuns(text, opts = {}) {
  const runs = [];
  const parts = text.split(/(`[^`]+`|\*\*[^*]+\*\*|\[[^\]]+\]\([^)\s]+\))/g);
  for (const part of parts) {
    if (!part) continue;
    if (part.startsWith("`") && part.endsWith("`") && part.length > 2) {
      runs.push(new TextRun({ text: part.slice(1, -1), font: MONO, size: opts.size ? opts.size - 2 : 18, color: opts.color || INK }));
    } else if (part.startsWith("**") && part.endsWith("**")) {
      runs.push(new TextRun({ text: part.slice(2, -2), bold: true, font: opts.font || FONT, size: opts.size || 20, color: opts.color || INK }));
    } else {
      const link = part.match(/^\[([^\]]+)\]\(([^)\s]+)\)$/);
      if (link) {
        runs.push(new ExternalHyperlink({
          link: link[2],
          children: [new TextRun({ text: link[1], font: opts.font || FONT, size: opts.size || 20, color: "1F6FD0", underline: {} })],
        }));
      } else {
        runs.push(new TextRun({ text: part, font: opts.font || FONT, size: opts.size || 20, color: opts.color || INK, bold: opts.bold }));
      }
    }
  }
  return runs;
}

const para = (text, o = {}) => new Paragraph({
  children: inlineRuns(text, o), spacing: { after: o.after ?? 140, line: 300 },
  ...(o.extra || {}),
});

// ------------------------------------------------------------- block parsing
const children = [];

function parseAttrs(header) {
  const attrs = {};
  for (const m of header.matchAll(/(\w+)="([^"]*)"/g)) attrs[m[1]] = m[2];
  return attrs;
}

function shadedCell(texts, fill) {
  return new Table({
    width: { size: 9360, type: WidthType.DXA },
    columnWidths: [9360],
    borders: {}, // default hairlines are fine
    rows: [new TableRow({
      children: [new TableCell({
        width: { size: 9360, type: WidthType.DXA },
        shading: { type: ShadingType.CLEAR, fill },
        margins: { top: 120, bottom: 120, left: 160, right: 160 },
        children: texts,
      })],
    })],
  });
}

function emitCallout(kind, body) {
  const [label, fill, color] = CALLOUT[kind] || CALLOUT.note;
  const inner = [
    new Paragraph({
      children: [new TextRun({ text: label.toUpperCase(), bold: true, font: FONT, size: 15, color })],
      spacing: { after: 80 },
    }),
  ];
  for (const line of joinParagraphs(body)) {
    if (line.startsWith("- ")) {
      inner.push(new Paragraph({ children: inlineRuns(line.slice(2), { size: 19 }), bullet: { level: 0 }, spacing: { after: 60 } }));
    } else {
      inner.push(new Paragraph({ children: inlineRuns(line, { size: 19 }), spacing: { after: 80 } }));
    }
  }
  children.push(shadedCell(inner, fill));
  children.push(new Paragraph({ spacing: { after: 60 }, children: [] }));
}

function joinParagraphs(lines) {
  const out = [];
  let cur = [];
  for (const l of lines) {
    const s = l.trim();
    if (!s) { if (cur.length) { out.push(cur.join(" ")); cur = []; } continue; }
    if (s.startsWith("- ")) { if (cur.length) { out.push(cur.join(" ")); cur = []; } out.push(s); continue; }
    if (out.length && out[out.length - 1].startsWith("- ") && /^[a-z]/.test(s) && !cur.length) {
      out[out.length - 1] += " " + s; continue;
    }
    cur.push(s);
  }
  if (cur.length) out.push(cur.join(" "));
  return out;
}

function emitTable(headerCells, rows) {
  const n = headerCells.length;
  const total = 9360;
  const w = Math.floor(total / n);
  const widths = Array(n).fill(w);
  widths[n - 1] = total - w * (n - 1);
  const mkCell = (text, isHeader, width) => new TableCell({
    width: { size: width, type: WidthType.DXA },
    shading: isHeader ? { type: ShadingType.CLEAR, fill: "E9EEFC" } : undefined,
    margins: { top: 60, bottom: 60, left: 100, right: 100 },
    children: [new Paragraph({
      children: inlineRuns(text.replace(/\[(yes|no)\]/g, "$1"), { size: 17, bold: isHeader, color: isHeader ? NAVY : INK }),
      spacing: { after: 0 },
    })],
  });
  children.push(new Table({
    width: { size: total, type: WidthType.DXA },
    columnWidths: widths,
    rows: [
      new TableRow({ tableHeader: true, children: headerCells.map((c) => mkCell(c, true, w)) }),
      ...rows.map((r) => new TableRow({ children: r.map((c, i) => mkCell(c, false, widths[i] || w)) })),
    ],
  }));
  children.push(new Paragraph({ spacing: { after: 120 }, children: [] }));
}

function emitFigure(attrs) {
  const name = path.basename(attrs.src, ".svg");
  const file = path.join(PNG, `${name}.png`);
  if (!fs.existsSync(file)) return;
  const buf = fs.readFileSync(file);
  // PNGs are rendered at 2x from a 1500px-wide wrapper; display at 6.5in wide.
  const sizeOf = (b) => ({ w: b.readUInt32BE(16), h: b.readUInt32BE(20) });
  const { w, h } = sizeOf(buf);
  const outW = 624; // points-ish px units used by docx transformation (6.5in * 96)
  const outH = Math.round((outW * h) / w);
  children.push(new Paragraph({
    children: [new TextRun({ text: `FIGURE ${attrs.num}  `, bold: true, color: PINK, font: FONT, size: 16 }),
      new TextRun({ text: attrs.title || "", bold: true, font: FONT, size: 16, color: INK })],
    spacing: { before: 160, after: 80 },
  }));
  children.push(new Paragraph({
    children: [new ImageRun({ type: "png", data: buf, transformation: { width: outW, height: outH } })],
    spacing: { after: 60 },
  }));
  if (attrs.caption) {
    children.push(new Paragraph({ children: inlineRuns(attrs.caption, { size: 16, color: INK3 }), spacing: { after: 200 } }));
  }
}

function convert(md) {
  const lines = md.split("\n");
  let i = 0;
  let paraBuf = [];
  const flush = () => {
    if (paraBuf.length) { children.push(para(paraBuf.join(" "))); paraBuf = []; }
  };
  while (i < lines.length) {
    const line = lines[i];
    const s = line.trim();

    if (s.startsWith("```")) {
      flush();
      const code = [];
      i += 1;
      while (i < lines.length && !lines[i].trim().startsWith("```")) { code.push(lines[i]); i += 1; }
      i += 1;
      children.push(shadedCell(code.map((c) => new Paragraph({
        children: [new TextRun({ text: c || " ", font: MONO, size: 16, color: INK })],
        spacing: { after: 20 },
      })), "F4F4FB"));
      children.push(new Paragraph({ spacing: { after: 120 }, children: [] }));
      continue;
    }

    if (s.startsWith(":::")) {
      flush();
      const header = s.slice(3).trim();
      const body = [];
      i += 1;
      let depth = 1;
      while (i < lines.length) {
        const t = lines[i].trim();
        if (t.startsWith(":::") && t.slice(3).trim()) depth += 1;
        else if (t === ":::") { depth -= 1; if (depth === 0) { i += 1; break; } }
        body.push(lines[i]);
        i += 1;
      }
      const name = header.split(/\s/)[0];
      const attrs = parseAttrs(header);
      if (name === "part") {
        children.push(new Paragraph({ children: [new PageBreak()] }));
        children.push(new Paragraph({
          children: [new TextRun({ text: attrs.no.toUpperCase(), bold: true, font: FONT, size: 22, color: PINK })],
          spacing: { before: 1200, after: 160 },
        }));
        children.push(new Paragraph({
          heading: HeadingLevel.HEADING_1,
          children: [new TextRun({ text: attrs.title, bold: true, font: DISPLAY, size: 56, color: INK })],
          spacing: { after: 200 },
        }));
        const desc = body.filter((l) => l.trim() && !l.trim().startsWith("- "));
        if (desc.length) children.push(para(desc.map((d) => d.trim()).join(" "), { size: 22, color: INK2, after: 300 }));
      } else if (name === "callout") {
        emitCallout(attrs.kind || "note", body);
      } else if (name === "figure") {
        emitFigure(attrs);
      } else if (name === "keep" ) {
        convert(body.join("\n"));
      } else if (name === "html") {
        const text = body.join("\n").replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
        if (text) {
          for (const chunk of body.join("\n").split(/<\/div>/)) {
            const t = chunk.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
            if (!t) continue;
            const isQ = /class="faq-q"/.test(chunk) || /check-title/.test(chunk);
            children.push(new Paragraph({
              children: [new TextRun({ text: t, bold: isQ, font: isQ ? DISPLAY : FONT, size: isQ ? 21 : 19, color: isQ ? NAVY : INK })],
              spacing: { before: isQ ? 160 : 0, after: 100 },
            }));
          }
        }
      }
      continue;
    }

    if (s === "<!-- pagebreak -->") { flush(); children.push(new Paragraph({ children: [new PageBreak()] })); i += 1; continue; }
    if (s.startsWith("<!--")) { i += 1; continue; }

    const h = s.match(/^(#{1,4})\s+(.*)$/);
    if (h) {
      flush();
      const level = h[1].length;
      let text = h[2].trim();
      if (level === 1) {
        let label = "";
        if (text.includes("|")) [label, text] = text.split("|").map((x) => x.trim());
        if (label) {
          children.push(new Paragraph({
            children: [new TextRun({ text: label.toUpperCase(), bold: true, font: FONT, size: 17, color: PINK })],
            spacing: { before: 360, after: 60 },
          }));
        }
        children.push(new Paragraph({
          heading: HeadingLevel.HEADING_1,
          children: [new TextRun({ text, bold: true, font: DISPLAY, size: 40, color: INK })],
          spacing: { after: 160 },
        }));
      } else {
        const sizes = { 2: 27, 3: 23, 4: 19 };
        children.push(new Paragraph({
          heading: level === 2 ? HeadingLevel.HEADING_2 : HeadingLevel.HEADING_3,
          children: [new TextRun({ text, bold: true, font: DISPLAY, size: sizes[level], color: INK })],
          spacing: { before: 220, after: 100 },
        }));
      }
      i += 1;
      continue;
    }

    if (s.startsWith("|") && lines[i + 1] && /^\|[\s:|-]+\|?\s*$/.test(lines[i + 1].trim())) {
      flush();
      const cells = (l) => l.trim().replace(/^\||\|$/g, "").split("|").map((c) => c.trim());
      const header = cells(line);
      i += 2;
      const rows = [];
      while (i < lines.length && lines[i].trim().startsWith("|")) { rows.push(cells(lines[i])); i += 1; }
      emitTable(header, rows);
      continue;
    }

    const li = s.match(/^([-*]|\d+\.)\s+(.*)$/);
    if (li) {
      flush();
      const ordered = /\d/.test(li[1][0]);
      let text = li[2];
      let j = i + 1;
      while (j < lines.length && /^\s{2,}\S/.test(lines[j]) && !/^\s*([-*]|\d+\.)\s/.test(lines[j])) {
        text += " " + lines[j].trim();
        j += 1;
      }
      children.push(new Paragraph({
        children: inlineRuns(text),
        ...(ordered ? { numbering: { reference: "ol", level: 0 } } : { bullet: { level: 0 } }),
        spacing: { after: 80, line: 290 },
      }));
      i = j;
      continue;
    }

    if (s === "---") { flush(); children.push(new Paragraph({ border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: "C9CDE4" } }, spacing: { after: 200 }, children: [] })); i += 1; continue; }
    if (s === "") { flush(); i += 1; continue; }
    paraBuf.push(s);
    i += 1;
  }
  flush();
}

// -------------------------------------------------------------- front matter
children.push(new Paragraph({ spacing: { before: 2400 }, children: [] }));
children.push(new Paragraph({
  children: [new TextRun({ text: "raffle.fun", bold: true, font: DISPLAY, size: 96, color: NAVY })],
  spacing: { after: 200 },
}));
children.push(new Paragraph({
  children: [new TextRun({ text: "A Whitepaper for Onchain NFT Raffles", bold: true, font: DISPLAY, size: 34, color: INK })],
  spacing: { after: 120 },
}));
children.push(para("How prize custody, ticket ownership, random selection, payouts, refunds, and recovery work.", { size: 22, color: INK2, after: 400 }));
children.push(para("Author: Heesho", { size: 22, bold: true, after: 80 }));
children.push(para("Version 1.0 | August 9, 2026 | Reviewed commit a2120f5e163dc3641d9864773febbfedca047edb", { size: 18, color: INK3, after: 80 }));
children.push(para("Target networks: Ethereum and Base. Undeployed and unaudited at the reviewed commit.", { size: 18, color: INK3, after: 400 }));
children.push(new Paragraph({ children: [new PageBreak()] }));
children.push(new Paragraph({
  heading: HeadingLevel.HEADING_1,
  children: [new TextRun({ text: "Contents", bold: true, font: DISPLAY, size: 40, color: INK })],
  spacing: { after: 200 },
}));
children.push(new TableOfContents("Contents", { hyperlink: true, headingStyleRange: "1-2" }));
children.push(new Paragraph({ children: [new PageBreak()] }));

// --------------------------------------------------------------------- body
const md = fs.readFileSync(path.join(HERE, "whitepaper.md"), "utf8");
convert(md);

const doc = new Document({
  creator: "Heesho",
  title: "raffle.fun - A Whitepaper for Onchain NFT Raffles",
  description: "How prize custody, ticket ownership, random selection, payouts, refunds, and recovery work in the raffle.fun protocol.",
  numbering: {
    config: [{
      reference: "ol",
      levels: [{ level: 0, format: LevelFormat.DECIMAL, text: "%1.", alignment: AlignmentType.LEFT }],
    }],
  },
  styles: { default: { document: { run: { font: FONT, size: 20, color: INK } } } },
  sections: [{
    properties: {
      page: {
        size: { width: 12240, height: 15840 },
        margin: { top: 1320, bottom: 1440, left: 1300, right: 1300 },
      },
    },
    footers: {
      default: new Footer({
        children: [new Paragraph({
          alignment: AlignmentType.RIGHT,
          children: [
            new TextRun({ text: "raffle.fun whitepaper  |  page ", font: FONT, size: 15, color: INK3 }),
            new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 15, color: INK3 }),
          ],
        })],
      }),
    },
    children,
  }],
});

const out = path.join(ROOT, "raffle-fun-whitepaper.docx");
Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(out, buf);
  console.log("OK:", out, buf.length, "bytes");
});
