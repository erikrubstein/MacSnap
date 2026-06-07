#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacSnap"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DIST_DIR="$ROOT_DIR/dist"
APPCAST_WORK_DIR="$ROOT_DIR/.build/appcast"
SPARKLE_BIN_DIR="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin"
GENERATE_APPCAST="$SPARKLE_BIN_DIR/generate_appcast"

REPOSITORY="${GITHUB_REPOSITORY:-erikrubstein/MacSnap}"
TAG="${GITHUB_REF_NAME:-$(git describe --tags --abbrev=0 2>/dev/null || true)}"
TAG="${TAG:-v0.1.0}"
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX:-https://github.com/$REPOSITORY/releases/download/$TAG/}"
PRODUCT_LINK="${PRODUCT_LINK:-https://github.com/$REPOSITORY}"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required tool not found: $1" >&2
    exit 1
  fi
}

require_tool swift

if [[ ! -x "$GENERATE_APPCAST" ]]; then
  swift package resolve
fi

if [[ ! -x "$GENERATE_APPCAST" ]]; then
  echo "Expected Sparkle generate_appcast at $GENERATE_APPCAST" >&2
  exit 1
fi

if [[ -z "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  echo "SPARKLE_PRIVATE_KEY must contain the Sparkle EdDSA private key." >&2
  exit 1
fi

shopt -s nullglob
dmg_files=("$DIST_DIR"/"$APP_NAME"-*.dmg)
shopt -u nullglob

if [[ "${#dmg_files[@]}" -eq 0 ]]; then
  echo "No DMG found at $DIST_DIR/$APP_NAME-*.dmg" >&2
  exit 1
fi

rm -rf "$APPCAST_WORK_DIR"
mkdir -p "$APPCAST_WORK_DIR"

for dmg in "${dmg_files[@]}"; do
  cp "$dmg" "$APPCAST_WORK_DIR/"
  notes_path="$APPCAST_WORK_DIR/$(basename "${dmg%.*}").md"
  cat > "$notes_path" <<NOTES
# $APP_NAME $TAG

See the GitHub release for changes:
$PRODUCT_LINK/releases/tag/$TAG
NOTES
done

printf '%s' "$SPARKLE_PRIVATE_KEY" | "$GENERATE_APPCAST" \
  --ed-key-file - \
  --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
  --link "$PRODUCT_LINK" \
  --embed-release-notes \
  --maximum-versions 1 \
  -o "$DIST_DIR/appcast.xml" \
  "$APPCAST_WORK_DIR"

echo "Created $DIST_DIR/appcast.xml"
