import argparse
import json
import os
import plistlib
import shutil
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

from sonicflow.backends.registry import ASR_BACKENDS, CLEANUP_BACKENDS
from sonicflow.config import Settings

LABEL = "com.sonicflow.engine"
PLIST_PATH = Path.home() / "Library" / "LaunchAgents" / f"{LABEL}.plist"
LOG_DIR = Path.home() / "Library" / "Logs" / "SonicFlow"
# Launchd agents can't read Desktop/Documents without a privacy grant, so the agent runs its own
# copy of the engine from Application Support instead of the source checkout.
APP_DIR = Path.home() / "Library" / "Application Support" / "SonicFlow"
ENGINE_SOURCE = Path(__file__).resolve().parents[2]
BACKEND_EXTRAS = ("parakeet", "whisper", "llm")


def build_plist(program: Path, asr: str, cleanup: str, log_dir: Path) -> dict:
    return {
        "Label": LABEL,
        "ProgramArguments": [str(program)],
        "WorkingDirectory": str(program.parents[2]),
        "EnvironmentVariables": {
            "SONICFLOW_ASR": asr,
            "SONICFLOW_CLEANUP": cleanup,
            # Models come from the local cache only; the engine never reaches the network.
            "HF_HUB_OFFLINE": "1",
        },
        "RunAtLoad": True,
        "KeepAlive": True,
        # Background agents are throttled by default, which shows up as dictation latency.
        "ProcessType": "Interactive",
        "StandardOutPath": str(log_dir / "engine.log"),
        "StandardErrorPath": str(log_dir / "engine.log"),
    }


def launchctl(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(["launchctl", *args], capture_output=True, text=True, check=check)


def domain() -> str:
    return f"gui/{os.getuid()}"


def is_loaded() -> bool:
    return launchctl("print", f"{domain()}/{LABEL}", check=False).returncode == 0


def unload(timeout_s: float = 15) -> None:
    """Boots the agent out and waits, since bootout returns before the job is gone."""
    if not is_loaded():
        return
    launchctl("bootout", f"{domain()}/{LABEL}", check=False)
    deadline = time.monotonic() + timeout_s
    while is_loaded():
        if time.monotonic() > deadline:
            sys.exit(f"{LABEL} did not unload within {timeout_s:.0f} s")
        time.sleep(0.2)


def health(port: int) -> dict | None:
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=1) as response:
            return json.load(response)
    except OSError:
        return None


def wait_for_health(port: int, timeout_s: float = 120) -> dict | None:
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        if (status := health(port)) is not None:
            return status
        time.sleep(1)
    return None


def deploy_engine() -> Path:
    uv = shutil.which("uv")
    if uv is None:
        sys.exit("uv is required to deploy the engine")
    venv = APP_DIR / "venv"
    python = venv / "bin" / "python"
    requirements = APP_DIR / "requirements.txt"
    extras = [arg for extra in BACKEND_EXTRAS for arg in ("--extra", extra)]

    APP_DIR.mkdir(parents=True, exist_ok=True)
    subprocess.run([uv, "venv", "-q", "--allow-existing", "-p", "3.12", str(venv)], check=True)
    subprocess.run(
        [uv, "export", "-q", "--project", str(ENGINE_SOURCE), "--frozen", "--no-dev"]
        + ["--no-emit-project", "--no-hashes", "-o", str(requirements)]
        + extras,
        check=True,
    )
    subprocess.run(
        [uv, "pip", "install", "-q", "-p", str(python), "-r", str(requirements)], check=True
    )
    subprocess.run(
        [uv, "pip", "install", "-q", "-p", str(python), "--no-deps"]
        + ["--reinstall-package", "sonicflow", str(ENGINE_SOURCE)],
        check=True,
    )
    return venv / "bin" / "sonicflow"


def install(asr: str, cleanup: str, port: int) -> None:
    if asr not in ASR_BACKENDS:
        sys.exit(f"unknown ASR backend {asr!r}; available: {sorted(ASR_BACKENDS)}")
    if cleanup not in CLEANUP_BACKENDS:
        sys.exit(f"unknown cleanup backend {cleanup!r}; available: {sorted(CLEANUP_BACKENDS)}")
    if not is_loaded() and health(port) is not None:
        sys.exit(f"another engine is already serving port {port}; stop it first")

    unload()
    print(f"deploying engine to {APP_DIR}…")
    program = deploy_engine()
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    PLIST_PATH.parent.mkdir(parents=True, exist_ok=True)
    PLIST_PATH.write_bytes(plistlib.dumps(build_plist(program, asr, cleanup, LOG_DIR)))
    launchctl("bootstrap", domain(), str(PLIST_PATH))

    print(f"installed {PLIST_PATH}; waiting for models to load…")
    status = wait_for_health(port)
    if status is None:
        sys.exit(f"engine did not come up; see {LOG_DIR / 'engine.log'}")
    print(f"running: {status}")


def uninstall() -> None:
    unload()
    PLIST_PATH.unlink(missing_ok=True)
    print("uninstalled")


def restart(port: int) -> None:
    if not is_loaded():
        sys.exit("not installed; run `sonicflow-service install`")
    launchctl("kickstart", "-k", f"{domain()}/{LABEL}")
    status = wait_for_health(port)
    print(f"running: {status}" if status else f"not healthy; see {LOG_DIR / 'engine.log'}")


def status(port: int) -> None:
    print(f"agent: {'loaded' if is_loaded() else 'not installed'} ({PLIST_PATH})")
    print(f"engine: {health(port) or 'not responding'}")
    print(f"log: {LOG_DIR / 'engine.log'}")


def main() -> None:
    port = Settings.from_env().port
    parser = argparse.ArgumentParser(description="Manage the SonicFlow background engine")
    commands = parser.add_subparsers(dest="command", required=True)
    install_parser = commands.add_parser("install", help="install and start at login")
    install_parser.add_argument("--asr", default="parakeet-v2")
    install_parser.add_argument("--cleanup", default="qwen3-4b")
    commands.add_parser("uninstall", help="stop and remove from login")
    commands.add_parser("restart", help="restart the engine")
    commands.add_parser("status", help="show agent and engine state")
    args = parser.parse_args()

    match args.command:
        case "install":
            install(args.asr, args.cleanup, port)
        case "uninstall":
            uninstall()
        case "restart":
            restart(port)
        case "status":
            status(port)
