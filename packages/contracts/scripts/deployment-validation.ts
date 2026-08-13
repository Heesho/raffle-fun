import {
  getAddress,
  parseAbi,
  zeroAddress,
  type Address,
  type PublicClient,
} from "viem";

import type { DeploymentRecord } from "./deployment-record.js";

const factoryAbi = parseAbi([
  "function quoteToken() view returns (address)",
  "function entropy() view returns (address)",
  "function callbackGasLimit() view returns (uint32)",
  "function protocolTreasury() view returns (address)",
  "function owner() view returns (address)",
  "function pendingOwner() view returns (address)",
]);
const lensAbi = parseAbi(["function factory() view returns (address)"]);
const quoteTokenAbi = parseAbi([
  "function decimals() view returns (uint8)",
  "function paused() view returns (bool)",
]);

const officialAddresses: Record<
  DeploymentRecord["chainId"],
  { quoteToken: Address; entropy: Address }
> = {
  8_453: {
    quoteToken: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    entropy: "0x6e7d74fA7d5C90FeF9F0512987605a6D546181bB",
  },
  84_532: {
    quoteToken: "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
    entropy: "0x41c9e39574F40Ad34c79f1C99B66A45eFB830d4c",
  },
};

export async function validateDeploymentOnchain(
  client: PublicClient,
  candidate: DeploymentRecord,
): Promise<void> {
  const actualChainId = await client.getChainId();
  if (actualChainId !== candidate.chainId) {
    throw new Error(
      `RPC chain ID ${actualChainId} does not match deployment chain ID ${candidate.chainId}.`,
    );
  }
  const latestBlock = await client.getBlockNumber();
  if (BigInt(candidate.deploymentBlock) > latestBlock) {
    throw new Error(
      `deploymentBlock ${candidate.deploymentBlock} is later than RPC head ${latestBlock}.`,
    );
  }

  const official = officialAddresses[candidate.chainId];
  assertAddress("quoteToken", candidate.quoteToken, official.quoteToken);
  assertAddress("entropy", candidate.entropy, official.entropy);

  for (const [label, address] of [
    ["quoteToken", candidate.quoteToken],
    ["entropy", candidate.entropy],
    ["raffleFactory", candidate.raffleFactory],
    ["raffleLens", candidate.raffleLens],
  ] as const) {
    const code = await client.getCode({ address: address as Address });
    if (code === undefined || code === "0x") {
      throw new Error(`${label} has no runtime bytecode at ${address}.`);
    }
  }

  const factory = candidate.raffleFactory as Address;
  const [
    quoteToken,
    entropy,
    callbackGasLimit,
    treasury,
    owner,
    pendingOwner,
    quoteTokenDecimals,
    quoteTokenPaused,
  ] = await Promise.all([
    client.readContract({
      address: factory,
      abi: factoryAbi,
      functionName: "quoteToken",
    }),
    client.readContract({
      address: factory,
      abi: factoryAbi,
      functionName: "entropy",
    }),
    client.readContract({
      address: factory,
      abi: factoryAbi,
      functionName: "callbackGasLimit",
    }),
    client.readContract({
      address: factory,
      abi: factoryAbi,
      functionName: "protocolTreasury",
    }),
    client.readContract({
      address: factory,
      abi: factoryAbi,
      functionName: "owner",
    }),
    client.readContract({
      address: factory,
      abi: factoryAbi,
      functionName: "pendingOwner",
    }),
    client.readContract({
      address: candidate.quoteToken as Address,
      abi: quoteTokenAbi,
      functionName: "decimals",
    }),
    client.readContract({
      address: candidate.quoteToken as Address,
      abi: quoteTokenAbi,
      functionName: "paused",
    }),
  ]);
  assertAddress("factory.quoteToken", quoteToken, candidate.quoteToken);
  assertAddress("factory.entropy", entropy, candidate.entropy);
  assertAddress(
    "factory.protocolTreasury",
    treasury,
    candidate.protocolTreasury,
  );
  if (callbackGasLimit !== candidate.callbackGasLimit) {
    throw new Error(
      `factory callbackGasLimit ${callbackGasLimit} does not match record ${candidate.callbackGasLimit}.`,
    );
  }
  if (quoteTokenDecimals !== 6) {
    throw new Error(
      `quote token decimals ${quoteTokenDecimals} do not match canonical USDC decimals 6.`,
    );
  }
  if (quoteTokenPaused) {
    throw new Error("quote token is paused at deployment validation time.");
  }

  const finalOwner = getAddress(candidate.finalFactoryOwner);
  const ownershipAccepted =
    getAddress(owner) === finalOwner && pendingOwner === zeroAddress;
  if (!ownershipAccepted) {
    throw new Error(
      `factory ownership has not been accepted by ${finalOwner}; pending handoff is not a publishable deployment state.`,
    );
  }
  if (candidate.chainId === 8_453) {
    const [ownerCode, treasuryCode] = await Promise.all([
      client.getCode({ address: finalOwner }),
      client.getCode({ address: candidate.protocolTreasury as Address }),
    ]);
    if (ownerCode === undefined || ownerCode === "0x") {
      throw new Error(
        "Base mainnet finalFactoryOwner must be a reviewed contract wallet.",
      );
    }
    if (treasuryCode === undefined || treasuryCode === "0x") {
      throw new Error(
        "Base mainnet protocolTreasury must be a reviewed contract wallet.",
      );
    }
    if (candidate.verificationStatus !== "verified") {
      throw new Error("Base mainnet records require verified source status.");
    }
  }

  const lensFactory = await client.readContract({
    address: candidate.raffleLens as Address,
    abi: lensAbi,
    functionName: "factory",
  });
  assertAddress("lens.factory", lensFactory, candidate.raffleFactory);
}

function assertAddress(label: string, actual: string, expected: string): void {
  if (getAddress(actual) !== getAddress(expected)) {
    throw new Error(`${label} ${actual} does not match expected ${expected}.`);
  }
}
