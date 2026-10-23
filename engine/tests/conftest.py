import numpy as np
import pytest

from sonicflow.backends.base import ASRBackend


class FakeASR(ASRBackend):
    name = "fake"

    def __init__(self) -> None:
        self.loaded = False
        self.transcribed_samples = 0

    def load(self) -> None:
        self.loaded = True

    def transcribe(self, audio: np.ndarray) -> str:
        self.transcribed_samples = len(audio)
        return f"heard {len(audio)} samples"


@pytest.fixture
def fake_asr() -> FakeASR:
    return FakeASR()
