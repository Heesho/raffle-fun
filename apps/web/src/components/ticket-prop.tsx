/**
 * The glossy floating ticket from the brand board.
 *
 * Rendered as inline SVG so it inherits the palette, scales cleanly, and costs
 * nothing to scatter. Decorative only — always aria-hidden.
 */
const skins = {
  pink: { face: "#ec2fa0", shade: "#c81f86", gloss: "#ff8ed4" },
  yellow: { face: "#ffd84d", shade: "#e8b91f", gloss: "#fff0a8" },
  blue: { face: "#3d8bfd", shade: "#2568d6", gloss: "#9ec6ff" },
  violet: { face: "#8b5cf6", shade: "#6d3fd6", gloss: "#c8b0ff" },
} as const;

export type TicketSkin = keyof typeof skins;

export function TicketProp({
  skin = "pink",
  size = 88,
  tilt = 0,
  delay = 0,
  className = "",
  style,
}: {
  readonly skin?: TicketSkin;
  readonly size?: number;
  readonly tilt?: number;
  readonly delay?: number;
  readonly className?: string;
  readonly style?: React.CSSProperties;
}) {
  const { face, shade, gloss } = skins[skin];

  return (
    <svg
      aria-hidden
      className={`prop ${className}`}
      fill="none"
      height={size * 1.34}
      style={
        {
          "--tilt": `${tilt}deg`,
          animationDelay: `${delay}s`,
          transform: `rotate(${tilt}deg)`,
          ...style,
        } as React.CSSProperties
      }
      viewBox="0 0 72 96"
      width={size}
    >
      {/* Body: a ticket with the brand's pinched waist. */}
      <path
        d="M10 6h52v26a10 10 0 0 0 0 20v36H10V52a10 10 0 0 0 0-20V6Z"
        fill={shade}
      />
      <path
        d="M8 4h52v26a10 10 0 0 0 0 20v36H8V50a10 10 0 0 0 0-20V4Z"
        fill={face}
      />
      {/* Inner cut, matching the logo's negative space. */}
      <path
        d="M18 15h32v10.5a7.5 7.5 0 0 0 0 15V71H18V40.5a7.5 7.5 0 0 0 0-15V15Z"
        stroke="white"
        strokeWidth="5"
        strokeLinejoin="round"
      />
      <path
        d="M34 26v14"
        stroke="white"
        strokeLinecap="round"
        strokeWidth="5"
      />
      {/* Gloss highlight. */}
      <path d="M12 8h9v78h-9V8Z" fill={gloss} opacity="0.55" />
    </svg>
  );
}
