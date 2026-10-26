#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release
APP="${CHIRPOS_APP_PATH:-$ROOT/dist/ChirpOS.app}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ROOT/Assets"
cp .build/release/Birding "$APP/Contents/MacOS/Birding.new"
mv -f "$APP/Contents/MacOS/Birding.new" "$APP/Contents/MacOS/Birding"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Birding</string>
<key>CFBundleIdentifier</key><string>dev.birding.desktop</string>
<key>CFBundleName</key><string>ChirpOS</string>
<key>CFBundleDisplayName</key><string>ChirpOS</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string><string>zh-Hant</string></array>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.7.1</string>
<key>CFBundleVersion</key><string>71</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
"$ROOT/.build/release/Birding" --export-icon "$ROOT/Assets"
"$ROOT/.build/release/Birding" --export-icon "$ROOT/.build/AppIcon-macOS" --macos-mask
rm -rf "$APP/Contents/Resources/Birding_BirdingCore.bundle"
cp -R "$ROOT/.build/release/Birding_BirdingCore.bundle" "$APP/Contents/Resources/"
rm -f "$APP/Contents/Resources/stand.png" # Remove the unused legacy export from incremental builds.
ICONSET="$ROOT/.build/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ROOT/.build/AppIcon-macOS/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$ROOT/.build/AppIcon-macOS/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$ROOT/.build/AppIcon.icns"
# A content-specific resource name avoids reusing Finder's stale icon cache.
ICON_HASH="$(shasum -a 256 "$ROOT/.build/AppIcon.icns" | cut -c 1-12)"
ICON_NAME="AppIcon-$ICON_HASH"
rm -f "$APP/Contents/Resources/AppIcon.icns" "$APP/Contents/Resources/"AppIcon-*.icns
cp "$ROOT/.build/AppIcon.icns" "$APP/Contents/Resources/$ICON_NAME.icns"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile $ICON_NAME" "$APP/Contents/Info.plist"
for language in en zh-Hans zh-Hant; do
    mkdir -p "$APP/Contents/Resources/$language.lproj"
    name="ChirpOS"
    if [[ "$language" != en ]]; then name="啾啾"; fi
    printf '"CFBundleName" = "%s";\n"CFBundleDisplayName" = "%s";\n' "$name" "$name" > "$APP/Contents/Resources/$language.lproj/InfoPlist.strings"
done
if [[ -n "${CHIRPOS_SIGNING_IDENTITY:-}" ]]; then
    codesign --force --sign "$CHIRPOS_SIGNING_IDENTITY" --options runtime --timestamp "$APP"
else
    codesign --force --sign - "$APP"
fi
touch "$APP"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then "$LSREGISTER" -f "$APP" || true; fi
printf 'Built: %s\n' "$APP"
