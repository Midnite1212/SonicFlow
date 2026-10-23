import pytest

from sonicflow.backends.rules import apply_rules, needs_llm


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        (
            "So um I think we should uh probably wait until the tests pass.",
            "I think we should probably wait until the tests pass.",
        ),
        (
            "Yeah so basically the uh the deploy failed.",
            "The deploy failed.",
        ),
        ("Yeah, that works for me.", "Yeah, that works for me."),
        ("i reviewed it. so the build passed", "I reviewed it. The build passed."),
        ("I know that that is fine", "I know that that is fine."),
        ("hmm, the the cache is cold", "The cache is cold."),
        ("um", ""),
        ("Ship it today!", "Ship it today!"),
    ],
)
def test_apply_rules(raw, expected):
    assert apply_rules(raw) == expected


@pytest.mark.parametrize(
    "text",
    [
        "Let's ship it on Friday, no wait, Thursday.",
        "Send it to Alice, sorry I mean Bob.",
        "The meeting is at 3, actually make that 4.",
        "It failed because of like a missing variable.",
    ],
)
def test_needs_llm_for_corrections_and_ambiguous_fillers(text):
    assert needs_llm(text)


def test_clean_text_skips_llm():
    assert not needs_llm("Can you send me the latest numbers before the meeting tomorrow?")
