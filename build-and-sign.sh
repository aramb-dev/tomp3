#!/usr/bin/env zsh
# build-and-sign.sh
# Builds tomp3, signs the binary + pkg, notarizes, and staples.
#
# Usage:
#   ./build-and-sign.sh                # build, sign, notarize
#   ./build-and-sign.sh --skip-notary  # sign only (faster, for testing)

set -euo pipefail

# ─── Identity (auto-detected from Keychain) ──────────────────────────────────
APP_SIGN_ID="Developer ID Application: Ibn Bilal (U8N2H82PMJ)"
PKG_SIGN_ID="Developer ID Installer: Ibn Bilal (U8N2H82PMJ)"
TEAM_ID="U8N2H82PMJ"
BUNDLE_ID="dev.aramb.tomp3"

# ─── Notarytool keychain profile ─────────────────────────────────────────────
# Uses the same "notarytool" profile as SystemVoiceMemos.
# Override per-run with: NOTARY_PROFILE=other-profile ./build-and-sign.sh
NOTARY_PROFILE="${NOTARY_PROFILE:-notarytool}"

# ─── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="${0:A:h}"
VERSION=$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')
BINARY_SRC="$SCRIPT_DIR/.build/release/tomp3"
PAYLOAD_BIN="$SCRIPT_DIR/installer/payload/usr/local/bin/tomp3"
PKG_COMPONENT="$SCRIPT_DIR/installer/build/tomp3-component.pkg"
PKG_OUT="$SCRIPT_DIR/installer/build/tomp3-$VERSION-macos.pkg"

# ─── Colours ──────────────────────────────────────────────────────────────────
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'; BOLD='\033[1m'
step()  { echo "\n${BOLD}${CYAN}▶ $1${RESET}" }
ok()    { echo "  ${GREEN}✓${RESET} $1" }
warn()  { echo "  ${YELLOW}⚠${RESET} $1" }

# ─── Parse flags ─────────────────────────────────────────────────────────────
SKIP_NOTARY=false
for arg in "$@"; do [[ "$arg" == "--skip-notary" ]] && SKIP_NOTARY=true; done

# ─── 1. Build ─────────────────────────────────────────────────────────────────
step "Building tomp3 v$VERSION (release)"
swift build -c release --arch arm64 --arch x86_64   # universal binary
ok "Build complete"

# ─── 2. Sign binary ──────────────────────────────────────────────────────────
step "Signing binary"
codesign \
  --deep --force --verify --verbose \
  --options runtime \
  --sign "$APP_SIGN_ID" \
  "$BINARY_SRC"
codesign --verify --verbose "$BINARY_SRC"
ok "Binary signed"

# ─── 3. Copy into payload ────────────────────────────────────────────────────
step "Preparing pkg payload"
mkdir -p "$(dirname "$PAYLOAD_BIN")"
cp "$BINARY_SRC" "$PAYLOAD_BIN"
chmod 755 "$PAYLOAD_BIN"
chmod +x "$SCRIPT_DIR/installer/scripts/postinstall"
ok "Payload ready"

# ─── 4. Build component pkg ──────────────────────────────────────────────────
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

# ─── 5. Wrap with productbuild (signed) ──────────────────────────────────────
step "Wrapping into distributable pkg"
productbuild \
  --distribution "$SCRIPT_DIR/installer/Distribution.xml" \
  --resources "$SCRIPT_DIR/installer/resources" \
  --package-path "$SCRIPT_DIR/installer/build" \
  --sign "$PKG_SIGN_ID" \
  "$PKG_OUT"
ok "Signed pkg: $(basename "$PKG_OUT")"

# ─── 6. Notarize ─────────────────────────────────────────────────────────────
if [[ "$SKIP_NOTARY" == true ]]; then
  warn "Skipping notarization (--skip-notary)"
else
  step "Notarizing (this takes ~2–5 minutes)"

  # Requires: xcrun notarytool store-credentials "tomp3-notary"
  #   --apple-id <your-apple-id>
  #   --team-id  $TEAM_ID
  #   --password <app-specific-password>
  xcrun notarytool submit "$PKG_OUT" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  step "Stapling notarization ticket"
  xcrun stapler staple "$PKG_OUT"
  ok "Notarized and stapled"
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
echo "\n${BOLD}${GREEN}✓ Done!${RESET}"
echo "  Package: ${CYAN}$PKG_OUT${RESET}"
echo "  Size:    $(du -sh "$PKG_OUT" | cut -f1)\n"
