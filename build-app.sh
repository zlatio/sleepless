#!/bin/bash
# Builds a universal Sleepless.app, Sleepless.zip and Sleepless.alfredworkflow into the project root.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

APP="Sleepless.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN/Sleepless" "$APP/Contents/MacOS/Sleepless"
cp Icon/Assets.car Icon/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Sleepless</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>dev.playground.sleepless</string>
    <key>CFBundleName</key>
    <string>Sleepless</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2</string>
    <key>CFBundleVersion</key>
    <string>3</string>
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

# An Alfred workflow file is a zip of the workflow folder's contents.
ditto -c -k --norsrc Alfred Sleepless.alfredworkflow

echo "Built $APP, Sleepless.zip and Sleepless.alfredworkflow — run with: open $APP"
