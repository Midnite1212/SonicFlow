import json
import logging
import os
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

DEFAULT_URL = "http://127.0.0.1:11434"

logger = logging.getLogger(__name__)


class OllamaUnavailable(RuntimeError):
    pass


def base_url() -> str:
    """Ollama, or an Ollama-compatible proxy, at `SONICFLOW_OLLAMA_URL`."""
    return os.environ.get("SONICFLOW_OLLAMA_URL", DEFAULT_URL).rstrip("/")


def _headers() -> dict[str, str]:
    """Adds a bearer token from the first line of `SONICFLOW_OLLAMA_TOKEN_FILE`, read on every
    request so a rotated token is picked up; a file keeps it out of launchd plists and `ps`."""
    headers = {"Content-Type": "application/json"}
    if path := os.environ.get("SONICFLOW_OLLAMA_TOKEN_FILE"):
        try:
            with open(path) as file:
                token = file.readline().strip()
        except OSError as error:
            raise OllamaUnavailable(f"cannot read the Ollama token file {path}") from error
        headers["Authorization"] = f"Bearer {token}"
    return headers


def _request(path: str, payload: dict | None = None, timeout: float = 60) -> dict:
    url = base_url()
    data = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(url + path, data=data, headers=_headers())
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        reason = "rejected the token" if error.code == 401 else f"answered {error.code}"
        raise OllamaUnavailable(f"Ollama at {url} {reason}") from error
    except (urllib.error.URLError, TimeoutError) as error:
        hint = "; open the Ollama app" if url == DEFAULT_URL else ""
        raise OllamaUnavailable(f"Ollama is not reachable at {url}{hint}") from error


def pulled_models() -> list[dict]:
    """Pulled models as `{name, size}`; raises OllamaUnavailable when Ollama is not running."""
    tags = _request("/api/tags", timeout=2)
    return [{"name": m["name"], "size": m.get("size")} for m in tags.get("models", [])]


class OllamaCleanup(PromptCleanup):
    """Cleanup through a model served by Ollama, on this Mac unless `SONICFLOW_OLLAMA_URL` says
    otherwise."""

    def __init__(self, name: str, model: str) -> None:
        self.name = name
        self.model = model

    def load(self) -> None:
        if self.model not in {m["name"] for m in pulled_models()}:
            raise ModelNotDownloaded(f"{self.model} is not pulled in Ollama")
        self._chat(cleanup_messages("Send it Friday, no wait, Thursday."), 32)

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
        """The text unchanged when the request fails, such as a request too long for the model,
        so the dictation still lands."""
        try:
            return self._chat(cleanup_messages(text), min(2 * len(text.split()) + 16, 512))
        except OllamaUnavailable as error:
            logger.warning("cleanup skipped: %s", error)
            return text

    def edit(self, selection: str, instruction: str) -> str:
        return self._chat(
            edit_messages(selection, instruction), min(2 * len(selection.split()) + 64, 2048)
        )
