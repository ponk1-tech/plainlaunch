#!/usr/bin/env bash
# Captures App Store screenshots (6.9" class, 1320x2868 — Apple's single required iPhone size as
# of 2026; it auto-scales down for smaller devices) for both supported locales, using the
# in-app tabs (About / Widget guide / Test / Customize-with-live-widget-preview). These are real
# app UI, not mockups: the Customize tab's preview renders through the exact same WidgetRowsView
# code the actual widget uses.
#
# Usage: scripts/screenshots.sh [simulator-name]
set -euo pipefail
cd "$(dirname "$0")/.."

SIM_NAME="${1:-iPhone 17 Pro Max}"
BUNDLE_ID="com.ponk1tech.plainlaunch"
OUT_ROOT="AppStore/screenshots"

echo "==> Resolving simulator: $SIM_NAME"
DEV_ID=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
data = json.load(sys.stdin)['devices']
for runtime, devices in data.items():
    for d in devices:
        if d['name'] == '$SIM_NAME':
            print(d['udid'])
            sys.exit(0)
sys.exit(1)
")
echo "    -> $DEV_ID"

xcrun simctl bootstatus "$DEV_ID" -b >/dev/null 2>&1 || true

echo "==> xcodegen generate"
xcodegen generate >/dev/null

echo "==> Building for simulator"
xcodebuild -project PlainLaunch.xcodeproj -scheme PlainLaunch \
  -destination "id=$DEV_ID" -configuration Debug build \
  | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" || true

APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*Debug-iphonesimulator/PlainLaunch.app" -maxdepth 6 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
  echo "Could not locate built PlainLaunch.app" >&2
  exit 1
fi

xcrun simctl install "$DEV_ID" "$APP_PATH"

capture() {
  local locale_dir="$1" tab="$2" extra_args="${3:-}"
  mkdir -p "$OUT_ROOT/$locale_dir"
  xcrun simctl terminate "$DEV_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 1
  # shellcheck disable=SC2086
  xcrun simctl launch "$DEV_ID" "$BUNDLE_ID" -QATab "$tab" $extra_args >/dev/null
  sleep 2
  xcrun simctl io "$DEV_ID" screenshot "$OUT_ROOT/$locale_dir/tab$tab.png" >/dev/null
}

echo "==> Capturing ja screenshots"
for tab in 0 1 2 3; do capture ja "$tab" ""; done

echo "==> Capturing en screenshots"
for tab in 0 1 2 3; do capture en "$tab" '-AppleLanguages "(en)" -AppleLocale en_US'; done

xcrun simctl terminate "$DEV_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true

echo "==> Done. Screenshots in $OUT_ROOT/{ja,en}/tab{0-3}.png"
echo "    tab0=About  tab1=Widget guide  tab2=Test  tab3=Customize (shows live widget preview)"
