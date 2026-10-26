#!/usr/bin/env bash
# Installs or updates SonicFlow: engine dependencies, default models, the background engine
# service, and the menu-bar app. Safe to rerun after pulling changes.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "error: $*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]] || fail "SonicFlow needs an Apple Silicon Mac"
command -v uv >/dev/null || fail "uv is missing: brew install uv"
command -v swift >/dev/null || fail "Swift is missing: xcode-select --install"

echo "==> Engine dependencies"
uv sync --project "$root/engine" --all-extras --quiet

echo "==> Models"
# Env overrides, then the choice saved from Settings, then the defaults. Loading each backend
# once fills the Hugging Face cache, which the offline background service reads from.
read -r asr cleanup < <(uv run --project "$root/engine" python - <<'PY'
import os
import sys
from sonicflow.backends.registry import create_asr, create_cleanup
from sonicflow.config import load_backend_choice

saved = load_backend_choice()
asr = os.environ.get("SONICFLOW_ASR") or saved.get("asr", "parakeet-v2")
cleanup = os.environ.get("SONICFLOW_CLEANUP") or saved.get("cleanup", "qwen3-4b")
for backend in (create_asr(asr), create_cleanup(cleanup)):
    backend.load()
    print(f"    {backend.name} ready", file=sys.stderr)
print(asr, cleanup)
PY
)

[[ -n "${cleanup:-}" ]] || fail "model download failed; see the output above"

echo "==> Background engine ($asr + $cleanup)"
uv run --project "$root/engine" sonicflow-service install --asr "$asr" --cleanup "$cleanup"

echo "==> Menu-bar app"
"$root/client/macos/scripts/install.sh"

echo "Done. Hold Option in any text field to dictate; Settings live in the menu-bar icon."
