#!/usr/bin/env bash
#
# Build the shippable FS25 mod zip.
# modDesc.xml MUST sit at the ROOT of the zip (FS25 requirement). We zip the
# individual mod files, never the containing folder. Tests/docs are dev-only and
# stay out of the shipped zip.
#
set -euo pipefail
cd "$(dirname "$0")"

OUT="FS25_SoundOverhaulRealism.zip"
rm -f "$OUT"

zip -r "$OUT" \
    modDesc.xml \
    scripts/ \
    sounds/ \
    icon_soundOverhaulRealism.png \
    LICENSE \
    -x "*/.*" "*/.gitkeep"

echo
echo "Built $OUT:"
unzip -l "$OUT"
