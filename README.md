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
| `client/macos/` | Swift menu-bar app: hotkey, mic capture, pill, paste |

## Install

```sh
scripts/install.sh
```

Needs an Apple Silicon Mac with `uv` (`brew install uv`) and the Swift toolchain (`xcode-select --install`). It installs the engine's dependencies, downloads the models, starts the background engine, and builds, signs, installs and launches the menu-bar app. Rerun it after pulling changes; it keeps the models chosen in Settings (`SONICFLOW_ASR` / `SONICFLOW_CLEANUP` override them).

## Development

```sh
bench/corpus/make_corpus.sh          # synthesize test audio (macOS `say`)
cd engine
uv sync
uv run pytest
uv run sonicflow-bench --asr <backend>
SONICFLOW_ASR=<backend> uv run sonicflow   # ws://127.0.0.1:8765/v1/dictate
```

Current best on M3 Pro: `uv sync --all-extras`, then `SONICFLOW_ASR=parakeet-v2 SONICFLOW_CLEANUP=qwen3-4b uv run sonicflow` (`qwen3-1.7b` is ~130 ms faster per correction but less accurate).

## Run the engine in the background

```sh
cd engine
uv run sonicflow-service install      # copies the engine to ~/Library/Application Support/SonicFlow and starts it at login
uv run sonicflow-service status
uv run sonicflow-service restart
uv run sonicflow-service uninstall
```

`install --asr <name> --cleanup <name>` picks backends (default: the saved choice, else `parakeet-v2` + `qwen3-4b`); the app can also switch them at runtime (`POST /v1/config`). Rerun `install` after pulling engine changes. Models must already be in the Hugging Face cache (run the bench or the engine once), since the service runs offline. Logs: `~/Library/Logs/SonicFlow/engine.log`. While the service runs, `uv run sonicflow` can't bind port 8765.

## Menu-bar app

```sh
client/macos/scripts/install.sh   # build, sign, install to ~/Applications, launch
client/macos/scripts/test.sh      # Swift unit tests
```

Hold **Option** anywhere to dictate; a pill with a live waveform appears at the bottom of the screen and the cleaned text is pasted into the focused app on release. The app talks to the background engine, so install that first. On first launch it asks for Microphone, Input Monitoring and Accessibility. By default the microphone stays ready with a 200 ms in-memory pre-roll so the first word is never clipped; macOS shows the mic indicator while the app runs, and nothing is sent outside a dictation. **Settings…** (⌘,) changes the hotkey, hold vs. tap-to-toggle mode, microphone, models and launch at login. Builds are signed with a local self-signed "SonicFlow Dev" identity (created on first build in its own keychain) so those grants survive rebuilds.

## Dictate from the terminal

With the engine running (background service or `uv run sonicflow`):

```sh
cd engine
uv run sonicflow-mic          # hold Option, speak, release → pasted into the focused app
uv run sonicflow-mic --no-paste
```

The terminal app needs Microphone, Accessibility and Input Monitoring permission (System Settings → Privacy & Security). Tapping Option or using it as a modifier (Option+arrow) cancels instead of dictating. The previous clipboard text is restored after pasting.

## Model credits

- [Parakeet TDT 0.6B](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2) by NVIDIA, CC-BY-4.0, run via [parakeet-mlx](https://github.com/senstella/parakeet-mlx)
- [Qwen3](https://huggingface.co/Qwen) 1.7B and 4B Instruct 2507 by Alibaba Qwen, Apache-2.0, run via [mlx-lm](https://github.com/ml-explore/mlx-lm)
- [Whisper large-v3-turbo](https://huggingface.co/openai/whisper-large-v3-turbo) by OpenAI, MIT, run via [mlx-whisper](https://github.com/ml-explore/mlx-examples/tree/main/whisper)

## Docs

- [Architecture](docs/ARCHITECTURE.md)
- [Wire protocol](docs/PROTOCOL.md)
- [Latency budget](docs/LATENCY.md)
- [Roadmap](docs/ROADMAP.md)
- [Decision records](docs/adr/)
