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
  chainId: 11_155_111,
  networkName: "sepolia",
  deployedAt: "2026-07-30T00:00:00.000Z",
  validationBlock: 1,
  validationBlockHash:
    "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  deploymentTransactions: {
    raffleFactory: {
      hash: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      blockNumber: 1,
    },
  },
  runtimeCodeHashes: {
    quoteToken:
      "0x0101010101010101010101010101010101010101010101010101010101010101",
    vrfWrapper:
      "0x0202020202020202020202020202020202020202020202020202020202020202",
    raffleFactory:
      "0x0303030303030303030303030303030303030303030303030303030303030303",
    raffleImplementation:
      "0x0404040404040404040404040404040404040404040404040404040404040404",
  },
  deployer: "0x1111111111111111111111111111111111111111",
  quoteToken: "0x3333333333333333333333333333333333333333",
  vrfWrapper: "0x4444444444444444444444444444444444444444",
  raffleFactory: "0x6666666666666666666666666666666666666666",
  raffleImplementation: "0x5555555555555555555555555555555555555555",
  protocolTreasury: "0x8888888888888888888888888888888888888888",
  callbackGasLimit: 300_000,
  requestConfirmations: 30,
  sourceCommit: "9999999999999999999999999999999999999999",
  verificationStatus: "verified",
} as const;

describe("deployment record", () => {
  it("writes the canonical network filename after strict validation", async () => {
    const directory = await mkdtemp(path.join(tmpdir(), "raffle-deployment-"));
    const destination = await writeDeploymentRecord(record, directory);
    assert.equal(
      destination,
      path.join(directory, "deployments", "11155111.json"),
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
      deploymentRecordSchema.parse({ ...record, networkName: "mainnet" }),
    );
    assert.throws(() =>
      deploymentRecordSchema.parse({
        ...record,
        callbackGasLimit: 299_999,
      }),
    );
    assert.throws(() =>
      deploymentRecordSchema.parse({ ...record, requestConfirmations: 29 }),
    );
    assert.throws(() =>
      deploymentRecordSchema.parse({
        ...record,
        verificationStatus: "unverified",
      }),
    );
    assert.throws(() =>
      deploymentRecordSchema.parse({
        ...record,
        raffleImplementation: record.raffleFactory,
      }),
    );
  });
});
