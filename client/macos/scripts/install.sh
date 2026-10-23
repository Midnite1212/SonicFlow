#!/usr/bin/env bash
# Builds the app, replaces ~/Applications/SonicFlow.app, and launches it.
set -euo pipefail

scripts="$(cd "$(dirname "$0")" && pwd)"
target="$HOME/Applications/SonicFlow.app"

"$scripts/build-app.sh"
pkill -x SonicFlow 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$target"
cp -R "$scripts/../build/SonicFlow.app" "$target"
open "$target"
echo "launched $target"
