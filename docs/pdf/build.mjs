#!/usr/bin/env node

/**
 * Builds one A4 PDF per public document from the canonical Markdown in `docs/`.
 *
 * The three documents are the published deliverable; this script exists so the PDFs are
 * regenerated from source rather than hand-exported, which is what keeps them from drifting
 * away from the repository. Mermaid fences are rendered to inline SVG in the same browser
 * that prints the page, so diagrams are real vectors with selectable text.
 *
 *   pnpm docs:pdf
 *
 * Requires a local Chrome. Override the path with CHROME=… when it is not installed at the
 * macOS default, matching `docs/whitepaper/src/build.mjs`.
 *
 * Chrome is driven straight over the DevTools Protocol using Node's built-in WebSocket.
 * A browser-automation library would be the obvious choice, but every current one pulls in
 * `extract-zip`, which carries an unpatched High advisory (GHSA-jmr9-qjv8-65gv, no release
 * above the vulnerable 2.0.1). Talking to Chrome directly keeps the dependency audit clean.
 */

import { spawn } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { Marked } from "marked";

/** Minimal DevTools Protocol client: launch Chrome, speak JSON over one WebSocket. */
async function launchChrome(executablePath) {
  const profile = mkdtempSync(join(tmpdir(), "raffle-pdf-"));
  const child = spawn(
    executablePath,
    [
      "--headless=new",
      "--disable-gpu",
      "--no-sandbox",
      "--font-render-hinting=none",
      "--remote-debugging-port=0",
      `--user-data-dir=${profile}`,
      "about:blank",
    ],
    { stdio: ["ignore", "pipe", "pipe"] },
  );

  const endpoint = await new Promise((ok, fail) => {
    let buffer = "";
    const timer = setTimeout(
      () => fail(new Error("Chrome did not report a DevTools endpoint")),
      30_000,
    );
    child.stderr.on("data", (chunk) => {
      buffer += chunk.toString();
      const found = buffer.match(/ws:\/\/[^\s]+/);
      if (found) {
        clearTimeout(timer);
        ok(found[0]);
      }
    });
    child.on("exit", (code) => {
      clearTimeout(timer);
      fail(new Error(`Chrome exited with code ${code} before starting`));
    });
  });

  const socket = new WebSocket(endpoint);
  await new Promise((ok, fail) => {
    socket.addEventListener("open", ok, { once: true });
    socket.addEventListener(
      "error",
      () => fail(new Error("DevTools socket failed")),
      {
        once: true,
      },
    );
  });

  let nextId = 0;
  const pending = new Map();
  const waiters = [];
  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (message.id !== undefined) {
      const entry = pending.get(message.id);
      if (!entry) return;
      pending.delete(message.id);
      message.error
        ? entry.fail(new Error(message.error.message))
        : entry.ok(message.result);
      return;
    }
    for (let i = waiters.length - 1; i >= 0; i -= 1) {
      if (waiters[i].match(message)) waiters.splice(i, 1)[0].ok(message);
    }
  });

  const send = (method, params = {}, sessionId) =>
    new Promise((ok, fail) => {
      const id = (nextId += 1);
      pending.set(id, { ok, fail });
      socket.send(JSON.stringify({ id, method, params, sessionId }));
    });

  const once = (match) => new Promise((ok) => waiters.push({ match, ok }));

  return {
    send,
    once,
    async close() {
      try {
        socket.close();
      } catch {}
      const exited = new Promise((ok) => child.once("exit", ok));
      child.kill();
      await exited;
      // Chrome can still be flushing its profile as it exits; losing a scratch directory
      // in the system temp dir is not worth failing a successful build over.
      try {
        rmSync(profile, {
          recursive: true,
          force: true,
          maxRetries: 5,
          retryDelay: 100,
        });
      } catch {}
    },
  };
}

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../..");
const outDir = resolve(root, "output/pdf");
const workDir = resolve(root, "docs/pdf/.build");

const factRegistry = readFileSync(
  resolve(root, "docs/facts/raffle-fun-facts.md"),
  "utf8",
);
if (
  /Historical snapshot|Pyth Entropy|RaffleLens|Base Sepolia/.test(factRegistry)
) {
  throw new Error(
    "Refusing to publish PDFs while the fact registry and technical whitepaper describe the retired protocol. See docs/WHITEPAPER.md.",
  );
}

const chrome =
  process.env.CHROME ||
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
if (!existsSync(chrome)) {
  throw new Error(
    `Chrome not found at ${chrome}. Install Chrome or set CHROME to its executable path.`,
  );
}

const docs = [
  {
    id: "raffle-fun-one-pager",
    path: "docs/one-pagers/raffle-fun.md",
    kicker: "Orientation",
    who: "Participants, sponsors, partners, press",
    lede: "Your NFT either sells at your price, or it earns while it waits.",
  },
  {
    id: "raffle-fun-explained",
    path: "docs/articles/raffle-fun-explained.md",
    kicker: "Explanation",
    who: "Anyone who knows NFTs but not Solidity",
    lede: "How an onchain raffle turns an unsold NFT into either a sale at your number or income while it waits.",
  },
  {
    id: "raffle-fun-technical-whitepaper",
    path: "docs/whitepapers/raffle-fun-technical-whitepaper.md",
    kicker: "Technical reference",
    who: "Auditors, protocol engineers, integrators",
    lede: "State machine, economics, invariants, threat model and integration surface for an immutable, administrator-free NFT raffle protocol.",
  },
];

/**
 * The commit the documents describe. This is deliberately read out of the fact registry
 * rather than hardcoded, so a stale SHA on a cover page is impossible.
 */
function protocolCommit() {
  const registry = readFileSync(
    resolve(root, "docs/facts/raffle-fun-facts.md"),
    "utf8",
  );
  const match = registry.match(/\*\*Registry commit\.\*\*\s*`([0-9a-f]{40})`/);
  if (!match) {
    throw new Error(
      "Could not read the registry commit from docs/facts/raffle-fun-facts.md",
    );
  }
  return match[1];
}

const escapeHtml = (value) =>
  value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

/** Inlines a repository SVG so the PDF carries real vectors rather than a broken link. */
function inlineSvg(relative, fromDir) {
  const file = resolve(root, fromDir, relative);
  if (!existsSync(file)) return null;
  let svg = readFileSync(file, "utf8").replace(/<\?xml[^>]*\?>/, "");
  const box = svg.match(/viewBox="0 0 ([\d.]+) ([\d.]+)"/);
  svg = svg.replace(/\sstyle="[^"]*"/, "");
  if (box) {
    svg = svg.replace(
      /<svg([^>]*?)\swidth="[^"]*"/,
      `<svg$1 width="${Math.round(+box[1])}" height="${Math.round(+box[2])}"`,
    );
  }
  return svg;
}

const brandMark = readFileSync(
  resolve(root, "apps/web/public/brand/logo-raffle-pink.png"),
).toString("base64");

function renderDocument(doc) {
  const raw = readFileSync(resolve(root, doc.path), "utf8");
  const title = (raw.match(/^#\s+(.+)$/m) || [, doc.id])[1].trim();

  const marked = new Marked({ gfm: true });
  const renderer = new marked.Renderer();

  renderer.code = function ({ text, lang }) {
    if (lang === "mermaid") {
      return `<figure class="diagram"><pre class="mermaid">${escapeHtml(text)}</pre></figure>`;
    }
    return `<pre><code>${escapeHtml(text)}</code></pre>`;
  };
  renderer.table = function (token) {
    return `<div class="tbl">${marked.Renderer.prototype.table.call(this, token)}</div>`;
  };
  renderer.image = function ({ href, text }) {
    const svg = inlineSvg(href, dirname(doc.path));
    if (!svg) return "";
    return `<figure class="plate">${svg}<figcaption>${text}</figcaption></figure>`;
  };
  renderer.link = function ({ href, tokens }) {
    const label = this.parser.parseInline(tokens);
    // Relative repository links cannot resolve inside a PDF; point them at the repository.
    const url =
      /\.md(#|$)/.test(href) && !/^https?:/.test(href)
        ? `https://github.com/Heesho/raffle-fun/blob/main/docs/${href.replace(/^(\.\.\/)+/, "")}`.replace(
            "/docs/docs/",
            "/docs/",
          )
        : href;
    return `<a href="${url}">${label}</a>`;
  };

  const html = marked
    .parse(raw, { renderer })
    .replace(/^\s*<h1[^>]*>[\s\S]*?<\/h1>/, "");
  return { ...doc, title, html };
}

const fontData = (file) =>
  readFileSync(
    resolve(root, "docs/whitepaper/assets/fonts", file),
    // The same locally licensed faces the whitepaper pipeline embeds.
  ).toString("base64");

const inter = fontData("inter-latin-var.woff2");
const nunito = fontData("nunito-latin-var.woff2");
const mermaidBundle = readFileSync(
  resolve(root, "node_modules/mermaid/dist/mermaid.min.js"),
  "utf8",
);

const documentHtml = (doc, commit) => `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>${doc.title}</title>
<style>
@font-face{font-family:"Inter var";src:url(data:font/woff2;base64,${inter}) format("woff2");font-weight:100 900}
@font-face{font-family:"Nunito var";src:url(data:font/woff2;base64,${nunito}) format("woff2");font-weight:200 1000}
:root{
  --ink:#10143a; --ink2:#454b78; --ink3:#676c94;
  --line:#dcdded; --line-strong:#c3c5dd; --sunk:#f4f4fb;
  --accent:#f033bb; --accent-deep:#c01a92; --navy:#16229b;
  --indigo:#1e2a9b; --danger:#c8213f;
  --amber:#7a4f00; --amber-wash:#fff5d6;
  --body:"Inter var",system-ui,sans-serif;
  --display:"Nunito var","Inter var",system-ui,sans-serif;
  --mono:"SF Mono",Menlo,Consolas,monospace;
}
@page{size:A4;margin:18mm 16mm 20mm}
*{box-sizing:border-box}
html,body{margin:0;padding:0}
body{font-family:var(--body);color:var(--ink);font-size:10.2pt;line-height:1.55;
  -webkit-print-color-adjust:exact;print-color-adjust:exact}
a{color:var(--indigo);text-decoration:none;border-bottom:.4pt solid var(--line-strong)}

/* ---- brand cover ----
   Matches the brand's actual hero surface, sampled from the social banner: off-white
   ground, #16229b navy display type, the pink ticket mark, and a soft pink/purple/blue
   glow low in the frame. Chrome cannot bleed into the printToPDF margins, so this is a
   rounded panel filling the text area; negative margins clip the wordmark instead. */
.cover{position:relative;overflow:hidden;break-after:page;
  border-radius:16pt;padding:20mm 18mm;min-height:250mm;background:#fbfbfb;
  border:.5pt solid #eceaf2;display:flex;flex-direction:column}
.cover::before{content:"";position:absolute;left:-12%;right:-12%;bottom:-16%;height:64%;
  background:
    radial-gradient(46% 62% at 28% 60%, rgba(240,51,187,.40) 0%, rgba(240,51,187,0) 70%),
    radial-gradient(44% 60% at 52% 76%, rgba(123,63,228,.38) 0%, rgba(123,63,228,0) 72%),
    radial-gradient(48% 62% at 76% 58%, rgba(59,139,234,.34) 0%, rgba(59,139,234,0) 72%)}
.mark{width:17mm;height:auto;display:block;margin-bottom:9mm;position:relative;z-index:1}
.brand{font-family:var(--display);font-weight:900;font-size:21pt;letter-spacing:-.03em;
  margin:0 0 10mm;color:var(--navy);position:relative;z-index:1}
.brand span{color:var(--accent)}
.kicker{font-family:var(--mono);font-size:7.5pt;letter-spacing:.2em;text-transform:uppercase;
  color:var(--accent);margin:0 0 4mm;position:relative;z-index:1}
h1.t{font-family:var(--display);font-weight:900;font-size:34pt;line-height:1.04;
  letter-spacing:-.03em;margin:0 0 6mm;color:var(--navy);max-width:142mm;
  position:relative;z-index:1}
.lede{font-size:12.5pt;line-height:1.42;color:var(--ink2);max-width:124mm;margin:0;
  position:relative;z-index:1}
.spacer{flex:1 1 auto;min-height:12mm}
.meta{display:flex;flex-wrap:wrap;gap:4mm 14mm;font-size:8.6pt;margin:0;color:var(--ink2);
  position:relative;z-index:1}
.meta b{font-family:var(--mono);font-size:6.6pt;letter-spacing:.13em;text-transform:uppercase;
  color:var(--ink3);font-weight:600;display:block;margin-bottom:1mm}
.meta span{font-family:var(--mono)}
.flags{margin-top:8mm;display:flex;gap:3mm;flex-wrap:wrap;position:relative;z-index:1}
.flag{font-family:var(--mono);font-size:7pt;letter-spacing:.06em;text-transform:uppercase;
  padding:2.4mm 4mm;border-radius:12pt;font-weight:600;
  background:#fff;border:.7pt solid var(--danger);color:var(--danger)}
.flag.n{border-color:var(--line-strong);color:var(--ink2);text-transform:none;letter-spacing:0}

h2{font-family:var(--display);font-weight:900;font-size:14pt;line-height:1.2;color:var(--navy);
  margin:19pt 0 5pt;padding-top:7pt;border-top:1.4pt solid var(--accent);
  break-after:avoid;break-inside:avoid}
h3{font-family:var(--display);font-weight:800;font-size:11pt;margin:13pt 0 3pt;color:var(--navy);
  break-after:avoid;break-inside:avoid}
h4{font-family:var(--display);font-weight:800;font-size:9.6pt;margin:11pt 0 2pt;break-after:avoid}
p,ul,ol{margin:0 0 7.5pt}
li{margin-bottom:2.5pt}
li>ul,li>ol{margin-top:2.5pt;margin-bottom:0}
ul,ol{padding-left:14pt}
hr{border:0;border-top:.5pt solid var(--line);margin:14pt 0}
code{font-family:var(--mono);font-size:8.4pt;background:#fdf0f9;color:var(--accent-deep);
  border:.4pt solid #f7d6ee;border-radius:3pt;padding:.5pt 2.4pt}
pre{background:var(--sunk);border:.5pt solid var(--line);border-radius:6pt;
  padding:7pt 9pt;font-family:var(--mono);font-size:7.8pt;line-height:1.45;
  color:var(--ink2);white-space:pre-wrap;word-wrap:break-word;
  break-inside:avoid;margin:0 0 8pt}
pre code{background:none;border:0;padding:0;font-size:1em}
blockquote{margin:0 0 8pt;padding:8pt 11pt;background:var(--amber-wash);
  border:.5pt solid var(--line);border-left:2.4pt solid var(--amber);
  border-radius:0 6pt 6pt 0;color:var(--ink2);break-inside:avoid}
blockquote p:last-child{margin-bottom:0}

.tbl{margin:0 0 9pt}
table{border-collapse:collapse;width:100%;font-size:8.2pt;font-variant-numeric:tabular-nums}
thead{display:table-header-group}
th{text-align:left;font-family:var(--mono);font-size:6.8pt;letter-spacing:.06em;
  text-transform:uppercase;color:var(--ink3);font-weight:600;
  border-bottom:.9pt solid var(--line-strong);padding:4pt 7pt 4pt 0;vertical-align:bottom}
td{border-bottom:.4pt solid var(--line);padding:4.5pt 7pt 4.5pt 0;
  vertical-align:top;color:var(--ink2)}
td:first-child,th:first-child{padding-left:0}
tr{break-inside:avoid}
td strong{color:var(--ink)}

figure.plate{margin:12pt 0 14pt;padding:9pt;text-align:center;break-inside:avoid;
  background:#fdfcff;border:.5pt solid var(--line);border-radius:8pt}
figure.plate svg{max-width:100%;max-height:176mm;height:auto;width:auto}
figure.plate figcaption{margin-top:7pt;font-size:7.6pt;color:var(--ink3);
  font-family:var(--body);text-align:center;line-height:1.4}
figure.diagram{margin:10pt 0 12pt;text-align:center;break-inside:avoid}
figure.diagram svg{max-width:100%;max-height:200mm;height:auto;width:auto}
figure.diagram pre.mermaid{background:none;border:0;padding:0;margin:0}
</style></head><body>
<div class="cover">
  <img class="mark" src="data:image/png;base64,${brandMark}" alt="">
  <p class="brand">raffle<span>.fun</span></p>
  <p class="kicker">${doc.kicker}</p>
  <h1 class="t">${doc.title}</h1>
  <p class="lede">${doc.lede}</p>
  <div class="spacer"></div>
  <dl class="meta">
    <div><b>Reader</b>${doc.who}</div>
    <div><b>Protocol commit</b><span>${commit.slice(0, 12)}</span></div>
  </dl>
  <div class="flags">
    <span class="flag">Not deployed</span>
    <span class="flag">Not independently audited</span>
    <span class="flag n">Pre-release</span>
  </div>
</div>
${doc.html}
<script>${mermaidBundle}</script>
<script>
  mermaid.initialize({ startOnLoad: false, theme: "neutral" });
  window.__diagrams = mermaid.run({ querySelector: "pre.mermaid" }).then(function () {
    // mermaid sizes its output only through a style attribute, so an SVG stripped of it
    // has no intrinsic height and collapses to nothing. Give each one explicit dimensions
    // from its viewBox and let the print stylesheet scale it down.
    document.querySelectorAll("figure.diagram svg").forEach(function (svg) {
      var box = (svg.getAttribute("viewBox") || "").split(/\\s+/);
      if (box.length === 4) {
        svg.setAttribute("width", Math.round(parseFloat(box[2])));
        svg.setAttribute("height", Math.round(parseFloat(box[3])));
      }
      svg.removeAttribute("style");
    });
    return document.querySelectorAll("figure.diagram svg").length;
  });
</script>
</body></html>`;

const commit = protocolCommit();
mkdirSync(outDir, { recursive: true });
mkdirSync(workDir, { recursive: true });

const MM = 1 / 25.4; // printToPDF takes inches

const browser = await launchChrome(chrome);

try {
  for (const entry of docs) {
    const doc = renderDocument(entry);
    const source = resolve(workDir, `${doc.id}.html`);
    writeFileSync(source, documentHtml(doc, commit));

    const { targetId } = await browser.send("Target.createTarget", {
      url: "about:blank",
    });
    const { sessionId } = await browser.send("Target.attachToTarget", {
      targetId,
      flatten: true,
    });

    await browser.send("Page.enable", {}, sessionId);
    const loaded = browser.once(
      (m) => m.method === "Page.loadEventFired" && m.sessionId === sessionId,
    );
    await browser.send("Page.navigate", { url: `file://${source}` }, sessionId);
    await loaded;

    // Resolves once every mermaid fence has been drawn and resized.
    const { result } = await browser.send(
      "Runtime.evaluate",
      {
        expression: "window.__diagrams",
        awaitPromise: true,
        returnByValue: true,
      },
      sessionId,
    );
    const drawn = result.value;
    const expected = (doc.html.match(/pre class="mermaid"/g) || []).length;
    if (drawn !== expected) {
      throw new Error(
        `${doc.id}: rendered ${drawn} of ${expected} mermaid diagrams`,
      );
    }

    const { data } = await browser.send(
      "Page.printToPDF",
      {
        printBackground: true,
        paperWidth: 210 * MM,
        paperHeight: 297 * MM,
        marginTop: 18 * MM,
        marginBottom: 20 * MM,
        marginLeft: 16 * MM,
        marginRight: 16 * MM,
        displayHeaderFooter: true,
        headerTemplate: "<div></div>",
        footerTemplate: `<div style="width:100%;margin:0 16mm;font-family:-apple-system,sans-serif;font-size:7pt;color:#676c94;display:flex;justify-content:space-between"><span>raffle.fun &middot; ${doc.title.replace(/&/g, "&amp;")}</span><span>Page <span class="pageNumber"></span> of <span class="totalPages"></span></span></div>`,
      },
      sessionId,
    );

    const target = resolve(outDir, `${doc.id}.pdf`);
    writeFileSync(target, Buffer.from(data, "base64"));
    await browser.send("Target.closeTarget", { targetId });

    const kb = Math.round(readFileSync(target).length / 1024);
    console.log(`${doc.id}.pdf  ${kb} KB  (${expected} diagrams)`);
  }
} finally {
  await browser.close();
}

console.log(
  `Wrote ${docs.length} PDFs to output/pdf for commit ${commit.slice(0, 7)}.`,
);
