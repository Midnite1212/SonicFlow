from collections.abc import Callable

from sonicflow.backends.base import ASRBackend, CleanupBackend, CleanupContext
from sonicflow.backends.rules import RulesCleanup
from sonicflow.models import FAMILY_KIND, Model, all_models, find, is_installed


class PassthroughCleanup(CleanupBackend):
    name = "none"

    def clean(self, text: str, context: CleanupContext) -> str:
        return text


# Factories import their heavy dependencies lazily so only the selected backend pays load cost.
def _parakeet(name: str, source: str) -> ASRBackend:
    from sonicflow.backends.parakeet import ParakeetASR

    return ParakeetASR(name, source)


def _whisper(name: str, source: str) -> ASRBackend:
    from sonicflow.backends.whisper import WhisperASR

    return WhisperASR(name, source)


def _mlx_lm(name: str, source: str) -> CleanupBackend:
    from sonicflow.backends.llm import LLMCleanup

    return LLMCleanup(name, source)


def _ollama(name: str, source: str) -> CleanupBackend:
    from sonicflow.backends.ollama import OllamaCleanup

    return OllamaCleanup(name, source)


FAMILIES: dict[str, Callable[[str, str], ASRBackend | CleanupBackend]] = {
    "parakeet": _parakeet,
    "whisper": _whisper,
    "mlx-lm": _mlx_lm,
    "ollama": _ollama,
}

# Backends that are not model files; tests also register fakes here.
ASR_BACKENDS: dict[str, Callable[[], ASRBackend]] = {}
CLEANUP_BACKENDS: dict[str, Callable[[], CleanupBackend]] = {
    "none": PassthroughCleanup,
    "rules": RulesCleanup,
}


def resolve(model_id: str) -> Model | None:
    """A known model, or an ad-hoc `family:source` id such as `whisper:/path/to/folder`."""
    if (model := find(model_id)) is not None:
        return model
    family, _, source = model_id.partition(":")
    if source and family in FAMILY_KIND:
        return Model(model_id, FAMILY_KIND[family], family, source, source, "custom")
    return None


def available(kind: str) -> list[str]:
    fixed = ASR_BACKENDS if kind == "asr" else CLEANUP_BACKENDS
    installed = [
        m.id for m in all_models() if m.kind == kind and m.family in FAMILIES and is_installed(m)
    ]
    return sorted({*fixed, *installed})


def _create(kind: str, model_id: str, fixed: dict) -> ASRBackend | CleanupBackend:
    if model_id in fixed:
        return fixed[model_id]()
    model = resolve(model_id)
    if model is None or model.kind != kind or model.family not in FAMILIES:
        raise ValueError(f"unknown {kind} model {model_id!r}; available: {available(kind)}")
    return FAMILIES[model.family](model.id, model.source)


def create_asr(model_id: str) -> ASRBackend:
    return _create("asr", model_id, ASR_BACKENDS)


def create_cleanup(model_id: str) -> CleanupBackend:
    return _create("cleanup", model_id, CLEANUP_BACKENDS)
