# Architecture

```
┌──────────────── macOS client (Swift, planned) ────────────────┐
│ hotkey ─► AVAudioEngine (16 kHz mono) ─► WebSocket ─► paste   │
│ app context (bundle id, selected text) via Accessibility      │
└──────────────────────────────┬────────────────────────────────┘
                               │ ws://127.0.0.1:8765/v1/dictate
┌──────────────────────────────▼────────────────────────────────┐
│ engine (Python, resident daemon)                              │
│                                                               │
│  PCM16 ─► ASRStream.feed ─► partials ─► rolling cleanup       │
│                 │                            │                │
│              finalize ─► tail ASR ─► tail cleanup ─► final    │
│                                                               │
│  single inference executor · models warm since startup        │
└───────────────────────────────────────────────────────────────┘
```

## Why it's fast

Latency that matters is **hotkey release → text pasted**. Everything that can happen while you are still talking does:

1. **Streaming ASR.** Audio streams in 100 ms chunks. Streaming backends transcribe as audio arrives, so on release only the last unconfirmed span is left to decode. Batch backends get the same API through the default `ASRStream`, which buffers and transcribes on `finalize` — slower, but benchmarkable on equal terms.
2. **Rolling cleanup (v0.3).** On each pause in speech the engine transcribes the audio so far and rewrites the sentences that need the LLM, keyed by their text. If nothing was said after the last pause, release reuses that transcript and those rewrites; otherwise it transcribes again and reuses the rewrites that still match. See ADR 0003.
3. **Skip when clean.** A cheap check (no fillers, no correction markers, punctuation present) bypasses the LLM entirely.
4. **Warm models, one thread.** Backends load at startup; all inference is serialized on one executor thread so GPU/ANE runtimes never contend.

## Components

| Component | Responsibility |
|---|---|
| `ASRBackend` | `load()`, `transcribe(audio)`, optional streaming `stream()` |
| `ASRStream` | `feed(chunk) -> partial | None`, `finalize() -> text` |
| `CleanupBackend` | `load()`, `clean(text, context)` |
| `CleanupContext` | App bundle id, personal dictionary; later: selected text, style |
| `registry` | Name → lazy factory, so only the selected backend's deps import |
| `server` | WebSocket session state, timing, routing calls through the executor |
| `bench` | Feeds the corpus through the same stream API, reports latency + WER |

## Deployment shapes

| Version | Shape |
|---|---|
| v0 | Engine on the same Mac as the client, loopback only |
| v0.5 | Engine on the M4 Max Mac Studio, client on the M3 Pro over LAN: opt-in, token and pinned TLS (ADR 0007) |
| v1 | Engine on a GPU cloud host with CUDA backends behind the same protocol; see ADR 0004 |
