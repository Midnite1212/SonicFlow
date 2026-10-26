import logging
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Literal

from sonicflow.models import Model

logger = logging.getLogger(__name__)


@dataclass
class Job:
    model_id: str
    repo: str
    state: Literal["queued", "downloading", "done", "error"] = "queued"
    total_bytes: int | None = None
    error: str | None = None


def repo_cache_dir(repo: str) -> Path:
    from huggingface_hub import constants

    return Path(constants.HF_HUB_CACHE) / f"models--{repo.replace('/', '--')}"


def cached_bytes(repo: str) -> int:
    blobs = repo_cache_dir(repo) / "blobs"
    return sum(f.stat().st_size for f in blobs.iterdir() if f.is_file()) if blobs.is_dir() else 0


class Downloads:
    """Fetches Hugging Face models one at a time, off the inference thread, only when asked."""

    def __init__(self) -> None:
        self._jobs: dict[str, Job] = {}
        self._lock = threading.Lock()
        self._executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="download")

    def start(self, model: Model) -> Job:
        with self._lock:
            job = self._jobs.get(model.id)
            if job and job.state in ("queued", "downloading"):
                return job
            job = Job(model.id, model.source, total_bytes=model.size_bytes)
            self._jobs[model.id] = job
        self._executor.submit(self._run, job)
        return job

    def _run(self, job: Job) -> None:
        from huggingface_hub import HfApi, snapshot_download

        job.state = "downloading"
        try:
            info = HfApi().model_info(job.repo, files_metadata=True)
            job.total_bytes = sum(s.size or 0 for s in info.siblings or []) or job.total_bytes
            snapshot_download(job.repo)
            job.state = "done"
            logger.info("downloaded %s", job.repo)
        except Exception as error:
            job.state = "error"
            job.error = str(error).splitlines()[0][:200]
            logger.warning("download of %s failed: %r", job.repo, error)

    def status(self) -> dict[str, dict]:
        with self._lock:
            jobs = list(self._jobs.values())
        return {job.model_id: {**asdict(job), "bytes": cached_bytes(job.repo)} for job in jobs}

    def forget(self, model_id: str) -> None:
        with self._lock:
            self._jobs.pop(model_id, None)

    def shutdown(self) -> None:
        self._executor.shutdown(wait=False, cancel_futures=True)


def remove_download(repo: str) -> bool:
    """Deletes a model's files from the Hugging Face cache; False when nothing was cached."""
    from huggingface_hub import scan_cache_dir

    for cached in scan_cache_dir().repos:
        if cached.repo_id == repo:
            scan_cache_dir().delete_revisions(*(r.commit_hash for r in cached.revisions)).execute()
            return True
    return False
