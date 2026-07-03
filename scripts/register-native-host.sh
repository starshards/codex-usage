#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: scripts/register-native-host.sh <chrome-extension-id>" >&2
  exit 64
fi

EXTENSION_ID="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST_BINARY="$ROOT/.build/debug/CodexUsageNativeHost"
TARGET_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
TARGET_FILE="$TARGET_DIR/com.starshards.codex_usage.json"

swift build --product CodexUsageNativeHost
mkdir -p "$TARGET_DIR"
sed \
  -e "s#__HOST_BINARY_PATH__#$HOST_BINARY#g" \
  -e "s#__EXTENSION_ID__#$EXTENSION_ID#g" \
  "$ROOT/native-host/com.starshards.codex_usage.json.template" > "$TARGET_FILE"

echo "Wrote $TARGET_FILE"
