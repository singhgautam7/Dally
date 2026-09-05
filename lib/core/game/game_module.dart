import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/stat_aggregate.dart';
import '../storage/stats_repository.dart';
import '../widgets/how_to_play.dart';
import 'game_category.dart';
import 'game_stats_schema.dart';

export 'game_stats_schema.dart' show StatFormat, StatBlock, StatCell, StatBar;

/// A selectable visual style for a game (chess pieces, coin faces, dice pips,
/// arcade skins), surfaced in the pause sheet where [GameModule.styleOptions]
/// is non-empty. A style changes *geometry only* — it never picks a colour, so
/// every style is guaranteed to work in all eight palettes.
@immutable
class StyleOption {
  const StyleOption({required this.id, required this.label, this.recommended = false});

  final String id;
  final String label;

  /// Carries the REC pill in the picker.
  final bool recommended;
}

/// One labelled row of styles in the picker, with its own persistence key.
///
/// Most games have exactly one row and never build a group by hand — the
/// default [GameModule.styleGroups] wraps [GameModule.styleOptions] in one.
/// A game with more than one thing worth styling (Jumper's character *and* its
/// platforms) declares them here, and each row is remembered separately.
@immutable
class StyleGroup {
  const StyleGroup({required this.id, required this.label, required this.options});

  /// Empty for a game's primary row, which keeps the bare `gameId` key so no
  /// existing player's choice is orphaned. Any other row is stored under
  /// `gameId.groupId`.
  final String id;

  /// What the row is called: "Character", "Platforms", "Piece".
  final String label;

  final List<StyleOption> options;

  /// The recommended option where there is one, else the first.
  String? get defaultId {
    if (options.isEmpty) return null;
    for (final o in options) {
      if (o.recommended) return o.id;
    }
    return options.first.id;
  }
}

/// Opaque, per-game configuration produced by the setup screen and handed to
/// the play screen. Each game defines its own subclass.
@immutable
abstract class GameConfig {
  const GameConfig();
}

/// The contract every game implements so it slots into the registry with no
/// shell edits. Adding a game = add its folder + register the module.
abstract class GameModule {
  /// Stable key for stats, history and saves; never change once shipped.
  String get id;

  String get title;

  /// Single-colour mark for the home tile (uses `currentColor`).
  Widget buildGlyph(BuildContext context);

  Set<PlayerMode> get players;
  Set<Vibe> get vibes;

  /// One-line summary shown on the tile / setup screen.
  String get tagline;

  // ── Catalogue metadata (drives home sections, search and filters) ──────────

  /// The catalogue category. Its [GameCategory.section] decides which labelled
  /// band of home the game appears in.
  GameCategory get category;

  /// How many bodies the game needs, for the Players filter.
  PlayerCount get playerCount =>
      players.contains(PlayerMode.passAndPlay) ? PlayerCount.two : PlayerCount.solo;

  /// Roughly how long a session runs, for the "A game takes" filter.
  GameLength get typicalLength => GameLength.medium;

  /// Extra searchable terms — synonyms, mechanics, the things people actually
  /// type. Never a trademarked name.
  List<String> get tags => const [];

  // ── Screens ───────────────────────────────────────────────────────────────

  /// The screen home pushes into. For most games that is the setup screen
  /// (options → Start). Quick Play and Tiny Arcade have no setup step, so they
  /// return their play screen directly — opening the game *is* starting it.
  Widget buildSetupScreen(BuildContext context, WidgetRef ref);

  /// The play screen for a concrete [config].
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config);

  bool get supportsSaveResume;

  /// Optional How-to-play sheet content (goal, board legend, controls). Shown
  /// from both the setup link and the pause row via [showHowTo].
  HowToContent? buildHowToPlay(BuildContext context);

  /// Style sets for the pause-sheet picker; empty when the game has none, in
  /// which case the row is omitted entirely rather than disabled.
  List<StyleOption> get styleOptions => const [];

  /// Default style id when the game has [styleOptions] — the recommended one
  /// where there is one, else the first.
  String? get defaultStyleId {
    if (styleOptions.isEmpty) return null;
    for (final s in styleOptions) {
      if (s.recommended) return s.id;
    }
    return styleOptions.first.id;
  }

  /// What the picker calls the thing being styled: "Piece", "Coin", "Dice".
  String get styleNoun => 'Style';

  /// The picker's rows. One row is the common case and comes for free from
  /// [styleOptions]; override only to offer more than one.
  List<StyleGroup> get styleGroups => styleOptions.isEmpty
      ? const []
      : [StyleGroup(id: '', label: styleNoun, options: styleOptions)];

  // ── Statistics (declared by the game, rendered by the shell) ───────────────

  /// The game's own stats page, built from its rolled-up [agg]. The Stats
  /// screen renders whatever comes back and knows nothing about any specific
  /// game — a new module's analytics section appears with zero shell edits.
  ///
  /// The default gives every game a sensible page from the metrics the shell
  /// records for free (sessions, play time, score); override to add the ones
  /// only this game understands.
  List<StatBlock> statBlocks(GameAggregate agg) {
    final score = agg.metric('score');
    return [
      if (!score.isEmpty)
        StatBlock.hero(
          title: 'Best score',
          cell: StatCell.metric('Best score', score, StatFormat.number,
              higherIsBetter: true, accent: true),
        ),
      StatBlock.cells(cells: [
        StatCell.count('Games', agg.sessions),
        StatCell.average('Average', score, StatFormat.number),
        StatCell('Play time', StatFormat.duration.render(agg.seconds),
            earned: agg.seconds > 0),
      ]),
    ];
  }

  /// One mono line for the "By game" row on the Stats overview. Null hides it.
  String? statSummary(GameAggregate agg) {
    final best = agg.metric('score').best(higherIsBetter: true);
    if (best == null) return null;
    return 'Best ${StatFormat.number.render(best)}';
  }

  /// The best-score line for the home tile, formatted by the game from its own
  /// namespaced stats. Returns null when there's nothing to show yet.
  String? homeBestLabel(StatsRepository stats) => null;

  /// The tile subtitle — the game's vibes joined, e.g. `"Brain teaser · Leisure"`.
  String get vibeLabel => vibes.map((v) => v.label).join(' · ');
}
