import { z } from "zod";

const metadataSchema = z
  .object({
    name: z.string().max(160).optional(),
    description: z.string().max(2_000).optional(),
    image: z.string().max(2_048).optional(),
  })
  .passthrough();

export interface SafeNftMetadata {
  readonly name: string;
  readonly description: string;
  readonly imageUrl?: string;
}

export function safeExternalUrl(
  raw: string | undefined,
  purpose: "metadata" | "image",
): string | undefined {
  if (raw === undefined) return undefined;
  const trimmed = raw.trim();
  if (trimmed.startsWith("ipfs://")) {
    const path = trimmed.slice("ipfs://".length).replace(/^ipfs\//, "");
    if (!/^[a-zA-Z0-9/._-]+$/.test(path)) return undefined;
    return `https://ipfs.io/ipfs/${path}`;
  }

  try {
    const url = new URL(trimmed);
    const allowedProtocol =
      url.protocol === "https:" ||
      (url.protocol === "http:" &&
        (url.hostname === "localhost" || url.hostname === "127.0.0.1"));
    if (!allowedProtocol || url.username !== "" || url.password !== "")
      return undefined;
    if (purpose === "image" && url.pathname.toLowerCase().endsWith(".svg")) {
      return undefined;
    }
    return url.toString();
  } catch {
    return undefined;
  }
}

export async function fetchSafeNftMetadata(
  tokenUri: string,
  signal?: AbortSignal,
): Promise<SafeNftMetadata> {
  const url = safeExternalUrl(tokenUri, "metadata");
  if (url === undefined) {
    throw new Error(
      "The NFT metadata URI uses an unsupported or unsafe scheme.",
    );
  }
  const response = await fetch(url, {
    headers: { Accept: "application/json" },
    redirect: "error",
    signal,
  });
  if (!response.ok) {
    throw new Error(`Metadata request failed with HTTP ${response.status}.`);
  }

  const contentLength = Number(response.headers.get("content-length") ?? "0");
  if (contentLength > 1_000_000) {
    throw new Error("NFT metadata exceeds the 1 MB display limit.");
  }
  const metadata = metadataSchema.parse(await response.json());
  return {
    name: metadata.name?.trim() || "Unnamed NFT",
    description: metadata.description?.trim() || "No description supplied.",
    imageUrl: safeExternalUrl(metadata.image, "image"),
  };
}
