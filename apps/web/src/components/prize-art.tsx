import Image from "next/image";

/**
 * Artwork for a prize NFT.
 *
 * Prize media is untrusted and frequently unavailable, so every raffle gets a
 * stable, brand-native gradient derived from its contract address and token ID.
 * A real image, when one resolves, is layered on top: `contain` keeps the whole
 * token visible over a blurred copy of itself, which is the treatment square
 * token art needs inside a wide frame.
 */
const palettes = [
  ["#ec2fa0", "#ff9ad5", "#5aa9ff"],
  ["#5aa9ff", "#a78bfa", "#ec2fa0"],
  ["#ffd84d", "#ff9ad5", "#ec2fa0"],
  ["#22b573", "#5aa9ff", "#a78bfa"],
  ["#1b2a9b", "#5aa9ff", "#ffd84d"],
  ["#ff7a59", "#ffd84d", "#ec2fa0"],
] as const;

function hash(seed: string): number {
  let value = 2_166_136_261;
  for (let index = 0; index < seed.length; index += 1) {
    value ^= seed.charCodeAt(index);
    value = Math.imul(value, 16_777_619);
  }
  return Math.abs(value);
}

export function PrizeArt({
  seed,
  imageUrl,
  fit = "cover",
  pixelated = false,
  className = "",
}: {
  readonly seed: string;
  readonly imageUrl?: string;
  readonly fit?: "cover" | "contain";
  readonly pixelated?: boolean;
  readonly className?: string;
}) {
  const digest = hash(seed.toLowerCase());
  const [from, via, to] = palettes[digest % palettes.length]!;
  const x = 18 + (digest % 5) * 12;
  const y = 14 + ((digest >> 3) % 5) * 12;
  const rendering = pixelated ? ("pixelated" as const) : undefined;

  return (
    <div
      className={`relative isolate overflow-hidden ${className}`}
      style={{
        backgroundColor: from,
        backgroundImage: `radial-gradient(circle at ${x}% ${y}%, ${via} 0%, transparent 55%), radial-gradient(circle at ${100 - x}% ${100 - y}%, ${to} 0%, transparent 60%), linear-gradient(135deg, ${from}, ${to})`,
      }}
    >
      {imageUrl === undefined ? (
        // Ticket silhouette echoing the brand mark.
        <svg
          aria-hidden
          className="absolute left-1/2 top-1/2 h-[62%] w-auto -translate-x-1/2 -translate-y-1/2 rotate-[-8deg] opacity-[0.22]"
          fill="none"
          viewBox="0 0 48 64"
        >
          <path
            d="M8 6h32v14a6 6 0 0 0 0 12v26H8V32a6 6 0 0 0 0-12V6Z"
            stroke="white"
            strokeWidth="3.5"
            strokeLinejoin="round"
          />
          <path
            d="M24 18v14"
            stroke="white"
            strokeWidth="3.5"
            strokeLinecap="round"
          />
        </svg>
      ) : (
        <>
          {fit === "contain" ? (
            <Image
              alt=""
              aria-hidden
              className="scale-125 object-cover blur-2xl saturate-150"
              fill
              sizes="800px"
              src={imageUrl}
              unoptimized
            />
          ) : null}
          <Image
            alt=""
            className={`relative ${fit === "contain" ? "object-contain" : "object-cover"}`}
            fill
            sizes="(max-width: 768px) 100vw, 500px"
            src={imageUrl}
            style={{ imageRendering: rendering }}
            unoptimized
          />
        </>
      )}
    </div>
  );
}
