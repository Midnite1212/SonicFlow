"""Locks model weights in RAM so macOS can't page them out between dictations (ADR 0006).

MLX's wired limit doesn't stop paging; mlock on the Metal buffers does. Under memory pressure a
locked 4 GB buffer read back in 0.1 s and an unlocked one in 12.7 s."""

import ctypes
import logging
import os

logger = logging.getLogger(__name__)

Region = tuple[int, int]


def enabled() -> bool:
    return os.environ.get("SONICFLOW_LOCK_MODELS", "1") != "0"


def _libc() -> ctypes.CDLL:
    libc = ctypes.CDLL(None, use_errno=True)
    for name in ("mlock", "munlock"):
        getattr(libc, name).argtypes = [ctypes.c_void_p, ctypes.c_size_t]
    return libc


def lock(arrays: list) -> list[Region]:
    """Locks each array's memory; the regions are what `unlock` needs later."""
    if not arrays:
        return []
    import mlx.core as mx
    import numpy as np

    libc, regions = _libc(), []
    for array in arrays:
        # A byte view shares the buffer and exposes dtypes NumPy lacks, such as bfloat16.
        view = np.asarray(array.view(mx.uint8))
        if view.nbytes and libc.mlock(view.ctypes.data, view.nbytes) == 0:
            regions.append((view.ctypes.data, view.nbytes))
    skipped = len(arrays) - len(regions)
    if skipped:
        logger.warning("could not lock %d of %d model arrays", skipped, len(arrays))
    return regions


def unlock(regions: list[Region]) -> None:
    libc = _libc()
    for address, size in regions:
        libc.munlock(address, size)
