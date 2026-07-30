import { Trophy } from "lucide-react";

import { thresholdScale } from "@/lib/economics";

/**
 * Progress toward the NFT threshold.
 *
 * The track keeps headroom past the threshold so the flip point reads as a
 * line the fill is travelling towards, and any overshoot stays visible as a
 * distinct segment instead of a bar that is simply "full".
 */
export function ThresholdBar({
  total,
  minimum,
  size = "sm",
  showLabel = false,
}: {
  readonly total: bigint;
  readonly minimum: bigint;
  readonly size?: "sm" | "lg";
  readonly showLabel?: boolean;
}) {
  const { fillPercent, markerPercent, overshootPercent, met } = thresholdScale(
    total,
    minimum,
  );
  const large = size === "lg";

  return (
    <div className={showLabel ? "pt-7" : undefined}>
      <div className="relative">
        <div
          aria-label={`${total} of ${minimum} tickets toward the NFT threshold`}
          aria-valuemax={Number(minimum)}
          aria-valuemin={0}
          aria-valuenow={Number(total)}
          className={`progress-track ${large ? "!h-4" : ""}`}
          role="progressbar"
        >
          {/* Sales up to the threshold. */}
          <div
            className="progress-fill"
            data-met={met}
            style={{ width: `${Math.max(fillPercent, 1.5)}%` }}
          />
          {/* Sales past it, so overshoot is legible rather than invisible. */}
          {overshootPercent > 0 ? (
            <div
              className="absolute inset-y-0 rounded-r-full bg-[#0d6b45]"
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
            background: met ? "#0d6b45" : "var(--ink)",
          }}
        />

        {showLabel ? (
          <span
            className="absolute -top-7 -translate-x-1/2 whitespace-nowrap rounded-full px-2 py-0.5 text-[0.68rem] font-extrabold"
            style={{
              left: `${markerPercent}%`,
              background: met ? "var(--grass-wash)" : "var(--paper-sunk)",
              color: met ? "#0d6b45" : "var(--ink)",
            }}
          >
            {met ? (
              <span className="inline-flex items-center gap-1">
                <Trophy aria-hidden size={11} /> NFT unlocked
              </span>
            ) : (
              `NFT at ${minimum.toString()}`
            )}
          </span>
        ) : null}
      </div>
    </div>
  );
}
