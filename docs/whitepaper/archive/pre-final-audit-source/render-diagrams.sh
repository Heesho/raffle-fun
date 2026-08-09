#!/bin/bash
# Rasterize every SVG diagram to PNG (for the DOCX build) using headless Chrome.
# Output: docs/whitepaper/build/diagrams-png/<name>.png at 2x scale.
set -euo pipefail
cd "$(dirname "$0")/.."
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUT="build/diagrams-png"
mkdir -p "$OUT"

for svg in assets/diagrams/*.svg; do
  name="$(basename "$svg" .svg)"
  # read viewBox to compute an aspect-correct window at width 1500
  read -r minx miny w h < <(python3 - "$svg" <<'EOF'
import re, sys
m = re.search(r'viewBox="([-\d.]+) ([-\d.]+) ([\d.]+) ([\d.]+)"', open(sys.argv[1]).read())
print(*m.groups())
EOF
)
  W=1500
  H=$(python3 -c "print(round($W * $h / $w))")
  cat > "$OUT/_wrap.html" <<HTML
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
@font-face { font-family: "Nunito"; font-weight: 200 1000; src: url("../../assets/fonts/nunito-latin-var.woff2") format("woff2"); }
@font-face { font-family: "Inter"; font-weight: 100 900; src: url("../../assets/fonts/inter-latin-var.woff2") format("woff2"); }
html,body { margin:0; background:#ffffff; }
svg { display:block; width:${W}px; height:${H}px; }
</style></head><body>
$(cat "$svg")
</body></html>
HTML
  "$CHROME" --headless=new --disable-gpu --force-device-scale-factor=2 \
    --window-size="$W,$H" --screenshot="$OUT/$name.png" \
    "file://$PWD/$OUT/_wrap.html" 2>/dev/null
  echo "rendered $name.png"
done
rm -f "$OUT/_wrap.html"
