---
name: bench
description: Run the SonicFlow latency and WER benchmark for one or more ASR/cleanup backends, compare against the previous result on this machine, and record the outcome. USE WHEN bench, benchmark, which is faster, compare backends, latency check, regression check, after changing engine or backend code.
---

# Bench

1. Make sure audio exists: `ls bench/corpus/audio/*.wav` — if not, run `bench/corpus/make_corpus.sh`.
2. Find the baseline: the newest file in `bench/results/` with the same `asr`, `cleanup` and `machine` (`jq -r .machine`). The machine matters; never compare M3 Pro against M4 Max numbers.
3. Run from `engine/`:
   ```sh
   uv run sonicflow-bench --asr <asr> --cleanup <cleanup> [--realtime] [--baseline <file>]
   ```
   Use `--realtime` for backends whose `stream()` does real streaming work; batch backends gain nothing from it.
4. Report one table row per run: machine, asr, cleanup, release→text p50/p95, rtf, WER raw, WER clean, load ms. Flag anything outside the budget in `docs/LATENCY.md`.
5. If `--baseline` exits non-zero, the change regressed latency beyond 10%: say so plainly with both numbers; don't re-run until it passes.
6. When a result settles a decision (new default, backend dropped), add the row to the Results table in `docs/LATENCY.md`.

Never paste per-item transcripts from `bench/corpus/personal/` into chat, docs, or commits.
