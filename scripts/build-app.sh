#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist/Codex Usage.app"
MACOS="$DIST/Contents/MacOS"

swift build --product CodexUsageMenubar
rm -rf "$DIST"
mkdir -p "$MACOS"
cp "$ROOT/.build/debug/CodexUsageMenubar" "$MACOS/Codex Usage"
cat > "$DIST/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Codex Usage</string>
  <key>CFBundleIdentifier</key>
  <string>com.starshards.codex-usage</string>
  <key>CFBundleName</key>
  <string>Codex Usage</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST
echo "$DIST"
