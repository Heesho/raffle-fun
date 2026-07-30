import type { ReactNode } from "react";

export type StatusTone = "neutral" | "active" | "warning" | "resolved" | "good";

const tones: Record<StatusTone, string> = {
  neutral: "bg-[var(--paper-sunk)] text-[var(--ink-soft)]",
  active: "bg-[var(--grass-wash)] text-[#0d6b45]",
  warning: "bg-[var(--amber-wash)] text-[var(--amber-ink)]",
  resolved: "bg-[var(--sky-wash)] text-[#1c5fa8]",
  good: "bg-[var(--pink-wash)] text-[var(--pink-strong)]",
};

export function StatusPill({
  children,
  tone = "neutral",
  pulse = false,
}: {
  readonly children: ReactNode;
  readonly tone?: StatusTone;
  readonly pulse?: boolean;
}) {
  return (
    <span className={`chip capitalize ${tones[tone]}`}>
      <span className="relative flex size-1.5">
        {pulse ? (
          <span className="absolute inline-flex size-full animate-ping rounded-full bg-current opacity-60" />
        ) : null}
        <span className="relative inline-flex size-1.5 rounded-full bg-current" />
      </span>
      {children}
    </span>
  );
}
