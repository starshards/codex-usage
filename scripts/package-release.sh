#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Codex Usage"
PRODUCT="CodexUsageMenubar"
BUNDLE_ID="${CODEX_USAGE_BUNDLE_ID:-com.starshards.codex-usage}"
MIN_SYSTEM_VERSION="${CODEX_USAGE_MIN_SYSTEM_VERSION:-14.0}"
RELEASE_DIR="${CODEX_USAGE_RELEASE_DIR:-$ROOT/dist/release}"
WORK_DIR="$RELEASE_DIR/work"
APP_PATH="$WORK_DIR/$APP_NAME.app"
DMG_ROOT="$WORK_DIR/dmg-root"

VERSION="${CODEX_USAGE_VERSION:-}"
BUILD_NUMBER="${CODEX_USAGE_BUILD_NUMBER:-}"
SIGN_IDENTITY="${CODEX_USAGE_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${CODEX_USAGE_NOTARY_PROFILE:-}"
NOTARIZE="${CODEX_USAGE_NOTARIZE:-0}"
DRY_RUN="${CODEX_USAGE_DRY_RUN:-0}"

usage() {
  cat <<'EOF'
Usage:
  scripts/package-release.sh [options]

Options:
  --version VERSION          Release version, for example 0.1.0.
  --build-number NUMBER     CFBundleVersion. Defaults to git commit count.
  --sign-identity ID        Developer ID Application identity for codesign.
  --notary-profile NAME     notarytool keychain profile name.
  --notarize                Submit the app and DMG to Apple notarization.
  --dry-run                 Print the workflow without building or writing files.
  -h, --help                Show this help.

Environment:
  CODEX_USAGE_VERSION
  CODEX_USAGE_BUILD_NUMBER
  CODEX_USAGE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
  CODEX_USAGE_NOTARY_PROFILE=codex-usage-notary
  CODEX_USAGE_NOTARIZE=1
  CODEX_USAGE_DRY_RUN=1
  CODEX_USAGE_RELEASE_DIR=dist/release

Developer ID release example:
  xcrun notarytool store-credentials codex-usage-notary --apple-id you@example.com --team-id TEAMID --password app-specific-password
  scripts/package-release.sh --version 0.1.0 --sign-identity "Developer ID Application: Your Name (TEAMID)" --notary-profile codex-usage-notary --notarize

GitHub Releases upload example:
  git tag v0.1.0
  git push origin v0.1.0
  gh release create v0.1.0 "dist/release/Codex Usage-0.1.0.dmg" "dist/release/Codex Usage-0.1.0.zip" --title "Codex Usage v0.1.0" --notes "Initial release"
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

warn() {
  echo "warning: $*" >&2
}

print_command() {
  local arg escaped
  printf '+'
  for arg in "$@"; do
    printf ' '
    if [[ "$arg" =~ ^[A-Za-z0-9_./:=@%+,-]+$ ]]; then
      printf '%s' "$arg"
    else
      escaped=${arg//\'/\'\\\'\'}
      printf "'%s'" "$escaped"
    fi
  done
  printf '\n'
}

run() {
  print_command "$@"
  if [[ "$DRY_RUN" != "1" ]]; then
    "$@"
  fi
}

require_command() {
  if [[ "$DRY_RUN" == "1" ]]; then
    return
  fi
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

detect_version() {
  if [[ -n "$VERSION" ]]; then
    return
  fi
  local tag
  if tag="$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null)"; then
    VERSION="${tag#v}"
  else
    VERSION="0.1.0"
  fi
}

detect_build_number() {
  if [[ -n "$BUILD_NUMBER" ]]; then
    return
  fi
  if BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null)"; then
    return
  fi
  BUILD_NUMBER="$(date +%Y%m%d%H%M)"
}

write_info_plist() {
  local plist="$APP_PATH/Contents/Info.plist"
  print_command "write" "$plist"
  if [[ "$DRY_RUN" == "1" ]]; then
    return
  fi
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST
}

build_app() {
  run swift build -c release --product "$PRODUCT"
  run rm -rf "$WORK_DIR"
  run mkdir -p "$APP_PATH/Contents/MacOS"
  run cp "$ROOT/.build/release/$PRODUCT" "$APP_PATH/Contents/MacOS/$APP_NAME"
  write_info_plist
}

sign_app() {
  if [[ -z "$SIGN_IDENTITY" ]]; then
    warn "CODEX_USAGE_SIGN_IDENTITY is empty; building unsigned artifacts for local testing only."
    return
  fi

  run codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$APP_PATH"
  run codesign --verify --deep --strict --verbose=2 "$APP_PATH"
}

create_zip() {
  local zip_path="$1"
  run rm -f "$zip_path"
  run ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$zip_path"
}

notarize_app() {
  local notary_zip="$RELEASE_DIR/$APP_NAME-$VERSION-notary.zip"
  create_zip "$notary_zip"
  run xcrun notarytool submit "$notary_zip" --keychain-profile "$NOTARY_PROFILE" --wait
  run xcrun stapler staple "$APP_PATH"
  run xcrun stapler validate "$APP_PATH"
  run rm -f "$notary_zip"
}

create_dmg() {
  local dmg_path="$1"
  run rm -rf "$DMG_ROOT"
  run mkdir -p "$DMG_ROOT"
  run cp -R "$APP_PATH" "$DMG_ROOT/"
  run ln -s /Applications "$DMG_ROOT/Applications"
  run rm -f "$dmg_path"
  run hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$DMG_ROOT" -ov -format UDZO "$dmg_path"
}

sign_dmg() {
  local dmg_path="$1"
  if [[ -z "$SIGN_IDENTITY" ]]; then
    return
  fi

  run codesign --force --timestamp --sign "$SIGN_IDENTITY" "$dmg_path"
  run codesign --verify --verbose=2 "$dmg_path"
}

notarize_dmg() {
  local dmg_path="$1"
  run xcrun notarytool submit "$dmg_path" --keychain-profile "$NOTARY_PROFILE" --wait
  run xcrun stapler staple "$dmg_path"
  run xcrun stapler validate "$dmg_path"
}

print_release_summary() {
  local tag="v$VERSION"
  echo
  echo "Artifacts:"
  echo "  $DMG_PATH"
  echo "  $ZIP_PATH"
  echo
  echo "GitHub Releases:"
  echo "  git tag $tag"
  echo "  git push origin $tag"
  echo "  gh release create $tag \"$DMG_PATH\" \"$ZIP_PATH\" --title \"Codex Usage $tag\" --notes \"Release $tag\""
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || die "--version requires a value"
      VERSION="$2"
      shift 2
      ;;
    --build-number)
      [[ $# -ge 2 ]] || die "--build-number requires a value"
      BUILD_NUMBER="$2"
      shift 2
      ;;
    --sign-identity)
      [[ $# -ge 2 ]] || die "--sign-identity requires a value"
      SIGN_IDENTITY="$2"
      shift 2
      ;;
    --notary-profile)
      [[ $# -ge 2 ]] || die "--notary-profile requires a value"
      NOTARY_PROFILE="$2"
      shift 2
      ;;
    --notarize)
      NOTARIZE=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

detect_version
detect_build_number

DMG_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.dmg"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION.zip"

if [[ "$NOTARIZE" == "1" && -z "$SIGN_IDENTITY" ]]; then
  die "--notarize requires --sign-identity or CODEX_USAGE_SIGN_IDENTITY"
fi

if [[ "$NOTARIZE" == "1" && -z "$NOTARY_PROFILE" ]]; then
  die "--notarize requires --notary-profile or CODEX_USAGE_NOTARY_PROFILE"
fi

require_command swift
require_command ditto
require_command hdiutil
if [[ -n "$SIGN_IDENTITY" ]]; then
  require_command codesign
fi
if [[ "$NOTARIZE" == "1" ]]; then
  require_command xcrun
fi

build_app
sign_app

if [[ "$NOTARIZE" == "1" ]]; then
  notarize_app
elif [[ -n "$SIGN_IDENTITY" ]]; then
  warn "app is signed but not notarized; pass --notarize for Developer ID distribution."
fi

create_zip "$ZIP_PATH"
create_dmg "$DMG_PATH"
sign_dmg "$DMG_PATH"

if [[ "$NOTARIZE" == "1" ]]; then
  notarize_dmg "$DMG_PATH"
elif [[ -n "$SIGN_IDENTITY" ]]; then
  warn "DMG is signed but not notarized; pass --notarize for Developer ID distribution."
fi

print_release_summary
