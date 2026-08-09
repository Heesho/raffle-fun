import type { Account, Address, Hash, PublicClient, WalletClient } from "viem";

import { raffleAbi, raffleFactoryAbi } from "./abis/generated.js";
import { MAX_REFUND_REDEMPTION_BATCH_SIZE } from "./math/economics.js";
import {
  ProtocolOwnedClaim,
  type CreateRaffleParams,
} from "./types/protocol.js";

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

export async function buyTickets(
  context: ActionContext,
  raffle: Address,
  recipient: Address,
  quantity: bigint,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "buyTickets",
    args: [recipient, quantity],
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

export async function enableRefunds(
  context: ActionContext,
  raffle: Address,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "enableRefunds",
  });
  return context.walletClient.writeContract(request);
}

export async function redeemRefundTickets(
  context: ActionContext,
  raffle: Address,
  ticketIds: readonly bigint[],
  to: Address,
): Promise<Hash> {
  validateRefundTicketIds(ticketIds);
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "redeemRefundTickets",
    args: [ticketIds, to],
  });
  return context.walletClient.writeContract(request);
}

export async function closeEmptyRaffle(
  context: ActionContext,
  raffle: Address,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "closeEmptyRaffle",
  });
  return context.walletClient.writeContract(request);
}

export async function redeemWinningTicket(
  context: ActionContext,
  raffle: Address,
  to: Address,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "redeemWinningTicket",
    args: [to],
  });
  return context.walletClient.writeContract(request);
}

export async function recoverProtocolOwnedClaim(
  context: ActionContext,
  holderRaffle: Address,
  targetRaffle: Address,
  claim: ProtocolOwnedClaim,
  refundTicketIds: readonly bigint[],
): Promise<Hash> {
  if (claim === ProtocolOwnedClaim.RefundTickets) {
    validateRefundTicketIds(refundTicketIds);
  }
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: holderRaffle,
    abi: raffleAbi,
    functionName: "recoverProtocolOwnedClaim",
    args: [targetRaffle, claim, refundTicketIds],
  });
  return context.walletClient.writeContract(request);
}

export async function claimSponsorPrize(
  context: ActionContext,
  raffle: Address,
  to: Address,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "claimSponsorPrize",
    args: [to],
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

export async function claimQuoteFor(
  context: ActionContext,
  raffle: Address,
  account: Address,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "claimQuoteFor",
    args: [account],
  });
  return context.walletClient.writeContract(request);
}

/**
 * Rejects refund batches that cannot succeed atomically onchain.
 *
 * Duplicate bearer-ticket IDs would make the second burn revert, so detecting them before simulation produces a
 * deterministic SDK error and avoids an unnecessary RPC request.
 */
export function validateRefundTicketIds(ticketIds: readonly bigint[]): void {
  if (
    ticketIds.length === 0 ||
    BigInt(ticketIds.length) > MAX_REFUND_REDEMPTION_BATCH_SIZE
  ) {
    throw new RangeError(
      `refundTicketIds must contain between 1 and ${MAX_REFUND_REDEMPTION_BATCH_SIZE.toString()} entries`,
    );
  }

  const seen = new Set<bigint>();
  for (const ticketId of ticketIds) {
    if (ticketId <= 0n) {
      throw new RangeError("refund ticket IDs must be positive");
    }
    if (seen.has(ticketId)) {
      throw new RangeError(
        `duplicate refund ticket ID: ${ticketId.toString()}`,
      );
    }
    seen.add(ticketId);
  }
}
