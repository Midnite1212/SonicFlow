# 0005 — User-chosen models, explicit downloads

**Status:** accepted · 2026-10-26

## Context

The engine shipped four hard-coded models and kept itself offline with `HF_HUB_OFFLINE=1`, filling the cache by loading each model once at install. Users want to try other models: a curated catalogue, any MLX build on Hugging Face, or a model folder already on disk. `huggingface_hub` reads offline mode once at import, so a running service cannot be offline for loading yet online for a download.

## Decision

- Models are entries with a family (`parakeet`, `whisper`, `mlx-lm`) and a source (a Hugging Face repo or an absolute folder). Built-in names stay as ids; anything else is addressed as `family:source`.
- Three groups: **recommended** (benchmarked on the M3 Pro, with numbers), **catalog** (curated MLX builds, untested for latency), **custom** (added by the user, stored in `models.json`).
- Loading is local-only by construction: every backend resolves its files through `models.local_path`, which uses `local_files_only=True` and fails with "not downloaded" rather than fetching.
- The only network calls are ones the user starts: `POST /v1/models/download`, `sonicflow-models download`, and reading a repo's metadata when adding it. Downloads run on their own thread, never on the inference thread, and use plain HTTP (`HF_HUB_DISABLE_XET=1`) so progress can be measured from the growing file.
- Added models must be MLX builds; PyTorch checkpoints are refused with a pointer to an MLX build.

## Consequences

`HF_HUB_OFFLINE` leaves the service plist. A forgotten download shows up as a load error naming the model, not a silent fetch. Catalog and custom models carry no latency claim until benched on the machine (guardrail 8).
