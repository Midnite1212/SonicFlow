import pytest

from sonicflow.config import Settings, load_backend_choice, save_backend_choice


@pytest.fixture(autouse=True)
def isolated_config(tmp_path, monkeypatch):
    monkeypatch.setenv("SONICFLOW_CONFIG", str(tmp_path / "config.json"))
    monkeypatch.delenv("SONICFLOW_ASR", raising=False)
    monkeypatch.delenv("SONICFLOW_CLEANUP", raising=False)


def test_saved_choice_round_trips():
    save_backend_choice("parakeet-v2", "qwen3-4b")
    assert load_backend_choice() == {"asr": "parakeet-v2", "cleanup": "qwen3-4b"}


def test_missing_or_corrupt_config_is_empty(tmp_path):
    assert load_backend_choice() == {}
    (tmp_path / "config.json").write_text("{not json")
    assert load_backend_choice() == {}


def test_settings_use_saved_choice_and_env_overrides(monkeypatch):
    save_backend_choice("parakeet-v2", "qwen3-4b")
    assert (Settings.from_env().asr, Settings.from_env().cleanup) == ("parakeet-v2", "qwen3-4b")
    monkeypatch.setenv("SONICFLOW_CLEANUP", "rules")
    assert Settings.from_env().cleanup == "rules"
