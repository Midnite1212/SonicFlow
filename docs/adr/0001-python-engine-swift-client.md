# 0001 — Python engine, Swift client

**Status:** accepted · 2026-10-23

## Context

Speech and LLM models ship first, and best, in the Python ecosystem (MLX, mlx-lm, whisper/parakeet ports, CUDA runtimes for the cloud). The inference itself runs in Metal/ANE/CUDA kernels, so interpreter overhead is small next to model time. The client needs a global hotkey, Accessibility, and paste into other apps, which are native macOS APIs.

## Decision

- Engine: Python 3.12, `uv`, FastAPI + WebSocket, backends behind abstract interfaces.
- Client: native Swift menu-bar app. No Electron, no webviews.
- If a Swift-only runtime (CoreML/ANE via FluidAudio, Apple SpeechAnalyzer) wins the bench, it runs as a backend sidecar behind the same protocol rather than replacing the engine.

## Consequences

Backends are easy to swap and benchmark. The client stays tiny. Python hot-path code needs care: no per-chunk allocation of model state, all inference on one executor thread.
