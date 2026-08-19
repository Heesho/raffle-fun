import type { IndexedRaffle } from "@/lib/subgraph";

export type ActiveRafflePhase =
  "PENDING_TIME" | "LIVE" | "AWAITING_DRAW" | "REFUND_READY";

/**
 * Refines time-sensitive onchain states for discovery UI. ACTIVE spans open
 * sales, the draw-request window, and a permissionless refund transition;
 * DRAWING likewise becomes refund-ready at its hard callback deadline.
 */
export function activeRafflePhase(
  raffle: IndexedRaffle,
  nowSeconds: number | undefined,
): ActiveRafflePhase | undefined {
  if (raffle.state !== "ACTIVE" && raffle.state !== "DRAWING") return undefined;
  if (nowSeconds === undefined) return "PENDING_TIME";

  const now = BigInt(nowSeconds);
  if (raffle.state === "DRAWING") {
    return raffle.callbackDeadline !== null &&
      now >= BigInt(raffle.callbackDeadline)
      ? "REFUND_READY"
      : undefined;
  }
  if (now < BigInt(raffle.endTime)) return "LIVE";
  if (
    BigInt(raffle.totalEntries) === 0n ||
    now >= BigInt(raffle.drawRequestDeadline)
  ) {
    return "REFUND_READY";
  }
  return "AWAITING_DRAW";
}
