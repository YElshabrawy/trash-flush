#!/bin/bash
# Packages Trash Flush as a drag-to-install disk image:
# build/TrashFlush-<version>.dmg, plus its SHA-256 checksum.
#
# Usage: scripts/make-dmg.sh
# Env:   SKIP_BUILD=1       package the existing build/TrashFlush.app as is
#        LAYOUT=0           skip the Finder window layout (background, icon
#                           positions). It drives Finder with AppleScript, which
#                           asks for Automation permission the first time.
#        NOTARY_PROFILE     a `notarytool` keychain profile. With a Developer ID
#                           certificate, notarizes and staples the DMG.
#
# Without a Developer ID certificate the app is signed ad hoc: it works, but
# macOS blocks the first launch until the user allows it in System Settings.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/TrashFlush.app"
VOLUME="Trash Flush"
DEVELOPER_ID="$(security find-identity -v -p codesigning 2>/dev/null \
  | awk -F'"' '/Developer ID Application/ {print $2; exit}')"

# 1. Build. A Developer ID signature is the one Gatekeeper accepts, so prefer it.
if [ "${SKIP_BUILD:-0}" != "1" ]; then
  if [ -n "$DEVELOPER_ID" ]; then
    SIGN_IDENTITY="${SIGN_IDENTITY:-$DEVELOPER_ID}" scripts/build-app.sh release
  else
    scripts/build-app.sh release
  fi
fi
[ -d "$APP" ] || { echo "error: $APP not found" >&2; exit 1; }

VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
DMG="build/TrashFlush-$VERSION.dmg"

WORK="$(mktemp -d)"
MOUNT=""
cleanup() {
  [ -n "$MOUNT" ] && hdiutil detach "$MOUNT" -quiet -force 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# 2. Stage the contents: the app, a link to /Applications and the background.
STAGE="$WORK/stage"
mkdir -p "$STAGE/.background"
ditto "$APP" "$STAGE/Trash Flush.app"
ln -s /Applications "$STAGE/Applications"
swift scripts/make-dmg-background.swift "$STAGE/.background/background.png" >/dev/null
sips -s dpiWidth 144 -s dpiHeight 144 "$STAGE/.background/background.png" >/dev/null

# 3. Make a writable image and lay out its Finder window. Finder saves the
# layout in the volume's .DS_Store, which ships inside the DMG.
if [ -d "/Volumes/$VOLUME" ]; then hdiutil detach "/Volumes/$VOLUME" -quiet -force || true; fi
hdiutil create -quiet -volname "$VOLUME" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$WORK/rw.dmg"
MOUNT="$(hdiutil attach "$WORK/rw.dmg" -readwrite -noverify -noautoopen | awk -F'\t' '/Apple_HFS/ {print $NF}')"

if [ "${LAYOUT:-1}" = "1" ]; then
  # perl's alarm is a timeout: never hang on a permission prompt nobody answers.
  if ! perl -e 'alarm shift; exec @ARGV' 60 osascript >/dev/null <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, 860, 548}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.png"
    set position of item "Trash Flush.app" of container window to {170, 190}
    set position of item "Applications" of container window to {490, 190}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT
  then
    echo "warning: couldn't lay out the Finder window (Automation permission?). The DMG works, just plainer." >&2
  fi
fi
rm -rf "$MOUNT/.fseventsd" "$MOUNT/.Trashes"
chmod -Rf go-w "$MOUNT" || true
sync
hdiutil detach "$MOUNT" -quiet
MOUNT=""

# 4. Compress into the final read-only image.
rm -f "$DMG"
hdiutil convert -quiet "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG"

# 5. With a Developer ID: sign the DMG, then notarize and staple it so it opens
# without warnings, even offline.
if [ -n "$DEVELOPER_ID" ]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
  if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature -v "$DMG"
  else
    echo "note: set NOTARY_PROFILE to notarize (see README › Releasing)." >&2
  fi
else
  echo "note: no Developer ID certificate, so the app is signed ad hoc and not notarized." >&2
fi

hdiutil verify -quiet "$DMG"
(cd build && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "Built $DMG ($(du -h "$DMG" | cut -f1))"
cat "$DMG.sha256"
