import type { ReactNode } from "react";

export function StatusPill({
  children,
  tone = "neutral",
}: {
  readonly children: ReactNode;
  readonly tone?: "neutral" | "active" | "warning" | "resolved";
}) {
  const tones = {
    neutral: "border-black/15 bg-white/70 text-[#56506a]",
    active: "border-emerald-900/15 bg-emerald-100 text-emerald-900",
    warning: "border-amber-900/15 bg-amber-100 text-amber-950",
    resolved: "border-violet-900/15 bg-violet-100 text-violet-950",
  };

  return (
    <span
      className={`inline-flex items-center gap-2 rounded-full border px-3 py-1 text-xs font-extrabold ${tones[tone]}`}
    >
      <span className="size-1.5 rounded-full bg-current opacity-60" />
      {children}
    </span>
  );
}
