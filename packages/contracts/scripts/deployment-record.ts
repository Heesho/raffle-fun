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

export const deploymentRecordSchema = z
  .object({
    chainId: z.union([z.literal(84_532), z.literal(8_453)]),
    networkName: z.union([z.literal("base-sepolia"), z.literal("base")]),
    deployedAt: z.iso.datetime(),
    deploymentBlock: z.number().int().positive(),
    deployer: address,
    finalFactoryOwner: address,
    verifiedQuoteTokens: z
      .array(address)
      .min(1)
      .max(32)
      .refine(
        (tokens) =>
          new Set(tokens.map((token) => token.toLowerCase())).size ===
          tokens.length,
        "verified quote tokens must be unique",
      ),
    entropy: address,
    raffleImplementation: address,
    raffleFactory: address,
    raffleLens: address,
    protocolTreasury: address,
    callbackGasLimit: z.number().int().positive(),
    sourceCommit: z.string().regex(/^[a-fA-F0-9]{40}$/),
    verificationStatus: z.union([
      z.literal("unverified"),
      z.literal("partial"),
      z.literal("verified"),
    ]),
  })
  .strict()
  .superRefine((record, context) => {
    const expected = record.chainId === 84_532 ? "base-sepolia" : "base";
    if (record.networkName !== expected) {
      context.addIssue({
        code: "custom",
        path: ["networkName"],
        message: `chain ${record.chainId} must use networkName ${expected}`,
      });
    }
  });

export type DeploymentRecordInput = z.input<typeof deploymentRecordSchema>;

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
