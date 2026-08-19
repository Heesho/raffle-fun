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
    "A plain-language guide to raffle economics, randomness, settlement, admin powers, and risks.",
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
            ["#transfers", "Entries & tickets"],
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
            title="One prize. Equal $1 entries. One immutable reserve."
            text="A sponsor deposits exactly one ERC721. Sales begin immediately, every entry has the same chance, and each purchase mints one ERC721 ticket containing an inclusive range of entry numbers."
          />
          <div className="mt-8 grid gap-4 md:grid-cols-[1fr_auto_1fr_auto_1fr] md:items-center">
            <Step
              icon={<Gift />}
              number="1"
              title="Prize escrowed"
              text="The factory deploys and initializes a fixed-implementation minimal clone, then deposits the exact NFT atomically."
            />
            <ArrowDown className="mx-auto md:-rotate-90" aria-hidden />
            <Step
              icon={<Ticket />}
              number="2"
              title="$1 entries sold"
              text="Any positive entry count is bought in one O(1) purchase. The ticket gets the next sequential ID and its range is stored separately; sales remain open until the fixed end time."
            />
            <ArrowDown className="mx-auto md:-rotate-90" aria-hidden />
            <Step
              icon={<Dices />}
              number="3"
              title="One random draw"
              text="After close, Chainlink VRF chooses one entry from 1 through totalEntries inclusively."
            />
          </div>
          <div className="mt-5 grid gap-5 md:grid-cols-2">
            <Outcome
              className="bg-[var(--yellow-wash)]"
              label="totalEntries ≥ reserveEntries"
              title="Reserve met"
              items={[
                "Settlement records the NFT for the current winning ticket owner",
                "Settlement records 5% of gross sales for the protocol",
                "Settlement records the remaining 95% for the sponsor’s fixed recipient",
              ]}
            />
            <Outcome
              className="bg-[var(--sky-wash)]"
              label="totalEntries < reserveEntries"
              title="Cash fallback"
              items={[
                "Settlement records 80% of gross sales for the winning ticket owner",
                "Settlement records 5% for the protocol",
                "Settlement records 15% plus the NFT for the sponsor",
              ]}
            />
          </div>
          <div className="card mt-5 p-6">
            <h3 className="text-2xl">If nobody buys an entry</h3>
            <p className="mt-3 text-sm leading-6 text-[var(--ink-2)]">
              The sponsor can put an empty raffle into Refunding immediately;
              anyone can do so after its sale deadline. Refund liability is
              zero, and anyone can return the NFT to the sponsor’s fixed
              recipient.
            </p>
          </div>
          <div className="mt-5 rounded-2xl bg-[var(--amber-wash)] p-6">
            <h3 className="text-2xl text-[var(--amber-ink)]">
              If randomness is unavailable
            </h3>
            <p className="mt-3 text-sm leading-6 text-[var(--amber-ink)]">
              A sold raffle accepts a permissionless draw request from sale end
              until its request deadline two days later. If none succeeds before
              that hard cutoff, anyone can open full refunds. An accepted
              request gets a fresh two-day callback window; callbacks resolve
              only before its callback deadline, and refunds open at that
              deadline. No sponsor proceeds or protocol fee is earned. Current
              owners burn up to 100 tickets per call and receive $1 USDC for
              every entry in each stored range; anyone can return the NFT to the
              sponsor’s fixed recipient. Any valid earlier callback is final and
              has no later refund timeout.
            </p>
          </div>
        </section>

        <section className="mt-24 scroll-mt-8" id="economics">
          <DocHeading
            eyebrow="Exact economics"
            title="Every entry is exactly $1 USDC."
            text="One 5% fee is deducted from aggregate gross sales, never added at checkout. Settlement records the winner, sponsor, and protocol claims without moving an asset; the winning ticket's owner later burns it to redeem atomically."
          />
          <div className="card mt-8 overflow-hidden">
            <div className="grid gap-1 bg-[var(--ink)] p-6 text-white sm:grid-cols-3">
              <Formula label="Gross pot" value="$1 × totalEntries" />
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
                title="Reserve met: 120 / 100"
              />
              <Example
                rows={[
                  ["Gross sales", "80.00 USDC"],
                  ["Protocol fee", "4.00 USDC"],
                  ["Distributable pot", "76.00 USDC"],
                  ["Winner", "64.00 USDC"],
                  ["Sponsor", "NFT + 12.00 USDC"],
                ]}
                title="Reserve missed: 80 / 100"
              />
            </div>
          </div>
          <p className="mt-5 rounded-2xl card p-5 text-sm leading-6">
            Purchases never allocate fees, and a VRF result records only the
            outcome and winning entry. Settling the winning ticket allocates the
            winner, sponsor, and protocol balances without paying or delivering
            an asset. The current ticket owner burns it while receiving the
            winner’s cash or NFT in one transaction.
          </p>
        </section>

        <section className="mt-24 scroll-mt-8" id="randomness">
          <DocHeading
            eyebrow="Randomness & settlement"
            title="The callback decides; it never sends assets."
            text="A raffle permits exactly one Chainlink VRF v2.5 request with 30 confirmations. Resolution stores only the winning entry and result, then stops. The callback never searches tickets or transfers assets."
          />
          <div className="mt-8 grid gap-5 md:grid-cols-3">
            <RiskCard
              icon={<Dices />}
              title="Verifiable draw"
              text="Chainlink VRF delivers proof-backed randomness to the same independent raffle through the authenticated direct-funding wrapper."
            />
            <RiskCard
              icon={<LockKeyhole />}
              title="Ticket proof"
              text="The caller supplies a ticket ID. Its separately stored first and last entries prove in O(1) whether it contains the winning entry."
            />
            <RiskCard
              icon={<CircleDollarSign />}
              title="Bearer redemption"
              text="Anyone may settle the result, but only the winning ticket's current owner can burn it and redeem. Sponsor and treasury releases still use their fixed addresses."
            />
          </div>
          <p className="mt-5 text-sm leading-6 text-[var(--ink-2)]">
            Oracle delivery is not instantaneous and no replacement request is
            allowed. Draw requests must be included before the two-day request
            cutoff. A request at the last valid second starts a fresh two-day
            callback window, so the maximum nominal wait is almost four days
            after sale end. Matching callbacks resolve only before their
            callback deadline; at the deadline they are ignored and refunds are
            available, even if nobody has opened refunds yet. Only
            wrapper-authenticated, ABI-decodable calls reach that ignore logic.
            Anyone may settle the winning ticket without fixing its owner. The
            ticket remains transferable afterward; whoever owns it when it is
            redeemed burns it and receives the prize atomically.
          </p>
        </section>

        <section className="mt-24 scroll-mt-8" id="transfers">
          <DocHeading
            eyebrow="Entries & ticket ownership"
            title="Ranges keep large purchases simple."
            text="A ticket can represent one entry or an enormous contiguous range. It remains transferable in every raffle state, including after settlement, until successful winner redemption or a refund burns it."
          />
          <div className="card mt-8 grid gap-5 p-6 sm:grid-cols-3">
            <Fact
              title="Odds"
              text="Your entries ÷ totalEntries. Every entry from 1 through totalEntries is eligible, without minting or iterating once per entry."
            />
            <Fact
              title="One-entry case"
              text="Entry #1 wins. There is no zero modulo and no off-by-one exclusion."
            />
            <Fact
              title="High reserve"
              text="It cannot make the raffle insolvent. It only changes which settlement branch is more likely."
            />
            <Fact
              title="No sales cap"
              text="Meeting the reserve does not close sales. Entries remain available until the published end time. The only technical total is uint128, not a meaningful product cap."
            />
          </div>
        </section>

        <section className="mt-24 scroll-mt-8" id="trust">
          <DocHeading
            eyebrow="Trust model"
            title="Know what code can—and cannot—protect."
            text="Existing raffles are non-upgradeable ERC-1167 clones. The factory owner can only pause or resume future creation; the treasury and protocol dependencies are immutable."
          />
          <div className="mt-8 grid gap-5 lg:grid-cols-2">
            <div className="card p-7">
              <div className="flex items-center gap-3">
                <ShieldCheck aria-hidden className="text-[var(--grass)]" />
                <h3 className="text-2xl">Factory owner can</h3>
              </div>
              <ul className="mt-5 list-disc space-y-2 pl-5 text-sm leading-6 text-[var(--ink-2)]">
                <li>Pause creation of new raffles</li>
                <li>Resume creation of new raffles</li>
                <li>Transfer two-step factory ownership</li>
              </ul>
            </div>
            <div className="card p-7">
              <div className="flex items-center gap-3">
                <LockKeyhole aria-hidden className="text-[var(--sky)]" />
                <h3 className="text-2xl">Factory owner cannot</h3>
              </div>
              <ul className="mt-5 list-disc space-y-2 pl-5 text-sm leading-6 text-[var(--ink-2)]">
                <li>
                  Change any raffle’s reserve, fee, timing, or quote token
                </li>
                <li>
                  Change the factory treasury, implementation, or VRF wrapper
                </li>
                <li>
                  Choose a winner, request another result, or upgrade a raffle
                </li>
                <li>Seize the prize, settlement pot, or user balances</li>
                <li>Pause an existing raffle or its settlement</li>
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
                New raffles accept only factory-admitted exact-transfer tokens.
                Their issuers may still upgrade, pause, freeze, blacklist, or
                otherwise prevent later claims.
              </li>
              <li>
                Deadlines bound protocol liveness, but cannot overcome a halted
                chain, censorship of recovery calls, or lost keys. A
                reorganization or censorship that prevents a request or callback
                from being included before its hard cutoff can force refunds.
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
