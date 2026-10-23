#!/bin/bash
# Compiles AppIcon.icon into Assets.car and AppIcon.icns next to this script.
# Needs Xcode 26 or later. build-app.sh only copies the two outputs, so it does not need Xcode.
set -euo pipefail
cd "$(dirname "$0")"

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# Absolute paths: actool hands work to a long-lived agent that resolves relative paths in its own directory.
# It also exits 0 when it compiles nothing, so the cp below is what fails the script on an error.
xcrun actool "$PWD/AppIcon.icon" \
    --compile "$OUT" \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --app-icon AppIcon \
    --standalone-icon-behavior all \
    --output-partial-info-plist "$OUT/partial.plist" \
    --errors \
    --warnings \
    --output-format human-readable-text

cp "$OUT/Assets.car" "$OUT/AppIcon.icns" .

echo "Wrote Icon/Assets.car and Icon/AppIcon.icns"
