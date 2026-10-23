#!/usr/bin/env bash
# Creates a self-signed "SonicFlow Dev" code-signing identity in its own keychain.
# A stable identity keeps macOS privacy grants (mic, Accessibility) across rebuilds; a dedicated
# keychain with a script-managed password lets codesign run without approval prompts.
set -euo pipefail

name="SonicFlow Dev"
keychain="$HOME/Library/Keychains/sonicflow-dev.keychain-db"
password_file="$HOME/Library/Application Support/SonicFlow/dev-keychain.pass"

if [[ -f "$keychain" ]] && security find-certificate -c "$name" "$keychain" >/dev/null 2>&1; then
  echo "$name already exists in $keychain"
  exit 0
fi

mkdir -p "$(dirname "$password_file")"
umask 077
openssl rand -hex 24 >"$password_file"
password="$(cat "$password_file")"

rm -f "$keychain"
security create-keychain -p "$password" "$keychain"
security set-keychain-settings "$keychain"
security unlock-keychain -p "$password" "$keychain"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
p12_password="$(openssl rand -hex 16)"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=$name" \
  -keyout "$workdir/key.pem" -out "$workdir/cert.pem" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "basicConstraints=critical,CA:false" 2>/dev/null
openssl pkcs12 -export -name "$name" -inkey "$workdir/key.pem" -in "$workdir/cert.pem" \
  -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
  -passout "pass:$p12_password" -out "$workdir/identity.p12"
security import "$workdir/identity.p12" -k "$keychain" -P "$p12_password" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" >/dev/null

# codesign only finds identities in keychains on the user search list; keep existing entries first.
existing=()
while IFS= read -r entry; do
  entry="${entry//\"/}"
  entry="${entry#"${entry%%[![:space:]]*}"}"
  [[ "$entry" == "$keychain" ]] || existing+=("$entry")
done < <(security list-keychains -d user)
security list-keychains -d user -s "${existing[@]}" "$keychain"
echo "created $name in $keychain"
