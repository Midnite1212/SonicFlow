import mlx.core as mx
import numpy as np
from parakeet_mlx import BaseParakeet, from_pretrained
from parakeet_mlx.audio import get_logmel

from sonicflow.backends.base import ASRBackend


class ParakeetASR(ASRBackend):
    def __init__(self, name: str, repo_id: str) -> None:
        self.name = name
        self.repo_id = repo_id
        self._model: BaseParakeet | None = None

    def load(self) -> None:
        self._model = from_pretrained(self.repo_id)
        self.transcribe(np.zeros(self.sample_rate, dtype=np.float32))

    def transcribe(self, audio: np.ndarray) -> str:
        assert self._model is not None, "load() must run before transcribe()"
        config = self._model.preprocessor_config
        if len(audio) < config.hop_length:
            return ""
        mel = get_logmel(mx.array(audio), config)
        return self._model.generate(mel)[0].text.strip()
