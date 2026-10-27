"""Tells real speech from what speech models produce on silence and background noise."""

import re

# Parakeet's mean token confidence for one- and two-word results: noise yields 0.72-0.80,
# deliberate short replies ("No.", "Okay.") 0.84 and up.
MIN_SHORT_CONFIDENCE = 0.82

FILLERS = frozenset({"ah", "er", "hm", "hmm", "mm", "mmm", "mm-hmm", "uh", "um"})


def is_filler(text: str) -> bool:
    """True when the transcript holds only non-lexical sounds, which noise often decodes to."""
    words = re.findall(r"[a-z]+(?:-[a-z]+)*", text.lower())
    return bool(words) and all(word in FILLERS for word in words)


def is_unsure_fragment(text: str, confidences: list[float]) -> bool:
    """True for a one- or two-word result decoded with low confidence."""
    if not confidences or len(text.split()) > 2:
        return False
    return sum(confidences) / len(confidences) < MIN_SHORT_CONFIDENCE
