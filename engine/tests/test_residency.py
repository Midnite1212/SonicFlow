import mlx.core as mx
import numpy as np
from conftest import FakeASR

from sonicflow import residency
from sonicflow.backends.registry import PassthroughCleanup
from sonicflow.server import Engine


class WeightedASR(FakeASR):
    def __init__(self) -> None:
        super().__init__()
        self.weights = [mx.ones((256, 256), dtype=mx.bfloat16), mx.zeros((16,))]
        mx.eval(self.weights)
        self.unloaded = False

    def arrays(self) -> list:
        return self.weights

    def unload(self) -> None:
        self.unloaded = True


def test_lock_covers_each_array_including_bfloat16():
    asr = WeightedASR()
    regions = residency.lock(asr.arrays())
    assert [size for _, size in regions] == [256 * 256 * 2, 16 * 4]
    assert regions[1][0] == np.asarray(asr.weights[1]).ctypes.data
    residency.unlock(regions)


def test_engine_locks_on_load_and_unlocks_on_unload(monkeypatch):
    unlocked = []
    monkeypatch.setattr(residency, "unlock", unlocked.extend)
    engine, asr = Engine(FakeASR(), PassthroughCleanup()), WeightedASR()
    engine.load(asr)
    assert asr.loaded
    engine.unload(asr)
    assert asr.unloaded
    assert len(unlocked) == 2


def test_opt_out_skips_locking(monkeypatch):
    monkeypatch.setenv("SONICFLOW_LOCK_MODELS", "0")
    unlocked = []
    monkeypatch.setattr(residency, "unlock", unlocked.extend)
    engine, asr = Engine(FakeASR(), PassthroughCleanup()), WeightedASR()
    engine.load(asr)
    engine.unload(asr)
    assert unlocked == []
