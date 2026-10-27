"""Measures a model on this Mac when the user asks: the bench CLI runs in a subprocess, so the
model under test never shares the engine's memory or inference thread."""

import json
import logging
import re
import shutil
import subprocess
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Literal

from sonicflow.bench.cli import REPO_ROOT
from sonicflow.config import config_path
from sonicflow.models import Bench, Model

logger = logging.getLogger(__name__)

VOICE = "Samantha"


def bench_dir() -> Path:
    return config_path().parent / "bench"


def corpus_dir() -> Path:
    return bench_dir() / "corpus"


def measured() -> dict[str, Bench]:
    try:
        saved = json.loads((bench_dir() / "measured.json").read_text())
    except (OSError, ValueError):
        return {}
    return {model_id: Bench(**bench) for model_id, bench in saved.items()}


def record(model_id: str, bench: Bench) -> None:
    saved = {key: asdict(value) for key, value in measured().items()}
    saved[model_id] = asdict(bench)
    path = bench_dir() / "measured.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(saved, indent=2) + "\n")


def ensure_corpus(corpus: Path) -> None:
    """Synthesizes any missing corpus audio with macOS TTS, as bench/corpus/make_corpus.sh does."""
    manifest = corpus / "manifest.jsonl"
    if not manifest.exists():
        source = REPO_ROOT / "bench" / "corpus" / "manifest.jsonl"
        if not source.exists():
            raise FileNotFoundError("bench corpus missing; reinstall the engine")
        manifest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(source, manifest)
    audio = corpus / "audio"
    audio.mkdir(exist_ok=True)
    for line in manifest.read_text().splitlines():
        if not line.strip():
            continue
        item = json.loads(line)
        path = audio / f"{item['id']}.wav"
        if not path.exists():
            subprocess.run(
                ["say", "-v", VOICE, "-o", str(path), "--file-format=WAVE"]
                + ["--data-format=LEI16@16000", item["spoken"]],
                check=True,
            )


def bench_command(asr: str, cleanup: str, corpus: Path, out: Path) -> list[str]:
    script = Path(sys.executable).with_name("sonicflow-bench")
    paths = ["--corpus", str(corpus), "--out", str(out)]
    return [str(script), "--asr", asr, "--cleanup", cleanup, *paths]


@dataclass
class BenchJob:
    model_id: str
    state: Literal["queued", "running", "done", "error"] = "queued"
    error: str | None = None


class Benchmarks:
    """Runs one benchmark at a time, only when asked."""

    def __init__(self) -> None:
        self._jobs: dict[str, BenchJob] = {}
        self._lock = threading.Lock()
        self._executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="bench")

    def start(self, model: Model, active_asr: str) -> BenchJob:
        """ASR models run without cleanup; cleanup models run behind the active ASR model."""
        with self._lock:
            job = self._jobs.get(model.id)
            if job and job.state in ("queued", "running"):
                return job
            job = BenchJob(model.id)
            self._jobs[model.id] = job
        asr, cleanup = (model.id, "none") if model.kind == "asr" else (active_asr, model.id)
        self._executor.submit(self._run, job, model, asr, cleanup)
        return job

    def _run(self, job: BenchJob, model: Model, asr: str, cleanup: str) -> None:
        job.state = "running"
        try:
            ensure_corpus(corpus_dir())
            result = subprocess.run(
                bench_command(asr, cleanup, corpus_dir(), bench_dir() / "results"),
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                lines = result.stderr.strip().splitlines() or ["benchmark failed"]
                raise RuntimeError(lines[-1][:200])
            written = re.search(r"^wrote (.+)$", result.stdout, re.MULTILINE)
            if written is None:
                raise RuntimeError("benchmark wrote no result")
            summary = json.loads(Path(written.group(1)).read_text())["summary"]
            wer = summary["wer_raw_vs_spoken" if model.kind == "asr" else "wer_text_vs_clean"]
            record(model.id, Bench(round(summary["release_to_text_ms"]["p50"]), round(wer, 3)))
            job.state = "done"
            logger.info("benchmarked %s", model.id)
        except Exception as error:
            job.state = "error"
            job.error = str(error).splitlines()[0][:200] if str(error) else repr(error)
            logger.warning("benchmark of %s failed: %r", model.id, error)

    def status(self) -> dict[str, dict]:
        with self._lock:
            return {job.model_id: asdict(job) for job in self._jobs.values()}

    def shutdown(self) -> None:
        self._executor.shutdown(wait=False, cancel_futures=True)
