#!/bin/bash
# Builds a universal Sleepless.app and Sleepless.zip into the project root.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

APP="Sleepless.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp "$BIN/Sleepless" "$APP/Contents/MacOS/Sleepless"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Sleepless</string>
    <key>CFBundleIdentifier</key>
    <string>dev.playground.sleepless</string>
    <key>CFBundleName</key>
    <string>Sleepless</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"

# --norsrc leaves out ._ xattr entries, which break the signature when the zip is extracted with unzip.
ditto -c -k --norsrc --keepParent "$APP" Sleepless.zip

echo "Built $APP and Sleepless.zip — run with: open $APP"
