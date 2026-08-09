# Embedded fonts

Latin-subset variable font files copied from the web application's own build output
(`apps/web/.next/static/media`), which `next/font` downloads from Google Fonts at
build time.

| File                     | Family                              | Style  | License                   |
| ------------------------ | ----------------------------------- | ------ | ------------------------- |
| `nunito-latin-var.woff2` | Nunito (variable, weights 200-1000) | normal | SIL Open Font License 1.1 |
| `inter-latin-var.woff2`  | Inter (variable, weights 100-900)   | normal | SIL Open Font License 1.1 |

Both families are published under the SIL Open Font License 1.1, which explicitly
permits bundling, embedding, and redistribution provided the fonts are not sold by
themselves. They are embedded in the generated whitepaper PDF and referenced by the
HTML print source. See https://openfontlicense.org for the license text.
