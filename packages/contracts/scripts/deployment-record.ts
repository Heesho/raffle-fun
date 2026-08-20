import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

import { z } from "zod";

const address = z
  .string()
  .regex(/^0x[a-fA-F0-9]{40}$/)
  .refine(
    (value) => value !== "0x0000000000000000000000000000000000000000",
    "zero address is not a deployment value",
  );

// Persist hashes in the same canonical form returned by Ethereum JSON-RPC so
// record comparisons cannot fail solely because of mixed-case hex digits.
const bytes32 = z.string().regex(/^0x[a-f0-9]{64}$/);
const deploymentTransaction = z
  .object({
    hash: bytes32,
    blockNumber: z.number().int().positive(),
  })
  .strict();

export const deploymentRecordSchema = z
  .object({
    chainId: z.union([z.literal(11_155_111), z.literal(1)]),
    networkName: z.union([z.literal("sepolia"), z.literal("mainnet")]),
    deployedAt: z.iso.datetime(),
    validationBlock: z.number().int().positive(),
    validationBlockHash: bytes32,
    deploymentTransactions: z
      .object({
        raffleFactory: deploymentTransaction,
      })
      .strict(),
    runtimeCodeHashes: z
      .object({
        quoteToken: bytes32,
        vrfWrapper: bytes32,
        raffleFactory: bytes32,
        raffleImplementation: bytes32,
      })
      .strict(),
    deployer: address,
    quoteToken: address,
    vrfWrapper: address,
    raffleFactory: address,
    raffleImplementation: address,
    protocolTreasury: address,
    callbackGasLimit: z.literal(300_000),
    requestConfirmations: z.literal(30),
    sourceCommit: z.string().regex(/^[a-fA-F0-9]{40}$/),
    verificationStatus: z.literal("verified"),
  })
  .strict()
  .superRefine((record, context) => {
    const expected = record.chainId === 11_155_111 ? "sepolia" : "mainnet";
    if (record.networkName !== expected) {
      context.addIssue({
        code: "custom",
        path: ["networkName"],
        message: `chain ${record.chainId} must use networkName ${expected}`,
      });
    }
    const uniqueProtocolAddresses = new Set(
      [
        record.quoteToken,
        record.vrfWrapper,
        record.raffleFactory,
        record.raffleImplementation,
        record.protocolTreasury,
      ].map((value) => value.toLowerCase()),
    );
    if (uniqueProtocolAddresses.size !== 5) {
      context.addIssue({
        code: "custom",
        path: ["raffleFactory"],
        message: "protocol dependency and treasury addresses must be distinct",
      });
    }
    if (
      record.validationBlock <
      record.deploymentTransactions.raffleFactory.blockNumber
    ) {
      context.addIssue({
        code: "custom",
        path: ["validationBlock"],
        message:
          "validation block must not precede the factory deployment transaction",
      });
    }
  });

export type DeploymentRecordInput = z.input<typeof deploymentRecordSchema>;
export type DeploymentRecord = z.output<typeof deploymentRecordSchema>;

export async function writeDeploymentRecord(
  candidate: unknown,
  repositoryRoot: string,
): Promise<string> {
  const record = deploymentRecordSchema.parse(candidate);
  const directory = path.join(repositoryRoot, "deployments");
  const destination = path.join(directory, `${record.chainId}.json`);
  await mkdir(directory, { recursive: true });
  await writeFile(destination, `${JSON.stringify(record, null, 2)}\n`, "utf8");
  return destination;
}
