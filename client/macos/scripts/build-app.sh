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
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
# SwiftPM stamps the deployment target as the SDK version, which makes macOS 26 draw the app in its
# compatibility look; stamp the real SDK so the window gets the current sidebar and toolbar.
vtool -set-build-version macos 14.0 "$(xcrun --show-sdk-version)" -replace \
  -output "$app/Contents/MacOS/SonicFlow" "$bin_dir/SonicFlow"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"

iconset="$root/build/AppIcon.iconset"
rm -rf "$iconset" && mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z $size $size "$root/Resources/AppIcon.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$root/Resources/AppIcon.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
security unlock-keychain -p "$(cat "$password_file")" "$keychain"
codesign --force --keychain "$keychain" --sign "$identity" --identifier com.sonicflow.app "$app"
echo "$app"
