import type { ReactNode } from "react";

/**
 * The standard opening band for an inner page.
 *
 * Every page starts on a saturated brand field so the product reads as one
 * thing rather than a set of white forms with a coloured home page. `tone`
 * picks which field: the full gradient for the marketing-weight pages, the
 * deep indigo for working pages where a loud gradient would compete with the
 * content below it.
 */
export function PageHeader({
  eyebrow,
  title,
  lede,
  aside,
  tone = "ink",
}: {
  readonly eyebrow: string;
  readonly title: ReactNode;
  readonly lede?: ReactNode;
  readonly aside?: ReactNode;
  readonly tone?: "ink" | "brand";
}) {
  return (
    <section
      className={`panel ${tone === "brand" ? "panel-brand panel-arc" : "panel-ink"}`}
    >
      <div className="page-shell flex flex-wrap items-end justify-between gap-8 py-12 md:py-16">
        <div className="max-w-3xl">
          <p className="eyebrow">{eyebrow}</p>
          <h1 className="mt-3 text-[length:var(--text-4xl)] text-white">
            {title}
          </h1>
          {lede ? (
            <p className="mt-4 max-w-2xl text-[length:var(--text-md)] leading-relaxed text-white/80">
              {lede}
            </p>
          ) : null}
        </div>
        {aside ? <div className="shrink-0">{aside}</div> : null}
      </div>
    </section>
  );
}
