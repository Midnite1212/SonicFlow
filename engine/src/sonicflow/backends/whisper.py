import mlx.core as mx
import mlx_whisper
import numpy as np
from mlx.utils import tree_flatten
from mlx_whisper.transcribe import ModelHolder

from sonicflow.backends.base import ASRBackend
from sonicflow.models import local_path


class WhisperASR(ASRBackend):
    def __init__(self, name: str, repo_id: str) -> None:
        self.name = name
        self.repo_id = repo_id
        self._path = repo_id

    def load(self) -> None:
        self._path = local_path(self.repo_id)
        self.transcribe(np.zeros(self.sample_rate, dtype=np.float32))

    def unload(self) -> None:
        ModelHolder.model = None
        ModelHolder.model_path = None
        mx.clear_cache()

    def arrays(self) -> list:
        model = ModelHolder.model
        return [] if model is None else [a for _, a in tree_flatten(model.parameters())]

    def transcribe(self, audio: np.ndarray) -> str:
        # A single temperature disables fallback re-decoding, which would multiply latency.
        result = mlx_whisper.transcribe(
            audio,
            path_or_hf_repo=self._path,
            language="en",
            temperature=0.0,
            condition_on_previous_text=False,
        )
        return result["text"].strip()
