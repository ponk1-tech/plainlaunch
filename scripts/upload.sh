#!/usr/bin/env bash
# Validates or uploads the most recently exported .ipa (from scripts/archive.sh) to App Store
# Connect, using altool's API-key authentication (reads the key from
# ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8 by Apple's own default-location
# convention, or ASC_PRIVATE_KEY_PATH if that's elsewhere).
set -euo pipefail
cd "$(dirname "$0")/.."

ACTION="${1:?Usage: upload.sh [validate|upload]}"
: "${ASC_KEY_ID:?Set ASC_KEY_ID (see README)}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID (see README)}"

EXPORT_DIR="build/export"
if [ ! -f "$EXPORT_DIR/latest.txt" ]; then
  echo "No exported .ipa found. Run 'make archive' first." >&2
  exit 1
fi
IPA_PATH=$(cat "$EXPORT_DIR/latest.txt")

# altool looks for ~/.appstoreconnect/private_keys/AuthKey_<id>.p8 automatically; if
# ASC_PRIVATE_KEY_PATH points elsewhere, stage a symlink there so --api-key just works.
DEFAULT_KEY_DIR="$HOME/.appstoreconnect/private_keys"
DEFAULT_KEY_PATH="$DEFAULT_KEY_DIR/AuthKey_${ASC_KEY_ID}.p8"
if [ -n "${ASC_PRIVATE_KEY_PATH:-}" ] && [ ! -f "$DEFAULT_KEY_PATH" ]; then
  mkdir -p "$DEFAULT_KEY_DIR"
  ln -s "$ASC_PRIVATE_KEY_PATH" "$DEFAULT_KEY_PATH"
fi

case "$ACTION" in
  validate)
    echo "==> Validating $IPA_PATH"
    xcrun altool --validate-app -f "$IPA_PATH" -t ios \
      --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
    ;;
  upload)
    echo "==> Uploading $IPA_PATH"
    xcrun altool --upload-app -f "$IPA_PATH" -t ios \
      --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
    ;;
  *)
    echo "Unknown action: $ACTION (expected validate|upload)" >&2
    exit 1
    ;;
esac
