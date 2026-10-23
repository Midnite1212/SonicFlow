import pytest

pytest.importorskip("mlx_lm")

from sonicflow.backends.llm import accept_rewrite  # noqa: E402


def test_accepts_correction_that_only_removes_words():
    assert accept_rewrite(
        "Let's ship it on Friday, no wait, Thursday.", "Let's ship it on Thursday."
    )


def test_accepts_one_reformatted_word():
    assert accept_rewrite("Deploy at five, actually make that six.", "Deploy at 6.")


def test_rejects_empty_rewrite():
    assert not accept_rewrite("Ship it Friday, no wait, Thursday.", "")


def test_rejects_answer_to_a_dictated_question():
    assert not accept_rewrite(
        "Do you know when the release is planned?", "The release is planned for next week."
    )


def test_rejects_runaway_rewrite():
    assert not accept_rewrite("Ship it.", "Ship it now, and also write the release notes today.")
