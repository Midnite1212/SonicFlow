import json

import pytest
from fastapi.testclient import TestClient

from sonicflow import model_routes
from sonicflow.backends.registry import PassthroughCleanup, available, resolve
from sonicflow.models import (
    ModelNotDownloaded,
    family_from_config,
    find,
    folder_family,
    load_custom,
    local_path,
)
from sonicflow.server import create_app


@pytest.fixture(autouse=True)
def isolated_config(tmp_path, monkeypatch):
    monkeypatch.setenv("SONICFLOW_CONFIG", str(tmp_path / "config.json"))


def make_folder(tmp_path, config: dict, weights: bool = True):
    folder = tmp_path / "model"
    folder.mkdir()
    (folder / "config.json").write_text(json.dumps(config))
    if weights:
        (folder / "model.safetensors").write_bytes(b"x" * 10)
    return folder


def test_family_from_config():
    assert family_from_config({"n_mels": 128, "n_audio_ctx": 1500}) == "whisper"
    assert family_from_config({"joint": {}, "encoder": {}, "decoder": {}}) == "parakeet"
    assert family_from_config({"model_type": "qwen3"}) == "mlx-lm"
    assert family_from_config({"foo": 1}) is None


def test_folder_needs_config_and_weights(tmp_path):
    assert folder_family(make_folder(tmp_path, {"model_type": "llama"}, weights=False)) is None
    (tmp_path / "model" / "model.safetensors").write_bytes(b"x")
    assert folder_family(tmp_path / "model") == "mlx-lm"


def test_local_path_never_downloads(tmp_path):
    assert local_path(str(tmp_path)) == str(tmp_path)
    with pytest.raises(ModelNotDownloaded):
        local_path("sonicflow-test/definitely-not-cached")


def test_resolve_known_ids_and_family_specs():
    assert resolve("qwen3-4b").family == "mlx-lm"
    assert resolve("whisper-small").group == "catalog"
    adhoc = resolve("whisper:/tmp/my-whisper")
    assert (adhoc.kind, adhoc.family, adhoc.source) == ("asr", "whisper", "/tmp/my-whisper")
    assert resolve("nonsense") is None
    assert resolve("mystery:thing") is None


def test_available_lists_fixed_backends_and_installed_models(monkeypatch):
    monkeypatch.setattr("sonicflow.backends.registry.is_installed", lambda m: m.id == "qwen3-0.6b")
    assert available("cleanup") == ["none", "qwen3-0.6b", "rules"]


@pytest.fixture
def client(fake_asr):
    return TestClient(create_app(fake_asr, PassthroughCleanup()))


def test_list_marks_groups_and_active(client):
    with client:
        body = client.get("/v1/models").json()
    assert body["active"] == {"asr": "fake", "cleanup": "none"}
    groups = {m["id"]: m["group"] for m in body["models"]}
    assert groups["parakeet-v2"] == "recommended"
    assert groups["whisper-small"] == "catalog"
    assert next(m for m in body["models"] if m["id"] == "qwen3-4b")["bench"]["p50_ms"] == 365


def test_add_and_remove_a_local_folder(client, tmp_path):
    folder = make_folder(tmp_path, {"n_mels": 80, "n_audio_ctx": 1500})
    with client:
        added = client.post(
            "/v1/models/custom", json={"source": str(folder), "title": "My Whisper"}
        )
        assert added.status_code == 200
        assert added.json()["id"] == f"whisper:{folder}"
        assert added.json()["installed"] is True
        assert [m.title for m in load_custom()] == ["My Whisper"]
        assert client.post("/v1/models/remove", json={"id": f"whisper:{folder}"}).status_code == 200
    assert load_custom() == []
    assert folder.is_dir()


def test_rejects_bad_sources(client, tmp_path):
    with client:
        not_model = make_folder(tmp_path, {"foo": 1})
        assert client.post("/v1/models/custom", json={"source": str(not_model)}).status_code == 400
        assert client.post("/v1/models/custom", json={"source": "justaword"}).status_code == 400
        assert client.post("/v1/models/custom", json={"source": "/no/such/dir"}).status_code == 400


def test_hub_repo_is_checked_for_mlx(client, monkeypatch):
    def fake_inspect(repo):
        if repo == "openai/whisper-small":
            raise ValueError("this is a PyTorch Whisper model")
        return "mlx-lm", 1234

    monkeypatch.setattr(model_routes, "inspect_hub_repo", fake_inspect)
    with client:
        ok = client.post("/v1/models/custom", json={"source": "someone/tiny-mlx"})
        assert ok.json()["id"] == "mlx-lm:someone/tiny-mlx"
        assert ok.json()["size_bytes"] == 1234
        bad = client.post("/v1/models/custom", json={"source": "openai/whisper-small"})
        assert bad.status_code == 400 and "PyTorch" in bad.json()["detail"]
    assert find("mlx-lm:someone/tiny-mlx").group == "custom"


def test_cannot_remove_active_or_download_builtins(client):
    with client:
        assert client.post("/v1/models/download", json={"id": "rules"}).status_code == 400
        assert client.post("/v1/models/remove", json={"id": "none"}).status_code == 409
        assert client.post("/v1/models/remove", json={"id": "nope"}).status_code == 404


def test_download_runs_in_background(client, monkeypatch):
    started = []
    monkeypatch.setattr(
        "sonicflow.downloads.Downloads.start",
        lambda self, model: (
            started.append(model.id) or type("J", (), {"__dict__": {"state": "queued"}})()
        ),
    )
    with client:
        response = client.post("/v1/models/download", json={"id": "whisper-tiny"})
    assert response.status_code == 202
    assert started == ["whisper-tiny"]


def test_switching_to_a_missing_download_is_409(client):
    with client:
        response = client.post("/v1/config", json={"asr": "whisper-large-v3"})
    assert response.status_code == 409
    assert "not downloaded" in response.json()["detail"]


def test_snapshot_without_weights_is_not_installed(tmp_path, monkeypatch):
    snapshot = tmp_path / "snap"
    snapshot.mkdir()
    (snapshot / "config.json").write_text("{}")
    monkeypatch.setattr("huggingface_hub.snapshot_download", lambda *a, **k: str(snapshot))
    with pytest.raises(ModelNotDownloaded):
        local_path("org/partial")
    (snapshot / "model.safetensors").write_bytes(b"x")
    assert local_path("org/partial") == str(snapshot)
