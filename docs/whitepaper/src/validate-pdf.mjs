#!/usr/bin/env node

import { createHash } from "node:crypto";
import { execFileSync, spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../..");
const pdf = resolve(
  root,
  process.argv[2] || "docs/whitepaper/build/candidate-stamped.pdf",
);
const htmlPath = resolve(root, "docs/whitepaper/build/whitepaper.html");
const reportPath = resolve(
  root,
  "docs/whitepaper/build/validation-report.json",
);

function run(command, args) {
  return execFileSync(command, args, {
    encoding: "utf8",
    maxBuffer: 50_000_000,
  });
}

function exists(command) {
  return (
    spawnSync("sh", ["-c", `command -v ${command}`], {
      stdio: "ignore",
    }).status === 0
  );
}

function assert(condition, message) {
  if (!condition) throw new Error(`PDF validation failed: ${message}`);
}

const report = {
  pdf,
  pdfinfo: "",
  qpdf: "unavailable",
  fonts: {},
  text: {},
  images: {},
  links: {},
  duplicatePages: [],
};

const info = run("pdfinfo", [pdf]);
report.pdfinfo = info;
const pages = Number(info.match(/^Pages:\s+(\d+)/m)?.[1]);
assert(pages >= 45 && pages <= 65, `expected 45-65 pages, got ${pages}`);
assert(
  /^Title:\s+raffle\.fun - A Plain-English Whitepaper/m.test(info),
  "title metadata mismatch",
);
assert(/^Author:\s+Heesho/m.test(info), "author metadata mismatch");
const pageSize = info.match(/Page size:\s+([\d.]+) x ([\d.]+) pts \(A4\)/);
assert(pageSize, "page size is not identified as A4");
assert(
  Math.abs(Number(pageSize[1]) - 595.28) < 1 &&
    Math.abs(Number(pageSize[2]) - 841.89) < 1,
  `page dimensions are not A4: ${pageSize?.[1]} x ${pageSize?.[2]} pts`,
);

if (exists("qpdf")) {
  report.qpdf = run("qpdf", ["--check", pdf]);
} else {
  report.qpdf =
    "qpdf is not installed; pypdf reopen and Poppler checks were used";
}

const fonts = run("pdffonts", [pdf]);
const fontRows = fonts
  .split("\n")
  .slice(2)
  .map((line) => line.trim())
  .filter(Boolean);
assert(fontRows.length > 0, "no fonts reported");
const unembedded = fontRows.filter(
  (line) => !/\s+yes\s+yes\s+(yes|no)\s+\d+\s+\d+$/.test(line),
);
assert(unembedded.length === 0, `unembedded fonts: ${unembedded.join(" | ")}`);
report.fonts = { count: fontRows.length, allEmbedded: true, raw: fonts };

const text = run("pdftotext", [pdf, "-"]);
for (const phrase of [
  "raffle.fun",
  "constructor-deployed",
  "Tickets remain transferable",
  "Independent external audit: Not completed",
  "Not deployed and not authorized for user funds",
  "(uint256(randomNumber) % totalTickets) + 1",
]) {
  assert(text.includes(phrase), `searchable text is missing: ${phrase}`);
}
for (const phrase of ["{{", "TODO", "FIXME", "Lorem ipsum"]) {
  assert(!text.includes(phrase), `placeholder text found: ${phrase}`);
}
report.text = { characters: text.length, searchable: true };

const pageHashes = new Map();
for (let page = 1; page <= pages; page += 1) {
  const pageText = run("pdftotext", [
    "-f",
    String(page),
    "-l",
    String(page),
    pdf,
    "-",
  ])
    .replace(/\b\d+\s*\/\s*\d+\b/g, "")
    .replace(/\s+/g, " ")
    .trim();
  if (pageText.length < 60) continue;
  const hash = createHash("sha256").update(pageText).digest("hex");
  if (pageHashes.has(hash))
    report.duplicatePages.push([pageHashes.get(hash), page]);
  else pageHashes.set(hash, page);
}
assert(
  report.duplicatePages.length === 0,
  `duplicate page text at ${JSON.stringify(report.duplicatePages)}`,
);

const images = run("pdfimages", ["-list", pdf]);
report.images = { raw: images, listed: true };

const html = readFileSync(htmlPath, "utf8");
const ids = new Set(
  [...html.matchAll(/\sid="([^"]+)"/g)].map((match) => match[1]),
);
const hrefs = [...html.matchAll(/\shref="([^"]+)"/g)].map((match) => match[1]);
const brokenInternal = hrefs
  .filter((href) => href.startsWith("#"))
  .filter((href) => !ids.has(href.slice(1)));
assert(
  brokenInternal.length === 0,
  `broken internal links: ${brokenInternal.join(", ")}`,
);
for (const href of hrefs.filter((value) => /^https?:/.test(value)))
  new URL(href);

const python = process.env.PYTHON || "python3";
const annotationJson = run(python, [
  "-c",
  [
    "import json,sys",
    "from pypdf import PdfReader",
    "r=PdfReader(sys.argv[1])",
    "links=0",
    "for p in r.pages:",
    "  for a in p.get('/Annots',[]):",
    "    o=a.get_object()",
    "    links += 1 if o.get('/Subtype') == '/Link' else 0",
    "def count(items):",
    "  return sum(count(i) if isinstance(i,list) else 1 for i in items)",
    "print(json.dumps({'pages':len(r.pages),'links':links,'bookmarks':count(r.outline)}))",
  ].join("\n"),
  pdf,
]);
const annotationReport = JSON.parse(annotationJson);
assert(annotationReport.pages === pages, "pypdf page count mismatch");
assert(annotationReport.links > 0, "PDF has no link annotations");
assert(
  annotationReport.bookmarks >= 20,
  "PDF outline/bookmarks are incomplete",
);
report.links = {
  sourceHrefCount: hrefs.length,
  brokenInternal,
  pdfLinkAnnotations: annotationReport.links,
  bookmarks: annotationReport.bookmarks,
  externalSyntaxChecked: true,
  externalReachabilityChecked: false,
};

writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(
  `Validated ${pages} A4 pages, ${fontRows.length} embedded font rows, ${annotationReport.links} links, and ${annotationReport.bookmarks} bookmarks.`,
);
console.log(`Wrote ${reportPath}`);
