import re
from dataclasses import dataclass
from functools import cache
from pathlib import Path
from typing import Any

_SEPARATORS = re.compile(r"[^\w']+")
_CAMEL_BOUNDARY = re.compile(r"(?<=[a-z])(?=[A-Z])")
_SYSTEM_WORDS = Path("/usr/share/dict/words")


@cache
def common_words() -> frozenset[str]:
    """Lowercase English words from the macOS word list; empty where the list is missing."""
    try:
        return frozenset(word for word in _SYSTEM_WORDS.read_text().split() if word.islower())
    except OSError:
        return frozenset()


@dataclass(frozen=True)
class Term:
    term: str
    heard: tuple[str, ...] = ()


@dataclass(frozen=True)
class Snippet:
    trigger: str
    text: str


def _key(phrase: str) -> str:
    return " ".join(word.lower() for word in _SEPARATORS.split(phrase) if word)


def _compile(phrases: dict[str, str]) -> re.Pattern[str] | None:
    """One case-insensitive pattern for all phrases, whose words may be split by spaces, commas,
    or hyphens, longest phrase first so "New York City" wins over "New York"."""
    if not phrases:
        return None
    alternatives = [
        r"[\s,-]+".join(re.escape(word) for word in key.split(" "))
        for key in sorted(phrases, key=len, reverse=True)
    ]
    return re.compile(r"(?<![\w'])(?:" + "|".join(alternatives) + r")(?![\w'])", re.IGNORECASE)


def _spoken_forms(term: Term) -> list[str]:
    forms = list(term.heard)
    parts = _CAMEL_BOUNDARY.sub(" ", term.term).split()
    # "iPhone" spoken apart would be "i phone", which would rewrite "I phone home".
    if len(parts) > 1 and all(len(part) > 1 for part in parts):
        forms.append(" ".join(parts))
    # A name that is also a word, such as "Will", must not rewrite the verb "will".
    is_word = term.term == term.term.capitalize() and term.term.lower() in common_words()
    if not is_word:
        forms.append(term.term)
    return forms


class Vocabulary:
    """The user's dictionary and snippets for one utterance."""

    def __init__(self, terms: tuple[Term, ...] = (), snippets: tuple[Snippet, ...] = ()) -> None:
        self.terms = terms
        self._spellings = {
            key: term.term for term in terms for form in _spoken_forms(term) if (key := _key(form))
        }
        self._snippets = {key: s.text for s in snippets if (key := _key(s.trigger))}
        self._spelling_pattern = _compile(self._spellings)
        self._trigger_pattern = _compile(self._snippets)

    @classmethod
    def from_event(cls, event: dict[str, Any]) -> "Vocabulary":
        """Reads the `dictionary` and `snippets` fields of a `start` message, skipping bad items."""
        terms = []
        for item in event.get("dictionary") or ():
            if isinstance(item, str):
                terms.append(Term(item))
            elif isinstance(item, dict) and isinstance(item.get("term"), str):
                heard = tuple(h for h in item.get("heard") or () if isinstance(h, str))
                terms.append(Term(item["term"], heard))
        snippets = tuple(
            Snippet(item["trigger"], item["text"])
            for item in event.get("snippets") or ()
            if isinstance(item, dict)
            and isinstance(item.get("trigger"), str)
            and isinstance(item.get("text"), str)
        )
        return cls(tuple(terms), snippets)

    def correct(self, text: str) -> str:
        return self._replace(self._spelling_pattern, self._spellings, text)

    def snippet_for(self, text: str) -> str | None:
        """The snippet when the whole utterance is its trigger."""
        return self._snippets.get(_key(text))

    def expand(self, text: str) -> str:
        return self._replace(self._trigger_pattern, self._snippets, text)

    @staticmethod
    def _replace(pattern: re.Pattern[str] | None, table: dict[str, str], text: str) -> str:
        if pattern is None:
            return text
        return pattern.sub(lambda match: table[_key(match.group())], text)
