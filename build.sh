#!/bin/bash
# Builds Clicky.app from source. Usage:
#   ./build.sh            build into ./build and launch
#   ./build.sh --install  build, copy to /Applications and launch from there
set -euo pipefail
cd "$(dirname "$0")"

APP="Clicky"
BUILD="build"
BUNDLE="$BUILD/$APP.app"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "✗ Swift compiler not found."
  echo "  Install Apple's Command Line Tools first:  xcode-select --install"
  exit 1
fi

echo "▸ Cleaning"
rm -rf "$BUNDLE" "$BUILD/AppIcon.iconset"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

echo "▸ Compiling (Apple Silicon, macOS 14+)"
swiftc -O -parse-as-library -swift-version 5 \
  -target arm64-apple-macos14.0 \
  Sources/*.swift \
  -o "$BUNDLE/Contents/MacOS/$APP"

echo "▸ Building icon"
ICONSET="$BUILD/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$BUNDLE/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "▸ Writing Info.plist"
cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP</string>
  <key>CFBundleDisplayName</key><string>$APP</string>
  <key>CFBundleIdentifier</key><string>local.clicky.app</string>
  <key>CFBundleExecutable</key><string>$APP</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "▸ Signing (ad-hoc)"
codesign --force --sign - "$BUNDLE" >/dev/null

if [[ "${1:-}" == "--install" ]]; then
  echo "▸ Installing to /Applications"
  rm -rf "/Applications/$APP.app"
  cp -R "$BUNDLE" /Applications/
  open "/Applications/$APP.app"
else
  open "$BUNDLE"
fi

echo "✓ Done — $APP is launching."
