import plistlib
from pathlib import Path

from sonicflow.service import LABEL, build_plist


def test_plist_runs_engine_offline_and_unthrottled(tmp_path):
    program = Path("/support/SonicFlow/venv/bin/sonicflow")
    plist = build_plist(program, "parakeet-v2", "qwen3-1.7b", tmp_path)

    assert plist["Label"] == LABEL
    assert plist["ProgramArguments"] == [str(program)]
    assert plist["WorkingDirectory"] == "/support/SonicFlow"
    assert plist["EnvironmentVariables"] == {
        "SONICFLOW_ASR": "parakeet-v2",
        "SONICFLOW_CLEANUP": "qwen3-1.7b",
        "HF_HUB_OFFLINE": "1",
    }
    assert plist["RunAtLoad"] and plist["KeepAlive"]
    assert plist["ProcessType"] == "Interactive"
    assert plist["StandardErrorPath"] == str(tmp_path / "engine.log")
    plistlib.dumps(plist)
