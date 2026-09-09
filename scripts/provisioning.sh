#!/usr/bin/env bash
# Ensures Development + Distribution signing identities (certificate + private key, in a
# dedicated local keychain) and both Debug (device) and Release (App Store) provisioning
# profiles for both bundle IDs exist, creating them via the App Store Connect API if not.
# Idempotent: safe to run before every build/archive.
#
# Why manual signing at all, instead of xcodebuild's own -authenticationKeyPath/
# -allowProvisioningUpdates automatic-provisioning flow: that flow fails on this account with
# "Authentication failed: Make sure a bearer token was provided..." even though the identical
# key works for every other App Store Connect API call this project makes (confirmed live: GET
# /v1/certificates and /v1/profiles both return 200). Root cause not identified — it may be that
# Xcode's automatic-signing path talks to a different (undocumented) Developer Portal protocol
# with different requirements than the public API. Manual signing, built entirely on the public,
# documented API, sidesteps it.
#
# Why a dedicated keychain instead of the login keychain: importing a raw-key-derived .p12 into
# the login keychain via `security import` failed in this (non-interactive, no WindowServer
# session) environment with "User interaction is not allowed" — macOS wants to show a trust
# confirmation dialog that can't be shown here. A freshly created, explicitly unlocked keychain
# doesn't trigger that dialog and works non-interactively; it's added to the user's keychain
# search list so codesign finds it like any other.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${ASC_KEY_ID:?Set ASC_KEY_ID (see README)}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID (see README)}"
: "${ASC_PRIVATE_KEY_PATH:?Set ASC_PRIVATE_KEY_PATH (see README)}"

APP_BUNDLE_ID_RESOURCE="3K468ZZZNM"       # com.ponk1tech.plainlaunch
WIDGET_BUNDLE_ID_RESOURCE="86S6H7V487"    # com.ponk1tech.plainlaunch.Widget
CERTS_DIR="build/certs"
KEYCHAIN_PATH="$HOME/Library/Keychains/plainlaunch-build.keychain-db"
PROFILES_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"

mkdir -p "$CERTS_DIR" "$PROFILES_DIR"

api() {
  local method="$1" path="$2" data_file="${3:-}"
  local jwt
  jwt=$(node scripts/asc_jwt.js)
  if [ -n "$data_file" ]; then
    curl -sS --globoff -X "$method" -H "Authorization: Bearer $jwt" -H "Content-Type: application/json" \
      -d @"$data_file" "https://api.appstoreconnect.apple.com/v1$path"
  else
    curl -sS --globoff -H "Authorization: Bearer $jwt" "https://api.appstoreconnect.apple.com/v1$path"
  fi
}

ensure_keychain() {
  if [ ! -f "$KEYCHAIN_PATH" ]; then
    local kc_pass="build-$(openssl rand -hex 8)"
    security create-keychain -p "$kc_pass" "$KEYCHAIN_PATH"
    security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
    echo "$kc_pass" > "$CERTS_DIR/keychain_password.txt"
    chmod 600 "$CERTS_DIR/keychain_password.txt"
  fi
  security unlock-keychain -p "$(cat "$CERTS_DIR/keychain_password.txt")" "$KEYCHAIN_PATH"
  local existing_list
  existing_list=$(security list-keychains -d user | sed 's/"//g' | xargs)
  case " $existing_list " in
    *" $KEYCHAIN_PATH "*) : ;;
    *) security list-keychains -d user -s $existing_list "$KEYCHAIN_PATH" ;;
  esac
}

# ensure_certificate CERT_TYPE(DEVELOPMENT|IOS_DISTRIBUTION) LABEL
# Prints the certificate resource id to stdout (and only that, so callers can capture it).
#
# The App Store Connect API's GET /v1/certificates for this key returns certificates from more
# than one team (confirmed live: a DEVELOPMENT-type query returned both this project's own
# "Created via API" cert *and* an unrelated personal-team "Gun Kobayashi" cert, even though this
# key is a Ponk1 Tech team key) — so "does a cert of this type exist" can't be answered safely by
# just taking the first result. Instead, the id of whichever cert *this script* created is cached
# locally (build/certs/<label>.cert_id) and treated as the source of truth; only a fresh
# environment with no cache falls back to creating a brand new certificate.
ensure_certificate() {
  local cert_type="$1" label="$2"
  local key_file="$CERTS_DIR/${label}.key"
  local csr_file="$CERTS_DIR/${label}.csr"
  local cer_file="$CERTS_DIR/${label}.cer"
  local id_file="$CERTS_DIR/${label}.cert_id"

  local cert_id=""
  if [ -f "$id_file" ]; then
    local cached_id
    cached_id=$(cat "$id_file")
    if api GET "/certificates/$cached_id" | python3 -c "import json,sys; sys.exit(0 if 'data' in json.load(sys.stdin) else 1)" 2>/dev/null; then
      cert_id="$cached_id"
    fi
  fi

  if [ -z "$cert_id" ]; then
    openssl genrsa -out "$key_file" 2048 >/dev/null 2>&1
    openssl req -new -key "$key_file" -out "$csr_file" -subj "/CN=Ponk1 Tech ${label}/O=Ponk1 Tech/C=JP" >/dev/null 2>&1
    python3 -c "
import json
print(json.dumps({'data': {'type': 'certificates', 'attributes': {
  'csrContent': open('$csr_file').read(), 'certificateType': '$cert_type'}}}))
" > /tmp/plainlaunch_cert_payload.json
    local response
    response=$(api POST "/certificates" /tmp/plainlaunch_cert_payload.json)
    cert_id=$(echo "$response" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['id'])")
    echo "$response" | python3 -c "
import json, sys, base64
d = json.load(sys.stdin)['data']
open('$cer_file', 'wb').write(base64.b64decode(d['attributes']['certificateContent']))
"
    openssl x509 -inform DER -in "$cer_file" -out "$CERTS_DIR/${label}.pem"
    local p12_pass="temp-$(openssl rand -hex 8)"
    openssl pkcs12 -export -inkey "$key_file" -in "$CERTS_DIR/${label}.pem" -out "$CERTS_DIR/${label}.p12" \
      -passout "pass:$p12_pass" -legacy -macalg sha1 -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES >/dev/null 2>&1
    security import "$CERTS_DIR/${label}.p12" -k "$KEYCHAIN_PATH" -P "$p12_pass" \
      -T /usr/bin/codesign -T /usr/bin/security -A >&2
    echo "$cert_id" > "$id_file"
    echo "    created $cert_type certificate $cert_id and imported into $KEYCHAIN_PATH" >&2
  else
    echo "    reusing existing $cert_type certificate $cert_id (cached in $id_file)" >&2
  fi

  echo "$cert_id"
}

# ensure_profile PROFILE_TYPE(IOS_APP_STORE|IOS_APP_DEVELOPMENT) BUNDLE_ID_RESOURCE PROFILE_NAME CERT_ID
ensure_profile() {
  local profile_type="$1" bundle_id_resource="$2" profile_name="$3" cert_id="$4"
  echo "==> Ensuring profile '$profile_name'..."
  local existing
  existing=$(api GET "/bundleIds/$bundle_id_resource/profiles" | python3 -c "
import json, sys
d = json.load(sys.stdin)
matches = [p for p in d.get('data', []) if p['attributes']['name'] == '$profile_name' and p['attributes']['profileState'] == 'ACTIVE']
print(matches[0]['id'] if matches else '')
")
  local profile_id
  if [ -n "$existing" ]; then
    profile_id="$existing"
    echo "    already exists ($profile_id), refreshing local copy"
  else
    local device_ids="[]"
    if [ "$profile_type" = "IOS_APP_DEVELOPMENT" ]; then
      # Development profiles must list specific devices. Register every ENABLED device already
      # on this team's account (the App Store Connect API has no endpoint to auto-register a
      # device from a UDID typed by a human here — that step, if a *new* device is ever needed,
      # is the one place this script can't avoid Xcode/Developer Portal doing it first).
      device_ids=$(api GET "/devices?filter[status]=ENABLED&limit=200" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(json.dumps([{'type': 'devices', 'id': x['id']} for x in d.get('data', [])]))
")
    fi
    python3 -c "
import json
rel = {
  'bundleId': {'data': {'type': 'bundleIds', 'id': '$bundle_id_resource'}},
  'certificates': {'data': [{'type': 'certificates', 'id': '$cert_id'}]},
}
devices = json.loads('''$device_ids''')
if devices:
    rel['devices'] = {'data': devices}
print(json.dumps({'data': {'type': 'profiles', 'attributes': {'name': '$profile_name', 'profileType': '$profile_type'},
  'relationships': rel}}))
" > /tmp/plainlaunch_profile_payload.json
    local response
    response=$(api POST "/profiles" /tmp/plainlaunch_profile_payload.json)
    profile_id=$(echo "$response" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d['data']['id'] if 'data' in d else '')
" )
    if [ -z "$profile_id" ]; then
      echo "    FAILED:"
      echo "$response" | python3 -m json.tool >&2
      return 1
    fi
    echo "    created ($profile_id)"
  fi

  api GET "/profiles/$profile_id" | python3 -c "
import json, sys, base64
d = json.load(sys.stdin)['data']
uuid = d['attributes']['uuid']
path = '$PROFILES_DIR/' + uuid + '.mobileprovision'
open(path, 'wb').write(base64.b64decode(d['attributes']['profileContent']))
print('    installed to', path)
"
}

echo "==> Ensuring local signing keychain..."
ensure_keychain

echo "==> Ensuring Distribution certificate..."
DIST_CERT_ID=$(ensure_certificate IOS_DISTRIBUTION distribution)

echo "==> Ensuring Development certificate..."
DEV_CERT_ID=$(ensure_certificate DEVELOPMENT development)

ensure_profile IOS_APP_STORE "$APP_BUNDLE_ID_RESOURCE" "PlainLaunch App Store" "$DIST_CERT_ID"
ensure_profile IOS_APP_STORE "$WIDGET_BUNDLE_ID_RESOURCE" "PlainLaunch Widget App Store" "$DIST_CERT_ID"
ensure_profile IOS_APP_DEVELOPMENT "$APP_BUNDLE_ID_RESOURCE" "PlainLaunch Debug" "$DEV_CERT_ID"
ensure_profile IOS_APP_DEVELOPMENT "$WIDGET_BUNDLE_ID_RESOURCE" "PlainLaunch Widget Debug" "$DEV_CERT_ID"

echo "==> Provisioning ready."
