#!/usr/bin/env bash
set -euo pipefail
IFS=$' \n\t'

umask 022
export LC_ALL=C
export LANG=C
export COPYFILE_DISABLE=1

readonly APP_NAME="AntiADHD"
readonly EXECUTABLE_NAME="AntiADHD"
readonly MINIMUM_MACOS="13.0"
readonly DEFAULT_BUNDLE_ID="com.parrotnavy.antiadhd"
readonly DEFAULT_SPARKLE_FEED_URL="https://parrotnavy.github.io/anti-adhd/api/macos-appcast.xml"
readonly DEFAULT_SPARKLE_PUBLIC_ED_KEY="pXA8Cv2XBe/5ug0CT2KItb84Hyh2Z2gdA3vh4bewycY="

usage() {
  printf 'Usage: %s <VERSION>\n' "$0" >&2
  printf '  VERSION examples: 0.0.1, 1.2.3-rc.1, main-abcdef0\n' >&2
}

log() {
  printf '==> %s\n' "$1" >&2
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

normalize_version() {
  local raw major minor patch
  raw="$1"
  major=0
  minor=0
  patch=0

  IFS='.' read -r major minor patch <<EOF
$raw
EOF

  major="${major%%[^0-9]*}"
  minor="${minor%%[^0-9]*}"
  patch="${patch%%[^0-9]*}"

  [[ -n "$major" ]] || major=0
  [[ -n "$minor" ]] || minor=0
  [[ -n "$patch" ]] || patch=0

  printf '%s.%s.%s' "$major" "$minor" "$patch"
}

version_equals() {
  [[ "$(normalize_version "$1")" == "$(normalize_version "$2")" ]]
}

extract_minos_with_vtool() {
  local binary output line found
  binary="$1"
  found=1

  command -v vtool >/dev/null 2>&1 || return 1
  output="$(vtool -show-build "$binary" 2>/dev/null || true)"
  [[ -n "$output" ]] || return 1

  while IFS= read -r line; do
    if [[ "$line" =~ minos[[:space:]]+([0-9]+(\.[0-9]+){1,2}) ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      found=0
    fi
  done <<EOF
$output
EOF

  return "$found"
}

extract_minos_with_otool() {
  local binary output line found
  binary="$1"
  found=1

  command -v otool >/dev/null 2>&1 || return 1
  output="$(otool -l "$binary" 2>/dev/null || true)"
  [[ -n "$output" ]] || return 1

  while IFS= read -r line; do
    if [[ "$line" =~ minos[[:space:]]+([0-9]+(\.[0-9]+){1,2}) ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      found=0
    fi
  done <<EOF
$output
EOF

  return "$found"
}

verify_minimum_os() {
  local binary minos_values value
  binary="$1"

  minos_values="$(extract_minos_with_vtool "$binary" || true)"
  if [[ -z "$minos_values" ]]; then
    minos_values="$(extract_minos_with_otool "$binary" || true)"
  fi

  [[ -n "$minos_values" ]] || fail "Unable to read Mach-O minimum OS for $binary"

  while IFS= read -r value; do
    [[ -n "$value" ]] || continue
    if ! version_equals "$value" "$MINIMUM_MACOS"; then
      fail "Mach-O min OS mismatch ($value != $MINIMUM_MACOS) for $binary"
    fi
  done <<EOF
$minos_values
EOF
}

verify_arches() {
  local binary expected actual arch
  binary="$1"
  expected="$2"
  actual="$(lipo -archs "$binary" 2>/dev/null || true)"

  [[ -n "$actual" ]] || fail "Unable to read architectures from $binary"

  for arch in $expected; do
    if [[ " $actual " != *" $arch "* ]]; then
      fail "Missing architecture '$arch' in $binary (found: $actual)"
    fi
  done
}

build_release_binary() {
  local arch_list bin_path binary_path
  arch_list="$1"

  set --
  for arch in $arch_list; do
    set -- "$@" --arch "$arch"
  done

  if swift build -c release "$@" --product "$EXECUTABLE_NAME" >&2; then
    bin_path="$(swift build -c release "$@" --show-bin-path)"
    binary_path="$bin_path/$EXECUTABLE_NAME"
    if [[ -x "$binary_path" ]]; then
      printf '%s\n' "$binary_path"
      return 0
    fi
  fi

  log "Falling back to per-architecture builds and lipo"

  local combined_output
  combined_output="$WORK_DIR/$EXECUTABLE_NAME"
  rm -f "$combined_output"

  set --
  for arch in $arch_list; do
    log "Building $arch"
    swift build -c release --arch "$arch" --product "$EXECUTABLE_NAME" >&2
    bin_path="$(swift build -c release --arch "$arch" --show-bin-path)"
    binary_path="$bin_path/$EXECUTABLE_NAME"
    [[ -x "$binary_path" ]] || fail "Missing built binary for architecture $arch"
    set -- "$@" "$binary_path"
  done

  lipo -create "$@" -output "$combined_output"
  chmod 755 "$combined_output"

  printf '%s\n' "$combined_output"
}

create_info_plist() {
  cat >"$INFO_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MINIMUM_MACOS</string>
  <key>LSUIElement</key>
  <true/>
  <key>SUFeedURL</key>
  <string>$SPARKLE_FEED_URL</string>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_ED_KEY</string>
</dict>
</plist>
EOF
}

embed_sparkle_framework() {
  local sparkle_framework_src
  sparkle_framework_src="$PROJECT_ROOT/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"

  if [[ ! -d "$sparkle_framework_src" ]]; then
    fail "Sparkle.framework not found at $sparkle_framework_src. Run 'swift package resolve' before packaging."
  fi

  rm -rf "$FRAMEWORKS_DIR/Sparkle.framework"
  /usr/bin/ditto "$sparkle_framework_src" "$FRAMEWORKS_DIR/Sparkle.framework"

  [[ -d "$FRAMEWORKS_DIR/Sparkle.framework" ]] || fail "Sparkle.framework embed failed: $FRAMEWORKS_DIR/Sparkle.framework is missing"

  [[ -d "$FRAMEWORKS_DIR/Sparkle.framework/Updater.app" ]] || fail "Sparkle embed incomplete: missing $FRAMEWORKS_DIR/Sparkle.framework/Updater.app"
}

embed_swift_runtime() {
  local sign_identity
  sign_identity="$1"

  set -- \
    --copy \
    --platform macosx \
    --scan-executable "$APP_EXECUTABLE_PATH" \
    --destination "$FRAMEWORKS_DIR" \
    --sign "$sign_identity"

  if [[ -n "$KEYCHAIN_PATH" ]]; then
    set -- "$@" --keychain "$KEYCHAIN_PATH"
  fi

  if [[ "$sign_identity" == "-" ]]; then
    set -- "$@" --Xcodesign --timestamp=none
  else
    set -- "$@" --Xcodesign --timestamp
  fi

  xcrun swift-stdlib-tool "$@"
}

ensure_frameworks_rpath() {
  local binary rpath
  binary="$1"
  rpath="@executable_path/../Frameworks"

  command -v otool >/dev/null 2>&1 || fail "otool not found; cannot verify rpath for $binary"
  command -v install_name_tool >/dev/null 2>&1 || fail "install_name_tool not found; cannot set rpath for $binary"

  if otool -l "$binary" 2>/dev/null | /usr/bin/grep -q "path $rpath ("; then
    return 0
  fi

  install_name_tool -add_rpath "$rpath" "$binary" || fail "Failed to add rpath '$rpath' to $binary"
  otool -l "$binary" 2>/dev/null | /usr/bin/grep -q "path $rpath (" || fail "rpath '$rpath' missing after install_name_tool for $binary"
}

sign_app_bundle() {
  local sign_identity
  sign_identity="$1"

  set -- --force --deep --sign "$sign_identity"

  if [[ -n "$KEYCHAIN_PATH" ]]; then
    set -- "$@" --keychain "$KEYCHAIN_PATH"
  fi

  if [[ "$sign_identity" == "-" ]]; then
    set -- "$@" --timestamp=none
  else
    set -- "$@" --options runtime --timestamp
  fi

  codesign "$@" "$APP_BUNDLE"
  codesign --verify --deep --strict "$APP_BUNDLE"
}

create_dmg() {
  local dmg_path
  dmg_path="$DIST_DIR/$DMG_NAME"

  rm -f "$dmg_path"
  rm -rf "$DMG_STAGE_DIR"
  mkdir -p "$DMG_STAGE_DIR"

  cp -R "$APP_BUNDLE" "$DMG_STAGE_DIR/$APP_NAME.app"
  ln -s /Applications "$DMG_STAGE_DIR/Applications"

  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGE_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    -quiet \
    "$dmg_path"

  printf '%s\n' "$dmg_path"
}

maybe_notarize() {
  local dmg_path key_path key_id issuer_id
  dmg_path="$1"
  key_path="${APPLE_NOTARY_KEY_P8_PATH:-}"
  key_id="${APPLE_NOTARY_KEY_ID:-}"
  issuer_id="${APPLE_NOTARY_ISSUER_ID:-}"

  if [[ -z "$key_path$key_id$issuer_id" ]]; then
    log "Skipping notarization (notary credentials not set)"
    return 0
  fi

  [[ -n "$key_path" && -n "$key_id" && -n "$issuer_id" ]] || fail "Notarization env vars must all be set"
  [[ -f "$key_path" ]] || fail "APPLE_NOTARY_KEY_P8_PATH not found at $key_path"
  [[ "$CODE_SIGN_IDENTITY" != "-" ]] || fail "Notarization requires non-ad-hoc CODE_SIGN_IDENTITY"

  log "Submitting DMG for notarization"
  xcrun notarytool submit "$dmg_path" \
    --key "$key_path" \
    --key-id "$key_id" \
    --issuer "$issuer_id" \
    --wait

  log "Stapling notarization ticket"
  xcrun stapler staple "$dmg_path"
}

write_checksums() {
  (
    cd "$DIST_DIR"
    shasum -a 256 "$DMG_NAME"
  ) >"$DIST_DIR/SHA256SUMS.txt"
}

[[ $# -eq 1 ]] || {
  usage
  fail "VERSION argument is required"
}

readonly VERSION="$1"

if [[ ! "$VERSION" =~ ^([0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?|main-[0-9A-Fa-f]{7,40})$ ]]; then
  fail "Invalid VERSION '$VERSION'"
fi

export MACOSX_DEPLOYMENT_TARGET="$MINIMUM_MACOS"

readonly SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-$DEFAULT_SPARKLE_FEED_URL}"
readonly SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-$DEFAULT_SPARKLE_PUBLIC_ED_KEY}"

readonly BUNDLE_ID="${BUNDLE_ID:-$DEFAULT_BUNDLE_ID}"
readonly TARGET_ARCHS="${TARGET_ARCHS:-arm64 x86_64}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly SCRIPT_DIR
readonly PROJECT_ROOT
readonly DIST_DIR="$PROJECT_ROOT/dist"
readonly WORK_DIR="$PROJECT_ROOT/.build/package"
readonly APP_BUNDLE="$WORK_DIR/$APP_NAME.app"
readonly CONTENTS_DIR="$APP_BUNDLE/Contents"
readonly MACOS_DIR="$CONTENTS_DIR/MacOS"
readonly FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
readonly INFO_PLIST="$CONTENTS_DIR/Info.plist"
readonly APP_EXECUTABLE_PATH="$MACOS_DIR/$EXECUTABLE_NAME"
readonly DMG_STAGE_DIR="$WORK_DIR/dmg-stage"
readonly DMG_NAME="$APP_NAME-$VERSION.dmg"
readonly CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
readonly KEYCHAIN_PATH="${KEYCHAIN_PATH:-}"

rm -rf "$APP_BUNDLE" "$DMG_STAGE_DIR"
mkdir -p "$DIST_DIR" "$WORK_DIR" "$MACOS_DIR" "$FRAMEWORKS_DIR"

log "MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET"
log "Building release binary"
BUILT_BINARY="$(build_release_binary "$TARGET_ARCHS")"
[[ -x "$BUILT_BINARY" ]] || fail "Built binary missing: $BUILT_BINARY"

verify_arches "$BUILT_BINARY" "$TARGET_ARCHS"
verify_minimum_os "$BUILT_BINARY"

log "Creating app bundle"
cp "$BUILT_BINARY" "$APP_EXECUTABLE_PATH"
chmod 755 "$APP_EXECUTABLE_PATH"
create_info_plist

log "Embedding Swift runtime"
embed_swift_runtime "$CODE_SIGN_IDENTITY"

log "Embedding Sparkle.framework"
embed_sparkle_framework

log "Ensuring executable rpath for Frameworks"
ensure_frameworks_rpath "$APP_EXECUTABLE_PATH"

log "Signing app bundle"
sign_app_bundle "$CODE_SIGN_IDENTITY"

verify_arches "$APP_EXECUTABLE_PATH" "$TARGET_ARCHS"
verify_minimum_os "$APP_EXECUTABLE_PATH"

log "Creating DMG"
DMG_PATH="$(create_dmg)"

maybe_notarize "$DMG_PATH"
write_checksums

log "Created $DMG_PATH"
log "Created $DIST_DIR/SHA256SUMS.txt"
