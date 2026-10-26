import asyncio
import json
import logging
import sys
import time
from collections.abc import Callable
from concurrent.futures import Future, ThreadPoolExecutor
from contextlib import asynccontextmanager

import numpy as np
import uvicorn
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from sonicflow.backends.base import ASRBackend, ASRStream, CleanupBackend, CleanupContext
from sonicflow.backends.registry import ASR_BACKENDS, CLEANUP_BACKENDS, create_asr, create_cleanup
from sonicflow.config import Settings, save_backend_choice
from sonicflow.vocabulary import Vocabulary, common_words

logger = logging.getLogger(__name__)


def pcm16_to_float32(data: bytes) -> np.ndarray:
    return np.frombuffer(data, dtype="<i2").astype(np.float32) / 32768.0


def elapsed_ms(start: float, end: float) -> float:
    return round((end - start) * 1000, 1)


def _log_failure(future: Future) -> None:
    if (error := future.exception()) is not None:
        logger.warning("warm-up failed: %r", error)


class BackendChoice(BaseModel):
    asr: str | None = None
    cleanup: str | None = None


class Engine:
    def __init__(self, asr: ASRBackend, cleanup: CleanupBackend) -> None:
        self.asr = asr
        self.cleanup = cleanup
        self._switching = asyncio.Lock()
        # MLX and most local runtimes are not safe to drive from several threads at once.
        self._executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="inference")

    async def run[T](self, fn: Callable[..., T], *args: object) -> T:
        return await asyncio.get_running_loop().run_in_executor(self._executor, fn, *args)

    def warm_in_background(self) -> None:
        """Wakes the GPU and pages model weights back in while the user is still speaking."""
        future = self._executor.submit(self._warm)
        future.add_done_callback(_log_failure)

    def _warm(self) -> None:
        self.asr.warm()
        self.cleanup.warm()

    async def switch(self, choice: BackendChoice) -> None:
        """Loads the requested backends first and swaps only if every load succeeds."""
        async with self._switching:
            asr = create_asr(choice.asr) if choice.asr not in (None, self.asr.name) else None
            cleanup = (
                create_cleanup(choice.cleanup)
                if choice.cleanup not in (None, self.cleanup.name)
                else None
            )
            if asr is not None:
                await self.run(asr.load)
            if cleanup is not None:
                await self.run(cleanup.load)
            replaced = [old for old, new in ((self.asr, asr), (self.cleanup, cleanup)) if new]
            self.asr = asr or self.asr
            self.cleanup = cleanup or self.cleanup
            # Utterances already running hold their own references, so this only frees caches
            # once they finish; it runs on the inference thread after any queued work.
            for backend in replaced:
                await self.run(backend.unload)

    def shutdown(self) -> None:
        self._executor.shutdown(wait=True)


def create_app(asr: ASRBackend, cleanup: CleanupBackend) -> FastAPI:
    engine = Engine(asr, cleanup)

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        await engine.run(asr.load)
        await engine.run(cleanup.load)
        await engine.run(common_words)
        yield
        engine.shutdown()

    app = FastAPI(lifespan=lifespan)

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "asr": engine.asr.name, "cleanup": engine.cleanup.name}

    @app.get("/v1/backends")
    def backends() -> dict[str, dict]:
        return {
            "asr": {"active": engine.asr.name, "available": sorted(ASR_BACKENDS)},
            "cleanup": {"active": engine.cleanup.name, "available": sorted(CLEANUP_BACKENDS)},
        }

    @app.post("/v1/config")
    async def configure(choice: BackendChoice) -> dict[str, str]:
        try:
            await engine.switch(choice)
        except ValueError as error:
            raise HTTPException(status_code=400, detail=str(error)) from None
        except Exception as error:
            logger.warning("backend load failed: %r", error)
            raise HTTPException(status_code=500, detail=f"failed to load: {error}") from None
        save_backend_choice(engine.asr.name, engine.cleanup.name)
        return health()

    @app.websocket("/v1/dictate")
    async def dictate(ws: WebSocket) -> None:
        await ws.accept()
        stream: ASRStream | None = None
        cleanup = engine.cleanup
        context = CleanupContext()
        vocabulary = Vocabulary()

        async def send_error(message: str) -> None:
            await ws.send_json({"type": "error", "message": message})

        try:
            while True:
                message = await ws.receive()
                if message["type"] == "websocket.disconnect":
                    return

                if (data := message.get("bytes")) is not None:
                    if stream is None:
                        await send_error("audio received before start")
                        continue
                    partial = await engine.run(stream.feed, pcm16_to_float32(data))
                    if partial is not None:
                        await ws.send_json({"type": "partial", "text": partial})
                    continue

                event = json.loads(message["text"])
                match event.get("type"):
                    case "start":
                        stream = await engine.run(engine.asr.stream)
                        cleanup = engine.cleanup
                        engine.warm_in_background()
                        vocabulary = Vocabulary.from_event(event)
                        context = CleanupContext(
                            app_bundle_id=event.get("app"),
                            dictionary=tuple(term.term for term in vocabulary.terms),
                        )
                    case "stop":
                        if stream is None:
                            await send_error("stop received before start")
                            continue
                        stopped_at = time.perf_counter()
                        raw = await engine.run(stream.finalize)
                        asr_done_at = time.perf_counter()
                        if (snippet := vocabulary.snippet_for(raw)) is not None:
                            text = snippet
                        else:
                            spoken = vocabulary.correct(raw)
                            cleaned = await engine.run(cleanup.clean, spoken, context)
                            # Corrected again in case cleanup re-cased a term.
                            text = vocabulary.expand(vocabulary.correct(cleaned))
                        done_at = time.perf_counter()
                        stream = None
                        await ws.send_json(
                            {
                                "type": "final",
                                "raw": raw,
                                "text": text,
                                "timings": {
                                    "asr_finalize_ms": elapsed_ms(stopped_at, asr_done_at),
                                    "cleanup_ms": elapsed_ms(asr_done_at, done_at),
                                    "total_ms": elapsed_ms(stopped_at, done_at),
                                },
                            }
                        )
                    case other:
                        await send_error(f"unknown message type {other!r}")
        except WebSocketDisconnect:
            return

    return app


def main() -> None:
    settings = Settings.from_env()
    if not settings.asr:
        sys.exit("SONICFLOW_ASR is not set")
    app = create_app(create_asr(settings.asr), create_cleanup(settings.cleanup))
    uvicorn.run(app, host=settings.host, port=settings.port)
