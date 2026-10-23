# 0004 — Localhost first, cloud later

**Status:** accepted · 2026-10-23

## Context

v0 is personal and local. v1 should be deployable to a hosted service. Serverless platforms like Vercel are built for short request/response functions without GPUs, which doesn't fit a resident model serving long-lived WebSockets (to re-verify when v1 starts).

## Decision

- v0 binds to `127.0.0.1` only.
- The protocol is transport-neutral, so a remote engine is just a different URL plus auth.
- v1 cloud runs the engine on a GPU host (e.g. Modal, RunPod, Fly GPU) with CUDA backends behind the same interfaces. A Vercel-style host can serve a web UI or settings dashboard, not the engine.
- Remote mode adds TLS and a bearer token in the `Authorization` header, never in the URL.

## Consequences

Cloud backends (faster-whisper, NeMo Parakeet) are additional registry entries rather than a fork. Remote audio leaves the machine, so cloud mode is opt-in per client.
