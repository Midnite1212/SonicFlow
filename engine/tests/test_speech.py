from sonicflow.speech import is_filler, is_unsure_fragment


def test_filler_only_transcripts():
    assert is_filler("Mm-hmm.")
    assert is_filler("Um, uh.")
    assert not is_filler("Hm, maybe.")
    assert not is_filler("Okay.")
    assert not is_filler("")


def test_unsure_fragments_are_short_and_low_confidence():
    assert is_unsure_fragment("Yeah.", [0.6, 0.85])
    assert not is_unsure_fragment("No.", [0.84, 0.86])
    assert not is_unsure_fragment("send the numbers today", [0.5, 0.5, 0.5, 0.5])
    assert not is_unsure_fragment("", [])
