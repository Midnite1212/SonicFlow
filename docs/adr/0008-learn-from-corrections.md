# 0008 — Learn dictionary words from corrections

**Status:** accepted · 2026-10-29

## Context

The dictionary fixes names and jargon the speech model mishears, but only once the user types each one in. The moment they fix a misheard word in pasted text is the best signal for what belongs there, and it is lost.

## Decision

- After a paste, the app reads the focused field through Accessibility (already granted for pasting) every second for up to a minute. It stops when focus moves, the field empties, or the next dictation starts. It finds the paste again by the text before and after it.
- At the end of the watch, it aligns the pasted and edited words and keeps fixes of one to three words that:
  - contain a name or jargon (a capital inside the word, a digit beside a letter, or a word missing from `/usr/share/dict/words`, the list the engine uses);
  - are spelled at least half like what was heard;
  - weren't heard as a single common word and have no apostrophe. The engine rewrites every match of what was heard, so learning "it" → "IT" or "were" → "we're" would damage every later dictation.
- A dictation where more than half the words changed teaches nothing.
- Learned words are added to the dictionary marked **Learned**, or extend an existing word's Heard As. **Learn words from your corrections** in Settings turns this off.
- Secure fields, edits made in command mode, and fields over 100,000 characters are skipped. The field's text stays in memory and is never logged or saved; only the learned word is saved, in the dictionary.

## Consequences

Names and jargon the user fixes once are spelled right from the next dictation, with no engine or protocol change. Apps whose text fields aren't exposed to Accessibility (some Electron and web views) teach nothing. A wrong guess costs one dictionary entry, tagged so it is easy to spot and delete. Numbers, grammar fixes and spoken numbers turned into digits are not learned.
