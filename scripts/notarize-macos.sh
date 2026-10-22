#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="${CHIRPOS_APP_PATH:-$ROOT/dist/ChirpOS.app}"
source "$ROOT/scripts/lib/macos-release-config.sh"
load_macos_release_config
: "${CHIRPOS_NOTARY_PROFILE:?Missing notarization profile; configure .local/macos-release.env}"
PROFILE="$CHIRPOS_NOTARY_PROFILE"
# Refuse ad-hoc or development signing before submitting a release.
SIGNATURE=$(codesign -dvv "$APP" 2>&1)
printf '%s\n' "$SIGNATURE" | grep '^Authority=Developer ID Application:' > /dev/null
codesign --verify --deep --strict --verbose=2 "$APP"
mkdir -p dist/releases
ditto -c -k --keepParent "$APP" dist/ChirpOS-notarization.zip
xcrun notarytool submit dist/ChirpOS-notarization.zip --keychain-profile "$PROFILE" --wait --output-format json > dist/notarization-result.json
plutil -extract status raw dist/notarization-result.json | grep -qx Accepted
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
ARCH=$(uname -m)
ditto -c -k --keepParent "$APP" "dist/releases/ChirpOS-$VERSION-macOS-$ARCH.zip"
