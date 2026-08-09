import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, it } from "node:test";

import {
  deploymentRecordSchema,
  writeDeploymentRecord,
} from "../../../scripts/deployment-record.js";

const record = {
  chainId: 84_532,
  networkName: "base-sepolia",
  deployedAt: "2026-07-30T00:00:00.000Z",
  deploymentBlock: 1,
  deployer: "0x1111111111111111111111111111111111111111",
  finalFactoryOwner: "0x2222222222222222222222222222222222222222",
  quoteToken: "0x3333333333333333333333333333333333333333",
  entropy: "0x4444444444444444444444444444444444444444",
  raffleFactory: "0x6666666666666666666666666666666666666666",
  raffleLens: "0x7777777777777777777777777777777777777777",
  protocolTreasury: "0x8888888888888888888888888888888888888888",
  callbackGasLimit: 300_000,
  sourceCommit: "9999999999999999999999999999999999999999",
  verificationStatus: "unverified",
} as const;

describe("deployment record", () => {
  it("writes the canonical network filename after strict validation", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "raffle-deployment-"));
    const destination = await writeDeploymentRecord(record, directory);
    assert.equal(
      destination,
      path.join(directory, "deployments", "84532.json"),
    );
    assert.deepEqual(JSON.parse(await readFile(destination, "utf8")), record);
  });

  it("rejects placeholders and mismatched network labels", () => {
    assert.throws(() =>
      deploymentRecordSchema.parse({
        ...record,
        quoteToken: "0x0000000000000000000000000000000000000000",
      }),
    );
    assert.throws(() =>
      deploymentRecordSchema.parse({ ...record, networkName: "base" }),
    );
    assert.throws(() =>
      deploymentRecordSchema.parse({
        ...record,
        callbackGasLimit: 4_294_967_296,
      }),
    );
    assert.throws(() =>
      deploymentRecordSchema.parse({
        ...record,
        raffleLens: record.raffleFactory,
      }),
    );
  });
});
