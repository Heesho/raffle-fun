#!/usr/bin/env node

import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../..");

/** Refuses to publish until every chapter has been migrated to the current Ethereum v1. */
function requireCurrentSectionSources() {
  const dir = resolve(root, "docs/whitepaper/source/sections");
  const corpus = readdirSync(dir)
    .filter((name) => name.endsWith(".md"))
    .map((name) => readFileSync(resolve(dir, name), "utf8"))
    .join("\n");

  const retiredTerms = [
    "Pyth Entropy",
    "RaffleLens",
    "Base Sepolia",
    "Base mainnet",
    "buyTickets",
    "ticketPrice",
    "minimumTickets",
    "winningTicketId",
    "sponsorCash",
    "Closed",
  ].filter((term) => corpus.includes(term));
  const missingCurrentMechanics = [
    ["Chainlink VRF", /Chainlink VRF/i],
    ["sequential range tickets", /sequential[^\n]*ticket|stored[^\n]*range/i],
    ["winningEntry", /winningEntry/],
    ["5% treasury / 95% result economics", /5%[^\n]*95%|95%[^\n]*5%/],
  ].filter(([, pattern]) => !pattern.test(corpus));

  if (retiredTerms.length === 0 && missingCurrentMechanics.length === 0) return;

  const problems = [
    ...retiredTerms.map((term) => `still mentions retired term "${term}"`),
    ...missingCurrentMechanics.map(([label]) => `does not describe ${label}`),
  ];
  throw new Error(
    [
      "Refusing to publish: the whitepaper chapters still describe a retired protocol design.",
      ...problems.map((problem) => `  - ${problem}`),
      "",
      "Rewrite the chapters against the current Solidity and docs/ before regenerating any output.",
      "See docs/WHITEPAPER.md for the full repair checklist.",
      "Do not publish the historical Markdown, figures, DOCX, or PDF as v1 documentation.",
    ].join("\n"),
  );
}

requireCurrentSectionSources();

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
