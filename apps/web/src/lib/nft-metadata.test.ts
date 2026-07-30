import { describe, expect, it } from "vitest";

import { safeExternalUrl } from "./nft-metadata";

describe("NFT metadata URL policy", () => {
  it("converts IPFS resources through a fixed HTTPS gateway", () => {
    expect(safeExternalUrl("ipfs://bafy/test.png", "image")).toBe(
      "https://ipfs.io/ipfs/bafy/test.png",
    );
  });

  it("rejects executable and credential-bearing URLs", () => {
    expect(safeExternalUrl("javascript:alert(1)", "image")).toBeUndefined();
    expect(
      safeExternalUrl("https://user:pass@example.com/a.png", "image"),
    ).toBeUndefined();
    expect(
      safeExternalUrl("https://example.com/a.svg", "image"),
    ).toBeUndefined();
  });
});
