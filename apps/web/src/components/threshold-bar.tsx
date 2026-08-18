import { reserveScale } from "@/lib/economics";
import { Trophy } from "lucide-react";

/**
 * Progress toward the NFT reserve.
 *
 * The track keeps headroom past the reserve so the flip point reads as a
 * line the fill is travelling towards, and any overshoot stays visible as a
 * distinct segment instead of a bar that is simply "full".
 */
export function ThresholdBar({
  total,
  reserve,
  size = "sm",
  showLabel = false,
}: {
  readonly total: bigint;
  readonly reserve: bigint;
  readonly size?: "sm" | "lg";
  readonly showLabel?: boolean;
}) {
  const { fillPercent, markerPercent, overshootPercent, met } = reserveScale(
    total,
    reserve,
  );

  const large = size === "lg";

  return (
    <div className={showLabel ? "pt-7" : undefined}>
      <div className="relative">
        <div
          aria-label={`${total.toString()} of ${reserve.toString()} entries toward the NFT reserve`}
          aria-valuemax={100}
          aria-valuemin={0}
          aria-valuenow={Math.min(100, fillPercent)}
          className={`progress-track ${large ? "!h-4" : ""}`}
          role="progressbar"
        >
          {/* Sales up to the reserve. */}
          <div
            className="progress-fill"
            data-met={met}
            style={{ width: `${Math.max(fillPercent, 1.5)}%` }}
          />
          {/* Sales past it, so overshoot is legible rather than invisible. */}
          {overshootPercent > 0 ? (
            <div
              className="absolute inset-y-0 rounded-r-full bg-[var(--grass-deep)]"
              style={{
                left: `${markerPercent}%`,
                width: `${overshootPercent}%`,
              }}
            />
          ) : null}
        </div>

        {/* The flip point. */}
        <span
          aria-hidden
          className="absolute -top-1 bottom-[-0.25rem] w-[3px] -translate-x-1/2 rounded-full"
          style={{
            left: `${markerPercent}%`,
            background: met ? "var(--grass-deep)" : "var(--ink)",
          }}
        />

        {showLabel ? (
          <span
            className="absolute -top-7 -translate-x-1/2 whitespace-nowrap rounded-full px-2 py-0.5 text-[0.68rem] font-extrabold"
            style={{
              left: `${markerPercent}%`,
              background: met ? "var(--grass-wash)" : "var(--paper-sunk)",
              color: met ? "var(--grass-deep)" : "var(--ink)",
            }}
          >
            {met ? (
              <span className="inline-flex items-center gap-1">
                <Trophy aria-hidden size={11} /> NFT unlocked
              </span>
            ) : (
              `NFT at ${reserve.toString()}`
            )}
          </span>
        ) : null}
      </div>
    </div>
  );
}
