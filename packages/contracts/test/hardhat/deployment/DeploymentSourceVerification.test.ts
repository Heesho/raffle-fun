import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { createEtherscanSourceVerifier } from "../../../scripts/deployment-source-verification.js";

const address = "0x3333333333333333333333333333333333333333";
const exactRecord = {
  SourceCode: "contract RaffleFactory {}",
  ABI: "[]",
  ContractName: "RaffleFactory",
  CompilerVersion: "v0.8.36+commit.8a079791",
  CompilerType: "solc",
  OptimizationUsed: "1",
  Runs: "200",
  EVMVersion: "cancun",
  Proxy: "0",
  Implementation: "",
  SimilarMatch: "",
};

describe("deployment source verification", () => {
  it("accepts only an exact independently fetched Etherscan record", async () => {
    const fetcher: typeof fetch = async (input) => {
      const url = new URL(String(input));
      assert.equal(
        url.origin + url.pathname,
        "https://api.etherscan.io/v2/api",
      );
      assert.equal(url.searchParams.get("chainid"), "1");
      assert.equal(url.searchParams.get("action"), "getsourcecode");
      assert.equal(url.searchParams.get("address"), address);
      assert.equal(url.searchParams.get("apikey"), "secret-key");
      return jsonResponse({
        status: "1",
        message: "OK",
        result: [exactRecord],
      });
    };

    await createEtherscanSourceVerifier("secret-key", fetcher)(
      1,
      address,
      "RaffleFactory",
    );
  });

  it("rejects missing publication and non-exact or proxy matches", async () => {
    const responseFor =
      (record: unknown): typeof fetch =>
      async () =>
        jsonResponse({ status: "1", message: "OK", result: [record] });

    await assert.rejects(
      createEtherscanSourceVerifier(
        "secret-key",
        responseFor({ ...exactRecord, SourceCode: "" }),
      )(1, address, "RaffleFactory"),
      /source is absent/,
    );
    await assert.rejects(
      createEtherscanSourceVerifier(
        "secret-key",
        responseFor({
          ...exactRecord,
          SimilarMatch: "0x4444444444444444444444444444444444444444",
        }),
      )(1, address, "RaffleFactory"),
      /only a SimilarMatch/,
    );
    await assert.rejects(
      createEtherscanSourceVerifier(
        "secret-key",
        responseFor({
          ...exactRecord,
          Proxy: "1",
          Implementation: "0x4444444444444444444444444444444444444444",
        }),
      )(1, address, "RaffleFactory"),
      /as a proxy/,
    );
    const { Implementation: _implementation, ...withoutImplementation } =
      exactRecord;
    await assert.rejects(
      createEtherscanSourceVerifier(
        "secret-key",
        responseFor(withoutImplementation),
      )(1, address, "RaffleFactory"),
      /as a proxy/,
    );
    const { SimilarMatch: _similarMatch, ...withoutSimilarMatch } = exactRecord;
    await assert.rejects(
      createEtherscanSourceVerifier(
        "secret-key",
        responseFor(withoutSimilarMatch),
      )(1, address, "RaffleFactory"),
      /omitted exact-match status/,
    );
  });

  it("requires exact compiler, optimizer, and Cancun settings", async () => {
    const responseFor =
      (record: unknown): typeof fetch =>
      async () =>
        jsonResponse({ status: "1", message: "OK", result: [record] });

    await assert.rejects(
      createEtherscanSourceVerifier(
        "secret-key",
        responseFor({
          ...exactRecord,
          CompilerVersion: "v0.8.35+commit.c7b9a2c3",
        }),
      )(1, address, "RaffleFactory"),
      /does not match/,
    );
    await assert.rejects(
      createEtherscanSourceVerifier(
        "secret-key",
        responseFor({ ...exactRecord, Runs: "1000" }),
      )(1, address, "RaffleFactory"),
      /optimizer settings/,
    );
    await assert.rejects(
      createEtherscanSourceVerifier(
        "secret-key",
        responseFor({ ...exactRecord, EVMVersion: "default" }),
      )(1, address, "RaffleFactory"),
      /does not match Cancun/,
    );
  });

  it("rejects a missing API key before making a request", () => {
    assert.throws(() => createEtherscanSourceVerifier(""), /ETHERSCAN_API_KEY/);
  });
});

function jsonResponse(payload: unknown): Response {
  return new Response(JSON.stringify(payload), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}
