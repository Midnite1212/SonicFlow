import json
import threading
import urllib.error
import urllib.request

from sonicflow.backends.prompting import (
    PromptCleanup,
    clean_output,
    cleanup_messages,
    edit_messages,
)
from sonicflow.models import ModelNotDownloaded

OLLAMA_URL = "http://127.0.0.1:11434"


class OllamaUnavailable(RuntimeError):
    pass


def _request(path: str, payload: dict | None = None, timeout: float = 60) -> dict:
    data = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(
        OLLAMA_URL + path, data=data, headers={"Content-Type": "application/json"}
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.load(response)
    except urllib.error.URLError as error:
        raise OllamaUnavailable("Ollama is not running; open the Ollama app") from error


def pulled_models() -> list[dict]:
    """Pulled models as `{name, size}`; raises OllamaUnavailable when Ollama is not running."""
    tags = _request("/api/tags", timeout=2)
    return [{"name": m["name"], "size": m.get("size")} for m in tags.get("models", [])]


class OllamaCleanup(PromptCleanup):
    """Cleanup through a model served by Ollama on this Mac."""

    def __init__(self, name: str, model: str) -> None:
        self.name = name
        self.model = model

    def load(self) -> None:
        if self.model not in {m["name"] for m in pulled_models()}:
            raise ModelNotDownloaded(f"{self.model} is not pulled in Ollama")
        self._rewrite("Send it Friday, no wait, Thursday.")

    def _chat(self, messages: list[dict], max_tokens: int) -> str:
        response = _request(
            "/api/chat",
            {
                "model": self.model,
                "messages": messages,
                "stream": False,
                "think": False,
                # Keeps the model and its prompt cache resident between dictations.
                "keep_alive": "30m",
                "options": {"temperature": 0, "num_predict": max_tokens},
            },
        )
        return clean_output(response.get("message", {}).get("content", ""))

    def _rewrite(self, text: str, cancelled: threading.Event | None = None) -> str:
        return self._chat(cleanup_messages(text), min(2 * len(text.split()) + 16, 512))

    def edit(self, selection: str, instruction: str) -> str:
        return self._chat(
            edit_messages(selection, instruction), min(2 * len(selection.split()) + 64, 2048)
        )
