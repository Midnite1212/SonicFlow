import mlx_whisper
import numpy as np

from sonicflow.backends.base import ASRBackend


class WhisperASR(ASRBackend):
    def __init__(self, name: str, repo_id: str) -> None:
        self.name = name
        self.repo_id = repo_id

    def load(self) -> None:
        self.transcribe(np.zeros(self.sample_rate, dtype=np.float32))

    def transcribe(self, audio: np.ndarray) -> str:
        # A single temperature disables fallback re-decoding, which would multiply latency.
        result = mlx_whisper.transcribe(
            audio,
            path_or_hf_repo=self.repo_id,
            language="en",
            temperature=0.0,
            condition_on_previous_text=False,
        )
        return result["text"].strip()
