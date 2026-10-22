#!/bin/bash
# Generated scratch helper (S6 attempt-02): rasterize Graphviz SVG files to PNG with macOS `sips`.
# A scratch copy of each SVG gets its intrinsic width/height multiplied by SCALE (viewBox unchanged), so sips
# rasterizes the full drawing at SCALE x resolution. The original SVG is not modified.
# Usage: svg_to_png.sh <scale> <scratch-dir> <png-out-dir> <in1.svg> [in2.svg ...]
set -u
scale="$1"; tmp="$2"; outdir="$3"; shift 3
mkdir -p "$tmp" "$outdir"
rc=0
for svg in "$@"; do
  base=$(basename "$svg" .svg)
  scaled="$tmp/$base.x$scale.svg"
  /opt/homebrew/bin/python3.11 -I - "$svg" "$scaled" "$scale" <<'EOF'
import re, sys
src, dst, scale = sys.argv[1], sys.argv[2], float(sys.argv[3])
text = open(src, encoding="utf-8").read()
def bump(m):
    return f'{m.group(1)}="{float(m.group(2)) * scale:.2f}pt"'
head, sep, rest = text.partition("<svg")
tag_end = rest.index(">")
tag = re.sub(r'(width|height)="([0-9.]+)pt"', bump, rest[:tag_end], count=2)
open(dst, "w", encoding="utf-8").write(head + sep + tag + rest[tag_end:])
EOF
  if sips -s format png "$scaled" --out "$outdir/$base.png" >/dev/null; then
    dims=$(sips -g pixelWidth -g pixelHeight "$outdir/$base.png" | awk '/pixel/ {printf "%s=%s ", $1, $2}')
    echo "OK $svg -> $outdir/$base.png ($dims)"
  else
    echo "FAIL $svg"; rc=1
  fi
done
exit $rc
