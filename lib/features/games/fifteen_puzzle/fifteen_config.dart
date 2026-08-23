import '../../../core/game/game_module.dart';

/// 15-puzzle setup: board side (3–5).
class FifteenConfig extends GameConfig {
  const FifteenConfig({required this.size});
  final int size;

  String get label => '$size×$size';
}
