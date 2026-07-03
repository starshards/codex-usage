#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: scripts/register-native-host.sh <chrome-extension-id> [chrome-extension-id ...]" >&2
  exit 64
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST_BINARY="${CODEX_USAGE_HOST_BINARY:-$ROOT/.build/debug/CodexUsageNativeHost}"
EXTENSION_IDS=("$@")

if [[ "${CODEX_USAGE_SKIP_SWIFT_BUILD:-0}" != "1" ]]; then
  swift build --product CodexUsageNativeHost
fi

if [[ -n "${CODEX_USAGE_NATIVE_HOST_DIRS:-}" ]]; then
  IFS=':' read -r -a TARGET_DIRS <<< "$CODEX_USAGE_NATIVE_HOST_DIRS"
else
  TARGET_DIRS=(
    "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
    "$HOME/Library/Application Support/Google/Chrome Beta/NativeMessagingHosts"
    "$HOME/Library/Application Support/Google/Chrome Canary/NativeMessagingHosts"
    "$HOME/Library/Application Support/Chromium/NativeMessagingHosts"
    "$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
  )
fi

write_manifest() {
  local target_dir="$1"
  local target_file="$target_dir/com.starshards.codex_usage.json"

  mkdir -p "$target_dir"
  {
    printf '{\n'
    printf '  "name": "com.starshards.codex_usage",\n'
    printf '  "description": "Codex Usage native messaging host",\n'
    printf '  "path": "%s",\n' "$HOST_BINARY"
    printf '  "type": "stdio",\n'
    printf '  "allowed_origins": [\n'
    for index in "${!EXTENSION_IDS[@]}"; do
      local comma=","
      if [[ "$index" -eq $((${#EXTENSION_IDS[@]} - 1)) ]]; then
        comma=""
      fi
      printf '    "chrome-extension://%s/"%s\n' "${EXTENSION_IDS[$index]}" "$comma"
    done
    printf '  ]\n'
    printf '}\n'
  } > "$target_file"

  echo "Wrote $target_file"
}

for target_dir in "${TARGET_DIRS[@]}"; do
  write_manifest "$target_dir"
done
