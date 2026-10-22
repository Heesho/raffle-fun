# 🔐 Security Review — target

---

## Scope

|  |  |
| --- | --- |
| **Mode** | filename |
| **Files reviewed** | `target/packages/contracts/src/RaffleFactory.sol` · `target/packages/contracts/src/Raffle.sol` · `target/packages/contracts/src/libraries/RaffleConstants.sol`<br>`target/packages/contracts/src/interfaces/IRaffle.sol` · `target/packages/contracts/src/interfaces/IRaffleFactory.sol` |
| **Confidence threshold (1-100)** | 75 |

---

## Findings

_None — this scan raised no findings._

---

## Leads

_Vulnerability trails with concrete code smells where the full exploit path could not be completed in one analysis pass. These are not false positives — they are high-signal leads for manual review. Not scored._

- **The sponsor receives proceeds before prize delivery** — `Raffle.releaseSponsorProceeds` — Code smells: Sponsor payment precedes prize delivery; `NftWon` has no refund transition. — A sponsor can receive 95% before prize delivery; the supplied source does not prove a prize contract that later blocks delivery.

---

> ⚠️ This review was performed by an AI assistant. AI analysis can never verify the complete absence of vulnerabilities and no guarantee of security is given. Team security reviews, bug bounty programs, and on-chain monitoring are strongly recommended. For a consultation regarding your projects' security, visit [https://www.pashov.com](https://www.pashov.com)
