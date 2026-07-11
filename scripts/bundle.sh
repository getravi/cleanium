#!/bin/bash
# Builds Cleanium.app from the SPM release binary. No Xcode required.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=dist/Cleanium.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/Cleanium "$APP/Contents/MacOS/Cleanium"
# SwiftPM's generated Bundle.module accessor looks for the resource bundle at
# Bundle.main.bundleURL (the .app root), not next to the executable — verified
# empirically: placing it under Contents/MacOS or Contents/Resources makes
# Bundle.module fail to resolve and fatalError once .build/ isn't present.
cp -R .build/release/Cleanium_CleaniumCore.bundle "$APP/" 2>/dev/null \
  || cp -R .build/release/*.bundle "$APP/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Cleanium</string>
    <key>CFBundleIdentifier</key><string>com.cleanium.app</string>
    <key>CFBundleName</key><string>Cleanium</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

# codesign refuses to seal the loose SPM resource bundle sitting at the app
# root (it's not a "real" nested bundle) and exits 1 with "unsealed contents
# present in the bundle root" even though the executable is still signed and
# the app runs fine unnotarized/local-only. That warning is expected here;
# don't let it abort the script.
codesign --force --deep --sign - "$APP" || true
echo "Built $APP"
