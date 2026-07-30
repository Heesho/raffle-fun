import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

interface DeploymentRecord {
  readonly chainId: number;
  readonly deploymentBlock: number;
  readonly raffleFactory: string;
}

const chainId = Number(process.argv[2]);
if (chainId !== 84_532 && chainId !== 8_453) {
  throw new Error("Usage: generate-manifest.ts <84532|8453>");
}

const packageDirectory = resolve(import.meta.dirname, "..");
const deploymentPath = resolve(
  packageDirectory,
  `../../deployments/${chainId}.json`,
);
const deployment = JSON.parse(
  await readFile(deploymentPath, "utf8"),
) as DeploymentRecord;
const network = chainId === 84_532 ? "base-sepolia" : "base";
const template = await readFile(
  resolve(packageDirectory, "subgraph.yaml"),
  "utf8",
);
const generated = template
  .replaceAll("network: base-sepolia", `network: ${network}`)
  .replace(
    "source:\n      abi: RaffleFactory\n      startBlock: 0",
    `source:\n      address: "${deployment.raffleFactory}"\n      abi: RaffleFactory\n      startBlock: ${deployment.deploymentBlock}`,
  );

await writeFile(
  resolve(packageDirectory, "subgraph.generated.yaml"),
  generated,
);
