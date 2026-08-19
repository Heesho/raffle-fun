"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  Check,
  CircleDollarSign,
  Dices,
  ExternalLink,
  Gift,
  LoaderCircle,
  Minus,
  Plus,
  ShoppingBag,
  Undo2,
} from "lucide-react";
import Link from "next/link";
import { useMemo, useState } from "react";
import {
  encodeFunctionData,
  erc20Abi,
  isAddress,
  zeroAddress,
  type Abi,
  type Address,
  type ContractFunctionParameters,
  type Hash,
} from "viem";
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useReadContracts,
  useWalletClient,
} from "wagmi";

import {
  buyEntries,
  calculatePurchaseAmounts,
  calculateResolutionAmounts,
  enableRefunds,
  ENTRY_PRICE,
  MAX_UINT128,
  raffleAbi,
  raffleFactoryAbi,
  raffleStatusLabels,
  ticketRangeContainsEntry,
  redeemWinningTicket,
  refundTickets,
  releaseProtocolFees,
  releaseSponsorPrize,
  releaseSponsorProceeds,
  settleWinningTicket,
  requestDraw,
  RaffleStatus,
  type ActionContext,
} from "@raffle-fun/sdk";

import { SandboxPanel } from "@/components/sandbox/sandbox-panel";
import type { StatusTone } from "@/components/status-pill";
import { WalletButton } from "@/components/wallet-button";
import { useNowMs } from "@/hooks/use-now";
import { useTokenMetadata } from "@/hooks/use-token-metadata";
import { isDemoMode } from "@/lib/demo";
import { formatTokenAmount } from "@/lib/format";
import {
  configuredChain,
  configuredChainId,
  explorerTransactionUrl,
  protocolDeployment,
} from "@/lib/protocol";
import { SANDBOX_USDC } from "@/lib/sandbox/adapter";
import { drawRequestDeadline, entriesOwnedBy } from "@/lib/sandbox/engine";
import { useSandbox, useSandboxRaffle } from "@/lib/sandbox/store";
import { fetchOwnedTicketRanges, isSubgraphConfigured } from "@/lib/subgraph";

import {
  InvalidState,
  RaffleLayout,
  type RaffleViewModel,
} from "./raffle-view";

// Widen only high-cardinality batch reads so TypeScript does not expand the
// complete generated function union for every item.
const batchRaffleAbi: Abi = raffleAbi;

function raffleRead(
  address: Address,
  functionName: string,
  args?: readonly unknown[],
): ContractFunctionParameters {
  return args === undefined
    ? { address, abi: batchRaffleAbi, functionName }
    : { address, abi: batchRaffleAbi, functionName, args };
}

interface LiveRaffleView {
  readonly registered: boolean;
  readonly raffle: Address;
  readonly factoryId: bigint;
  readonly status: RaffleStatus;
  readonly sponsor: Address;
  readonly sponsorRecipient: Address;
  readonly protocolTreasury: Address;
  readonly quoteToken: Address;
  readonly prizeToken: Address;
  readonly prizeTokenId: bigint;
  readonly reserveEntries: bigint;
  readonly endTime: bigint;
  readonly drawRequestDeadline: bigint;
  readonly totalEntries: bigint;
  readonly ticketCount: bigint;
  readonly grossSales: bigint;
  readonly unsettledPot: bigint;
  readonly remainingRefundLiability: bigint;
  readonly winnerProceeds: bigint;
  readonly sponsorProceeds: bigint;
  readonly protocolFees: bigint;
  readonly vrfRequestId: bigint;
  readonly drawRequestedAt: bigint;
  readonly resolvedAt: bigint;
  readonly winningEntry: bigint;
  readonly winningTicketId: bigint;
  readonly settlementComplete: boolean;
  readonly winnerRedeemed: boolean;
  readonly prizeClaimed: boolean;
  readonly callbackDeadline: bigint;
  readonly accountedQuoteBalance: bigint;
  readonly accountTicketBalance: bigint;
}

type ActionProgress =
  | { readonly kind: "idle" }
  | { readonly kind: "pending"; readonly text: string }
  | { readonly kind: "batch"; readonly id: string }
  | {
      readonly kind: "success";
      readonly hash: Hash;
      readonly indexing: boolean;
    }
  | { readonly kind: "error"; readonly text: string };

function parsePositiveBigInt(value: string, label: string): bigint {
  if (!/^[1-9]\d*$/.test(value))
    throw new Error(`${label} must be a positive integer.`);
  return BigInt(value);
}

function parseTicketIds(value: string): readonly bigint[] {
  const values = value
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean);
  if (values.length === 0 || values.length > 100) {
    throw new Error("Enter between one and 100 ticket IDs.");
  }
  const ids = values.map((part) => parsePositiveBigInt(part, "Ticket ID"));
  if (new Set(ids.map(String)).size !== ids.length) {
    throw new Error("Do not include a ticket ID more than once.");
  }
  return ids;
}

function formatDeadline(timestamp: bigint): string {
  if (timestamp === 0n) return "Not set";
  return new Date(Number(timestamp) * 1_000).toLocaleString();
}

function stateTone(status: RaffleStatus): StatusTone {
  if (status === RaffleStatus.Active) return "active";
  if (status === RaffleStatus.NftWon || status === RaffleStatus.CashWon)
    return "resolved";
  if (status === RaffleStatus.Drawing || status === RaffleStatus.Refunding)
    return "warning";
  return "neutral";
}

export function RaffleDetail({
  raffleAddress,
}: {
  readonly raffleAddress: string;
}) {
  return isDemoMode() ? (
    <SandboxRaffleDetail address={raffleAddress} />
  ) : (
    <LiveRaffleDetail raffleAddress={raffleAddress} />
  );
}

function SandboxRaffleDetail({ address }: { readonly address: string }) {
  const raffle = useSandboxRaffle(address);
  const { sandbox } = useSandbox();
  const now = useNowMs();
  if (raffle === undefined || sandbox === undefined || now === undefined) {
    return <LoadingRaffle />;
  }

  const tones: Record<string, StatusTone> = {
    ACTIVE: "active",
    DRAWING: "warning",
    NFT_WON: "resolved",
    CASH_WON: "resolved",
    REFUNDING: "warning",
  };
  const refundReady =
    (raffle.status === "ACTIVE" &&
      ((raffle.totalEntries === 0n && now >= raffle.endTime) ||
        (raffle.totalEntries > 0n && now >= drawRequestDeadline(raffle)))) ||
    (raffle.status === "DRAWING" &&
      raffle.callbackDeadline !== null &&
      now >= raffle.callbackDeadline);
  const view: RaffleViewModel = {
    address: raffle.id as Address,
    factoryId: raffle.factoryId,
    sponsor: raffle.sponsor as Address,
    quoteToken: SANDBOX_USDC.address as Address,
    prizeToken: raffle.prizeToken as Address,
    prizeTokenId: raffle.prizeTokenId,
    prizeName: raffle.prizeName,
    prizeCollection: raffle.prizeCollection,
    prizeImage: raffle.prizeImage,
    prizePixelated: raffle.prizePixelated,
    entryPrice: ENTRY_PRICE,
    reserveEntries: raffle.reserveEntries,
    totalEntries: raffle.totalEntries,
    grossSales: raffle.grossSales,
    unsettledPot: raffle.unsettledPot,
    endTime: BigInt(Math.floor(raffle.endTime / 1_000)),
    stateLabel: refundReady
      ? "refund ready"
      : raffle.status.replaceAll("_", " ").toLowerCase(),
    stateTone: refundReady ? "warning" : (tones[raffle.status] ?? "neutral"),
    isActive: raffle.status === "ACTIVE" && now < raffle.endTime,
    isRefunding: raffle.status === "REFUNDING",
    refundReady,
    outcomeLabel:
      raffle.status === "NFT_WON" || raffle.status === "CASH_WON"
        ? raffle.status.replaceAll("_", " ").toLowerCase()
        : undefined,
    winningEntry: raffle.winningEntry ?? undefined,
    accountEntryBalance: entriesOwnedBy(raffle, sandbox.player),
  };

  return (
    <RaffleLayout
      aside={<SandboxPanel raffle={raffle} />}
      footnote={
        <p className="px-2 text-xs leading-5 text-[var(--ink-3)]">
          One ticket represents one purchase range and remains transferable
          until its owner burns it during winner redemption or a refund.{" "}
          <Link className="font-bold underline" href="/docs">
            Read the full mechanics.
          </Link>
        </p>
      }
      token={SANDBOX_USDC}
      view={view}
    />
  );
}

function LiveRaffleDetail({
  raffleAddress,
}: {
  readonly raffleAddress: string;
}) {
  const validRaffle = isAddress(raffleAddress);
  const raffle = validRaffle ? (raffleAddress as Address) : undefined;
  const { address, chainId, isConnected } = useAccount();
  const publicClient = usePublicClient();
  const wallet = useWalletClient();
  const queryClient = useQueryClient();
  const latestBlockTimeQuery = useQuery({
    queryKey: ["latest-block-time", configuredChainId],
    queryFn: async () => (await publicClient!.getBlock()).timestamp,
    enabled: publicClient !== undefined,
    refetchInterval: 12_000,
  });
  const currentTime = latestBlockTimeQuery.data;
  const [entryCountText, setEntryCountText] = useState("20");
  const [recipient, setRecipient] = useState("");
  const [refundTicketIds, setRefundTicketIds] = useState("");
  const [winningTicketProof, setWinningTicketProof] = useState("");
  const [progress, setProgress] = useState<ActionProgress>({ kind: "idle" });
  const parsedWinningTicketId = /^[1-9]\d*$/.test(winningTicketProof)
    ? BigInt(winningTicketProof)
    : undefined;
  const indexConfigured = isSubgraphConfigured();
  const ownedTicketQuery = useQuery({
    queryKey: [
      "owned-ticket-ranges",
      raffle?.toLowerCase(),
      address?.toLowerCase(),
    ],
    queryFn: () => fetchOwnedTicketRanges(raffle!, address!),
    enabled: indexConfigured && raffle !== undefined && address !== undefined,
    refetchInterval: 15_000,
  });
  const winningTicketRangeQuery = useReadContract({
    address: raffle,
    abi: raffleAbi,
    functionName: "ticketRange",
    args: [parsedWinningTicketId ?? 0n],
    query: {
      enabled: raffle !== undefined && parsedWinningTicketId !== undefined,
    },
  });

  const contracts: readonly ContractFunctionParameters[] =
    raffle === undefined || protocolDeployment === undefined
      ? []
      : [
          {
            address: protocolDeployment.raffleFactory,
            abi: raffleFactoryAbi,
            functionName: "isRaffle",
            args: [raffle],
          },
          raffleRead(raffle, "raffleId"),
          raffleRead(raffle, "status"),
          raffleRead(raffle, "sponsor"),
          raffleRead(raffle, "sponsorRecipient"),
          raffleRead(raffle, "protocolTreasury"),
          raffleRead(raffle, "quoteToken"),
          raffleRead(raffle, "prizeToken"),
          raffleRead(raffle, "prizeTokenId"),
          raffleRead(raffle, "reserveEntries"),
          raffleRead(raffle, "endTime"),
          raffleRead(raffle, "drawRequestDeadline"),
          raffleRead(raffle, "totalEntries"),
          raffleRead(raffle, "ticketCount"),
          raffleRead(raffle, "grossSales"),
          raffleRead(raffle, "unsettledPot"),
          raffleRead(raffle, "remainingRefundLiability"),
          raffleRead(raffle, "winnerRecipient"),
          raffleRead(raffle, "winnerProceeds"),
          raffleRead(raffle, "sponsorProceeds"),
          raffleRead(raffle, "protocolFees"),
          raffleRead(raffle, "vrfRequestId"),
          raffleRead(raffle, "drawRequestedAt"),
          raffleRead(raffle, "resolvedAt"),
          raffleRead(raffle, "winningEntry"),
          raffleRead(raffle, "winningTicketId"),
          raffleRead(raffle, "settlementComplete"),
          raffleRead(raffle, "winnerRedeemed"),
          raffleRead(raffle, "prizeClaimed"),
          raffleRead(raffle, "callbackDeadline"),
          raffleRead(raffle, "accountedQuoteBalance"),
          raffleRead(raffle, "balanceOf", [address ?? zeroAddress]),
        ];

  const viewQuery = useReadContracts({
    allowFailure: true,
    contracts,
    query: { enabled: contracts.length > 0, refetchInterval: 12_000 },
  });

  const view = useMemo<LiveRaffleView | undefined>(() => {
    if (raffle === undefined || viewQuery.data === undefined) return undefined;
    const value = <T,>(index: number): T | undefined => {
      const result = viewQuery.data[index];
      return result?.status === "success" ? (result.result as T) : undefined;
    };
    // Every contract read that drives state, economics, or write eligibility must
    // succeed together. A partial multicall is not a zero-valued protocol state.
    if (
      viewQuery.data.length < 31 ||
      viewQuery.data
        .slice(0, 31)
        .some(
          (result) =>
            result?.status !== "success" || result.result === undefined,
        )
    ) {
      return undefined;
    }
    const registered = value<boolean>(0);
    const factoryId = value<bigint>(1);
    const status = value<number>(2);
    const sponsor = value<Address>(3);
    const sponsorRecipient = value<Address>(4);
    const protocolTreasury = value<Address>(5);
    const quoteToken = value<Address>(6);
    const prizeToken = value<Address>(7);
    const prizeTokenId = value<bigint>(8);
    if (
      registered === undefined ||
      factoryId === undefined ||
      status === undefined ||
      sponsor === undefined ||
      sponsorRecipient === undefined ||
      protocolTreasury === undefined ||
      quoteToken === undefined ||
      prizeToken === undefined ||
      prizeTokenId === undefined
    )
      return undefined;
    return {
      registered,
      raffle,
      factoryId,
      status: status as RaffleStatus,
      sponsor,
      sponsorRecipient,
      protocolTreasury,
      quoteToken,
      prizeToken,
      prizeTokenId,
      reserveEntries: value<bigint>(9) ?? 0n,
      endTime: value<bigint>(10) ?? 0n,
      drawRequestDeadline: value<bigint>(11) ?? 0n,
      totalEntries: value<bigint>(12) ?? 0n,
      ticketCount: value<bigint>(13) ?? 0n,
      grossSales: value<bigint>(14) ?? 0n,
      unsettledPot: value<bigint>(15) ?? 0n,
      remainingRefundLiability: value<bigint>(16) ?? 0n,
      winnerProceeds: value<bigint>(18) ?? 0n,
      sponsorProceeds: value<bigint>(19) ?? 0n,
      protocolFees: value<bigint>(20) ?? 0n,
      vrfRequestId: value<bigint>(21) ?? 0n,
      drawRequestedAt: value<bigint>(22) ?? 0n,
      resolvedAt: value<bigint>(23) ?? 0n,
      winningEntry: value<bigint>(24) ?? 0n,
      winningTicketId: value<bigint>(25) ?? 0n,
      settlementComplete: value<boolean>(26) ?? false,
      winnerRedeemed: value<boolean>(27) ?? false,
      prizeClaimed: value<boolean>(28) ?? false,
      callbackDeadline: value<bigint>(29) ?? 0n,
      accountedQuoteBalance: value<bigint>(30) ?? 0n,
      accountTicketBalance: value<bigint>(31) ?? 0n,
    };
  }, [raffle, viewQuery.data]);

  const tokenMetadata = useTokenMetadata(view?.quoteToken);
  const indexedEntryBalance = useMemo(() => {
    if (address === undefined || ownedTicketQuery.data === undefined) {
      return undefined;
    }
    if (ownedTicketQuery.data.some((ticket) => ticket.entryCount === null)) {
      return undefined;
    }
    return ownedTicketQuery.data.reduce(
      (total, ticket) => total + BigInt(ticket.entryCount!),
      0n,
    );
  }, [address, ownedTicketQuery.data]);
  const indexedWinningTicket = useMemo(() => {
    if (view === undefined || view.winningEntry === 0n) return undefined;
    return ownedTicketQuery.data?.find(
      (ticket) =>
        ticket.firstEntry !== null &&
        ticket.lastEntry !== null &&
        view.winningEntry >= BigInt(ticket.firstEntry) &&
        view.winningEntry <= BigInt(ticket.lastEntry),
    );
  }, [ownedTicketQuery.data, view]);
  const parsedEntryCount = /^[1-9]\d*$/.test(entryCountText)
    ? BigInt(entryCountText)
    : undefined;
  const purchaseAmounts = useMemo(() => {
    if (parsedEntryCount === undefined || parsedEntryCount > MAX_UINT128)
      return undefined;
    return calculatePurchaseAmounts({ entryCount: parsedEntryCount });
  }, [parsedEntryCount]);

  async function finish(hash: Hash) {
    if (publicClient === undefined) return;
    setProgress({ kind: "pending", text: "Waiting for confirmation…" });
    await publicClient.waitForTransactionReceipt({ hash });
    await Promise.all([
      viewQuery.refetch(),
      ...(indexConfigured ? [ownedTicketQuery.refetch()] : []),
      queryClient.invalidateQueries({ queryKey: ["raffles"] }),
    ]);
    setProgress({ kind: "success", hash, indexing: isSubgraphConfigured() });
  }

  function actionContext() {
    if (
      publicClient === undefined ||
      wallet.data === undefined ||
      address === undefined
    ) {
      throw new Error("Connect a wallet before submitting this action.");
    }
    if (chainId !== configuredChainId) {
      throw new Error(`Switch your wallet to ${configuredChain.name}.`);
    }
    return {
      publicClient,
      walletClient: wallet.data,
      account: address,
    } as unknown as ActionContext & { readonly account: Address };
  }

  async function readCore() {
    if (publicClient === undefined || raffle === undefined)
      throw new Error("Raffle unavailable.");
    const [status, endTime, totalEntries] = await Promise.all([
      publicClient.readContract({
        address: raffle,
        abi: raffleAbi,
        functionName: "status",
      }),
      publicClient.readContract({
        address: raffle,
        abi: raffleAbi,
        functionName: "endTime",
      }),
      publicClient.readContract({
        address: raffle,
        abi: raffleAbi,
        functionName: "totalEntries",
      }),
    ]);
    return {
      status: status as RaffleStatus,
      endTime: endTime as bigint,
      totalEntries: totalEntries as bigint,
    };
  }

  async function handleBuy() {
    if (
      raffle === undefined ||
      parsedEntryCount === undefined ||
      purchaseAmounts === undefined ||
      view === undefined
    ) {
      setProgress({
        kind: "error",
        text: "Enter a positive uint128 entry count.",
      });
      return;
    }
    setProgress({
      kind: "pending",
      text: "Checking live raffle and allowance…",
    });
    try {
      const context = actionContext();
      const live = await readCore();
      const block = await context.publicClient.getBlock();
      if (
        live.status !== RaffleStatus.Active ||
        block.timestamp >= live.endTime
      ) {
        throw new Error("Entry sales are not open onchain.");
      }
      if (parsedEntryCount > MAX_UINT128 - live.totalEntries) {
        throw new Error(
          "That purchase exceeds the remaining uint128 entry range.",
        );
      }
      const to =
        recipient.trim() === ""
          ? context.account
          : isAddress(recipient)
            ? recipient
            : undefined;
      if (to === undefined || to === zeroAddress)
        throw new Error("Enter a valid ticket recipient.");
      const allowance = await context.publicClient.readContract({
        address: view.quoteToken,
        abi: erc20Abi,
        functionName: "allowance",
        args: [context.account, raffle],
      });
      if (allowance < purchaseAmounts.grossAmount) {
        const calls = [
          {
            to: view.quoteToken,
            data: encodeFunctionData({
              abi: erc20Abi,
              functionName: "approve",
              args: [raffle, purchaseAmounts.grossAmount],
            }),
          },
          {
            to: raffle,
            data: encodeFunctionData({
              abi: raffleAbi,
              functionName: "buyEntries",
              args: [to, parsedEntryCount],
            }),
          },
        ] as const;
        try {
          await context.publicClient.simulateCalls({
            account: context.account,
            calls,
          });
          const { id } = await context.walletClient.sendCalls({
            account: context.account,
            calls,
            experimental_fallback: true,
          });
          setProgress({ kind: "batch", id });
          return;
        } catch {
          setProgress({
            kind: "pending",
            text: `Confirm the ${tokenMetadata.symbol} approval first…`,
          });
          const { request } = await context.publicClient.simulateContract({
            account: context.account,
            address: view.quoteToken,
            abi: erc20Abi,
            functionName: "approve",
            args: [raffle, purchaseAmounts.grossAmount],
          });
          const approvalHash =
            await context.walletClient.writeContract(request);
          await context.publicClient.waitForTransactionReceipt({
            hash: approvalHash,
          });
        }
      }
      setProgress({ kind: "pending", text: "Simulating entry purchase…" });
      await finish(await buyEntries(context, raffle, to, parsedEntryCount));
    } catch (error) {
      setProgress({
        kind: "error",
        text: error instanceof Error ? error.message : "Entry purchase failed.",
      });
    }
  }

  async function handleAction(
    action:
      | "draw"
      | "settleWinner"
      | "redeemWinner"
      | "sponsorPrize"
      | "sponsorProceeds"
      | "protocolFees"
      | "refunds"
      | "refund",
  ) {
    if (raffle === undefined || view === undefined) return;
    setProgress({ kind: "pending", text: "Checking current onchain state…" });
    try {
      const context = actionContext();
      let hash: Hash;
      if (action === "draw") {
        hash = await requestDraw(context, raffle);
      } else if (action === "refunds") {
        hash = await enableRefunds(context, raffle);
      } else if (action === "refund") {
        const ticketIds = parseTicketIds(refundTicketIds);
        hash = await refundTickets(context, raffle, ticketIds);
      } else if (action === "sponsorProceeds") {
        hash = await releaseSponsorProceeds(context, raffle);
      } else if (action === "protocolFees") {
        hash = await releaseProtocolFees(context, raffle);
      } else if (action === "settleWinner" || action === "redeemWinner") {
        const ticketId =
          winningTicketProof.trim() === "" && view.settlementComplete
            ? view.winningTicketId
            : parsePositiveBigInt(winningTicketProof, "Winning ticket ID");
        if (ticketId === 0n) throw new Error("Enter the winning ticket ID.");
        const [firstEntry, lastEntry] =
          (await context.publicClient.readContract({
            address: raffle,
            abi: raffleAbi,
            functionName: "ticketRange",
            args: [ticketId],
          })) as readonly [bigint, bigint];
        if (
          !ticketRangeContainsEntry(
            { firstEntry, lastEntry },
            view.winningEntry,
          )
        ) {
          throw new Error(
            "That ticket range does not contain the winning entry.",
          );
        }
        hash =
          action === "settleWinner"
            ? await settleWinningTicket(context, raffle, ticketId)
            : await redeemWinningTicket(context, raffle, ticketId);
      } else {
        hash = await releaseSponsorPrize(context, raffle);
      }
      await finish(hash);
    } catch (error) {
      setProgress({
        kind: "error",
        text: error instanceof Error ? error.message : "Transaction failed.",
      });
    }
  }

  if (!validRaffle)
    return (
      <InvalidState
        title="Invalid raffle address"
        detail="Use a full EVM address."
      />
    );
  if (protocolDeployment === undefined) {
    return (
      <InvalidState
        title="Protocol not deployed"
        detail={`There is no verified deployment registered for ${configuredChain.name}.`}
      />
    );
  }
  if (viewQuery.isPending) return <LoadingRaffle />;
  if (viewQuery.isError || view === undefined || !view.registered) {
    return (
      <InvalidState
        title="Raffle not found"
        detail="This address is not registered by the canonical factory, or the direct contract reads failed."
      />
    );
  }

  const now = currentTime ?? 0n;
  const canBuy =
    currentTime !== undefined &&
    view.status === RaffleStatus.Active &&
    now < view.endTime;
  const canDraw =
    currentTime !== undefined &&
    view.status === RaffleStatus.Active &&
    view.totalEntries > 0n &&
    now >= view.endTime &&
    now < view.drawRequestDeadline;
  const canEnableRefunds =
    (view.status === RaffleStatus.Active &&
      view.totalEntries === 0n &&
      ((currentTime !== undefined && now >= view.endTime) ||
        address?.toLowerCase() === view.sponsor.toLowerCase())) ||
    (view.status === RaffleStatus.Active &&
      view.totalEntries > 0n &&
      currentTime !== undefined &&
      now >= view.drawRequestDeadline) ||
    (view.status === RaffleStatus.Drawing &&
      currentTime !== undefined &&
      view.callbackDeadline > 0n &&
      now >= view.callbackDeadline);
  const refundReady =
    currentTime !== undefined &&
    ((view.status === RaffleStatus.Active &&
      ((view.totalEntries === 0n && now >= view.endTime) ||
        (view.totalEntries > 0n && now >= view.drawRequestDeadline))) ||
      (view.status === RaffleStatus.Drawing &&
        view.callbackDeadline > 0n &&
        now >= view.callbackDeadline));
  const canReleaseSponsorPrize =
    !view.prizeClaimed &&
    (view.status === RaffleStatus.CashWon ||
      view.status === RaffleStatus.Refunding);

  const model: RaffleViewModel = {
    address: view.raffle,
    factoryId: view.factoryId.toString(),
    sponsor: view.sponsor,
    quoteToken: view.quoteToken,
    prizeToken: view.prizeToken,
    prizeTokenId: view.prizeTokenId.toString(),
    entryPrice: ENTRY_PRICE,
    reserveEntries: view.reserveEntries,
    totalEntries: view.totalEntries,
    grossSales: view.grossSales,
    unsettledPot: view.unsettledPot,
    endTime: view.endTime,
    stateLabel: refundReady ? "refund ready" : raffleStatusLabels[view.status],
    stateTone: refundReady ? "warning" : stateTone(view.status),
    isActive: canBuy,
    isRefunding: view.status === RaffleStatus.Refunding,
    refundReady,
    outcomeLabel:
      view.status === RaffleStatus.NftWon ||
      view.status === RaffleStatus.CashWon
        ? raffleStatusLabels[view.status]
        : undefined,
    winningEntry: view.winningEntry === 0n ? undefined : view.winningEntry,
    accountEntryBalance: indexedEntryBalance,
  };
  const projectedSettlement =
    purchaseAmounts === undefined || parsedEntryCount === undefined
      ? undefined
      : calculateResolutionAmounts(
          view.unsettledPot + purchaseAmounts.grossAmount,
          view.totalEntries + parsedEntryCount >= view.reserveEntries,
        );

  return (
    <RaffleLayout
      aside={
        <>
          <section className="card p-6">
            <p className="eyebrow">Your action</p>
            <h2 className="mt-2 text-2xl">Buy entries</h2>
            <EntryStepper
              disabled={!canBuy}
              onChange={setEntryCountText}
              value={entryCountText}
            />
            <label className="mt-4 block">
              <span className="field-label">Ticket owner (optional)</span>
              <input
                className="input numeric"
                onChange={(event) => setRecipient(event.target.value)}
                placeholder={address ?? "0x…"}
                value={recipient}
              />
            </label>
            {purchaseAmounts && projectedSettlement ? (
              <dl className="mt-5 space-y-2 text-sm">
                <Split
                  label="Entry price"
                  value={formatTokenAmount(
                    ENTRY_PRICE,
                    tokenMetadata.decimals,
                    tokenMetadata.symbol,
                  )}
                />
                <Split
                  label="Total paid"
                  strong
                  value={formatTokenAmount(
                    purchaseAmounts.grossAmount,
                    tokenMetadata.decimals,
                    tokenMetadata.symbol,
                  )}
                />
                <Split label="Ticket NFTs minted" value="1" />
                <Split
                  label="Projected 5% fee"
                  value={formatTokenAmount(
                    projectedSettlement.protocolFee,
                    tokenMetadata.decimals,
                    tokenMetadata.symbol,
                  )}
                />
              </dl>
            ) : null}
            <p className="mt-4 rounded-2xl bg-[var(--yellow-wash)] p-3 text-xs leading-5 text-[var(--ink-soft)]">
              Each purchase gets the next simple ticket ID. Its inclusive entry
              range is stored separately, and purchase gas does not grow with
              entry count.
            </p>
            <div className="perforation my-5" />
            {!isConnected ? (
              <WalletButton full />
            ) : (
              <button
                className="btn btn-primary w-full"
                disabled={
                  !canBuy ||
                  purchaseAmounts === undefined ||
                  progress.kind === "pending"
                }
                onClick={handleBuy}
                type="button"
              >
                <ShoppingBag aria-hidden size={17} /> Buy entries
              </button>
            )}
          </section>

          <section className="card p-6">
            <p className="eyebrow">Settlement</p>
            {view.status === RaffleStatus.Refunding ? (
              <label className="mt-4 block">
                <span className="field-label">
                  Ticket IDs to refund (comma-separated, max 100)
                </span>
                <input
                  className="input numeric"
                  onChange={(event) => setRefundTicketIds(event.target.value)}
                  placeholder="for example: 1, 3, 4"
                  value={refundTicketIds}
                />
                {(ownedTicketQuery.data?.length ?? 0) > 0 ? (
                  <button
                    className="field-hint font-bold underline"
                    onClick={() =>
                      setRefundTicketIds(
                        ownedTicketQuery
                          .data!.slice(0, 100)
                          .map((ticket) => ticket.ticketId)
                          .join(", "),
                      )
                    }
                    type="button"
                  >
                    Use up to 100 of your indexed tickets
                  </button>
                ) : null}
              </label>
            ) : null}
            {view.status === RaffleStatus.NftWon ||
            view.status === RaffleStatus.CashWon ? (
              <label className="mt-4 block">
                <span className="field-label">Winning ticket ID</span>
                <input
                  className="input numeric"
                  onChange={(event) =>
                    setWinningTicketProof(event.target.value)
                  }
                  placeholder="for example: 3"
                  value={winningTicketProof}
                />
                {parsedWinningTicketId !== undefined ? (
                  <span className="field-hint">
                    Range:{" "}
                    {winningTicketRangeQuery.data === undefined
                      ? "reading from chain…"
                      : `${(winningTicketRangeQuery.data as readonly [bigint, bigint])[0].toString()}–${(winningTicketRangeQuery.data as readonly [bigint, bigint])[1].toString()}`}
                  </span>
                ) : null}
                {view.settlementComplete && view.winningTicketId !== 0n ? (
                  <span className="field-hint">
                    Recorded winning ticket: #{view.winningTicketId.toString()}
                  </span>
                ) : null}
                {indexedWinningTicket !== undefined ? (
                  <button
                    className="field-hint font-bold underline"
                    onClick={() =>
                      setWinningTicketProof(indexedWinningTicket.ticketId)
                    }
                    type="button"
                  >
                    Use your indexed winning ticket
                  </button>
                ) : null}
              </label>
            ) : null}
            <div className="mt-4 grid gap-2">
              <ActionButton
                disabled={!canDraw || progress.kind === "pending"}
                icon={<Dices size={17} />}
                label="Request draw · Chainlink fee in ETH"
                onClick={() => handleAction("draw")}
              />
              <ActionButton
                disabled={!canEnableRefunds || progress.kind === "pending"}
                icon={<Undo2 size={17} />}
                label={
                  view.totalEntries === 0n
                    ? "Finalize empty raffle"
                    : "Enable full refunds after timeout"
                }
                onClick={() => handleAction("refunds")}
              />
              <ActionButton
                disabled={
                  view.status !== RaffleStatus.Refunding ||
                  refundTicketIds.trim() === "" ||
                  progress.kind === "pending"
                }
                icon={<CircleDollarSign size={17} />}
                label="Burn tickets & claim refunds"
                onClick={() => handleAction("refund")}
              />
              <ActionButton
                disabled={
                  view.sponsorProceeds === 0n || progress.kind === "pending"
                }
                icon={<CircleDollarSign size={17} />}
                label={`Release ${formatTokenAmount(view.sponsorProceeds, tokenMetadata.decimals, tokenMetadata.symbol)} to sponsor`}
                onClick={() => handleAction("sponsorProceeds")}
              />
              <ActionButton
                disabled={
                  view.protocolFees === 0n || progress.kind === "pending"
                }
                icon={<CircleDollarSign size={17} />}
                label={`Release ${formatTokenAmount(view.protocolFees, tokenMetadata.decimals, tokenMetadata.symbol)} to treasury`}
                onClick={() => handleAction("protocolFees")}
              />
              <ActionButton
                disabled={
                  (view.status !== RaffleStatus.NftWon &&
                    view.status !== RaffleStatus.CashWon) ||
                  view.settlementComplete ||
                  winningTicketProof.trim() === "" ||
                  progress.kind === "pending"
                }
                icon={<Gift size={17} />}
                label="Record winning ticket & allocate balances"
                onClick={() => handleAction("settleWinner")}
              />
              <ActionButton
                disabled={
                  (view.status !== RaffleStatus.NftWon &&
                    view.status !== RaffleStatus.CashWon) ||
                  view.winnerRedeemed ||
                  (winningTicketProof.trim() === "" &&
                    (!view.settlementComplete ||
                      view.winningTicketId === 0n)) ||
                  progress.kind === "pending"
                }
                icon={
                  view.status === RaffleStatus.CashWon ? (
                    <CircleDollarSign size={17} />
                  ) : (
                    <Gift size={17} />
                  )
                }
                label={
                  view.status === RaffleStatus.CashWon
                    ? "Burn winning ticket & redeem cash"
                    : "Burn winning ticket & redeem NFT"
                }
                onClick={() => handleAction("redeemWinner")}
              />
              <ActionButton
                disabled={
                  !canReleaseSponsorPrize || progress.kind === "pending"
                }
                icon={<Gift size={17} />}
                label="Release NFT to sponsor"
                onClick={() => handleAction("sponsorPrize")}
              />
            </div>
          </section>

          <section className="card p-6">
            <p className="eyebrow">Recovery & liabilities</p>
            <dl className="mt-4 space-y-2 text-sm">
              <Split
                label="Purchase tickets"
                value={view.ticketCount.toString()}
              />
              <Split
                label="Your ticket NFTs"
                value={view.accountTicketBalance.toString()}
              />
              <Split
                label="Draw request deadline"
                value={formatDeadline(view.drawRequestDeadline)}
              />
              <Split
                label="Callback deadline"
                value={formatDeadline(view.callbackDeadline)}
              />
              <Split
                label="Remaining refunds"
                value={formatTokenAmount(
                  view.remainingRefundLiability,
                  tokenMetadata.decimals,
                  tokenMetadata.symbol,
                )}
              />
              <Split
                label="Winner proceeds"
                value={formatTokenAmount(
                  view.winnerProceeds,
                  tokenMetadata.decimals,
                  tokenMetadata.symbol,
                )}
              />
              <Split
                label="Sponsor proceeds"
                value={formatTokenAmount(
                  view.sponsorProceeds,
                  tokenMetadata.decimals,
                  tokenMetadata.symbol,
                )}
              />
              <Split
                label="Protocol fees"
                value={formatTokenAmount(
                  view.protocolFees,
                  tokenMetadata.decimals,
                  tokenMetadata.symbol,
                )}
              />
              <Split
                label="Accounted quote"
                strong
                value={formatTokenAmount(
                  view.accountedQuoteBalance,
                  tokenMetadata.decimals,
                  tokenMetadata.symbol,
                )}
              />
            </dl>
          </section>
          {progress.kind !== "idle" ? (
            <ProgressPanel progress={progress} />
          ) : null}
        </>
      }
      footnote={
        <p className="px-2 text-xs leading-5 text-[var(--ink-3)]">
          Anyone may record the winning ticket and allocate balances. The ticket
          stays transferable until its current owner redeems and burns it
          atomically for the prize. Sponsor and treasury payments always go to
          their configured addresses.{" "}
          <Link className="font-bold underline" href="/docs">
            Read the full mechanics.
          </Link>
        </p>
      }
      token={tokenMetadata}
      view={model}
    />
  );
}

function EntryStepper({
  value,
  onChange,
  disabled = false,
}: {
  readonly value: string;
  readonly onChange: (value: string) => void;
  readonly disabled?: boolean;
}) {
  const parsed = /^[1-9]\d*$/.test(value) ? BigInt(value) : 0n;
  const bump = (delta: bigint) =>
    onChange((parsed + delta < 1n ? 1n : parsed + delta).toString());
  return (
    <div className="mt-5">
      <span className="field-label" id="entry-count-label">
        Entries ($1 each)
      </span>
      <div className="flex items-center gap-2">
        <button
          aria-label="Remove one entry"
          className="btn btn-outline !size-12 !min-h-0 shrink-0 !p-0"
          disabled={disabled || parsed <= 1n}
          onClick={() => bump(-1n)}
          type="button"
        >
          <Minus aria-hidden size={18} />
        </button>
        <input
          aria-labelledby="entry-count-label"
          className="input numeric !h-12 text-center !text-lg !font-extrabold"
          disabled={disabled}
          inputMode="numeric"
          onChange={(event) => onChange(event.target.value)}
          pattern="[0-9]*"
          type="text"
          value={value}
        />
        <button
          aria-label="Add one entry"
          className="btn btn-outline !size-12 !min-h-0 shrink-0 !p-0"
          disabled={disabled || parsed >= MAX_UINT128}
          onClick={() => bump(1n)}
          type="button"
        >
          <Plus aria-hidden size={18} />
        </button>
      </div>
      <div className="mt-2 flex gap-1.5">
        {[20n, 100n, 1_000n].map((preset) => (
          <button
            className="chip bg-[var(--paper-sunk)] text-[var(--ink-2)] hover:text-[var(--ink)]"
            disabled={disabled}
            key={preset.toString()}
            onClick={() => onChange(preset.toString())}
            type="button"
          >
            {preset.toString()}
          </button>
        ))}
      </div>
    </div>
  );
}

function Split({
  label,
  value,
  strong = false,
}: {
  readonly label: string;
  readonly value: string;
  readonly strong?: boolean;
}) {
  return (
    <div className="flex items-center justify-between gap-4">
      <dt className={strong ? "font-extrabold" : "text-[var(--ink-2)]"}>
        {label}
      </dt>
      <dd className={`numeric ${strong ? "font-extrabold" : "font-bold"}`}>
        {value}
      </dd>
    </div>
  );
}

function ActionButton({
  icon,
  label,
  disabled,
  onClick,
}: {
  readonly icon: React.ReactNode;
  readonly label: string;
  readonly disabled: boolean;
  readonly onClick: () => void;
}) {
  return (
    <button
      className="btn btn-outline w-full justify-start text-left"
      disabled={disabled}
      onClick={onClick}
      type="button"
    >
      {icon}
      <span>{label}</span>
    </button>
  );
}

function ProgressPanel({
  progress,
}: {
  readonly progress: Exclude<ActionProgress, { kind: "idle" }>;
}) {
  return (
    <div
      className={`card p-5 text-sm ${progress.kind === "error" ? "border-[var(--danger)] bg-[var(--danger-wash)] text-[var(--danger)]" : ""}`}
      role={progress.kind === "error" ? "alert" : "status"}
    >
      {progress.kind === "pending" ? (
        <p className="flex items-center gap-2 font-bold">
          <LoaderCircle aria-hidden className="animate-spin" size={17} />
          {progress.text}
        </p>
      ) : null}
      {progress.kind === "batch" ? (
        <p className="font-bold">
          Wallet batch submitted:{" "}
          <span className="numeric break-all">{progress.id}</span>. Refresh
          after it confirms.
        </p>
      ) : null}
      {progress.kind === "error" ? (
        <p className="font-bold">{progress.text}</p>
      ) : null}
      {progress.kind === "success" ? (
        <p className="font-bold text-[#0d6b45]">
          <Check aria-hidden className="mr-1 inline" size={16} /> Confirmed ·{" "}
          <a
            className="underline"
            href={explorerTransactionUrl(progress.hash)}
            rel="noreferrer"
            target="_blank"
          >
            view transaction <ExternalLink className="inline" size={13} />
          </a>
          {progress.indexing ? " · indexing may take a moment" : ""}
        </p>
      ) : null}
    </div>
  );
}

function LoadingRaffle() {
  return (
    <div className="page-shell py-14" role="status">
      <span className="sr-only">Loading raffle</span>
      <div className="skeleton h-10 w-72 rounded-full" />
      <div className="mt-8 grid gap-7 lg:grid-cols-[1fr_23rem]">
        <div className="skeleton h-[34rem] rounded-3xl" />
        <div className="skeleton h-96 rounded-3xl" />
      </div>
    </div>
  );
}
