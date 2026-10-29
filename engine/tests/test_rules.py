import pytest

from sonicflow.backends.rules import apply_rules, needs_llm, plan_rewrites


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


def test_plan_sends_only_flagged_sentences():
    text = "We shipped the parser. It was like really fast. The docs are done."
    assert plan_rewrites(text) == [
        ("We shipped the parser.", False),
        ("It was like really fast.", True),
        ("The docs are done.", False),
    ]


def test_plan_joins_correction_with_the_sentence_it_retracts():
    text = "The review is done. Let's ship it on Friday. No wait, Thursday. Thanks all."
    assert plan_rewrites(text) == [
        ("The review is done.", False),
        ("Let's ship it on Friday. No wait, Thursday.", True),
        ("Thanks all.", False),
    ]


def test_plan_keeps_clean_text_as_one_span():
    assert plan_rewrites("One. Two. Three.") == [("One. Two. Three.", False)]


def test_plan_bare_correction_takes_the_replacement_after_it():
    text = "The bug is in the parser. Scratch that. The lexer. Tests pass."
    assert plan_rewrites(text) == [
        ("The bug is in the parser. Scratch that. The lexer.", True),
        ("Tests pass.", False),
    ]


def test_plan_rewrites_each_flagged_sentence_on_its_own():
    text = "It was like fast. Ship it Friday, no wait, Thursday. Done."
    assert plan_rewrites(text) == [
        ("It was like fast.", True),
        ("Ship it Friday, no wait, Thursday.", True),
        ("Done.", False),
    ]
