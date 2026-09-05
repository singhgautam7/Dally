# Dally — engineering contract

The standing rules for every change in this repository. This file is the
authority; `specs/guidelines.md` (how to build) and `specs/performance.md`
(what it costs) are the long-form companions and stay true — where this file
and one of them disagree, this file wins and the other gets updated in the
same change.

Read it before writing code. Run the checklist (§14) before finishing.

---

## 1. Project constraints — non-negotiable

* **100% offline.** No network call, ever: no HTTP, no sockets, no remote
  config, no CDN font, no crash reporter, no update check. Everything a game
  needs is bundled in `assets/` or generated on device.
* **No analytics, no telemetry, no ads, no tracking, no account.** Nothing
  leaves the device. `PRIVACY_POLICY.md` says so and must stay true.
* **Bundled fonts only.** Space Grotesk and JetBrains Mono ship in
  `assets/fonts/`. Never `google_fonts`, never a `fonts.googleapis.com` link.
* **Token-only styling.** All colour from `DallyTokens` (`context.tokens`), all
  spacing from `Insets`, all radii from `Radii`, all type from `DallyType`. A
  raw `Color(0x…)`, a magic `EdgeInsets`, or an ad-hoc font size in a widget is
  a bug. Proportional geometry derived from a measured box (`cell * 0.14`) is
  responsiveness, not a magic number, and is encouraged.
* **All eight preset themes work, and every custom triple works.** Since the v4
  theme phase a palette is `palette(mode, accent, amoled)` — 2 modes × 10
  accents × AMOLED — and the eight named presets are triples on top of it. Every
  screen must be legible across all of them. The two that break things are
  AMOLED (surfaces vanish into the background — that is what
  `tokens.surfaceBorder` is for) and the light ones (tints collapse together).
* **Theme switching mid-game is instant and state-preserving.** No game state
  may live in a colour. A switch is a repaint: no board reset, no animation
  restart, no reflow, no clock reset.
* **Generic naming.** See §12.

### The exception register (literal colours)

Four sets of literal colours exist. All are deliberate and documented at their
definition. **Do not add a fifth without writing down why:**

1. `PlayerIdentity`'s four seat colours — a seat that changed hue with the theme
   would stop being an identity.
2. Chess's two piece colours — "white to move" is a rule, not a style.
3. Solitaire's card face and suit colours — "red suit" is a rule too.
4. `installErrorBoundary`'s fallback — it must render when the token layer
   itself is what failed.

---

## 2. Architecture and modularity

### 2.1 One registration point per game

Every game implements `GameModule` (`core/game/game_module.dart`) and is wired
in **exactly one place**: `kGameModules` in `core/game/game_registry.dart`.

Adding a game = a new folder under `lib/features/games/` + one registry line.
That lights up Home, Search, Filters, the catalogue counts, routing and Stats
with **zero edits to any of those screens**. If you find yourself editing Home,
Stats, Search or the filter sheet to make a game appear, something is wired
wrong — stop and fix the wiring.

### 2.2 Folder shape

```
lib/features/games/<game>/
  <game>_module.dart     the GameModule
  <game>_config.dart     the GameConfig the setup screen produces
  logic/                 pure Dart: rules, generation, scoring. No widgets.
  ui/                    setup_<game>_screen.dart, play_<game>_screen.dart,
                         <game>_painter.dart
```

The split is not decorative: **everything in `logic/` is unit-testable with a
seeded RNG and no `WidgetTester`.** No `package:flutter/material.dart` in a
logic core; `dart:ui`/`package:flutter/foundation.dart` for `Offset`, `Color`
or `@immutable` is acceptable, a widget is not.

### 2.3 Reuse before you create

Nearly every finding in the v3 audit was a game re-answering a question the app
had already answered. **Before you write a widget, grep `core/widgets/` for its
name.** If something close exists, extend it. If a second game needs what you
just wrote, it moves to `core/` **in the same change** — "later" is what
produced nine copies of the end-of-game strip.

The canonical shared modules:

**Chrome**
| Use | For |
|---|---|
| `GameScaffold` | Every board game's screen: status bar, board, controls, overflow, **undo**, back navigation. |
| `ArcadeScaffold` · `MentalMathScaffold` · `QuickPlayScaffold` | The three section shells. A game in one of those sections uses its shell instead of `GameScaffold`. |
| `showPauseSheet` | Pause. Games inject rows via `extraRows`; they never build a sheet. |
| `GameBackScope` / `leaveGame` / `showExitConfirm` | Leaving. §5. |
| `GameOverStrip` | The end of a game. |
| `showDallySheet` | **Every** bottom sheet. |
| `stylePickerRow` / `showStylePicker` | Per-game visual styles, one or more labelled rows. |
| `HowToContent` / `showHowTo` / `openHowTo` | How to play. |
| `SetupScaffold` | Every setup screen. |

**Controls & pieces**
`PrimaryPill` (`.secondary` · `.danger` · `enabled`) · `OverflowButton` ·
`UndoButton` · `RoundActionButton` · `CircularNumberPad` · `OptionStepper` ·
`InlineStepper` · `SegmentedSelector` · `DallyToggle` · `FilterChipPill` ·
`BoardChip` · `StatChip` · `PlayerNameRow` · `GameDie` / `DieView` ·
`GameGlyph` · `GenericPalettePreview` · `PlayerMark` / `PlayerStrip`.

**State, data & simulation**
| Use | For |
|---|---|
| `DallyRandom` via `randomProvider` | All randomness. §8. |
| `FixedStepLoop` / `RealTimeGameMixin` | Anything that advances on its own. §6. |
| `GameClock` | A game that times the player. |
| `MotionRunner` + `MotionPreset` | All animation. §4. |
| `UndoStack` (`core/game/undo.dart`) | All undo. §7. |
| `fitBoard` (`core/util/board_fit.dart`) | All grid-board sizing. §10. |
| `PlayerIdentity` / `paintPlayerToken` | All seats. §11. |
| `Expression` | Any arithmetic a game builds or checks. |
| `wordListProvider` | Any game that needs words. |
| `Sounds.play` · `Haptics` | Sound and vibration. |
| `KeyValueStore` / `SaveRepository` / `HistoryRepository` / `StatsRepository` | All persistence. §9. |
| `DallyLoading` · `DallyEmptyState` · `installErrorBoundary` | Loading, empty, error. |

### 2.4 Pure cores, separate rendering

Rules live in `logic/`. Painters read a core and draw it; they never own rules.
A painter must be constructible from a core plus colours, with no side effects
in `paint()`.

---

## 3. Theme: tokens, derivation and caching

### 3.1 The derivation

`palette(mode, accentId, amoled)` in `core/theme/palettes.dart` is a **pure,
synchronous function of three inputs** — no I/O, no cache, cheap enough to call
per build. Eight of the eleven tokens are a table lookup into one of three
neutral ramps (Light, Dark, Dark+AMOLED); `accent` is the identity's per-mode
resolved value; `onAccent` is computed by picking whichever of ink and white
scores higher against the accent. The 2048 ramp, the semantic `success`/
`danger` pair and the Minesweeper digits are accent-independent by
construction, which is what makes thirty combinations checkable as ten.

Adding an accent means adding one `DallyAccent` row. The contrast matrix test
(`test/theme/contrast_matrix_test.dart`) then walks every mode × accent ×
amoled triple and fails the build if accent-on-bg, onAccent-on-accent, or
success/danger drop under 4.5:1. **Do not add an accent without letting that
test measure it.**

Thresholds: 4.5:1 for anything with text in it, 3:1 for a graphical object that
carries meaning alone (the player tokens), and no threshold for hairlines and
tile fills — which are declared decorative and are held to the rule that **they
never carry state on their own.** A selected row gets accent plus a weight
change, not a darker line.

`textFaint` never carries information that appears nowhere else and never sits
below 11px. A value a player needs — a score, a timer, a count remaining — is
`textMuted` or above.

### 3.2 Theme caching — the rule

The palette function is cheap; **resolved painter styles are not.** A painter
that builds `Paint` objects, `TextPainter`s or gradient shaders per cell per
frame is the expensive path, and a theme switch is the moment those go stale.

* Cache anything derived from tokens that is (a) per-cell or per-frame and
  (b) more expensive than a field read — laid-out text above all. Cache by
  `(glyph, size, colour)` and reuse; never lay out a recurring string inside
  `paint()`.
* **Key the cache on the tokens that produced it** (the palette identity, or the
  colours themselves) so a theme switch invalidates it. A cache keyed on
  geometry alone silently keeps the old palette's colours after a switch — that
  is the bug this rule exists to prevent.
* Never key a `flutter_svg` picture cache on the theme: tint with `colorFilter`,
  never `SvgTheme(currentColor:)`. `SvgTheme` is part of the picture cache key,
  so it re-decodes every glyph on screen on every palette switch.
* Never capture a colour into an `AnimationController`, a `Tween` or a
  long-lived controller field. Read tokens in `build`/`paint`, so a mid-flight
  switch is a repaint and nothing more.
* A mid-game switch must be **cheap and state-preserving**: no game state in a
  colour, no board reset, no animation restart, no reflow, the clock keeps
  running. The board and the score must not animate on switch; other chrome may
  cross-fade at the theme cross-fade duration.

### 3.3 Shading

Shade toward `t.bg`, never toward literal black or white. "Darker" means
"toward the page", and the page is not always dark.

---

## 4. Motion

All animation goes through `MotionPreset` + `MotionRunner`
(`core/theme/motion.dart`). The vocabulary is closed:

| Preset | Means |
|---|---|
| `move` | A piece travelling between two places. |
| `settle` | A piece arriving and coming to rest. |
| `appear` / `remove` | Something entering or leaving the board. |
| `flip` | A card or tile turning over. |
| `pop` | Emphasis on place, merge or score. |
| `shake` | Rejection, or "look here". |
| `pulse` | A resting highlight breathing. |
| `countUp` | A score counting to its new value. |

Read the shaped value, not the raw 0→1: `flipScaleX`, `flipPastHalf`,
`popScale()`, `shakeOffset()`, `pulseAlpha`.

Flutter's implicit animations are allowed on one condition: **their duration and
curve come from `core/theme/motion.dart`, and the duration collapses to
`Duration.zero` under reduce motion.** A bare `AnimationController` with
hand-picked timings is not allowed; neither is an inline
`Duration(milliseconds: 140)`. The narrow exception is a bespoke run length no
beat describes (the bottle spinner's decay, a dice tumble) — those keep their
own duration and still collapse under reduce motion.

Every animation is:

* **Interruptible** — a superseded run completes its future at its end value and
  never dangles. The core is always authoritative; the animation only draws, so
  never await a run before applying game state.
* **Reduce-motion-aware** — read `reduceMotionEnabled(context, ref)` in `build`
  or `readReduceMotion(...)` in `initState`/`didChangeDependencies`. **Never
  `reduceMotionOf` alone**: that is the OS flag only and silently ignores
  Dally's own Settings toggle.
* **Theme-switch-safe** — §3.2.
* **Scoped** — inside a `RepaintBoundary`. A per-frame loop publishes through a
  `ValueNotifier` the painter listens to rather than `setState`-ing the screen.

No springs, bounce, 3D, particles, screen wipes, confetti, or sound-as-feedback.

---

## 5. Navigation and back

One shared behaviour, in one implementation. **Never write a `PopScope` in a
game.** `GameBackScope` is it, and `GameScaffold` and all three section shells
already wear it:

1. Flow is `Home → Setup → Play`; setup produces a `GameConfig` and pushes play
   with it as `extra`. Quick Play and Arcade have no setup — opening the game is
   starting it.
2. First system back mid-game → the pause sheet.
3. Back again → the leave confirmation → **Home**.
4. Back once the game has **ended** → straight Home; there is nothing to
   confirm.
5. The pause sheet's "Back to games" and any on-board equivalent both route
   through `leaveGame`.

**`leaveGame` is the only exit.** Not `context.pop()` (that lands on the game's
own setup screen), not `go(Routes.home)` (that skips the confirmation every
other game gives).

Pass `ended:` and `progressSaved:` truthfully. `progressSaved` only changes the
confirm copy, but a game that lies tells the player their board is gone when it
isn't. Confirm on exit whenever in-progress state would be lost.

When you open the pause sheet from the overflow yourself, call `notePauseSeen()`
so the *next* back offers to leave rather than re-opening the sheet.

---

## 6. Performance and stability

* **Boards are one `CustomPainter`.** Never one widget per cell past a trivial
  3×3. A 16×16 Minesweeper board is one painter.
* **Never lay out text inside `paint()` when the string recurs.** A
  `TextPainter` is a full shaping pass; cache by (glyph, size, colour). Measured:
  it halves `PAINT` on a large board.
* **Real-time games are frame-rate independent.** `FixedStepLoop` accumulates
  wall time and drains it in whole fixed steps (16ms); games integrate against
  the constant `dt` handed to `onStep`, never against real frame time. A long
  stall is capped, not fast-forwarded. Physics constants must also be
  **resolution-independent**: derive them from the measured arena (a scale
  factor, or normalised units), so a tablet is the same game at a larger scale
  rather than an unplayable one. Generated content must respect what the player
  can actually reach at that scale.
* **Dispose everything.** Every `AnimationController`, `Ticker`, `Timer`,
  `StreamSubscription` and `WidgetsBindingObserver` in `dispose()`.
* **A loop that stops on background must start again on resume.** Do not
  hand-roll it: `GameClock` and `RealTimeGameMixin.handleLifecycle` both already
  remember whether they were running. Pause for sheets with `pauseForUi()` and
  resume with `resumeFromUi()` — a game must not play on behind its own pause
  sheet.
* **Persistence never blocks the frame.** Writes are async and debounced, never
  awaited inside a gesture handler, never per-frame.
* **Stats are aggregate queries.** Every number on the Stats overview and the
  per-game pages comes from the rollup, whose cost does not grow with play
  history. **Never load the full session log to compute a number** — add it to
  the rollup instead. Only the Activity screen reads sessions, and it pages.
* Derived whole-board values (a conflict set, a legal-move map, a score
  breakdown) are computed **on mutation and cached**, never recomputed in
  `build`.
* `const` wherever the analyzer allows; `RepaintBoundary` around anything that
  repaints independently; Riverpod reads granular
  (`ref.watch(p.select((s) => s.field))`).
* **Profile before optimising the UI thread.** Measured on this app, `BUILD`
  runs at a 0.03ms median. `specs/performance.md` §5a has the numbers.

---

## 7. Undo, and record integrity

### 7.1 The control

One control, one place, one behaviour: `UndoButton`, rendered by `GameScaffold`
in the chrome's top-right, immediately left of the overflow, at the same ghosted
weight. A game opts in by passing `onUndo`/`canUndo`; a game that does not pass
them shows nothing. **A missing control is quieter than a permanently dead one.**

Three states: available (icon in the text colour, hairline ring), nothing to
undo (whole control dimmed, not tappable, never hidden), pressed (a brief accent
tint). The control never carries a number — a count would make the cap read as a
resource to spend.

### 7.2 The stack

`UndoStack<S>` (`core/game/undo.dart`) holds **at most five** snapshots, oldest
dropped silently. One tap is one step; there is no press-and-hold. The stack
clears on a new game, on a restart, and **the moment a game ends** — a finished
board cannot be un-finished. On a two-seat board the control is also disabled
while it is not your turn: the last move belongs to the other seat.

Where it applies: Solitaire, 2048, Sudoku, Dots & Boxes, Frog Hop,
Four-in-a-Row. Where it does not, and where no control appears: everything
real-time (Arcade, Reaction), everything with hidden state a rewind would leak
(Minesweeper, Memory, Undercover), and everything where the move is the answer
(the Mental Math drills).

### 7.3 Record-integrity policy — binding

Undo must never silently inflate a leaderboard or a stat.

1. **Stats and records are written at the end of a game, from the final state**,
   never accumulated per move. An undone move therefore cannot double-count.
2. **A session that used undo is flagged.** The flag rides with the session
   (`usedUndo`) and is recorded with it.
3. **A flagged session does not set a "clean" record** — best time, best score,
   fewest moves, clean-solve streaks. It still counts as a game played, still
   counts toward wins/losses and play time, and still appears in history. It is
   excluded only from the records that a rewind would corrupt.
4. **The cap is the second guard.** Five steps bounds both the damage and the
   state a save file has to carry.
5. Timed games keep counting during an undo. The stack is part of the save file,
   so backgrounding and returning keeps it; closing the game does not.

If a game adds a new record-shaped metric, it states explicitly whether the
`usedUndo` flag excludes it. Silence is not a default.

### 7.4 Motion

An undone move plays its own motion in reverse at the same duration — a disc
rises out of a column, a card returns to its pile — so the board never jumps.
Reduce Motion replaces the reverse animation with the destination state plus one
brief highlight on whatever moved.

---

## 8. Randomness

* **One source:** `DallyRandom`, injected as `randomProvider`. Not
  `math.Random()`, not `Random.secure()` directly, and above all **not a
  `Random? rng` parameter with a `?? Random()` fallback** — that lets a call site
  omit the argument, compile, read as correct, and be silently unseedable.
* A core takes its RNG as a constructor argument. **Every production call site
  passes it explicitly**, including previews on setup screens.
* Use the unbiased helpers: `nextInt`, `range` (inclusive both ends), `pick`,
  `shuffle`, `sample`. Never `% n` on a raw draw.
* Every generator gets a test with `DallyRandom.seeded(n)`. A puzzle that cannot
  be reproduced from a seed cannot be regression-tested. Test the *screen* too,
  not just the core — it was the screens that dropped the seed.

---

## 9. Persistence and stats

* All I/O through `KeyValueStore`, which guards every read and write and returns
  a fallback on corruption. A corrupt save is discarded and a fresh game
  offered — never a crash, never a red screen.
* Keys separated by concern: `settings` · `save.<gameId>` · `history.sessions` ·
  `history.rollup`. A growing history cannot slow a settings write.
* **Every persisted structure carries `schemaVersion`.** On read, a newer version
  is discarded to defaults; an older one is migrated or discarded. Never crash.
  A migration that changes the *shape* of a setting (one key becoming three)
  runs once, writes the new keys, and leaves the old key in place for one
  release so a downgrade survives.
* Sessions written with `recordSession`, never an ad-hoc counter.
* **Per-game stat schemas are data, declared by the module.** A module returns
  `List<StatBlock> statBlocks(GameAggregate)`; the Stats screen renders whatever
  comes back and switches only on block *kind*, never on a game id. Adding a
  game requires **zero** edits to the Stats screen. An unearned metric renders
  `—`, never a zero.
* Saves are debounced, not written per move, and never awaited in a gesture
  handler.

---

## 10. Board fitting

**One fitter, used by every grid game:** `fitBoard` in
`core/util/board_fit.dart`.

```
cell = clamp(floor, min(availW / cols, availH / rows), cap)
```

Take the available width and height inside the safe area, divide by the column
and row counts, take the **smaller** of the two scales, clamp between a floor
and a cap, and centre what comes out. Nothing in game code knows a pixel size.

* **Non-square and any-orientation grids are first-class.** A 10 × 6 and a 6 × 10
  are both legal and both fill the screen properly. Never assume `rows == cols`.
* Below the floor the board scrolls rather than shrinking past a usable touch
  target.
* Landscape needs no special case: width and height swap, the board re-derives
  its cell, and the surrounding chrome moves from above the board to the side.
* No fixed pixel board sizes, anywhere.

---

## 11. Player identity and seats

Any game with two or more seats uses the shared system.

* `identitiesFor(n)` gives the seats — **chosen** subsets, not truncations, so a
  two-player game never gets the pair that collapses for the most common
  colour-vision deficiency.
* `paintPlayerToken` draws a seat on a board; `PlayerMark` / `PlayerStrip` draw
  one in the widget layer. These are the only places a seat is drawn.
* **Colour is never the only channel.** Each identity carries a shape, and the
  shape is what survives greyscale and colour-vision deficiency. Shapes are
  non-optional in Light.
* **In Light mode the one-step-darker hairline around a seat token is
  mandatory**, not a refinement: two of the four fixed fills sit under 3:1
  against the light background, and the hairline is what carries the edge. The
  fills themselves never move — they are shared with saved games and
  screenshots.
* Seat colours are fixed and do **not** follow the palette (§1, exception 1).
* Token styles come through the shared style picker (geometry only, never a
  second colour scheme).
* The score row carries every seat; the active one is full strength and the rest
  sit dimmed. Turn order is seat order. A tie is declared as a tie, listing
  every seat on the top score.

---

## 12. Naming and trademark safety

Generic, descriptive names only — in ids, titles, taglines, tags, asset
filenames, store metadata and every user-visible string. The games are
"15-puzzle", "Dots & Boxes", "Snakes & Ladders", "Memory", "Undercover",
"Four-in-a-Row", "Frog Hop", "Updraft".

**Do not use**, in code or copy: any trademarked game title or its close
lexical variants, a trademarked piece or character name, a publisher's wording
or tagline, or a name that reads as "the X clone". In particular do not name or
allude to: the bird-flapping mobile game, the tile-matching franchises, the
falling-block puzzle, the doodle-jumping platformer, the werewolf/mafia party
brands, or any specific board-game publisher's edition.

`test/core/catalogue_test.dart` enforces this against a deny-list, and it earns
its keep: the v4 design canvas called the one-tap flyer "Flappy Token", the test
refused it, and it shipped as **Updraft**. A design's working title does not
override this rule — fix the name and note it in the handoff.

A game id, once shipped, is a permanent key for stats, history and saves.
Renaming one is a migration, not an edit — see §9, and
`docs/undercover-migration.md` for the worked example.

---

## 13. Testing

* **Logic cores are tested without a widget tree.** `logic/` takes its RNG by
  injection, so its tests are fast, deterministic and complete.
* Rule-heavy logic gets exhaustive tests: legality, win/draw detection,
  generation validity, scoring, board-boundary edge cases.
* Generators are tested with `DallyRandom.seeded(n)`, asserting invariants
  across many seeds.
* **No test depends on the wall clock or on UI timing.** Drive `FixedStepLoop`
  with `feed()`; drive tickers with `tester.pump(duration)`. A test that sleeps,
  or that asserts on a real elapsed duration, is a flake waiting to happen.
* Screen tests use `pumpGameScreen` (seeded RNG, real palette) or
  `pumpGameRoute` (adds a router with Home on the stack, so "back to games" can
  be *observed* landing on Home). Lay every new board out at 320×568 — the size
  where boards overflow.
* Shared components are tested once, where they live, not once per caller.
* A fixed bug gets a test that would have caught it.
* `flutter analyze` clean and `flutter test` green before every merge.
* **Do not run `dart format` on this repository.** It is hand-formatted; the
  formatter rewrites whole files and buries the real change.

---

## 14. Per-change checklist

**Reuse**
- [ ] Nothing here duplicates something in `core/` — I grepped before writing.
- [ ] Anything a second game will need has moved to `core/`, in this change.

**Architecture**
- [ ] The game is registered in exactly one place; no shell screen was edited.
- [ ] Rules are in `logic/`, with no widget import.

**Navigation**
- [ ] No `PopScope` outside `GameBackScope`; no `pop()` / `go(home)` as an exit.
- [ ] Every exit goes through `leaveGame`, with `ended`/`progressSaved` truthful.
- [ ] Controllers, tickers, timers and observers disposed.
- [ ] Loop/clock pauses on background **and resumes**; pauses for sheets.
- [ ] A sheet with a variable row list scrolls.

**Theme & motion**
- [ ] No literal colour, radius, or spacing; new text takes a scale style.
- [ ] Anything derived from tokens and reused per cell/frame is cached, and the
      cache is keyed so a theme switch invalidates it.
- [ ] Checked in AMOLED and at least one light palette; a mid-game switch keeps
      the board, the score and the clock.
- [ ] Every duration and curve comes from a `MotionPreset`; reduce motion read
      via `reduceMotionEnabled` / `readReduceMotion` and collapses to instant.

**Data**
- [ ] Randomness through `randomProvider`; ranges unbiased; seeded test present.
- [ ] `schemaVersion` present; corruption → fresh, not a crash.
- [ ] Sessions via `recordSession`; stats via the module's `statBlocks`, read
      from the rollup, never the session log.
- [ ] If the game supports undo: the stack is capped at five, cleared on
      new/restart/end, and `usedUndo` excludes the session from clean records.

**Craft**
- [ ] Board sizing goes through `fitBoard`; non-square and landscape verified.
- [ ] Responsive from 320×568 to a tablet, both orientations, at large text
      scale.
- [ ] Empty / error / loading states present.
- [ ] No trademarked name anywhere.
- [ ] Tests added — including one that would have caught the bug being fixed.
- [ ] `flutter analyze` clean, `flutter test` green.

---

## 15. Recipe — how to add a new game

1. **Make the folder** in the shape of §2.2.
2. **Write the rules core first**, in `logic/`, with the RNG injected. Test it
   before any widget exists.
3. **Implement `GameModule`**: `id` (permanent), `title`, `tagline`, `category`,
   `tags`, `playerCount`, `typicalLength`, `buildSetupScreen`,
   `buildPlayScreen`, `buildHowToPlay`, `statBlocks`, and `styleOptions` if the
   game has styles.
4. **Declare the stats schema in the module**, never in the Stats screen.
5. **Add the glyph** at `assets/glyphs/<id>.svg`; the filename matches the id.
6. **Register it** — append to `kGameModules`. That is the only edit outside
   your folder.
7. **Build the setup screen** on `SetupScaffold`, with the shared controls; it
   produces a `GameConfig` and pushes play.
8. **Build the play screen** on `GameScaffold` (or the section shell), with
   `showPauseSheet`, `GameOverStrip`, `leaveGame`, `fitBoard` for the board, and
   `onUndo`/`canUndo` if undo applies.
9. **Adopt Motion natively** — no bare controllers, reduce-motion honoured from
   the first commit.
10. **Record the session** with `recordSession`, including `usedUndo` where the
    game supports undo.
11. **Write the tests**: the core with a seeded RNG, plus a screen test at
    320×568.
12. **Run the checklist** (§14).
