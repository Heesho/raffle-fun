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
  },
  {
    id: "raffle-fun-explained",
    path: "docs/articles/raffle-fun-explained.md",
    kicker: "Explanation",
    who: "Anyone who knows NFTs but not Solidity",
  },
  {
    id: "raffle-fun-technical-whitepaper",
    path: "docs/whitepapers/raffle-fun-technical-whitepaper.md",
    kicker: "Technical reference",
    who: "Auditors, protocol engineers, integrators",
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
  --accent:#d31d8b; --indigo:#1e2a9b; --danger:#c8213f;
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

.cover{border-bottom:1.6pt solid var(--ink);padding-bottom:11pt;margin-bottom:16pt}
.brand{font-family:var(--display);font-weight:900;font-size:11pt;letter-spacing:-.01em;margin:0 0 14pt}
.brand b{color:var(--accent)}
.kicker{font-family:var(--mono);font-size:7pt;letter-spacing:.13em;text-transform:uppercase;
  color:var(--accent);margin:0 0 5pt}
h1.t{font-family:var(--display);font-weight:900;font-size:25pt;line-height:1.08;
  letter-spacing:-.02em;margin:0 0 10pt}
.meta{display:flex;flex-wrap:wrap;gap:3pt 20pt;font-size:8.2pt;color:var(--ink2);margin:0}
.meta b{font-family:var(--mono);font-size:6.8pt;letter-spacing:.09em;text-transform:uppercase;
  color:var(--ink3);font-weight:600;display:block}
.meta span{font-family:var(--mono)}
.flags{margin-top:9pt;display:flex;gap:5pt;flex-wrap:wrap}
.flag{font-family:var(--mono);font-size:6.8pt;letter-spacing:.05em;text-transform:uppercase;
  padding:2.5pt 5pt;border:.6pt solid var(--danger);color:var(--danger);border-radius:1.5pt}
.flag.n{border-color:var(--line-strong);color:var(--ink2);text-transform:none;letter-spacing:0}

h2{font-family:var(--display);font-weight:900;font-size:14pt;line-height:1.2;
  margin:19pt 0 5pt;padding-top:7pt;border-top:.5pt solid var(--line);
  break-after:avoid;break-inside:avoid}
h3{font-family:var(--display);font-weight:800;font-size:11pt;margin:13pt 0 3pt;
  break-after:avoid;break-inside:avoid}
h4{font-family:var(--display);font-weight:800;font-size:9.6pt;margin:11pt 0 2pt;break-after:avoid}
p,ul,ol{margin:0 0 7.5pt}
li{margin-bottom:2.5pt}
li>ul,li>ol{margin-top:2.5pt;margin-bottom:0}
ul,ol{padding-left:14pt}
hr{border:0;border-top:.5pt solid var(--line);margin:14pt 0}
code{font-family:var(--mono);font-size:8.4pt;background:var(--sunk);
  border:.4pt solid var(--line);border-radius:1.5pt;padding:.5pt 2pt}
pre{background:var(--sunk);border:.5pt solid var(--line);border-radius:2pt;
  padding:7pt 9pt;font-family:var(--mono);font-size:7.8pt;line-height:1.45;
  color:var(--ink2);white-space:pre-wrap;word-wrap:break-word;
  break-inside:avoid;margin:0 0 8pt}
pre code{background:none;border:0;padding:0;font-size:1em}
blockquote{margin:0 0 8pt;padding:7pt 10pt;background:var(--amber-wash);
  border:.5pt solid var(--line);border-left:2pt solid var(--amber);
  color:var(--ink2);break-inside:avoid}
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

figure.diagram{margin:10pt 0 12pt;text-align:center;break-inside:avoid}
figure.diagram svg{max-width:100%;max-height:200mm;height:auto;width:auto}
figure.diagram pre.mermaid{background:none;border:0;padding:0;margin:0}
</style></head><body>
<div class="cover">
  <p class="brand">raffle<b>.fun</b></p>
  <p class="kicker">${doc.kicker}</p>
  <h1 class="t">${doc.title}</h1>
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
