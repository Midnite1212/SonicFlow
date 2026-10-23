# 0002 — Bench first, pluggable backends

**Status:** accepted · 2026-10-23

## Context

The fastest model for this hardware (M3 Pro 36 GB, M4 Max) isn't knowable from model cards; it depends on runtime, quantization and how streaming is done.

## Decision

Every ASR and cleanup model implements `ASRBackend` / `CleanupBackend` and registers a lazy factory. The default is picked only from `sonicflow-bench` results on both machines. The bench drives backends through the same `stream()` / `finalize()` / `clean()` calls the server uses.

## Consequences

Adding a model is one file plus a registry line. Comparisons are like-for-like. The synthetic TTS corpus favours clean audio, so final picks get re-checked on personal recordings.
