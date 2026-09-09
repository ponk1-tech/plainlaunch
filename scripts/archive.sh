#!/usr/bin/env bash
# Builds a Release archive and exports an App Store-ready .ipa.
#
# Signing is MANUAL, using a certificate + provisioning profiles created directly via the App
# Store Connect API (scripts/provisioning.sh) rather than xcodebuild's own
# -authenticationKeyPath/-allowProvisioningUpdates automatic-provisioning flow, which fails on
# this account with "Authentication failed: Make sure a bearer token was provided..." even
# though the same key works fine for every other App Store Connect API call this project makes
# (confirmed live: GET /v1/certificates and /v1/profiles both return 200 with the identical key).
# Root cause not identified; manual signing sidesteps it entirely. See docs/release.md
# "Known issue" if you want to retry automatic signing later (e.g. after an Xcode update).
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/provisioning.sh

BUILD_NUMBER="${PLAINLAUNCH_BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
export PLAINLAUNCH_BUILD_NUMBER="$BUILD_NUMBER"

ARCHIVE_DIR="build/archive"
EXPORT_DIR="build/export"
ARCHIVE_PATH="$ARCHIVE_DIR/PlainLaunch-$BUILD_NUMBER.xcarchive"

mkdir -p "$ARCHIVE_DIR" "$EXPORT_DIR"

echo "==> xcodegen generate (build $BUILD_NUMBER)"
xcodegen generate >/dev/null

echo "==> Archiving (Release, manual signing)"
xcodebuild -project PlainLaunch.xcodeproj -scheme PlainLaunch \
  -destination 'generic/platform=iOS' -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
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
	<string>manual</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>com.ponk1tech.plainlaunch</key>
		<string>PlainLaunch App Store</string>
		<key>com.ponk1tech.plainlaunch.Widget</key>
		<string>PlainLaunch Widget App Store</string>
	</dict>
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
  -exportOptionsPlist "$EXPORT_DIR/exportOptions.plist"

IPA_PATH=$(find "$EXPORT_DIR" -maxdepth 1 -name "*.ipa" | head -1)
echo "==> Done: $IPA_PATH (build $BUILD_NUMBER)"
echo "$IPA_PATH" > "$EXPORT_DIR/latest.txt"
