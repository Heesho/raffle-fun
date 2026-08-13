"use client";

import { useQueryClient } from "@tanstack/react-query";
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
  type Address,
  type Hash,
} from "viem";
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useWalletClient,
} from "wagmi";

import {
  buyTickets,
  calculatePurchaseAmounts,
  calculateResolutionAmounts,
  claimSponsorPrize,
  claimQuote,
  closeEmptyRaffle,
  enableRefunds,
  formatQuoteAmount,
  raffleAbi,
  raffleLensAbi,
  redeemRefundTickets,
  redeemWinningTicket,
  RaffleStatus,
  raffleStatusLabels,
  requestDraw,
  type ActionContext,
} from "@raffle-fun/sdk";

import type { StatusTone } from "@/components/status-pill";
import { WalletButton } from "@/components/wallet-button";
import { useTokenMetadata } from "@/hooks/use-token-metadata";
import { isDemoMode } from "@/lib/demo";
import { SandboxPanel } from "@/components/sandbox/sandbox-panel";
import { SANDBOX_WETH } from "@/lib/sandbox/adapter";
import { ticketsOwnedBy } from "@/lib/sandbox/engine";
import { useSandbox, useSandboxRaffle } from "@/lib/sandbox/store";
import { formatTokenAmount } from "@/lib/format";
import {
  configuredChain,
  configuredChainId,
  explorerTransactionUrl,
  protocolDeployment,
} from "@/lib/protocol";
import { isSubgraphConfigured } from "@/lib/subgraph";

import {
  InvalidState,
  RaffleLayout,
  type RaffleViewModel,
} from "./raffle-view";

type LiveRaffleView = {
  readonly factoryId: bigint;
  readonly registered: boolean;
  readonly raffle: Address;
  readonly status: number;
  readonly sponsor: Address;
  readonly sponsorPrizeRecoveryRecipient: Address;
  readonly protocolTreasury: Address;
  readonly quoteToken: Address;
  readonly prizeToken: Address;
  readonly prizeTokenId: bigint;
  readonly ticketPrice: bigint;
  readonly minimumTickets: bigint;
  readonly startTime: bigint;
  readonly endTime: bigint;
  readonly requestGraceDeadline: bigint;
  readonly drawRequestedAt: bigint;
  readonly callbackDeadline: bigint;
  readonly nftRedemptionDeadline: bigint;
  readonly resolvedAt: bigint;
  readonly entropySequenceNumber: bigint;
  readonly totalTickets: bigint;
  readonly grossSales: bigint;
  readonly unsettledPot: bigint;
  readonly remainingRefundLiability: bigint;
  readonly winnerCashLiability: bigint;
  readonly totalClaimableQuote: bigint;
  readonly accountedQuoteBalance: bigint;
  readonly winningTicketId: bigint;
  readonly winningTicketOwner: Address;
  readonly winningTicketRedeemed: boolean;
  readonly prizeClaimed: boolean;
  readonly accountTicketBalance: bigint;
  readonly accountQuoteClaim: bigint;
  readonly accountOwnsWinningTicket: boolean;
  readonly accountIsPrizeRecoveryRecipient: boolean;
  readonly entropyFee: bigint;
  readonly entropyFeeAvailable: boolean;
  readonly canBuy: boolean;
  readonly canDraw: boolean;
  readonly canEnableRefunds: boolean;
  readonly canRedeemWinningTicket: boolean;
  readonly canRedeemRefundTickets: boolean;
  readonly canClaimQuote: boolean;
  readonly canClaimSponsorPrize: boolean;
};

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

const MAX_QUANTITY = 100;
const quantityPattern = /^(?:[1-9]|[1-9]\d|100)$/;

function parseRefundTicketIds(value: string): readonly bigint[] {
  const values = value
    .split(",")
    .map((part) => part.trim())
    .filter((part) => part !== "");
  if (values.length === 0 || values.length > 100) {
    throw new Error("Enter between one and 100 ticket IDs.");
  }
  if (values.some((part) => !/^[1-9]\d*$/.test(part))) {
    throw new Error("Ticket IDs must be positive integers.");
  }
  const ticketIds = values.map(BigInt);
  if (new Set(ticketIds.map(String)).size !== ticketIds.length) {
    throw new Error("Do not include a ticket ID more than once.");
  }
  return ticketIds;
}

function resolveDestination(value: string, fallback: Address): Address {
  const destination = value.trim() === "" ? fallback : value;
  if (!isAddress(destination) || destination === zeroAddress) {
    throw new Error("Enter a valid nonzero destination.");
  }
  return destination;
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
  if (isDemoMode()) {
    return <SandboxRaffleDetail address={raffleAddress} />;
  }
  return <LiveRaffleDetail raffleAddress={raffleAddress} />;
}

/* --------------------------------------------------------------- sandbox */

function SandboxRaffleDetail({ address }: { readonly address: string }) {
  const raffle = useSandboxRaffle(address);
  const { sandbox } = useSandbox();

  if (raffle === undefined || sandbox === undefined) {
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

  const tones: Record<string, StatusTone> = {
    ACTIVE: "active",
    DRAWING: "warning",
    NFT_WON: "resolved",
    CASH_WON: "resolved",
    REFUNDING: "warning",
    CLOSED: "neutral",
  };

  const view: RaffleViewModel = {
    address: raffle.id as Address,
    factoryId: raffle.factoryId,
    sponsor: raffle.sponsor as Address,
    quoteToken: SANDBOX_WETH.address as Address,
    prizeToken: raffle.prizeToken as Address,
    prizeTokenId: raffle.prizeTokenId,
    prizeName: raffle.prizeName,
    prizeCollection: raffle.prizeCollection,
    prizeImage: raffle.prizeImage,
    prizePixelated: raffle.prizePixelated,
    ticketPrice: raffle.ticketPrice,
    minimumTickets: BigInt(raffle.minimumTickets),
    totalTickets: BigInt(raffle.tickets.length),
    grossSales: raffle.grossSales,
    unsettledPot: raffle.unsettledPot,
    startTime: BigInt(Math.floor(raffle.startTime / 1000)),
    endTime: BigInt(Math.floor(raffle.endTime / 1000)),
    stateLabel: raffle.status.replaceAll("_", " ").toLowerCase(),
    stateTone: tones[raffle.status] ?? "neutral",
    isActive: raffle.status === "ACTIVE",
    outcomeLabel:
      raffle.status === "NFT_WON" ||
      raffle.status === "CASH_WON" ||
      raffle.status === "CLOSED"
        ? raffle.status.replaceAll("_", " ").toLowerCase()
        : undefined,
    winningTicketId:
      raffle.winningTicketId === null
        ? undefined
        : BigInt(raffle.winningTicketId),
    accountTicketBalance: BigInt(ticketsOwnedBy(raffle, sandbox.player)),
  };

  return (
    <RaffleLayout
      aside={<SandboxPanel raffle={raffle} />}
      footnote={
        <p className="px-2 text-xs leading-5 text-[var(--ink-3)]">
          Ticket ownership locks while randomness is pending and for the
          selected winner after resolution. Refund tickets are transferable.{" "}
          <Link className="font-bold underline" href="/docs">
            Read the full mechanics.
          </Link>
        </p>
      }
      token={SANDBOX_WETH}
      view={view}
    />
  );
}

/* ------------------------------------------------------------------ live */

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
  const [quantity, setQuantity] = useState(1);
  const [recipient, setRecipient] = useState("");
  const [claimDestination, setClaimDestination] = useState("");
  const [refundTicketIds, setRefundTicketIds] = useState("");
  const [progress, setProgress] = useState<ActionProgress>({ kind: "idle" });

  const viewQuery = useReadContract({
    address: protocolDeployment?.raffleLens,
    abi: raffleLensAbi,
    functionName: "getRaffleState",
    args:
      raffle === undefined
        ? undefined
        : [raffle, address === undefined ? zeroAddress : address],
    query: {
      enabled: protocolDeployment !== undefined && raffle !== undefined,
      refetchInterval: 12_000,
    },
  });

  const view = viewQuery.data as LiveRaffleView | undefined;
  const tokenMetadata = useTokenMetadata(view?.quoteToken);
  const parsedQuantity = quantityPattern.test(String(quantity))
    ? BigInt(quantity)
    : undefined;
  const purchaseAmounts = useMemo(() => {
    if (view === undefined || parsedQuantity === undefined) return undefined;
    return calculatePurchaseAmounts({
      ticketPrice: view.ticketPrice,
      quantity: parsedQuantity,
    });
  }, [parsedQuantity, view]);

  async function readLiveView(): Promise<LiveRaffleView> {
    if (
      publicClient === undefined ||
      protocolDeployment === undefined ||
      raffle === undefined
    ) {
      throw new Error("The raffle deployment is not available.");
    }
    return (await publicClient.readContract({
      address: protocolDeployment.raffleLens,
      abi: raffleLensAbi,
      functionName: "getRaffleState",
      args: [raffle, address ?? zeroAddress],
    })) as LiveRaffleView;
  }

  async function finish(hash: Hash) {
    if (publicClient === undefined) return;
    setProgress({ kind: "pending", text: "Waiting for confirmation…" });
    await publicClient.waitForTransactionReceipt({ hash });
    await Promise.all([
      viewQuery.refetch(),
      queryClient.invalidateQueries({ queryKey: ["raffles"] }),
    ]);
    setProgress({
      kind: "success",
      hash,
      indexing: isSubgraphConfigured(),
    });
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

  async function handleBuy() {
    if (
      raffle === undefined ||
      parsedQuantity === undefined ||
      purchaseAmounts === undefined
    ) {
      setProgress({ kind: "error", text: "Enter a quantity from 1 to 100." });
      return;
    }
    setProgress({
      kind: "pending",
      text: "Checking live raffle and allowance…",
    });
    try {
      const context = actionContext();
      const live = await readLiveView();
      if (!live.canBuy) throw new Error("Ticket sales are not open onchain.");
      const to =
        recipient.trim() === ""
          ? context.account
          : isAddress(recipient)
            ? recipient
            : undefined;
      if (to === undefined || to === zeroAddress) {
        throw new Error("Enter a valid nonzero ticket recipient.");
      }
      const allowance = await context.publicClient.readContract({
        address: live.quoteToken,
        abi: erc20Abi,
        functionName: "allowance",
        args: [context.account, raffle],
      });

      if (allowance < purchaseAmounts.grossAmount) {
        const calls = [
          {
            to: live.quoteToken,
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
              functionName: "buyTickets",
              args: [to, parsedQuantity],
            }),
          },
        ] as const;

        try {
          setProgress({
            kind: "pending",
            text: "Simulating approval and purchase as one wallet batch…",
          });
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
          await queryClient.invalidateQueries({ queryKey: ["raffles"] });
          return;
        } catch {
          setProgress({
            kind: "pending",
            text: `Batching is unavailable. Confirm the ${tokenMetadata.symbol} approval first…`,
          });
          const { request } = await context.publicClient.simulateContract({
            account: context.account,
            address: live.quoteToken,
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

      const latest = await readLiveView();
      if (!latest.canBuy) {
        throw new Error(
          "Ticket sales closed before the purchase could be submitted.",
        );
      }
      setProgress({ kind: "pending", text: "Simulating ticket purchase…" });
      const hash = await buyTickets(context, raffle, to, parsedQuantity);
      await finish(hash);
    } catch (error) {
      setProgress({
        kind: "error",
        text:
          error instanceof Error ? error.message : "Ticket purchase failed.",
      });
    }
  }

  async function handleAction(
    action:
      "draw" | "close" | "quote" | "winner" | "sponsor" | "refunds" | "refund",
  ) {
    if (raffle === undefined) return;
    setProgress({ kind: "pending", text: "Checking current onchain state…" });
    try {
      const context = actionContext();
      const live = await readLiveView();
      let hash: Hash;
      if (action === "draw") {
        if (!live.canDraw)
          throw new Error("A draw cannot be requested right now.");
        if (!live.entropyFeeAvailable)
          throw new Error("The oracle fee is currently unavailable.");
        setProgress({
          kind: "pending",
          text: `Simulating draw with ${formatQuoteAmount(live.entropyFee, 18)} ETH oracle fee…`,
        });
        hash = await requestDraw(context, raffle, live.entropyFee);
      } else if (action === "refunds") {
        if (!live.canEnableRefunds) {
          throw new Error(
            "The applicable settlement deadline has not expired.",
          );
        }
        hash = await enableRefunds(context, raffle);
      } else if (action === "refund") {
        if (!live.canRedeemRefundTickets) {
          throw new Error("This raffle is not refunding.");
        }
        const ticketIds = parseRefundTicketIds(refundTicketIds);
        const destination = resolveDestination(
          claimDestination,
          context.account,
        );
        hash = await redeemRefundTickets(
          context,
          raffle,
          ticketIds,
          destination,
        );
      } else if (action === "close") {
        const block = await context.publicClient.getBlock();
        if (live.status !== RaffleStatus.Active || live.totalTickets !== 0n) {
          throw new Error("This raffle is not eligible for no-sales closure.");
        }
        if (
          block.timestamp < live.endTime &&
          context.account.toLowerCase() !== live.sponsor.toLowerCase()
        ) {
          throw new Error("Only the sponsor can close before the sale end.");
        }
        hash = await closeEmptyRaffle(context, raffle);
      } else if (action === "quote") {
        if (!live.canClaimQuote)
          throw new Error("No quote-token claim is available.");
        const destination = resolveDestination(
          claimDestination,
          context.account,
        );
        hash = await claimQuote(context, raffle, destination);
      } else if (action === "winner") {
        if (!live.canRedeemWinningTicket)
          throw new Error("This account does not own the winning ticket.");
        const destination = resolveDestination(
          claimDestination,
          context.account,
        );
        hash = await redeemWinningTicket(context, raffle, destination);
      } else {
        if (!live.canClaimSponsorPrize)
          throw new Error("The sponsor-side NFT recovery is not available.");
        const destination = resolveDestination(
          claimDestination,
          context.account,
        );
        hash = await claimSponsorPrize(context, raffle, destination);
      }
      await finish(hash);
    } catch (error) {
      setProgress({
        kind: "error",
        text: error instanceof Error ? error.message : "Transaction failed.",
      });
    }
  }

  if (!validRaffle) {
    return (
      <InvalidState
        title="Invalid raffle address"
        detail="Use a full EVM address."
      />
    );
  }
  if (protocolDeployment === undefined) {
    return (
      <InvalidState
        title="Protocol not deployed"
        detail={`There is no verified deployment registered for ${configuredChain.name}, so this address cannot be validated as a canonical raffle.`}
      />
    );
  }
  if (viewQuery.isPending) {
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
  if (viewQuery.isError || view === undefined) {
    return (
      <InvalidState
        title="Raffle not found"
        detail="The lens rejected this address or the chain read failed. Only factory-registered raffles are displayed."
      />
    );
  }

  const model: RaffleViewModel = {
    address: view.raffle,
    factoryId: view.factoryId.toString(),
    sponsor: view.sponsor,
    quoteToken: view.quoteToken,
    prizeToken: view.prizeToken,
    prizeTokenId: view.prizeTokenId.toString(),
    ticketPrice: view.ticketPrice,
    minimumTickets: view.minimumTickets,
    totalTickets: view.totalTickets,
    grossSales: view.grossSales,
    unsettledPot: view.unsettledPot,
    startTime: view.startTime,
    endTime: view.endTime,
    stateLabel: raffleStatusLabels[view.status as RaffleStatus],
    stateTone: stateTone(view.status as RaffleStatus),
    isActive: view.status === RaffleStatus.Active,
    outcomeLabel:
      view.status === RaffleStatus.NftWon ||
      view.status === RaffleStatus.CashWon ||
      view.status === RaffleStatus.Closed
        ? raffleStatusLabels[view.status as RaffleStatus]
        : undefined,
    winningTicketId: view.winningTicketId,
    accountTicketBalance: view.accountTicketBalance,
  };

  const projectedSettlement =
    purchaseAmounts === undefined || parsedQuantity === undefined
      ? undefined
      : calculateResolutionAmounts(
          view.unsettledPot + purchaseAmounts.grossAmount,
          view.totalTickets + parsedQuantity >= view.minimumTickets,
        );

  const purchaseDisabled = !view.canBuy || progress.kind === "pending";

  return (
    <RaffleLayout
      aside={
        <>
          <section className="card p-6">
            <p className="eyebrow">Your action</p>
            <h2 className="mt-2 text-2xl">Get tickets</h2>

            <QuantityStepper
              disabled={!view.canBuy}
              onChange={setQuantity}
              quantity={quantity}
            />

            <label className="mt-4 block">
              <span className="field-label">Send tickets to (optional)</span>
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
                  label="Total paid"
                  strong
                  value={formatTokenAmount(
                    purchaseAmounts.grossAmount,
                    tokenMetadata.decimals,
                    tokenMetadata.symbol,
                  )}
                />
                <Split
                  label="Gross pot after purchase"
                  value={formatTokenAmount(
                    view.unsettledPot + purchaseAmounts.grossAmount,
                    tokenMetadata.decimals,
                    tokenMetadata.symbol,
                  )}
                />
                <Split
                  label="Projected settlement fee · 5%"
                  value={formatTokenAmount(
                    projectedSettlement.protocolFee,
                    tokenMetadata.decimals,
                    tokenMetadata.symbol,
                  )}
                />
                <Split
                  label="Projected distributable pot"
                  value={formatTokenAmount(
                    projectedSettlement.distributablePot,
                    tokenMetadata.decimals,
                    tokenMetadata.symbol,
                  )}
                />
              </dl>
            ) : null}

            <p className="mt-4 rounded-2xl bg-[var(--yellow-wash)] p-3 text-xs leading-5 text-[var(--ink-soft)]">
              Purchases add their full amount to the unsettled pot. One 5%
              protocol fee is calculated from aggregate sales when the raffle
              resolves.
            </p>

            <div className="perforation my-5" />

            {!isConnected ? (
              <WalletButton full />
            ) : (
              <button
                className="btn btn-primary w-full"
                disabled={purchaseDisabled}
                onClick={handleBuy}
                type="button"
              >
                <ShoppingBag aria-hidden size={17} /> Buy tickets
              </button>
            )}
          </section>

          <section className="card p-6">
            <p className="eyebrow">Settle or claim</p>
            <label className="mt-4 block">
              <span className="field-label">
                Redemption destination (optional)
              </span>
              <input
                className="input numeric"
                onChange={(event) => setClaimDestination(event.target.value)}
                placeholder={address ?? "0x…"}
                value={claimDestination}
              />
            </label>
            {view.status === RaffleStatus.Refunding ? (
              <label className="mt-4 block">
                <span className="field-label">
                  Ticket IDs to burn (comma-separated, max 100)
                </span>
                <input
                  className="input numeric"
                  onChange={(event) => setRefundTicketIds(event.target.value)}
                  placeholder="1, 2, 3"
                  value={refundTicketIds}
                />
              </label>
            ) : null}
            <div className="mt-4 grid gap-2">
              <ActionButton
                disabled={
                  !view.canDraw ||
                  !view.entropyFeeAvailable ||
                  progress.kind === "pending"
                }
                icon={<Dices size={17} />}
                label={`Request draw · ${formatQuoteAmount(view.entropyFee, 18)} ETH`}
                onClick={() => handleAction("draw")}
              />
              <ActionButton
                disabled={!view.canEnableRefunds || progress.kind === "pending"}
                icon={<Undo2 size={17} />}
                label="Enable refunds after settlement deadline"
                onClick={() => handleAction("refunds")}
              />
              <ActionButton
                disabled={
                  view.status !== RaffleStatus.Active ||
                  view.totalTickets !== 0n ||
                  progress.kind === "pending"
                }
                icon={<Check size={17} />}
                label="Close no-sales raffle"
                onClick={() => handleAction("close")}
              />
              <ActionButton
                disabled={
                  !view.canRedeemRefundTickets ||
                  refundTicketIds.trim() === "" ||
                  progress.kind === "pending"
                }
                icon={<CircleDollarSign size={17} />}
                label="Burn tickets & redeem refund"
                onClick={() => handleAction("refund")}
              />
              <ActionButton
                disabled={!view.canClaimQuote || progress.kind === "pending"}
                icon={<CircleDollarSign size={17} />}
                label={`Claim ${formatTokenAmount(
                  view.accountQuoteClaim,
                  tokenMetadata.decimals,
                  tokenMetadata.symbol,
                )}`}
                onClick={() => handleAction("quote")}
              />
              <ActionButton
                disabled={
                  !view.canRedeemWinningTicket || progress.kind === "pending"
                }
                icon={<Gift size={17} />}
                label="Burn winning ticket & redeem prize"
                onClick={() => handleAction("winner")}
              />
              <ActionButton
                disabled={
                  !view.canClaimSponsorPrize || progress.kind === "pending"
                }
                icon={<Gift size={17} />}
                label="Recover sponsor NFT"
                onClick={() => handleAction("sponsor")}
              />
            </div>
          </section>

          <section className="card p-6">
            <p className="eyebrow">Recovery & liabilities</p>
            <dl className="mt-4 space-y-2 text-sm">
              <Split
                label="Request grace deadline"
                value={formatDeadline(view.requestGraceDeadline)}
              />
              <Split
                label="Draw requested"
                value={formatDeadline(view.drawRequestedAt)}
              />
              <Split
                label="Callback deadline"
                value={formatDeadline(view.callbackDeadline)}
              />
              <Split
                label="NFT redemption deadline"
                value={formatDeadline(view.nftRedemptionDeadline)}
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
                label="Winning cash"
                value={formatTokenAmount(
                  view.winnerCashLiability,
                  tokenMetadata.decimals,
                  tokenMetadata.symbol,
                )}
              />
              <Split
                label="All quote claims"
                value={formatTokenAmount(
                  view.totalClaimableQuote,
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
            <p className="mt-4 break-all text-xs leading-5 text-[var(--ink-2)]">
              Fixed prize recovery: {view.sponsorPrizeRecoveryRecipient}
            </p>
            {!view.entropyFeeAvailable && view.canDraw ? (
              <p className="mt-4 rounded-2xl bg-[var(--amber-wash)] p-3 text-xs font-bold text-[var(--amber-ink)]">
                The oracle fee read is unavailable. The request grace deadline
                and permissionless refund path remain visible above.
              </p>
            ) : null}
          </section>

          {progress.kind !== "idle" ? (
            <ProgressPanel progress={progress} />
          ) : null}
        </>
      }
      footnote={
        <p className="px-2 text-xs leading-5 text-[var(--ink-3)]">
          Ticket ownership locks while randomness is pending and for the
          selected winner after resolution. Refund tickets remain transferable
          until burn.{" "}
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

/* --------------------------------------------------------------- pieces */

function QuantityStepper({
  quantity,
  onChange,
  disabled = false,
}: {
  readonly quantity: number;
  readonly onChange: (value: number) => void;
  readonly disabled?: boolean;
}) {
  function clamp(value: number) {
    return Math.min(MAX_QUANTITY, Math.max(1, value));
  }

  return (
    <div className="mt-5">
      <span className="field-label" id="quantity-label">
        Quantity
      </span>
      <div className="flex items-center gap-2">
        <button
          aria-label="Remove one ticket"
          className="btn btn-outline !size-12 !min-h-0 shrink-0 !p-0"
          disabled={disabled || quantity <= 1}
          onClick={() => onChange(clamp(quantity - 1))}
          type="button"
        >
          <Minus aria-hidden size={18} />
        </button>
        <input
          aria-labelledby="quantity-label"
          className="input numeric !h-12 text-center !text-lg !font-extrabold"
          disabled={disabled}
          inputMode="numeric"
          max={MAX_QUANTITY}
          min={1}
          onChange={(event) => {
            const next = Number.parseInt(event.target.value, 10);
            onChange(Number.isNaN(next) ? 1 : clamp(next));
          }}
          type="number"
          value={quantity}
        />
        <button
          aria-label="Add one ticket"
          className="btn btn-outline !size-12 !min-h-0 shrink-0 !p-0"
          disabled={disabled || quantity >= MAX_QUANTITY}
          onClick={() => onChange(clamp(quantity + 1))}
          type="button"
        >
          <Plus aria-hidden size={18} />
        </button>
      </div>
      <div className="mt-2 flex gap-1.5">
        {[5, 10, 25].map((preset) => (
          <button
            className="chip bg-[var(--paper-sunk)] text-[var(--ink-2)] hover:text-[var(--ink)]"
            disabled={disabled}
            key={preset}
            onClick={() => onChange(preset)}
            type="button"
          >
            {preset}
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
      className="flex min-h-12 w-full items-center gap-3 rounded-2xl border border-[var(--line)] bg-[var(--paper-raised)] px-4 text-left text-sm font-extrabold transition-colors hover:border-[var(--ink)] disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:border-[var(--line)]"
      disabled={disabled}
      onClick={onClick}
      type="button"
    >
      {icon} {label}
    </button>
  );
}

function ProgressPanel({ progress }: { readonly progress: ActionProgress }) {
  return (
    <section
      className={`rounded-3xl p-5 text-sm ${
        progress.kind === "error"
          ? "bg-[var(--danger-wash)] text-[var(--danger)]"
          : "card"
      }`}
      role={progress.kind === "error" ? "alert" : "status"}
    >
      {progress.kind === "pending" ? (
        <p className="flex items-center gap-2 font-bold">
          <LoaderCircle aria-hidden className="animate-spin" size={17} />
          {progress.text}
        </p>
      ) : null}
      {progress.kind === "error" ? (
        <p className="font-bold">{progress.text}</p>
      ) : null}
      {progress.kind === "batch" ? (
        <div>
          <p className="font-extrabold">Wallet batch submitted</p>
          <p className="numeric mt-1 break-all text-xs text-[var(--ink-2)]">
            Batch ID: {progress.id}
          </p>
          <p className="mt-2 text-xs leading-5 text-[var(--ink-2)]">
            Your wallet tracks confirmation. Chain and index views refresh
            automatically.
          </p>
        </div>
      ) : null}
      {progress.kind === "success" ? (
        <div>
          <p className="flex items-center gap-2 font-extrabold text-[#0d6b45]">
            <Check aria-hidden size={17} /> Confirmed onchain
          </p>
          <a
            className="mt-2 inline-flex items-center gap-1 font-bold underline"
            href={explorerTransactionUrl(progress.hash)}
            rel="noreferrer"
            target="_blank"
          >
            View transaction <ExternalLink aria-hidden size={13} />
          </a>
          {progress.indexing ? (
            <p className="mt-2 text-xs leading-5 text-[var(--ink-2)]">
              The index is catching up; direct chain state above already
              refreshed.
            </p>
          ) : null}
        </div>
      ) : null}
    </section>
  );
}
