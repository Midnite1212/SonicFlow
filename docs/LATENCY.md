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

Current matrix (21-item corpus, one run each). WER spells numbers under 100 as words, splits camelCase and joins known compounds on both sides, so formatting differences ("10:30" vs "ten thirty") no longer count as errors (#6):

| Date | Machine | ASR | Cleanup | release→text p50 | WER raw | WER clean |
|---|---|---|---|---|---|---|
| 2026-10-27 | Apple M3 Pro | parakeet-v2 | none | 106 ms | 1.3% | 15.4% |
| 2026-10-27 | Apple M3 Pro | parakeet-v3 | none | 115 ms | 1.6% | 16.2% |
| 2026-10-27 | Apple M3 Pro | whisper-turbo | none | 644 ms | 1.3% | 15.0% |
| 2026-10-27 | Apple M3 Pro | parakeet-v2 | rules | 113 ms | 1.3% | 13.2% |
| 2026-10-27 | Apple M3 Pro | parakeet-v2 | qwen3-1.7b | 234 ms | 1.3% | 2.3% |
| 2026-10-27 | Apple M3 Pro | parakeet-v2 | qwen3-4b | 378 ms | 1.3% | 0.8% |

History (WER before normalisation):

| Date | Machine | ASR | Cleanup | release→text p50 / p95 | WER raw | WER clean |
|---|---|---|---|---|---|---|
| 2026-10-26 | Apple M3 Pro | parakeet-v2 | none | 115–138 / 394–550 ms | 4.9% | 17.6% |
| 2026-10-26 | Apple M3 Pro | parakeet-v3 | none | 115–141 / 329–404 ms | 4.9% | 17.6% |
| 2026-10-26 | Apple M3 Pro | whisper-turbo | none | 588–592 / 783–788 ms | 5.9% | 16.0% |
| 2026-10-26 | Apple M3 Pro | parakeet-v2 | rules | 112–115 / 295–417 ms | 4.9% | 15.3% |
| 2026-10-26 | Apple M3 Pro | parakeet-v2 | qwen3-1.7b | 229–232 / 291–317 ms | 4.9% | 4.2% |
| 2026-10-26 | Apple M3 Pro | parakeet-v2 | qwen3-4b | 362–367 / 472–498 ms | 4.9% | 2.7% |
| 2026-10-23 | Apple M3 Pro | parakeet-v2 | none | 110–111 / 181–213 ms | 7.1% | — |
| 2026-10-23 | Apple M3 Pro | parakeet-v3 | none | 115–125 / 195–217 ms | 8.2% | — |
| 2026-10-23 | Apple M3 Pro | whisper-turbo | none | 595–602 / 712–721 ms | 8.8% | — |
| 2026-10-23 | Apple M3 Pro | parakeet-v2 | none | (same runs as above) | 7.1% | 15.8% |
| 2026-10-23 | Apple M3 Pro | parakeet-v2 | rules | 107–115 / 182–186 ms | 7.1% | 12.0% |
| 2026-10-23 | Apple M3 Pro | parakeet-v2 | qwen3-1.7b | 112–114 / 275–303 ms | 7.1% | 5.7% |
| 2026-10-23 | Apple M3 Pro | parakeet-v2 | qwen3-4b | 127–128 / 459–469 ms | 7.1% | 5.1% |
| 2026-10-24 | Apple M3 Pro | parakeet-v2 | qwen3-1.7b (prompt v2, 20 items) | 20 items, 60% routed to LLM: cleanup p50/p95 131 / 167 ms | — | 5.3% (was 7.7%) |
| 2026-10-24 | Apple M3 Pro | parakeet-v2 | qwen3-4b (prompt v2, 20 items) | 372 / 473 ms | — | 3.4% (was 3.8%) |

Ranges span two runs with warm models; load is ~1.2 s once cached. The v2/v3 gap is real ("write path" → "right path" in both, extra misses in v3). Whisper pads every input to a 30 s window, so its cost is ~580 ms even for a 2 s clip; it drops some fillers on its own and formats identifiers and sentences better, but misses the raw budget.

LLM cleanup only runs on the 4 items `needs_llm()` flags, so its cost shows at p95: per rewrite, qwen3-1.7b takes 129–173 ms and qwen3-4b 230–353 ms on top of ASR. Both resolve all three self-corrections; only 4B also drops the ambiguous "like". Both drop a leading "Let's" in "Let's ship it on Friday, no wait, Thursday".

### Idle penalty

After ~30 s without dictation the first utterance used to cost 360–873 ms end to end (parakeet-v2 + qwen3-1.7b, live WebSocket, 4 idle cycles) against ~260–290 ms back to back. The engine now runs a short ASR and LLM warm-up on `start`, while the user is still speaking; after-idle latency is 257–375 ms, back-to-back unchanged (#14).

### Background service overhead

The same deployed engine answers ~20–30 ms slower on short clips under launchd (140–169 ms) than started from a terminal (118–137 ms); LLM-routed clips are within noise. Raising the inference and event-loop threads to user-interactive QoS made no measurable difference, so it was not kept (#17).

### Cleanup prompt v2

The 20-item corpus adds corrections with leading words and literal uses of "like" / "you know". Before the prompt change, qwen3-1.7b answered a dictated question ("Do you know when the release is planned?" → "The release is planned for next week."). Prompt v2 says the text is never addressed to the model and keeps every word outside the retracted span, and `accept_rewrite` rejects rewrites with more than ~20% words that were never spoken. With it, qwen3-4b gets every item right; qwen3-1.7b still keeps a retracted name ("Please call Sam") and a filler "like", so 4B is the default (#23).

### Sentence-level cleanup

Only sentences `needs_llm()` flags go to the LLM (a correction travels with the sentence it retracts, and a bare "Scratch that." also takes the next one). On the 21-item corpus with qwen3-4b the output is identical to whole-text cleanup (2.67% clean WER) while a 330-character passage with one correction drops from 1,702 ms to 297 ms of cleanup (#36).
