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
APP_ICON_SOURCE="$ROOT_DIR/Sources/MacSnap/Resources/MacSnapIcon.png"
DMG_BACKGROUND_SOURCE="$ROOT_DIR/Packaging/DMGBackground.png"
APP_ICONSET="$PACKAGE_DIR/$APP_NAME.iconset"
APP_ICON="$APP_RESOURCES/$APP_NAME.icns"
DMG_STAGE="$PACKAGE_DIR/dmg"
DMG_BACKGROUND="$DMG_STAGE/.background/background.png"
RW_DMG_PATH="$PACKAGE_DIR/$APP_NAME-rw.dmg"
DMG_PATH="$DIST_DIR/$APP_NAME-$APP_VERSION.dmg"

rm -rf "$PACKAGE_DIR" "$DIST_DIR"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$DIST_DIR"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required tool not found: $1" >&2
    exit 1
  fi
}

validate_icon_source() {
  if [[ ! -s "$APP_ICON_SOURCE" ]]; then
    echo "Expected non-empty app icon PNG at $APP_ICON_SOURCE" >&2
    exit 1
  fi

  if ! sips -g pixelWidth -g pixelHeight "$APP_ICON_SOURCE" >/dev/null 2>&1; then
    echo "App icon source is not a valid PNG: $APP_ICON_SOURCE" >&2
    exit 1
  fi
}

validate_dmg_background_source() {
  if [[ ! -s "$DMG_BACKGROUND_SOURCE" ]]; then
    echo "Expected non-empty DMG background PNG at $DMG_BACKGROUND_SOURCE" >&2
    exit 1
  fi

  if ! sips -g pixelWidth -g pixelHeight "$DMG_BACKGROUND_SOURCE" >/dev/null 2>&1; then
    echo "DMG background source is not a valid PNG: $DMG_BACKGROUND_SOURCE" >&2
    exit 1
  fi
}

build_icns_from_png() {
  rm -rf "$APP_ICONSET"
  mkdir -p "$APP_ICONSET"

  while read -r size name; do
    sips -s format png -z "$size" "$size" "$APP_ICON_SOURCE" --out "$APP_ICONSET/$name" >/dev/null
  done <<EOF
16 icon_16x16.png
32 icon_16x16@2x.png
32 icon_32x32.png
64 icon_32x32@2x.png
128 icon_128x128.png
256 icon_128x128@2x.png
256 icon_256x256.png
512 icon_256x256@2x.png
512 icon_512x512.png
1024 icon_512x512@2x.png
EOF

  iconutil -c icns "$APP_ICONSET" -o "$APP_ICON"
}

copy_dmg_background() {
  mkdir -p "$(dirname "$DMG_BACKGROUND")"
  cp "$DMG_BACKGROUND_SOURCE" "$DMG_BACKGROUND"
}

sign_app_bundle() {
  codesign --force --deep --sign - "$APP_BUNDLE"
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
}

set_dmg_finder_layout() {
  local mounted_volume="$1"

  if [[ -e "$mounted_volume/.background" ]]; then
    SetFile -a V "$mounted_volume/.background" 2>/dev/null || chflags hidden "$mounted_volume/.background" 2>/dev/null || true
  fi
  if [[ -e "$mounted_volume/.fseventsd" ]]; then
    SetFile -a V "$mounted_volume/.fseventsd" 2>/dev/null || chflags hidden "$mounted_volume/.fseventsd" 2>/dev/null || true
  fi
  cp "$APP_ICON" "$mounted_volume/.VolumeIcon.icns"
  SetFile -a C "$mounted_volume" 2>/dev/null || true

  osascript <<APPLESCRIPT
set targetFolder to POSIX file "$mounted_volume" as alias
tell application "Finder"
  activate
  open targetFolder
  delay 1
  set dmgWindow to front Finder window
  set current view of dmgWindow to icon view
  set toolbar visible of dmgWindow to false
  set statusbar visible of dmgWindow to false
  set the bounds of dmgWindow to {120, 120, 840, 540}
  set viewOptions to the icon view options of dmgWindow
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 112
  set text size of viewOptions to 13
  set background color of viewOptions to {63222, 63222, 63222}
  set background picture of viewOptions to (POSIX file "$mounted_volume/.background/background.png")
  try
    set position of item ".background" of dmgWindow to {80, 80}
  end try
  try
    set position of item ".fseventsd" of dmgWindow to {80, 150}
  end try
  try
    set position of item ".VolumeIcon.icns" of dmgWindow to {80, 220}
  end try
  try
    set position of item ".DS_Store" of dmgWindow to {80, 150}
  end try
  set position of item "$APP_NAME.app" of dmgWindow to {155, 220}
  set position of item "Applications" of dmgWindow to {515, 220}
  update targetFolder
  delay 3
  close dmgWindow
end tell
APPLESCRIPT

  if [[ ! -f "$mounted_volume/.DS_Store" ]]; then
    echo "Finder did not persist .DS_Store for the DMG layout." >&2
    return 1
  fi
}

hide_dmg_helper_items() {
  local mounted_volume="$1"

  for helper_item in ".DS_Store" ".background" ".fseventsd"; do
    if [[ -e "$mounted_volume/$helper_item" ]]; then
      SetFile -a V "$mounted_volume/$helper_item" 2>/dev/null || chflags hidden "$mounted_volume/$helper_item" 2>/dev/null || true
    fi
  done

  rm -rf "$mounted_volume/.fseventsd"
}

require_tool swift
require_tool sips
require_tool iconutil
require_tool hdiutil
require_tool osascript
require_tool codesign
validate_icon_source
validate_dmg_background_source

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
  cp -R "$resource_bundle" "$APP_RESOURCES/"
else
  echo "Expected SwiftPM resource bundle not found at $resource_bundle" >&2
  exit 1
fi

build_icns_from_png

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
  <key>CFBundleIconFile</key>
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
sign_app_bundle

rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE/.background"
copy_dmg_background
cp -R "$APP_BUNDLE" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -fs HFS+ \
  -format UDRW \
  "$RW_DMG_PATH"

MOUNT_DIR="$(mktemp -d "$PACKAGE_DIR/dmg-mount.XXXXXX")"
device=""
detach_dmg() {
  if [[ -n "$device" ]]; then
    hdiutil detach "$device" -quiet || true
  fi
  rm -rf "$MOUNT_DIR"
}
trap detach_dmg EXIT

device="$(hdiutil attach "$RW_DMG_PATH" -readwrite -noverify -noautoopen -mountpoint "$MOUNT_DIR" | awk '/Apple_APFS|Apple_HFS/ { print $1 }' | tail -1)"
set_dmg_finder_layout "$MOUNT_DIR"
hide_dmg_helper_items "$MOUNT_DIR"
sync
sleep 1
hdiutil detach "$device" -quiet
device=""

hdiutil convert "$RW_DMG_PATH" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG_PATH" >/dev/null

echo "Created $DMG_PATH"
file "$APP_MACOS/$APP_NAME"
