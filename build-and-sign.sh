#!/usr/bin/env zsh
# build-and-sign.sh
# Builds the tomp3 CLI + menu bar app, signs, notarizes, and staples
# everything into one distributable .pkg.
#
# Usage:
#   ./build-and-sign.sh                # build, sign, notarize
#   ./build-and-sign.sh --skip-notary  # sign only (faster, for testing)

set -euo pipefail

# ─── Identity ────────────────────────────────────────────────────────────────
APP_SIGN_ID="Developer ID Application: Ibn Bilal (U8N2H82PMJ)"
PKG_SIGN_ID="Developer ID Installer: Ibn Bilal (U8N2H82PMJ)"
TEAM_ID="U8N2H82PMJ"
BUNDLE_ID="dev.aramb.tomp3"
APP_BUNDLE_ID="dev.aramb.tomp3app"

NOTARY_PROFILE="${NOTARY_PROFILE:-notarytool}"

# ─── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="${0:A:h}"
VERSION=$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')

BINARY_SRC="$SCRIPT_DIR/.build/apple/Products/Release/tomp3"
PAYLOAD_BIN="$SCRIPT_DIR/installer/payload/usr/local/bin/tomp3"
PAYLOAD_APP="$SCRIPT_DIR/installer/payload/Applications/ToMP3App.app"

ARCHIVE_PATH="/tmp/ToMP3App.xcarchive"
EXPORT_PATH="/tmp/ToMP3App-export"
EXPORT_OPTIONS="$SCRIPT_DIR/App/ExportOptions.plist"

PKG_COMPONENT="$SCRIPT_DIR/installer/build/tomp3-component.pkg"
PKG_OUT="$SCRIPT_DIR/installer/build/tomp3-$VERSION-macos.pkg"

# ─── Colours ─────────────────────────────────────────────────────────────────
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'; BOLD='\033[1m'
step()  { echo "\n${BOLD}${CYAN}▶ $1${RESET}" }
ok()    { echo "  ${GREEN}✓${RESET} $1" }
warn()  { echo "  ${YELLOW}⚠${RESET} $1" }

# ─── Flags ───────────────────────────────────────────────────────────────────
SKIP_NOTARY=false
for arg in "$@"; do [[ "$arg" == "--skip-notary" ]] && SKIP_NOTARY=true; done

# ─── 1. Build CLI (universal) ─────────────────────────────────────────────────
step "Building tomp3 CLI v$VERSION (release · universal)"
swift build -c release --arch arm64 --arch x86_64
ok "CLI build complete"

# ─── 2. Sign CLI binary ──────────────────────────────────────────────────────
step "Signing CLI binary"
codesign --deep --force --verify --verbose \
  --options runtime \
  --sign "$APP_SIGN_ID" \
  "$BINARY_SRC"
codesign --verify --verbose "$BINARY_SRC"
ok "CLI binary signed"

# ─── 3. Build Xcode app ───────────────────────────────────────────────────────
step "Generating Xcode project (xcodegen)"
(cd "$SCRIPT_DIR/App" && xcodegen generate --quiet)
ok "Project generated"

step "Archiving ToMP3App (Release)"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
xcodebuild archive \
  -project "$SCRIPT_DIR/App/ToMP3App.xcodeproj" \
  -scheme ToMP3App \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_IDENTITY="$APP_SIGN_ID" \
  | grep -E "error:|warning:|Build succeeded|Archive succeeded" || true
ok "Archive complete"

step "Exporting signed .app (Developer ID)"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates \
  | grep -E "error:|Export succeeded" || true
ok "App exported: $EXPORT_PATH/ToMP3App.app"

# ─── 4. Assemble payload ─────────────────────────────────────────────────────
step "Preparing pkg payload"
mkdir -p "$(dirname "$PAYLOAD_BIN")"
cp "$BINARY_SRC" "$PAYLOAD_BIN"
chmod 755 "$PAYLOAD_BIN"

mkdir -p "$(dirname "$PAYLOAD_APP")"
rm -rf "$PAYLOAD_APP"
cp -R "$EXPORT_PATH/ToMP3App.app" "$PAYLOAD_APP"

chmod +x "$SCRIPT_DIR/installer/scripts/postinstall"
ok "Payload ready  (CLI + ToMP3App.app)"

# ─── 5. Build component pkg ──────────────────────────────────────────────────
step "Building component package"
mkdir -p "$SCRIPT_DIR/installer/build"
pkgbuild \
  --root "$SCRIPT_DIR/installer/payload" \
  --scripts "$SCRIPT_DIR/installer/scripts" \
  --identifier "$BUNDLE_ID" \
  --version "$VERSION" \
  --install-location "/" \
  "$PKG_COMPONENT"
ok "Component package built"

# ─── 6. Wrap with productbuild (signed) ──────────────────────────────────────
step "Wrapping into distributable pkg"
productbuild \
  --distribution "$SCRIPT_DIR/installer/Distribution.xml" \
  --resources "$SCRIPT_DIR/installer/resources" \
  --package-path "$SCRIPT_DIR/installer/build" \
  --sign "$PKG_SIGN_ID" \
  "$PKG_OUT"
ok "Signed pkg: $(basename "$PKG_OUT")"

# ─── 7. Notarize ─────────────────────────────────────────────────────────────
if [[ "$SKIP_NOTARY" == true ]]; then
  warn "Skipping notarization (--skip-notary)"
else
  step "Notarizing (this takes ~2–5 minutes)"
  xcrun notarytool submit "$PKG_OUT" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  step "Stapling notarization ticket"
  for attempt in 1 2 3; do
    xcrun stapler staple "$PKG_OUT" && break
    warn "Staple attempt $attempt failed, retrying in 5s…"
    sleep 5
  done
  xcrun stapler validate "$PKG_OUT"
  ok "Notarized and stapled"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
echo "\n${BOLD}${GREEN}✓ Done!${RESET}"
echo "  Package: ${CYAN}$PKG_OUT${RESET}"
echo "  Size:    $(du -sh "$PKG_OUT" | cut -f1)"
echo "  Contains: tomp3 CLI + ToMP3App.app (Finder extension included)\n"
