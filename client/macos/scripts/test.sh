#!/usr/bin/env bash
# Command Line Tools ship the Swift Testing macro plugin outside the default search path.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
plugins="$(xcode-select -p)/usr/lib/swift/host/plugins/testing"
if [[ -d "$plugins" ]]; then
  swift test --package-path "$root" -Xswiftc -plugin-path -Xswiftc "$plugins"
else
  swift test --package-path "$root"
fi
