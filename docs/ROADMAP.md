# Roadmap

## v0 — Fast core (English, localhost)

- [x] v0.0 Groundwork: protocol, backend interfaces, server, bench harness, corpus
- [x] v0.1 ASR bake-off: add candidates one at a time, bench on M3 Pro and M4 Max, pick a default
  - [x] Parakeet TDT v2 and v3 (#3) — v2 leads on M3 Pro: ~110 ms p50, 7.1% WER
  - [x] Whisper large-v3-turbo (#7) — ~600 ms p50, 8.8% WER; too slow for the v0 default, kept as the multilingual candidate
  - [x] M4 Max bench (#5) — 2.6–3× faster than the M3 Pro at every combination, same WER; parakeet-v2 stays the default
- [x] v0.2 Cleanup bake-off: rule-based fast path, then local LLMs, measured on filler/correction items
  - [x] Rule-based cleanup and LLM router (#9) — ~0 ms, clean-text WER 15.8% → 12.0%; routes only the 4 correction/ambiguous items
  - [x] Local LLM cleanup (#10) — qwen3-1.7b default (~150 ms per rewrite, 5.7% clean WER); qwen3-4b for quality (~300 ms, 5.1%)
  - [x] Prompt v2 and hallucination guard (#23) — qwen3-4b now default: every corpus item correct, 3.4% clean WER
  - [x] Sentence-level cleanup (#36) — long passage 1,702 → 297 ms, identical output
- [x] v0.3 Rolling cleanup during speech (self-correction across pauses) (#77, ADR 0003) — release 500 ms after the last word: ~430 → ~40 ms p50 on the M3 Pro
- [x] v0.4 macOS client: menu bar, hold-to-talk + toggle hotkey, paste into the focused app, latency HUD
  - [x] Terminal mic client, hold Option to talk (#13)
  - [x] Warm-up on hotkey press removes the idle penalty (#14)
  - [x] Swift menu-bar app: hold Option, pill with live waveform, paste (#19)
  - [x] Instant capture with a warm mic and 200 ms pre-roll (#20)
  - [x] Settings window: hotkey, mode, microphone, models, launch at login (#28)
  - [x] Recover from dead mic input; silent dictations are cancelled (#31)
  - [x] Recent dictations in the menu, memory only, click to copy (#33)
  - [x] App icon (#40)
  - [x] App window with Home, History and Settings; onboarding; opt-in saved history (#42)
- [x] v0.5 Engine as a launchd daemon; optional LAN bind so the Mac Studio serves the laptop
  - [x] LaunchAgent with `sonicflow-service`, engine deployed to Application Support (#17)
  - [x] Switch models at runtime, choice saved in config.json (#25)
  - [x] One-step `scripts/install.sh` (#35)
  - [x] Model weights locked in RAM so memory pressure can't slow the next dictation (#30, ADR 0006)
  - [x] Share the engine with other Macs: pairing code, pinned TLS, fallback to this Mac (#76, ADR 0007)
- [x] v0.8c Models pane: Recommended, Browse, My Models (#56)
- [x] v0.8b Ollama cleanup models and Hugging Face search (#54)
- [x] v0.8a Model library: catalogue, explicit downloads, your own models (#52)
- [x] v0.7a Night-session design via Impeccable: PRODUCT.md, DESIGN.md, speed-stripe UI (#50)

## v1 — Wispr Flow parity and beyond

- Mandarin, Cantonese, Japanese (multilingual backend, per-language routing)
- [x] Personal dictionary and snippets / voice shortcuts (#44)
- [x] Per-app styles: standard, casual, lowercase (#46)
- [x] Command mode: select text, hold the hotkey with Shift, speak an edit (#48)
- [x] History with re-paste (#42, #64)
- Cloud-hosted engine on a GPU host (ADR 0004)

## v2 — Ideas

- Code dictation that knows identifiers from the open repo
- [x] Auto-dictionary learned from edits you make after pasting (#82, ADR 0008)
- [x] Learning pane to review fixes the auto-dictionary held back (#88)
- [x] Dictionary catches new mishearings that sound and look like a known word (#90)
- [x] Live transcript above the pill, then what cleanup removed (#91)
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
