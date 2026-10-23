import pytest

pytest.importorskip("mlx_lm")

from sonicflow.backends.llm import accept_rewrite  # noqa: E402


def test_accepts_shorter_rewrite():
    assert accept_rewrite("Ship it Friday, no wait, Thursday.", "Ship it Thursday.")


def test_rejects_empty_rewrite():
    assert not accept_rewrite("Ship it Friday, no wait, Thursday.", "")


def test_rejects_runaway_rewrite():
    assert not accept_rewrite("Ship it.", "Ship it. " * 20)
