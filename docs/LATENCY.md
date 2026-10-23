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
| 2026-10-23 | Apple M3 Pro | whisper-turbo | none | 595–602 / 712–721 ms | 8.8% | — |
| 2026-10-23 | Apple M3 Pro | parakeet-v2 | none | (same runs as above) | 7.1% | 15.8% |
| 2026-10-23 | Apple M3 Pro | parakeet-v2 | rules | 107–115 / 182–186 ms | 7.1% | 12.0% |
| 2026-10-23 | Apple M3 Pro | parakeet-v2 | qwen3-1.7b | 112–114 / 275–303 ms | 7.1% | 5.7% |
| 2026-10-23 | Apple M3 Pro | parakeet-v2 | qwen3-4b | 127–128 / 459–469 ms | 7.1% | 5.1% |

Ranges span two runs with warm models; load is ~1.2 s once cached. Synthetic-corpus WER over-counts number and compound formatting ("ten thirty" vs "10.30", "standup" vs "stand up"), so the absolute figures are pessimistic; the v2/v3 gap is real ("write path" → "right path" in both, extra misses in v3). Whisper pads every input to a 30 s window, so its cost is ~580 ms even for a 2 s clip; it drops some fillers on its own and formats identifiers and sentences better, but misses the raw budget.

LLM cleanup only runs on the 4 items `needs_llm()` flags, so its cost shows at p95: per rewrite, qwen3-1.7b takes 129–173 ms and qwen3-4b 230–353 ms on top of ASR. Both resolve all three self-corrections; only 4B also drops the ambiguous "like". Both drop a leading "Let's" in "Let's ship it on Friday, no wait, Thursday".

### Idle penalty

After ~30 s without dictation the first utterance used to cost 360–873 ms end to end (parakeet-v2 + qwen3-1.7b, live WebSocket, 4 idle cycles) against ~260–290 ms back to back. The engine now runs a short ASR and LLM warm-up on `start`, while the user is still speaking; after-idle latency is 257–375 ms, back-to-back unchanged (#14).

### Background service overhead

The same deployed engine answers ~20–30 ms slower on short clips under launchd (140–169 ms) than started from a terminal (118–137 ms); LLM-routed clips are within noise. Raising the inference and event-loop threads to user-interactive QoS made no measurable difference, so it was not kept (#17).
