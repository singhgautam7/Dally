import '../../../core/game/game_module.dart';

/// 2048 setup choices: just the board size (3–6).
class Game2048Config extends GameConfig {
  const Game2048Config({required this.size});
  final int size;

  String get label => '$size×$size';
}
