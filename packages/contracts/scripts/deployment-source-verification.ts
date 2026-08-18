import { getAddress, zeroAddress, type Address } from "viem";

import type { DeploymentRecord } from "./deployment-record.js";

const ETHERSCAN_V2_URL = "https://api.etherscan.io/v2/api";
const REQUIRED_COMPILER = "v0.8.36+commit.8a079791";

type Fetch = typeof globalThis.fetch;

interface EtherscanSourceRecord {
  readonly SourceCode?: unknown;
  readonly ABI?: unknown;
  readonly ContractName?: unknown;
  readonly CompilerVersion?: unknown;
  readonly CompilerType?: unknown;
  readonly OptimizationUsed?: unknown;
  readonly Runs?: unknown;
  readonly EVMVersion?: unknown;
  readonly Proxy?: unknown;
  readonly Implementation?: unknown;
  readonly SimilarMatch?: unknown;
}

/**
 * Builds an independent Etherscan V2 source-verification check for publication.
 * Candidate JSON fields are deliberately not consulted.
 */
export function createEtherscanSourceVerifier(
  apiKey: string,
  fetcher: Fetch = globalThis.fetch,
): (
  chainId: DeploymentRecord["chainId"],
  address: Address,
  expectedContractName: "RaffleFactory" | "Raffle",
) => Promise<void> {
  if (apiKey.trim() === "") {
    throw new Error(
      "ETHERSCAN_API_KEY is required for independent source verification.",
    );
  }

  return async (chainId, address, expectedContractName) => {
    const url = new URL(ETHERSCAN_V2_URL);
    url.searchParams.set("chainid", String(chainId));
    url.searchParams.set("module", "contract");
    url.searchParams.set("action", "getsourcecode");
    url.searchParams.set("address", getAddress(address));
    url.searchParams.set("apikey", apiKey);

    const response = await fetcher(url, {
      headers: { accept: "application/json" },
    });
    if (!response.ok) {
      throw new Error(
        `Etherscan source lookup for ${expectedContractName} failed with HTTP ${response.status}.`,
      );
    }

    const payload: unknown = await response.json();
    if (
      !isObject(payload) ||
      payload.status !== "1" ||
      !Array.isArray(payload.result)
    ) {
      throw new Error(
        `Etherscan did not confirm published source for ${expectedContractName} at ${address}.`,
      );
    }
    if (payload.result.length !== 1 || !isObject(payload.result[0])) {
      throw new Error(
        `Etherscan returned an unexpected source record for ${expectedContractName} at ${address}.`,
      );
    }

    const record = payload.result[0] as EtherscanSourceRecord;
    if (
      typeof record.SourceCode !== "string" ||
      record.SourceCode.trim() === ""
    ) {
      throw new Error(
        `Etherscan source is absent for ${expectedContractName} at ${address}.`,
      );
    }
    if (
      typeof record.ABI !== "string" ||
      record.ABI.trim() === "" ||
      record.ABI.toLowerCase().includes("not verified")
    ) {
      throw new Error(
        `Etherscan ABI is not verified for ${expectedContractName} at ${address}.`,
      );
    }
    if (record.ContractName !== expectedContractName) {
      throw new Error(
        `Etherscan contract name ${String(record.ContractName)} does not match ${expectedContractName}.`,
      );
    }
    if (
      record.CompilerType !== "solc" ||
      record.CompilerVersion !== REQUIRED_COMPILER
    ) {
      throw new Error(
        `Etherscan compiler ${String(record.CompilerType)} ${String(record.CompilerVersion)} does not match ${REQUIRED_COMPILER}.`,
      );
    }
    if (record.OptimizationUsed !== "1" || record.Runs !== "200") {
      throw new Error(
        `Etherscan optimizer settings for ${expectedContractName} do not match enabled/200.`,
      );
    }
    if (
      typeof record.EVMVersion !== "string" ||
      record.EVMVersion.toLowerCase() !== "cancun"
    ) {
      throw new Error(
        `Etherscan EVM version for ${expectedContractName} does not match Cancun.`,
      );
    }
    if (record.Proxy !== "0" || record.Implementation !== "") {
      throw new Error(
        `Etherscan identifies ${expectedContractName} at ${address} as a proxy; direct source verification is required.`,
      );
    }

    if (typeof record.SimilarMatch !== "string") {
      throw new Error(
        `Etherscan omitted exact-match status for ${expectedContractName} at ${address}.`,
      );
    }
    const similarMatch = record.SimilarMatch;
    if (similarMatch !== "" && getAddress(similarMatch) !== zeroAddress) {
      throw new Error(
        `Etherscan reports only a SimilarMatch for ${expectedContractName} at ${address}; an exact match is required.`,
      );
    }
  };
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
