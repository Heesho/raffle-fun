import { readFile } from "node:fs/promises";

const report = await readFile(new URL("../lcov.info", import.meta.url), "utf8");

const totals = {
  branchesFound: sum("BRF"),
  branchesHit: sum("BRH"),
  functionsFound: sum("FNF"),
  functionsHit: sum("FNH"),
  linesFound: sum("LF"),
  linesHit: sum("LH"),
};

const lineCoverage = percentage(totals.linesHit, totals.linesFound, "lines");
const branchCoverage = percentage(
  totals.branchesHit,
  totals.branchesFound,
  "branches",
);
const functionCoverage = percentage(
  totals.functionsHit,
  totals.functionsFound,
  "functions",
);

process.stdout.write(
  `Production coverage: ${lineCoverage.toFixed(2)}% lines, ${branchCoverage.toFixed(2)}% branches, ${functionCoverage.toFixed(2)}% functions.\n`,
);

if (lineCoverage < 95 || branchCoverage < 90) {
  throw new Error(
    "Production coverage is below the required 95% line / 90% branch thresholds.",
  );
}

function sum(label) {
  return [...report.matchAll(new RegExp(`^${label}:(\\d+)$`, "gm"))].reduce(
    (total, match) => total + Number(match[1]),
    0,
  );
}

function percentage(hit, found, label) {
  if (found === 0) {
    throw new Error(`LCOV report contains no ${label}.`);
  }
  return (hit / found) * 100;
}
