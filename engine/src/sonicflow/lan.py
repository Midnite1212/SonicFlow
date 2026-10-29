"""Serves the engine to other Macs on the local network (ADR 0007).

Off by default. When on, a second listener accepts TLS with a self-signed certificate that clients
pin, and every request must carry the bearer token from the pairing code. The loopback listener is
unchanged, and the controls under /v1/lan answer only there."""

import asyncio
import base64
import contextlib
import functools
import hashlib
import hmac
import json
import logging
import os
import secrets
import socket
import ssl
import subprocess
from dataclasses import dataclass
from pathlib import Path

import uvicorn

from sonicflow.config import config_path

logger = logging.getLogger(__name__)

PAIRING_PREFIX = "sonicflow1."
CONTROL_PATH = "/v1/lan"


@dataclass(frozen=True)
class Identity:
    token: str
    cert: Path
    key: Path
    fingerprint: str


def _dir() -> Path:
    return config_path().parent


def _state_path() -> Path:
    return _dir() / "lan.json"


def _write_private(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    staging = path.with_suffix(".tmp")
    staging.unlink(missing_ok=True)
    with os.fdopen(os.open(staging, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w") as file:
        file.write(text)
    staging.replace(path)


def _load_state() -> dict:
    try:
        state = json.loads(_state_path().read_text())
    except (OSError, ValueError):
        return {}
    return state if isinstance(state, dict) else {}


def _save_state(state: dict) -> None:
    _write_private(_state_path(), json.dumps(state, indent=2) + "\n")


def is_enabled() -> bool:
    return _load_state().get("enabled") is True


def set_enabled(enabled: bool) -> None:
    _save_state(_load_state() | {"enabled": enabled})


def _make_certificate(cert: Path, key: Path) -> None:
    cert.parent.mkdir(parents=True, exist_ok=True)
    key.unlink(missing_ok=True)
    # openssl keeps the mode of a file it overwrites, so the key is never readable by others.
    os.close(os.open(key, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600))
    # Apple's TLS rejects LibreSSL's defaults (v1, explicit curve parameters) as a decode error.
    subprocess.run(
        ["/usr/bin/openssl", "req", "-x509", "-newkey", "ec", "-nodes", "-days", "3650"]
        + ["-pkeyopt", "ec_paramgen_curve:prime256v1", "-pkeyopt", "ec_param_enc:named_curve"]
        + ["-addext", "basicConstraints=critical,CA:FALSE"]
        + ["-addext", "extendedKeyUsage=serverAuth"]
        + ["-subj", "/CN=SonicFlow engine", "-keyout", str(key), "-out", str(cert)],
        check=True,
        capture_output=True,
    )


def fingerprint(cert: Path) -> str:
    return hashlib.sha256(ssl.PEM_cert_to_DER_cert(cert.read_text())).hexdigest()


def identity(rotate: bool = False) -> Identity:
    """The token and certificate, created on first use; `rotate` invalidates every paired client."""
    state = _load_state()
    if rotate or not isinstance(state.get("token"), str):
        state["token"] = secrets.token_urlsafe(32)
        _save_state(state)
    cert, key = _dir() / "lan-cert.pem", _dir() / "lan-key.pem"
    if not (cert.exists() and key.exists()):
        _make_certificate(cert, key)
    return Identity(state["token"], cert, key, fingerprint(cert))


@functools.cache
def host_name() -> str:
    try:
        name = subprocess.run(
            ["/usr/sbin/scutil", "--get", "LocalHostName"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return socket.gethostname()
    return f"{name}.local"


def pairing_code(identity: Identity, host: str, port: int) -> str:
    """Everything a client needs to reach and trust this engine, as one string to copy."""
    payload = {"host": host, "port": port, "token": identity.token, "sha256": identity.fingerprint}
    encoded = base64.urlsafe_b64encode(json.dumps(payload, separators=(",", ":")).encode())
    return PAIRING_PREFIX + encoded.decode().rstrip("=")


def read_pairing_code(code: str) -> dict:
    encoded = code.strip().removeprefix(PAIRING_PREFIX)
    return json.loads(base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4)))


class RequireToken:
    """Admits requests that carry the bearer token, and never the LAN controls themselves."""

    def __init__(self, app, token: str) -> None:
        self.app = app
        self._expected = f"Bearer {token}".encode()

    async def __call__(self, scope, receive, send) -> None:
        if scope["type"] not in ("http", "websocket") or self._admits(scope):
            await self.app(scope, receive, send)
        elif scope["type"] == "http":
            await send(
                {
                    "type": "http.response.start",
                    "status": 401,
                    "headers": [(b"content-type", b"application/json")],
                }
            )
            await send({"type": "http.response.body", "body": b'{"detail":"unauthorized"}'})
        else:
            await receive()
            await send({"type": "websocket.close", "code": 1008})

    def _admits(self, scope) -> bool:
        if scope["path"].startswith(CONTROL_PATH):
            return False
        header = dict(scope["headers"]).get(b"authorization", b"")
        return hmac.compare_digest(header, self._expected)


class _Listener(uvicorn.Server):
    @contextlib.contextmanager
    def capture_signals(self):
        # The loopback server owns the process's signals and stops this one on its way out.
        yield


class LanServer:
    def __init__(self, app) -> None:
        self._app = app
        self._server: _Listener | None = None
        self._task: asyncio.Task | None = None
        self.port: int | None = None

    @property
    def running(self) -> bool:
        return self._task is not None and not self._task.done()

    async def start(self, identity: Identity, port: int) -> None:
        """Listens on every interface, IPv4 and IPv6; raises OSError if the port is taken."""
        await self.stop()
        sock = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
        try:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
            sock.bind(("::", port))
            sock.listen()
        except OSError:
            sock.close()
            raise
        config = uvicorn.Config(
            RequireToken(self._app, identity.token),
            ssl_certfile=str(identity.cert),
            ssl_keyfile=str(identity.key),
            lifespan="off",
            log_level="warning",
        )
        server = _Listener(config)
        task = asyncio.create_task(server.serve(sockets=[sock]))
        while not server.started and not task.done():
            await asyncio.sleep(0.02)
        if not server.started:
            # uvicorn only closes the sockets of a server that started.
            sock.close()
            task.result()
            raise OSError("the network listener stopped while starting")
        self._server, self._task, self.port = server, task, sock.getsockname()[1]

    async def stop(self) -> None:
        server, task = self._server, self._task
        self._server = self._task = self.port = None
        if server is None or task is None:
            return
        server.should_exit = True
        try:
            await task
        except Exception as error:
            logger.warning("network listener failed: %r", error)
