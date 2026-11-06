#!/usr/bin/env bash
# Puts the signing identity from SIGNING_CERTIFICATE_P12 (base64) and SIGNING_CERTIFICATE_PASSWORD into
# a throwaway keychain, so codesign can use it without a password prompt. Used by the release workflow.
#
#   KEYCHAIN_DIR=<dir> scripts/import-identity.sh
set -euo pipefail

test -n "${SIGNING_CERTIFICATE_P12:-}" && test -n "${SIGNING_CERTIFICATE_PASSWORD:-}" || {
  echo "SIGNING_CERTIFICATE_P12 and SIGNING_CERTIFICATE_PASSWORD must be set." >&2
  exit 1
}

DIR="${KEYCHAIN_DIR:-${RUNNER_TEMP:-$(mktemp -d)}}"
KEYCHAIN="$DIR/task-coach-signing.keychain-db"
PASS="$(/usr/bin/openssl rand -base64 18)"

security create-keychain -p "$PASS" "$KEYCHAIN"
security set-keychain-settings -lut 3600 "$KEYCHAIN"
security unlock-keychain -p "$PASS" "$KEYCHAIN"
printf '%s' "$SIGNING_CERTIFICATE_P12" | base64 --decode > "$DIR/identity.p12"
security import "$DIR/identity.p12" -k "$KEYCHAIN" -P "$SIGNING_CERTIFICATE_PASSWORD" -T /usr/bin/codesign >/dev/null
rm "$DIR/identity.p12"
# Let codesign use the key without asking.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASS" "$KEYCHAIN" >/dev/null
# Add it to the search list, keeping the existing keychains.
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')
echo "$KEYCHAIN"
