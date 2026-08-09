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
    quoteToken: address,
    entropy: address,
    raffleFactory: address,
    raffleLens: address,
    protocolTreasury: address,
    callbackGasLimit: z.number().int().positive().max(4_294_967_295),
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
    const uniqueProtocolAddresses = new Set(
      [
        record.quoteToken,
        record.entropy,
        record.raffleFactory,
        record.raffleLens,
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
