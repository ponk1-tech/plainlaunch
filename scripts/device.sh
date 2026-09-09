#!/usr/bin/env bash
# Builds for, installs on, and (optionally) launches PlainLaunch on whichever physical iPhone is
# currently connected and paired, auto-detected via `xcrun devicectl`. Falls back with a clear
# message if no device is available or the device needs a human action first (unlock, trust,
# Developer Mode, or a fresh USB connection to establish the developer disk image tunnel).
set -euo pipefail
cd "$(dirname "$0")/.."

ACTION="${1:-install}" # build | install | launch | logs

echo "==> Looking for a connected iOS device..."
xcrun devicectl list devices -j /tmp/plainlaunch_devices.json >/dev/null

UDID=$(python3 - <<'EOF'
import json
try:
    with open('/tmp/plainlaunch_devices.json') as f:
        data = json.load(f)
    devices = [d for d in data.get('result', {}).get('devices', []) if d.get('hardwareProperties', {}).get('platform') == 'iOS']
    if not devices:
        raise SystemExit(1)
    # Prefer a device that's actually connected (not just previously paired).
    devices.sort(key=lambda d: d.get('connectionProperties', {}).get('tunnelState') == 'connected', reverse=True)
    print(devices[0]['hardwareProperties']['udid'])
except Exception:
    raise SystemExit(1)
EOF
) || {
  echo "No paired iOS device found. Connect an iPhone via USB (or make sure it's paired over Wi-Fi) and try again." >&2
  exit 1
}

echo "    -> device UDID: $UDID"

echo "==> xcodegen generate"
xcodegen generate >/dev/null

echo "==> Building (Debug, -allowProvisioningUpdates)"
set +e
BUILD_LOG=$(xcodebuild -project PlainLaunch.xcodeproj -scheme PlainLaunch \
  -destination "id=$UDID" -configuration Debug -allowProvisioningUpdates build 2>&1)
BUILD_STATUS=$?
set -e
echo "$BUILD_LOG" | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED|could not be mounted|Developer Mode|not paired|trust" || true

if [ $BUILD_STATUS -ne 0 ]; then
  if echo "$BUILD_LOG" | grep -qi "developer disk image could not be mounted\|no DDI\|disconnected immediately"; then
    cat >&2 <<'MSG'

This device needs a human action before Xcode can install on it:
  1. Connect it to this Mac with a USB cable (not just Wi-Fi).
  2. Unlock the device and, if asked, tap "Trust This Computer".
  3. If Developer Mode isn't on yet: Settings > Privacy & Security > Developer Mode > enable,
     then let the device restart and unlock it again.
Then re-run this script.
MSG
  fi
  exit $BUILD_STATUS
fi

[ "$ACTION" = "build" ] && exit 0

APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*Debug-iphoneos/PlainLaunch.app" -maxdepth 6 2>/dev/null | head -1)
echo "==> Installing $APP_PATH"
xcrun devicectl device install app --device "$UDID" "$APP_PATH"

[ "$ACTION" = "install" ] && exit 0

echo "==> Launching"
xcrun devicectl device process launch --device "$UDID" com.ponk1tech.plainlaunch

[ "$ACTION" = "launch" ] && exit 0

echo "==> Streaming console logs (Ctrl-C to stop)"
xcrun devicectl device console --device "$UDID"
