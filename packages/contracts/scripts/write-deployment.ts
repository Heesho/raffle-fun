import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { promisify } from "node:util";

import { createPublicClient, http, parseAbi, type Address } from "viem";

import { loadDeploymentBuildEvidence } from "./deployment-build-evidence.js";
import {
  deploymentRecordSchema,
  writeDeploymentRecord,
} from "./deployment-record.js";
import { createEtherscanSourceVerifier } from "./deployment-source-verification.js";
import { validateDeploymentOnchain } from "./deployment-validation.js";

const execFileAsync = promisify(execFile);
const vrfWrapperAbi = parseAbi(["function link() view returns (address)"]);

const inputPath = process.argv[2];
if (inputPath === undefined) {
  throw new Error(
    "Usage: pnpm deployment:write <candidate.json>; no address is inferred or defaulted.",
  );
}

const candidate = deploymentRecordSchema.parse(
  JSON.parse(await readFile(path.resolve(inputPath), "utf8")),
);
const repositoryRoot = path.resolve(import.meta.dirname, "../../..");
const contractsRoot = path.join(repositoryRoot, "packages", "contracts");
const [{ stdout: sourceCommitOutput }, { stdout: worktreeStatus }] =
  await Promise.all([
    execFileAsync("git", ["rev-parse", "HEAD"], {
      cwd: repositoryRoot,
      encoding: "utf8",
    }),
    execFileAsync(
      "git",
      ["status", "--porcelain=v1", "--untracked-files=all"],
      {
        cwd: repositoryRoot,
        encoding: "utf8",
      },
    ),
  ]);
const sourceCommit = sourceCommitOutput.trim();
if (worktreeStatus.trim() !== "") {
  throw new Error(
    "Deployment publication requires a completely clean worktree, including no untracked files.",
  );
}
if (candidate.sourceCommit.toLowerCase() !== sourceCommit.toLowerCase()) {
  throw new Error(
    `candidate sourceCommit ${candidate.sourceCommit} does not match clean HEAD ${sourceCommit}.`,
  );
}

const hardhatBinary = path.join(
  contractsRoot,
  "node_modules",
  ".bin",
  "hardhat",
);
await execFileAsync(hardhatBinary, ["compile", "--force"], {
  cwd: contractsRoot,
  encoding: "utf8",
  maxBuffer: 10 * 1024 * 1024,
});
const [{ stdout: postCompileCommit }, { stdout: postCompileStatus }] =
  await Promise.all([
    execFileAsync("git", ["rev-parse", "HEAD"], {
      cwd: repositoryRoot,
      encoding: "utf8",
    }),
    execFileAsync(
      "git",
      ["status", "--porcelain=v1", "--untracked-files=all"],
      {
        cwd: repositoryRoot,
        encoding: "utf8",
      },
    ),
  ]);
if (
  postCompileCommit.trim().toLowerCase() !== sourceCommit.toLowerCase() ||
  postCompileStatus.trim() !== ""
) {
  throw new Error(
    "Source commit or worktree changed while compiling release artifacts; aborting deployment publication.",
  );
}

const etherscanApiKey = process.env.ETHERSCAN_API_KEY;
if (etherscanApiKey === undefined) {
  throw new Error(
    "ETHERSCAN_API_KEY is required to verify published Factory and implementation source independently.",
  );
}
const rpcUrl =
  candidate.chainId === 11_155_111
    ? process.env.SEPOLIA_RPC_URL
    : process.env.ETHEREUM_RPC_URL;
if (rpcUrl === undefined) {
  throw new Error(
    "The matching network RPC URL is required for bytecode checks.",
  );
}

const client = createPublicClient({ transport: http(rpcUrl) });
const vrfLinkToken = await client.readContract({
  address: candidate.vrfWrapper as Address,
  abi: vrfWrapperAbi,
  functionName: "link",
  blockNumber: BigInt(candidate.validationBlock),
});
const evidence = await loadDeploymentBuildEvidence(
  repositoryRoot,
  candidate,
  vrfLinkToken,
  sourceCommit,
  createEtherscanSourceVerifier(etherscanApiKey),
);
await validateDeploymentOnchain(client, candidate, evidence);

const [{ stdout: finalCommit }, { stdout: finalStatus }] = await Promise.all([
  execFileAsync("git", ["rev-parse", "HEAD"], {
    cwd: repositoryRoot,
    encoding: "utf8",
  }),
  execFileAsync("git", ["status", "--porcelain=v1", "--untracked-files=all"], {
    cwd: repositoryRoot,
    encoding: "utf8",
  }),
]);
if (
  finalCommit.trim().toLowerCase() !== sourceCommit.toLowerCase() ||
  finalStatus.trim() !== ""
) {
  throw new Error(
    "Source commit or worktree changed during deployment validation; refusing to write a record.",
  );
}

const destination = await writeDeploymentRecord(candidate, repositoryRoot);
process.stdout.write(`Wrote verified deployment record: ${destination}\n`);
