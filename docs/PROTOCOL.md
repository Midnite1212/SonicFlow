# Wire Protocol — v1

One WebSocket session per client; one utterance at a time per session.

**Endpoint:** `ws://127.0.0.1:8765/v1/dictate`
**Health:** `GET /health` → `{"status": "ok", "asr": "<name>", "cleanup": "<name>"}`

## Backends

| Request | Response |
|---|---|
| `GET /v1/backends` | `{"asr": {"active": "<name>", "available": [...]}, "cleanup": {...}}` |
| `POST /v1/config` with `{"asr": "<name>"?, "cleanup": "<name>"?}` | Health body once the new backends are loaded; `400` for an unknown name, `500` if loading fails (the previous backends stay active) |

## Sharing with other Macs

Off by default (ADR 0007). These endpoints answer only on loopback.

| Request | Response |
|---|---|
| `GET /v1/lan` | `{"enabled": false}`, or `{"enabled": true, "host", "port", "code"}` while shared |
| `POST /v1/lan` with `{"enabled": bool}` | The same body. Turning on starts a TLS listener on `SONICFLOW_LAN_PORT` (default 8766) on every interface and remembers the choice; `409` if the port is taken |
| `POST /v1/lan/reset` | The same body, with a new token; clients paired with the old code stop being admitted |

`code` is `sonicflow1.` followed by unpadded base64url JSON: `{"host", "port", "token", "sha256"}`, where `sha256` is the hex digest of the listener's DER certificate. On the shared listener every endpoint below (but not `/v1/lan`) is served as on loopback over `https`/`wss`. Each request must send `Authorization: Bearer <token>`; without it HTTP answers `401` and the WebSocket handshake is refused. Clients trust the certificate by comparing its digest with `sha256`, not through a CA.

## Models

| Request | Response |
|---|---|
| `GET /v1/models` | `{"active": {"asr", "cleanup"}, "models": [{id, kind, family, source, title, group, size_bytes, note, bench, installed, download, benchmark}]}`; `group` is `recommended`, `catalog` or `custom`. `bench` is `{p50_ms, wer}`, plus `"local": true` when measured on this Mac |
| `POST /v1/models/download` with `{"id"}` | `202`; the download runs in the background. Progress appears in each model's `download`: `{state, bytes, total_bytes, error}` |
| `POST /v1/models/bench` with `{"id"}` | `202`; times an installed model over the bench corpus in a subprocess (ASR models alone, cleanup models behind the active ASR model). Progress appears in each model's `benchmark`: `{state, error}`; the result replaces its `bench`. `400` if not installed |
| `POST /v1/models/custom` with `{"source", "title"?}` | The new model. `source` is a Hugging Face repo (`org/name`, MLX builds only) or an absolute folder with `config.json` and `.safetensors`; the family is detected. `400` with a reason otherwise |
| `GET /v1/models/search?q=&kind=asr\|cleanup` | `{"results": [{source, family, kind, downloads, added}]}`: MLX models on Hugging Face, most downloaded first. Contacts Hugging Face, so clients call it only when the user searches; `502` if unreachable |
| `GET /v1/models/ollama` | `{"running": bool, "models": [{name, size, added}]}` from Ollama at `SONICFLOW_OLLAMA_URL` (default this Mac) |
| `POST /v1/models/custom` with `{"source": "<ollama model>", "family": "ollama"}` | Adds a model Ollama has pulled as a cleanup model (id `ollama:<name>`); `400` if Ollama is not running or the model is not pulled |
| `POST /v1/models/remove` with `{"id"}` | Deletes downloaded files and forgets a custom model (local folders stay on disk). `409` for an active model |

Any installed model id, or `family:source`, is accepted by `POST /v1/config`. The choice is saved to `~/Library/Application Support/SonicFlow/config.json` and used on the next start; `SONICFLOW_ASR` / `SONICFLOW_CLEANUP` override it.

## Client → server

| Frame | Shape | Notes |
|---|---|---|
| text | `{"type": "start", "app": "<bundle id>?", "style": "<style>"?, "dictionary": [...]?, "snippets": [...]?, "partials": bool?}` | Opens an utterance; `"partials": true` asks for the transcript while the user speaks |
| binary | PCM16 LE, mono, 16 kHz | Any chunk size; 100 ms (3200 bytes) recommended |
| text | `{"type": "stop", "selection": "..."?}` | Hotkey released; finalize now. With `selection`, the utterance is a command (see below) |

## Server → client

| Shape | When |
|---|---|
| `{"type": "partial", "text": "..."}` | The transcript so far, before cleanup: from streaming backends as text becomes available, and, when `start` asked for partials, from rolling backends at each pause and every 0.5 s of speech. Never sent after `final` |
| `{"type": "final", "raw": "...", "text": "...", "timings": {"asr_finalize_ms": n, "cleanup_ms": n, "total_ms": n}}` | After `stop` |
| `{"type": "error", "message": "..."}` | Protocol misuse; session stays open |

`raw` is the ASR output; `text` is what the client pastes. `timings` are measured from receipt of `stop`.

## Command mode

A `stop` with a non-blank `selection` treats the transcript as an instruction ("make it shorter") and the `final` `text` is `selection` rewritten by the cleanup model; the client pastes it over the selection. Errors: `"no instruction heard"` for an empty transcript, and `"command mode needs an LLM cleanup model, not '<name>'"` when cleanup is `none` or `rules`.

## Styles

`style` formats the cleaned text without a model call: `standard` (default) leaves it as is, `casual` drops the final period, and `lowercase` also starts each sentence in lowercase, keeping "I" and dictionary terms. Unknown values act as `standard`. The client picks the style from the app being dictated into.

## Dictionary and snippets

`dictionary` items are `{"term": "SonicFlow", "heard": ["sonic flo"]}` or a bare `"term"`. The engine rewrites any `heard` form, and the term in other capitalizations or spoken apart ("sonic flow"), to the term, before and after cleanup. A term that is a capitalized everyday word ("Will") only replaces its `heard` forms.

`snippets` items are `{"trigger": "my calendar link", "text": "https://…"}`. An utterance that is only the trigger returns `text` exactly and skips cleanup; a trigger inside a sentence is replaced after cleanup. Matching ignores case and punctuation. Malformed items are skipped.
