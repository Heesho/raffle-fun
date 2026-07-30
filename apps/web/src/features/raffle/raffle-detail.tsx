"use client";

import { useQueryClient } from "@tanstack/react-query";
import {
  AlertTriangle,
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
  cancelBeforeSales,
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

import type { StatusTone } from "@/components/status-pill";
import { WalletButton } from "@/components/wallet-button";
import { useTokenMetadata } from "@/hooks/use-token-metadata";
import { isDemoMode } from "@/lib/demo";
import { SandboxPanel } from "@/components/sandbox/sandbox-panel";
import { SANDBOX_WETH } from "@/lib/sandbox/adapter";
import { ticketsOwnedBy } from "@/lib/sandbox/engine";
import { useSandbox, useSandboxRaffle } from "@/lib/sandbox/store";
import { formatTokenAmount, shortAddress } from "@/lib/format";
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
  readonly netPot: bigint;
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

const MAX_QUANTITY = 100;
const quantityPattern = /^(?:[1-9]|[1-9]\d|100)$/;

function stateTone(state: RaffleState): StatusTone {
  if (state === RaffleState.Active) return "active";
  if (state === RaffleState.Resolved) return "resolved";
  if (state === RaffleState.DrawRequested) return "warning";
  return "neutral";
}

export function RaffleDetail({
  raffleAddress,
  referrer,
}: {
  readonly raffleAddress: string;
  readonly referrer?: string;
}) {
  if (isDemoMode()) {
    return <SandboxRaffleDetail address={raffleAddress} />;
  }
  return <LiveRaffleDetail raffleAddress={raffleAddress} referrer={referrer} />;
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
    DRAW_REQUESTED: "warning",
    RESOLVED: "resolved",
    CANCELLED: "neutral",
  };
  const outcomeLabels: Record<string, string> = {
    NFT_AWARDED: "NFT to the winner",
    CASH_FALLBACK: "80% cash to the winner",
    NO_SALES: "no sales",
    CANCELLED_BEFORE_SALE: "cancelled before any sale",
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
    netPot: raffle.netPot,
    startTime: BigInt(Math.floor(raffle.startTime / 1000)),
    endTime: BigInt(Math.floor(raffle.endTime / 1000)),
    stateLabel: raffle.state.replaceAll("_", " ").toLowerCase(),
    stateTone: tones[raffle.state] ?? "neutral",
    isActive: raffle.state === "ACTIVE",
    outcomeLabel: outcomeLabels[raffle.outcome],
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
        <p className="px-2 text-xs leading-5 text-[var(--ink-faint)]">
          Ticket transfers lock only while randomness is pending. After
          resolution they move freely, but the snapshotted winner never changes.{" "}
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
  referrer,
}: {
  readonly raffleAddress: string;
  readonly referrer?: string;
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
  const [acceptedUnverifiedTokenRisk, setAcceptedUnverifiedTokenRisk] =
    useState(false);
  const [progress, setProgress] = useState<ActionProgress>({ kind: "idle" });

  const referrerAddress =
    referrer !== undefined && isAddress(referrer) && referrer !== zeroAddress
      ? (referrer as Address)
      : undefined;
  const invalidReferrer =
    referrer !== undefined &&
    referrer !== "" &&
    (!isAddress(referrer) || referrer === zeroAddress);

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

  const providerQuery = useReadContract({
    address: protocolDeployment?.raffleFactory,
    abi: raffleFactoryAbi,
    functionName: "isProvider",
    args: referrerAddress === undefined ? undefined : [referrerAddress],
    query: {
      enabled:
        protocolDeployment !== undefined && referrerAddress !== undefined,
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
  const providerApproved =
    referrerAddress === undefined || providerQuery.data === true;
  const parsedQuantity = quantityPattern.test(String(quantity))
    ? BigInt(quantity)
    : undefined;
  const purchaseAmounts = useMemo(() => {
    if (view === undefined || parsedQuantity === undefined) return undefined;
    return calculatePurchaseAmounts({
      ticketPrice: view.ticketPrice,
      quantity: parsedQuantity,
      hasProvider: referrerAddress !== undefined,
    });
  }, [parsedQuantity, referrerAddress, view]);

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
    if (invalidReferrer || !providerApproved) {
      setProgress({
        kind: "error",
        text: invalidReferrer
          ? "The ref parameter is not a valid nonzero address."
          : "This referrer is not currently allowlisted onchain.",
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
      const provider = referrerAddress ?? zeroAddress;
      if (referrerAddress !== undefined) {
        const stillAllowed = await context.publicClient.readContract({
          address: protocolDeployment!.raffleFactory,
          abi: raffleFactoryAbi,
          functionName: "isProvider",
          args: [referrerAddress],
        });
        if (!stillAllowed)
          throw new Error("The referrer is no longer allowlisted.");
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
              args: [to, parsedQuantity, provider],
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
      const hash = await buyTickets(
        context,
        raffle,
        to,
        parsedQuantity,
        referrerAddress ?? zeroAddress,
      );
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
    action: "draw" | "close" | "quote" | "prize" | "cancel",
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
        setProgress({
          kind: "pending",
          text: `Simulating draw with ${formatQuoteAmount(live.entropyFee, 18)} ETH oracle fee…`,
        });
        hash = await requestDraw(context, raffle, live.entropyFee);
      } else if (action === "cancel") {
        if (live.state !== RaffleState.Active || live.totalTickets !== 0n) {
          throw new Error(
            "Cancellation is only possible while zero tickets have been sold.",
          );
        }
        hash = await cancelBeforeSales(context, raffle);
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

  const hasProvider = referrerAddress !== undefined;
  const isSponsor =
    address !== undefined &&
    address.toLowerCase() === view.sponsor.toLowerCase();
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
    netPot: view.netPot,
    startTime: view.startTime,
    endTime: view.endTime,
    stateLabel: raffleStateLabels[view.state as RaffleState],
    stateTone: stateTone(view.state as RaffleState),
    isActive: view.state === RaffleState.Active,
    outcomeLabel:
      view.outcome === RaffleOutcome.None
        ? undefined
        : raffleOutcomeLabels[view.outcome as RaffleOutcome],
    winningTicketId: view.winningTicketId,
    accountTicketBalance: view.accountTicketBalance,
  };

  const purchaseDisabled =
    !view.canBuy ||
    progress.kind === "pending" ||
    invalidReferrer ||
    !providerApproved ||
    !quoteTokenVerificationKnown ||
    (!quoteTokenVerified && !acceptedUnverifiedTokenRisk);

  return (
    <RaffleLayout
      banner={
        <>
          {quoteTokenVerificationQuery.data === false ? (
            <div className="rounded-3xl bg-[var(--amber-wash)] p-5 text-[var(--amber-ink)]">
              <p className="flex items-center gap-2 font-extrabold">
                <AlertTriangle aria-hidden size={18} /> Unverified payment token
              </p>
              <p className="mt-2 text-sm leading-6">
                This raffle is canonical, but its ERC-20 is not currently
                verified for official discovery. It may freeze, rebase,
                blacklist accounts, or otherwise prevent purchases and claims.
                Review the token contract before interacting.
              </p>
              <label className="mt-4 flex items-start gap-2 text-sm font-bold">
                <input
                  checked={acceptedUnverifiedTokenRisk}
                  className="mt-1 size-4 accent-[var(--pink)]"
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
              className="mt-4 rounded-3xl bg-[var(--danger-wash)] p-5 text-sm font-bold text-[var(--danger)]"
              role="alert"
            >
              Payment-token verification could not be read. Purchases are
              disabled until the factory check succeeds.
            </p>
          ) : null}
        </>
      }
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

            {purchaseAmounts ? (
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
                  label="Protocol · 5%"
                  value={formatTokenAmount(
                    purchaseAmounts.protocolFee,
                    tokenMetadata.decimals,
                    tokenMetadata.symbol,
                  )}
                />
                <Split
                  label={hasProvider ? "Provider · 5%" : "Provider · none"}
                  value={formatTokenAmount(
                    purchaseAmounts.providerFee,
                    tokenMetadata.decimals,
                    tokenMetadata.symbol,
                  )}
                />
                <Split
                  label="Added to net pot"
                  value={formatTokenAmount(
                    purchaseAmounts.netContribution,
                    tokenMetadata.decimals,
                    tokenMetadata.symbol,
                  )}
                />
              </dl>
            ) : null}

            {referrer !== undefined ? (
              <p
                className={`mt-4 rounded-2xl p-3 text-xs leading-5 ${
                  invalidReferrer || !providerApproved
                    ? "bg-[var(--danger-wash)] text-[var(--danger)]"
                    : "bg-[var(--grass-wash)] text-[#0d6b45]"
                }`}
              >
                {invalidReferrer
                  ? "Invalid ref parameter. It will not be substituted or used."
                  : providerApproved
                    ? `Allowlisted provider: ${shortAddress(referrerAddress!)}. A disclosed 5% fee applies.`
                    : "The requested provider is not allowlisted. Purchase is disabled."}
              </p>
            ) : null}

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
              <span className="field-label">Claim destination (optional)</span>
              <input
                className="input numeric"
                onChange={(event) => setClaimDestination(event.target.value)}
                placeholder={address ?? "0x…"}
                value={claimDestination}
              />
            </label>
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

          {isSponsor ? (
            <section className="card p-6">
              <p className="eyebrow">Sponsor controls</p>
              <h2 className="mt-2 text-xl">Your escrowed prize</h2>
              <p className="mt-3 text-sm leading-6 text-[var(--ink-soft)]">
                {view.totalTickets === 0n
                  ? "No tickets have sold yet, so you can still cancel and reclaim the NFT. The moment ticket #1 sells this option disappears for good."
                  : `${view.totalTickets.toString()} tickets have sold. The NFT is now locked until the draw settles — it can only go to the winner or back to you through settlement.`}
              </p>
              <button
                className="btn btn-outline mt-4 w-full"
                disabled={
                  view.state !== RaffleState.Active ||
                  view.totalTickets !== 0n ||
                  progress.kind === "pending"
                }
                onClick={() => handleAction("cancel")}
                type="button"
              >
                <Undo2 aria-hidden size={17} /> Cancel & reclaim NFT
              </button>
            </section>
          ) : null}

          {progress.kind !== "idle" ? (
            <ProgressPanel progress={progress} />
          ) : null}
        </>
      }
      footnote={
        <p className="px-2 text-xs leading-5 text-[var(--ink-faint)]">
          Ticket transfers lock only while randomness is pending. After
          resolution they move freely, but the snapshotted winner never changes.{" "}
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
            className="chip bg-[var(--paper-sunk)] text-[var(--ink-soft)] hover:text-[var(--ink)]"
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
      <dt className={strong ? "font-extrabold" : "text-[var(--ink-soft)]"}>
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
          <p className="numeric mt-1 break-all text-xs text-[var(--ink-soft)]">
            Batch ID: {progress.id}
          </p>
          <p className="mt-2 text-xs leading-5 text-[var(--ink-soft)]">
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
            <p className="mt-2 text-xs leading-5 text-[var(--ink-soft)]">
              The index is catching up; direct chain state above already
              refreshed.
            </p>
          ) : null}
        </div>
      ) : null}
    </section>
  );
}
