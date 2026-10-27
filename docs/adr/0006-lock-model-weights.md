# 0006 — Lock model weights in RAM

**Status:** accepted · 2026-10-27

## Context

Under memory pressure macOS pages out the engine's idle Metal buffers, and the next dictation waits for gigabytes to come back from swap: 4.4–8.9 s in daily use, 15.2 s in a test after one critical-pressure event against 0.5 s warm (#30). MLX's `set_wired_limit` does not prevent this on macOS 26 with MLX 0.32: a wired and an unwired 4 GB buffer both took about 20 s to read back after the same pressure.

## Decision

After a backend loads, the engine locks each of its weight arrays with `mlock` on the Metal buffer (a zero-copy byte view of the array), and unlocks them before the backend unloads on a model switch. Backends list their arrays through `arrays()`; Ollama and the built-in cleanups return none. `SONICFLOW_LOCK_MODELS=0` turns locking off.

## Consequences

- The first dictation after heavy pressure took 1.1 s locked against 15.2 s unlocked; warm latency and startup are unchanged.
- The active models' weights (about 4.7 GB for Parakeet v2 and Qwen3 4B) can never be paged out, so under pressure other apps swap more instead. The limit is `vm.user_wire_limit`, about 30 GB on a 36 GB Mac; arrays that cannot be locked are skipped with a warning.
- Caches and activations are not locked; they are small and rebuilt per request.
