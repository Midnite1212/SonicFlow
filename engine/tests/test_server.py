import numpy as np
import pytest
from conftest import FakeASR
from fastapi.testclient import TestClient

from sonicflow.backends.registry import ASR_BACKENDS, PassthroughCleanup
from sonicflow.config import load_backend_choice
from sonicflow.server import create_app, pcm16_to_float32


def pcm16(samples: int) -> bytes:
    return np.zeros(samples, dtype="<i2").tobytes()


def test_pcm16_to_float32_scales_to_unit_range():
    data = np.array([-32768, 0, 16384], dtype="<i2").tobytes()
    np.testing.assert_allclose(pcm16_to_float32(data), [-1.0, 0.0, 0.5])


def test_health_loads_backends(fake_asr):
    with TestClient(create_app(fake_asr, PassthroughCleanup())) as client:
        assert client.get("/health").json() == {"status": "ok", "asr": "fake", "cleanup": "none"}
    assert fake_asr.loaded


def test_dictate_returns_final_with_timings(fake_asr):
    with (
        TestClient(create_app(fake_asr, PassthroughCleanup())) as client,
        client.websocket_connect("/v1/dictate") as ws,
    ):
        ws.send_json({"type": "start", "app": "com.apple.TextEdit"})
        ws.send_bytes(pcm16(1600))
        ws.send_bytes(pcm16(1600))
        ws.send_json({"type": "stop"})
        final = ws.receive_json()

    assert final["type"] == "final"
    assert final["raw"] == final["text"] == "heard 3200 samples"
    assert set(final["timings"]) == {"asr_finalize_ms", "cleanup_ms", "total_ms"}
    assert fake_asr.warm_count == 1


class ScriptedASR(FakeASR):
    def __init__(self, transcript: str) -> None:
        super().__init__()
        self.transcript = transcript

    def transcribe(self, audio: np.ndarray) -> str:
        return self.transcript


class RecordingCleanup(PassthroughCleanup):
    def __init__(self) -> None:
        self.seen: list[str] = []

    def clean(self, text, context):
        self.seen.append(text)
        return text


def dictate(asr, cleanup, start: dict, stop: dict | None = None) -> dict:
    with (
        TestClient(create_app(asr, cleanup)) as client,
        client.websocket_connect("/v1/dictate") as ws,
    ):
        ws.send_json({"type": "start", **start})
        ws.send_bytes(pcm16(1600))
        ws.send_json({"type": "stop", **(stop or {})})
        return ws.receive_json()


class EditingCleanup(RecordingCleanup):
    def edit(self, selection, instruction):
        return f"{instruction.upper()}: {selection}"


def test_command_mode_edits_the_selection():
    final = dictate(
        ScriptedASR("make it loud"),
        EditingCleanup(),
        {"dictionary": ["SonicFlow"]},
        {"selection": "ship sonicflow"},
    )
    assert final["type"] == "final"
    assert final["text"] == "MAKE IT LOUD: ship SonicFlow"
    assert final["raw"] == "make it loud"


def test_command_mode_errors_without_llm_or_instruction():
    final = dictate(ScriptedASR("shorter"), PassthroughCleanup(), {}, {"selection": "text"})
    assert final == {
        "type": "error",
        "message": "command mode needs an LLM cleanup model, not 'none'",
    }
    final = dictate(ScriptedASR(" "), EditingCleanup(), {}, {"selection": "text"})
    assert final == {"type": "error", "message": "no instruction heard"}


def test_blank_selection_is_normal_dictation():
    cleanup = RecordingCleanup()
    final = dictate(ScriptedASR("hello"), cleanup, {}, {"selection": "  "})
    assert final["text"] == "hello"
    assert cleanup.seen == ["hello"]


def test_dictionary_corrects_before_cleanup_and_snippet_expands():
    cleanup = RecordingCleanup()
    final = dictate(
        ScriptedASR("Ship sonic flow, then my sign off"),
        cleanup,
        {
            "dictionary": [{"term": "SonicFlow"}],
            "snippets": [{"trigger": "my sign off", "text": "Thanks, R"}],
        },
    )
    assert cleanup.seen == ["Ship SonicFlow, then my sign off"]
    assert final["text"] == "Ship SonicFlow, then Thanks, R"


def test_style_applies_after_cleanup_and_keeps_terms():
    final = dictate(
        ScriptedASR("Priya says hi. Sounds good."),
        PassthroughCleanup(),
        {"style": "lowercase", "dictionary": ["Priya"]},
    )
    assert final["text"] == "Priya says hi. sounds good"


def test_whole_utterance_snippet_skips_cleanup():
    cleanup = RecordingCleanup()
    final = dictate(
        ScriptedASR("My email."),
        cleanup,
        {"snippets": [{"trigger": "my email", "text": "r@example.com"}]},
    )
    assert final["text"] == "r@example.com"
    assert final["raw"] == "My email."
    assert cleanup.seen == []


def test_audio_before_start_is_an_error(fake_asr):
    with (
        TestClient(create_app(fake_asr, PassthroughCleanup())) as client,
        client.websocket_connect("/v1/dictate") as ws,
    ):
        ws.send_bytes(pcm16(160))
        assert ws.receive_json()["type"] == "error"


class FailingASR(FakeASR):
    name = "broken"

    def load(self) -> None:
        raise RuntimeError("weights missing")


@pytest.fixture
def switchable(fake_asr, tmp_path, monkeypatch):
    monkeypatch.setenv("SONICFLOW_CONFIG", str(tmp_path / "config.json"))
    monkeypatch.setitem(ASR_BACKENDS, "fake", FakeASR)
    monkeypatch.setitem(ASR_BACKENDS, "broken", FailingASR)
    return TestClient(create_app(fake_asr, PassthroughCleanup()))


def test_backends_lists_active_and_available(switchable):
    with switchable as client:
        listing = client.get("/v1/backends").json()
    assert listing["asr"]["active"] == "fake"
    assert {"fake", "broken"} <= set(listing["asr"]["available"])
    assert listing["cleanup"]["active"] == "none"


def test_config_switches_cleanup_and_saves_choice(switchable, tmp_path):
    with switchable as client:
        response = client.post("/v1/config", json={"cleanup": "rules"})
        assert response.json()["cleanup"] == "rules"
        with client.websocket_connect("/v1/dictate") as ws:
            ws.send_json({"type": "start"})
            ws.send_bytes(pcm16(1600))
            ws.send_json({"type": "stop"})
            assert ws.receive_json()["text"] == "Heard 1600 samples."
    assert load_backend_choice() == {"asr": "fake", "cleanup": "rules"}


def test_failed_load_keeps_current_backend(switchable):
    with switchable as client:
        response = client.post("/v1/config", json={"asr": "broken"})
        assert response.status_code == 500
        assert client.get("/health").json()["asr"] == "fake"


def test_unknown_backend_is_rejected(switchable):
    with switchable as client:
        assert client.post("/v1/config", json={"asr": "nope"}).status_code == 400


def test_noise_transcripts_deliver_nothing():
    cleanup = RecordingCleanup()
    for transcript in ("Mm-hmm.", ""):
        final = dictate(ScriptedASR(transcript), cleanup, {})
        assert final["text"] == ""
        assert final["raw"] == ""
    assert cleanup.seen == []
