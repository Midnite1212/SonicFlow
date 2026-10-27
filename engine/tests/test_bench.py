import json

import pytest

from sonicflow.bench.cli import corpus_wer, load_corpus, normalize


def test_normalize_strips_case_and_punctuation():
    assert normalize("Let's ship it, Thursday!") == "let's ship it thursday"


def test_normalize_spells_formatting_variants_one_way():
    assert normalize("Move the standup to 10:30.") == normalize("move the stand up to ten thirty")
    assert normalize("Deploy at 6.") == "deploy at six"
    assert normalize("Rename getUserProfile") == "rename get user profile"


def test_corpus_wer_is_zero_for_matching_text():
    assert corpus_wer(["Hello, world."], ["hello world"]) == 0.0


def test_corpus_wer_counts_empty_hypothesis_as_errors():
    assert corpus_wer(["hello world"], [""]) > 0


def test_load_corpus_requires_audio(tmp_path):
    entry = {"id": "a", "kind": "plain", "spoken": "hi", "clean": "Hi."}
    (tmp_path / "manifest.jsonl").write_text(json.dumps(entry) + "\n")
    with pytest.raises(SystemExit, match="missing audio"):
        load_corpus(tmp_path)
