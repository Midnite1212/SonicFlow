from sonicflow.vocabulary import Snippet, Term, Vocabulary


def test_compound_terms_match_when_spoken_apart_or_lowercased():
    vocabulary = Vocabulary((Term("SonicFlow"), Term("GitHub")))
    assert (
        vocabulary.correct("Open sonic flow, then push to github.")
        == "Open SonicFlow, then push to GitHub."
    )
    assert vocabulary.correct("Sonic-flow is fast") == "SonicFlow is fast"


def test_heard_variants_and_multi_word_terms():
    vocabulary = Vocabulary((Term("Priya", ("pria", "preya")), Term("New York")))
    assert vocabulary.correct("Tell Pria we land in new york.") == "Tell Priya we land in New York."


def test_capitalized_word_leaves_common_word_alone():
    vocabulary = Vocabulary((Term("Will"), Term("iPhone")))
    assert vocabulary.correct("I will call. I phone home.") == "I will call. I phone home."
    assert vocabulary.correct("my IPHONE") == "my iPhone"


def test_words_inside_other_words_are_untouched():
    vocabulary = Vocabulary((Term("HKID"),))
    assert vocabulary.correct("hkid hkids") == "HKID hkids"


def test_snippet_for_whole_utterance_ignores_case_and_punctuation():
    vocabulary = Vocabulary(snippets=(Snippet("my calendar link", "https://cal.example/r"),))
    assert vocabulary.snippet_for("My calendar link.") == "https://cal.example/r"
    assert vocabulary.snippet_for("Send my calendar link.") is None


def test_snippet_expands_inside_a_sentence_literally():
    vocabulary = Vocabulary(snippets=(Snippet("sign off", r"Thanks,\n— R \1"),))
    assert vocabulary.expand("Great work. Sign off.") == r"Great work. Thanks,\n— R \1."


def test_empty_vocabulary_is_identity():
    vocabulary = Vocabulary()
    assert vocabulary.correct("Hello there.") == "Hello there."
    assert vocabulary.expand("Hello there.") == "Hello there."
    assert vocabulary.snippet_for("") is None


def test_from_event_accepts_strings_and_objects_and_skips_bad_items():
    vocabulary = Vocabulary.from_event(
        {
            "dictionary": ["Kubernetes", {"term": "Priya", "heard": ["pria", 3]}, {"bad": 1}, 7],
            "snippets": [{"trigger": "my email", "text": "r@example.com"}, {"trigger": "x"}],
        }
    )
    assert [term.term for term in vocabulary.terms] == ["Kubernetes", "Priya"]
    assert vocabulary.correct("pria uses kubernetes") == "Priya uses Kubernetes"
    assert vocabulary.snippet_for("my email") == "r@example.com"
    assert Vocabulary.from_event({}).correct("x") == "x"
