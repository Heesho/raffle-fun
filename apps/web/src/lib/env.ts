import { z } from "zod";

const httpUrl = z
  .url()
  .refine(
    (value) => value.startsWith("https://") || value.startsWith("http://"),
    "must be an HTTP(S) URL",
  );

const optionalHttpUrl = z.preprocess(
  (value) => (value === "" ? undefined : value),
  httpUrl.optional(),
);

const optionalString = z.preprocess(
  (value) => (value === "" ? undefined : value),
  z.string().min(1).optional(),
);

const webEnvironmentSchema = z
  .object({
    NEXT_PUBLIC_CHAIN_ID: z.coerce
      .number()
      .int()
      .refine(
        (value) => value === 84_532 || value === 8_453 || value === 31_337,
        {
          message:
            "must be Base Sepolia (84532), Base (8453), or local Anvil (31337)",
        },
      )
      .default(84_532),
    NEXT_PUBLIC_RPC_URL: optionalHttpUrl,
    NEXT_PUBLIC_SUBGRAPH_URL: optionalHttpUrl,
    NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID: optionalString,
  })
  .strict();

const candidate = {
  NEXT_PUBLIC_CHAIN_ID: process.env.NEXT_PUBLIC_CHAIN_ID,
  NEXT_PUBLIC_RPC_URL: process.env.NEXT_PUBLIC_RPC_URL,
  NEXT_PUBLIC_SUBGRAPH_URL: process.env.NEXT_PUBLIC_SUBGRAPH_URL,
  NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID:
    process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID,
};

const result = webEnvironmentSchema.safeParse(candidate);

export const webEnv = result.success
  ? result.data
  : {
      NEXT_PUBLIC_CHAIN_ID: 84_532 as const,
      NEXT_PUBLIC_RPC_URL: undefined,
      NEXT_PUBLIC_SUBGRAPH_URL: undefined,
      NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID: undefined,
    };

export const webEnvErrors = result.success
  ? []
  : result.error.issues.map(
      (issue) => `${issue.path.join(".")}: ${issue.message}`,
    );
