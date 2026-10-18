#!/bin/bash
# Builds build/TrashFlush.app from the Swift package. Needs Xcode or the
# Command Line Tools; no Xcode project involved.
#
# Usage: scripts/build-app.sh [release|debug]
# Env:   SIGN_IDENTITY  codesigning identity (default: first "Developer ID
#                       Application" or "Apple Development" identity found,
#                       otherwise ad hoc)
#        BUNDLE_ID      default: dev.trashflush.TrashFlush
#        VERSION        the version users see, default: 1.0.0
#        UNIVERSAL=0    build only for this Mac's architecture (faster)
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="build/TrashFlush.app"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
BUNDLE_ID="${BUNDLE_ID:-dev.trashflush.TrashFlush}"

# 1. Compile. A universal binary runs on Apple silicon and Intel Macs.
BIN_DIR="$(mktemp -d)"
if [ "${UNIVERSAL:-1}" = "1" ]; then
  for arch in arm64 x86_64; do
    swift build -c "$CONFIG" --triple "$arch-apple-macosx14.0"
    PRODUCTS="$(swift build -c "$CONFIG" --triple "$arch-apple-macosx14.0" --show-bin-path)"
    cp "$PRODUCTS/TrashFlush" "$BIN_DIR/TrashFlush-$arch"
  done
  lipo -create "$BIN_DIR"/TrashFlush-* -output "$BIN_DIR/TrashFlush"
else
  swift build -c "$CONFIG"
  PRODUCTS="$(swift build -c "$CONFIG" --show-bin-path)"
  cp "$PRODUCTS/TrashFlush" "$BIN_DIR/TrashFlush"
fi

# 2. Assemble the bundle: binary + Info.plist + icon, plus Lottie (a universal
# dynamic framework) and the resource bundle with the confetti animation.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/TrashFlush" "$APP/Contents/MacOS/TrashFlush"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/TrashFlush"
cp -R "$PRODUCTS/Lottie.framework" "$APP/Contents/Frameworks/"
cp -R "$PRODUCTS/TrashFlush_TrashFlush.bundle" "$APP/Contents/Resources/"
PLIST="$APP/Contents/Info.plist"
cp Support/Info.plist "$PLIST"
plutil -replace CFBundleShortVersionString -string "$VERSION" "$PLIST"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$PLIST"
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$PLIST"
plutil -lint "$PLIST" >/dev/null

WORK="$(mktemp -d)"
if swift scripts/make-icon.swift Support/icon-art.jpg "$WORK/icon.png"; then
  ICONSET="$WORK/TrashFlush.iconset"
  mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$WORK/icon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$WORK/icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/TrashFlush.icns"
else
  echo "warning: icon generation failed, building without an icon" >&2
fi
rm -rf "$WORK" "$BIN_DIR"

# 3. Sign. macOS remembers Full Disk Access per code signature, so a stable
# identity (Apple Development or Developer ID) keeps the permission across
# rebuilds. Ad hoc signatures change every build and need re-granting.
# Lottie is re-signed with the same identity: the hardened runtime only loads
# frameworks signed by the app's own team. Nested code is signed first.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
  | awk -F'"' '/Developer ID Application|Apple Development/ {print $2; exit}')}"
if [ -n "$IDENTITY" ] && [ "$IDENTITY" != "-" ]; then
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP/Contents/Frameworks/Lottie.framework"
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
  echo "Signed with: $IDENTITY"
else
  # An ad hoc signature is identified by the hash of this exact build, so
  # macOS would forget Accessibility and Full Disk Access on every rebuild
  # while System Settings still shows the old build as allowed. Naming the
  # bundle identifier as the requirement keeps them across rebuilds.
  codesign --force --sign - "$APP/Contents/Frameworks/Lottie.framework"
  codesign --force --sign - -r="designated => identifier \"$BUNDLE_ID\"" "$APP"
  echo "Signed ad hoc (no signing identity found)"
fi
codesign --verify --strict "$APP"

echo "Built $APP ($(du -sh "$APP" | cut -f1))"
