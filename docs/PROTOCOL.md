# Wire Protocol — v1

One WebSocket session per client; one utterance at a time per session.

**Endpoint:** `ws://127.0.0.1:8765/v1/dictate`
**Health:** `GET /health` → `{"status": "ok", "asr": "<name>", "cleanup": "<name>"}`

## Client → server

| Frame | Shape | Notes |
|---|---|---|
| text | `{"type": "start", "app": "<bundle id>?", "dictionary": ["term", ...]?}` | Opens an utterance |
| binary | PCM16 LE, mono, 16 kHz | Any chunk size; 100 ms (3200 bytes) recommended |
| text | `{"type": "stop"}` | Hotkey released; finalize now |

## Server → client

| Shape | When |
|---|---|
| `{"type": "partial", "text": "..."}` | Streaming backends, as text becomes available |
| `{"type": "final", "raw": "...", "text": "...", "timings": {"asr_finalize_ms": n, "cleanup_ms": n, "total_ms": n}}` | After `stop` |
| `{"type": "error", "message": "..."}` | Protocol misuse; session stays open |

`raw` is the ASR output; `text` is what the client pastes. `timings` are measured from receipt of `stop`.
