#!/usr/bin/env bash
# Builds SonicFlow.app into client/macos/build/ and signs it with the stable dev identity.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/build/SonicFlow.app"
identity="${SONICFLOW_SIGN_IDENTITY:-SonicFlow Dev}"
keychain="$HOME/Library/Keychains/sonicflow-dev.keychain-db"
password_file="$HOME/Library/Application Support/SonicFlow/dev-keychain.pass"

if [[ ! -f "$keychain" ]]; then
  "$root/scripts/make-dev-cert.sh"
fi

swift build --package-path "$root" -c release
bin_dir="$(swift build --package-path "$root" -c release --show-bin-path)"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin_dir/SonicFlow" "$app/Contents/MacOS/SonicFlow"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
security unlock-keychain -p "$(cat "$password_file")" "$keychain"
codesign --force --keychain "$keychain" --sign "$identity" --identifier com.sonicflow.app "$app"
echo "$app"
