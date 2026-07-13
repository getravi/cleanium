#!/bin/bash
# Notarize and staple Cleanium.app, then produce a distributable zip.
#
# One-time prerequisites (yours to do — see docs/NOTARIZING.md):
#   1. Apple Developer Program membership ($99/yr).
#   2. A "Developer ID Application" certificate in your login keychain.
#   3. A stored notarytool credential profile:
#        xcrun notarytool store-credentials cleanium-notary \
#          --apple-id "you@example.com" --team-id "TEAMID" \
#          --password "app-specific-password"
#
# Usage:
#   CLEANIUM_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#     ./scripts/notarize.sh
# Optional: NOTARY_PROFILE (default: cleanium-notary)
set -euo pipefail
cd "$(dirname "$0")/.."

: "${CLEANIUM_SIGN_IDENTITY:?Set CLEANIUM_SIGN_IDENTITY to your Developer ID Application identity}"
PROFILE="${NOTARY_PROFILE:-cleanium-notary}"
APP=dist/Cleanium.app
ZIP=dist/Cleanium.zip

# 1. Build + sign with hardened runtime (bundle.sh honors CLEANIUM_SIGN_IDENTITY).
./scripts/bundle.sh

# 2. Verify the signature is Developer-ID + hardened runtime before wasting a submission.
codesign --verify --strict --verbose=2 "$APP"
codesign -dvv "$APP" 2>&1 | grep -q "flags=.*runtime" \
  || { echo "error: hardened runtime not set on $APP"; exit 1; }

# 3. Notarization needs a zip (or dmg) to upload; --wait blocks until Apple responds.
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Submitting to Apple notary service (this takes a few minutes)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

# 4. Staple the ticket onto the .app so it validates offline, then re-zip the
#    stapled app (a bare zip can't be stapled — the ticket lives in the .app).
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# 5. Confirm Gatekeeper accepts it as if freshly downloaded.
spctl --assess --type execute --verbose=4 "$APP"

echo "Notarized + stapled: $APP  ->  $ZIP"
