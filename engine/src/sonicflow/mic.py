import argparse
import json
import queue
import subprocess
import sys
import threading
import time
from collections import deque

import sounddevice as sd
from pynput import keyboard
from websockets.exceptions import WebSocketException
from websockets.sync.client import ClientConnection, connect

from sonicflow import SAMPLE_RATE
from sonicflow.hotkey import HoldToTalk

OPTION_KEYS = {keyboard.Key.alt, keyboard.Key.alt_l, keyboard.Key.alt_r, keyboard.Key.alt_gr}
CHUNK_SAMPLES = SAMPLE_RATE // 10
PREROLL_CHUNKS = 2
START_SOUND = "/System/Library/Sounds/Tink.aiff"


def chime() -> None:
    subprocess.Popen(["afplay", START_SOUND], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def paste(text: str, typer: keyboard.Controller) -> None:
    previous = subprocess.run(["pbpaste"], capture_output=True, text=True).stdout
    subprocess.run(["pbcopy"], input=text, text=True, check=True)
    with typer.pressed(keyboard.Key.cmd):
        typer.tap("v")
    # Restoring too early would paste the old clipboard; only text clipboards can be restored.
    if previous:
        threading.Timer(
            0.5, lambda: subprocess.run(["pbcopy"], input=previous, text=True, check=False)
        ).start()


def await_final(ws: ClientConnection) -> dict:
    while True:
        message = json.loads(ws.recv())
        if message["type"] in ("final", "error"):
            return message


def run(url: str, should_paste: bool) -> None:
    events: queue.Queue[tuple[str, bytes | None]] = queue.Queue()

    def on_audio(indata, frames, time_info, status) -> None:
        events.put(("audio", bytes(indata)))

    hold = HoldToTalk(
        OPTION_KEYS,
        on_start=lambda: events.put(("start", None)),
        on_stop=lambda: events.put(("stop", None)),
        on_cancel=lambda: events.put(("cancel", None)),
    )
    typer = keyboard.Controller()
    preroll: deque[bytes] = deque(maxlen=PREROLL_CHUNKS)
    recording = False

    with (
        connect(url, max_size=None) as ws,
        sd.RawInputStream(
            samplerate=SAMPLE_RATE,
            channels=1,
            dtype="int16",
            blocksize=CHUNK_SAMPLES,
            callback=on_audio,
        ),
        keyboard.Listener(on_press=hold.press, on_release=hold.release) as listener,
    ):
        if not getattr(listener, "IS_TRUSTED", True):
            sys.exit(
                "Key events are blocked. Allow your terminal under System Settings → "
                "Privacy & Security → Accessibility and Input Monitoring, then restart it."
            )
        print("Ready. Hold Option to dictate; Ctrl+C to quit.")

        while True:
            kind, payload = events.get()
            match kind:
                case "audio":
                    if recording:
                        ws.send(payload)
                    else:
                        preroll.append(payload)
                case "start":
                    recording = True
                    chime()
                    ws.send(json.dumps({"type": "start"}))
                    for chunk in preroll:
                        ws.send(chunk)
                    preroll.clear()
                    print("● listening…", end="\r", flush=True)
                case "stop" | "cancel":
                    recording = False
                    released_at = time.perf_counter()
                    ws.send(json.dumps({"type": "stop"}))
                    final = await_final(ws)
                    round_trip_ms = (time.perf_counter() - released_at) * 1000
                    if kind == "cancel":
                        print(" " * 20, end="\r", flush=True)
                        continue
                    if final["type"] == "error":
                        print(f"error: {final['message']}")
                        continue
                    timings = final["timings"]
                    print(
                        f"[{round_trip_ms:.0f} ms · asr {timings['asr_finalize_ms']:.0f}"
                        f" · cleanup {timings['cleanup_ms']:.0f}] {final['text']}"
                    )
                    if should_paste and final["text"]:
                        paste(final["text"], typer)


def main() -> None:
    parser = argparse.ArgumentParser(description="Hold Option to dictate into the focused app")
    parser.add_argument("--url", default="ws://127.0.0.1:8765/v1/dictate")
    parser.add_argument("--no-paste", action="store_true", help="print only; don't paste")
    args = parser.parse_args()
    try:
        run(args.url, should_paste=not args.no_paste)
    except (ConnectionRefusedError, WebSocketException) as error:
        sys.exit(
            f"cannot reach the engine at {args.url} ({error}); start it with `uv run sonicflow`"
        )
    except KeyboardInterrupt:
        pass
