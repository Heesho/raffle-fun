import { readFile } from "node:fs/promises";
import path from "node:path";

import {
  encodeDeployData,
  getAddress,
  keccak256,
  pad,
  type Abi,
  type Address,
  type Hex,
} from "viem";

import type { DeploymentRecord } from "./deployment-record.js";
import type { DeploymentValidationEvidence } from "./deployment-validation.js";

const REQUIRED_SOLC_LONG_VERSION = "0.8.36+commit.8a079791";

interface Artifact {
  readonly contractName: string;
  readonly sourceName: string;
  readonly abi: Abi;
  readonly bytecode: Hex;
  readonly deployedBytecode: Hex;
  readonly buildInfoId: string;
}

interface ImmutableReference {
  readonly start: number;
  readonly length: number;
}

interface BuildContractOutput {
  readonly evm: {
    readonly deployedBytecode: {
      readonly object: string;
      readonly immutableReferences: Readonly<
        Record<string, readonly ImmutableReference[]>
      >;
    };
  };
}

interface BuildInfo {
  readonly solcLongVersion: string;
  readonly userSourceNameMap: Readonly<Record<string, string>>;
  readonly input: {
    readonly settings: {
      readonly evmVersion?: unknown;
      readonly viaIR?: unknown;
      readonly optimizer?: {
        readonly enabled?: unknown;
        readonly runs?: unknown;
      };
    };
  };
}

interface BuildOutput {
  readonly output: {
    readonly contracts: Readonly<
      Record<string, Readonly<Record<string, BuildContractOutput>>>
    >;
    readonly sources: Readonly<Record<string, { readonly ast: unknown }>>;
  };
}

export async function loadDeploymentBuildEvidence(
  repositoryRoot: string,
  candidate: DeploymentRecord,
  vrfLinkToken: Address,
  sourceCommit: string,
  verifyPublishedSource: DeploymentValidationEvidence["verifyPublishedSource"],
): Promise<DeploymentValidationEvidence> {
  const contractsRoot = path.join(repositoryRoot, "packages", "contracts");
  const [factoryArtifact, raffleArtifact] = await Promise.all([
    loadArtifact(
      path.join(
        contractsRoot,
        "artifacts",
        "src",
        "RaffleFactory.sol",
        "RaffleFactory.json",
      ),
      "RaffleFactory",
      "src/RaffleFactory.sol",
    ),
    loadArtifact(
      path.join(contractsRoot, "artifacts", "src", "Raffle.sol", "Raffle.json"),
      "Raffle",
      "src/Raffle.sol",
    ),
  ]);

  const [factoryRuntime, raffleRuntime] = await Promise.all([
    materializeRuntime(contractsRoot, factoryArtifact, {
      quoteToken: candidate.quoteToken,
      vrfWrapper: candidate.vrfWrapper,
      protocolTreasury: candidate.protocolTreasury,
      raffleImplementation: candidate.raffleImplementation,
    }),
    materializeRuntime(contractsRoot, raffleArtifact, {
      factory: candidate.raffleFactory,
      quoteToken: candidate.quoteToken,
      i_linkToken: vrfLinkToken,
      i_vrfV2PlusWrapper: candidate.vrfWrapper,
    }),
  ]);

  const factoryDeploymentData = encodeDeployData({
    abi: factoryArtifact.abi,
    bytecode: factoryArtifact.bytecode,
    args: [
      getAddress(candidate.quoteToken),
      getAddress(candidate.vrfWrapper),
      getAddress(candidate.protocolTreasury),
    ],
  });

  return {
    sourceCommit,
    factoryDeploymentData,
    expectedRuntimeCodeHashes: {
      raffleFactory: keccak256(factoryRuntime),
      raffleImplementation: keccak256(raffleRuntime),
    },
    verifyPublishedSource,
  };
}

async function loadArtifact(
  artifactPath: string,
  expectedContractName: string,
  expectedSourceName: string,
): Promise<Artifact> {
  const value: unknown = JSON.parse(await readFile(artifactPath, "utf8"));
  if (!isObject(value))
    throw new Error(`Invalid Hardhat artifact at ${artifactPath}.`);
  if (
    value.contractName !== expectedContractName ||
    value.sourceName !== expectedSourceName
  ) {
    throw new Error(
      `Hardhat artifact identity does not match ${expectedSourceName}:${expectedContractName}.`,
    );
  }
  if (
    !Array.isArray(value.abi) ||
    !isHex(value.bytecode) ||
    !isHex(value.deployedBytecode) ||
    typeof value.buildInfoId !== "string"
  ) {
    throw new Error(`Hardhat artifact is incomplete at ${artifactPath}.`);
  }
  return value as unknown as Artifact;
}

async function materializeRuntime(
  contractsRoot: string,
  artifact: Artifact,
  immutableValues: Readonly<Record<string, string>>,
): Promise<Hex> {
  const buildInfoPath = path.join(
    contractsRoot,
    "artifacts",
    "build-info",
    `${artifact.buildInfoId}.json`,
  );
  const buildOutputPath = path.join(
    contractsRoot,
    "artifacts",
    "build-info",
    `${artifact.buildInfoId}.output.json`,
  );
  const [buildInfoValue, buildOutputValue]: [unknown, unknown] =
    await Promise.all([readJson(buildInfoPath), readJson(buildOutputPath)]);
  const buildInfo = buildInfoValue as BuildInfo;
  const buildOutput = buildOutputValue as BuildOutput;
  assertBuildSettings(buildInfo, artifact.contractName);

  const compilerSourceName = buildInfo.userSourceNameMap?.[artifact.sourceName];
  if (typeof compilerSourceName !== "string") {
    throw new Error(`Build info does not map ${artifact.sourceName}.`);
  }
  const contractOutput =
    buildOutput.output?.contracts?.[compilerSourceName]?.[
      artifact.contractName
    ];
  const sourceAst = buildOutput.output?.sources?.[compilerSourceName]?.ast;
  if (contractOutput === undefined || sourceAst === undefined) {
    throw new Error(
      `Build output is missing ${compilerSourceName}:${artifact.contractName}.`,
    );
  }

  const template = contractOutput.evm.deployedBytecode.object;
  if (
    `0x${template}`.toLowerCase() !== artifact.deployedBytecode.toLowerCase()
  ) {
    throw new Error(
      `${artifact.contractName} artifact/runtime template mismatch.`,
    );
  }

  let runtime = template;
  const consumedNames = new Set<string>();
  for (const [declarationId, references] of Object.entries(
    contractOutput.evm.deployedBytecode.immutableReferences,
  )) {
    let immutableName: string | undefined;
    for (const source of Object.values(buildOutput.output.sources)) {
      immutableName = findNodeNameById(source.ast, Number(declarationId));
      if (immutableName !== undefined) break;
    }
    if (
      immutableName === undefined ||
      immutableValues[immutableName] === undefined
    ) {
      throw new Error(
        `No release value supplied for immutable ${declarationId} (${immutableName ?? "unknown"}) in ${artifact.contractName}.`,
      );
    }
    consumedNames.add(immutableName);
    const replacement = pad(
      getAddress(immutableValues[immutableName] as Address),
      { size: 32 },
    ).slice(2);
    for (const reference of references) {
      if (reference.length !== 32) {
        throw new Error(
          `${artifact.contractName}.${immutableName} has a non-address immutable reference.`,
        );
      }
      const start = reference.start * 2;
      const end = start + reference.length * 2;
      runtime = `${runtime.slice(0, start)}${replacement}${runtime.slice(end)}`;
    }
  }
  const missingNames = Object.keys(immutableValues).filter(
    (name) => !consumedNames.has(name),
  );
  if (missingNames.length !== 0) {
    throw new Error(
      `${artifact.contractName} build output did not consume immutables: ${missingNames.join(", ")}.`,
    );
  }
  return `0x${runtime}` as Hex;
}

function assertBuildSettings(buildInfo: BuildInfo, contractName: string): void {
  const settings = buildInfo.input?.settings;
  if (
    buildInfo.solcLongVersion !== REQUIRED_SOLC_LONG_VERSION ||
    settings?.optimizer?.enabled !== true ||
    settings.optimizer.runs !== 200 ||
    settings.evmVersion !== "cancun" ||
    settings.viaIR === true
  ) {
    throw new Error(
      `${contractName} build info does not match solc ${REQUIRED_SOLC_LONG_VERSION}, optimizer 200, Cancun, no via-IR.`,
    );
  }
}

function findNodeNameById(
  value: unknown,
  targetId: number,
): string | undefined {
  if (Array.isArray(value)) {
    for (const item of value) {
      const match = findNodeNameById(item, targetId);
      if (match !== undefined) return match;
    }
    return undefined;
  }
  if (!isObject(value)) return undefined;
  if (value.id === targetId && typeof value.name === "string")
    return value.name;
  for (const item of Object.values(value)) {
    const match = findNodeNameById(item, targetId);
    if (match !== undefined) return match;
  }
  return undefined;
}

async function readJson(file: string): Promise<unknown> {
  return JSON.parse(await readFile(file, "utf8"));
}

function isHex(value: unknown): value is Hex {
  return typeof value === "string" && /^0x[0-9a-fA-F]*$/.test(value);
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
