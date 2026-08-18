import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { format } from "prettier";

interface HardhatArtifact {
  readonly abi: readonly unknown[];
}

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const sdkDirectory = resolve(scriptDirectory, "..");
const repositoryRoot = resolve(sdkDirectory, "../..");
const checkOnly = process.argv.includes("--check");

const contracts = {
  raffle: resolve(
    repositoryRoot,
    "packages/contracts/artifacts/src/Raffle.sol/Raffle.json",
  ),
  raffleFactory: resolve(
    repositoryRoot,
    "packages/contracts/artifacts/src/RaffleFactory.sol/RaffleFactory.json",
  ),
} as const;

const artifacts = await Promise.all(
  Object.entries(contracts).map(async ([name, path]) => {
    const artifact = JSON.parse(
      await readFile(path, "utf8"),
    ) as HardhatArtifact;
    return [name, artifact.abi] as const;
  }),
);

const generatedSource = await format(
  [
    "/* This file is generated from Hardhat artifacts. Do not edit manually. */",
    ...artifacts.map(
      ([name, abi]) =>
        `export const ${name}Abi = ${JSON.stringify(abi, null, 2)} as const;`,
    ),
    "",
  ].join("\n\n"),
  { parser: "typescript" },
);

const generatedPath = resolve(sdkDirectory, "src/abis/generated.ts");
await verifyOrWrite(generatedPath, generatedSource);

for (const [name, abi] of artifacts) {
  const contractName = name === "raffle" ? "Raffle" : "RaffleFactory";
  const subgraphPath = resolve(
    repositoryRoot,
    `packages/subgraph/abis/${contractName}.json`,
  );
  await verifyOrWrite(subgraphPath, `${JSON.stringify(abi, null, 2)}\n`);
}

async function verifyOrWrite(path: string, content: string): Promise<void> {
  if (checkOnly) {
    let current: string;
    try {
      current = await readFile(path, "utf8");
    } catch {
      throw new Error(`Generated artifact is missing: ${path}`);
    }
    if (current !== content) {
      throw new Error(`Generated artifact drift detected: ${path}`);
    }
    return;
  }

  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, content);
}
