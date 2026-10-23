import argparse
import json
import platform
import re
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path

import jiwer
import numpy as np
import soundfile as sf

from sonicflow import SAMPLE_RATE
from sonicflow.backends.base import ASRBackend, CleanupBackend, CleanupContext
from sonicflow.backends.registry import create_asr, create_cleanup

REPO_ROOT = Path(__file__).resolve().parents[4]


@dataclass(frozen=True)
class CorpusItem:
    id: str
    kind: str
    spoken: str
    clean: str
    audio_path: Path


@dataclass(frozen=True)
class ItemResult:
    id: str
    kind: str
    audio_s: float
    feed_ms: float
    finalize_ms: float
    cleanup_ms: float
    raw: str
    text: str


def normalize(text: str) -> str:
    return " ".join(re.sub(r"[^\w\s']", " ", text.lower()).split())


def load_corpus(corpus_dir: Path) -> list[CorpusItem]:
    items = []
    for line in (corpus_dir / "manifest.jsonl").read_text().splitlines():
        if not line.strip():
            continue
        entry = json.loads(line)
        items.append(
            CorpusItem(
                id=entry["id"],
                kind=entry["kind"],
                spoken=entry["spoken"],
                clean=entry["clean"],
                audio_path=corpus_dir / "audio" / f"{entry['id']}.wav",
            )
        )
    missing = [item.id for item in items if not item.audio_path.exists()]
    if missing:
        sys.exit(f"missing audio for {missing}; run bench/corpus/make_corpus.sh")
    return items


def read_audio(path: Path) -> np.ndarray:
    audio, sample_rate = sf.read(path, dtype="float32")
    if sample_rate != SAMPLE_RATE or audio.ndim != 1:
        sys.exit(f"{path} must be mono {SAMPLE_RATE} Hz, got {sample_rate} Hz / {audio.ndim}D")
    return audio


def run_item(
    item: CorpusItem,
    asr: ASRBackend,
    cleanup: CleanupBackend,
    chunk_samples: int,
    realtime: bool,
) -> ItemResult:
    audio = read_audio(item.audio_path)
    stream = asr.stream()
    feed_s = 0.0
    for offset in range(0, len(audio), chunk_samples):
        chunk = audio[offset : offset + chunk_samples]
        started = time.perf_counter()
        stream.feed(chunk)
        feed_s += time.perf_counter() - started
        if realtime:
            time.sleep(max(0.0, len(chunk) / SAMPLE_RATE - (time.perf_counter() - started)))

    finalize_start = time.perf_counter()
    raw = stream.finalize()
    cleanup_start = time.perf_counter()
    text = cleanup.clean(raw, CleanupContext())
    done = time.perf_counter()

    return ItemResult(
        id=item.id,
        kind=item.kind,
        audio_s=round(len(audio) / SAMPLE_RATE, 2),
        feed_ms=round(feed_s * 1000, 1),
        finalize_ms=round((cleanup_start - finalize_start) * 1000, 1),
        cleanup_ms=round((done - cleanup_start) * 1000, 1),
        raw=raw,
        text=text,
    )


def percentiles(values: list[float]) -> dict[str, float]:
    return {
        "p50": round(float(np.percentile(values, 50)), 1),
        "p95": round(float(np.percentile(values, 95)), 1),
    }


def corpus_wer(references: list[str], hypotheses: list[str]) -> float:
    return round(
        jiwer.wer(
            [normalize(r) for r in references], [normalize(h) or "<empty>" for h in hypotheses]
        ),
        4,
    )


def machine_name() -> str:
    try:
        return subprocess.run(
            ["sysctl", "-n", "machdep.cpu.brand_string"], capture_output=True, text=True, check=True
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return platform.processor() or platform.machine()


def summarize(items: list[CorpusItem], results: list[ItemResult], load_ms: float) -> dict:
    total_audio_s = sum(r.audio_s for r in results)
    total_compute_s = sum(r.feed_ms + r.finalize_ms for r in results) / 1000
    return {
        "load_ms": load_ms,
        "finalize_ms": percentiles([r.finalize_ms for r in results]),
        "cleanup_ms": percentiles([r.cleanup_ms for r in results]),
        "release_to_text_ms": percentiles([r.finalize_ms + r.cleanup_ms for r in results]),
        "rtf": round(total_compute_s / total_audio_s, 4),
        "wer_raw_vs_spoken": corpus_wer([i.spoken for i in items], [r.raw for r in results]),
        "wer_text_vs_clean": corpus_wer([i.clean for i in items], [r.text for r in results]),
    }


def compare_to_baseline(summary: dict, baseline_path: Path, max_regression: float) -> bool:
    baseline = json.loads(baseline_path.read_text())["summary"]
    before = baseline["release_to_text_ms"]["p50"]
    after = summary["release_to_text_ms"]["p50"]
    change = (after - before) / before if before else 0.0
    print(f"release→text p50: {before} ms → {after} ms ({change:+.1%})")
    return change <= max_regression


def main() -> None:
    parser = argparse.ArgumentParser(description="Latency and accuracy benchmark for SonicFlow")
    parser.add_argument("--asr", required=True)
    parser.add_argument("--cleanup", default="none")
    parser.add_argument("--corpus", type=Path, default=REPO_ROOT / "bench" / "corpus")
    parser.add_argument("--out", type=Path, default=REPO_ROOT / "bench" / "results")
    parser.add_argument("--chunk-ms", type=int, default=100)
    parser.add_argument("--realtime", action="store_true", help="pace audio feed at speaking speed")
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--max-regression", type=float, default=0.10)
    args = parser.parse_args()

    items = load_corpus(args.corpus)
    asr = create_asr(args.asr)
    cleanup = create_cleanup(args.cleanup)

    load_start = time.perf_counter()
    asr.load()
    cleanup.load()
    load_ms = round((time.perf_counter() - load_start) * 1000, 1)

    chunk_samples = SAMPLE_RATE * args.chunk_ms // 1000
    run_item(items[0], asr, cleanup, chunk_samples, realtime=False)
    results = [run_item(item, asr, cleanup, chunk_samples, args.realtime) for item in items]
    summary = summarize(items, results, load_ms)

    for result in results:
        print(
            f"{result.id:<16} {result.finalize_ms:>8} ms  {result.cleanup_ms:>8} ms  {result.text}"
        )
    print(json.dumps(summary, indent=2))

    args.out.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y-%m-%dT%H%M%S")
    out_path = args.out / f"{stamp}-{args.asr}-{args.cleanup}.json"
    out_path.write_text(
        json.dumps(
            {
                "asr": args.asr,
                "cleanup": args.cleanup,
                "machine": machine_name(),
                "realtime": args.realtime,
                "chunk_ms": args.chunk_ms,
                "summary": summary,
                "items": [asdict(r) for r in results],
            },
            indent=2,
        )
    )
    print(f"wrote {out_path}")

    if args.baseline and not compare_to_baseline(summary, args.baseline, args.max_regression):
        sys.exit(f"latency regression beyond {args.max_regression:.0%}")
