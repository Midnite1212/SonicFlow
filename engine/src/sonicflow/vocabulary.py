import re
from dataclasses import dataclass
from functools import cache
from pathlib import Path
from typing import Any

_SEPARATORS = re.compile(r"[^\w']+")
_CAMEL_BOUNDARY = re.compile(r"(?<=[a-z])(?=[A-Z])")
_SYSTEM_WORDS = Path("/usr/share/dict/words")
_TOKEN = re.compile(r"[\w']+")
_SPAN_GAP = re.compile(r"[\s-]+")
_SOUNDS = {
    **dict.fromkeys("bp", "p"),
    **dict.fromkeys("cgkq", "k"),
    "x": "ks",
    **dict.fromkeys("dt", "t"),
    **dict.fromkeys("fv", "f"),
    **dict.fromkeys("sz", "s"),
    **dict.fromkeys("mn", "m"),
    **dict.fromkeys("hwy", ""),
}
_MAX_SPAN_WORDS = 3
_MIN_SOUND_LENGTH = 4
_MIN_SPELLING = 0.7


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


def _letters(phrase: str) -> str:
    return "".join(c for c in phrase.lower() if c.isalnum())


def _sound(letters: str) -> str:
    """A rough sound-alike key: consonants grouped by how they sound, vowels dropped after the
    first letter. Matches the app's key for learned corrections."""
    key = ""
    for index, letter in enumerate(letters.replace("ph", "f").replace("ck", "k")):
        codes = ("a" if index == 0 else "") if letter in "aeiou" else _SOUNDS.get(letter, letter)
        for code in codes:
            if not key.endswith(code):
                key += code
    return key


def _similarity(a: str, b: str) -> float:
    if not a or not b:
        return 0.0
    previous = list(range(len(b) + 1))
    for i, x in enumerate(a):
        current = [i + 1]
        for j, y in enumerate(b):
            current.append(min(previous[j + 1] + 1, current[j] + 1, previous[j] + (x != y)))
        previous = current
    return 1 - previous[-1] / max(len(a), len(b))


@dataclass(frozen=True)
class _SoundForm:
    letters: str
    words: int
    term: str


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
        self._sound_forms: dict[str, list[_SoundForm]] = {}
        for term in terms:
            for form in {term.term, *term.heard}:
                letters = _letters(form)
                if len(key := _sound(letters)) >= _MIN_SOUND_LENGTH:
                    entry = _SoundForm(letters, len(_TOKEN.findall(form)), term.term)
                    self._sound_forms.setdefault(key, []).append(entry)
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
        return self._sound_alike(self._replace(self._spelling_pattern, self._spellings, text))

    def _sound_alike(self, text: str) -> str:
        """Rewrites words that sound like a term or one of its heard spellings and are spelled
        close to it, so a new mishearing of a learned name is caught too. One word never stands
        for another single word: different names sound alike too easily ("Jansen", "Johnson")."""
        if not self._sound_forms:
            return text
        tokens = list(_TOKEN.finditer(text))
        out: list[str] = []
        end = 0
        i = 0
        while i < len(tokens):
            for size in range(min(_MAX_SPAN_WORDS, len(tokens) - i), 0, -1):
                span = tokens[i : i + size]
                if any(
                    not _SPAN_GAP.fullmatch(text[a.end() : b.start()])
                    for a, b in zip(span, span[1:], strict=False)
                ):
                    continue
                phrase = text[span[0].start() : span[-1].end()]
                if (term := self._sounds_like(phrase, size)) is None:
                    continue
                out += [text[end : span[0].start()], term]
                end = span[-1].end()
                i += size
                break
            else:
                i += 1
        return "".join(out) + text[end:]

    def _sounds_like(self, span: str, words: int) -> str | None:
        letters = _letters(span)
        for form in self._sound_forms.get(_sound(letters), ()):
            spelled_alike = _similarity(letters, form.letters) >= _MIN_SPELLING
            if (words > 1 or form.words > 1) and spelled_alike:
                return form.term
        return None

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
