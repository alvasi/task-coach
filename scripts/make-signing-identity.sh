#!/usr/bin/env bash
# Creates the self-signed code-signing identity that every Task Coach release is signed with.
# Run it once. Keep the output folder private and backed up: losing it means the next release
# looks like a different app to macOS (permissions reset), and the installer's signature check fails.
#
#   scripts/make-signing-identity.sh [output-dir]     (default: ~/.task-coach-signing)
#
# It's not an Apple Developer ID, so Gatekeeper still doesn't vouch for the app. It gives releases a
# stable identity, so macOS keeps permissions across updates and the installer can check the download.
set -euo pipefail

NAME="Task Coach Self-Signed"
OUT="${1:-$HOME/.task-coach-signing}"
OPENSSL=/usr/bin/openssl   # LibreSSL: its .p12 defaults are ones macOS's `security import` accepts

if [[ -e "$OUT/identity.p12" ]]; then
  echo "An identity already exists in $OUT. Remove it first if you really want a new one." >&2
  exit 1
fi
mkdir -p "$OUT"
chmod 700 "$OUT"

cat > "$OUT/cert.conf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

"$OPENSSL" req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$OUT/key.pem" -out "$OUT/cert.pem" -config "$OUT/cert.conf" 2>/dev/null

PASSWORD="$("$OPENSSL" rand -base64 24)"
printf '%s' "$PASSWORD" > "$OUT/password.txt"
"$OPENSSL" pkcs12 -export -inkey "$OUT/key.pem" -in "$OUT/cert.pem" \
  -name "$NAME" -out "$OUT/identity.p12" -passout "pass:$PASSWORD"
chmod 600 "$OUT"/*

echo "Created \"$NAME\" in $OUT (valid 10 years)."
echo
echo "To let GitHub sign releases with it, store it as two repository secrets:"
echo "  base64 -i \"$OUT/identity.p12\" | gh secret set SIGNING_CERTIFICATE_P12 -R <owner>/task-coach"
echo "  gh secret set SIGNING_CERTIFICATE_PASSWORD -R <owner>/task-coach < \"$OUT/password.txt\""
