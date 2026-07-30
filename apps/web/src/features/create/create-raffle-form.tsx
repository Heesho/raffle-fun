"use client";

import {
  ArrowRight,
  Check,
  CircleDollarSign,
  ExternalLink,
  ImageOff,
  LoaderCircle,
  ShieldCheck,
} from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { useMemo, useState } from "react";
import {
  decodeEventLog,
  erc20Abi,
  erc721Abi,
  isAddress,
  type Address,
  type Hash,
} from "viem";
import {
  useAccount,
  usePublicClient,
  useReadContract,
  useReadContracts,
  useWalletClient,
} from "wagmi";
import { z } from "zod";

import {
  createRaffle,
  formatQuoteAmount,
  parseQuoteAmount,
  raffleFactoryAbi,
  type ActionContext,
} from "@raffle-fun/sdk";

import { WalletButton } from "@/components/wallet-button";
import { explorerTransactionUrl, protocolDeployment } from "@/lib/protocol";
import { fetchSafeNftMetadata, type SafeNftMetadata } from "@/lib/nft-metadata";

const formSchema = z.object({
  prizeToken: z.string().refine(isAddress, "Enter a valid ERC721 address."),
  prizeTokenId: z
    .string()
    .regex(/^(0|[1-9]\d*)$/, "Use a nonnegative token ID."),
  quoteToken: z.string().refine(isAddress, "Choose a verified payment token."),
  ticketPrice: z
    .string()
    .regex(/^(?:0|[1-9]\d*)(?:\.\d+)?$/, "Enter a positive token amount."),
  minimumTickets: z
    .string()
    .regex(/^[1-9]\d*$/, "Minimum tickets must be at least one."),
  startTime: z.string().min(1, "Choose a start time."),
  endTime: z.string().min(1, "Choose an end time."),
  metadataURI: z.string().max(2_048, "Metadata URI is too long."),
});

type ProgressState =
  | { readonly kind: "idle" }
  | { readonly kind: "pending"; readonly message: string }
  | { readonly kind: "success"; readonly hash: Hash; readonly raffle?: Address }
  | { readonly kind: "error"; readonly message: string };

interface QuoteTokenOption {
  readonly address: Address;
  readonly symbol: string;
  readonly decimals: number;
}

function initialDate(hoursFromNow: number): string {
  const date = new Date(Date.now() + hoursFromNow * 3_600_000);
  date.setMinutes(date.getMinutes() - date.getTimezoneOffset());
  return date.toISOString().slice(0, 16);
}

export function CreateRaffleForm() {
  const { address, chainId, isConnected } = useAccount();
  const publicClient = usePublicClient();
  const wallet = useWalletClient();
  const [form, setForm] = useState({
    prizeToken: "",
    prizeTokenId: "",
    quoteToken: "",
    ticketPrice: "1",
    minimumTickets: "100",
    startTime: initialDate(1),
    endTime: initialDate(24 * 7),
    metadataURI: "",
  });
  const [metadata, setMetadata] = useState<SafeNftMetadata>();
  const [metadataState, setMetadataState] = useState<
    "idle" | "loading" | "error"
  >("idle");
  const [metadataError, setMetadataError] = useState("");
  const [progress, setProgress] = useState<ProgressState>({ kind: "idle" });
  const [approved, setApproved] = useState(false);

  const quoteTokenCountQuery = useReadContract({
    address: protocolDeployment?.raffleFactory,
    abi: raffleFactoryAbi,
    functionName: "verifiedQuoteTokenCount",
    query: { enabled: protocolDeployment !== undefined, staleTime: 30_000 },
  });
  const quoteTokenCount = Number(quoteTokenCountQuery.data ?? 0n);
  const quoteTokenAddressQuery = useReadContracts({
    allowFailure: true,
    contracts: Array.from({ length: quoteTokenCount }, (_, index) => ({
      address: protocolDeployment?.raffleFactory,
      abi: raffleFactoryAbi,
      functionName: "verifiedQuoteTokenAt" as const,
      args: [BigInt(index)] as const,
    })),
    query: { enabled: quoteTokenCount > 0, staleTime: 30_000 },
  });
  const knownQuoteTokens = useMemo(
    () =>
      (quoteTokenAddressQuery.data ?? []).flatMap((result) =>
        result.status === "success" &&
        typeof result.result === "string" &&
        isAddress(result.result)
          ? [result.result]
          : [],
      ),
    [quoteTokenAddressQuery.data],
  );
  const quoteTokenDetailsQuery = useReadContracts({
    allowFailure: true,
    contracts: knownQuoteTokens.flatMap((quoteToken) => [
      {
        address: protocolDeployment?.raffleFactory,
        abi: raffleFactoryAbi,
        functionName: "isVerifiedQuoteToken" as const,
        args: [quoteToken] as const,
      },
      { address: quoteToken, abi: erc20Abi, functionName: "symbol" as const },
      { address: quoteToken, abi: erc20Abi, functionName: "decimals" as const },
    ]),
    query: {
      enabled: knownQuoteTokens.length > 0,
      staleTime: 30_000,
      refetchInterval: 30_000,
    },
  });
  const quoteTokens = useMemo<readonly QuoteTokenOption[]>(() => {
    const details = quoteTokenDetailsQuery.data ?? [];
    return knownQuoteTokens.flatMap((quoteToken, index) => {
      const allowed = details[index * 3];
      const symbol = details[index * 3 + 1];
      const decimals = details[index * 3 + 2];
      if (
        allowed?.status !== "success" ||
        allowed.result !== true ||
        decimals?.status !== "success" ||
        typeof decimals.result !== "number"
      ) {
        return [];
      }
      return [
        {
          address: quoteToken,
          symbol:
            symbol?.status === "success" && typeof symbol.result === "string"
              ? symbol.result.slice(0, 16)
              : `${quoteToken.slice(0, 6)}…${quoteToken.slice(-4)}`,
          decimals: decimals.result,
        },
      ];
    });
  }, [knownQuoteTokens, quoteTokenDetailsQuery.data]);
  const selectedQuoteToken =
    quoteTokens.find(
      (token) => token.address.toLowerCase() === form.quoteToken.toLowerCase(),
    ) ?? quoteTokens[0];
  const parsed = useMemo(
    () =>
      formSchema
        .superRefine((value, context) => {
          if (selectedQuoteToken === undefined) {
            context.addIssue({
              code: "custom",
              path: ["quoteToken"],
              message:
                "Choose a verified payment token with readable decimals.",
            });
            return;
          }
          try {
            if (
              parseQuoteAmount(
                value.ticketPrice,
                selectedQuoteToken.decimals,
              ) <= 0n
            ) {
              throw new Error("zero price");
            }
          } catch {
            context.addIssue({
              code: "custom",
              path: ["ticketPrice"],
              message: `Enter a positive ${selectedQuoteToken.symbol} amount with at most ${selectedQuoteToken.decimals} decimals.`,
            });
          }
        })
        .safeParse({
          ...form,
          quoteToken: selectedQuoteToken?.address ?? form.quoteToken,
        }),
    [form, selectedQuoteToken],
  );

  const target = useMemo(() => {
    if (!parsed.success) return undefined;
    return {
      prizeToken: parsed.data.prizeToken as Address,
      prizeTokenId: BigInt(parsed.data.prizeTokenId),
    };
  }, [parsed]);

  function update(key: keyof typeof form, value: string) {
    setForm((current) => ({ ...current, [key]: value }));
    if (key === "prizeToken" || key === "prizeTokenId") {
      setApproved(false);
      setMetadata(undefined);
    }
  }

  async function loadMetadata() {
    if (
      publicClient === undefined ||
      target === undefined ||
      address === undefined
    ) {
      setMetadataError("Connect a wallet and enter a valid NFT first.");
      setMetadataState("error");
      return;
    }
    setMetadataState("loading");
    setMetadataError("");
    try {
      const [owner, tokenUri] = await Promise.all([
        publicClient.readContract({
          address: target.prizeToken,
          abi: erc721Abi,
          functionName: "ownerOf",
          args: [target.prizeTokenId],
        }),
        publicClient.readContract({
          address: target.prizeToken,
          abi: erc721Abi,
          functionName: "tokenURI",
          args: [target.prizeTokenId],
        }),
      ]);
      if (owner.toLowerCase() !== address.toLowerCase()) {
        throw new Error("The connected wallet does not own this token.");
      }
      setMetadata(await fetchSafeNftMetadata(tokenUri));
      setMetadataState("idle");
    } catch (error) {
      setMetadataState("error");
      setMetadataError(
        error instanceof Error ? error.message : "Could not load NFT.",
      );
    }
  }

  async function approvePrize() {
    if (
      publicClient === undefined ||
      wallet.data === undefined ||
      address === undefined ||
      target === undefined ||
      protocolDeployment === undefined
    ) {
      setProgress({
        kind: "error",
        message: "Wallet or protocol is not ready.",
      });
      return;
    }
    setProgress({
      kind: "pending",
      message: "Confirm NFT approval in your wallet…",
    });
    try {
      const owner = await publicClient.readContract({
        address: target.prizeToken,
        abi: erc721Abi,
        functionName: "ownerOf",
        args: [target.prizeTokenId],
      });
      if (owner.toLowerCase() !== address.toLowerCase()) {
        throw new Error("The connected wallet no longer owns this NFT.");
      }
      const { request } = await publicClient.simulateContract({
        account: address,
        address: target.prizeToken,
        abi: erc721Abi,
        functionName: "approve",
        args: [protocolDeployment.raffleFactory, target.prizeTokenId],
      });
      const hash = await wallet.data.writeContract(request);
      setProgress({ kind: "pending", message: "Waiting for NFT approval…" });
      await publicClient.waitForTransactionReceipt({ hash });
      setApproved(true);
      setProgress({ kind: "success", hash });
    } catch (error) {
      setProgress({
        kind: "error",
        message: error instanceof Error ? error.message : "Approval failed.",
      });
    }
  }

  async function submitRaffle() {
    if (
      !parsed.success ||
      publicClient === undefined ||
      wallet.data === undefined ||
      address === undefined ||
      protocolDeployment === undefined ||
      target === undefined ||
      selectedQuoteToken === undefined
    ) {
      setProgress({
        kind: "error",
        message: "Complete every required field first.",
      });
      return;
    }

    setProgress({
      kind: "pending",
      message: "Checking live ownership and approval…",
    });
    try {
      const [owner, tokenApproval, operatorApproval, latestBlock] =
        await Promise.all([
          publicClient.readContract({
            address: target.prizeToken,
            abi: erc721Abi,
            functionName: "ownerOf",
            args: [target.prizeTokenId],
          }),
          publicClient.readContract({
            address: target.prizeToken,
            abi: erc721Abi,
            functionName: "getApproved",
            args: [target.prizeTokenId],
          }),
          publicClient.readContract({
            address: target.prizeToken,
            abi: erc721Abi,
            functionName: "isApprovedForAll",
            args: [address, protocolDeployment.raffleFactory],
          }),
          publicClient.getBlock(),
        ]);
      if (owner.toLowerCase() !== address.toLowerCase()) {
        throw new Error("The connected wallet no longer owns this NFT.");
      }
      if (
        tokenApproval.toLowerCase() !==
          protocolDeployment.raffleFactory.toLowerCase() &&
        !operatorApproval
      ) {
        throw new Error("Approve the factory to escrow this NFT first.");
      }
      const startTime = BigInt(
        Math.floor(new Date(parsed.data.startTime).getTime() / 1000),
      );
      const endTime = BigInt(
        Math.floor(new Date(parsed.data.endTime).getTime() / 1000),
      );
      if (startTime < latestBlock.timestamp) {
        throw new Error("Start time is now in the past. Choose a later time.");
      }
      if (endTime <= startTime) {
        throw new Error("End time must be after the start time.");
      }

      setProgress({ kind: "pending", message: "Simulating raffle creation…" });
      const hash = await createRaffle(
        {
          publicClient,
          walletClient: wallet.data,
          account: address,
        } as unknown as ActionContext,
        protocolDeployment.raffleFactory,
        {
          prizeToken: target.prizeToken,
          prizeTokenId: target.prizeTokenId,
          quoteToken: selectedQuoteToken.address,
          ticketPrice: parseQuoteAmount(
            parsed.data.ticketPrice,
            selectedQuoteToken.decimals,
          ),
          minimumTickets: BigInt(parsed.data.minimumTickets),
          startTime,
          endTime,
          metadataURI: parsed.data.metadataURI,
        },
      );
      setProgress({
        kind: "pending",
        message: "Escrowing prize and creating tickets…",
      });
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      let raffle: Address | undefined;
      for (const log of receipt.logs) {
        try {
          const decoded = decodeEventLog({
            abi: raffleFactoryAbi,
            data: log.data,
            topics: log.topics,
          });
          if (decoded.eventName === "RaffleCreated") {
            raffle = (decoded.args as { raffle: Address }).raffle;
            break;
          }
        } catch {
          // Logs from the prize NFT and clone are intentionally skipped.
        }
      }
      setProgress({ kind: "success", hash, raffle });
    } catch (error) {
      setProgress({
        kind: "error",
        message:
          error instanceof Error ? error.message : "Raffle creation failed.",
      });
    }
  }

  const canWrite =
    isConnected &&
    address !== undefined &&
    chainId === protocolDeployment?.chainId &&
    parsed.success;

  return (
    <div className="grid gap-8 lg:grid-cols-[1fr_23rem]">
      <div className="space-y-5">
        <FormSection number="1" title="Connect and choose a prize">
          <div className="mb-5 max-w-xs">
            <WalletButton />
          </div>
          <div className="grid gap-4 sm:grid-cols-[1fr_10rem]">
            <Field
              label="ERC721 contract"
              onChange={(value) => update("prizeToken", value)}
              placeholder="0x…"
              value={form.prizeToken}
            />
            <Field
              label="Token ID"
              onChange={(value) => update("prizeTokenId", value)}
              placeholder="42"
              value={form.prizeTokenId}
            />
          </div>
          <button
            className="btn btn-ghost mt-4"
            disabled={metadataState === "loading" || target === undefined}
            onClick={loadMetadata}
            type="button"
          >
            {metadataState === "loading" ? (
              <LoaderCircle aria-hidden className="animate-spin" size={17} />
            ) : (
              <ShieldCheck aria-hidden size={17} />
            )}
            Verify ownership & metadata
          </button>
          {metadataError ? (
            <p className="mt-3 text-sm font-semibold text-red-700" role="alert">
              {metadataError}
            </p>
          ) : null}
          {metadata ? (
            <div className="mt-5 flex gap-4 rounded-2xl border border-black/10 bg-white/50 p-4">
              <div className="relative grid size-24 shrink-0 place-items-center overflow-hidden rounded-xl bg-[#1726a3] text-white">
                {metadata.imageUrl ? (
                  <Image
                    alt=""
                    className="object-cover"
                    fill
                    sizes="96px"
                    src={metadata.imageUrl}
                    unoptimized
                  />
                ) : (
                  <ImageOff aria-hidden />
                )}
              </div>
              <div>
                <p className="font-black">{metadata.name}</p>
                <p className="mt-1 line-clamp-3 text-sm leading-5 text-[#56506a]">
                  {metadata.description}
                </p>
              </div>
            </div>
          ) : null}
        </FormSection>

        <FormSection number="2" title="Set the ticket economics">
          <label className="mb-4 block">
            <span className="mb-2 block text-xs font-extrabold text-[#56506a]">
              Payment token
            </span>
            <select
              className="input"
              disabled={quoteTokens.length === 0}
              onChange={(event) => update("quoteToken", event.target.value)}
              value={selectedQuoteToken?.address ?? ""}
            >
              {quoteTokens.length === 0 ? (
                <option value="">No verified tokens available</option>
              ) : null}
              {quoteTokens.map((token) => (
                <option key={token.address} value={token.address}>
                  {token.symbol} · {token.address.slice(0, 6)}…
                  {token.address.slice(-4)}
                </option>
              ))}
            </select>
            <span className="mt-2 block text-xs leading-5 text-[#56506a]">
              The protocol accepts any contract-backed ERC-20. This official
              creation flow offers only tokens currently verified for discovery.
            </span>
          </label>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field
              label={`Gross ticket price (${selectedQuoteToken?.symbol ?? "token"})`}
              onChange={(value) => update("ticketPrice", value)}
              placeholder="1.00"
              value={form.ticketPrice}
            />
            <Field
              label="Minimum tickets"
              onChange={(value) => update("minimumTickets", value)}
              placeholder="100"
              value={form.minimumTickets}
            />
          </div>
          <p className="mt-4 text-sm leading-6 text-[#56506a]">
            Exactly the minimum counts as met. There is no cap: a high threshold
            simply makes the NFT branch less likely and does not change the
            fallback split.
          </p>
        </FormSection>

        <FormSection number="3" title="Choose the sale window">
          <div className="grid gap-4 sm:grid-cols-2">
            <Field
              label="Starts"
              onChange={(value) => update("startTime", value)}
              type="datetime-local"
              value={form.startTime}
            />
            <Field
              label="Ends"
              onChange={(value) => update("endTime", value)}
              type="datetime-local"
              value={form.endTime}
            />
          </div>
          <div className="mt-4">
            <Field
              label="Optional raffle metadata URI"
              onChange={(value) => update("metadataURI", value)}
              placeholder="ipfs://…"
              value={form.metadataURI}
            />
          </div>
        </FormSection>

        <FormSection number="4" title="Approve and create">
          {!parsed.success ? (
            <ul className="mb-5 list-disc space-y-1 pl-5 text-sm text-red-700">
              {parsed.error.issues.map((issue) => (
                <li key={`${issue.path.join(".")}-${issue.message}`}>
                  {issue.message}
                </li>
              ))}
            </ul>
          ) : null}
          <div className="flex flex-wrap gap-3">
            <button
              className="btn btn-ghost"
              disabled={!canWrite || progress.kind === "pending"}
              onClick={approvePrize}
              type="button"
            >
              {approved ? <Check aria-hidden size={17} /> : null}
              {approved ? "Factory approved" : "1. Approve NFT"}
            </button>
            <button
              className="btn btn-primary"
              disabled={!canWrite || !approved || progress.kind === "pending"}
              onClick={submitRaffle}
              type="button"
            >
              2. Create raffle <ArrowRight aria-hidden size={17} />
            </button>
          </div>
          {progress.kind !== "idle" ? (
            <div
              className={`mt-5 rounded-xl border p-4 text-sm ${
                progress.kind === "error"
                  ? "border-red-900/20 bg-red-50 text-red-800"
                  : "border-black/10 bg-white/55"
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
                  {progress.message}
                </p>
              ) : null}
              {progress.kind === "error" ? progress.message : null}
              {progress.kind === "success" ? (
                <div>
                  <p className="flex items-center gap-2 font-black text-emerald-800">
                    <Check aria-hidden size={17} /> Transaction confirmed
                  </p>
                  <div className="mt-3 flex flex-wrap gap-3">
                    <a
                      className="font-bold underline"
                      href={explorerTransactionUrl(progress.hash)}
                      rel="noreferrer"
                      target="_blank"
                    >
                      View transaction{" "}
                      <ExternalLink className="inline" size={13} />
                    </a>
                    {progress.raffle ? (
                      <Link
                        className="font-bold underline"
                        href={`/raffle/${progress.raffle}`}
                      >
                        Open raffle
                      </Link>
                    ) : null}
                  </div>
                </div>
              ) : null}
            </div>
          ) : null}
        </FormSection>
      </div>

      <aside className="lg:sticky lg:top-6 lg:self-start">
        <div className="ticket-card overflow-hidden">
          <div className="bg-[#1726a3] p-6 text-white">
            <p className="eyebrow !text-[#7fc8ff]">Review economics</p>
            <h2 className="mt-2 text-3xl font-bold">
              One threshold, no ambiguity.
            </h2>
          </div>
          <div className="space-y-4 p-6">
            <OutcomeCard
              color="bg-[#ffdc55]"
              label="Threshold met"
              text="The winning ticket holder claims the NFT. You claim the full net pot."
            />
            <OutcomeCard
              color="bg-[#7fc8ff]"
              label="Threshold missed"
              text="You reclaim the NFT plus 20% of the net pot. The winner claims 80%."
            />
            <div className="border-t border-dashed border-black/25 pt-5 text-sm">
              <p className="flex items-center justify-between">
                <span>Protocol fee</span>
                <strong>5% of gross</strong>
              </p>
              <p className="mt-2 flex items-center justify-between">
                <span>Optional provider</span>
                <strong>+5% of gross</strong>
              </p>
              <p className="mt-4 flex items-start gap-2 rounded-xl bg-amber-100 p-3 text-xs leading-5">
                <CircleDollarSign
                  aria-hidden
                  className="mt-0.5 shrink-0"
                  size={16}
                />
                At {form.ticketPrice || "—"}{" "}
                {selectedQuoteToken?.symbol ?? "tokens"} ×{" "}
                {form.minimumTickets || "0"} tickets, the implied gross
                threshold target is{" "}
                {form.ticketPrice &&
                /^\d+(\.\d+)?$/.test(form.ticketPrice) &&
                /^[1-9]\d*$/.test(form.minimumTickets) &&
                selectedQuoteToken !== undefined
                  ? (() => {
                      try {
                        return formatQuoteAmount(
                          parseQuoteAmount(
                            form.ticketPrice,
                            selectedQuoteToken.decimals,
                          ) * BigInt(form.minimumTickets || "0"),
                          selectedQuoteToken.decimals,
                        );
                      } catch {
                        return "—";
                      }
                    })()
                  : "—"}{" "}
                {selectedQuoteToken?.symbol ?? "tokens"}.
              </p>
            </div>
          </div>
        </div>
      </aside>
    </div>
  );
}

function FormSection({
  number,
  title,
  children,
}: {
  readonly number: string;
  readonly title: string;
  readonly children: React.ReactNode;
}) {
  return (
    <section className="ticket-card p-6 md:p-8">
      <div className="mb-6 flex items-center gap-3">
        <span className="grid size-9 place-items-center rounded-full border border-black bg-[#ffdc55] text-sm font-black">
          {number}
        </span>
        <h2 className="text-2xl font-bold">{title}</h2>
      </div>
      {children}
    </section>
  );
}

function Field({
  label,
  value,
  onChange,
  placeholder,
  type = "text",
}: {
  readonly label: string;
  readonly value: string;
  readonly onChange: (value: string) => void;
  readonly placeholder?: string;
  readonly type?: string;
}) {
  return (
    <label className="block">
      <span className="mb-2 block text-xs font-extrabold text-[#56506a]">
        {label}
      </span>
      <input
        className="input numeric"
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        type={type}
        value={value}
      />
    </label>
  );
}

function OutcomeCard({
  color,
  label,
  text,
}: {
  readonly color: string;
  readonly label: string;
  readonly text: string;
}) {
  return (
    <div className={`rounded-2xl border border-black/15 p-4 ${color}`}>
      <p className="font-black">{label}</p>
      <p className="mt-1 text-xs leading-5 text-black/65">{text}</p>
    </div>
  );
}
