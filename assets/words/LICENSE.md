# Word list provenance

Both files are bundled with the app and are never fetched at runtime — the
word games, like every other game in Dally, work with the radio off.

## `dictionary.txt` — 76,107 words, the validation list

Derived from **`/usr/share/dict/web2`**, the word list shipped with macOS and
the BSDs. It is *Webster's Second International Dictionary* (1934); its
copyright has lapsed and the list is in the **public domain**. The file's own
`README` (`/usr/share/dict/README`) states this: "The 1934 copyright has lapsed,
according to the supplier."

Regenerate with `python3 tool/build_dictionary.py`, which:

1. keeps entries matching `[a-z]{3,8}` — lowercase only, so proper nouns,
   abbreviations and hyphenated phrases drop out;
2. unions in `answers.txt`, so every puzzle word is also a valid guess and the
   handful of post-1934 words in it (laptop, cookie) are accepted from players;
3. sorts, so the output is byte-identical between runs.

Public domain means no attribution string is required in the app. This file
records the provenance regardless.

## `answers.txt` — 851 words, the puzzle list

Hand-written for Dally: common English words of 4–8 letters, ordered roughly
most-familiar first. Ordering *is* the difficulty signal — a game asking for an
easy word draws from the head of the list, a hard one from the tail.

A short list of common English words is not a creative work anyone owns; it was
written for this project and carries no upstream licence. It is deliberately
finite: there is no ongoing authoring step and nothing to keep updated.

The invariants (4–8 letters, no duplicates, every answer present in
`dictionary.txt`) are enforced by `test/games/word_list_test.dart`, not by
convention.
