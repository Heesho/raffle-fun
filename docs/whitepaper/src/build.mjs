#!/usr/bin/env node

import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../../..");

/**
 * Refuses to publish while the chapter sources still describe the pre-2026-08-13 model.
 *
 * The fact generator used to abort the build here by accident, because it parsed an enum
 * that ES-01 deleted. Repairing the generator removed that accidental brake, so the check
 * is now explicit. It runs before any toolchain detection so an author is never asked to
 * install Chrome or pypdf only to be told the content is stale.
 *
 * The prose must not name the removed recovery dispatcher, must not claim tickets are
 * transferable in every status (ES-02), and must describe the NFT-delivery timeout that
 * opens the third refund origin (ES-03).
 */
function requireCurrentSectionSources() {
  const dir = resolve(root, "docs/whitepaper/source/sections");
  const corpus = readdirSync(dir)
    .filter((name) => name.endsWith(".md"))
    .map((name) => readFileSync(resolve(dir, name), "utf8"))
    .join("\n");

  const removed = [
    ["recoverProtocolOwnedClaim", "ES-01 deleted this function"],
    ["ProtocolOwnedClaim", "ES-01 deleted this enum"],
    ["transferable in every", "ES-02 locks transfers in Drawing"],
  ].filter(([needle]) => corpus.includes(needle));

  const missingTimeout =
    !/nftRedemptionDeadline|NFT[- ]delivery timeout|NFT redemption timeout/i.test(
      corpus,
    );

  if (removed.length === 0 && !missingTimeout) return;

  const problems = [
    ...removed.map(([needle, why]) => `still mentions "${needle}" (${why})`),
    ...(missingTimeout
      ? [
          "never describes the NFT-delivery timeout (ES-03, the third refund origin)",
        ]
      : []),
  ];
  throw new Error(
    [
      "Refusing to publish: docs/whitepaper/source/sections/ describes a superseded protocol.",
      ...problems.map((problem) => `  - ${problem}`),
      "",
      "Rewrite the chapter sources against docs/facts/raffle-fun-facts.md first.",
      "See docs/WHITEPAPER.md for the full repair checklist.",
      "`pnpm docs:whitepaper:figures` still works and regenerates correct figures.",
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
