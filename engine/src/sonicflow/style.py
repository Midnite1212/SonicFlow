import re

STYLES = ("standard", "casual", "lowercase")

_FINAL_PERIOD = re.compile(r"(?<!\.)\.\s*$")
_SENTENCE_START = re.compile(r"(^|[.!?]\s+)([A-Z][a-z']*)\b")
_FIRST_PERSON = frozenset({"I", "I'm", "I'll", "I've", "I'd"})


def apply_style(text: str, style: str | None, keep: frozenset[str] = frozenset()) -> str:
    """Formats cleaned text for where it lands. `keep` holds words whose capital must stay,
    such as dictionary terms; unknown styles leave the text as it is."""
    if style not in ("casual", "lowercase"):
        return text
    text = _FINAL_PERIOD.sub("", text)
    if style == "lowercase":

        def lower(match: re.Match[str]) -> str:
            word = match.group(2)
            if word in _FIRST_PERSON or word in keep:
                return match.group(0)
            return match.group(1) + word.lower()

        text = _SENTENCE_START.sub(lower, text)
    return text
