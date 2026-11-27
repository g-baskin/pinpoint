#!/bin/bash
# Builds a universal (Apple silicon + Intel) Pinpoint.app for download and zips it into dist/.
# Usage: scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."
PLIST=Resources/Info.plist
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$PLIST")"
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/Pinpoint"
for arch in arm64 x86_64; do
  lipo "$BIN" -verify_arch "$arch" || { echo "Binary is missing $arch" >&2; exit 1; }
done
APP=dist/Pinpoint.app
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pinpoint"
cp "$PLIST" "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
# Downloads are ad-hoc signed (a local certificate means nothing on other Macs). The fixed designated
# requirement lets macOS keep Screen Recording permission when people install an update.
codesign --force --deep --sign - -r="designated => identifier \"$BUNDLE_ID\"" "$APP"
codesign --verify --strict --verbose=1 "$APP"
ZIP="Pinpoint-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/$ZIP"
(cd dist && shasum -a 256 "$ZIP" > "$ZIP.sha256")
echo "Built dist/$ZIP ($(lipo -archs "$APP/Contents/MacOS/Pinpoint"))"
cat "dist/$ZIP.sha256"
