#!/usr/bin/env zsh
# release.sh
# Builds, signs, notarizes, then auto-updates CHANGELOG, landing page,
# creates the GitHub release, and pushes everything.
#
# Usage:
#   ./release.sh "Fixed a bug" "Added a feature"
#   ./release.sh --skip-notary "Quick test release"
#
# Each argument after flags becomes a bullet point in the release notes.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
SITE_DIR="/Volumes/aramb/github/aramb.dev"
SITE_PAGE="$SITE_DIR/app/tomp3/page.tsx"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'; BOLD='\033[1m'
step()  { echo "\n${BOLD}${CYAN}▶ $1${RESET}" }
ok()    { echo "  ${GREEN}✓${RESET} $1" }
warn()  { echo "  ${YELLOW}⚠${RESET} $1" }
die()   { echo "\n  ${YELLOW}✗ $1${RESET}\n"; exit 1 }

# ─── Parse flags & notes ─────────────────────────────────────────────────────
SKIP_NOTARY_FLAG=""
NOTES=()

for arg in "$@"; do
  if [[ "$arg" == "--skip-notary" ]]; then
    SKIP_NOTARY_FLAG="--skip-notary"
  else
    NOTES+=("$arg")
  fi
done

[[ ${#NOTES[@]} -eq 0 ]] && die "Provide at least one release note.\n  Usage: ./release.sh \"What changed\" \"Another change\""

VERSION=$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')
PKG_OUT="$SCRIPT_DIR/installer/build/tomp3-$VERSION-macos.pkg"
BINARY_SRC="$SCRIPT_DIR/.build/apple/Products/Release/tomp3"

# ─── 1. Build + sign + notarize ──────────────────────────────────────────────
step "Running build-and-sign for v$VERSION"
"$SCRIPT_DIR/build-and-sign.sh" $SKIP_NOTARY_FLAG
ok "Build complete"

# ─── 2. Update CHANGELOG.md ──────────────────────────────────────────────────
step "Updating CHANGELOG.md"

CHANGELOG="$SCRIPT_DIR/CHANGELOG.md"
BULLET_LINES=""
for note in "${NOTES[@]}"; do
  BULLET_LINES+="- $note\n"
done

# Prepend new version block after the first line (# Changelog)
TMPFILE=$(mktemp)
awk -v ver="$VERSION" -v bullets="$BULLET_LINES" '
  NR==1 { print; print ""; print "## v" ver; printf "%s", bullets; print ""; next }
  { print }
' "$CHANGELOG" > "$TMPFILE"
mv "$TMPFILE" "$CHANGELOG"
ok "CHANGELOG.md updated"

# ─── 3. Update landing page ──────────────────────────────────────────────────
step "Updating aramb.dev/tomp3 landing page"

[[ ! -f "$SITE_PAGE" ]] && die "Landing page not found: $SITE_PAGE"

# Bump VERSION constant
sed -i '' "s/^const VERSION = \".*\"/const VERSION = \"$VERSION\"/" "$SITE_PAGE"

# Build changelog items JS array entry for the new version
ITEMS_JS=""
for note in "${NOTES[@]}"; do
  # Escape double quotes for JS string
  escaped="${note//\"/\\\"}"
  ITEMS_JS+="      \"$escaped\",\n"
done

NEW_ENTRY="  {\n    version: \"$VERSION\",\n    items: [\n$ITEMS_JS    ],\n  },"

# Insert new entry at the top of the changelog array
perl -i -0pe "s/(const changelog = \[)(\n)/$1\n$NEW_ENTRY\n/" "$SITE_PAGE"

ok "Landing page updated"

# ─── 4. Commit tomp3 repo ────────────────────────────────────────────────────
step "Committing tomp3 repo"
cd "$SCRIPT_DIR"
git add -A
git commit -m "release: v$VERSION

$(for note in "${NOTES[@]}"; do echo "- $note"; done)"
git tag "v$VERSION" 2>/dev/null || warn "Tag v$VERSION already exists — skipping"
git push
git push origin "v$VERSION" 2>/dev/null || true
ok "tomp3 repo pushed"

# ─── 5. Commit aramb.dev ─────────────────────────────────────────────────────
step "Committing aramb.dev"
cd "$SITE_DIR"
git add "$SITE_PAGE"
git commit -m "feat: update tomp3 landing page to v$VERSION"
git push
ok "aramb.dev pushed"

# ─── 6. Create GitHub release ────────────────────────────────────────────────
step "Creating GitHub release v$VERSION"
cd "$SCRIPT_DIR"

RELEASE_NOTES="## What's new\n"
for note in "${NOTES[@]}"; do
  RELEASE_NOTES+="- $note\n"
done

cp "$BINARY_SRC" /tmp/tomp3-macos-arm64

gh release create "v$VERSION" \
  "$PKG_OUT" \
  /tmp/tomp3-macos-arm64 \
  --title "v$VERSION" \
  --notes "$(printf "$RELEASE_NOTES")"

ok "GitHub release v$VERSION created"

# ─── Done ─────────────────────────────────────────────────────────────────────
echo "\n${BOLD}${GREEN}✓ Released v$VERSION!${RESET}"
echo "  ${CYAN}https://github.com/aramb-dev/tomp3/releases/tag/v$VERSION${RESET}"
echo "  ${CYAN}https://aramb.dev/tomp3${RESET}\n"
