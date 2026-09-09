#!/usr/bin/env bash
# Builds a Release archive and exports an App Store-ready .ipa, using the App Store Connect API
# key for signing/provisioning (no Xcode-signed-in Apple ID required). Requires ASC_KEY_ID,
# ASC_ISSUER_ID, ASC_PRIVATE_KEY_PATH (see README "App Store Connect API setup").
set -euo pipefail
cd "$(dirname "$0")/.."

: "${ASC_KEY_ID:?Set ASC_KEY_ID (see README)}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID (see README)}"
: "${ASC_PRIVATE_KEY_PATH:?Set ASC_PRIVATE_KEY_PATH (see README)}"

BUILD_NUMBER="${PLAINLAUNCH_BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
export PLAINLAUNCH_BUILD_NUMBER="$BUILD_NUMBER"

ARCHIVE_DIR="build/archive"
EXPORT_DIR="build/export"
ARCHIVE_PATH="$ARCHIVE_DIR/PlainLaunch-$BUILD_NUMBER.xcarchive"

mkdir -p "$ARCHIVE_DIR" "$EXPORT_DIR"

echo "==> xcodegen generate (build $BUILD_NUMBER)"
xcodegen generate >/dev/null

echo "==> Archiving (Release)"
xcodebuild -project PlainLaunch.xcodeproj -scheme PlainLaunch \
  -destination 'generic/platform=iOS' -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_PRIVATE_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  archive

cat > "$EXPORT_DIR/exportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>4YX4L8D7YW</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
	<key>compileBitcode</key>
	<false/>
</dict>
</plist>
PLIST

echo "==> Exporting .ipa"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_DIR/exportOptions.plist" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_PRIVATE_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

IPA_PATH=$(find "$EXPORT_DIR" -maxdepth 1 -name "*.ipa" | head -1)
echo "==> Done: $IPA_PATH (build $BUILD_NUMBER)"
echo "$IPA_PATH" > "$EXPORT_DIR/latest.txt"
