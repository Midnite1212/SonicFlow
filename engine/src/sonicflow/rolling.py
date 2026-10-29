"""Transcribes and cleans up during pauses in speech, so release finishes only what is left
(ADR 0003).

On each pause the audio so far is transcribed and its sentences that need the LLM are rewritten,
keyed by their exact text. If nothing was said after the last pause, release reuses that
transcript and its rewrites; otherwise it transcribes everything and reuses whichever rewrites
still match."""

import os
import threading
from collections.abc import Callable
from concurrent.futures import Future

import numpy as np

from sonicflow import SAMPLE_RATE
from sonicflow.backends.base import ASRBackend, CleanupBackend, CleanupContext

PAUSE_S = 0.25
MIN_AUDIO_S = 0.5
# Loudness relative to the loudest chunk so far below which a chunk counts as a pause.
QUIET = 0.1
# Stricter, for reusing a transcript at release: a soft last word must never be dropped.
SILENT = 0.05
# Also, the tail after a pause may be at most this much louder than the pause itself, so a loud
# cough early on can't make a soft last phrase pass for silence.
NOISE_MARGIN = 2.0
NOISE_FLOOR = 1e-4


def enabled() -> bool:
    return os.environ.get("SONICFLOW_ROLLING", "1") != "0"


def _level(chunk: np.ndarray) -> float:
    return float(np.sqrt(np.mean(np.square(chunk)))) if len(chunk) else 0.0


class Rolling:
    """One utterance. `add` and `release` run on the caller's thread and hand work to `submit`,
    which must run it on the inference thread in order; `transcript` runs there too, as does
    `on_transcript`, called with each pause's transcript so far."""

    def __init__(
        self,
        asr: ASRBackend,
        cleanup: CleanupBackend,
        context: CleanupContext,
        prepare_text: Callable[[str], str],
        submit: Callable[..., Future],
        on_transcript: Callable[["Rolling", str], None] | None = None,
    ) -> None:
        self._asr = asr
        self._cleanup = cleanup
        self._context = context
        self._prepare_text = prepare_text
        self._submit = submit
        self._on_transcript = on_transcript
        self._chunks: list[np.ndarray] = []
        self._levels: list[float] = []
        self._samples = 0
        self._peak = 0.0
        self._quiet_s = 0.0
        self._quiet_from = 0
        self._spoke_since_pass = False
        self._pass: Future | None = None
        self._pass_end = 0
        self._pause_levels: dict[int, float] = {}
        self._snapshot: tuple[int, str] | None = None
        self.cancelled = threading.Event()

    def add(self, chunk: np.ndarray) -> None:
        level = _level(chunk)
        self._chunks.append(chunk)
        self._levels.append(level)
        self._samples += len(chunk)
        self._peak = max(self._peak, level)
        if level < QUIET * self._peak:
            self._quiet_s += len(chunk) / SAMPLE_RATE
        else:
            self._quiet_s = 0.0
            self._quiet_from = len(self._chunks)
            self._spoke_since_pass = True
        if (
            self._quiet_s >= PAUSE_S
            and self._spoke_since_pass
            and self._samples >= MIN_AUDIO_S * SAMPLE_RATE
            and (self._pass is None or self._pass.done())
        ):
            self._spoke_since_pass = False
            self._pass_end = len(self._chunks)
            self._pause_levels[self._pass_end] = max(self._levels[self._quiet_from :])
            self._pass = self._submit(self._run_pass, self._pass_end, np.concatenate(self._chunks))

    def release(self) -> None:
        """Stops work in flight unless its transcript will be the final one."""
        if not self._silent_since(self._pass_end):
            self.cancel()

    def cancel(self) -> None:
        """Stops early cleanup; a transcript already made can still be reused."""
        self.cancelled.set()

    def transcript(self) -> str:
        if self._snapshot is not None and self._silent_since(self._snapshot[0]):
            return self._snapshot[1]
        return self._asr.transcribe(np.concatenate(self._chunks)) if self._chunks else ""

    def _silent_since(self, end: int) -> bool:
        if end == 0:
            return False
        pause = max(self._pause_levels[end] * NOISE_MARGIN, NOISE_FLOOR)
        limit = min(SILENT * self._peak, pause)
        return all(level <= limit for level in self._levels[end:])

    def _run_pass(self, end: int, audio: np.ndarray) -> None:
        if self.cancelled.is_set():
            return
        raw = self._asr.transcribe(audio)
        self._snapshot = (end, raw)
        if raw and self._on_transcript is not None:
            self._on_transcript(self, raw)
        if raw and not self.cancelled.is_set():
            self._cleanup.prepare(self._prepare_text(raw), self._context, self.cancelled)
