# Wire Protocol — v1

One WebSocket session per client; one utterance at a time per session.

**Endpoint:** `ws://127.0.0.1:8765/v1/dictate`
**Health:** `GET /health` → `{"status": "ok", "asr": "<name>", "cleanup": "<name>"}`

## Backends

| Request | Response |
|---|---|
| `GET /v1/backends` | `{"asr": {"active": "<name>", "available": [...]}, "cleanup": {...}}` |
| `POST /v1/config` with `{"asr": "<name>"?, "cleanup": "<name>"?}` | Health body once the new backends are loaded; `400` for an unknown name, `500` if loading fails (the previous backends stay active) |

The choice is saved to `~/Library/Application Support/SonicFlow/config.json` and used on the next start; `SONICFLOW_ASR` / `SONICFLOW_CLEANUP` override it.

## Client → server

| Frame | Shape | Notes |
|---|---|---|
| text | `{"type": "start", "app": "<bundle id>?", "dictionary": [...]?, "snippets": [...]?}` | Opens an utterance |
| binary | PCM16 LE, mono, 16 kHz | Any chunk size; 100 ms (3200 bytes) recommended |
| text | `{"type": "stop"}` | Hotkey released; finalize now |

## Server → client

| Shape | When |
|---|---|
| `{"type": "partial", "text": "..."}` | Streaming backends, as text becomes available |
| `{"type": "final", "raw": "...", "text": "...", "timings": {"asr_finalize_ms": n, "cleanup_ms": n, "total_ms": n}}` | After `stop` |
| `{"type": "error", "message": "..."}` | Protocol misuse; session stays open |

`raw` is the ASR output; `text` is what the client pastes. `timings` are measured from receipt of `stop`.

## Dictionary and snippets

`dictionary` items are `{"term": "SonicFlow", "heard": ["sonic flo"]}` or a bare `"term"`. The engine rewrites any `heard` form, and the term in other capitalizations or spoken apart ("sonic flow"), to the term, before and after cleanup. A term that is a capitalized everyday word ("Will") only replaces its `heard` forms.

`snippets` items are `{"trigger": "my calendar link", "text": "https://…"}`. An utterance that is only the trigger returns `text` exactly and skips cleanup; a trigger inside a sentence is replaced after cleanup. Matching ignores case and punctuation. Malformed items are skipped.
