#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh"
OUT="$ROOT/.build/species-preview"
"$ROOT/dist/ChirpOS.app/Contents/MacOS/Birding" --export-species "$OUT"
mkdir -p "$ROOT/Assets/Species"
cp "$OUT/species-lineup.png" "$OUT/species-actions.png" "$OUT/species-animations.gif" "$ROOT/Assets/Species/"
printf 'Frame previews: %s\n' "$OUT"
