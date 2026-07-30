import { readFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

import { createPublicClient, http, type Address } from "viem";

import {
  deploymentRecordSchema,
  writeDeploymentRecord,
} from "./deployment-record.js";

const inputPath = process.argv[2];
if (inputPath === undefined) {
  throw new Error(
    "Usage: pnpm deployment:write <candidate.json>; no address is inferred or defaulted.",
  );
}

const candidate = deploymentRecordSchema.parse(
  JSON.parse(await readFile(path.resolve(inputPath), "utf8")),
);
const rpcUrl =
  candidate.chainId === 84_532
    ? process.env.BASE_SEPOLIA_RPC_URL
    : process.env.BASE_RPC_URL;
if (rpcUrl === undefined) {
  throw new Error(
    "The matching network RPC URL is required for bytecode checks.",
  );
}

const client = createPublicClient({ transport: http(rpcUrl) });
for (const [label, address] of [
  ...candidate.verifiedQuoteTokens.map(
    (quoteToken, index) =>
      [`verifiedQuoteTokens[${index}]`, quoteToken] as const,
  ),
  ["entropy", candidate.entropy],
  ["raffleImplementation", candidate.raffleImplementation],
  ["raffleFactory", candidate.raffleFactory],
  ["raffleLens", candidate.raffleLens],
] as const) {
  const code = await client.getCode({ address: address as Address });
  if (code === undefined || code === "0x") {
    throw new Error(`${label} has no runtime bytecode at ${address}.`);
  }
}

const repositoryRoot = path.resolve(import.meta.dirname, "../../..");
const destination = await writeDeploymentRecord(candidate, repositoryRoot);
process.stdout.write(`Wrote verified deployment record: ${destination}\n`);
