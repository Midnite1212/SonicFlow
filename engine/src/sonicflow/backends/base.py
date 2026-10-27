from abc import ABC, abstractmethod
from dataclasses import dataclass, field

import numpy as np

from sonicflow import SAMPLE_RATE


class ASRStream:
    """Buffers audio and transcribes once on finalize; streaming backends override this."""

    def __init__(self, backend: "ASRBackend") -> None:
        self._backend = backend
        self._chunks: list[np.ndarray] = []

    def feed(self, chunk: np.ndarray) -> str | None:
        """Accepts float32 mono audio; returns a partial transcript when one is available."""
        self._chunks.append(chunk)
        return None

    def finalize(self) -> str:
        if not self._chunks:
            return ""
        return self._backend.transcribe(np.concatenate(self._chunks))


class ASRBackend(ABC):
    name: str
    sample_rate: int = SAMPLE_RATE

    def load(self) -> None:
        pass

    @abstractmethod
    def transcribe(self, audio: np.ndarray) -> str: ...

    def warm(self) -> None:
        self.transcribe(np.zeros(self.sample_rate // 2, dtype=np.float32))

    def unload(self) -> None:
        pass

    def arrays(self) -> list:
        """MLX arrays to keep in RAM between dictations: the loaded model's weights."""
        return []

    def stream(self) -> ASRStream:
        return ASRStream(self)


@dataclass(frozen=True)
class CleanupContext:
    app_bundle_id: str | None = None
    dictionary: tuple[str, ...] = field(default_factory=tuple)


class CleanupBackend(ABC):
    name: str

    def load(self) -> None:
        pass

    def warm(self) -> None:
        pass

    def unload(self) -> None:
        pass

    def arrays(self) -> list:
        """MLX arrays to keep in RAM between dictations: the loaded model's weights."""
        return []

    @abstractmethod
    def clean(self, text: str, context: CleanupContext) -> str: ...

    def edit(self, selection: str, instruction: str) -> str:
        """Rewrites `selection` as the spoken `instruction` asks (command mode)."""
        raise NotImplementedError(f"command mode needs an LLM cleanup model, not {self.name!r}")
