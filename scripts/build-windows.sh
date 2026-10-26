#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
DOTNET="${CHIRPOS_DOTNET:-dotnet}"
if [[ -x "$ROOT/.build/tools/dotnet/dotnet" ]]; then DOTNET="$ROOT/.build/tools/dotnet/dotnet"; fi
MAKENSIS="${CHIRPOS_MAKENSIS:-makensis}"
command -v "$MAKENSIS" >/dev/null || { echo 'Install NSIS (macOS: brew install makensis; Linux: install nsis), or set CHIRPOS_MAKENSIS.' >&2; exit 1; }
PACKAGE_DIR="${CHIRPOS_PACKAGE_DIR:-$ROOT/dist/releases}"
mkdir -p "$PACKAGE_DIR"
PACKAGE_DIR="$(cd "$PACKAGE_DIR" && pwd)"
if command -v pwsh >/dev/null; then pwsh -NoProfile -File scripts/test-windows-installer.ps1; fi
if [[ ! -f shared/art/manifest.json || ! -f shared/AppIcon.ico ]]; then echo 'Missing shared assets; run scripts/export-shared.sh on macOS first.' >&2; exit 1; fi
"$DOTNET" run --project platforms/windows/ChirpOS.Tests -c Release -p:UseSharedCompilation=false
VERSION=$(sed -n 's/.*<Version>\([^<]*\)<\/Version>.*/\1/p' platforms/windows/ChirpOS/ChirpOS.csproj)
for rid in "${@:-win-arm64}"; do
    case "$rid" in win-arm64|win-x64) ;; *) echo "Unsupported target: $rid" >&2; exit 1;; esac
    OUT="$ROOT/dist/windows/$rid"
    "$DOTNET" publish platforms/windows/ChirpOS/ChirpOS.csproj -c Release -r "$rid" --self-contained false -p:UseSharedCompilation=false --disable-build-servers -o "$OUT"
    cp LICENSE "$OUT/LICENSE.txt"
    cp platforms/windows/Verify-Windows.cmd "$OUT/Verify-Windows.cmd"
    cp platforms/windows/README.md "$OUT/README.md"
    SETUP="$PACKAGE_DIR/ChirpOS-$VERSION-$rid-setup.exe"
    "$MAKENSIS" -V2 "-DVERSION=$VERSION" "-DRID=$rid" "-DREPO_ROOT=$ROOT" "-DPAYLOAD_DIR=$OUT" "-DOUTPUT_FILE=$SETUP" "$ROOT/platforms/windows/installer/ChirpOS.nsi"
    ARCHIVE="$PACKAGE_DIR/ChirpOS-$VERSION-$rid-framework-dependent.zip"
    rm -f "$ARCHIVE"
    (cd "$OUT" && zip -9 "$ARCHIVE" ChirpOS.exe LICENSE.txt README.md Verify-Windows.cmd)
    if [[ -n "${CHIRPOS_SHARE_DIR:-}" ]]; then
        SHARE="$CHIRPOS_SHARE_DIR"
        mkdir -p "$SHARE"
        cp "$SETUP" "$SHARE/"
    fi
    printf 'Installer: %s\n' "$SETUP"
done
