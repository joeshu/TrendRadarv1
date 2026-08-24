#!/usr/bin/env bash
set -euo pipefail

FONT_URL="https://developer.huawei.com/images/download/general/HarmonyOS-Sans.zip"
FONT_SHA256="fb02c86e358cd9aad8d4dfa957ee502381e7ee2e94499a9133add4324b6ce69a"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FONT_DIR="$IOS_DIR/TrendRadar/Resources/Fonts"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$FONT_DIR"
curl --fail --location --silent --show-error "$FONT_URL" -o "$TMP_DIR/HarmonyOS-Sans.zip"
echo "$FONT_SHA256  $TMP_DIR/HarmonyOS-Sans.zip" | shasum -a 256 --check

for weight in Thin Light Regular Medium; do
  unzip -j -o "$TMP_DIR/HarmonyOS-Sans.zip" \
    "HarmonyOS Sans/HarmonyOS_Sans_SC/HarmonyOS_Sans_SC_${weight}.ttf" \
    -d "$FONT_DIR" >/dev/null
done

echo "HarmonyOS Sans SC fonts installed in $FONT_DIR"
