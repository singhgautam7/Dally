# Mafia → Undercover: what happened to the stats

## The rename

The game that shipped as **Mafia** was never Mafia — it had no night phase, no
roles beyond two, and the whole thing turned on a word. It is **Undercover**,
and it is renamed everywhere: module id, title, tagline, tags, glyph asset,
setup and pause titles, how-to sheet, search index, saved-group key, and the
stats page.

The module id went from `mafia` to `undercover`.

## The stats decision: **reset**, deliberately

A game id is a permanent key for history, stats and saves, so renaming one is a
migration rather than an edit. Two options were on the table:

1. **Carry the old rows over** under the new key — a player's Mafia record
   becomes their Undercover record.
2. **Reset** — the old rows stay in history under `mafia` and age out with the
   200-session cap; Undercover starts from zero.

**We reset.** The per-game metrics do not map:

| Mafia recorded | Undercover records | Maps? |
|---|---|---|
| `villagerWins` | `civilianWins` | Name-wise yes, but the win condition changed: villagers won by finding every *imposter*, civilians win by finding every Undercover **and Mr. White**. |
| `imposterWins` | `undercoverWins` | Same problem, from the other side. |
| — | `mrWhiteWins` | A role that did not exist. |
| — | `whiteGuesses`, `whiteGuessLanded` | A mechanic that did not exist. |
| `rounds` | `rounds` | A Mafia round included a night phase. The number means something different. |
| `asVillager`, `asImposter` | — | Never populated; dropped. |

Carrying the rows over would have produced a "Who won" chart in which the
Civilians bar silently included games won under a different rule, and a
"Mr. White's last chance" block whose denominator was wrong from the first day.
A record you cannot explain is worse than one that starts today.

## What that means in practice

* Old `mafia` sessions remain in the session log until they age out of the
  200-row retention cap. They are not deleted, not rewritten, and not shown
  under Undercover.
* The Stats overview derives its "By game" rows from the registry, and `mafia`
  is no longer registered — so the old rows simply stop being surfaced. Nothing
  crashes on them: `gameByIdProvider` returns null for an unregistered id, which
  is the same path a removed game already took.
* Undercover's own aggregate starts empty, and every number on its page reads
  `—` until it is earned.
* The saved-group blob moved from `save.mafia` to `save.undercover`. The old
  key is left in place rather than deleted; it is a few dozen bytes and
  removing it buys nothing.

## The word data

Mafia's dataset was `{word, hint, band}` — a secret word and a *category* the
imposter saw instead. Undercover needs `{civilian, undercover, band}`: two real
words, near each other. That is a different shape and different content, so the
old list was replaced rather than converted.

The new bank is original editorial content written for this app — no scraped
list, no third-party dataset, no network path — and it ships under the project's
own licence. Provenance and the invariants that hold it together live at the top
of `lib/features/games/undercover/data/undercover_words.dart` and in
`test/games/undercover_words_test.dart`.
