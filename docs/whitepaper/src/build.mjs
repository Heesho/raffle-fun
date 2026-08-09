#!/usr/bin/env node

import { execFileSync, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../..");
const chrome =
  process.env.CHROME ||
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const bundledPython = resolve(
  dirname(process.execPath),
  "../../python/bin/python3",
);
const pythonCandidates = [process.env.PYTHON, "python3", bundledPython].filter(
  Boolean,
);
const python = pythonCandidates.find((candidate) => {
  if (candidate.includes("/") && !existsSync(candidate)) return false;
  return (
    spawnSync(candidate, ["-c", "import pypdf"], { stdio: "ignore" }).status ===
    0
  );
});
if (!python) {
  throw new Error(
    "No Python interpreter with pypdf found. Set PYTHON or install pypdf.",
  );
}
process.env.PYTHON = python;

function run(command, args) {
  console.log(`$ ${command} ${args.join(" ")}`);
  execFileSync(command, args, { cwd: root, stdio: "inherit" });
}

if (process.env.npm_execpath) {
  run(process.execPath, [process.env.npm_execpath, "contracts:build"]);
} else {
  run("corepack", ["pnpm", "contracts:build"]);
}
run(process.execPath, ["docs/whitepaper/src/protocol-facts.mjs"]);
run(process.execPath, ["docs/whitepaper/src/generate-figures.mjs"]);
run(python, ["docs/whitepaper/source/build.py", "--candidate-only"]);

const dumped = execFileSync(
  chrome,
  [
    "--headless=new",
    "--disable-gpu",
    "--virtual-time-budget=5000",
    "--dump-dom",
    new URL("file://" + resolve(root, "docs/whitepaper/build/whitepaper.html"))
      .href,
  ],
  { encoding: "utf8", maxBuffer: 50_000_000 },
);
const overflow = dumped.match(/data-overflow-count="(\d+)"/);
if (!overflow) throw new Error("layout overflow check did not execute");
if (Number(overflow[1]) !== 0) {
  const elements =
    dumped.match(/data-overflow-elements="([^"]*)"/)?.[1] || "unknown";
  throw new Error(`horizontal layout overflow detected in ${elements}`);
}
console.log("Layout overflow check passed.");

run(process.execPath, [
  "docs/whitepaper/src/validate-pdf.mjs",
  "docs/whitepaper/build/candidate-stamped.pdf",
]);
run(python, ["docs/whitepaper/source/build.py", "--publish-candidate"]);
console.log("Whitepaper build, validation, and atomic publication completed.");
