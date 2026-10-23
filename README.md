# SonicFlow

Local, blazing-fast voice dictation for macOS. Hold a hotkey, speak, release, and clean text lands in whatever app you're in. Everything runs on your machine.

Status: **v0 groundwork.** The engine skeleton, wire protocol and benchmark harness exist. No ASR backend is wired in yet; candidates are being benchmarked one by one (see [docs/ROADMAP.md](docs/ROADMAP.md)).

## Layout

| Path | What |
|---|---|
| `engine/` | Python engine: FastAPI WebSocket server, pluggable ASR and cleanup backends, bench CLI |
| `bench/corpus/` | Benchmark manifest plus TTS generator; audio is generated locally |
| `bench/results/` | Bench output JSON (gitignored) |
| `docs/` | Architecture, protocol, latency budget, roadmap, ADRs |
| `client/` | Native macOS client (planned, Swift) |

## Quick start

```sh
bench/corpus/make_corpus.sh          # synthesize test audio (macOS `say`)
cd engine
uv sync
uv run pytest
uv run sonicflow-bench --asr <backend>
SONICFLOW_ASR=<backend> uv run sonicflow   # ws://127.0.0.1:8765/v1/dictate
```

## Model credits

- [Parakeet TDT 0.6B](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2) by NVIDIA, CC-BY-4.0, run via [parakeet-mlx](https://github.com/senstella/parakeet-mlx)

## Docs

- [Architecture](docs/ARCHITECTURE.md)
- [Wire protocol](docs/PROTOCOL.md)
- [Latency budget](docs/LATENCY.md)
- [Roadmap](docs/ROADMAP.md)
- [Decision records](docs/adr/)
