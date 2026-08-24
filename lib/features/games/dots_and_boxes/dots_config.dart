import '../../../core/game/game_module.dart';

/// Dots & Boxes setup: board size, two names, and who moves first.
class DotsConfig extends GameConfig {
  const DotsConfig({
    required this.size,
    required this.playerOne,
    required this.playerTwo,
    required this.firstPlayer,
    this.claimMarks = true,
  });

  /// Boxes per side: 4, 5 or 6.
  final int size;

  final String playerOne;
  final String playerTwo;

  /// 0 or 1 — resolved from the "Loser starts" default before the game opens.
  final int firstPlayer;

  /// The owner's initial inside a claimed box. On by default: the tint alone
  /// fails the light palettes, where both players' tints sit close together.
  final bool claimMarks;

  String nameOf(int player) => player == 0 ? playerOne : playerTwo;

  String get label => '$size×$size · $playerOne vs $playerTwo';

  /// Stat key so each board size keeps its own record.
  String get configLabel => '$size×$size';
}
