from collections.abc import Callable

from sonicflow.backends.base import ASRBackend, CleanupBackend, CleanupContext


class PassthroughCleanup(CleanupBackend):
    name = "none"

    def clean(self, text: str, context: CleanupContext) -> str:
        return text


# Factories import their heavy dependencies lazily so only the selected backend pays load cost.
ASR_BACKENDS: dict[str, Callable[[], ASRBackend]] = {}

CLEANUP_BACKENDS: dict[str, Callable[[], CleanupBackend]] = {
    "none": PassthroughCleanup,
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
