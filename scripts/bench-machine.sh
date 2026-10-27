#!/usr/bin/env bash
# Benchmarks the standard backend matrix twice on this Mac and prints rows for docs/LATENCY.md.
# Run after scripts/install.sh; it downloads any model in the matrix that is missing.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/bench/results/machine-$(date +%Y%m%dT%H%M%S)"
matrix=(
  "parakeet-v2 none" "parakeet-v3 none" "whisper-turbo none"
  "parakeet-v2 rules" "parakeet-v2 qwen3-1.7b" "parakeet-v2 qwen3-4b"
)

command -v jq >/dev/null || { echo "error: jq is missing: brew install jq" >&2; exit 1; }
"$root/bench/corpus/make_corpus.sh" >/dev/null
uv run --project "$root/engine" sonicflow-models download \
  parakeet-v2 parakeet-v3 whisper-turbo qwen3-1.7b qwen3-4b
mkdir -p "$out"
for combo in "${matrix[@]}"; do
  read -r asr cleanup <<<"$combo"
  for run in 1 2; do
    echo "==> $asr + $cleanup (run $run)" >&2
    uv run --project "$root/engine" sonicflow-bench --asr "$asr" --cleanup "$cleanup" --out "$out" >/dev/null
  done
done

uv run --project "$root/engine" python - "$out" <<'PY'
import json
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path

runs = defaultdict(list)
for path in sorted(Path(sys.argv[1]).glob("*.json")):
    result = json.loads(path.read_text())
    runs[(result["machine"], result["asr"], result["cleanup"])].append(result["summary"])

def span(values):
    low, high = min(values), max(values)
    return f"{low:.0f}" if round(low) == round(high) else f"{low:.0f}–{high:.0f}"

print("| Date | Machine | ASR | Cleanup | release→text p50 / p95 | WER raw | WER clean |")
print("|---|---|---|---|---|---|---|")
for (machine, asr, cleanup), summaries in runs.items():
    p50 = span([s["release_to_text_ms"]["p50"] for s in summaries])
    p95 = span([s["release_to_text_ms"]["p95"] for s in summaries])
    raw = summaries[0]["wer_raw_vs_spoken"] * 100
    clean = summaries[0]["wer_text_vs_clean"] * 100
    print(f"| {date.today()} | {machine} | {asr} | {cleanup} | {p50} / {p95} ms | {raw:.1f}% | {clean:.1f}% |")
PY
