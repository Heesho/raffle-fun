import type { Metadata } from "next";
import {
  AlertTriangle,
  ArrowDown,
  CircleDollarSign,
  Dices,
  Gift,
  LockKeyhole,
  ShieldCheck,
  Ticket,
} from "lucide-react";

export const metadata: Metadata = {
  title: "Mechanics and risks",
  description:
    "A plain-language guide to raffles economics, randomness, claims, admin powers, and risks.",
};

export default function DocsPage() {
  return (
    <div className="page-shell py-14 md:py-20">
      <div className="max-w-4xl">
        <p className="eyebrow">Mechanics & risks</p>
        <h1 className="mt-3 text-5xl font-bold leading-[0.96] md:text-8xl">
          Read the rules <br />
          before you play.
        </h1>
        <p className="mt-6 max-w-2xl text-lg leading-8 text-[#56506a]">
          raffles is a fixed-outcome protocol, not a promise about the value,
          authenticity, or legality of any prize. This is the complete mechanic
          in plain language.
        </p>
      </div>

      <nav
        className="ticket-card mt-10 flex flex-wrap gap-2 p-4 text-sm font-bold"
        aria-label="Documentation sections"
      >
        {[
          ["#mechanic", "Mechanic"],
          ["#economics", "Economics"],
          ["#randomness", "Randomness"],
          ["#transfers", "Tickets"],
          ["#trust", "Trust & risks"],
        ].map(([href, label]) => (
          <a
            className="rounded-full px-4 py-2 hover:bg-[#ffdc55]"
            href={href}
            key={href}
          >
            {label}
          </a>
        ))}
      </nav>

      <section className="mt-20 scroll-mt-8" id="mechanic">
        <DocHeading
          eyebrow="The mechanic"
          title="One prize. Equal tickets. One immutable threshold."
          text="A sponsor deposits exactly one ERC721. Every purchased ticket is a unique ERC721 with the same chance of winning. The sale starts inclusively and ends exclusively."
        />
        <div className="mt-8 grid gap-4 md:grid-cols-[1fr_auto_1fr_auto_1fr] md:items-center">
          <Step
            icon={<Gift />}
            number="1"
            title="Prize escrowed"
            text="The factory creates a non-upgradeable raffle clone and deposits the exact NFT."
          />
          <ArrowDown className="mx-auto md:-rotate-90" aria-hidden />
          <Step
            icon={<Ticket />}
            number="2"
            title="Tickets sold"
            text="Gross price is pulled once. Fees and net contribution are accounted exactly."
          />
          <ArrowDown className="mx-auto md:-rotate-90" aria-hidden />
          <Step
            icon={<Dices />}
            number="3"
            title="One random draw"
            text="After close, Pyth Entropy chooses ticket 1 through the last ticket inclusively."
          />
        </div>
        <div className="mt-5 grid gap-5 md:grid-cols-2">
          <Outcome
            className="bg-[#ffdc55]"
            label="total tickets ≥ minimum"
            title="Threshold met"
            items={[
              "Winning ticket holder claims the NFT",
              "Sponsor claims the full net pot",
              "Protocol and provider fees remain claimable",
            ]}
          />
          <Outcome
            className="bg-[#7fc8ff]"
            label="total tickets < minimum"
            title="Cash fallback"
            items={[
              "Winner claims 80% of the net pot",
              "Sponsor claims 20% and reclaims the NFT",
              "There are no ticket refunds",
            ]}
          />
        </div>
        <div className="ticket-card mt-5 p-6">
          <h3 className="text-2xl font-bold">If nobody buys a ticket</h3>
          <p className="mt-3 text-sm leading-6 text-[#56506a]">
            Anyone can close the raffle after its end without requesting
            randomness. The sponsor reclaims the NFT and no quote-token payouts
            are created. A sponsor may also cancel before any sale; cancellation
            becomes impossible after ticket 1 is sold.
          </p>
        </div>
      </section>

      <section className="mt-24 scroll-mt-8" id="economics">
        <DocHeading
          eyebrow="Exact economics"
          title="The ticket price is all you pay."
          text="Fees are deducted from the advertised gross amount, never added at checkout. Integer rounding always follows the contract and every remainder stays with the sponsor side of the cash split."
        />
        <div className="ticket-card mt-8 overflow-hidden">
          <div className="grid gap-1 bg-[#1726a3] p-6 text-white sm:grid-cols-4">
            <Formula label="Gross" value="price × quantity" />
            <Formula label="Protocol" value="floor(gross × 5%)" />
            <Formula label="Provider" value="floor(gross × 5%)" />
            <Formula label="Net" value="gross − both fees" />
          </div>
          <div className="grid gap-6 p-6 lg:grid-cols-2">
            <Example
              rows={[
                ["Gross sales", "120.00 USDC"],
                ["Protocol fee", "6.00 USDC"],
                ["Provider fee", "6.00 USDC"],
                ["Net pot", "108.00 USDC"],
                ["Winner", "NFT"],
                ["Sponsor", "108.00 USDC"],
              ]}
              title="Threshold met: 120 / 100"
            />
            <Example
              rows={[
                ["Gross sales", "80.00 USDC"],
                ["Protocol fee", "4.00 USDC"],
                ["Provider fee", "4.00 USDC"],
                ["Net pot", "72.00 USDC"],
                ["Winner", "57.60 USDC"],
                ["Sponsor", "NFT + 14.40 USDC"],
              ]}
              title="Threshold missed: 80 / 100"
            />
          </div>
        </div>
        <p className="mt-5 rounded-2xl border border-black/15 bg-white/55 p-5 text-sm leading-6">
          <strong>No provider?</strong> Only the 5% protocol fee applies, so 95%
          of each gross purchase enters the net pot. A nonzero provider must be
          currently allowlisted by the factory; an invalid referral is rejected
          rather than silently replaced.
        </p>
      </section>

      <section className="mt-24 scroll-mt-8" id="randomness">
        <DocHeading
          eyebrow="Randomness & claims"
          title="The callback decides; it never sends assets."
          text="A raffle permits exactly one Entropy v2 request. Resolution stores the winning ticket, snapshots its current owner, allocates claims, and stops. Every NFT, quote-token, and excess-native transfer happens later through a pull claim."
        />
        <div className="mt-8 grid gap-5 md:grid-cols-3">
          <RiskCard
            icon={<Dices />}
            title="Verifiable draw"
            text="Pyth Entropy combines committed randomness and delivers the requested sequence to the same raffle clone."
          />
          <RiskCard
            icon={<LockKeyhole />}
            title="Winner snapshotted"
            text="Moving the winning ticket after resolution cannot redirect the prize or cash payout."
          />
          <RiskCard
            icon={<CircleDollarSign />}
            title="Pull-based claims"
            text="Recipients choose a nonzero destination at claim time. A failed transfer rolls back and can be retried."
          />
        </div>
        <p className="mt-5 text-sm leading-6 text-[#56506a]">
          Oracle delivery is not instantaneous. If a callback fails, Pyth retry
          or replay tooling must deliver the same sequence; the raffle cannot
          request a replacement result. This preserves uniqueness but creates an
          external liveness dependency.
        </p>
      </section>

      <section className="mt-24 scroll-mt-8" id="transfers">
        <DocHeading
          eyebrow="Ticket ownership"
          title="Transferable before and after the pending draw."
          text="Tickets move like normal ERC721s while a raffle is active. Transfers freeze only while randomness is pending, preventing ownership changes between request and winner snapshot. After resolution, tickets may move again as souvenirs."
        />
        <div className="ticket-card mt-8 grid gap-5 p-6 sm:grid-cols-3">
          <Fact
            title="Odds"
            text="Your balance ÷ all sold tickets. Every ticket ID from 1 through totalTickets is eligible."
          />
          <Fact
            title="One-ticket case"
            text="Ticket #1 wins. There is no zero modulo and no off-by-one exclusion."
          />
          <Fact
            title="High threshold"
            text="It cannot make the raffle insolvent. It only changes which settlement branch is more likely."
          />
        </div>
      </section>

      <section className="mt-24 scroll-mt-8" id="trust">
        <DocHeading
          eyebrow="Trust model"
          title="Know what code can—and cannot—protect."
          text="Existing raffle clones are non-upgradeable. Factory administration affects future creation, payment-token discovery labels, and provider configuration—not an active raffle’s fixed economics."
        />
        <div className="mt-8 grid gap-5 lg:grid-cols-2">
          <div className="ticket-card p-7">
            <div className="flex items-center gap-3">
              <ShieldCheck aria-hidden className="text-emerald-700" />
              <h3 className="text-2xl font-bold">Factory owner can</h3>
            </div>
            <ul className="mt-5 list-disc space-y-2 pl-5 text-sm leading-6 text-[#56506a]">
              <li>Change the treasury captured by newly created raffles</li>
              <li>Verify or unverify payment tokens for official discovery</li>
              <li>Allow or remove providers</li>
              <li>Pause creation of new raffles</li>
              <li>Transfer two-step factory ownership</li>
            </ul>
          </div>
          <div className="ticket-card p-7">
            <div className="flex items-center gap-3">
              <LockKeyhole aria-hidden className="text-violet-700" />
              <h3 className="text-2xl font-bold">Factory owner cannot</h3>
            </div>
            <ul className="mt-5 list-disc space-y-2 pl-5 text-sm leading-6 text-[#56506a]">
              <li>Change existing economics, fees, timing, or threshold</li>
              <li>
                Choose a winner, request another result, or upgrade a clone
              </li>
              <li>Seize the prize, net pot, provider fees, or user claims</li>
              <li>Pause an existing raffle or its claims</li>
            </ul>
          </div>
        </div>
        <div className="mt-5 rounded-2xl border border-amber-900/20 bg-amber-100 p-6">
          <h3 className="flex items-center gap-2 text-xl font-black text-amber-950">
            <AlertTriangle aria-hidden /> Important risks
          </h3>
          <ul className="mt-4 list-disc space-y-2 pl-5 text-sm leading-6 text-amber-950/80">
            <li>
              The protocol is unaudited. Tests and analysis are not an
              independent audit.
            </li>
            <li>
              Prize NFTs and metadata can be counterfeit, mutable, malicious, or
              worthless.
            </li>
            <li>
              Any contract-backed quote token can be selected. Unverified and
              verified tokens may still freeze, rebase, blacklist accounts, or
              prevent claims.
            </li>
            <li>
              Pyth Entropy availability and replay tooling are external liveness
              dependencies.
            </li>
            <li>
              The subgraph can lag or fail. Direct chain state is authoritative.
            </li>
            <li>
              Chance-based prize systems may require jurisdiction-specific legal
              review. This software does not provide regulatory compliance.
            </li>
          </ul>
        </div>
      </section>
    </div>
  );
}

function DocHeading({
  eyebrow,
  title,
  text,
}: {
  readonly eyebrow: string;
  readonly title: string;
  readonly text: string;
}) {
  return (
    <div className="max-w-3xl">
      <p className="eyebrow">{eyebrow}</p>
      <h2 className="mt-3 text-4xl font-bold md:text-6xl">{title}</h2>
      <p className="mt-5 text-base leading-7 text-[#56506a]">{text}</p>
    </div>
  );
}

function Step({
  icon,
  number,
  title,
  text,
}: {
  readonly icon: React.ReactNode;
  readonly number: string;
  readonly title: string;
  readonly text: string;
}) {
  return (
    <div className="ticket-card h-full p-6">
      <div className="flex items-center justify-between">
        <span className="grid size-11 place-items-center rounded-xl bg-[#ffdc55]">
          {icon}
        </span>
        <span className="text-xs font-black text-[#56506a]">{number}</span>
      </div>
      <h3 className="mt-5 text-2xl font-bold">{title}</h3>
      <p className="mt-2 text-sm leading-6 text-[#56506a]">{text}</p>
    </div>
  );
}

function Outcome({
  className,
  label,
  title,
  items,
}: {
  readonly className: string;
  readonly label: string;
  readonly title: string;
  readonly items: readonly string[];
}) {
  return (
    <div className={`rounded-2xl border border-black p-7 ${className}`}>
      <p className="eyebrow">{label}</p>
      <h3 className="mt-2 text-3xl font-bold">{title}</h3>
      <ul className="mt-5 list-disc space-y-2 pl-5 text-sm leading-6">
        {items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </div>
  );
}

function Formula({
  label,
  value,
}: {
  readonly label: string;
  readonly value: string;
}) {
  return (
    <div className="border-white/10 p-3 sm:border-r last:border-r-0">
      <p className="text-xs font-bold text-white/45">{label}</p>
      <p className="numeric mt-2 text-sm font-black">{value}</p>
    </div>
  );
}

function Example({
  title,
  rows,
}: {
  readonly title: string;
  readonly rows: readonly (readonly [string, string])[];
}) {
  return (
    <div>
      <h3 className="text-2xl font-bold">{title}</h3>
      <dl className="mt-4 divide-y divide-black/10 rounded-xl border border-black/10">
        {rows.map(([label, value]) => (
          <div className="flex justify-between gap-4 p-3 text-sm" key={label}>
            <dt className="text-[#56506a]">{label}</dt>
            <dd className="numeric font-black">{value}</dd>
          </div>
        ))}
      </dl>
    </div>
  );
}

function RiskCard({
  icon,
  title,
  text,
}: {
  readonly icon: React.ReactNode;
  readonly title: string;
  readonly text: string;
}) {
  return (
    <div className="ticket-card p-6">
      <span className="grid size-11 place-items-center rounded-xl bg-[#7fc8ff]">
        {icon}
      </span>
      <h3 className="mt-5 text-2xl font-bold">{title}</h3>
      <p className="mt-2 text-sm leading-6 text-[#56506a]">{text}</p>
    </div>
  );
}

function Fact({
  title,
  text,
}: {
  readonly title: string;
  readonly text: string;
}) {
  return (
    <div>
      <h3 className="font-black">{title}</h3>
      <p className="mt-2 text-sm leading-6 text-[#56506a]">{text}</p>
    </div>
  );
}
