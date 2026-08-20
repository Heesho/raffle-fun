import {
  getAddress,
  keccak256,
  parseAbi,
  type Address,
  type Hash,
  type Hex,
  type PublicClient,
} from "viem";

import type { DeploymentRecord } from "./deployment-record.js";

const factoryAbi = parseAbi([
  "function quoteToken() view returns (address)",
  "function vrfWrapper() view returns (address)",
  "function callbackGasLimit() view returns (uint32)",
  "function requestConfirmations() view returns (uint16)",
  "function raffleImplementation() view returns (address)",
  "function protocolTreasury() view returns (address)",
]);
const raffleImplementationAbi = parseAbi([
  "function ENTRY_PRICE() view returns (uint256)",
  "function factory() view returns (address)",
  "function quoteToken() view returns (address)",
  "function vrfWrapper() view returns (address)",
  "function getLinkToken() view returns (address)",
  "function callbackGasLimit() view returns (uint32)",
  "function requestConfirmations() view returns (uint16)",
  "function initialized() view returns (bool)",
  "function status() view returns (uint8)",
]);
const quoteTokenAbi = parseAbi([
  "function decimals() view returns (uint8)",
  "function paused() view returns (bool)",
]);
const vrfWrapperAbi = parseAbi([
  "function s_configured() view returns (bool)",
  "function s_disabled() view returns (bool)",
  "function s_vrfCoordinator() view returns (address)",
  "function link() view returns (address)",
  "function linkNativeFeed() view returns (address)",
  "function getConfig() view returns (int256,uint32,uint32,uint32,uint32,uint32,uint32,uint16,uint8,uint8,bytes32,uint8)",
  "function estimateRequestPriceNative(uint32 callbackGasLimit,uint32 numWords,uint256 requestGasPriceWei) view returns (uint256)",
]);
const vrfCoordinatorAbi = parseAbi([
  "function s_config() view returns (uint16 minimumRequestConfirmations,uint32 maxGasLimit,bool reentrancyLock,uint32 stalenessSeconds,uint32 gasAfterPaymentCalculation,uint32 fulfillmentFlatFeeNativePPM,uint32 fulfillmentFlatFeeLinkDiscountPPM,uint8 nativePremiumPercentage,uint8 linkPremiumPercentage)",
]);

const officialAddresses: Record<
  DeploymentRecord["chainId"],
  { quoteToken: Address; vrfWrapper: Address }
> = {
  1: {
    quoteToken: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    vrfWrapper: "0x02aae1A04f9828517b3007f83f6181900CaD910c",
  },
  11_155_111: {
    quoteToken: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
    vrfWrapper: "0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1",
  },
};

export interface DeploymentValidationEvidence {
  /** Commit whose freshly compiled Factory artifact produced `factoryDeploymentData`. */
  readonly sourceCommit: string;
  /** Exact Factory creation bytecode plus constructor arguments from the local release artifact. */
  readonly factoryDeploymentData: Hex;
  /** Candidate-specific runtime hashes materialized from the same local build's immutable references. */
  readonly expectedRuntimeCodeHashes: {
    readonly raffleFactory: Hash;
    readonly raffleImplementation: Hash;
  };
  /** Independent explorer/Sourcify lookup; a candidate record cannot self-attest verification. */
  readonly verifyPublishedSource: (
    chainId: DeploymentRecord["chainId"],
    address: Address,
    expectedContractName: "RaffleFactory" | "Raffle",
  ) => Promise<void>;
}

export async function validateDeploymentOnchain(
  client: PublicClient,
  candidate: DeploymentRecord,
  evidence: DeploymentValidationEvidence,
): Promise<void> {
  if (
    candidate.sourceCommit.toLowerCase() !== evidence.sourceCommit.toLowerCase()
  ) {
    throw new Error(
      `deployment sourceCommit ${candidate.sourceCommit} does not match the clean local release commit ${evidence.sourceCommit}.`,
    );
  }
  const actualChainId = await client.getChainId();
  if (actualChainId !== candidate.chainId) {
    throw new Error(
      `RPC chain ID ${actualChainId} does not match deployment chain ID ${candidate.chainId}.`,
    );
  }
  const validationBlockNumber = BigInt(candidate.validationBlock);
  const latestBlock = await client.getBlockNumber();
  if (validationBlockNumber > latestBlock) {
    throw new Error(
      `validationBlock ${candidate.validationBlock} is later than RPC head ${latestBlock}.`,
    );
  }
  const [finalizedBlock, validationBlock] = await Promise.all([
    client.getBlock({ blockTag: "finalized" }),
    client.getBlock({ blockNumber: validationBlockNumber }),
  ]);
  if (validationBlockNumber > finalizedBlock.number) {
    throw new Error(
      `validationBlock ${candidate.validationBlock} is later than finalized block ${finalizedBlock.number}.`,
    );
  }
  if (validationBlock.hash !== candidate.validationBlockHash) {
    throw new Error(
      `validation block hash ${validationBlock.hash} does not match record ${candidate.validationBlockHash}.`,
    );
  }

  const official = officialAddresses[candidate.chainId];
  assertAddress("quoteToken", candidate.quoteToken, official.quoteToken);
  assertAddress("vrfWrapper", candidate.vrfWrapper, official.vrfWrapper);

  const codeTargets = [
    ["quoteToken", candidate.quoteToken],
    ["vrfWrapper", candidate.vrfWrapper],
    ["raffleFactory", candidate.raffleFactory],
    ["raffleImplementation", candidate.raffleImplementation],
  ] as const;
  const runtimeCodes = await Promise.all(
    codeTargets.map(
      async ([label, address]) =>
        [
          label,
          await client.getCode({
            address: address as Address,
            blockNumber: validationBlockNumber,
          }),
        ] as const,
    ),
  );
  for (const [label, code] of runtimeCodes) {
    if (code === undefined || code === "0x") {
      const address = candidate[label];
      throw new Error(`${label} has no runtime bytecode at ${address}.`);
    }
    const actualCodeHash = keccak256(code);
    if (actualCodeHash !== candidate.runtimeCodeHashes[label]) {
      throw new Error(
        `${label} runtime hash ${actualCodeHash} does not match record ${candidate.runtimeCodeHashes[label]}.`,
      );
    }
    if (
      (label === "raffleFactory" || label === "raffleImplementation") &&
      actualCodeHash !== evidence.expectedRuntimeCodeHashes[label]
    ) {
      throw new Error(
        `${label} runtime hash ${actualCodeHash} does not match the freshly compiled local release artifact ${evidence.expectedRuntimeCodeHashes[label]}.`,
      );
    }
  }

  await validateDeploymentTransaction(
    client,
    candidate.deploymentTransactions.raffleFactory.hash as Hash,
    BigInt(candidate.deploymentTransactions.raffleFactory.blockNumber),
    candidate.raffleFactory,
    candidate.deployer,
    validationBlockNumber,
    "raffleFactory",
    evidence.factoryDeploymentData,
  );
  const factory = candidate.raffleFactory as Address;
  const [
    quoteToken,
    vrfWrapper,
    callbackGasLimit,
    requestConfirmations,
    raffleImplementation,
    treasury,
    quoteTokenDecimals,
    quoteTokenPaused,
    implementationFactory,
    implementationQuoteToken,
    implementationVrfWrapper,
    implementationLinkToken,
    implementationCallbackGasLimit,
    implementationRequestConfirmations,
    implementationEntryPrice,
    implementationInitialized,
    implementationStatus,
    wrapperConfigured,
    wrapperDisabled,
    wrapperCoordinator,
    wrapperLink,
    wrapperNativeFeed,
    wrapperConfig,
    estimatedNativeRequestPrice,
  ] = await Promise.all([
    client.readContract({
      address: factory,
      abi: factoryAbi,
      functionName: "quoteToken",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: factory,
      abi: factoryAbi,
      functionName: "vrfWrapper",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: factory,
      abi: factoryAbi,
      functionName: "callbackGasLimit",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: factory,
      abi: factoryAbi,
      functionName: "requestConfirmations",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: factory,
      abi: factoryAbi,
      functionName: "raffleImplementation",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: factory,
      abi: factoryAbi,
      functionName: "protocolTreasury",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.quoteToken as Address,
      abi: quoteTokenAbi,
      functionName: "decimals",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.quoteToken as Address,
      abi: quoteTokenAbi,
      functionName: "paused",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.raffleImplementation as Address,
      abi: raffleImplementationAbi,
      functionName: "factory",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.raffleImplementation as Address,
      abi: raffleImplementationAbi,
      functionName: "quoteToken",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.raffleImplementation as Address,
      abi: raffleImplementationAbi,
      functionName: "vrfWrapper",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.raffleImplementation as Address,
      abi: raffleImplementationAbi,
      functionName: "getLinkToken",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.raffleImplementation as Address,
      abi: raffleImplementationAbi,
      functionName: "callbackGasLimit",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.raffleImplementation as Address,
      abi: raffleImplementationAbi,
      functionName: "requestConfirmations",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.raffleImplementation as Address,
      abi: raffleImplementationAbi,
      functionName: "ENTRY_PRICE",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.raffleImplementation as Address,
      abi: raffleImplementationAbi,
      functionName: "initialized",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.raffleImplementation as Address,
      abi: raffleImplementationAbi,
      functionName: "status",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.vrfWrapper as Address,
      abi: vrfWrapperAbi,
      functionName: "s_configured",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.vrfWrapper as Address,
      abi: vrfWrapperAbi,
      functionName: "s_disabled",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.vrfWrapper as Address,
      abi: vrfWrapperAbi,
      functionName: "s_vrfCoordinator",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.vrfWrapper as Address,
      abi: vrfWrapperAbi,
      functionName: "link",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.vrfWrapper as Address,
      abi: vrfWrapperAbi,
      functionName: "linkNativeFeed",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.vrfWrapper as Address,
      abi: vrfWrapperAbi,
      functionName: "getConfig",
      blockNumber: validationBlockNumber,
    }),
    client.readContract({
      address: candidate.vrfWrapper as Address,
      abi: vrfWrapperAbi,
      functionName: "estimateRequestPriceNative",
      args: [candidate.callbackGasLimit, 1, 1_000_000_000n],
      blockNumber: validationBlockNumber,
    }),
  ]);
  assertAddress("factory.quoteToken", quoteToken, candidate.quoteToken);
  assertAddress("factory.vrfWrapper", vrfWrapper, candidate.vrfWrapper);
  assertAddress(
    "factory.raffleImplementation",
    raffleImplementation,
    candidate.raffleImplementation,
  );
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
  if (requestConfirmations !== candidate.requestConfirmations) {
    throw new Error(
      `factory requestConfirmations ${requestConfirmations} does not match record ${candidate.requestConfirmations}.`,
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
  assertAddress(
    "implementation.factory",
    implementationFactory,
    candidate.raffleFactory,
  );
  assertAddress(
    "implementation.quoteToken",
    implementationQuoteToken,
    candidate.quoteToken,
  );
  assertAddress(
    "implementation.vrfWrapper",
    implementationVrfWrapper,
    candidate.vrfWrapper,
  );
  assertAddress(
    "implementation.getLinkToken",
    implementationLinkToken,
    wrapperLink,
  );
  if (implementationCallbackGasLimit !== candidate.callbackGasLimit) {
    throw new Error(
      `implementation callbackGasLimit ${implementationCallbackGasLimit} does not match record ${candidate.callbackGasLimit}.`,
    );
  }
  if (implementationRequestConfirmations !== candidate.requestConfirmations) {
    throw new Error(
      `implementation requestConfirmations ${implementationRequestConfirmations} does not match record ${candidate.requestConfirmations}.`,
    );
  }
  if (implementationEntryPrice !== 1_000_000n) {
    throw new Error(
      `implementation ENTRY_PRICE ${implementationEntryPrice} does not match one six-decimal quote token.`,
    );
  }
  if (!implementationInitialized || implementationStatus !== 5) {
    throw new Error(
      "raffle implementation is not permanently initialized in its locked Refunding state.",
    );
  }
  if (!wrapperConfigured || wrapperDisabled) {
    throw new Error("Chainlink VRF wrapper is not configured and enabled.");
  }
  if (wrapperConfig[11] < 1) {
    throw new Error("Chainlink VRF wrapper does not support one random word.");
  }
  if (estimatedNativeRequestPrice === 0n) {
    throw new Error(
      "Chainlink VRF wrapper returned a zero native request price.",
    );
  }
  const dependencyCodeTargets = [
    ["VRF coordinator", wrapperCoordinator],
    ["LINK token", wrapperLink],
    ["LINK/native feed", wrapperNativeFeed],
  ] as const;
  for (const [label, address] of dependencyCodeTargets) {
    const code = await client.getCode({
      address,
      blockNumber: validationBlockNumber,
    });
    if (code === undefined || code === "0x") {
      throw new Error(`${label} has no runtime bytecode at ${address}.`);
    }
  }
  const coordinatorConfig = await client.readContract({
    address: wrapperCoordinator,
    abi: vrfCoordinatorAbi,
    functionName: "s_config",
    blockNumber: validationBlockNumber,
  });
  const minimumConfirmations = coordinatorConfig[0];
  const maximumCallbackGas = coordinatorConfig[1];
  const wrapperGasOverhead = wrapperConfig[4];
  const eip150CallbackOverhead =
    Math.floor(candidate.callbackGasLimit / 63) + 1;
  if (
    candidate.requestConfirmations < minimumConfirmations ||
    candidate.requestConfirmations > 200
  ) {
    throw new Error(
      `requestConfirmations ${candidate.requestConfirmations} are outside the live Chainlink range ${minimumConfirmations}..200.`,
    );
  }
  if (
    candidate.callbackGasLimit + wrapperGasOverhead + eip150CallbackOverhead >
    maximumCallbackGas
  ) {
    throw new Error(
      `callbackGasLimit ${candidate.callbackGasLimit} plus wrapper overhead ${wrapperGasOverhead} and EIP-150 overhead ${eip150CallbackOverhead} exceeds coordinator maximum ${maximumCallbackGas}.`,
    );
  }

  if (candidate.chainId === 1) {
    const treasuryCode = await client.getCode({
      address: candidate.protocolTreasury as Address,
      blockNumber: validationBlockNumber,
    });
    if (treasuryCode === undefined || treasuryCode === "0x") {
      throw new Error(
        "Ethereum mainnet protocolTreasury must be a reviewed contract wallet.",
      );
    }
  }

  await Promise.all([
    evidence.verifyPublishedSource(
      candidate.chainId,
      candidate.raffleFactory as Address,
      "RaffleFactory",
    ),
    evidence.verifyPublishedSource(
      candidate.chainId,
      candidate.raffleImplementation as Address,
      "Raffle",
    ),
  ]);
}

async function validateDeploymentTransaction(
  client: PublicClient,
  transactionHash: Hash,
  expectedDeploymentBlock: bigint,
  expectedContract: string,
  expectedDeployer: string,
  validationBlockNumber: bigint,
  label: string,
  expectedDeploymentData: Hex,
): Promise<void> {
  const [receipt, transaction] = await Promise.all([
    client.getTransactionReceipt({ hash: transactionHash }),
    client.getTransaction({ hash: transactionHash }),
  ]);
  const deployedContract = receipt.contractAddress;
  const successfulDeployment =
    receipt.status === "success" &&
    deployedContract !== null &&
    deployedContract !== undefined &&
    getAddress(deployedContract) === getAddress(expectedContract) &&
    receipt.blockNumber === expectedDeploymentBlock &&
    receipt.blockNumber <= validationBlockNumber &&
    transaction.to === null &&
    getAddress(transaction.from) === getAddress(expectedDeployer) &&
    transaction.input.toLowerCase() === expectedDeploymentData.toLowerCase();
  if (!successfulDeployment) {
    throw new Error(
      `${label} deployment transaction ${transactionHash} does not match the successful recorded deployment and exact locally compiled creation data.`,
    );
  }
}

function assertAddress(label: string, actual: string, expected: string): void {
  if (getAddress(actual) !== getAddress(expected)) {
    throw new Error(`${label} ${actual} does not match expected ${expected}.`);
  }
}
