import asyncio
import json
import sys
import time
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager

import numpy as np
import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

from sonicflow.backends.base import ASRBackend, ASRStream, CleanupBackend, CleanupContext
from sonicflow.backends.registry import create_asr, create_cleanup
from sonicflow.config import Settings


def pcm16_to_float32(data: bytes) -> np.ndarray:
    return np.frombuffer(data, dtype="<i2").astype(np.float32) / 32768.0


def elapsed_ms(start: float, end: float) -> float:
    return round((end - start) * 1000, 1)


class Engine:
    def __init__(self, asr: ASRBackend, cleanup: CleanupBackend) -> None:
        self.asr = asr
        self.cleanup = cleanup
        # MLX and most local runtimes are not safe to drive from several threads at once.
        self._executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="inference")

    async def run[T](self, fn: Callable[..., T], *args: object) -> T:
        return await asyncio.get_running_loop().run_in_executor(self._executor, fn, *args)

    def shutdown(self) -> None:
        self._executor.shutdown(wait=True)


def create_app(asr: ASRBackend, cleanup: CleanupBackend) -> FastAPI:
    engine = Engine(asr, cleanup)

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        await engine.run(asr.load)
        await engine.run(cleanup.load)
        yield
        engine.shutdown()

    app = FastAPI(lifespan=lifespan)

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "asr": asr.name, "cleanup": cleanup.name}

    @app.websocket("/v1/dictate")
    async def dictate(ws: WebSocket) -> None:
        await ws.accept()
        stream: ASRStream | None = None
        context = CleanupContext()

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
                        stream = await engine.run(asr.stream)
                        context = CleanupContext(
                            app_bundle_id=event.get("app"),
                            dictionary=tuple(event.get("dictionary", ())),
                        )
                    case "stop":
                        if stream is None:
                            await send_error("stop received before start")
                            continue
                        stopped_at = time.perf_counter()
                        raw = await engine.run(stream.finalize)
                        asr_done_at = time.perf_counter()
                        text = await engine.run(cleanup.clean, raw, context)
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
