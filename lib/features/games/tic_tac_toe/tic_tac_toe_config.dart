import '../../../core/game/game_module.dart';

/// Tic-tac-toe setup: board size, in-a-row length to win, and who moves first.
class TicTacToeConfig extends GameConfig {
  const TicTacToeConfig({
    required this.size,
    required this.winLength,
    required this.firstPlayer,
  });

  final int size;
  final int winLength;

  /// 1 (X) or 2 (O).
  final int firstPlayer;

  String get label => '$size×$size · $winLength in a row';
}
