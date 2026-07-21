#!/usr/bin/env bash
#
# Capture App Store screenshots for CardOnCue on the sizes App Store Connect requires.
#
#   ./scripts/capture-screenshots.sh
#
# Output: ./Screenshots/<size>/NN-<name>.png   (gitignored)
#
# Requires the iOS platform installed:  xcodebuild -downloadPlatform iOS
# The Watch app additionally needs:      xcodebuild -downloadPlatform watchOS
#
# The app ships a DEBUG-only demo seeder (see DemoDataSeeder in CardOnCueApp.swift) that
# inserts 8 realistic cards and marks onboarding complete, so the card list is populated.
# This script enables it by writing the CardOnCueSeedDemoData key straight into the app's
# sandboxed preferences plist — `simctl spawn defaults write` and SIMCTL_CHILD_ env vars
# both proved unreliable. Verify it ran by reading:
#   <app data container>/Documents/demo-seed-result.txt
#
# Screens beyond the card list (barcode detail, scanner) still need a human to tap
# through; re-run with SKIP_RESET=1 to keep the state you navigated to.

set -euo pipefail

BUNDLE_ID="com.nathanfennel.CardOnCue"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/Screenshots"
RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-26-5"
SKIP_RESET="${SKIP_RESET:-0}"

# name|device type identifier|output folder
DEVICES=(
  "CardOnCue-iPhone69|com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max|iphone-6.9"
  "CardOnCue-iPad13|com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-16GB|ipad-13"
)

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

command -v xcrun >/dev/null || die "xcrun not found"
xcrun simctl list runtimes 2>/dev/null | grep -q "iOS 26.5" \
  || die "iOS 26.5 runtime missing. Run: xcodebuild -downloadPlatform iOS"

log "Building CardOnCue for the simulator"
xcodebuild -project "$ROOT/CardOnCue.xcodeproj" \
  -scheme CardOnCue \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  -derivedDataPath "$ROOT/build/screenshots-dd" \
  build >/dev/null || die "build failed"

APP="$(find "$ROOT/build/screenshots-dd" -name 'CardOnCue.app' -path '*iphonesimulator*' | head -1)"
[ -n "$APP" ] || die "could not locate built CardOnCue.app"
log "Built: $APP"

for entry in "${DEVICES[@]}"; do
  IFS='|' read -r NAME TYPE FOLDER <<< "$entry"
  mkdir -p "$OUT/$FOLDER"

  UDID="$(xcrun simctl list devices -j | python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
print(next((x['udid'] for v in d.values() for x in v if x['name']=='$NAME'), ''))
")"

  if [ -z "$UDID" ]; then
    log "Creating simulator $NAME"
    UDID="$(xcrun simctl create "$NAME" "$TYPE" "$RUNTIME")"
  elif [ "$SKIP_RESET" != "1" ]; then
    log "Resetting $NAME to a clean state"
    xcrun simctl shutdown "$UDID" 2>/dev/null || true
    xcrun simctl erase "$UDID"
  fi

  log "Booting $NAME ($UDID)"
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null

  # Keep the device alive; headless devices can be reaped mid-session.
  open -a Simulator --args -CurrentDeviceUDID "$UDID"
  sleep 5

  log "Installing"
  xcrun simctl install "$UDID" "$APP"

  # Enable the DEBUG-only demo seeder by writing directly into the app's sandboxed
  # preferences plist. The container only exists after install.
  DEVDIR="$HOME/Library/Developer/CoreSimulator/Devices/$UDID"
  CONTAINER=""
  for d in "$DEVDIR"/data/Containers/Data/Application/*/; do
    META="$d.com.apple.mobile_container_manager.metadata.plist"
    if [ -f "$META" ] && plutil -p "$META" 2>/dev/null | grep -q "$BUNDLE_ID"; then
      CONTAINER="$d"
    fi
  done

  if [ -n "$CONTAINER" ]; then
    PLIST="$CONTAINER/Library/Preferences/$BUNDLE_ID.plist"
    mkdir -p "$CONTAINER/Library/Preferences"
    [ -f "$PLIST" ] || plutil -create xml1 "$PLIST" 2>/dev/null
    plutil -replace CardOnCueSeedDemoData -bool YES "$PLIST" 2>/dev/null \
      && log "Demo seeding enabled"
  else
    log "WARNING: app container not found; launching without demo data"
  fi

  log "Launching"
  xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
  sleep 10

  if [ -n "$CONTAINER" ] && [ -f "$CONTAINER/Documents/demo-seed-result.txt" ]; then
    log "Seeder: $(cat "$CONTAINER/Documents/demo-seed-result.txt")"
  fi

  log "Capturing $FOLDER/01-launch.png"
  xcrun simctl io "$UDID" screenshot "$OUT/$FOLDER/01-launch.png" >/dev/null 2>&1

  cat <<EOF

  $NAME is now running CardOnCue.
  Tap through to each screen you want, and capture with:

      xcrun simctl io $UDID screenshot "$OUT/$FOLDER/02-cards.png"
      xcrun simctl io $UDID screenshot "$OUT/$FOLDER/03-barcode.png"

EOF
done

log "Done. Screenshots in $OUT (gitignored)."
