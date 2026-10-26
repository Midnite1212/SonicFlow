# SonicFlow — Agent Guide

SonicFlow is a local dictation engine whose whole reason to exist is speed. Every change is judged first by what it does to release→text latency, then by accuracy, then by everything else.

## Layout

- `engine/` — Python 3.12, managed by `uv`. FastAPI server (`server.py`), backend protocols (`backends/base.py`), registry (`backends/registry.py`), bench CLI (`bench/cli.py`).
- `bench/corpus/` — `manifest.jsonl` is the source of truth; `make_corpus.sh` generates audio into `audio/` (gitignored).
- `client/macos/` — Swift package: `SonicFlowCore` (pure, unit-tested logic) and the `SonicFlow` menu-bar app. Build with `scripts/install.sh`, test with `scripts/test.sh`; never commit `.build/` or `build/`.
- `docs/` — architecture, protocol, latency budget, roadmap, ADRs.

## Commands

Run from `engine/`:

```sh
uv sync                                   # install
uv run pytest                             # tests
uv run ruff check . && uv run ruff format --check .
uv run sonicflow-bench --asr <name> [--cleanup <name>] [--realtime] [--baseline <json>]
SONICFLOW_ASR=<name> uv run sonicflow      # serve on 127.0.0.1:8765
uv run sonicflow-service install|status|restart|uninstall   # background LaunchAgent
uv run sonicflow-mic                        # hold Option to dictate
```

## Guardrails

1. **Latency is a test.** Any change touching `server.py`, `backends/`, or a backend's settings runs `sonicflow-bench` against the previous result for the same machine with `--baseline`. A p50 release→text regression over 10% blocks the change unless the change is explicitly an accuracy trade-off recorded in an ADR.
2. **Offline by default.** The engine makes no network calls at runtime. Model downloads happen only in a backend's `load()` and only on first use. Any cloud fallback is opt-in and off by default.
3. **Dictated content is private.** Never log, print, persist, or put in test fixtures any transcript or audio from real use. Logs carry timings and sizes only. Real recordings live in `bench/corpus/personal/` (gitignored) and are never committed. The app's history is the one exception: it lives in memory unless the user turns on **Save history**, which writes it to Application Support (mode 0600) and prunes it by the chosen retention. Usage stats on disk hold counts only, never text.
4. **Bind to loopback.** The server defaults to `127.0.0.1`. Binding to another interface is a deliberate config change, never a default.
5. **Backends stay behind the protocol.** New ASR or cleanup models implement `ASRBackend` / `CleanupBackend`, register a lazy factory in `registry.py`, and import their heavy dependencies inside the factory or `load()`. No backend-specific branches in `server.py` or the bench.
6. **One inference thread.** All model calls go through `Engine.run`, which serializes them on a single executor. Never call a backend from the event loop directly.
7. **Warm, not lazy.** Models load once at startup in `load()`. Nothing on the per-utterance path may download, compile, or allocate model state.
8. **Measure, don't guess.** Claims that one backend is faster or more accurate cite a `bench/results/` file from the machine in question (M3 Pro and M4 Max numbers are not interchangeable).
9. **Dependencies earn their place.** Backend-only dependencies go in an optional extra named after the backend, never in the core dependency list. A new core dependency needs an ADR.
10. **No Electron, no webviews.** The client is native Swift.

## Workflow

Every step on the roadmap gets a GitHub issue (goal plus a step checklist) and lands through its own PR that closes it. Before merging: `ruff check`, `ruff format --check`, `pytest`, and a bench run if the hot path changed, with the bench row in the PR. Squash-merge and delete the branch; `main` is the timeline.

## Conventions

- Audio on the wire and inside the engine is mono 16 kHz. Wire format is PCM16 little-endian; backends receive float32 in [-1, 1].
- Protocol changes update `docs/PROTOCOL.md` in the same change and bump the path version (`/v1/` → `/v2/`) when they break clients.
- Significant decisions get an ADR in `docs/adr/NNNN-title.md` (context, decision, consequences; under a page).
- Default to no comments; add one only for a non-obvious why.
