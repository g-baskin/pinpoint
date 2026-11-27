#!/bin/bash
# Builds build/Pinpoint.app (release, signed). Usage: scripts/build-app.sh [--install]
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
BIN="$(swift build -c release --show-bin-path)/Pinpoint"
APP=build/Pinpoint.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Pinpoint"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"
# Use a real signing identity if one exists (keeps the Screen Recording permission across rebuilds); else ad-hoc.
# Prefer a real Apple identity; else the local "Pinpoint Local Signing" cert (scripts/setup-signing.sh); else ad-hoc.
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')"
if [ -z "$IDENTITY" ]; then
  IDENTITY="$(security find-identity -p codesigning 2>/dev/null | awk '/"Pinpoint Local Signing"/ {print $2; exit}')"
fi
if [ -z "$IDENTITY" ]; then
  # Certificate made before the rename; re-run scripts/setup-signing.sh to replace it.
  IDENTITY="$(security find-identity -p codesigning 2>/dev/null | awk '/"Zoomies Local Signing"/ {print $2; exit}')"
fi
if [ -n "$IDENTITY" ]; then
  codesign --force --deep --sign "$IDENTITY" "$APP"
else
  # Ad-hoc, but with a fixed designated requirement (bundle id) instead of the per-build hash,
  # so macOS keeps Screen Recording permission across rebuilds.
  codesign --force --deep --sign - -r='designated => identifier "app.pinpoint.Pinpoint"' "$APP"
fi
echo "Built $APP (signed with: ${IDENTITY:-ad-hoc})"
du -sh "$APP"
if [ "${1:-}" = "--install" ]; then
  mkdir -p "$HOME/Applications"
  # The app used to be called Zoomies: move the old copy to the Trash so there's only one.
  if [ -d "$HOME/Applications/Zoomies.app" ]; then mv "$HOME/Applications/Zoomies.app" "$HOME/.Trash/Zoomies-old-$(date +%s).app"; fi
  rm -rf "$HOME/Applications/Pinpoint.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "Installed to ~/Applications/Pinpoint.app"
fi
