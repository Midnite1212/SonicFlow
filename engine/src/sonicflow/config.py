import json
import os
from dataclasses import dataclass
from pathlib import Path

DEFAULT_CONFIG_PATH = Path.home() / "Library" / "Application Support" / "SonicFlow" / "config.json"


def config_path() -> Path:
    return Path(os.environ.get("SONICFLOW_CONFIG", DEFAULT_CONFIG_PATH))


def load_backend_choice() -> dict[str, str]:
    try:
        saved = json.loads(config_path().read_text())
    except (OSError, ValueError):
        return {}
    return {key: saved[key] for key in ("asr", "cleanup") if isinstance(saved.get(key), str)}


def save_backend_choice(asr: str, cleanup: str) -> None:
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    staging = path.with_suffix(".tmp")
    staging.write_text(json.dumps({"asr": asr, "cleanup": cleanup}, indent=2) + "\n")
    staging.replace(path)


@dataclass(frozen=True)
class Settings:
    asr: str
    cleanup: str
    host: str
    port: int

    @classmethod
    def from_env(cls) -> "Settings":
        """Environment variables win over the saved choice so dev runs can pick backends freely."""
        saved = load_backend_choice()
        return cls(
            asr=os.environ.get("SONICFLOW_ASR") or saved.get("asr", ""),
            cleanup=os.environ.get("SONICFLOW_CLEANUP") or saved.get("cleanup", "none"),
            host=os.environ.get("SONICFLOW_HOST", "127.0.0.1"),
            port=int(os.environ.get("SONICFLOW_PORT", "8765")),
        )
