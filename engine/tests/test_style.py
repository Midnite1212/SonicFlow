from sonicflow.style import apply_style


def test_standard_and_unknown_styles_leave_text_alone():
    for style in ("standard", None, "shouty"):
        assert apply_style("Sounds good.", style) == "Sounds good."


def test_casual_drops_only_the_final_period():
    assert apply_style("Sounds good. See you at one.", "casual") == "Sounds good. See you at one"
    assert apply_style("Are you free?", "casual") == "Are you free?"
    assert apply_style("Wait for it...", "casual") == "Wait for it..."


def test_lowercase_lowers_sentence_starts_but_keeps_i_and_terms():
    text = "Sounds good. I'll bring it. Priya too? GitHub is down. Thanks."
    assert (
        apply_style(text, "lowercase", keep=frozenset({"Priya"}))
        == "sounds good. I'll bring it. Priya too? GitHub is down. thanks"
    )


def test_lowercase_leaves_mid_sentence_capitals():
    assert apply_style("Ask Sam about Monday.", "lowercase") == "ask Sam about Monday"
