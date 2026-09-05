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

  /// Pieces a side: 3, 4 or 5. The lane is `perSide * 2 + 1` cells.
  final int perSide;

  final FrogMode mode;

  /// Seat 0 is the bottom end, seat 1 the top.
  final List<String> names;

  final FrogSide first;

  int get lane => perSide * 2 + 1;

  String nameOf(FrogSide side) => names[side == FrogSide.bottom ? 0 : 1];

  String get label => mode == FrogMode.puzzle
      ? 'Puzzle · $perSide a side'
      : '$perSide a side · ${names.join(' vs ')}';

  /// Stat key, so each lane size keeps its own record.
  String get configLabel => '$perSide a side';
}
