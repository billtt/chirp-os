#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="${CHIRPOS_APP_PATH:-$ROOT/dist/ChirpOS.app}"
source "$ROOT/scripts/lib/macos-release-config.sh"
MODE=signed
CHECK=false
for arg in "$@"; do
    case "$arg" in
        --ad-hoc) MODE=adhoc ;;
        --check) CHECK=true ;;
        *) echo 'Usage: scripts/release-macos.sh [--check] [--ad-hoc]' >&2; exit 2 ;;
    esac
done
if [[ "$MODE" == signed ]]; then
    if ! load_macos_release_config || ! check_macos_release_credentials; then
        echo '请参考 scripts/macos-release.env.example 配置本机发布身份。' >&2
        echo 'Configure this machine using scripts/macos-release.env.example.' >&2
        if [[ "$CHECK" == true ]]; then exit 1; fi
        if [[ -t 0 && -z "${CI:-}" ]]; then
            printf '是否改用临时签名？该文件没有 Apple 公证，不适合公开分发。 [y/N]\nUse ad-hoc signing without notarization? [y/N] ' >&2
            read -r answer || answer=n
            case "$answer" in y|Y|yes|YES) MODE=adhoc ;; *) exit 1 ;; esac
        else
            echo '非交互运行已停止；如确需临时签名，请显式使用 --ad-hoc。' >&2
            echo 'Stopped without a prompt. Use --ad-hoc explicitly only for an ad-hoc test build.' >&2
            exit 1
        fi
    fi
fi
if [[ "$CHECK" == true ]]; then echo "Release preflight OK ($MODE)"; exit 0; fi
if [[ "$MODE" == adhoc ]]; then
    # Never silently downgrade after a signing or notarization error.
    export CHIRPOS_SIGNING_IDENTITY=''
    bash "$ROOT/scripts/build.sh"
    codesign --verify --deep --strict "$APP"
    VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
    mkdir -p "$ROOT/dist/adhoc"
    OUTPUT="$ROOT/dist/adhoc/ChirpOS-$VERSION-macOS-$(uname -m)-adhoc.zip"
    ditto -c -k --keepParent "$APP" "$OUTPUT"
    echo "Ad-hoc test package (not notarized): $OUTPUT"
else
    bash "$ROOT/scripts/build.sh"
    bash "$ROOT/scripts/notarize-macos.sh"
fi
