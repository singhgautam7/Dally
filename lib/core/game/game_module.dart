import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/stats_repository.dart';
import '../widgets/how_to_play.dart';
import 'game_category.dart';

/// How a stat should be read and formatted on the Stats screen.
enum StatFormat {
  /// Whole number (score, moves, length).
  number,

  /// Elapsed time in seconds, shown `mm:ss`.
  duration,

  /// A 2048 tile value.
  tile,

  /// Win / loss / draw record.
  record,
}

/// Declares one tracked statistic for a game. The [key] is namespaced under the
/// game id by the shell (`"<gameId>.<key>"`). [variantKeys] enumerates
/// per-difficulty/per-size sub-keys so "best time" can exist per difficulty.
@immutable
class StatSpec {
  const StatSpec({
    required this.key,
    required this.label,
    required this.format,
    required this.higherIsBetter,
    this.variantLabels = const {},
  });

  final String key;
  final String label;
  final StatFormat format;
  final bool higherIsBetter;

  /// Optional map of `variantKey` → human label (e.g. `expert` → `Expert`).
  final Map<String, String> variantLabels;
}

/// A selectable visual style for a game (chess pieces, mine/flag sets, snake
/// skins), surfaced in the pause sheet where [GameModule.styleOptions] is
/// non-empty.
@immutable
class StyleOption {
  const StyleOption({required this.id, required this.label});

  final String id;
  final String label;
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
  /// Stable key for stats and saves; never change once shipped.
  String get id;

  String get title;

  /// Single-colour mark for the home tile (uses `currentColor`).
  Widget buildGlyph(BuildContext context);

  Set<PlayerMode> get players;
  Set<Vibe> get vibes;

  /// One-line summary shown on the tile / setup screen.
  String get tagline;

  /// The setup screen: options → Start. Returns to the play screen via routing.
  Widget buildSetupScreen(BuildContext context, WidgetRef ref);

  /// The play screen for a concrete [config].
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config);

  /// What "best" means for this game.
  List<StatSpec> get statSpecs;

  bool get supportsSaveResume;

  /// Optional How-to-play sheet content (goal, board legend, controls). Shown
  /// from both the setup link and the pause row via [showHowTo].
  HowToContent? buildHowToPlay(BuildContext context);

  /// Style sets for the pause-sheet picker; empty when the game has none.
  List<StyleOption> get styleOptions => const [];

  /// Default style id when the game has [styleOptions].
  String? get defaultStyleId =>
      styleOptions.isEmpty ? null : styleOptions.first.id;

  /// The best-score line for the home tile, formatted by the game from its own
  /// namespaced stats (e.g. `"Best 11 264"`, `"01:16 · Beginner"`). Returns
  /// null when there's nothing to show yet, and the tile omits the line.
  String? homeBestLabel(StatsRepository stats) => null;

  /// The tile subtitle — the game's vibes joined, e.g. `"Brain teaser · Leisure"`.
  /// Relies on [vibes] being an insertion-ordered set literal.
  String get vibeLabel => vibes.map((v) => v.label).join(' · ');
}
