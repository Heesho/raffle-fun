import { ArrowRight, Dices, Sparkles, Ticket, Trophy } from "lucide-react";
import Link from "next/link";

import { TicketProp } from "@/components/ticket-prop";
import { RaffleDirectory } from "@/features/discover/raffle-directory";

const steps = [
  {
    icon: Sparkles,
    title: "Pick a prize",
    text: "Browse open raffles. Every ticket in one raffle has exactly the same chance.",
  },
  {
    icon: Ticket,
    title: "Buy tickets",
    text: "The advertised price is the total you pay. Tickets are NFTs you can resell before the draw.",
  },
  {
    icon: Dices,
    title: "One random draw",
    text: "Pyth Entropy picks a single winning ticket. Hit the threshold and it wins the NFT; miss it and it wins 80% of the distributable pot.",
  },
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
    <section className="panel panel-bloom">
      {/* Floating ticket props, straight off the brand board. */}
      <TicketProp
        className="bottom-[14%] left-[2%] hidden lg:block"
        delay={0}
        size={104}
        skin="pink"
        tilt={-22}
      />
      <TicketProp
        className="left-[52%] top-[6%] hidden xl:block"
        delay={1.4}
        size={62}
        skin="blue"
        tilt={18}
      />
      <TicketProp
        className="bottom-[10%] left-[42%] hidden lg:block"
        delay={2.2}
        size={74}
        skin="yellow"
        tilt={-12}
      />
      <TicketProp
        className="right-[3%] top-[62%] hidden md:block"
        delay={0.8}
        size={92}
        skin="violet"
        tilt={26}
      />

      <div className="page-shell relative grid items-center gap-14 pb-20 pt-14 md:pb-28 md:pt-20 lg:grid-cols-[1.05fr_.95fr]">
        <div>
          <span className="chip bg-white/70 text-[var(--ink)] backdrop-blur">
            <span className="relative flex size-2">
              <span className="absolute inline-flex size-full animate-ping rounded-full bg-[var(--pink)] opacity-70" />
              <span className="relative inline-flex size-2 rounded-full bg-[var(--pink)]" />
            </span>
            Permissionless NFT raffles on Base
          </span>

          <h1 className="mt-5 text-[clamp(2.75rem,8vw,5.5rem)]">
            A fair draw,
            <br />
            <span className="text-[var(--pink)]">in plain sight.</span>
          </h1>

          <p className="mt-6 max-w-xl text-base font-medium leading-7 text-[var(--ink-soft)] md:text-lg md:leading-8">
            One NFT prize. Equal-chance tickets. A minimum threshold that
            decides whether the winner takes the NFT or 80% of the distributable
            pot. Every payout is fixed in code before the first ticket sells.
          </p>

          <div className="mt-8 flex flex-wrap gap-3">
            <a className="btn btn-primary btn-lg" href="#raffles-heading">
              Explore raffles <ArrowRight aria-hidden size={18} />
            </a>
            <Link className="btn btn-outline btn-lg" href="/create">
              Sponsor a prize
            </Link>
          </div>
        </div>

        <SettlementCard />
      </div>
    </section>
  );
}

function SettlementCard() {
  return (
    <div className="card mx-auto w-full max-w-lg overflow-hidden p-6 shadow-[var(--shadow-lift)] sm:p-8">
      <p className="eyebrow">How settlement works</p>
      <p className="mt-2 text-3xl">One draw. Two outcomes.</p>

      <div className="perforation my-6" />

      <div className="grid gap-4 sm:grid-cols-2">
        <div className="rounded-2xl bg-[var(--yellow)] p-5">
          <Trophy aria-hidden className="text-[var(--ink)]" size={20} />
          <p className="eyebrow mt-3 !text-[var(--ink)]/60">Threshold met</p>
          <p className="mt-1.5 text-lg font-extrabold">Winner gets the NFT</p>
          <p className="mt-2 text-sm font-medium leading-5 text-[var(--ink)]/70">
            The sponsor claims the distributable pot after the 5% fee.
          </p>
        </div>
        <div className="rounded-2xl bg-[#3d8bfd] p-5 text-white">
          <Dices aria-hidden size={20} />
          <p className="eyebrow mt-3 !text-white/70">Threshold missed</p>
          <p className="mt-1.5 text-lg font-extrabold">Winner gets 80% cash</p>
          <p className="mt-2 text-sm font-medium leading-5 text-white/85">
            The sponsor reclaims the NFT plus 20% of the distributable pot.
          </p>
        </div>
      </div>

      <div className="perforation my-6" />

      <div className="flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm font-extrabold">
          The ticket price is the total you pay
        </p>
        <p className="numeric text-xs font-bold text-[var(--ink-faint)]">
          One 5% protocol fee at resolution
        </p>
      </div>
    </div>
  );
}

function HowItWorks() {
  return (
    <section className="panel panel-yellow">
      <div className="page-shell relative py-14 md:py-16">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <p className="eyebrow !text-[var(--ink)]/55">Three steps</p>
            <h2 className="mt-2 text-3xl md:text-4xl">How a raffle works</h2>
          </div>
          <Link className="btn btn-ink" href="/docs">
            Read the mechanics <ArrowRight aria-hidden size={16} />
          </Link>
        </div>

        <ol className="mt-9 grid gap-4 md:grid-cols-3">
          {steps.map((step, index) => (
            <li
              className="rounded-3xl bg-white/70 p-6 backdrop-blur-sm"
              key={step.title}
            >
              <div className="flex items-center gap-3">
                <span className="grid size-10 place-items-center rounded-full bg-[var(--ink)] text-white">
                  <step.icon aria-hidden size={18} />
                </span>
                <span className="numeric text-sm font-extrabold text-[var(--ink)]/45">
                  0{index + 1}
                </span>
              </div>
              <h3 className="mt-4 text-xl">{step.title}</h3>
              <p className="mt-2 text-sm font-medium leading-6 text-[var(--ink)]/70">
                {step.text}
              </p>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
