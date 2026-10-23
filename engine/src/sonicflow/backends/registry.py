from collections.abc import Callable

from sonicflow.backends.base import ASRBackend, CleanupBackend, CleanupContext
from sonicflow.backends.rules import RulesCleanup


class PassthroughCleanup(CleanupBackend):
    name = "none"

    def clean(self, text: str, context: CleanupContext) -> str:
        return text


def _parakeet(name: str, repo_id: str) -> Callable[[], ASRBackend]:
    def factory() -> ASRBackend:
        from sonicflow.backends.parakeet import ParakeetASR

        return ParakeetASR(name, repo_id)

    return factory


def _whisper(name: str, repo_id: str) -> Callable[[], ASRBackend]:
    def factory() -> ASRBackend:
        from sonicflow.backends.whisper import WhisperASR

        return WhisperASR(name, repo_id)

    return factory


def _llm(name: str, repo_id: str) -> Callable[[], CleanupBackend]:
    def factory() -> CleanupBackend:
        from sonicflow.backends.llm import LLMCleanup

        return LLMCleanup(name, repo_id)

    return factory


# Factories import their heavy dependencies lazily so only the selected backend pays load cost.
ASR_BACKENDS: dict[str, Callable[[], ASRBackend]] = {
    "parakeet-v2": _parakeet("parakeet-v2", "mlx-community/parakeet-tdt-0.6b-v2"),
    "parakeet-v3": _parakeet("parakeet-v3", "mlx-community/parakeet-tdt-0.6b-v3"),
    "whisper-turbo": _whisper("whisper-turbo", "mlx-community/whisper-large-v3-turbo"),
}

CLEANUP_BACKENDS: dict[str, Callable[[], CleanupBackend]] = {
    "none": PassthroughCleanup,
    "rules": RulesCleanup,
    "qwen3-1.7b": _llm("qwen3-1.7b", "mlx-community/Qwen3-1.7B-4bit"),
    "qwen3-4b": _llm("qwen3-4b", "mlx-community/Qwen3-4B-Instruct-2507-4bit"),
}


def create_asr(name: str) -> ASRBackend:
    try:
        factory = ASR_BACKENDS[name]
    except KeyError:
        raise ValueError(
            f"unknown ASR backend {name!r}; available: {sorted(ASR_BACKENDS)}"
        ) from None
    return factory()


def create_cleanup(name: str) -> CleanupBackend:
    try:
        factory = CLEANUP_BACKENDS[name]
    except KeyError:
        raise ValueError(
            f"unknown cleanup backend {name!r}; available: {sorted(CLEANUP_BACKENDS)}"
        ) from None
    return factory()
