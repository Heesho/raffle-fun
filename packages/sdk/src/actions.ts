import type { Account, Address, Hash, PublicClient, WalletClient } from "viem";

import { raffleAbi, raffleFactoryAbi } from "./abis/generated.js";
import type { CreateRaffleParams } from "./types/protocol.js";

export interface ActionContext {
  readonly publicClient: PublicClient;
  readonly walletClient: WalletClient;
  readonly account: Account | Address;
}

export async function createRaffle(
  context: ActionContext,
  factory: Address,
  params: CreateRaffleParams,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: factory,
    abi: raffleFactoryAbi,
    functionName: "createRaffle",
    args: [params],
  });
  return context.walletClient.writeContract(request);
}

export async function setQuoteTokenVerification(
  context: ActionContext,
  factory: Address,
  quoteToken: Address,
  verified: boolean,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: factory,
    abi: raffleFactoryAbi,
    functionName: "setQuoteTokenVerification",
    args: [quoteToken, verified],
  });
  return context.walletClient.writeContract(request);
}

export async function buyTickets(
  context: ActionContext,
  raffle: Address,
  recipient: Address,
  quantity: bigint,
  provider: Address,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "buyTickets",
    args: [recipient, quantity, provider],
  });
  return context.walletClient.writeContract(request);
}

export async function requestDraw(
  context: ActionContext,
  raffle: Address,
  entropyFee: bigint,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "requestDraw",
    value: entropyFee,
  });
  return context.walletClient.writeContract(request);
}

export async function closeNoSales(
  context: ActionContext,
  raffle: Address,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "closeNoSales",
  });
  return context.walletClient.writeContract(request);
}

/**
 * The sponsor's only exit. Reverts once a single ticket has been sold, after
 * which the escrowed prize can move only through settlement.
 */
export async function cancelBeforeSales(
  context: ActionContext,
  raffle: Address,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "cancelBeforeSales",
  });
  return context.walletClient.writeContract(request);
}

export async function claimQuote(
  context: ActionContext,
  raffle: Address,
  to: Address,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "claimQuote",
    args: [to],
  });
  return context.walletClient.writeContract(request);
}

export async function claimPrize(
  context: ActionContext,
  raffle: Address,
  to: Address,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "claimPrize",
    args: [to],
  });
  return context.walletClient.writeContract(request);
}

export async function predictRaffleAddress(
  publicClient: PublicClient,
  factory: Address,
  args: {
    readonly raffleId: bigint;
    readonly sponsor: Address;
    readonly quoteToken: Address;
    readonly prizeToken: Address;
    readonly prizeTokenId: bigint;
  },
): Promise<Address> {
  return publicClient.readContract({
    address: factory,
    abi: raffleFactoryAbi,
    functionName: "predictRaffleAddress",
    args: [
      args.raffleId,
      args.sponsor,
      args.quoteToken,
      args.prizeToken,
      args.prizeTokenId,
    ],
  });
}
