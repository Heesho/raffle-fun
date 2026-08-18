import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

interface DeploymentRecord {
  readonly chainId: number;
  readonly deploymentTransactions: {
    readonly raffleFactory: { readonly blockNumber: number };
  };
  readonly raffleFactory: string;
}

const chainId = Number(process.argv[2]);
if (chainId !== 11_155_111 && chainId !== 1) {
  throw new Error("Usage: generate-manifest.ts <11155111|1>");
}

const packageDirectory = resolve(import.meta.dirname, "..");
const deploymentPath = resolve(
  packageDirectory,
  `../../deployments/${chainId}.json`,
);
const deployment = JSON.parse(
  await readFile(deploymentPath, "utf8"),
) as DeploymentRecord;
const network = chainId === 11_155_111 ? "sepolia" : "mainnet";
const template = await readFile(
  resolve(packageDirectory, "subgraph.yaml"),
  "utf8",
);
const generated = template
  .replaceAll("network: sepolia", `network: ${network}`)
  .replace(
    "source:\n      abi: RaffleFactory\n      startBlock: 0",
    `source:\n      address: "${deployment.raffleFactory}"\n      abi: RaffleFactory\n      startBlock: ${deployment.deploymentTransactions.raffleFactory.blockNumber}`,
  );

await writeFile(
  resolve(packageDirectory, "subgraph.generated.yaml"),
  generated,
);
