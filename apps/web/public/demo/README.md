# Demo prize images

Third-party NFT artwork used **only** by the local demo fixtures in
`src/lib/demo.ts`, so the interface can be designed against realistic prizes
before a network deployment exists.

| File               | Collection           | Token | Source                     |
| ------------------ | -------------------- | ----- | -------------------------- |
| `punk-3100.png`    | CryptoPunks          | 3100  | larvalabs.com              |
| `bayc-8817.png`    | Bored Ape Yacht Club | 8817  | IPFS (contract `tokenURI`) |
| `milady-1618.png`  | Milady Maker         | 1618  | miladymaker.net            |
| `azuki-9605.png`   | Azuki                | 9605  | IPFS (contract `tokenURI`) |
| `pudgy-6873.png`   | Pudgy Penguins       | 6873  | IPFS (contract `tokenURI`) |
| `doodles-6914.png` | Doodles              | 6914  | IPFS (contract `tokenURI`) |

These images are the property of their respective collections and creators.
They are not licensed for production use here. Remove this directory (and set
`NEXT_PUBLIC_DEMO_MODE=off`) before shipping a public deployment; real raffles
resolve prize media from each prize contract's own `tokenURI`.
