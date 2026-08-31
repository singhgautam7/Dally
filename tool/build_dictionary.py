#!/usr/bin/env python3
"""Regenerates assets/words/dictionary.txt — the offline validation list.

Source: /usr/share/dict/web2, shipped with macOS and the BSDs. It is Webster's
Second International (1934), whose copyright has lapsed; the file's own README
states as much. Public domain, so it can be bundled without attribution
strings, though assets/words/LICENSE.md records the provenance anyway.

Filtering: lowercase a-z only (which drops proper nouns and abbreviations) and
3-8 letters, the range the word games actually use, unioned with the curated
answers.txt so every puzzle word is also a valid guess. Everything is sorted so
the output is byte-identical between runs and diffs stay readable.

Run:  python3 tool/build_dictionary.py
"""
import re
from pathlib import Path

SOURCE = Path("/usr/share/dict/web2")
ASSETS = Path(__file__).resolve().parent.parent / "assets" / "words"
OUT = ASSETS / "dictionary.txt"
ANSWERS = ASSETS / "answers.txt"

def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"{SOURCE} not found — this script needs a BSD/macOS host")
    pattern = re.compile(r"[a-z]{3,8}\Z")
    words = sorted({
        line.strip()
        for line in SOURCE.read_text(encoding="utf-8", errors="ignore").splitlines()
        if pattern.match(line.strip())
    })
    # The curated answer list is folded in so every puzzle word validates, and
    # so the handful of post-1934 words it contains (laptop, cookie) are
    # accepted from players too.
    words = sorted(set(words) | {w.strip() for w in ANSWERS.read_text().splitlines() if w.strip()})
    OUT.write_text("\n".join(words) + "\n", encoding="utf-8")
    print(f"{len(words)} words -> {OUT} ({OUT.stat().st_size // 1024} KB)")

if __name__ == "__main__":
    main()
