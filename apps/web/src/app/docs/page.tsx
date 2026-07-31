import type { Metadata } from "next";
import { PageHeader } from "@/components/page-header";
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
    <>
      <PageHeader
        eyebrow="Mechanics & risks"
        lede="raffle.fun is a fixed-outcome protocol, not a promise about the value, authenticity, or legality of any prize. This is the complete mechanic in plain language."
        title={
          <>
            Read the rules <br />
            before you play.
          </>
        }
        tone="brand"
      />
      <div className="page-shell py-12 md:py-16">
        <nav
          className="card flex flex-wrap gap-1.5 p-2.5 text-[length:var(--text-sm)] font-medium"
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
              className="rounded-full px-3.5 py-2 text-[var(--ink-2)] transition-colors hover:bg-[var(--brand-pink-pale)] hover:text-[var(--pink-ink)]"
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
              text="Each purchase adds its full gross amount to the unsettled pot. Sales remain open until the fixed end time."
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
              className="bg-[var(--yellow-wash)]"
              label="total tickets ≥ minimum"
              title="Threshold met"
              items={[
                "Winning ticket holder claims the NFT",
                "Protocol receives 5% of aggregate gross sales",
                "Sponsor claims the remaining 95%",
              ]}
            />
            <Outcome
              className="bg-[var(--sky-wash)]"
              label="total tickets < minimum"
              title="Cash fallback"
              items={[
                "Winner claims 80% of the distributable pot",
                "Sponsor claims 20% and reclaims the NFT",
                "There are no ticket refunds",
              ]}
            />
          </div>
          <div className="card mt-5 p-6">
            <h3 className="text-2xl">If nobody buys a ticket</h3>
            <p className="mt-3 text-sm leading-6 text-[var(--ink-2)]">
              Anyone can close the raffle after its end without requesting
              randomness. The sponsor reclaims the NFT and no quote-token
              payouts are created. A sponsor may also cancel at any point while
              zero tickets have sold. Once ticket 1 is sold the prize is locked:
              it can only reach the winner or return to the sponsor through
              settlement.
            </p>
          </div>
        </section>

        <section className="mt-24 scroll-mt-8" id="economics">
          <DocHeading
            eyebrow="Exact economics"
            title="The ticket price is all you pay."
            text="One 5% fee is calculated from aggregate gross sales when the raffle resolves. It is deducted from the pot, never added at checkout. Every rounding remainder stays with the sponsor side of the cash split."
          />
          <div className="card mt-8 overflow-hidden">
            <div className="grid gap-1 bg-[var(--ink)] p-6 text-white sm:grid-cols-3">
              <Formula label="Gross pot" value="all ticket revenue" />
              <Formula label="Protocol" value="floor(gross pot × 5%)" />
              <Formula label="Distributable" value="gross pot − protocol" />
            </div>
            <div className="grid gap-6 p-6 lg:grid-cols-2">
              <Example
                rows={[
                  ["Gross sales", "120.00 USDC"],
                  ["Protocol fee", "6.00 USDC"],
                  ["Distributable pot", "114.00 USDC"],
                  ["Winner", "NFT"],
                  ["Sponsor", "114.00 USDC"],
                ]}
                title="Threshold met: 120 / 100"
              />
              <Example
                rows={[
                  ["Gross sales", "80.00 USDC"],
                  ["Protocol fee", "4.00 USDC"],
                  ["Distributable pot", "76.00 USDC"],
                  ["Winner", "60.80 USDC"],
                  ["Sponsor", "NFT + 15.20 USDC"],
                ]}
                title="Threshold missed: 80 / 100"
              />
            </div>
          </div>
          <p className="mt-5 rounded-2xl card p-5 text-sm leading-6">
            The fee is not allocated during individual purchases. Resolution
            calculates it once from the complete gross pot, then creates the
            treasury, winner, and sponsor pull claims.
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
          <p className="mt-5 text-sm leading-6 text-[var(--ink-2)]">
            Oracle delivery is not instantaneous. If a callback fails, Pyth
            retry or replay tooling must deliver the same sequence; the raffle
            cannot request a replacement result. This preserves uniqueness but
            creates an external liveness dependency.
          </p>
        </section>

        <section className="mt-24 scroll-mt-8" id="transfers">
          <DocHeading
            eyebrow="Ticket ownership"
            title="Transferable before and after the pending draw."
            text="Tickets move like normal ERC721s while a raffle is active. Transfers freeze only while randomness is pending, preventing ownership changes between request and winner snapshot. After resolution, tickets may move again as souvenirs."
          />
          <div className="card mt-8 grid gap-5 p-6 sm:grid-cols-3">
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
            <Fact
              title="No sales cap"
              text="Meeting the minimum does not close sales. Tickets remain available until the published end time, and the sponsor may earn above the target."
            />
          </div>
        </section>

        <section className="mt-24 scroll-mt-8" id="trust">
          <DocHeading
            eyebrow="Trust model"
            title="Know what code can—and cannot—protect."
            text="Existing raffle clones are non-upgradeable. Factory administration affects future creation and payment-token discovery labels—not an active raffle’s fixed economics."
          />
          <div className="mt-8 grid gap-5 lg:grid-cols-2">
            <div className="card p-7">
              <div className="flex items-center gap-3">
                <ShieldCheck aria-hidden className="text-[var(--grass)]" />
                <h3 className="text-2xl">Factory owner can</h3>
              </div>
              <ul className="mt-5 list-disc space-y-2 pl-5 text-sm leading-6 text-[var(--ink-2)]">
                <li>Change the treasury captured by newly created raffles</li>
                <li>
                  Verify or unverify payment tokens for official discovery
                </li>
                <li>Pause creation of new raffles</li>
                <li>Transfer two-step factory ownership</li>
              </ul>
            </div>
            <div className="card p-7">
              <div className="flex items-center gap-3">
                <LockKeyhole aria-hidden className="text-[var(--sky)]" />
                <h3 className="text-2xl">Factory owner cannot</h3>
              </div>
              <ul className="mt-5 list-disc space-y-2 pl-5 text-sm leading-6 text-[var(--ink-2)]">
                <li>Change existing economics, fees, timing, or threshold</li>
                <li>
                  Choose a winner, request another result, or upgrade a clone
                </li>
                <li>Seize the prize, settlement pot, or user claims</li>
                <li>Pause an existing raffle or its claims</li>
              </ul>
            </div>
          </div>
          <div className="mt-5 rounded-2xl bg-[var(--amber-wash)] p-6">
            <h3 className="flex items-center gap-2 text-xl font-extrabold text-[var(--amber-ink)]">
              <AlertTriangle aria-hidden /> Important risks
            </h3>
            <ul className="mt-4 list-disc space-y-2 pl-5 text-sm leading-6 text-[var(--amber-ink)]">
              <li>
                The protocol is unaudited. Tests and analysis are not an
                independent audit.
              </li>
              <li>
                Prize NFTs and metadata can be counterfeit, mutable, malicious,
                or worthless.
              </li>
              <li>
                Any contract-backed quote token can be selected. Unverified and
                verified tokens may still freeze, rebase, blacklist accounts, or
                prevent claims.
              </li>
              <li>
                Pyth Entropy availability and replay tooling are external
                liveness dependencies.
              </li>
              <li>
                The subgraph can lag or fail. Direct chain state is
                authoritative.
              </li>
              <li>
                Chance-based prize systems may require jurisdiction-specific
                legal review. This software does not provide regulatory
                compliance.
              </li>
            </ul>
          </div>
        </section>
      </div>
    </>
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
      <h2 className="mt-3 text-4xl md:text-5xl">{title}</h2>
      <p className="mt-5 text-base leading-7 text-[var(--ink-2)]">{text}</p>
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
    <div className="card h-full p-6">
      <div className="flex items-center justify-between">
        <span className="grid size-11 place-items-center rounded-xl bg-[var(--yellow-wash)]">
          {icon}
        </span>
        <span className="text-xs font-extrabold text-[var(--ink-2)]">
          {number}
        </span>
      </div>
      <h3 className="mt-5 text-2xl">{title}</h3>
      <p className="mt-2 text-sm leading-6 text-[var(--ink-2)]">{text}</p>
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
    <div className={`rounded-3xl p-7 ${className}`}>
      <p className="eyebrow">{label}</p>
      <h3 className="mt-2 text-3xl">{title}</h3>
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
      <p className="numeric mt-2 text-sm font-extrabold">{value}</p>
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
      <h3 className="text-2xl">{title}</h3>
      <dl className="mt-4 divide-y divide-[var(--line)] rounded-2xl border border-[var(--line)]">
        {rows.map(([label, value]) => (
          <div className="flex justify-between gap-4 p-3 text-sm" key={label}>
            <dt className="text-[var(--ink-2)]">{label}</dt>
            <dd className="numeric font-extrabold">{value}</dd>
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
    <div className="card p-6">
      <span className="grid size-11 place-items-center rounded-xl bg-[var(--sky-wash)]">
        {icon}
      </span>
      <h3 className="mt-5 text-2xl">{title}</h3>
      <p className="mt-2 text-sm leading-6 text-[var(--ink-2)]">{text}</p>
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
      <h3 className="font-extrabold">{title}</h3>
      <p className="mt-2 text-sm leading-6 text-[var(--ink-2)]">{text}</p>
    </div>
  );
}
