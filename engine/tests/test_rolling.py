import threading
from concurrent.futures import Future

import numpy as np
from conftest import FakeASR
from fastapi.testclient import TestClient

from sonicflow import SAMPLE_RATE
from sonicflow.backends.base import CleanupContext
from sonicflow.backends.prompting import Interrupted, PromptCleanup
from sonicflow.backends.registry import PassthroughCleanup
from sonicflow.rolling import Rolling
from sonicflow.server import create_app

CHUNK = SAMPLE_RATE // 10


def speech(seconds: float) -> list[np.ndarray]:
    return [np.full(CHUNK, 0.3, dtype=np.float32)] * round(seconds * 10)


def silence(seconds: float) -> list[np.ndarray]:
    return [np.zeros(CHUNK, dtype=np.float32)] * round(seconds * 10)


def run_now(fn, *args) -> Future:
    future = Future()
    future.set_result(fn(*args))
    return future


class CountingASR(FakeASR):
    rolling = True

    def __init__(self) -> None:
        super().__init__()
        self.calls: list[int] = []

    def transcribe(self, audio: np.ndarray) -> str:
        self.calls.append(len(audio))
        return f"Ship it Friday, no wait, Thursday. Heard {len(audio)}."


class ScriptedCleanup(PromptCleanup):
    name = "scripted"
    interruptible = True

    def __init__(self) -> None:
        self.rewritten: list[str] = []

    def _rewrite(self, text: str, cancelled: threading.Event | None = None) -> str:
        if cancelled is not None and cancelled.is_set():
            raise Interrupted
        self.rewritten.append(text)
        return "Ship it Thursday."


def utterance(asr, cleanup, chunks) -> tuple[Rolling, CleanupContext]:
    context = CleanupContext()
    speech_ = Rolling(asr, cleanup, context, lambda text: text, run_now)
    for chunk in chunks:
        speech_.add(chunk)
    return speech_, context


def test_pause_then_release_reuses_the_transcript_and_rewrites():
    asr, cleanup = CountingASR(), ScriptedCleanup()
    speech_, context = utterance(asr, cleanup, speech(1) + silence(0.6))
    speech_.release()

    raw = speech_.transcript()
    assert asr.calls == [round(1.3 * SAMPLE_RATE)]
    assert not speech_.cancelled.is_set()
    assert cleanup.clean(raw, context) == f"Ship it Thursday. Heard {asr.calls[0]}."
    assert cleanup.rewritten == ["Ship it Friday, no wait, Thursday."]


def test_speech_after_the_pause_is_transcribed_at_release():
    asr, cleanup = CountingASR(), ScriptedCleanup()
    speech_, context = utterance(asr, cleanup, speech(1) + silence(0.3) + speech(0.5))
    speech_.release()

    assert speech_.cancelled.is_set()
    assert speech_.transcript() == "Ship it Friday, no wait, Thursday. Heard 28800."
    assert asr.calls == [round(1.3 * SAMPLE_RATE), round(1.8 * SAMPLE_RATE)]
    cleanup.clean(speech_.transcript(), context)
    assert cleanup.rewritten == ["Ship it Friday, no wait, Thursday."]


def test_no_pause_means_no_early_work():
    asr = CountingASR()
    speech_, _ = utterance(asr, ScriptedCleanup(), speech(2))
    speech_.release()
    assert asr.calls == []
    speech_.transcript()
    assert asr.calls == [2 * SAMPLE_RATE]


def test_silence_alone_never_starts_a_pass():
    asr = CountingASR()
    utterance(asr, ScriptedCleanup(), silence(2))
    assert asr.calls == []


def test_a_new_pass_waits_for_the_one_in_flight():
    asr, submitted = CountingASR(), []
    speech_ = Rolling(
        asr, ScriptedCleanup(), CleanupContext(), str, lambda *a: submitted.append(a) or Future()
    )
    for chunk in speech(1) + silence(0.3) + speech(0.5) + silence(0.5):
        speech_.add(chunk)
    assert len(submitted) == 1


def test_interrupted_rewrite_is_not_kept():
    cleanup, context = ScriptedCleanup(), CleanupContext()
    cancelled = threading.Event()
    cancelled.set()
    cleanup.prepare("Ship it Friday, no wait, Thursday.", context, cancelled)
    assert context.rewrites == {}


def pcm16(chunks: list[np.ndarray]) -> list[bytes]:
    return [(chunk * 32767).astype("<i2").tobytes() for chunk in chunks]


def test_server_reuses_the_pause_transcript():
    asr = CountingASR()
    with (
        TestClient(create_app(asr, PassthroughCleanup())) as client,
        client.websocket_connect("/v1/dictate") as ws,
    ):
        ws.send_json({"type": "start"})
        for data in pcm16(speech(1) + silence(0.5)):
            ws.send_bytes(data)
        ws.send_json({"type": "stop"})
        partial = ws.receive_json()
        final = ws.receive_json()

    raw = f"Ship it Friday, no wait, Thursday. Heard {asr.calls[0]}."
    assert partial == {"type": "partial", "text": raw}
    assert final["type"] == "final" and final["raw"] == raw
    assert len(asr.calls) == 1


def test_each_pause_reports_the_transcript_so_far():
    asr, seen = CountingASR(), []
    speech_ = Rolling(
        asr,
        PassthroughCleanup(),
        CleanupContext(),
        lambda text: text,
        run_now,
        lambda utterance, raw: seen.append((utterance, raw)),
    )
    for chunk in speech(1) + silence(0.3) + speech(0.5) + silence(0.3):
        speech_.add(chunk)
    assert [raw for _, raw in seen] == [
        f"Ship it Friday, no wait, Thursday. Heard {calls}." for calls in asr.calls
    ]
    assert len(seen) == 2 and all(utterance is speech_ for utterance, _ in seen)


def level(value: float, seconds: float) -> list[np.ndarray]:
    return [np.full(CHUNK, value, dtype=np.float32)] * round(seconds * 10)


def test_soft_last_words_after_a_loud_moment_are_transcribed():
    asr = CountingASR()
    chunks = level(0.9, 0.1) + speech(1) + silence(0.3) + level(0.02, 0.5) + silence(0.2)
    speech_, _ = utterance(asr, ScriptedCleanup(), chunks)
    speech_.release()
    speech_.transcript()
    assert speech_.cancelled.is_set()
    assert asr.calls[-1] == round(2.1 * SAMPLE_RATE)


def test_steady_room_noise_after_the_pause_still_counts_as_silence():
    asr = CountingASR()
    chunks = level(0.004, 0.3) + speech(1) + level(0.004, 0.3) + level(0.006, 0.5)
    speech_, _ = utterance(asr, ScriptedCleanup(), chunks)
    speech_.release()
    speech_.transcript()
    assert len(asr.calls) == 1


def test_cancelled_early_cleanup_still_reuses_the_transcript():
    asr, cleanup = CountingASR(), ScriptedCleanup()
    speech_, _ = utterance(asr, cleanup, speech(1) + silence(0.6))
    speech_.cancel()
    speech_.release()
    speech_.transcript()
    assert len(asr.calls) == 1
