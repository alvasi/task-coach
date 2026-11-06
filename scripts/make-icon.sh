#!/usr/bin/env bash
# Regenerates Resources/AppIcon.icns from the AppIconArt SwiftUI view.
# Only needed when the icon design changes; the .icns is checked in.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build
mkdir -p Resources
WORK="$(mktemp -d)"
SET="$WORK/AppIcon.iconset"
mkdir -p "$SET"

.build/debug/TaskCoach --icon "$WORK/icon-1024.png"

for size in 16 32 128 256 512; do
  sips -z $size $size "$WORK/icon-1024.png" --out "$SET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double "$WORK/icon-1024.png" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$SET" -o Resources/AppIcon.icns
cp "$WORK/icon-1024.png" Resources/icon-1024.png
rm -rf "$WORK"
echo "Wrote Resources/AppIcon.icns"
