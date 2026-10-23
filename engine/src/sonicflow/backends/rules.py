import re

from sonicflow.backends.base import CleanupBackend, CleanupContext

_HESITATIONS = re.compile(r"\b(?:u+m+|u+h+|uhm|erm?|a+h+|h+m+|m{2,})\b[,.]?", re.IGNORECASE)

# Only strip a run of discourse markers when it ends in "so"/"basically", so "Yeah, that works"
# keeps its meaning.
_LEADING_MARKERS = re.compile(
    r"(^|[.!?]\s+)(?:(?:yeah|yes|okay|ok|well|alright|so|basically),?\s+)*(?:so|basically),?\s+",
    re.IGNORECASE,
)

# Repeats that are usually grammatical ("that that", "had had") are left alone.
_STUTTER = re.compile(r"\b(?!(?:that|had)\b)(\w+)(?:\s+\1\b)+", re.IGNORECASE)

_SELF_CORRECTION = re.compile(
    r"\b(?:no,? wait|wait,? no|sorry,? i mean|i mean|scratch that|make that|no,? sorry|"
    r"or rather|correction)\b",
    re.IGNORECASE,
)
_AMBIGUOUS_FILLERS = re.compile(r"\b(?:like|you know|kind of|sort of)\b", re.IGNORECASE)


def needs_llm(text: str) -> bool:
    return bool(_SELF_CORRECTION.search(text) or _AMBIGUOUS_FILLERS.search(text))


def _tidy_punctuation(text: str) -> str:
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"\s+([,.!?;:])", r"\1", text)
    text = re.sub(r",(?:\s*,)+", ",", text)
    text = re.sub(r",\s*([.!?])", r"\1", text)
    return text.strip(" ,")


def _capitalize_sentences(text: str) -> str:
    return re.sub(r"(^|[.!?]\s+)([a-z])", lambda m: m.group(1) + m.group(2).upper(), text)


def apply_rules(text: str) -> str:
    text = _HESITATIONS.sub(" ", text)
    text = _tidy_punctuation(text)
    text = _STUTTER.sub(r"\1", text)
    text = _LEADING_MARKERS.sub(r"\1", text)
    text = _tidy_punctuation(text)
    if not text:
        return text
    text = _capitalize_sentences(text)
    if text[-1].isalnum():
        text += "."
    return text


class RulesCleanup(CleanupBackend):
    name = "rules"

    def clean(self, text: str, context: CleanupContext) -> str:
        return apply_rules(text)
