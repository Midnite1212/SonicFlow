import json
import sys
import time

import pytest
from fastapi.testclient import TestClient

from sonicflow import benchmarks
from sonicflow.backends.registry import PassthroughCleanup
from sonicflow.models import Bench, find
from sonicflow.server import create_app


@pytest.fixture(autouse=True)
def isolated_config(tmp_path, monkeypatch):
    monkeypatch.setenv("SONICFLOW_CONFIG", str(tmp_path / "config.json"))


def fake_bench(result: dict | None, exit_code: int = 0):
    """A stand-in bench CLI that writes `result` and prints where, like the real one."""

    def command(asr, cleanup, corpus, out):
        out.mkdir(parents=True, exist_ok=True)
        path = out / f"{asr}-{cleanup}.json"
        script = (
            f"import pathlib, sys; pathlib.Path({str(path)!r}).write_text({json.dumps(result)!r}); "
            f"print('wrote {path}'); sys.exit({exit_code})"
        )
        return [sys.executable, "-c", script]

    return command


def wait_for(benches: benchmarks.Benchmarks, model_id: str) -> dict:
    for _ in range(200):
        job = benches.status()[model_id]
        if job["state"] in ("done", "error"):
            return job
        time.sleep(0.02)
    raise TimeoutError(model_id)


SUMMARY = {
    "summary": {
        "release_to_text_ms": {"p50": 241.6},
        "wer_raw_vs_spoken": 0.0134,
        "wer_text_vs_clean": 0.021,
    }
}


def test_asr_and_cleanup_models_record_their_own_numbers(monkeypatch):
    monkeypatch.setattr(benchmarks, "ensure_corpus", lambda corpus: None)
    monkeypatch.setattr(benchmarks, "bench_command", fake_bench(SUMMARY))
    benches = benchmarks.Benchmarks()
    benches.start(find("whisper-small"), active_asr="parakeet-v2")
    assert wait_for(benches, "whisper-small")["state"] == "done"
    benches.start(find("qwen3-1.7b"), active_asr="parakeet-v2")
    assert wait_for(benches, "qwen3-1.7b")["state"] == "done"
    assert benchmarks.measured() == {
        "whisper-small": Bench(242, 0.013),
        "qwen3-1.7b": Bench(242, 0.021),
    }


def test_failed_benchmark_reports_the_error(monkeypatch):
    monkeypatch.setattr(benchmarks, "ensure_corpus", lambda corpus: None)
    monkeypatch.setattr(benchmarks, "bench_command", fake_bench(None, exit_code=3))
    benches = benchmarks.Benchmarks()
    benches.start(find("qwen3-1.7b"), active_asr="parakeet-v2")
    job = wait_for(benches, "qwen3-1.7b")
    assert job["state"] == "error"
    assert benchmarks.measured() == {}


def test_corpus_audio_is_synthesized_once(tmp_path, monkeypatch):
    spoken = []

    def fake_say(command, check):
        spoken.append(command[-1])
        open(command[command.index("-o") + 1], "wb").close()

    monkeypatch.setattr(benchmarks.subprocess, "run", fake_say)
    benchmarks.ensure_corpus(tmp_path / "corpus")
    benchmarks.ensure_corpus(tmp_path / "corpus")
    lines = (tmp_path / "corpus" / "manifest.jsonl").read_text().splitlines()
    assert len(spoken) == len([line for line in lines if line.strip()])


def test_local_benchmark_replaces_the_shipped_one(fake_asr, monkeypatch):
    benchmarks.record("qwen3-4b", Bench(401, 0.009))
    monkeypatch.setattr("sonicflow.model_routes.is_installed", lambda m: m.id != "whisper-small")
    with TestClient(create_app(fake_asr, PassthroughCleanup())) as client:
        models = {m["id"]: m for m in client.get("/v1/models").json()["models"]}
        assert client.post("/v1/models/bench", json={"id": "whisper-small"}).status_code == 400
    assert models["qwen3-4b"]["bench"] == {"p50_ms": 401, "wer": 0.009, "local": True}
    assert models["qwen3-1.7b"]["bench"] == {"p50_ms": 234, "wer": 0.023}
    assert models["qwen3-4b"]["benchmark"] is None
