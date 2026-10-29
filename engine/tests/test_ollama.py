import json
import socketserver
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

import pytest
from fastapi.testclient import TestClient

from sonicflow.backends import ollama
from sonicflow.backends.base import CleanupContext
from sonicflow.backends.ollama import OllamaCleanup, OllamaUnavailable, pulled_models
from sonicflow.backends.registry import PassthroughCleanup, create_cleanup
from sonicflow.models import ModelNotDownloaded, load_custom
from sonicflow.server import create_app


class FakeOllama(BaseHTTPRequestHandler):
    chats: list[dict] = []
    token: str | None = None
    too_long = False

    def log_message(self, *args):
        pass

    def _send(self, body: dict, status: int = 200) -> None:
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _authorized(self) -> bool:
        expected = None if FakeOllama.token is None else f"Bearer {FakeOllama.token}"
        if self.headers["Authorization"] == expected:
            return True
        self._send({"error": "unauthorized"}, 401)
        return False

    def do_GET(self):
        if self._authorized():
            self._send({"models": [{"name": "llama3.2:3b", "size": 2_000_000_000}]})

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        if not self._authorized():
            return
        if FakeOllama.too_long:
            self._send({"error": {"type": "context_length_exceeded"}}, 413)
            return
        FakeOllama.chats.append(body)
        last = body["messages"][-1]["content"]
        reply = (
            "Shorter."
            if last.startswith("Instruction:")
            else last.replace(", no wait, Thursday", "")
        )
        self._send({"message": {"role": "assistant", "content": reply + "  "}})


class QuickServer(HTTPServer):
    def server_bind(self):
        # HTTPServer.server_bind does a reverse DNS lookup that can stall for half a minute.
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = "127.0.0.1", self.server_address[1]


@pytest.fixture
def fake_ollama(monkeypatch, tmp_path):
    monkeypatch.setenv("SONICFLOW_CONFIG", str(tmp_path / "config.json"))
    server = QuickServer(("127.0.0.1", 0), FakeOllama)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    monkeypatch.setenv("SONICFLOW_OLLAMA_URL", f"http://127.0.0.1:{server.server_port}/")
    FakeOllama.chats = []
    FakeOllama.token = None
    FakeOllama.too_long = False
    yield
    server.shutdown()


def test_lists_pulled_models(fake_ollama):
    assert pulled_models() == [{"name": "llama3.2:3b", "size": 2_000_000_000}]


def test_cleanup_sends_examples_and_keeps_model_warm(fake_ollama):
    backend = create_cleanup("ollama:llama3.2:3b")
    assert isinstance(backend, OllamaCleanup)
    backend.load()
    FakeOllama.chats = []
    assert (
        backend.clean("Ship it Friday, no wait, Thursday.", CleanupContext()) == "Ship it Friday."
    )
    chat = FakeOllama.chats[0]
    assert chat["model"] == "llama3.2:3b"
    assert chat["stream"] is False and chat["keep_alive"] == "30m"
    assert chat["options"]["temperature"] == 0
    assert chat["messages"][0]["role"] == "system"
    assert len(chat["messages"]) == 18


def test_unflagged_text_never_reaches_ollama(fake_ollama):
    backend = OllamaCleanup("o", "llama3.2:3b")
    assert backend.clean("Hello there.", CleanupContext()) == "Hello there."
    assert FakeOllama.chats == []


def test_edit_uses_the_edit_prompt(fake_ollama):
    assert OllamaCleanup("o", "llama3.2:3b").edit("long text", "make it shorter") == "Shorter."


def test_missing_model_and_stopped_ollama(fake_ollama, monkeypatch):
    with pytest.raises(ModelNotDownloaded):
        OllamaCleanup("o", "mistral:7b").load()
    monkeypatch.setenv("SONICFLOW_OLLAMA_URL", "http://127.0.0.1:9")
    with pytest.raises(OllamaUnavailable, match=r"not reachable at http://127.0.0.1:9$"):
        pulled_models()
    monkeypatch.delenv("SONICFLOW_OLLAMA_URL")
    monkeypatch.setattr(ollama, "DEFAULT_URL", "http://127.0.0.1:9")
    with pytest.raises(OllamaUnavailable, match="open the Ollama app"):
        pulled_models()


def test_token_file_sends_a_bearer_token(fake_ollama, monkeypatch, tmp_path):
    FakeOllama.token = "s3cret"
    with pytest.raises(OllamaUnavailable, match="rejected the token"):
        pulled_models()
    token_file = tmp_path / "token"
    token_file.write_text("s3cret\nnext line ignored\n")
    monkeypatch.setenv("SONICFLOW_OLLAMA_TOKEN_FILE", str(token_file))
    OllamaCleanup("o", "llama3.2:3b").load()
    token_file.write_text("rotated\n")
    with pytest.raises(OllamaUnavailable, match="rejected the token"):
        pulled_models()
    monkeypatch.setenv("SONICFLOW_OLLAMA_TOKEN_FILE", str(tmp_path / "missing"))
    with pytest.raises(OllamaUnavailable, match="token file"):
        pulled_models()


def test_failed_cleanup_request_keeps_the_dictated_text(fake_ollama):
    backend = OllamaCleanup("o", "llama3.2:3b")
    backend.load()
    FakeOllama.too_long = True
    text = "Ship it Friday, no wait, Thursday."
    assert backend.clean(text, CleanupContext()) == text


def test_routes_list_and_add_ollama_models(fake_ollama, fake_asr):
    with TestClient(create_app(fake_asr, PassthroughCleanup())) as client:
        listed = client.get("/v1/models/ollama").json()
        assert listed == {
            "running": True,
            "models": [{"name": "llama3.2:3b", "size": 2_000_000_000, "added": False}],
        }
        added = client.post("/v1/models/custom", json={"source": "llama3.2:3b", "family": "ollama"})
        assert added.json()["id"] == "ollama:llama3.2:3b"
        assert added.json()["installed"] is True
        missing = client.post("/v1/models/custom", json={"source": "qwen:1b", "family": "ollama"})
        assert missing.status_code == 400 and "ollama pull" in missing.json()["detail"]
        assert client.get("/v1/models/ollama").json()["models"][0]["added"] is True
        assert (
            client.post("/v1/models/download", json={"id": "ollama:llama3.2:3b"}).status_code == 400
        )
        assert (
            client.post("/v1/models/remove", json={"id": "ollama:llama3.2:3b"}).status_code == 200
        )
    assert load_custom() == []


def test_ollama_not_running_route(fake_asr, monkeypatch, tmp_path):
    monkeypatch.setenv("SONICFLOW_CONFIG", str(tmp_path / "config.json"))
    monkeypatch.setenv("SONICFLOW_OLLAMA_URL", "http://127.0.0.1:9")
    with TestClient(create_app(fake_asr, PassthroughCleanup())) as client:
        assert client.get("/v1/models/ollama").json() == {"running": False, "models": []}
