# Whitepaper status

The published technical whitepaper is
[`docs/whitepapers/raffle-fun-technical-whitepaper.md`](whitepapers/raffle-fun-technical-whitepaper.md),
regenerated against the current Ethereum/Chainlink ERC-1167 v1 source. Its claim-level
provenance lives in [`docs/facts/raffle-fun-facts.md`](facts/raffle-fun-facts.md), and
all three public documents are rendered to A4 PDFs by `pnpm docs:pdf`, which stamps the
registry commit onto every cover.

The public documents are:

| Document                                                                          | Audience                                      | Output                                    |
| --------------------------------------------------------------------------------- | --------------------------------------------- | ----------------------------------------- |
| [one-pager](one-pagers/raffle-fun.md)                                             | general orientation                           | `output/pdf/raffle-fun-one-pager.pdf`     |
| [plain-language article](articles/raffle-fun-explained.md)                        | readers who know NFTs but not Solidity        | `output/pdf/raffle-fun-explained.pdf`     |
| [technical whitepaper](whitepapers/raffle-fun-technical-whitepaper.md)            | auditors, protocol engineers, integrators     | `output/pdf/raffle-fun-technical-whitepaper.pdf` |

None of them is a release specification. Production Solidity is authoritative, and the
candidate is **not deployed and not independently audited**.

The normative engineering documents remain:

- [repository overview](../README.md);
- [architecture](ARCHITECTURE.md);
- [lifecycle](STATE-MACHINE.md);
- [economics](ECONOMICS.md);
- [Chainlink VRF](RANDOMNESS.md);
- [security invariants](SECURITY-INVARIANTS.md);
- [threat model](THREAT-MODEL.md);
- [deployment runbook](DEPLOYMENT.md).

## The retired generation

`docs/whitepaper/**` is a separate, **superseded** workspace: the source, build
pipeline, fact-check register, and pre-generated SVG figures for the older Base/Pyth,
full-deployment, Lens, per-ticket design. Its fact generator still requires symbols that
no longer exist in production Solidity, so `pnpm docs:whitepaper` cannot run — and it
should not. Nothing in that directory may be used for deployment, integration, audit, or
transaction decisions.

§16.2 of the current whitepaper tabulates exactly what that design retired, so a future
writer cannot reintroduce removed behavior from a historical audit report.

## Publication guard

`docs/pdf/build.mjs` refuses to publish while the fact registry or any of the three
public documents describes the retired protocol. Passages that must name retired
components — a "removed behaviour, do not restore" ledger — are fenced with
`<!-- retired-reference:start -->` / `<!-- retired-reference:end -->` comments and are
exempt; everything outside a fence is read as a claim about the current protocol.
