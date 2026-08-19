import type { Account, Address, Hash, PublicClient, WalletClient } from "viem";

import { raffleAbi, raffleFactoryAbi } from "./abis/generated.js";
import {
  MAX_REFUND_TICKET_BATCH_SIZE,
  MAX_UINT128,
  MAX_UINT64,
  validateEntryCount,
  validateTicketId,
} from "./math/economics.js";
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
  validateCreateRaffleParams(params);
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: factory,
    abi: raffleFactoryAbi,
    functionName: "createRaffle",
    args: [params],
  });
  return context.walletClient.writeContract(request);
}

export async function buyEntries(
  context: ActionContext,
  raffle: Address,
  recipient: Address,
  entryCount: bigint,
): Promise<Hash> {
  validateEntryCount(entryCount);
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "buyEntries",
    args: [recipient, entryCount],
  });
  return context.walletClient.writeContract(request);
}

export async function requestDraw(
  context: ActionContext,
  raffle: Address,
): Promise<Hash> {
  const estimatedFees = await context.publicClient.estimateFeesPerGas({
    chain: context.publicClient.chain,
    type: "eip1559",
  });
  const requestGasPriceWei = estimatedFees.maxFeePerGas;
  const vrfRequestPrice = await context.publicClient.readContract({
    address: raffle,
    abi: raffleAbi,
    functionName: "estimateVrfRequestPrice",
    args: [requestGasPriceWei],
  });
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "requestDraw",
    value: vrfRequestPrice,
    maxFeePerGas: requestGasPriceWei,
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

export async function refundTickets(
  context: ActionContext,
  raffle: Address,
  ticketIds: readonly bigint[],
): Promise<Hash> {
  validateRefundTicketIds(ticketIds);
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "refundTickets",
    args: [ticketIds],
  });
  return context.walletClient.writeContract(request);
}

export async function settleWinningTicket(
  context: ActionContext,
  raffle: Address,
  ticketId: bigint,
): Promise<Hash> {
  validateTicketId(ticketId);
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "settleWinningTicket",
    args: [ticketId],
  });
  return context.walletClient.writeContract(request);
}

export async function releaseWinnerProceeds(
  context: ActionContext,
  raffle: Address,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "releaseWinnerProceeds",
  });
  return context.walletClient.writeContract(request);
}

export async function releaseWinnerPrize(
  context: ActionContext,
  raffle: Address,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "releaseWinnerPrize",
  });
  return context.walletClient.writeContract(request);
}

export async function releaseSponsorPrize(
  context: ActionContext,
  raffle: Address,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "releaseSponsorPrize",
  });
  return context.walletClient.writeContract(request);
}

export async function releaseSponsorProceeds(
  context: ActionContext,
  raffle: Address,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "releaseSponsorProceeds",
  });
  return context.walletClient.writeContract(request);
}

export async function releaseProtocolFees(
  context: ActionContext,
  raffle: Address,
): Promise<Hash> {
  const { request } = await context.publicClient.simulateContract({
    account: context.account,
    address: raffle,
    abi: raffleAbi,
    functionName: "releaseProtocolFees",
  });
  return context.walletClient.writeContract(request);
}

export function validateCreateRaffleParams(params: CreateRaffleParams): void {
  if (params.prizeTokenId < 0n || params.prizeTokenId > (1n << 256n) - 1n) {
    throw new RangeError("prizeTokenId must fit uint256");
  }
  if (params.reserveEntries <= 0n || params.reserveEntries > MAX_UINT128) {
    throw new RangeError("reserveEntries must be between 1 and uint128 max");
  }
  if (params.endTime <= 0n || params.endTime > MAX_UINT64) {
    throw new RangeError("endTime must be between 1 and uint64 max");
  }
}

/**
 * Rejects refund batches that cannot succeed atomically onchain.
 *
 * Duplicate ticket IDs would make the second burn revert. Ticket IDs are
 * sequential ERC-721 identifiers; their entry ranges live in contract storage.
 */
export function validateRefundTicketIds(ticketIds: readonly bigint[]): void {
  if (
    ticketIds.length === 0 ||
    BigInt(ticketIds.length) > MAX_REFUND_TICKET_BATCH_SIZE
  ) {
    throw new RangeError(
      `ticketIds must contain between 1 and ${MAX_REFUND_TICKET_BATCH_SIZE.toString()} tickets`,
    );
  }

  const seen = new Set<bigint>();
  for (const ticketId of ticketIds) {
    validateTicketId(ticketId);
    if (seen.has(ticketId)) {
      throw new RangeError(
        `duplicate refund ticket ID: ${ticketId.toString()}`,
      );
    }
    seen.add(ticketId);
  }
}

export { validateEntryCount } from "./math/economics.js";
