"use client";

import { useQueryClient } from "@tanstack/react-query";
import {
  ArrowUpRight,
  AlertTriangle,
  Check,
  CircleDollarSign,
  Clock3,
  Dices,
  ExternalLink,
  Gift,
  LoaderCircle,
  Ticket,
  Trophy,
  Users,
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
  claimPrize,
  claimQuote,
  closeNoSales,
  formatQuoteAmount,
  raffleAbi,
  raffleFactoryAbi,
  raffleLensAbi,
  RaffleOutcome,
  raffleOutcomeLabels,
  RaffleState,
  raffleStateLabels,
  requestDraw,
  type ActionContext,
} from "@raffle-fun/sdk";

import { StatusPill } from "@/components/status-pill";
import { WalletButton } from "@/components/wallet-button";
import { useTokenMetadata } from "@/hooks/use-token-metadata";
import {
  formatCountdown,
  formatDateTime,
  formatTokenAmount,
  percentOf,
  shortAddress,
} from "@/lib/format";
import {
  configuredChain,
  configuredChainId,
  explorerAddressUrl,
  explorerTransactionUrl,
  protocolDeployment,
} from "@/lib/protocol";
import { isSubgraphConfigured } from "@/lib/subgraph";

type LiveRaffleView = {
  readonly factoryId: bigint;
  readonly registered: boolean;
  readonly raffle: Address;
  readonly state: number;
  readonly outcome: number;
  readonly sponsor: Address;
  readonly protocolTreasury: Address;
  readonly quoteToken: Address;
  readonly prizeToken: Address;
  readonly prizeTokenId: bigint;
  readonly ticketPrice: bigint;
  readonly minimumTickets: bigint;
  readonly startTime: bigint;
  readonly endTime: bigint;
  readonly totalTickets: bigint;
  readonly grossSales: bigint;
  readonly unsettledPot: bigint;
  readonly winningTicketId: bigint;
  readonly winner: Address;
  readonly accountTicketBalance: bigint;
  readonly accountQuoteClaim: bigint;
  readonly accountIsPrizeClaimant: boolean;
  readonly entropyFee: bigint;
  readonly canBuy: boolean;
  readonly canDraw: boolean;
  readonly canClaimQuote: boolean;
  readonly canClaimPrize: boolean;
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

const quantityPattern = /^(?:[1-9]|[1-9]\d|100)$/;

export function RaffleDetail({
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
  const [quantity, setQuantity] = useState("1");
  const [recipient, setRecipient] = useState("");
  const [claimDestination, setClaimDestination] = useState("");
  const [acceptedUnverifiedTokenRisk, setAcceptedUnverifiedTokenRisk] =
    useState(false);
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
  const quoteTokenVerificationQuery = useReadContract({
    address: protocolDeployment?.raffleFactory,
    abi: raffleFactoryAbi,
    functionName: "isVerifiedQuoteToken",
    args: view === undefined ? undefined : [view.quoteToken],
    query: {
      enabled: protocolDeployment !== undefined && view !== undefined,
      refetchInterval: 30_000,
    },
  });
  const tokenMetadata = useTokenMetadata(view?.quoteToken);
  const quoteTokenVerificationKnown =
    typeof quoteTokenVerificationQuery.data === "boolean";
  const quoteTokenVerified = quoteTokenVerificationQuery.data === true;
  const parsedQuantity = quantityPattern.test(quantity)
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
    if (!quoteTokenVerificationKnown) {
      setProgress({
        kind: "error",
        text: "Payment-token verification could not be confirmed onchain.",
      });
      return;
    }
    if (!quoteTokenVerified && !acceptedUnverifiedTokenRisk) {
      setProgress({
        kind: "error",
        text: "Acknowledge the unverified payment-token risk before buying.",
      });
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

  async function handleAction(action: "draw" | "close" | "quote" | "prize") {
    if (raffle === undefined) return;
    setProgress({ kind: "pending", text: "Checking current onchain state…" });
    try {
      const context = actionContext();
      const live = await readLiveView();
      let hash: Hash;
      if (action === "draw") {
        if (!live.canDraw)
          throw new Error("A draw cannot be requested right now.");
        setProgress({
          kind: "pending",
          text: `Simulating draw with ${formatQuoteAmount(live.entropyFee, 18)} ETH oracle fee…`,
        });
        hash = await requestDraw(context, raffle, live.entropyFee);
      } else if (action === "close") {
        const block = await context.publicClient.getBlock();
        if (
          live.state !== RaffleState.Active ||
          live.totalTickets !== 0n ||
          block.timestamp < live.endTime
        ) {
          throw new Error("This raffle is not eligible for no-sales closure.");
        }
        hash = await closeNoSales(context, raffle);
      } else if (action === "quote") {
        if (!live.canClaimQuote)
          throw new Error("No quote-token claim is available.");
        const destination =
          claimDestination.trim() === ""
            ? context.account
            : isAddress(claimDestination)
              ? claimDestination
              : undefined;
        if (destination === undefined || destination === zeroAddress) {
          throw new Error("Enter a valid claim destination.");
        }
        hash = await claimQuote(context, raffle, destination);
      } else {
        if (!live.canClaimPrize)
          throw new Error("No prize claim is available.");
        const destination =
          claimDestination.trim() === ""
            ? context.account
            : isAddress(claimDestination)
              ? claimDestination
              : undefined;
        if (destination === undefined || destination === zeroAddress) {
          throw new Error("Enter a valid prize destination.");
        }
        hash = await claimPrize(context, raffle, destination);
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
      <div className="page-shell py-20" role="status">
        <div className="ticket-card h-[36rem] animate-pulse bg-white/60" />
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

  const progressPercent = percentOf(view.totalTickets, view.minimumTickets);
  const thresholdMet = view.totalTickets >= view.minimumTickets;
  const thresholdTarget = view.ticketPrice * view.minimumTickets;
  const currentSettlement = calculateResolutionAmounts(
    view.state === RaffleState.Resolved ? view.grossSales : view.unsettledPot,
    thresholdMet,
  );
  const projectedSettlement =
    purchaseAmounts === undefined || parsedQuantity === undefined
      ? undefined
      : calculateResolutionAmounts(
          view.unsettledPot + purchaseAmounts.grossAmount,
          view.totalTickets + parsedQuantity >= view.minimumTickets,
        );

  return (
    <div className="page-shell py-12 md:py-18">
      <div className="mb-8 flex flex-wrap items-center justify-between gap-4">
        <div>
          <p className="eyebrow">Raffle #{view.factoryId.toString()}</p>
          <h1 className="mt-2 text-4xl font-bold md:text-6xl">
            NFT #{view.prizeTokenId.toString()}
          </h1>
        </div>
        <StatusPill
          tone={
            view.state === RaffleState.Active
              ? "active"
              : view.state === RaffleState.Resolved
                ? "resolved"
                : view.state === RaffleState.DrawRequested
                  ? "warning"
                  : "neutral"
          }
        >
          {raffleStateLabels[view.state as RaffleState]}
        </StatusPill>
      </div>

      {quoteTokenVerificationQuery.data === false ? (
        <div className="mb-7 rounded-2xl border border-amber-900/20 bg-amber-100 p-5 text-amber-950">
          <p className="flex items-center gap-2 font-black">
            <AlertTriangle aria-hidden size={19} /> Unverified payment token
          </p>
          <p className="mt-2 text-sm leading-6 text-amber-950/80">
            This raffle is canonical, but its ERC-20 is not currently verified
            for official discovery. It may freeze, rebase, blacklist accounts,
            or otherwise prevent purchases and claims. Review the token contract
            before interacting.
          </p>
          <label className="mt-4 flex items-start gap-2 text-sm font-bold">
            <input
              checked={acceptedUnverifiedTokenRisk}
              className="mt-1 size-4 accent-[#1726a3]"
              onChange={(event) =>
                setAcceptedUnverifiedTokenRisk(event.target.checked)
              }
              type="checkbox"
            />
            I understand this token is unverified and want to enable ticket
            purchases.
          </label>
        </div>
      ) : null}

      {quoteTokenVerificationQuery.isError ? (
        <p
          className="mb-7 rounded-2xl border border-red-900/20 bg-red-50 p-5 text-sm font-bold text-red-800"
          role="alert"
        >
          Payment-token verification could not be read. Purchases are disabled
          until the factory check succeeds.
        </p>
      ) : null}

      <div className="grid gap-7 lg:grid-cols-[1fr_24rem]">
        <div className="space-y-7">
          <section className="ticket-card overflow-hidden">
            <div className="grid min-h-72 place-items-center bg-[#1726a3] p-10 text-white">
              <div className="text-center">
                <span className="mx-auto grid size-28 rotate-6 place-items-center rounded-[2rem] border border-white/30 bg-white/10">
                  <Gift aria-hidden size={50} strokeWidth={1.4} />
                </span>
                <p className="mt-6 text-xs font-bold text-white/55">
                  ERC721 prize
                </p>
                <a
                  className="mt-2 inline-flex items-center gap-1 text-sm font-black hover:text-[#ffdc55]"
                  href={explorerAddressUrl(view.prizeToken)}
                  rel="noreferrer"
                  target="_blank"
                >
                  {shortAddress(view.prizeToken)}{" "}
                  <ArrowUpRight aria-hidden size={14} />
                </a>
              </div>
            </div>
            <div className="grid gap-4 p-6 sm:grid-cols-2 lg:grid-cols-4">
              <Metric
                icon={<CircleDollarSign size={17} />}
                label="Ticket"
                value={formatTokenAmount(
                  view.ticketPrice,
                  tokenMetadata.decimals,
                  tokenMetadata.symbol,
                )}
              />
              <Metric
                icon={<Users size={17} />}
                label="Sold"
                value={view.totalTickets.toString()}
              />
              <Metric
                icon={<Clock3 size={17} />}
                label="Time left"
                value={
                  view.state === RaffleState.Active
                    ? formatCountdown(view.endTime)
                    : "Closed"
                }
              />
              <Metric
                icon={<Ticket size={17} />}
                label="Your tickets"
                value={view.accountTicketBalance.toString()}
              />
            </div>
          </section>

          <section className="ticket-card p-6 md:p-8">
            <div className="flex flex-wrap items-end justify-between gap-4">
              <div>
                <p className="eyebrow">NFT threshold</p>
                <h2 className="mt-2 text-3xl font-bold">
                  {view.totalTickets.toString()} of{" "}
                  {view.minimumTickets.toString()} tickets
                </h2>
              </div>
              <p className="numeric text-3xl font-black">
                {progressPercent.toFixed(0)}%
              </p>
            </div>
            <div className="mt-5 h-4 overflow-hidden rounded-full bg-black/10">
              <div
                className="h-full rounded-full bg-[#ef2ab2]"
                style={{ width: `${Math.min(progressPercent, 100)}%` }}
              />
            </div>
            <div className="mt-5 grid gap-3 text-sm sm:grid-cols-3">
              <Stat
                label="Gross target"
                value={formatTokenAmount(
                  thresholdTarget,
                  tokenMetadata.decimals,
                  tokenMetadata.symbol,
                )}
              />
              <Stat
                label="Gross sales"
                value={formatTokenAmount(
                  view.grossSales,
                  tokenMetadata.decimals,
                  tokenMetadata.symbol,
                )}
              />
              <Stat
                label="Distributable after 5%"
                value={formatTokenAmount(
                  currentSettlement.distributablePot,
                  tokenMetadata.decimals,
                  tokenMetadata.symbol,
                )}
              />
            </div>
            <p className="mt-5 text-xs leading-5 text-[#56506a]">
              The threshold selects the settlement branch; it does not cap
              sales. Tickets remain available until the fixed closing time, so
              the sponsor can exceed the target and existing odds can change.
            </p>
          </section>

          <section>
            <div className="mb-4">
              <p className="eyebrow">Settlement branches</p>
              <h2 className="mt-2 text-3xl font-bold">
                What the winner receives
              </h2>
            </div>
            <div className="grid gap-4 md:grid-cols-2">
              <OutcomePanel
                active={thresholdMet && view.outcome === RaffleOutcome.None}
                icon={<Trophy aria-hidden />}
                label="At or above threshold"
                title="Winner claims the NFT"
                text="A 5% protocol fee is allocated at resolution. The sponsor claims the remaining 95% of aggregate gross sales."
              />
              <OutcomePanel
                active={!thresholdMet && view.outcome === RaffleOutcome.None}
                icon={<CircleDollarSign aria-hidden />}
                label="Below threshold"
                title="Winner claims 80% cash"
                text="The sponsor reclaims the NFT and receives the remaining 20% of the distributable pot."
              />
            </div>
            {view.outcome !== RaffleOutcome.None ? (
              <p className="mt-4 rounded-xl bg-violet-100 p-4 text-sm font-black text-violet-950">
                Settled outcome:{" "}
                {raffleOutcomeLabels[view.outcome as RaffleOutcome]}
                {view.winningTicketId > 0n
                  ? ` · Ticket #${view.winningTicketId.toString()} won`
                  : ""}
              </p>
            ) : null}
          </section>

          <section className="ticket-card p-6 md:p-8">
            <p className="eyebrow">Chain-authoritative details</p>
            <dl className="mt-5 grid gap-4 text-sm sm:grid-cols-2">
              <Detail
                label="Raffle contract"
                value={shortAddress(view.raffle)}
                href={explorerAddressUrl(view.raffle)}
              />
              <Detail
                label="Sponsor"
                value={shortAddress(view.sponsor)}
                href={explorerAddressUrl(view.sponsor)}
              />
              <Detail
                label="Prize contract"
                value={shortAddress(view.prizeToken)}
                href={explorerAddressUrl(view.prizeToken)}
              />
              <Detail
                label="Quote token"
                value={`${tokenMetadata.symbol} · ${shortAddress(view.quoteToken)}`}
                href={explorerAddressUrl(view.quoteToken)}
              />
              <Detail label="Starts" value={formatDateTime(view.startTime)} />
              <Detail label="Ends" value={formatDateTime(view.endTime)} />
            </dl>
          </section>

          <section className="ticket-card p-6 md:p-8">
            <p className="eyebrow">Indexed history</p>
            <h2 className="mt-2 text-3xl font-bold">Activity</h2>
            <p className="mt-4 text-sm leading-6 text-[#56506a]">
              {isSubgraphConfigured()
                ? "The configured index may take a short time to reflect recent confirmations. Live actions above always use direct chain reads."
                : "No subgraph endpoint is configured, so indexed purchase and claim history is unavailable. Live contract state above remains authoritative."}
            </p>
          </section>
        </div>

        <aside className="space-y-5 lg:sticky lg:top-6 lg:self-start">
          <section className="ticket-card p-6">
            <p className="eyebrow">Your action</p>
            <h2 className="mt-2 text-3xl font-bold">Get tickets</h2>
            <div className="mt-5">
              <label className="text-xs font-extrabold text-[#56506a]">
                Quantity (1–100)
                <input
                  className="input numeric mt-2"
                  inputMode="numeric"
                  onChange={(event) => setQuantity(event.target.value)}
                  value={quantity}
                />
              </label>
            </div>
            <div className="mt-4">
              <label className="text-xs font-extrabold text-[#56506a]">
                Optional recipient
                <input
                  className="input mt-2"
                  onChange={(event) => setRecipient(event.target.value)}
                  placeholder={address ?? "0x…"}
                  value={recipient}
                />
              </label>
            </div>
            {purchaseAmounts && projectedSettlement ? (
              <dl className="mt-5 space-y-2 border-y border-dashed border-black/25 py-4 text-xs">
                <Split
                  label="Total paid"
                  value={formatTokenAmount(
                    purchaseAmounts.grossAmount,
                    tokenMetadata.decimals,
                    tokenMetadata.symbol,
                  )}
                  strong
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
                  strong
                />
              </dl>
            ) : null}
            <p className="mt-4 rounded-xl bg-[#ffdc55]/55 p-3 text-xs leading-5">
              Purchases add their full amount to the gross pot. One 5% protocol
              fee is calculated from aggregate sales when the raffle resolves.
            </p>
            <div className="mt-5">
              {!isConnected ? (
                <WalletButton />
              ) : (
                <button
                  className="btn btn-primary w-full"
                  disabled={
                    !view.canBuy ||
                    progress.kind === "pending" ||
                    !quoteTokenVerificationKnown ||
                    (!quoteTokenVerified && !acceptedUnverifiedTokenRisk)
                  }
                  onClick={handleBuy}
                  type="button"
                >
                  Buy tickets <ArrowUpRight aria-hidden size={17} />
                </button>
              )}
            </div>
          </section>

          <section className="ticket-card p-6">
            <p className="eyebrow">Settle or claim</p>
            <div className="mt-4">
              <label className="text-xs font-extrabold text-[#56506a]">
                Optional claim destination
                <input
                  className="input mt-2"
                  onChange={(event) => setClaimDestination(event.target.value)}
                  placeholder={address ?? "0x…"}
                  value={claimDestination}
                />
              </label>
            </div>
            <div className="mt-4 grid gap-2">
              <ActionButton
                disabled={!view.canDraw || progress.kind === "pending"}
                icon={<Dices size={17} />}
                label={`Request draw · ${formatQuoteAmount(view.entropyFee, 18)} ETH`}
                onClick={() => handleAction("draw")}
              />
              <ActionButton
                disabled={
                  view.state !== RaffleState.Active ||
                  view.totalTickets !== 0n ||
                  progress.kind === "pending"
                }
                icon={<Check size={17} />}
                label="Close no-sales raffle"
                onClick={() => handleAction("close")}
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
                disabled={!view.canClaimPrize || progress.kind === "pending"}
                icon={<Gift size={17} />}
                label="Claim NFT prize"
                onClick={() => handleAction("prize")}
              />
            </div>
          </section>

          {progress.kind !== "idle" ? (
            <section
              className={`rounded-2xl border p-4 text-sm ${
                progress.kind === "error"
                  ? "border-red-900/20 bg-red-50 text-red-800"
                  : "border-black/10 bg-white/75"
              }`}
              role={progress.kind === "error" ? "alert" : "status"}
            >
              {progress.kind === "pending" ? (
                <p className="flex items-center gap-2 font-bold">
                  <LoaderCircle
                    aria-hidden
                    className="animate-spin"
                    size={17}
                  />
                  {progress.text}
                </p>
              ) : null}
              {progress.kind === "error" ? progress.text : null}
              {progress.kind === "batch" ? (
                <div>
                  <p className="font-black">Wallet batch submitted</p>
                  <p className="mt-1 break-all text-xs text-[#56506a]">
                    Batch ID: {progress.id}
                  </p>
                  <p className="mt-2 text-xs text-[#56506a]">
                    Your wallet tracks confirmation. Chain and index views will
                    refresh automatically.
                  </p>
                </div>
              ) : null}
              {progress.kind === "success" ? (
                <div>
                  <p className="flex items-center gap-2 font-black text-emerald-800">
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
                    <p className="mt-2 text-xs text-[#56506a]">
                      The index is catching up; the direct chain state above has
                      already refreshed.
                    </p>
                  ) : null}
                </div>
              ) : null}
            </section>
          ) : null}

          <p className="px-2 text-xs leading-5 text-[#56506a]">
            Ticket transfers are locked only while randomness is pending. After
            resolution they may move as souvenirs, but the snapshotted winner
            does not change.{" "}
            <Link className="font-bold underline" href="/docs">
              Read the full mechanics.
            </Link>
          </p>
        </aside>
      </div>
    </div>
  );
}

function InvalidState({
  title,
  detail,
}: {
  readonly title: string;
  readonly detail: string;
}) {
  return (
    <div className="page-shell py-20">
      <div className="ticket-card mx-auto max-w-2xl p-10 text-center">
        <h1 className="text-4xl font-bold">{title}</h1>
        <p className="mt-4 text-sm leading-6 text-[#56506a]">{detail}</p>
        <Link className="btn btn-dark mt-6" href="/">
          Back to discover
        </Link>
      </div>
    </div>
  );
}

function Metric({
  icon,
  label,
  value,
}: {
  readonly icon: React.ReactNode;
  readonly label: string;
  readonly value: string;
}) {
  return (
    <div className="rounded-xl bg-black/[0.045] p-4">
      <p className="flex items-center gap-2 text-xs font-bold text-[#56506a]">
        {icon} {label}
      </p>
      <p className="numeric mt-2 font-black">{value}</p>
    </div>
  );
}

function Stat({
  label,
  value,
}: {
  readonly label: string;
  readonly value: string;
}) {
  return (
    <div className="rounded-xl bg-black/[0.045] p-4">
      <dt className="text-xs font-bold text-[#56506a]">{label}</dt>
      <dd className="numeric mt-1 font-black">{value}</dd>
    </div>
  );
}

function OutcomePanel({
  icon,
  label,
  title,
  text,
  active,
}: {
  readonly icon: React.ReactNode;
  readonly label: string;
  readonly title: string;
  readonly text: string;
  readonly active: boolean;
}) {
  return (
    <div
      className={`rounded-2xl border p-6 ${
        active
          ? "border-black bg-[#ffdc55] shadow-[4px_4px_0_#1726a3]"
          : "border-black/15 bg-white/55"
      }`}
    >
      <div className="grid size-10 place-items-center rounded-full border border-black bg-white/55">
        {icon}
      </div>
      <p className="eyebrow mt-5">{label}</p>
      <h3 className="mt-2 text-2xl font-bold">{title}</h3>
      <p className="mt-3 text-sm leading-6 text-[#56506a]">{text}</p>
    </div>
  );
}

function Detail({
  label,
  value,
  href,
}: {
  readonly label: string;
  readonly value: string;
  readonly href?: string;
}) {
  return (
    <div>
      <dt className="text-xs font-bold text-[#56506a]">{label}</dt>
      <dd className="numeric mt-1 font-black">
        {href ? (
          <a
            className="inline-flex items-center gap-1 hover:underline"
            href={href}
            rel="noreferrer"
            target="_blank"
          >
            {value} <ExternalLink aria-hidden size={13} />
          </a>
        ) : (
          value
        )}
      </dd>
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
    <div
      className={`flex items-center justify-between gap-4 ${strong ? "font-black" : ""}`}
    >
      <dt>{label}</dt>
      <dd className="numeric">{value}</dd>
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
      className="flex min-h-12 w-full items-center gap-3 rounded-xl border border-black/15 bg-white/50 px-4 text-left text-sm font-black hover:bg-[#ffdc55] disabled:opacity-40"
      disabled={disabled}
      onClick={onClick}
      type="button"
    >
      {icon} {label}
    </button>
  );
}
