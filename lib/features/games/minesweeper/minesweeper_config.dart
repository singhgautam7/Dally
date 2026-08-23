import '../../../core/game/game_module.dart';

enum MineDifficulty {
  beginner('Beginner', 9, 9, 10),
  intermediate('Intermediate', 16, 16, 40),
  expert('Expert', 30, 16, 99),
  custom('Custom', 12, 12, 24);

  const MineDifficulty(this.label, this.width, this.height, this.mines);
  final String label;
  final int width;
  final int height;
  final int mines;
}

/// Minesweeper setup: dimensions, mine count, and the guess-free toggle. For
/// preset difficulties width/height/mines come from [difficulty]; Custom uses
/// the explicit values.
class MinesweeperConfig extends GameConfig {
  const MinesweeperConfig({
    required this.difficulty,
    required this.width,
    required this.height,
    required this.mines,
    required this.guessFree,
  });

  final MineDifficulty difficulty;
  final int width;
  final int height;
  final int mines;
  final bool guessFree;

  String get label =>
      '${difficulty.label} · $width×$height · $mines mines${guessFree ? ' · guess-free' : ''}';

  /// Stat key so each difficulty keeps its own best time.
  String get statKey => difficulty == MineDifficulty.custom
      ? 'custom.${width}x${height}x$mines'
      : difficulty.name;
}
