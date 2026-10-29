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


_OPENS_WITH_CORRECTION = re.compile(
    r"^(?:no,? wait|wait,? no|sorry|i mean|scratch that|actually|make that|or rather|correction)\b",
    re.IGNORECASE,
)
_SENTENCE_END = re.compile(r"(?<=[.!?])\s+")


def needs_llm(text: str) -> bool:
    return bool(_SELF_CORRECTION.search(text) or _AMBIGUOUS_FILLERS.search(text))


def plan_rewrites(text: str) -> list[tuple[str, bool]]:
    """Splits text into consecutive spans, flagging the ones the LLM must rewrite.

    Only flagged sentences pay for the LLM, one rewrite each. A sentence that opens with a
    correction ("No wait, Thursday.") retracts something in the sentence before it, so the two
    travel together; a bare "Scratch that." also takes the sentence after it, which holds the
    replacement.
    """
    units: list[tuple[str, bool]] = []
    awaiting_replacement = False
    for sentence in _SENTENCE_END.split(text.strip()):
        if not sentence:
            continue
        flagged = needs_llm(sentence)
        correction = _OPENS_WITH_CORRECTION.match(sentence) if flagged else None
        if awaiting_replacement or (correction and units):
            previous, _ = units.pop()
            units.append((f"{previous} {sentence}", True))
        else:
            units.append((sentence, flagged))
        # "Scratch that." on its own: the replacement is in the next sentence.
        awaiting_replacement = bool(correction) and not sentence[correction.end() :].strip(" ,.!?")

    # Flagged units stay apart so each rewrite is reusable while the transcript grows.
    spans: list[tuple[str, bool]] = []
    for unit, flagged in units:
        if spans and not flagged and not spans[-1][1]:
            previous, _ = spans.pop()
            unit = f"{previous} {unit}"
        spans.append((unit, flagged))
    return spans


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
