# 0009 — Quantize Parakeet to 8 bits at load

**Status:** accepted · 2026-11-05

## Context

The engine held about 5 GB with Parakeet v2 and Qwen3 4B loaded. Parakeet's published MLX weights are float32; `parakeet_mlx` casts them to bfloat16 at load, leaving 1,178 MB of weights that ADR 0006 locks in RAM. Its linear and embedding layers, the bulk of the model, all have input sizes divisible by 64.

## Decision

`ParakeetASR.load` runs `mlx.nn.quantize(model, group_size=64, bits=8)` on the loaded model, so every Parakeet variant serves 8-bit linear and embedding weights. Convolutions and norms stay bfloat16. The files on disk are unchanged.

## Consequences

- Parakeet's weights drop from 1,178 MB to 700 MB.
- On an M3 Pro (`--realtime`, 21-item corpus, three runs each), v2 finalize p50 fell from 142 to 95 ms and release→text p50 from ~400 to ~330 ms; raw WER stayed at 1.3%, with two items differing only in punctuation. v3 (two runs each) matched: finalize 142 → 95 ms, identical raw transcripts on every item.
- The corpus is synthetic speech; accents, noise and domain vocabulary are not covered, so a regression on real dictation would show up in use first. Removing the `nn.quantize` call restores bfloat16.
