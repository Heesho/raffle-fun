// Generated scratch helper (S6 attempt-02): render Graphviz DOT files to SVG with the locally copied
// @viz-js/viz (Graphviz compiled to WebAssembly), because the native `dot` binary is not installed and no
// network installs are permitted. Usage: node render_dot.cjs <out-dir> <in1.dot> [in2.dot ...]
"use strict";
const fs = require("fs");
const path = require("path");
const vizPath = path.join(__dirname, "..", "tools", "viz", "dist", "viz.cjs");
const Viz = require(vizPath);

async function main() {
  const [outDir, ...inputs] = process.argv.slice(2);
  fs.mkdirSync(outDir, { recursive: true });
  const viz = await Viz.instance();
  console.log(`viz.js module: ${vizPath}`);
  console.log(`graphviz version (wasm): ${viz.graphvizVersion}`);
  let failures = 0;
  for (const input of inputs) {
    const dot = fs.readFileSync(input, "utf8");
    const result = viz.render(dot, { format: "svg", engine: "dot" });
    const base = path.basename(input).replace(/\.dot$/, "");
    for (const e of result.errors || []) console.log(`[${base}] ${e.level || "message"}: ${e.message}`);
    if (result.status !== "success") {
      failures += 1;
      console.log(`[${base}] FAILED`);
      continue;
    }
    const out = path.join(outDir, `${base}.svg`);
    fs.writeFileSync(out, result.output);
    console.log(`[${base}] wrote ${out} (${result.output.length} bytes)`);
  }
  process.exit(failures ? 1 : 0);
}

main().catch((err) => {
  console.error(err);
  process.exit(2);
});
