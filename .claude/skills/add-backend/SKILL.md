---
name: add-backend
description: Add a new ASR or cleanup model to SonicFlow behind the backend protocol, with an optional dependency extra, a test, and a first bench run. USE WHEN add backend, try model, add parakeet, add whisper, add moonshine, add an LLM for cleanup, wire up a new ASR.
---

# Add a backend

1. Confirm the package exists and its current API via Context7 or its README — don't code from memory.
2. Add the dependency as an optional extra in `engine/pyproject.toml` named after the backend (`[project.optional-dependencies] parakeet = [...]`), then `uv sync --extra <name>`.
3. Create `engine/src/sonicflow/backends/<name>.py`:
   - Subclass `ASRBackend` or `CleanupBackend`; set `name`.
   - Heavy imports and model download/load go in `load()`, never at module import.
   - Inputs are float32 mono 16 kHz in [-1, 1]. Convert inside the backend if the model needs otherwise.
   - Override `stream()` only if the model genuinely streams; otherwise inherit the buffering default.
4. Register a lazy factory in `registry.py`:
   ```python
   def _parakeet() -> ASRBackend:
       from sonicflow.backends.parakeet import ParakeetASR
       return ParakeetASR()
   ```
5. Unit-test any pure logic the backend adds (text post-processing, chunk handling); model inference itself is covered by the bench.
6. Run `uv run ruff check . && uv run pytest`, then the `bench` skill for this backend on this machine.
7. Report the bench row and a one-line verdict versus the current best.
