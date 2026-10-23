# Roadmap

## v0 — Fast core (English, localhost)

- [x] v0.0 Groundwork: protocol, backend interfaces, server, bench harness, corpus
- [ ] v0.1 ASR bake-off: add candidates one at a time, bench on M3 Pro and M4 Max, pick a default
  - [x] Parakeet TDT v2 and v3 (#3) — v2 leads on M3 Pro: ~110 ms p50, 7.1% WER
  - [x] Whisper large-v3-turbo (#7) — ~600 ms p50, 8.8% WER; too slow for the v0 default, kept as the multilingual candidate
- [ ] v0.2 Cleanup bake-off: rule-based fast path, then local LLMs, measured on filler/correction items
  - [x] Rule-based cleanup and LLM router (#9) — ~0 ms, clean-text WER 15.8% → 12.0%; routes only the 4 correction/ambiguous items
  - [x] Local LLM cleanup (#10) — qwen3-1.7b default (~150 ms per rewrite, 5.7% clean WER); qwen3-4b for quality (~300 ms, 5.1%)
- [ ] v0.3 Rolling cleanup during speech (self-correction across pauses)
- [ ] v0.4 macOS client: menu bar, hold-to-talk + toggle hotkey, paste into the focused app, latency HUD
- [ ] v0.5 Engine as a launchd daemon; optional LAN bind so the Mac Studio serves the laptop

## v1 — Wispr Flow parity and beyond

- Mandarin, Cantonese, Japanese (multilingual backend, per-language routing)
- Personal dictionary and snippets / voice shortcuts
- Per-app styles (Slack casual, email formal, editor → code-aware)
- Command mode: select text, speak an edit ("make it shorter")
- History with re-paste
- Cloud-hosted engine on a GPU host (ADR 0004)

## v2 — Ideas

- Code dictation that knows identifiers from the open repo
- Auto-dictionary learned from edits you make after pasting
- Voice → Claude Code prompt mode
- iPhone keyboard client against the home engine

## Backend candidates

From memory, unverified — check each package's current state when adding it.

| ASR | Runtime | Note |
|---|---|---|
| Parakeet TDT 0.6B (`parakeet-mlx`) | MLX | Strong English accuracy, very fast |
| Whisper large-v3-turbo (`mlx-whisper`) | MLX | Multilingual baseline for v1 |
| Whisper via `whisper.cpp` | Metal / CoreML | Mature, C++ |
| Moonshine | ONNX / MLX | Small, built for low latency |
| Kyutai STT | MLX | Natively streaming |
| Parakeet via FluidAudio, Apple SpeechAnalyzer | CoreML / ANE (Swift) | Needs a Swift sidecar; try after Python options |

| Cleanup | Runtime | Note |
|---|---|---|
| Rule-based fillers + punctuation | Python | Floor: ~0 ms |
| Qwen3 1.7B / 4B instruct | `mlx-lm` | Size vs latency trade |
| Gemma 3 4B, Llama 3.2 3B | `mlx-lm` | Alternatives |
