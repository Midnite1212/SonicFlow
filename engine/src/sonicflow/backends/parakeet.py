import mlx.core as mx
import numpy as np
from mlx.utils import tree_flatten
from parakeet_mlx import BaseParakeet, from_pretrained
from parakeet_mlx.audio import get_logmel

from sonicflow.backends.base import ASRBackend
from sonicflow.models import local_path
from sonicflow.speech import is_unsure_fragment


class ParakeetASR(ASRBackend):
    def __init__(self, name: str, repo_id: str) -> None:
        self.name = name
        self.repo_id = repo_id
        self._model: BaseParakeet | None = None

    def load(self) -> None:
        self._model = from_pretrained(local_path(self.repo_id))
        self.transcribe(np.zeros(self.sample_rate, dtype=np.float32))

    def unload(self) -> None:
        self._model = None
        mx.clear_cache()

    def arrays(self) -> list:
        return [] if self._model is None else [a for _, a in tree_flatten(self._model.parameters())]

    def transcribe(self, audio: np.ndarray) -> str:
        assert self._model is not None, "load() must run before transcribe()"
        config = self._model.preprocessor_config
        if len(audio) < config.hop_length:
            return ""
        mel = get_logmel(mx.array(audio), config)
        result = self._model.generate(mel)[0]
        text = result.text.strip()
        if is_unsure_fragment(text, [token.confidence for token in result.tokens]):
            return ""
        return text
