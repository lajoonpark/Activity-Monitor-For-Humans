#!/usr/bin/env bash
#
# make_release.sh
#
# Builds an ad-hoc signed Release build of Wren and packages it into a
# drag-to-Applications DMG. Architecture is selected with ARCH=arm64 | x86_64 |
# universal (default: universal).
#
# Used both locally and by .github/workflows/release.yml. Single source of
# truth for release packaging.
#
set -euo pipefail

# --- 0. Resolve paths -------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_ROOT/Wren.xcodeproj"
SCHEME="Wren"

OUT_DIR="${OUT_DIR:-$REPO_ROOT/dist}"
DERIVED_DATA="${DERIVED_DATA_PATH:-$REPO_ROOT/.build}"

APP_NAME="Wren"
APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
STAGING_DIR="$(mktemp -d -t wren-dmg)"
trap 'rm -rf "$STAGING_DIR"' EXIT

mkdir -p "$OUT_DIR"

# --- Architecture selection (ARCH=arm64 | x86_64 | universal) ---------------
ARCH="${ARCH:-universal}"
case "$ARCH" in
  arm64)     ARCHS='arm64' ;;
  x86_64)    ARCHS='x86_64' ;;
  universal) ARCHS='arm64 x86_64' ;;
  *) echo "error: unknown ARCH '$ARCH' (use arm64, x86_64, or universal)" >&2; exit 1 ;;
esac
# Universal keeps the historical '-macOS.dmg' name; single-arch adds a suffix.
if [[ "$ARCH" == "universal" ]]; then ARCH_SUFFIX=""; else ARCH_SUFFIX="-$ARCH"; fi
echo "    arch      : $ARCH ($ARCHS)"

echo "==> Wren release packaging"
echo "    repo root : $REPO_ROOT"
echo "    output    : $OUT_DIR"

# --- 1. Read version --------------------------------------------------------
# Prefer MARKETING_VERSION from the project; fall back to a numeric-ish tag.
VERSION="$(\
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/MARKETING_VERSION/ {print $2; exit}' \
)"
VERSION="${VERSION:-0.0.0}"
echo "    version   : $VERSION"

DMG_NAME="$APP_NAME-$VERSION-macOS${ARCH_SUFFIX}.dmg"
DMG_PATH="$OUT_DIR/$DMG_NAME"

# --- 2. Build universal Release ---------------------------------------------
echo "==> Building $ARCH Release ($(uname -m) host)..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  ARCHS="$ARCHS" \
  ONLY_ACTIVE_ARCH=NO \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: expected app bundle not found at $APP_PATH" >&2
  exit 1
fi

# --- 3. Explicitly re-sign ad-hoc + hardened runtime ------------------------
# Ad-hoc for now (see README Gatekeeper note). To add a paid Developer ID later,
# replace the identity here with the certificate name in one line.
echo "==> Re-signing ad-hoc with hardened runtime..."
codesign --force --sign - --options runtime "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

echo "==> Signing summary:"
codesign -dv --verbose=2 "$APP_PATH" 2>&1 | sed 's/^/    /'

# Gatekeeper assessment will legitimately fail without a Developer ID; report
# it as expected rather than a build failure.
if spctl --assess --type execute "$APP_PATH" 2>/dev/null; then
  echo "  (spctl: assess passed)"
else
  echo "  (spctl: assess FAILS as expected - no Developer ID; documented workaround required)"
fi

# --- 4. Stage DMG contents --------------------------------------------------
echo "==> Staging DMG contents..."
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

cat > "$STAGING_DIR/README.txt" <<EOF
Wren $VERSION

Install:
  Drag Wren.app into the Applications folder.

First launch:
  The app is ad-hoc signed (this is an open-source project without a
  paid Apple Developer ID), so macOS Gatekeeper will say the developer
  "cannot be verified" the first time.

  To open it anyway:
    - Control-click (right-click) Wren.app -> Open -> Open, or
    - System Settings -> Privacy & Security -> scroll to the bottom ->
      "Open Anyway" -> Open.

SHA-256:
  $(shasum -a 256 "$APP_PATH" 2>/dev/null | awk '{print $1}' || echo '(see .dmg.sha256 on release page)')
EOF

# --- 5. Create DMG ----------------------------------------------------------
echo "==> Creating DMG ($DMG_PATH)..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"
echo "    done."

# --- 6. Checksum + summary --------------------------------------------------
DMG_CHECKSUM="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
printf '%s' "$DMG_CHECKSUM" > "$DMG_PATH.sha256"

echo
echo "==> Release artifacts"
echo "    DMG      : $DMG_PATH"
echo "    SHA-256  : $DMG_PATH.sha256"
echo "    checksum : $DMG_CHECKSUM"
