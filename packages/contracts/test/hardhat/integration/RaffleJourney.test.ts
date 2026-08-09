import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import { toHex } from "viem";

import RaffleFunModule from "../../../ignition/modules/RaffleFun.js";

describe("Raffle Fun integration", () => {
  it("deploys the one-USDC factory and read-only lens through Ignition", async () => {
    const { ignition, viem } = await network.create({ network: "hardhatBase" });
    const [owner, treasury] = await viem.getWalletClients();
    assert.ok(owner);
    assert.ok(treasury);

    const quote = await viem.deployContract("MockERC20");
    const entropy = await viem.deployContract("MockEntropyV2");
    const { raffleFactory, raffleLens } = await ignition.deploy(
      RaffleFunModule,
      {
        parameters: {
          RaffleFunModule: {
            quoteToken: quote.address,
            entropy: entropy.address,
            protocolTreasury: treasury.account.address,
            callbackGasLimit: 300_000n,
            finalFactoryOwner: treasury.account.address,
          },
        },
        deploymentId: "raffle-fun-integration",
      },
    );

    assertAddressEqual(await raffleFactory.read.quoteToken(), quote.address);
    assertAddressEqual(await raffleFactory.read.entropy(), entropy.address);
    assert.equal(await raffleFactory.read.callbackGasLimit(), 300_000);
    assertAddressEqual(await raffleLens.read.factory(), raffleFactory.address);
    assertAddressEqual(
      await raffleFactory.read.pendingOwner(),
      treasury.account.address,
    );
  });

  it("settles a transferable bearer ticket for cash and recovers the NFT", async () => {
    const { networkHelpers, viem } = await network.create({
      network: "hardhatBase",
    });
    const publicClient = await viem.getPublicClient();
    const [owner, sponsor, buyer, buyerTwo, treasury, requester] =
      await viem.getWalletClients();
    assert.ok(owner && sponsor && buyer && buyerTwo && treasury && requester);

    const quote = await viem.deployContract("MockERC20");
    const prize = await viem.deployContract("MockERC721");
    const entropy = await viem.deployContract("MockEntropyV2");
    const factory = await viem.deployContract("RaffleFactory", [
      quote.address,
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
          prizeToken: prize.address,
          prizeTokenId: 1n,
          sponsorPrizeRecoveryRecipient: sponsor.account.address,
          ticketPrice: 1_000_000n,
          minimumTickets: 3n,
          startTime: 0n,
          endTime,
          metadataURI: "ipfs://integration-raffle",
        },
      ]),
    );

    const raffleAddress = await factory.read.raffleById([1n]);
    assertAddressEqual(await prize.read.ownerOf([1n]), raffleAddress);
    assertAddressEqual(await factory.read.quoteToken(), quote.address);
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
    await wait(
      publicClient,
      buyerRaffle.write.transferFrom([
        buyer.account.address,
        buyerTwo.account.address,
        2n,
      ]),
    );

    await networkHelpers.time.increaseTo(endTime);
    const requesterRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: requester },
    });
    const fee = await raffle.read.getEntropyFee();
    await wait(publicClient, requesterRaffle.write.requestDraw({ value: fee }));
    assert.equal(await raffle.read.status(), 2);
    await wait(
      publicClient,
      entropy.write.fulfill([1n, toHex(1n, { size: 32 })]),
    );

    assert.equal(await raffle.read.status(), 4);
    assert.equal(await raffle.read.winningTicketId(), 2n);
    assert.equal(await raffle.read.winnerCashLiability(), 1_520_000n);
    assert.equal(
      await raffle.read.claimableQuote([treasury.account.address]),
      100_000n,
    );
    const view = await lens.read.getRaffleState([
      raffleAddress,
      buyerTwo.account.address,
    ]);
    assert.equal(view.accountOwnsWinningTicket, true);
    assert.equal(view.canRedeemWinningTicket, true);

    const winnerRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: buyerTwo },
    });
    const winnerBefore = await quote.read.balanceOf([buyerTwo.account.address]);
    await wait(
      publicClient,
      winnerRaffle.write.redeemWinningTicket([buyerTwo.account.address]),
    );
    assert.equal(
      (await quote.read.balanceOf([buyerTwo.account.address])) - winnerBefore,
      1_520_000n,
    );
    await assert.rejects(raffle.read.ownerOf([2n]));

    const sponsorRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: sponsor },
    });
    await wait(
      publicClient,
      sponsorRaffle.write.claimSponsorPrize([sponsor.account.address]),
    );
    assertAddressEqual(await prize.read.ownerOf([1n]), sponsor.account.address);
  });

  it("enables refunds once and burns each bearer ticket for exact USDC", async () => {
    const { networkHelpers, viem } = await network.create({
      network: "hardhatBase",
    });
    const publicClient = await viem.getPublicClient();
    const [owner, sponsor, buyer, recovery, treasury, finalizer] =
      await viem.getWalletClients();
    assert.ok(owner && sponsor && buyer && recovery && treasury && finalizer);

    const quote = await viem.deployContract("MockERC20");
    const prize = await viem.deployContract("MockERC721");
    const entropy = await viem.deployContract("MockEntropyV2");
    const factory = await viem.deployContract("RaffleFactory", [
      quote.address,
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

    await networkHelpers.time.increaseTo(
      await raffle.read.requestGraceDeadline(),
    );
    const finalizerRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: finalizer },
    });
    await wait(publicClient, finalizerRaffle.write.enableRefunds());
    assert.equal(await raffle.read.status(), 5);
    assert.equal(await raffle.read.remainingRefundLiability(), 2_000_000n);

    const before = await quote.read.balanceOf([buyer.account.address]);
    await wait(
      publicClient,
      buyerRaffle.write.redeemRefundTickets([[1n, 2n], buyer.account.address]),
    );
    assert.equal(
      (await quote.read.balanceOf([buyer.account.address])) - before,
      2_000_000n,
    );
    assert.equal(await raffle.read.remainingRefundLiability(), 0n);

    const recoveryRaffle = await viem.getContractAt("Raffle", raffleAddress, {
      client: { wallet: recovery },
    });
    await wait(
      publicClient,
      recoveryRaffle.write.claimSponsorPrize([recovery.account.address]),
    );
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
