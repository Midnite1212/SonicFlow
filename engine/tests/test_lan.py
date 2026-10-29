import asyncio
import json
import ssl
import stat
import subprocess
import urllib.error
import urllib.request

import pytest
from conftest import FakeASR
from fastapi import FastAPI, WebSocket
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from sonicflow import lan
from sonicflow.backends.registry import PassthroughCleanup
from sonicflow.server import create_app


@pytest.fixture(autouse=True)
def config_dir(tmp_path, monkeypatch):
    monkeypatch.setenv("SONICFLOW_CONFIG", str(tmp_path / "config.json"))
    return tmp_path


LOOPBACK = "http://127.0.0.1:8765"


def mode(path) -> int:
    return stat.S_IMODE(path.stat().st_mode)


def test_identity_is_private_and_stable(config_dir):
    first = lan.identity()
    assert lan.identity() == first
    assert mode(first.key) == mode(config_dir / "lan.json") == 0o600
    assert len(first.fingerprint) == 64


def test_certificate_is_one_apple_tls_accepts():
    text = subprocess.run(
        ["/usr/bin/openssl", "x509", "-noout", "-text", "-in", str(lan.identity().cert)],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    assert "Version: 3" in text
    assert "ASN1 OID: prime256v1" in text
    assert "Field Type" not in text


def test_rotating_changes_the_token_but_keeps_the_certificate():
    first = lan.identity()
    second = lan.identity(rotate=True)
    assert second.token != first.token
    assert second.fingerprint == first.fingerprint


def test_pairing_code_round_trips():
    identity = lan.identity()
    code = lan.pairing_code(identity, "studio.local", 8766)
    assert code.startswith(lan.PAIRING_PREFIX)
    assert lan.read_pairing_code(code) == {
        "host": "studio.local",
        "port": 8766,
        "token": identity.token,
        "sha256": identity.fingerprint,
    }


def guarded_app() -> FastAPI:
    app = FastAPI()

    @app.get("/health")
    def health() -> dict:
        return {"status": "ok"}

    @app.get("/v1/lan")
    def controls() -> dict:
        return {"enabled": True}

    @app.websocket("/v1/dictate")
    async def dictate(ws: WebSocket) -> None:
        await ws.accept()
        await ws.send_json({"type": "hello"})
        await ws.close()

    return lan.RequireToken(app, "secret")


@pytest.mark.parametrize("header", [None, "Bearer wrong", "secret"])
def test_requests_without_the_token_are_refused(header):
    headers = {"Authorization": header} if header else {}
    response = TestClient(guarded_app()).get("/health", headers=headers)
    assert response.status_code == 401


def test_requests_with_the_token_are_served():
    client = TestClient(guarded_app())
    assert client.get("/health", headers={"Authorization": "Bearer secret"}).status_code == 200


def test_lan_controls_are_refused_even_with_the_token():
    client = TestClient(guarded_app())
    response = client.get("/v1/lan", headers={"Authorization": "Bearer secret"})
    assert response.status_code == 401


def test_websocket_needs_the_token():
    client = TestClient(guarded_app())
    with pytest.raises(WebSocketDisconnect), client.websocket_connect("/v1/dictate"):
        pass
    headers = {"Authorization": "Bearer secret"}
    with client.websocket_connect("/v1/dictate", headers=headers) as ws:
        assert ws.receive_json() == {"type": "hello"}


def fetch(url: str, identity: lan.Identity, token: str | None) -> int:
    context = ssl.create_default_context(cafile=str(identity.cert))
    context.check_hostname = False
    request = urllib.request.Request(url)
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(request, context=context, timeout=5) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code


def test_lan_server_serves_tls_on_the_network():
    identity = lan.identity()

    async def scenario() -> list[int]:
        app = FastAPI()
        app.get("/health")(lambda: {"status": "ok"})
        server = lan.LanServer(app)
        await server.start(identity, 0)
        url = f"https://127.0.0.1:{server.port}/health"
        try:
            return [
                await asyncio.to_thread(fetch, url, identity, identity.token),
                await asyncio.to_thread(fetch, url, identity, None),
            ]
        finally:
            await server.stop()
            assert not server.running

    assert asyncio.run(scenario()) == [200, 401]


def test_lan_controls_toggle_sharing_and_remember_it(fake_asr: FakeASR):
    app = create_app(fake_asr, PassthroughCleanup(), lan_port=0)
    with TestClient(app, base_url=LOOPBACK) as client:
        assert client.get("/v1/lan").json() == {"enabled": False}
        shared = client.post("/v1/lan", json={"enabled": True}).json()
        assert shared["enabled"] and shared["port"] > 0
        pairing = lan.read_pairing_code(shared["code"])
        assert pairing["port"] == shared["port"]

        reset = client.post("/v1/lan/reset").json()
        assert lan.read_pairing_code(reset["code"])["token"] != pairing["token"]
        assert lan.is_enabled()

        assert client.post("/v1/lan", json={"enabled": False}).json() == {"enabled": False}
    assert not lan.is_enabled()


def test_engine_shares_again_on_restart(fake_asr: FakeASR, config_dir):
    lan.set_enabled(True)
    with TestClient(
        create_app(fake_asr, PassthroughCleanup(), lan_port=0), base_url=LOOPBACK
    ) as client:
        assert client.get("/v1/lan").json()["enabled"]
    assert json.loads((config_dir / "lan.json").read_text())["enabled"]


def test_lan_controls_refuse_browsers_and_rebound_hosts(fake_asr: FakeASR):
    with TestClient(
        create_app(fake_asr, PassthroughCleanup(), lan_port=0), base_url=LOOPBACK
    ) as client:
        rebound = client.get("/v1/lan", headers={"host": "attacker.example:8765"})
        page = client.post(
            "/v1/lan", json={"enabled": True}, headers={"origin": "http://127.0.0.1:8765"}
        )
        assert rebound.status_code == page.status_code == 403
        assert not lan.is_enabled()


def test_failed_start_releases_the_port(monkeypatch):
    identity = lan.identity()
    broken = lan.Identity(identity.token, identity.cert, identity.cert, identity.fingerprint)

    async def scenario() -> None:
        server = lan.LanServer(FastAPI())
        await server.start(identity, 0)
        port = server.port
        await server.stop()
        with pytest.raises(OSError):
            await server.start(broken, port)
        assert not server.running
        await server.stop()
        await server.start(identity, port)
        assert server.running
        await server.stop()

    asyncio.run(scenario())
