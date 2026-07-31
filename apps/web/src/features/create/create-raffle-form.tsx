"use client";

import {
  ArrowRight,
  Check,
  CircleDollarSign,
  ExternalLink,
  ImageOff,
  Info,
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
import {
  configuredChain,
  explorerTransactionUrl,
  protocolDeployment,
} from "@/lib/protocol";
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

type FormField = keyof z.infer<typeof formSchema>;

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
  // Validation is only surfaced once a field has been visited or the sponsor
  // has tried to submit. Showing every rule up front reads as failure.
  const [touched, setTouched] = useState<ReadonlySet<FormField>>(new Set());
  const [attempted, setAttempted] = useState(false);
  const [metadata, setMetadata] = useState<SafeNftMetadata>();
  const [metadataState, setMetadataState] = useState<
    "idle" | "loading" | "error"
  >("idle");
  const [metadataError, setMetadataError] = useState("");
  const [progress, setProgress] = useState<ProgressState>({ kind: "idle" });
  const [approved, setApproved] = useState(false);

  const deployed = protocolDeployment !== undefined;

  const quoteTokenCountQuery = useReadContract({
    address: protocolDeployment?.raffleFactory,
    abi: raffleFactoryAbi,
    functionName: "verifiedQuoteTokenCount",
    query: { enabled: deployed, staleTime: 30_000 },
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

  const issues = useMemo(() => {
    const map = new Map<string, string>();
    if (!parsed.success) {
      for (const issue of parsed.error.issues) {
        const key = String(issue.path[0] ?? "");
        if (!map.has(key)) map.set(key, issue.message);
      }
    }
    return map;
  }, [parsed]);

  function errorFor(field: FormField): string | undefined {
    if (!attempted && !touched.has(field)) return undefined;
    return issues.get(field);
  }

  const target = useMemo(() => {
    if (!parsed.success) return undefined;
    return {
      prizeToken: parsed.data.prizeToken as Address,
      prizeTokenId: BigInt(parsed.data.prizeTokenId),
    };
  }, [parsed]);

  function update(key: FormField, value: string) {
    setForm((current) => ({ ...current, [key]: value }));
    if (key === "prizeToken" || key === "prizeTokenId") {
      setApproved(false);
      setMetadata(undefined);
    }
  }

  function markTouched(key: FormField) {
    setTouched((current) => new Set(current).add(key));
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
    setAttempted(true);
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
    setAttempted(true);
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

  const impliedTarget = (() => {
    if (selectedQuoteToken === undefined) return undefined;
    if (!/^\d+(\.\d+)?$/.test(form.ticketPrice)) return undefined;
    if (!/^[1-9]\d*$/.test(form.minimumTickets)) return undefined;
    try {
      return formatQuoteAmount(
        parseQuoteAmount(form.ticketPrice, selectedQuoteToken.decimals) *
          BigInt(form.minimumTickets),
        selectedQuoteToken.decimals,
      );
    } catch {
      return undefined;
    }
  })();

  return (
    <div className="grid gap-8 lg:grid-cols-[1fr_22rem]">
      <div className="space-y-5">
        {!deployed ? (
          <div className="card flex gap-3 border-[var(--line-strong)] bg-[var(--yellow-wash)] p-5 text-sm leading-6 text-[var(--amber-ink)]">
            <Info aria-hidden className="mt-0.5 shrink-0" size={18} />
            <p>
              <strong>No deployment on {configuredChain.name} yet.</strong> You
              can walk through the whole flow, but creating a raffle stays
              disabled until a verified factory is registered for this network.
            </p>
          </div>
        ) : null}

        <FormSection
          done={target !== undefined}
          number="1"
          title="Connect and choose a prize"
        >
          <div className="mb-5 max-w-xs">
            <WalletButton full />
          </div>
          <div className="grid gap-4 sm:grid-cols-[1fr_10rem]">
            <Field
              error={errorFor("prizeToken")}
              label="ERC721 contract"
              onBlur={() => markTouched("prizeToken")}
              onChange={(value) => update("prizeToken", value)}
              placeholder="0x…"
              value={form.prizeToken}
            />
            <Field
              error={errorFor("prizeTokenId")}
              label="Token ID"
              onBlur={() => markTouched("prizeTokenId")}
              onChange={(value) => update("prizeTokenId", value)}
              placeholder="42"
              value={form.prizeTokenId}
            />
          </div>
          <button
            className="btn btn-outline mt-4"
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
            <p className="field-error" role="alert">
              {metadataError}
            </p>
          ) : null}
          {metadata ? (
            <div className="mt-5 flex gap-4 rounded-2xl bg-[var(--paper-sunk)] p-4">
              <div className="relative grid size-24 shrink-0 place-items-center overflow-hidden rounded-2xl bg-[var(--ink)] text-white">
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
                <p className="font-extrabold">{metadata.name}</p>
                <p className="mt-1 line-clamp-3 text-sm leading-5 text-[var(--ink-2)]">
                  {metadata.description}
                </p>
              </div>
            </div>
          ) : null}
        </FormSection>

        <FormSection
          done={
            selectedQuoteToken !== undefined &&
            issues.get("ticketPrice") === undefined
          }
          number="2"
          title="Set the ticket economics"
        >
          <label className="mb-4 block">
            <span className="field-label">Payment token</span>
            <select
              className="select"
              disabled={quoteTokens.length === 0}
              onChange={(event) => update("quoteToken", event.target.value)}
              value={selectedQuoteToken?.address ?? ""}
            >
              {quoteTokens.length === 0 ? (
                <option value="">
                  {deployed
                    ? "No verified tokens available yet"
                    : "Available after deployment"}
                </option>
              ) : null}
              {quoteTokens.map((token) => (
                <option key={token.address} value={token.address}>
                  {token.symbol} · {token.address.slice(0, 6)}…
                  {token.address.slice(-4)}
                </option>
              ))}
            </select>
            <span className="field-hint">
              The protocol accepts any contract-backed ERC-20. This official
              flow offers only tokens currently verified for discovery.
            </span>
          </label>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field
              error={errorFor("ticketPrice")}
              label={`Gross ticket price (${selectedQuoteToken?.symbol ?? "token"})`}
              onBlur={() => markTouched("ticketPrice")}
              onChange={(value) => update("ticketPrice", value)}
              placeholder="1.00"
              value={form.ticketPrice}
            />
            <Field
              error={errorFor("minimumTickets")}
              label="Minimum tickets"
              onBlur={() => markTouched("minimumTickets")}
              onChange={(value) => update("minimumTickets", value)}
              placeholder="100"
              value={form.minimumTickets}
            />
          </div>
          <p className="field-hint">
            Exactly the minimum counts as met. There is no cap: a high threshold
            simply makes the NFT branch less likely and never changes the
            fallback split.
          </p>
        </FormSection>

        <FormSection done number="3" title="Choose the sale window">
          <div className="grid gap-4 sm:grid-cols-2">
            <Field
              error={errorFor("startTime")}
              label="Starts"
              onBlur={() => markTouched("startTime")}
              onChange={(value) => update("startTime", value)}
              type="datetime-local"
              value={form.startTime}
            />
            <Field
              error={errorFor("endTime")}
              label="Ends"
              onBlur={() => markTouched("endTime")}
              onChange={(value) => update("endTime", value)}
              type="datetime-local"
              value={form.endTime}
            />
          </div>
          <div className="mt-4">
            <Field
              error={errorFor("metadataURI")}
              label="Raffle metadata URI (optional)"
              onBlur={() => markTouched("metadataURI")}
              onChange={(value) => update("metadataURI", value)}
              placeholder="ipfs://…"
              value={form.metadataURI}
            />
          </div>
        </FormSection>

        <FormSection number="4" title="Approve and create">
          {attempted && !parsed.success ? (
            <ul
              className="mb-5 space-y-1.5 rounded-2xl bg-[var(--danger-wash)] p-4 text-sm font-bold text-[var(--danger)]"
              role="alert"
            >
              {[...issues.values()].map((message) => (
                <li key={message}>{message}</li>
              ))}
            </ul>
          ) : null}
          <div className="flex flex-wrap gap-3">
            <button
              className="btn btn-outline"
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
              className={`mt-5 rounded-2xl p-4 text-sm ${
                progress.kind === "error"
                  ? "bg-[var(--danger-wash)] text-[var(--danger)]"
                  : "bg-[var(--paper-sunk)]"
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
              {progress.kind === "error" ? (
                <p className="font-bold">{progress.message}</p>
              ) : null}
              {progress.kind === "success" ? (
                <div>
                  <p className="flex items-center gap-2 font-extrabold text-[#0d6b45]">
                    <Check aria-hidden size={17} /> Transaction confirmed
                  </p>
                  <div className="mt-3 flex flex-wrap gap-4">
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

      <aside className="lg:sticky lg:top-24 lg:self-start">
        <div className="card overflow-hidden">
          <div className="panel-ink p-6">
            <p className="eyebrow !text-[var(--sky)]">Review economics</p>
            <h2 className="mt-2 text-2xl">One threshold, no ambiguity.</h2>
          </div>
          <div className="space-y-4 p-6">
            <OutcomeCard
              tint="var(--yellow-wash)"
              label="Threshold met"
              text="The winning ticket holder claims the NFT. You claim the distributable pot after the 5% settlement fee."
            />
            <OutcomeCard
              tint="var(--sky-wash)"
              label="Threshold missed"
              text="You reclaim the NFT plus 20% of the distributable pot. The winner claims 80%."
            />
            <div className="perforation !my-5" />
            <dl className="space-y-2 text-sm">
              <div className="flex items-center justify-between">
                <dt className="text-[var(--ink-2)]">Protocol fee</dt>
                <dd className="font-extrabold">5% of gross</dd>
              </div>
              <div className="flex items-center justify-between">
                <dt className="text-[var(--ink-2)]">Fee timing</dt>
                <dd className="font-extrabold">At resolution</dd>
              </div>
            </dl>
            <p className="flex items-start gap-2 rounded-2xl bg-[var(--paper-sunk)] p-3 text-xs leading-5 text-[var(--ink-2)]">
              <CircleDollarSign
                aria-hidden
                className="mt-0.5 shrink-0"
                size={16}
              />
              <span>
                At {form.ticketPrice || "—"}{" "}
                {selectedQuoteToken?.symbol ?? "tokens"} ×{" "}
                {form.minimumTickets || "0"} tickets, the implied gross minimum
                target is{" "}
                <strong className="numeric">
                  {impliedTarget ?? "—"}{" "}
                  {selectedQuoteToken?.symbol ?? "tokens"}
                </strong>
                .
              </span>
            </p>
            <p className="text-xs leading-5 text-[var(--ink-faint)]">
              The minimum selects the NFT branch but does not stop sales.
              Tickets remain available until the fixed closing time.
            </p>
          </div>
        </div>
      </aside>
    </div>
  );
}

function FormSection({
  number,
  title,
  done = false,
  children,
}: {
  readonly number: string;
  readonly title: string;
  readonly done?: boolean;
  readonly children: React.ReactNode;
}) {
  return (
    <section className="card p-6 md:p-7">
      <div className="mb-6 flex items-center gap-3">
        <span
          className={`grid size-8 shrink-0 place-items-center rounded-full text-sm font-extrabold ${
            done
              ? "bg-[var(--grass)] text-white"
              : "bg-[var(--yellow)] text-[var(--ink)]"
          }`}
        >
          {done ? <Check aria-hidden size={16} /> : number}
        </span>
        <h2 className="text-xl md:text-2xl">{title}</h2>
      </div>
      {children}
    </section>
  );
}

function Field({
  label,
  value,
  onChange,
  onBlur,
  placeholder,
  error,
  type = "text",
}: {
  readonly label: string;
  readonly value: string;
  readonly onChange: (value: string) => void;
  readonly onBlur?: () => void;
  readonly placeholder?: string;
  readonly error?: string;
  readonly type?: string;
}) {
  return (
    <label className="block">
      <span className="field-label">{label}</span>
      <input
        aria-invalid={error !== undefined}
        className="input numeric"
        onBlur={onBlur}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        type={type}
        value={value}
      />
      {error ? <span className="field-error">{error}</span> : null}
    </label>
  );
}

function OutcomeCard({
  tint,
  label,
  text,
}: {
  readonly tint: string;
  readonly label: string;
  readonly text: string;
}) {
  return (
    <div className="rounded-2xl p-4" style={{ background: tint }}>
      <p className="font-extrabold">{label}</p>
      <p className="mt-1 text-xs leading-5 text-[var(--ink-2)]">{text}</p>
    </div>
  );
}
