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
from fastapi import Depends, FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from sonicflow import lan, residency, rolling
from sonicflow.backends.base import ASRBackend, ASRStream, CleanupBackend, CleanupContext
from sonicflow.backends.registry import available, create_asr, create_cleanup
from sonicflow.benchmarks import Benchmarks
from sonicflow.config import Settings, save_backend_choice
from sonicflow.downloads import Downloads
from sonicflow.model_routes import model_router
from sonicflow.models import ModelNotDownloaded
from sonicflow.speech import is_filler
from sonicflow.style import apply_style
from sonicflow.vocabulary import Vocabulary, common_words

logger = logging.getLogger(__name__)


def pcm16_to_float32(data: bytes) -> np.ndarray:
    return np.frombuffer(data, dtype="<i2").astype(np.float32) / 32768.0


def elapsed_ms(start: float, end: float) -> float:
    return round((end - start) * 1000, 1)


def _log_failure(future: Future) -> None:
    if (error := future.exception()) is not None:
        logger.warning("background inference failed: %r", error)


KEEP_WARM_S = 1.0


class CommandError(Exception):
    """A command-mode request the engine cannot carry out; reported to the client."""


class BackendChoice(BaseModel):
    asr: str | None = None
    cleanup: str | None = None


class LanChoice(BaseModel):
    enabled: bool


LOOPBACK_HOSTS = frozenset({"127.0.0.1", "localhost", "[::1]"})


def from_this_mac(request: Request) -> None:
    """Refuses browsers, including pages that rebind their own domain to 127.0.0.1, since the
    sharing controls hand out the pairing token."""
    host = request.headers.get("host", "").rsplit(":", 1)[0]
    if host not in LOOPBACK_HOSTS or "origin" in request.headers:
        raise HTTPException(status_code=403, detail="only SonicFlow on this Mac may change sharing")


class Engine:
    def __init__(self, asr: ASRBackend, cleanup: CleanupBackend) -> None:
        self.asr = asr
        self.cleanup = cleanup
        self._switching = asyncio.Lock()
        self._warmed_at = 0.0
        self._locked: dict[int, list[residency.Region]] = {}
        # MLX and most local runtimes are not safe to drive from several threads at once.
        self._executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="inference")

    def load(self, backend: ASRBackend | CleanupBackend) -> None:
        """Loads on the inference thread and locks the weights in RAM (see residency)."""
        backend.load()
        if residency.enabled():
            self._locked[id(backend)] = residency.lock(backend.arrays())

    def unload(self, backend: ASRBackend | CleanupBackend) -> None:
        residency.unlock(self._locked.pop(id(backend), []))
        backend.unload()

    async def run[T](self, fn: Callable[..., T], *args: object) -> T:
        return await asyncio.get_running_loop().run_in_executor(self._executor, fn, *args)

    def submit(self, fn: Callable[..., object], *args: object) -> Future:
        """Queues work on the inference thread without waiting for it."""
        future = self._executor.submit(fn, *args)
        future.add_done_callback(_log_failure)
        return future

    def warm_in_background(self) -> None:
        """Wakes the GPU and pages model weights back in while the user is still speaking."""
        self._warmed_at = time.monotonic()
        self.submit(self._warm)

    def keep_warm(self) -> None:
        """Repeats the warm-up while audio streams in, since an idle GPU clocks down within a
        second or two and the cleanup that follows release runs slower."""
        if time.monotonic() - self._warmed_at >= KEEP_WARM_S:
            self.warm_in_background()

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
                await self.run(self.load, asr)
            if cleanup is not None:
                await self.run(self.load, cleanup)
            replaced = [old for old, new in ((self.asr, asr), (self.cleanup, cleanup)) if new]
            self.asr = asr or self.asr
            self.cleanup = cleanup or self.cleanup
            # Utterances already running hold their own references, so this only frees caches
            # once they finish; it runs on the inference thread after any queued work.
            for backend in replaced:
                await self.run(self.unload, backend)

    def shutdown(self) -> None:
        self._executor.shutdown(wait=True)


def create_app(asr: ASRBackend, cleanup: CleanupBackend, lan_port: int = 8766) -> FastAPI:
    engine = Engine(asr, cleanup)

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        await engine.run(residency.limit_cache)
        await engine.run(engine.load, asr)
        await engine.run(engine.load, cleanup)
        await engine.run(common_words)
        async with sharing:
            if lan.is_enabled():
                try:
                    await lan_server.start(await asyncio.to_thread(lan.identity), lan_port)
                except Exception as error:
                    # Dictation on this Mac must not depend on the network listener.
                    logger.warning("could not serve the network: %r", error)
        yield
        await lan_server.stop()
        downloads.shutdown()
        benchmarks.shutdown()
        engine.shutdown()

    downloads = Downloads()
    benchmarks = Benchmarks()
    app = FastAPI(lifespan=lifespan)
    app.include_router(model_router(engine, downloads, benchmarks))
    lan_server = lan.LanServer(app)
    # One change at a time: starting and stopping the listener and writing lan.json all await.
    sharing = asyncio.Lock()

    async def share(identity: lan.Identity) -> None:
        try:
            await lan_server.start(identity, lan_port)
        except OSError as error:
            raise HTTPException(
                status_code=409,
                detail=f"could not listen on port {lan_port}: {error.strerror or error}",
            ) from None

    async def lan_status() -> dict:
        if not lan_server.running:
            return {"enabled": False}
        identity = await asyncio.to_thread(lan.identity)
        host = await asyncio.to_thread(lan.host_name)
        return {
            "enabled": True,
            "host": host,
            "port": lan_server.port,
            "code": lan.pairing_code(identity, host, lan_server.port),
        }

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "asr": engine.asr.name, "cleanup": engine.cleanup.name}

    @app.get("/v1/backends")
    def backends() -> dict[str, dict]:
        return {
            "asr": {"active": engine.asr.name, "available": available("asr")},
            "cleanup": {"active": engine.cleanup.name, "available": available("cleanup")},
        }

    @app.post("/v1/config")
    async def configure(choice: BackendChoice) -> dict[str, str]:
        try:
            await engine.switch(choice)
        except ValueError as error:
            raise HTTPException(status_code=400, detail=str(error)) from None
        except ModelNotDownloaded as error:
            raise HTTPException(status_code=409, detail=f"{error}; download it first") from None
        except Exception as error:
            logger.warning("backend load failed: %r", error)
            raise HTTPException(status_code=500, detail=f"failed to load: {error}") from None
        save_backend_choice(engine.asr.name, engine.cleanup.name)
        return health()

    # Only the loopback listener reaches these; lan.RequireToken refuses them on the network.
    @app.get("/v1/lan", dependencies=[Depends(from_this_mac)])
    async def get_lan() -> dict:
        async with sharing:
            return await lan_status()

    @app.post("/v1/lan", dependencies=[Depends(from_this_mac)])
    async def set_lan(choice: LanChoice) -> dict:
        async with sharing:
            if choice.enabled:
                await share(await asyncio.to_thread(lan.identity))
            else:
                await lan_server.stop()
            lan.set_enabled(choice.enabled)
            return await lan_status()

    @app.post("/v1/lan/reset", dependencies=[Depends(from_this_mac)])
    async def reset_lan() -> dict:
        async with sharing:
            identity = await asyncio.to_thread(lan.identity, True)
            if lan_server.running:
                await share(identity)
            return await lan_status()

    @app.websocket("/v1/dictate")
    async def dictate(ws: WebSocket) -> None:
        await ws.accept()
        stream: ASRStream | None = None
        speech: rolling.Rolling | None = None
        cleanup = engine.cleanup
        context = CleanupContext()
        vocabulary = Vocabulary()
        style: str | None = None

        async def send_error(message: str) -> None:
            await ws.send_json({"type": "error", "message": message})

        async def finish(raw: str, selection: object) -> str:
            if isinstance(selection, str) and selection.strip():
                if not raw.strip():
                    raise CommandError("no instruction heard")
                try:
                    return vocabulary.correct(await engine.run(cleanup.edit, selection, raw))
                except NotImplementedError as error:
                    raise CommandError(str(error)) from None
            if not raw.strip():
                return ""
            if (snippet := vocabulary.snippet_for(raw)) is not None:
                return snippet
            cleaned = await engine.run(cleanup.clean, vocabulary.correct(raw), context)
            # Corrected again in case cleanup re-cased a term.
            styled = apply_style(vocabulary.correct(cleaned), style, frozenset(context.dictionary))
            return vocabulary.expand(styled)

        try:
            while True:
                message = await ws.receive()
                if message["type"] == "websocket.disconnect":
                    return

                if (data := message.get("bytes")) is not None:
                    if stream is None:
                        await send_error("audio received before start")
                        continue
                    engine.keep_warm()
                    if speech is not None:
                        # Rolling keeps the audio itself, so this loop never waits on inference
                        # and reads `stop` the moment it arrives.
                        speech.add(pcm16_to_float32(data))
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
                        style = event.get("style")
                        context = CleanupContext(
                            app_bundle_id=event.get("app"),
                            dictionary=tuple(term.term for term in vocabulary.terms),
                        )
                        if speech is not None:
                            speech.cancel()
                        speech = (
                            rolling.Rolling(
                                engine.asr, cleanup, context, vocabulary.correct, engine.submit
                            )
                            if engine.asr.rolling and rolling.enabled()
                            else None
                        )
                    case "stop":
                        if stream is None:
                            await send_error("stop received before start")
                            continue
                        stopped_at = time.perf_counter()
                        if speech is not None:
                            selection = event.get("selection")
                            if isinstance(selection, str) and selection.strip():
                                # A command's words are an instruction, never cleaned up.
                                speech.cancel()
                            speech.release()
                            raw = await engine.run(speech.transcript)
                        else:
                            raw = await engine.run(stream.finalize)
                        speech = None
                        if is_filler(raw):
                            raw = ""
                        asr_done_at = time.perf_counter()
                        stream = None
                        try:
                            text = await finish(raw, event.get("selection"))
                        except CommandError as error:
                            await send_error(str(error))
                            continue
                        done_at = time.perf_counter()
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
        finally:
            # Work for an utterance that never finished must not hold up the next one.
            if speech is not None:
                speech.cancel()

    return app


def main() -> None:
    settings = Settings.from_env()
    if not settings.asr:
        sys.exit("SONICFLOW_ASR is not set")
    app = create_app(create_asr(settings.asr), create_cleanup(settings.cleanup), settings.lan_port)
    uvicorn.run(app, host=settings.host, port=settings.port)
