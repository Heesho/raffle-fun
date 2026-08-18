import { z } from "zod";

const addressSchema = z
  .string()
  .regex(/^0x[a-fA-F0-9]{40}$/, "Expected an EVM address");
const privateKeySchema = z
  .string()
  .regex(/^0x[a-fA-F0-9]{64}$/, "Expected a 32-byte private key");
const rpcUrlSchema = z
  .url()
  .refine(
    (value) => value.startsWith("https://") || value.startsWith("http://"),
    "Expected an HTTP(S) RPC URL",
  );

export const deploymentEnvSchema = z.object({
  DEPLOYER_PRIVATE_KEY: privateKeySchema,
  PROTOCOL_TREASURY: addressSchema,
  FACTORY_OWNER: addressSchema,
  SEPOLIA_RPC_URL: rpcUrlSchema.optional(),
  ETHEREUM_RPC_URL: rpcUrlSchema.optional(),
  ETHERSCAN_API_KEY: z.string().min(1).optional(),
});

export const publicWebEnvSchema = z.object({
  NEXT_PUBLIC_CHAIN_ID: z.coerce.number().int().positive().default(11_155_111),
  NEXT_PUBLIC_RPC_URL: rpcUrlSchema,
  NEXT_PUBLIC_SUBGRAPH_URL: z.url(),
  NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID: z.string().min(1),
});

export type DeploymentEnv = z.infer<typeof deploymentEnvSchema>;
export type PublicWebEnv = z.infer<typeof publicWebEnvSchema>;

export function parseDeploymentEnv(
  environment: Record<string, string | undefined>,
): DeploymentEnv {
  return deploymentEnvSchema.parse(environment);
}

export function parsePublicWebEnv(
  environment: Record<string, string | undefined>,
): PublicWebEnv {
  return publicWebEnvSchema.parse(environment);
}
