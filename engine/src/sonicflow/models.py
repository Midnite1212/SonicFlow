"""Every model the engine can run: tested defaults, a curated download list, and the user's own."""

import json
import os
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Literal

from sonicflow.config import config_path

Kind = Literal["asr", "cleanup"]

# Families name the runtime that loads a model; each maps to one backend class.
FAMILY_KIND: dict[str, Kind] = {
    "parakeet": "asr",
    "whisper": "asr",
    "mlx-lm": "cleanup",
    "ollama": "cleanup",
}


@dataclass(frozen=True)
class Bench:
    """Measured on an M3 Pro over the 22-item corpus; see docs/LATENCY.md."""

    p50_ms: int
    wer: float


@dataclass(frozen=True)
class Model:
    id: str
    kind: Kind
    family: str
    source: str
    title: str
    group: Literal["recommended", "catalog", "custom"]
    size_bytes: int | None = None
    note: str = ""
    bench: Bench | None = None

    @property
    def is_local_folder(self) -> bool:
        return self.source.startswith("/")

    def to_dict(self) -> dict:
        data = asdict(self)
        data["bench"] = asdict(self.bench) if self.bench else None
        return data


def _gb(value: float) -> int:
    return int(value * 1e9)


RECOMMENDED: tuple[Model, ...] = (
    Model(
        "parakeet-v2",
        "asr",
        "parakeet",
        "mlx-community/parakeet-tdt-0.6b-v2",
        "Parakeet TDT 0.6B v2",
        "recommended",
        _gb(2.47),
        "Default. Fastest and most accurate English model tested.",
        Bench(115, 0.049),
    ),
    Model(
        "parakeet-v3",
        "asr",
        "parakeet",
        "mlx-community/parakeet-tdt-0.6b-v3",
        "Parakeet TDT 0.6B v3",
        "recommended",
        _gb(2.51),
        "Adds 24 European languages at the same speed.",
        Bench(115, 0.049),
    ),
    Model(
        "whisper-turbo",
        "asr",
        "whisper",
        "mlx-community/whisper-large-v3-turbo",
        "Whisper large-v3 turbo",
        "recommended",
        _gb(1.61),
        "Multilingual, including Chinese and Japanese; about five times slower.",
        Bench(588, 0.059),
    ),
    Model(
        "qwen3-4b",
        "cleanup",
        "mlx-lm",
        "mlx-community/Qwen3-4B-Instruct-2507-4bit",
        "Qwen3 4B Instruct",
        "recommended",
        _gb(2.28),
        "Default. Most accurate self-correction cleanup.",
        Bench(365, 0.027),
    ),
    Model(
        "qwen3-1.7b",
        "cleanup",
        "mlx-lm",
        "mlx-community/Qwen3-1.7B-4bit",
        "Qwen3 1.7B",
        "recommended",
        _gb(0.98),
        "Faster cleanup with slightly more misses.",
        Bench(230, 0.042),
    ),
    Model(
        "rules",
        "cleanup",
        "builtin",
        "",
        "Rules only",
        "recommended",
        0,
        "No model: removes fillers and fixes spacing, ~0 ms.",
        Bench(113, 0.153),
    ),
    Model(
        "none",
        "cleanup",
        "builtin",
        "",
        "No cleanup",
        "recommended",
        0,
        "Pastes the raw transcript.",
        Bench(115, 0.176),
    ),
)

CATALOG: tuple[Model, ...] = (
    Model(
        "whisper-tiny",
        "asr",
        "whisper",
        "mlx-community/whisper-tiny-mlx",
        "Whisper tiny",
        "catalog",
        _gb(0.07),
        "Smallest multilingual model; low accuracy.",
    ),
    Model(
        "whisper-base",
        "asr",
        "whisper",
        "mlx-community/whisper-base-mlx",
        "Whisper base",
        "catalog",
        _gb(0.14),
        "Small multilingual model.",
    ),
    Model(
        "whisper-small",
        "asr",
        "whisper",
        "mlx-community/whisper-small-mlx",
        "Whisper small",
        "catalog",
        _gb(0.48),
        "Balanced multilingual model.",
    ),
    Model(
        "whisper-medium",
        "asr",
        "whisper",
        "mlx-community/whisper-medium-mlx",
        "Whisper medium",
        "catalog",
        _gb(1.52),
        "Accurate multilingual model; slow.",
    ),
    Model(
        "whisper-large-v3",
        "asr",
        "whisper",
        "mlx-community/whisper-large-v3-mlx",
        "Whisper large-v3",
        "catalog",
        _gb(3.08),
        "Most accurate Whisper; slowest.",
    ),
    Model(
        "distil-whisper-large-v3",
        "asr",
        "whisper",
        "mlx-community/distil-whisper-large-v3",
        "Distil-Whisper large-v3",
        "catalog",
        _gb(1.51),
        "English only, faster than large-v3.",
    ),
    Model(
        "parakeet-1.1b",
        "asr",
        "parakeet",
        "mlx-community/parakeet-tdt-1.1b",
        "Parakeet TDT 1.1B",
        "catalog",
        _gb(4.28),
        "Larger English Parakeet.",
    ),
    Model(
        "qwen3-0.6b",
        "cleanup",
        "mlx-lm",
        "mlx-community/Qwen3-0.6B-4bit",
        "Qwen3 0.6B",
        "catalog",
        _gb(0.35),
        "Tiny and fast; misses more corrections.",
    ),
    Model(
        "llama-3.2-1b",
        "cleanup",
        "mlx-lm",
        "mlx-community/Llama-3.2-1B-Instruct-4bit",
        "Llama 3.2 1B Instruct",
        "catalog",
        _gb(0.71),
    ),
    Model(
        "llama-3.2-3b",
        "cleanup",
        "mlx-lm",
        "mlx-community/Llama-3.2-3B-Instruct-4bit",
        "Llama 3.2 3B Instruct",
        "catalog",
        _gb(1.82),
    ),
    Model(
        "gemma-3-1b",
        "cleanup",
        "mlx-lm",
        "mlx-community/gemma-3-1b-it-4bit",
        "Gemma 3 1B",
        "catalog",
        _gb(0.77),
    ),
    Model(
        "qwen2.5-3b",
        "cleanup",
        "mlx-lm",
        "mlx-community/Qwen2.5-3B-Instruct-4bit",
        "Qwen2.5 3B Instruct",
        "catalog",
        _gb(1.75),
    ),
    Model(
        "phi-3.5-mini",
        "cleanup",
        "mlx-lm",
        "mlx-community/Phi-3.5-mini-instruct-4bit",
        "Phi-3.5 mini",
        "catalog",
        _gb(2.15),
    ),
)


def custom_models_path() -> Path:
    return config_path().parent / "models.json"


def load_custom() -> list[Model]:
    try:
        saved = json.loads(custom_models_path().read_text())
    except (OSError, ValueError):
        return []
    models = []
    for item in saved if isinstance(saved, list) else []:
        try:
            models.append(
                Model(
                    id=item["id"],
                    kind=item["kind"],
                    family=item["family"],
                    source=item["source"],
                    title=item["title"],
                    group="custom",
                    size_bytes=item.get("size_bytes"),
                )
            )
        except (KeyError, TypeError):
            continue
    return models


def save_custom(models: list[Model]) -> None:
    path = custom_models_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = ("id", "kind", "family", "source", "title", "size_bytes")
    payload = [{key: getattr(model, key) for key in fields} for model in models]
    staging = path.with_suffix(".tmp")
    staging.write_text(json.dumps(payload, indent=2) + "\n")
    staging.replace(path)


def all_models() -> list[Model]:
    return [*RECOMMENDED, *CATALOG, *load_custom()]


def find(model_id: str) -> Model | None:
    return next((model for model in all_models() if model.id == model_id), None)


def custom_id(family: str, source: str) -> str:
    return f"{family}:{source}"


def family_from_config(config: dict) -> str | None:
    """Tells the runtime a model folder needs from its config.json."""
    if "n_mels" in config and "n_audio_ctx" in config:
        return "whisper"
    if "joint" in config and "encoder" in config and "decoder" in config:
        return "parakeet"
    if "model_type" in config:
        return "mlx-lm"
    return None


def folder_family(path: Path) -> str | None:
    try:
        config = json.loads((path / "config.json").read_text())
    except (OSError, ValueError):
        return None
    return family_from_config(config) if _has_weights(path) else None


def folder_size(path: Path) -> int:
    return sum(file.stat().st_size for file in path.rglob("*") if file.is_file())


class ModelNotDownloaded(RuntimeError):
    pass


def local_path(source: str) -> str:
    """The folder holding a model's files, without touching the network.

    Loading never downloads: a Hugging Face model must have been fetched by an explicit download.
    """
    folder = Path(os.path.expanduser(source))
    if folder.is_dir():
        return str(folder)
    from huggingface_hub import snapshot_download

    try:
        snapshot = Path(snapshot_download(source, local_files_only=True))
    except Exception as error:
        raise ModelNotDownloaded(f"{source} is not downloaded") from error
    # A snapshot holding only config.json (read when the model was added) or an interrupted
    # download has no weights yet.
    if not _has_weights(snapshot):
        raise ModelNotDownloaded(f"{source} is not downloaded")
    return str(snapshot)


def _has_weights(folder: Path) -> bool:
    return any(folder.glob("*.safetensors")) or any(folder.glob("*.npz"))


def is_installed(model: Model) -> bool:
    if model.family == "builtin":
        return True
    if model.family == "ollama":
        from sonicflow.backends.ollama import OllamaUnavailable, pulled_models

        try:
            return model.source in {m["name"] for m in pulled_models()}
        except OllamaUnavailable:
            return False
    try:
        local_path(model.source)
    except ModelNotDownloaded:
        return False
    return True
