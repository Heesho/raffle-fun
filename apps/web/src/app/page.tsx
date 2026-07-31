import { ArrowRight, Coins, Ticket, Trophy } from "lucide-react";
import Link from "next/link";

import { TicketProp } from "@/components/ticket-prop";
import { RaffleDirectory } from "@/features/discover/raffle-directory";

const steps = [
  {
    title: "Pick a prize",
    text: "Browse open raffles. Every ticket in one raffle has exactly the same chance.",
  },
  {
    title: "Buy tickets",
    text: "The advertised price is the total you pay. Tickets are NFTs you can resell before the draw.",
  },
  {
    title: "One random draw",
    text: "Pyth Entropy picks a single winning ticket. Hit the threshold and it wins the NFT; miss it and it wins 80% of the distributable pot.",
  },
] as const;

/** Step markers, in the board's pink / navy / yellow rotation. */
const stepChips = [
  { fill: "var(--pink)", ink: "#ffffff" },
  { fill: "var(--brand-navy)", ink: "var(--yellow)" },
  { fill: "var(--yellow)", ink: "var(--brand-navy)" },
] as const;

export default function HomePage() {
  return (
    <>
      <Hero />
      <HowItWorks />
      <RaffleDirectory />
    </>
  );
}

function Hero() {
  return (
    <section className="panel panel-brand panel-arc">
      {/* Ticket confetti, composed rather than scattered: two behind the copy,
          one tucked behind the card, all in brand skins. */}
      <TicketProp
        className="bottom-[14%] left-[3%] hidden 2xl:block"
        delay={0}
        size={96}
        skin="pink"
        tilt={-18}
      />
      <TicketProp
        className="right-[4%] top-[12%] hidden lg:block"
        delay={1.6}
        size={54}
        skin="yellow"
        tilt={16}
      />
      <TicketProp
        className="bottom-[10%] right-[8%] hidden lg:block"
        delay={0.9}
        size={78}
        skin="blue"
        tilt={22}
      />

      <div className="page-shell grid items-center gap-12 pb-20 pt-16 md:pb-28 md:pt-20 lg:grid-cols-[1.02fr_.98fr] lg:gap-16">
        <div>
          <span className="chip border-white/25 bg-white/15 text-white backdrop-blur">
            <span className="relative flex size-1.5">
              <span className="absolute inline-flex size-full animate-ping rounded-full bg-[var(--yellow)] opacity-80" />
              <span className="relative inline-flex size-1.5 rounded-full bg-[var(--yellow)]" />
            </span>
            Permissionless NFT raffles on Base
          </span>

          <h1 className="mt-6 text-[length:var(--display)] text-white">
            A fair draw,
            <br />
            in plain sight.
          </h1>

          <p className="mt-6 max-w-[34rem] text-[length:var(--text-md)] leading-relaxed text-white/85">
            One NFT prize. Equal-chance tickets. A minimum threshold decides
            whether the winner takes the NFT or 80% of the distributable pot —
            and every payout is fixed in code before the first ticket sells.
          </p>

          <div className="mt-9 flex flex-wrap gap-3">
            <a className="btn btn-on-brand btn-lg" href="#raffles-heading">
              Explore raffles <ArrowRight aria-hidden size={17} />
            </a>
            <Link className="btn btn-on-ink btn-lg" href="/create">
              Sponsor a prize
            </Link>
          </div>

          <dl className="mt-10 flex flex-wrap gap-x-10 gap-y-4 border-t border-white/20 pt-6">
            {[
              { term: "Protocol fee", detail: "5% at resolution" },
              { term: "Randomness", detail: "Pyth Entropy" },
              { term: "Tickets", detail: "Transferable NFTs" },
            ].map((item) => (
              <div key={item.term}>
                <dt className="eyebrow">{item.term}</dt>
                <dd className="mt-1 text-[length:var(--text-base)] font-semibold text-white">
                  {item.detail}
                </dd>
              </div>
            ))}
          </dl>
        </div>

        <SettlementCard />
      </div>
    </section>
  );
}

/**
 * The single idea a first-time visitor has to understand: one draw resolves
 * into one of two known outcomes. Presented as a comparison, with the branch
 * colours (yellow = NFT, sky = cash) that the rest of the product reuses.
 */
function SettlementCard() {
  return (
    <div className="card mx-auto w-full max-w-[30rem] overflow-hidden shadow-[var(--shadow-lg)]">
      <div className="px-6 pt-6">
        <p className="eyebrow">How settlement works</p>
        <p className="mt-1.5 font-[family-name:var(--font-display)] text-[length:var(--text-xl)] font-extrabold tracking-[-0.02em]">
          One draw. Two outcomes.
        </p>
      </div>

      <div className="perforation mx-6 my-5" />

      <div className="grid gap-3 px-6 sm:grid-cols-2">
        <Outcome
          detail="The sponsor claims the distributable pot after the 5% fee."
          fill="var(--yellow)"
          icon={<Trophy aria-hidden size={17} />}
          ink="var(--brand-navy)"
          label="Threshold met"
          title="Winner takes the NFT"
        />
        <Outcome
          detail="The sponsor reclaims the NFT plus 20% of the distributable pot."
          fill="var(--brand-navy)"
          icon={<Coins aria-hidden size={17} />}
          ink="#ffffff"
          label="Threshold missed"
          title="Winner takes 80% cash"
        />
      </div>

      <div className="mt-6 flex flex-wrap items-center justify-between gap-2 border-t border-[var(--line)] bg-[var(--paper-sunk)] px-6 py-4">
        <p className="text-[length:var(--text-sm)] font-semibold">
          The ticket price is the total you pay
        </p>
        <p className="numeric text-[length:var(--text-xs)] text-[var(--ink-3)]">
          One 5% protocol fee at resolution
        </p>
      </div>
    </div>
  );
}

/**
 * The two branches as solid colour-blocked tiles — yellow-on-navy and
 * navy-on-white, the pairings the brand board uses for its stacked pills.
 */
function Outcome({
  detail,
  fill,
  icon,
  ink,
  label,
  title,
}: {
  readonly detail: string;
  readonly fill: string;
  readonly icon: React.ReactNode;
  readonly ink: string;
  readonly label: string;
  readonly title: string;
}) {
  return (
    <div
      className="rounded-[var(--radius)] p-4"
      style={{ background: fill, color: ink }}
    >
      <span aria-hidden style={{ opacity: 0.85 }}>
        {icon}
      </span>
      <p
        className="mt-2.5 text-[length:var(--text-2xs)] font-bold uppercase tracking-[0.1em]"
        style={{ opacity: 0.65 }}
      >
        {label}
      </p>
      <p className="mt-1 text-[length:var(--text-base)] font-semibold leading-snug">
        {title}
      </p>
      <p
        className="mt-2 text-[length:var(--text-xs)] leading-relaxed"
        style={{ opacity: 0.75 }}
      >
        {detail}
      </p>
    </div>
  );
}

function HowItWorks() {
  return (
    <section className="panel panel-cream band-top">
      <div className="page-shell py-14 md:py-20">
        <div className="flex flex-wrap items-end justify-between gap-6">
          <div>
            <p className="eyebrow">Three steps</p>
            <h2 className="mt-2 text-[length:var(--text-3xl)]">
              How a raffle works
            </h2>
          </div>
          <Link className="btn btn-outline" href="/docs">
            Read the mechanics <ArrowRight aria-hidden size={16} />
          </Link>
        </div>

        {/* The board numbers its steps in solid brand chips — pink, navy,
            yellow — over a cream ground. */}
        <ol className="mt-10 grid gap-6 md:grid-cols-3">
          {steps.map((step, index) => (
            <li className="card-flat p-6" key={step.title}>
              <span
                className="numeric grid size-9 place-items-center rounded-full text-[length:var(--text-sm)] font-bold"
                style={{
                  background: stepChips[index]!.fill,
                  color: stepChips[index]!.ink,
                }}
              >
                {index + 1}
              </span>
              <h3 className="mt-4 text-[length:var(--text-lg)]">
                {step.title}
              </h3>
              <p className="mt-2 text-[length:var(--text-base)] leading-relaxed text-[var(--ink-2)]">
                {step.text}
              </p>
            </li>
          ))}
        </ol>

        <p className="mt-10 flex items-center gap-2 text-[length:var(--text-sm)] text-[var(--ink-3)]">
          <Ticket aria-hidden size={15} />
          Tickets are ERC-721s — resell yours on any marketplace before the draw
          closes.
        </p>
      </div>
    </section>
  );
}
