import '../../../core/game/game_module.dart';

/// Snakes & Ladders setup: board size and seats. The link map itself is drawn
/// fresh from the seedable RNG when the game opens.
class SnakesConfig extends GameConfig {
  const SnakesConfig({
    required this.playerCount,
    required this.names,
    required this.side,
  });

  final int playerCount;
  final List<String> names;

  /// Squares per side: 6, 8 or 10.
  final int side;

  String nameOf(int player) => names[player];

  int get squares => side * side;

  String get label => '$side×$side · $playerCount players';

  String get configLabel => '$side×$side';
}
