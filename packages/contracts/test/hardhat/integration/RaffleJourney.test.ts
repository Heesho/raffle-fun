import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import { toHex } from "viem";

import RaffleFunModule from "../../../ignition/modules/RaffleFun.js";

describe("Raffle Fun integration", () => {
  it("deploys the canonical implementation, factory, and lens through Ignition", async () => {
    const { ignition, viem } = await network.create({
      network: "hardhatBase",
    });
    const [owner, treasury] = await viem.getWalletClients();
    assert.ok(owner);
    assert.ok(treasury);

    const quote = await viem.deployContract("MockERC20");
    const entropy = await viem.deployContract("MockEntropyV2");
    const { raffleImplementation, raffleFactory, raffleLens } =
      await ignition.deploy(RaffleFunModule, {
        parameters: {
          RaffleFunModule: {
            verifiedQuoteTokens: [quote.address],
            entropy: entropy.address,
            protocolTreasury: treasury.account.address,
            callbackGasLimit: 300_000n,
            finalFactoryOwner: treasury.account.address,
          },
        },
        deploymentId: "raffle-fun-integration",
      });

    assertAddressEqual(
      await raffleFactory.read.raffleImplementation(),
      raffleImplementation.address,
    );
    assert.equal(await raffleFactory.read.verifiedQuoteTokenCount(), 1n);
    assertAddressEqual(
      await raffleFactory.read.verifiedQuoteTokenAt([0n]),
      quote.address,
    );
    assert.equal(
      await raffleFactory.read.isVerifiedQuoteToken([quote.address]),
      true,
    );
    assertAddressEqual(await raffleFactory.read.entropy(), entropy.address);
    assert.equal(await raffleFactory.read.callbackGasLimit(), 300_000);
    assertAddressEqual(await raffleLens.read.factory(), raffleFactory.address);
    assertAddressEqual(
      await raffleFactory.read.pendingOwner(),
      treasury.account.address,
    );
  });

  it("completes create, buy, transfer, draw, and pull-claim journeys with Viem", async () => {
    const { networkHelpers, viem } = await network.create({
      network: "hardhatBase",
    });
    const publicClient = await viem.getPublicClient();
    const [owner, sponsor, buyer, buyerTwo, treasury, requester] =
      await viem.getWalletClients();
    assert.ok(owner);
    assert.ok(sponsor);
    assert.ok(buyer);
    assert.ok(buyerTwo);
    assert.ok(treasury);
    assert.ok(requester);

    const quote = await viem.deployContract("MockERC20");
    const prize = await viem.deployContract("MockERC721");
    const entropy = await viem.deployContract("MockEntropyV2");
    const implementation = await viem.deployContract("Raffle");
    const factory = await viem.deployContract("RaffleFactory", [
      implementation.address,
      [quote.address],
      entropy.address,
      treasury.account.address,
      300_000,
      owner.account.address,
    ]);
    const lens = await viem.deployContract("RaffleLens", [factory.address]);

    await wait(publicClient, prize.write.mint([sponsor.account.address, 1n]));

    const sponsorPrize = await viem.getContractAt("MockERC721", prize.address, {
      client: { wallet: sponsor },
    });
    await wait(
      publicClient,
      sponsorPrize.write.setApprovalForAll([factory.address, true]),
    );

    const predicted = await factory.read.predictRaffleAddress([
      1n,
      sponsor.account.address,
      quote.address,
      prize.address,
      1n,
    ]);
    const latestTimestamp = BigInt(await networkHelpers.time.latest());
    const endTime = latestTimestamp + 3_600n;
    const sponsorFactory = await viem.getContractAt(
      "RaffleFactory",
      factory.address,
      { client: { wallet: sponsor } },
    );
    const creationHash = await sponsorFactory.write.createRaffle([
      {
        prizeToken: prize.address,
        prizeTokenId: 1n,
        quoteToken: quote.address,
        sponsorPrizeRecoveryRecipient: sponsor.account.address,
        ticketPrice: 1_000_000n,
        minimumTickets: 3n,
        startTime: 0n,
        endTime,
        metadataURI: "ipfs://integration-raffle",
      },
    ]);
    const creationReceipt = await publicClient.waitForTransactionReceipt({
      hash: creationHash,
    });
    assert.equal(creationReceipt.status, "success");
    assertAddressEqual(await factory.read.raffleById([1n]), predicted);
    assertAddressEqual(await prize.read.ownerOf([1n]), predicted);
    assert.equal(
      await factory.read.isVerifiedQuoteToken([quote.address]),
      true,
    );

    const raffle = await viem.getContractAt("Raffle", predicted);
    const buyerQuote = await viem.getContractAt("MockERC20", quote.address, {
      client: { wallet: buyer },
    });
    const buyerRaffle = await viem.getContractAt("Raffle", predicted, {
      client: { wallet: buyer },
    });
    await wait(
      publicClient,
      quote.write.mint([buyer.account.address, 2_000_000n]),
    );
    await wait(publicClient, buyerQuote.write.approve([predicted, 2_000_000n]));
    await wait(
      publicClient,
      buyerRaffle.write.buyTickets([buyer.account.address, 2n]),
    );
    await wait(
      publicClient,
      buyerRaffle.write.transferFrom([
        buyer.account.address,
        buyerTwo.account.address,
        2n,
      ]),
    );

    assert.equal(await raffle.read.totalTickets(), 2n);
    assert.equal(await raffle.read.unsettledPot(), 2_000_000n);
    assert.equal(
      await raffle.read.claimableQuote([treasury.account.address]),
      0n,
    );
    assertAddressEqual(
      await raffle.read.ownerOf([2n]),
      buyerTwo.account.address,
    );
    const accountView = await lens.read.getRaffleState([
      predicted,
      buyer.account.address,
    ]);
    assert.equal(accountView.accountTicketBalance, 1n);
    assert.equal(accountView.canBuy, true);

    await networkHelpers.time.increaseTo(endTime);
    const requesterRaffle = await viem.getContractAt("Raffle", predicted, {
      client: { wallet: requester },
    });
    const fee = await raffle.read.getEntropyFee();
    await wait(publicClient, requesterRaffle.write.requestDraw({ value: fee }));
    assert.equal(await raffle.read.state(), 3);

    await wait(
      publicClient,
      entropy.write.fulfill([1n, toHex(1n, { size: 32 })]),
    );
    assert.equal(await raffle.read.state(), 4);
    assert.equal(await raffle.read.outcome(), 2);
    assert.equal(await raffle.read.winningTicketId(), 2n);
    assertAddressEqual(await raffle.read.winner(), buyerTwo.account.address);
    assert.equal(
      await raffle.read.claimableQuote([treasury.account.address]),
      100_000n,
    );

    const winnerRaffle = await viem.getContractAt("Raffle", predicted, {
      client: { wallet: buyerTwo },
    });
    const winnerBalanceBefore = await quote.read.balanceOf([
      buyerTwo.account.address,
    ]);
    await wait(
      publicClient,
      winnerRaffle.write.claimQuote([buyerTwo.account.address]),
    );
    const winnerBalanceAfter = await quote.read.balanceOf([
      buyerTwo.account.address,
    ]);
    assert.equal(winnerBalanceAfter - winnerBalanceBefore, 1_520_000n);

    const sponsorRaffle = await viem.getContractAt("Raffle", predicted, {
      client: { wallet: sponsor },
    });
    await wait(
      publicClient,
      sponsorRaffle.write.claimPrize([sponsor.account.address]),
    );
    assertAddressEqual(await prize.read.ownerOf([1n]), sponsor.account.address);
  });

  it("completes grace-expiry, bounded refund, and fixed claim-for recovery", async () => {
    const { networkHelpers, viem } = await network.create({
      network: "hardhatBase",
    });
    const publicClient = await viem.getPublicClient();
    const [owner, sponsor, buyer, recovery, treasury, finalizer] =
      await viem.getWalletClients();
    assert.ok(owner);
    assert.ok(sponsor);
    assert.ok(buyer);
    assert.ok(recovery);
    assert.ok(treasury);
    assert.ok(finalizer);

    const quote = await viem.deployContract("MockERC20");
    const prize = await viem.deployContract("MockERC721");
    const entropy = await viem.deployContract("MockEntropyV2");
    const implementation = await viem.deployContract("Raffle");
    const factory = await viem.deployContract("RaffleFactory", [
      implementation.address,
      [quote.address],
      entropy.address,
      treasury.account.address,
      300_000,
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
          prizeToken: prize.address,
          prizeTokenId: 9n,
          quoteToken: quote.address,
          sponsorPrizeRecoveryRecipient: recovery.account.address,
          ticketPrice: 1_000_000n,
          minimumTickets: 2n,
          startTime: 0n,
          endTime,
          metadataURI: "ipfs://integration-refund",
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
      quote.write.mint([buyer.account.address, 2_000_000n]),
    );
    await wait(
      publicClient,
      buyerQuote.write.approve([raffleAddress, 2_000_000n]),
    );
    await wait(
      publicClient,
      buyerRaffle.write.buyTickets([buyer.account.address, 2n]),
    );

    const requestGraceDeadline = await raffle.read.requestGraceDeadline();
    await networkHelpers.time.increaseTo(requestGraceDeadline);
    const finalizerRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: finalizer },
    });
    await wait(publicClient, finalizerRaffle.write.finalizeUnrequestedDraw());
    assert.equal(await raffle.read.state(), 6);
    assert.equal(await raffle.read.outcome(), 5);
    assert.equal(await raffle.read.uncreditedRefundLiability(), 2_000_000n);
    assert.equal(await raffle.read.totalClaimableQuote(), 0n);

    await wait(
      publicClient,
      finalizerRaffle.write.creditTicketRefunds([[1n, 2n]]),
    );
    assert.equal(await raffle.read.uncreditedRefundLiability(), 0n);
    assert.equal(
      await raffle.read.claimableQuote([buyer.account.address]),
      2_000_000n,
    );
    const buyerBalanceBefore = await quote.read.balanceOf([
      buyer.account.address,
    ]);
    await wait(
      publicClient,
      finalizerRaffle.write.claimQuoteFor([buyer.account.address]),
    );
    assert.equal(
      (await quote.read.balanceOf([buyer.account.address])) -
        buyerBalanceBefore,
      2_000_000n,
    );

    await wait(publicClient, finalizerRaffle.write.claimPrizeFor());
    assertAddressEqual(
      await prize.read.ownerOf([9n]),
      recovery.account.address,
    );
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
