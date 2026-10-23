import numpy as np
from fastapi.testclient import TestClient

from sonicflow.backends.registry import PassthroughCleanup
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


def test_audio_before_start_is_an_error(fake_asr):
    with (
        TestClient(create_app(fake_asr, PassthroughCleanup())) as client,
        client.websocket_connect("/v1/dictate") as ws,
    ):
        ws.send_bytes(pcm16(160))
        assert ws.receive_json()["type"] == "error"
