import Image from "next/image";

export function BrandMark({
  size = 30,
  className = "",
}: {
  readonly size?: number;
  readonly className?: string;
}) {
  return (
    <Image
      alt=""
      aria-hidden
      className={className}
      height={size}
      priority
      src="/brand/logo-raffle-pink.png"
      style={{ height: size, width: "auto" }}
      width={Math.round(size * 0.89)}
    />
  );
}

export function Wordmark({ className = "" }: { readonly className?: string }) {
  return (
    <span
      className={`font-extrabold lowercase tracking-[-0.03em] ${className}`}
    >
      raffle<span className="text-[var(--pink)]">.fun</span>
    </span>
  );
}
