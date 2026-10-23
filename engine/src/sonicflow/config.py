import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    asr: str
    cleanup: str
    host: str
    port: int

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            asr=os.environ.get("SONICFLOW_ASR", ""),
            cleanup=os.environ.get("SONICFLOW_CLEANUP", "none"),
            host=os.environ.get("SONICFLOW_HOST", "127.0.0.1"),
            port=int(os.environ.get("SONICFLOW_PORT", "8765")),
        )
