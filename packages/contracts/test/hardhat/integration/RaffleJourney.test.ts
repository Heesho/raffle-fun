import assert from "node:assert/strict";
import path from "node:path";
import { describe, it } from "node:test";

import { network } from "hardhat";
import { keccak256 } from "viem";
import RaffleFunModule from "../../../ignition/modules/RaffleFun.js";
import { loadDeploymentBuildEvidence } from "../../../scripts/deployment-build-evidence.js";
import type { DeploymentRecord } from "../../../scripts/deployment-record.js";

const ENTRY_PRICE = 1_000_000n;

describe("Raffle Fun sequential-ticket integration", () => {
  it("deploys only the fixed factory and locked clone implementation", async () => {
    const { ignition, viem } = await network.create({
      network: "hardhatEthereum",
    });
    const publicClient = await viem.getPublicClient();
    const [owner, treasury] = await viem.getWalletClients();
    assert.ok(owner && treasury);

    const quote = await viem.deployContract("MockERC20");
    const vrfWrapper = await viem.deployContract("MockVRFV2PlusWrapper");
    const { raffleFactory } = await ignition.deploy(RaffleFunModule, {
      parameters: {
        RaffleFunModule: {
          quoteToken: quote.address,
          vrfWrapper: vrfWrapper.address,
          protocolTreasury: treasury.account.address,
          finalFactoryOwner: treasury.account.address,
        },
      },
      deploymentId: "raffle-fun-sequential-ticket-integration",
    });

    assertAddressEqual(await raffleFactory.read.quoteToken(), quote.address);
    assertAddressEqual(
      await raffleFactory.read.vrfWrapper(),
      vrfWrapper.address,
    );
    assert.equal(await raffleFactory.read.callbackGasLimit(), 300_000);
    assert.equal(await raffleFactory.read.requestConfirmations(), 30);
    const implementation = await raffleFactory.read.raffleImplementation();
    const implementationCode = await publicClient.getCode({
      address: implementation,
    });
    assert.ok(implementationCode !== undefined && implementationCode !== "0x");
    const factoryCode = await publicClient.getCode({
      address: raffleFactory.address,
    });
    assert.ok(factoryCode !== undefined && factoryCode !== "0x");
    const buildCandidate = {
      chainId: 1,
      networkName: "mainnet",
      deployedAt: "2026-08-18T00:00:00.000Z",
      validationBlock: 1,
      validationBlockHash: `0x${"11".repeat(32)}`,
      deploymentTransactions: {
        raffleFactory: { hash: `0x${"22".repeat(32)}`, blockNumber: 1 },
      },
      runtimeCodeHashes: {
        quoteToken: `0x${"33".repeat(32)}`,
        vrfWrapper: `0x${"44".repeat(32)}`,
        raffleFactory: keccak256(factoryCode),
        raffleImplementation: keccak256(implementationCode),
      },
      deployer: owner.account.address,
      finalFactoryOwner: treasury.account.address,
      quoteToken: quote.address,
      vrfWrapper: vrfWrapper.address,
      raffleFactory: raffleFactory.address,
      raffleImplementation: implementation,
      protocolTreasury: treasury.account.address,
      callbackGasLimit: 300_000,
      requestConfirmations: 30,
      sourceCommit: "9999999999999999999999999999999999999999",
      verificationStatus: "verified",
    } as const satisfies DeploymentRecord;
    const buildEvidence = await loadDeploymentBuildEvidence(
      path.resolve(import.meta.dirname, "../../../../.."),
      buildCandidate,
      vrfWrapper.address,
      buildCandidate.sourceCommit,
      async () => {},
    );
    assert.equal(
      buildEvidence.expectedRuntimeCodeHashes.raffleFactory,
      keccak256(factoryCode),
    );
    assert.equal(
      buildEvidence.expectedRuntimeCodeHashes.raffleImplementation,
      keccak256(implementationCode),
    );
    assertAddressEqual(
      await raffleFactory.read.pendingOwner(),
      treasury.account.address,
    );
  });

  it("settles an NFT raffle permissionlessly for the current bearer", async () => {
    const { networkHelpers, viem } = await network.create({
      network: "hardhatEthereum",
    });
    const publicClient = await viem.getPublicClient();
    const [owner, sponsor, buyer, winner, treasury, requester, settler] =
      await viem.getWalletClients();
    assert.ok(
      owner && sponsor && buyer && winner && treasury && requester && settler,
    );

    const quote = await viem.deployContract("MockERC20");
    const prize = await viem.deployContract("MockERC721");
    const vrfWrapper = await viem.deployContract("MockVRFV2PlusWrapper");
    const factory = await viem.deployContract("RaffleFactory", [
      quote.address,
      vrfWrapper.address,
      treasury.account.address,
      owner.account.address,
    ]);

    await wait(publicClient, prize.write.mint([sponsor.account.address, 1n]));
    const sponsorPrize = await viem.getContractAt("MockERC721", prize.address, {
      client: { wallet: sponsor },
    });
    await wait(
      publicClient,
      sponsorPrize.write.setApprovalForAll([factory.address, true]),
    );

    const endTime = BigInt(await networkHelpers.time.latest()) + 3_600n;
    const sponsorFactory = await viem.getContractAt(
      "RaffleFactory",
      factory.address,
      { client: { wallet: sponsor } },
    );
    await wait(
      publicClient,
      sponsorFactory.write.createRaffle([
        {
          sponsorRecipient: sponsor.account.address,
          prizeToken: prize.address,
          prizeTokenId: 1n,
          reserveEntries: 6n,
          endTime,
        },
      ]),
    );

    const raffleAddress = await factory.read.raffleById([1n]);
    const implementation = await factory.read.raffleImplementation();
    const cloneRuntime = await publicClient.getCode({ address: raffleAddress });
    assert.equal(
      cloneRuntime?.toLowerCase(),
      `0x363d3d373d3d3d363d73${implementation.slice(2)}5af43d82803e903d91602b57fd5bf3`.toLowerCase(),
    );
    const raffle = await viem.getContractAt("Raffle", raffleAddress);
    const buyerQuote = await viem.getContractAt("MockERC20", quote.address, {
      client: { wallet: buyer },
    });
    const buyerRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: buyer },
    });
    await wait(
      publicClient,
      quote.write.mint([buyer.account.address, 6n * ENTRY_PRICE]),
    );
    await wait(
      publicClient,
      buyerQuote.write.approve([raffleAddress, 6n * ENTRY_PRICE]),
    );
    await wait(
      publicClient,
      buyerRaffle.write.buyEntries([buyer.account.address, 2n]),
    );
    await wait(
      publicClient,
      buyerRaffle.write.buyEntries([winner.account.address, 4n]),
    );

    const firstTicket = 1n;
    const winningTicket = 2n;
    assertAddressEqual(
      await raffle.read.ownerOf([firstTicket]),
      buyer.account.address,
    );
    assertAddressEqual(
      await raffle.read.ownerOf([winningTicket]),
      winner.account.address,
    );
    assert.deepEqual(await raffle.read.ticketRange([winningTicket]), [3n, 6n]);
    assert.equal(await raffle.read.totalEntries(), 6n);
    assert.equal(await raffle.read.ticketCount(), 2n);
    assert.equal(await raffle.read.grossSales(), 6n * ENTRY_PRICE);

    await networkHelpers.time.increaseTo(endTime);
    const requesterRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: requester },
    });
    const fee = await raffle.read.getVrfRequestPrice();
    await wait(publicClient, requesterRaffle.write.requestDraw({ value: fee }));
    assert.equal(await raffle.read.status(), 2);
    await wait(publicClient, vrfWrapper.write.fulfill([1n, 2n]));
    assert.equal(await raffle.read.status(), 3);
    assert.equal(await raffle.read.winningEntry(), 3n);

    const winnerRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: winner },
    });
    await wait(
      publicClient,
      winnerRaffle.write.transferFrom([
        winner.account.address,
        buyer.account.address,
        winningTicket,
      ]),
    );

    const settlerRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: settler },
    });
    await wait(
      publicClient,
      settlerRaffle.write.settleWinningTicket([winningTicket]),
    );
    assertAddressEqual(
      await raffle.read.winnerRecipient(),
      "0x0000000000000000000000000000000000000000",
    );
    assertAddressEqual(
      await raffle.read.ownerOf([winningTicket]),
      buyer.account.address,
    );
    assert.equal(await raffle.read.settlementComplete(), true);
    assert.equal(await raffle.read.prizeClaimed(), false);
    assertAddressEqual(await prize.read.ownerOf([1n]), raffleAddress);
    await wait(
      publicClient,
      buyerRaffle.write.redeemWinningTicket([winningTicket]),
    );
    assertAddressEqual(await prize.read.ownerOf([1n]), buyer.account.address);
    assertAddressEqual(
      await raffle.read.winnerRecipient(),
      buyer.account.address,
    );
    assert.equal(await raffle.read.protocolFees(), 300_000n);
    assert.equal(await raffle.read.sponsorProceeds(), 5_700_000n);
    assert.equal(await raffle.read.unsettledPot(), 0n);
  });

  it("finalizes cash at 80/5/15 gross and lets each party claim independently", async () => {
    const { networkHelpers, viem } = await network.create({
      network: "hardhatEthereum",
    });
    const publicClient = await viem.getPublicClient();
    const [owner, sponsor, buyer, treasury, requester, settler] =
      await viem.getWalletClients();
    assert.ok(owner && sponsor && buyer && treasury && requester && settler);

    const quote = await viem.deployContract("MockERC20");
    const prize = await viem.deployContract("MockERC721");
    const wrapper = await viem.deployContract("MockVRFV2PlusWrapper");
    const factory = await viem.deployContract("RaffleFactory", [
      quote.address,
      wrapper.address,
      treasury.account.address,
      owner.account.address,
    ]);
    await wait(publicClient, prize.write.mint([sponsor.account.address, 7n]));
    const sponsorPrize = await viem.getContractAt("MockERC721", prize.address, {
      client: { wallet: sponsor },
    });
    await wait(
      publicClient,
      sponsorPrize.write.setApprovalForAll([factory.address, true]),
    );
    const endTime = BigInt(await networkHelpers.time.latest()) + 60n;
    const sponsorFactory = await viem.getContractAt(
      "RaffleFactory",
      factory.address,
      { client: { wallet: sponsor } },
    );
    await wait(
      publicClient,
      sponsorFactory.write.createRaffle([
        {
          sponsorRecipient: sponsor.account.address,
          prizeToken: prize.address,
          prizeTokenId: 7n,
          reserveEntries: 2n,
          endTime,
        },
      ]),
    );

    const raffleAddress = await factory.read.raffleById([1n]);
    const raffle = await viem.getContractAt("Raffle", raffleAddress);
    const buyerQuote = await viem.getContractAt("MockERC20", quote.address, {
      client: { wallet: buyer },
    });
    const buyerRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: buyer },
    });
    await wait(
      publicClient,
      quote.write.mint([buyer.account.address, ENTRY_PRICE]),
    );
    await wait(
      publicClient,
      buyerQuote.write.approve([raffleAddress, ENTRY_PRICE]),
    );
    await wait(
      publicClient,
      buyerRaffle.write.buyEntries([buyer.account.address, 1n]),
    );

    await networkHelpers.time.increaseTo(endTime);
    const requesterRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: requester },
    });
    await wait(
      publicClient,
      requesterRaffle.write.requestDraw({
        value: await raffle.read.getVrfRequestPrice(),
      }),
    );
    await wait(publicClient, wrapper.write.fulfill([1n, 0n]));
    assert.equal(await raffle.read.status(), 4);
    assert.equal(await raffle.read.unsettledPot(), ENTRY_PRICE);
    assert.equal(await raffle.read.protocolFees(), 0n);
    assert.equal(await raffle.read.sponsorProceeds(), 0n);

    const ticketId = 1n;
    const settlerRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: settler },
    });
    const buyerBefore = await quote.read.balanceOf([buyer.account.address]);
    await wait(
      publicClient,
      settlerRaffle.write.settleWinningTicket([ticketId]),
    );
    assert.equal(
      (await quote.read.balanceOf([buyer.account.address])) - buyerBefore,
      0n,
    );
    assertAddressEqual(
      await raffle.read.winnerRecipient(),
      "0x0000000000000000000000000000000000000000",
    );
    assert.equal(await raffle.read.winnerProceeds(), 800_000n);
    await wait(publicClient, buyerRaffle.write.redeemWinningTicket([ticketId]));
    assert.equal(
      (await quote.read.balanceOf([buyer.account.address])) - buyerBefore,
      800_000n,
    );
    assert.equal(await raffle.read.winnerProceeds(), 0n);
    assert.equal(await raffle.read.protocolFees(), 50_000n);
    assert.equal(await raffle.read.sponsorProceeds(), 150_000n);

    const finalizerRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: settler },
    });
    const sponsorBefore = await quote.read.balanceOf([sponsor.account.address]);
    await wait(publicClient, finalizerRaffle.write.releaseSponsorProceeds());
    assert.equal(
      (await quote.read.balanceOf([sponsor.account.address])) - sponsorBefore,
      150_000n,
    );
    await wait(publicClient, finalizerRaffle.write.releaseSponsorPrize());
    assertAddressEqual(await prize.read.ownerOf([7n]), sponsor.account.address);
  });

  it("refunds weighted tickets when no draw request is accepted by the hard deadline", async () => {
    const { networkHelpers, viem } = await network.create({
      network: "hardhatEthereum",
    });
    const publicClient = await viem.getPublicClient();
    const [owner, sponsor, buyer, treasury, finalizer] =
      await viem.getWalletClients();
    assert.ok(owner && sponsor && buyer && treasury && finalizer);

    const quote = await viem.deployContract("MockERC20");
    const prize = await viem.deployContract("MockERC721");
    const wrapper = await viem.deployContract("MockVRFV2PlusWrapper");
    const factory = await viem.deployContract("RaffleFactory", [
      quote.address,
      wrapper.address,
      treasury.account.address,
      owner.account.address,
    ]);
    await wait(publicClient, prize.write.mint([sponsor.account.address, 9n]));
    const sponsorPrize = await viem.getContractAt("MockERC721", prize.address, {
      client: { wallet: sponsor },
    });
    await wait(
      publicClient,
      sponsorPrize.write.setApprovalForAll([factory.address, true]),
    );
    const endTime = BigInt(await networkHelpers.time.latest()) + 60n;
    const sponsorFactory = await viem.getContractAt(
      "RaffleFactory",
      factory.address,
      { client: { wallet: sponsor } },
    );
    await wait(
      publicClient,
      sponsorFactory.write.createRaffle([
        {
          sponsorRecipient: sponsor.account.address,
          prizeToken: prize.address,
          prizeTokenId: 9n,
          reserveEntries: 100n,
          endTime,
        },
      ]),
    );

    const raffleAddress = await factory.read.raffleById([1n]);
    const raffle = await viem.getContractAt("Raffle", raffleAddress);
    const buyerQuote = await viem.getContractAt("MockERC20", quote.address, {
      client: { wallet: buyer },
    });
    const buyerRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: buyer },
    });
    await wait(
      publicClient,
      quote.write.mint([buyer.account.address, 7n * ENTRY_PRICE]),
    );
    await wait(
      publicClient,
      buyerQuote.write.approve([raffleAddress, 7n * ENTRY_PRICE]),
    );
    await wait(
      publicClient,
      buyerRaffle.write.buyEntries([buyer.account.address, 2n]),
    );
    await wait(
      publicClient,
      buyerRaffle.write.buyEntries([buyer.account.address, 5n]),
    );

    const finalizerRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: finalizer },
    });
    await networkHelpers.time.increaseTo(
      await raffle.read.drawRequestDeadline(),
    );
    await wait(publicClient, finalizerRaffle.write.enableRefunds());
    assert.equal(await raffle.read.status(), 5);
    assert.equal(
      await raffle.read.remainingRefundLiability(),
      7n * ENTRY_PRICE,
    );

    const before = await quote.read.balanceOf([buyer.account.address]);
    await wait(publicClient, buyerRaffle.write.refundTickets([[1n, 2n]]));
    assert.equal(
      (await quote.read.balanceOf([buyer.account.address])) - before,
      7n * ENTRY_PRICE,
    );
    assert.equal(await raffle.read.remainingRefundLiability(), 0n);
    await wait(publicClient, finalizerRaffle.write.releaseSponsorPrize());
    assertAddressEqual(await prize.read.ownerOf([9n]), sponsor.account.address);
  });
});

async function wait(
  publicClient: Awaited<
    ReturnType<
      Awaited<ReturnType<typeof network.create>>["viem"]["getPublicClient"]
    >
  >,
  hashPromise: Promise<`0x${string}`>,
): Promise<void> {
  const hash = await hashPromise;
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  assert.equal(receipt.status, "success");
}

function assertAddressEqual(actual: string, expected: string): void {
  assert.equal(actual.toLowerCase(), expected.toLowerCase());
}
