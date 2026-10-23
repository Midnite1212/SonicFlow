# Latency Budget

Measured from hotkey release to final text available to the client.

| Path | p50 | p95 |
|---|---|---|
| Raw transcript (no cleanup) | < 150 ms | < 300 ms |
| With LLM cleanup | < 500 ms | < 900 ms |

Accuracy floor: corpus WER (raw vs spoken) ≤ 5% on the synthetic corpus; re-baseline once personal recordings exist.

## How it's measured

`sonicflow-bench` feeds each corpus file through `ASRStream` in 100 ms chunks and times `finalize()` + `clean()` — the same calls the server makes after `stop`. Use `--realtime` for streaming backends so they get the same head start they would have live. Every run writes `bench/results/<timestamp>-<asr>-<cleanup>.json` with the machine name.

| Metric | Meaning |
|---|---|
| `release_to_text_ms` | `finalize` + `cleanup`; the number the budget applies to |
| `finalize_ms` | ASR work left after release |
| `cleanup_ms` | LLM work left after release |
| `rtf` | Total ASR compute ÷ audio duration (lower is better) |
| `load_ms` | Startup cost; doesn't count against the budget |
| `wer_raw_vs_spoken` | ASR accuracy |
| `wer_text_vs_clean` | End-to-end output vs the ideal cleaned text |

## Results

| Date | Machine | ASR | Cleanup | release→text p50 / p95 | WER raw | WER clean |
|---|---|---|---|---|---|---|
| 2026-10-23 | Apple M3 Pro | parakeet-v2 | none | 110–111 / 181–213 ms | 7.1% | — |
| 2026-10-23 | Apple M3 Pro | parakeet-v3 | none | 115–125 / 195–217 ms | 8.2% | — |

Ranges span two runs with warm models; load is ~1.2 s once cached. Synthetic-corpus WER over-counts number and compound formatting ("ten thirty" vs "10.30", "standup" vs "stand up"), so the absolute figures are pessimistic; the v2/v3 gap is real ("write path" → "right path" in both, extra misses in v3).
