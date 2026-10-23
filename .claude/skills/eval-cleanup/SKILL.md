---
name: eval-cleanup
description: Evaluate a SonicFlow cleanup backend (rule-based or LLM) on filler removal, self-correction, and formatting using the corpus `clean` targets, and inspect failures. USE WHEN eval cleanup, test the LLM fix, self-correction quality, filler removal, compare cleanup models, tune the cleanup prompt.
---

# Eval cleanup

1. Run the bench with the cleanup backend and a fixed ASR so only cleanup varies:
   ```sh
   uv run sonicflow-bench --asr <best asr> --cleanup <cleanup>
   ```
2. From the result JSON, list items where normalized `text` differs from the manifest's `clean`, grouped by `kind` (`filler`, `correction`, `code`, `plain`).
3. Judge each miss: real error (kept a filler, kept the retracted phrase, changed meaning) vs acceptable variant (punctuation, number style). Only real errors count against the backend.
4. Plain items must come out unchanged in meaning — a cleanup that rewrites clean text is worse than none.
5. Report per-kind pass counts, `cleanup_ms` p50/p95, and the worst three misses.
6. New failure patterns become new manifest lines (`spoken` + `clean`) so they stay covered; regenerate audio afterwards.
