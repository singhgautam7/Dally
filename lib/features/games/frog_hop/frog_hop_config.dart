import '../../../core/game/game_module.dart';
import 'logic/frog_hop.dart';

/// Race (two players, pass and play) or Puzzle (one player, no turn order).
enum FrogMode { race, puzzle }

extension FrogModeX on FrogMode {
  String get label => this == FrogMode.race ? 'Race' : 'Puzzle';
  String get caption =>
      this == FrogMode.race ? 'Two players' : 'Swap the sides on your own';
}

/// Frog Hop setup: how long the lane is, who is on which end, and who opens.
class FrogHopConfig extends GameConfig {
  const FrogHopConfig({
    required this.perSide,
    required this.mode,
    this.names = const ['Mira', 'Tom'],
    this.first = FrogSide.bottom,
  });

  /// Pieces a side: 3, 4 or 5. The lane is `perSide * 2 + gaps` cells.
  final int perSide;

  final FrogMode mode;

  /// Seat 0 is the bottom end, seat 1 the top.
  final List<String> names;

  final FrogSide first;

  /// Empty cells between the two blocks.
  ///
  /// The puzzle is the classic one-gap layout, where `n² + 2n` is the minimum.
  /// The race needs room: on a one-gap lane it cannot be won at all, and one
  /// player can be walled out on the first move. See [FrogHopGame.gaps].
  int get gaps => mode == FrogMode.puzzle ? 1 : 3;

  int get lane => perSide * 2 + gaps;

  String nameOf(FrogSide side) => names[side == FrogSide.bottom ? 0 : 1];

  String get label => mode == FrogMode.puzzle
      ? 'Puzzle · $perSide a side'
      : '$perSide a side · ${names.join(' vs ')}';

  /// Stat key, so each lane size keeps its own record.
  String get configLabel => '$perSide a side';
}
