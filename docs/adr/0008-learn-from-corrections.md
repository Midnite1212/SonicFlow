# 0008 — Learn dictionary words from corrections

**Status:** accepted · 2026-10-29, revised 2026-10-30

## Context

The dictionary fixes names and jargon the speech model mishears, but only once the user types each one in. The moment they fix a misheard word in pasted text is the best signal for what belongs there, and it is lost.

## Decision

- **Reading the fix:**
  - After a paste, the app reads the focused field through Accessibility (already granted for pasting) every second for up to a minute.
  - It stops when focus moves, the field empties, or the next dictation starts.
  - It finds the paste again by the text before and after it.
- **Fields Accessibility can't read:** terminals such as xterm.js expose an empty input. There the app replays the user's edit keys on the pasted line, taken from the hotkey's existing listen-only event tap.
  - It follows only keys that edit the same way in every terminal: typing, Backspace, Delete, ← →, and ⌥ with ← → ⌫.
  - It learns when Return is pressed, the next dictation starts, or the minute is up.
  - Any of these stop the replay, and nothing is learned:
    - any other key, including ⌘ and ⌃ shortcuts, Home, End and ⌥ as Meta;
    - a click;
    - moving before the paste;
    - a switch to another app;
    - a secure input prompt;
    - an input method other than a plain keyboard layout.
- **What gets learned:** the pasted and edited words are aligned, ignoring possessives ("Studio's"). Fixes of one to three words are kept when they:
  - contain a name or jargon: a capital inside the word, a digit beside a letter, a word missing from `/usr/share/dict/words` (the list the engine uses), or a capitalized phrase whose spelling also changed. A fix that isn't a name on its own takes in the unchanged capitalized words beside it, so "Mac Stoo videos" → "Mac Studio" is learned as **Mac Studio**.
  - look or sound at least half like what was heard. The sound key groups consonants that sound alike and drops later vowels, so "Max Videos" and "Mac Studio" match. It counts only for phrases of more than one word, with sound keys of four or more and spellings at least 30% alike, because short words and names collide ("the team" and "Tim", "Jonathan" and "Johnson").
  - weren't heard as a single common word, and have no apostrophe left. The engine rewrites every match of what was heard, so learning "it" → "IT" or "were" → "we're" would damage every later dictation.
  - aren't the heard word with text typed straight after it ("config" → "config.yaml").
- **Widening a fix to a name:**
  - Widening takes in only capitals that aren't there just because they start a sentence, and never "I".
  - So "May be I" → "Maybe I" is not learned. Neither is a name at the very start of a sentence.
- **Whole rewrites:** a dictation where more than half the words changed teaches nothing.
- **Held for review:** a fix that looks like a name but fails a rule above is listed under **Learning** for the user to add or dismiss, with the reason: it was heard as a common word, it starts a sentence, or it looks or sounds only partly alike. Case-only fixes of a common word ("it" → "IT"), grammar fixes, typed-on text and fixes alike in neither spelling nor sound are dropped, as before. Learning also lists what was learned, with a way to take it back out of the dictionary.
- **Where learned words go:** they are added to the dictionary marked **Learned**, or extend an existing word's Heard As. **Learn words from your corrections** in Settings turns this off.
- **Skipped and private:**
  - Secure fields, edits made in command mode, and fields over 100,000 characters are skipped.
  - The field's text and the replayed keys stay in memory and are never logged or saved.
  - Only the learned word is saved, in the dictionary. The Learning list holds just the heard and fixed words and is kept like History: in memory unless **Save history** is on, then pruned by its retention.

## Consequences

Names and jargon the user fixes once are spelled right from the next dictation, with no engine or protocol change. A wrong guess costs one dictionary entry, tagged so it is easy to spot and delete. Numbers, grammar fixes and capitalized common words are not learned.

In a terminal, edits made with keys the replay doesn't model teach nothing: clicks, history and shell completion. So do fixes to text that was in the line before the paste.
