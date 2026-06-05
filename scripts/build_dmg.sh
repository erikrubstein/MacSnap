#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacSnap"
PRODUCT_NAME="MacSnap"
BUNDLE_ID="${BUNDLE_ID:-com.erik.macsnap}"
MINIMUM_SYSTEM_VERSION="${MINIMUM_SYSTEM_VERSION:-13.0}"
ARCHS="${ARCHS:-arm64 x86_64}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -n "${VERSION:-}" ]]; then
  APP_VERSION="$VERSION"
else
  APP_VERSION="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)"
  APP_VERSION="${APP_VERSION:-0.1.0}"
fi

BUILD_NUMBER="${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"
DIST_DIR="$ROOT_DIR/dist"
PACKAGE_DIR="$ROOT_DIR/.build/package"
APP_BUNDLE="$PACKAGE_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
DMG_STAGE="$PACKAGE_DIR/dmg"
DMG_PATH="$DIST_DIR/$APP_NAME-$APP_VERSION.dmg"

rm -rf "$PACKAGE_DIR" "$DIST_DIR"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$DIST_DIR"

successful_archs=()
for arch in $ARCHS; do
  echo "Building $PRODUCT_NAME for $arch..."
  swift build -c release --arch "$arch" --product "$PRODUCT_NAME"

  executable="$ROOT_DIR/.build/$arch-apple-macosx/release/$PRODUCT_NAME"
  if [[ ! -x "$executable" ]]; then
    echo "Expected executable not found at $executable" >&2
    exit 1
  fi

  successful_archs+=("$arch")
done

if [[ "${#successful_archs[@]}" -eq 0 ]]; then
  echo "No architectures were built." >&2
  exit 1
elif [[ "${#successful_archs[@]}" -eq 1 ]]; then
  arch="${successful_archs[0]}"
  cp "$ROOT_DIR/.build/$arch-apple-macosx/release/$PRODUCT_NAME" "$APP_MACOS/$APP_NAME"
else
  inputs=()
  for arch in "${successful_archs[@]}"; do
    inputs+=("$ROOT_DIR/.build/$arch-apple-macosx/release/$PRODUCT_NAME")
  done
  lipo -create "${inputs[@]}" -output "$APP_MACOS/$APP_NAME"
fi
chmod +x "$APP_MACOS/$APP_NAME"

resource_arch="${successful_archs[0]}"
resource_bundle="$ROOT_DIR/.build/$resource_arch-apple-macosx/release/MacSnap_MacSnap.bundle"
if [[ -d "$resource_bundle" ]]; then
  cp -R "$resource_bundle" "$APP_BUNDLE/"
  cp -R "$resource_bundle" "$APP_RESOURCES/"
else
  echo "Expected SwiftPM resource bundle not found at $resource_bundle" >&2
  exit 1
fi

cat > "$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
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
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MINIMUM_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "APPL????" > "$APP_CONTENTS/PkgInfo"

rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"
cp -R "$APP_BUNDLE" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created $DMG_PATH"
file "$APP_MACOS/$APP_NAME"
