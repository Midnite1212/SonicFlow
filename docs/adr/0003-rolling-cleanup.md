# 0003 — Rolling cleanup during speech

**Status:** accepted · 2026-10-23, revised 2026-10-29

## Context

A single ASR and LLM cleanup pass after release adds its full latency to every utterance. Self-corrections ("Friday, no wait, Thursday") can span pauses. The ASR backends are batch models, not streaming ones, so there are no stable committed segments to clean as they arrive.

## Decision

- On each pause in speech (0.25 s below a tenth of the loudest level so far), the engine transcribes all the audio so far on the inference thread. It also rewrites that transcript's flagged sentences, each on its own, keyed by their exact text in the utterance's `CleanupContext`.
- At release, if nothing louder than a twentieth of the peak came after the last pause, that transcript is the final one and its rewrites are reused. Otherwise the whole utterance is transcribed again, and only the rewrites whose sentence text still matches are reused.
- The work is queued, never awaited, so the WebSocket loop reads `stop` at once. When release needs a fresh transcript, a rewrite in flight stops at its next token. Only the MLX LLM can stop like that, so other cleanup backends do nothing early.
- Backends opt in with `ASRBackend.rolling` when transcribing is cheap enough to repeat (Parakeet, not Whisper). `SONICFLOW_ROLLING=0` turns it off.

## Consequences

Rewrites are deterministic and keyed by their input, so a reused rewrite is exactly what release would compute. A reused transcript is not always identical: it ends with the pause's quarter second of silence instead of however long the hotkey was held, and Parakeet sometimes punctuates the two differently ("Alice. Sorry I mean Bob." against "Alice, sorry I mean Bob,"). Corpus WER is unchanged. Releasing a moment after the last word usually leaves only the vocabulary and style steps. Speaking again just before release can cost up to one extra transcription of the audio so far. Streaming ASR with committed segments would remove that, and stays a later option.
