#!/bin/bash
# Rasterize the 21 numbered SVG figures to PNG for the DOCX build.
# Output: docs/whitepaper/build/diagrams-png/<name>.png at 2x scale.
set -euo pipefail
cd "$(dirname "$0")/.."
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUT="build/diagrams-png"
mkdir -p "$OUT"

for svg in assets/diagrams/[0-9][0-9]-*.svg; do
  name="$(basename "$svg" .svg)"
  # Read viewBox and compute an aspect-correct browser viewport at width 1500.
  read -r minx miny w h < <(node -e '
    const fs = require("node:fs");
    const match = fs.readFileSync(process.argv[1], "utf8").match(/viewBox="([-\d.]+) ([-\d.]+) ([\d.]+) ([\d.]+)"/);
    if (!match) process.exit(2);
    console.log(match.slice(1).join(" "));
  ' "$svg")
  W=1500
  H=$(node -e 'console.log(Math.round(Number(process.argv[1]) * Number(process.argv[2]) / Number(process.argv[3])))' "$W" "$h" "$w")
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --window-size="$W,$H" --screenshot="$OUT/$name.png" \
    "file://$PWD/$svg" 2>/dev/null
  echo "rendered $name.png"
done
