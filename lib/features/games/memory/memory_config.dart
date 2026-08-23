import '../../../core/game/game_module.dart';

/// Memory setup: grid dimensions (rows × cols, even total).
class MemoryConfig extends GameConfig {
  const MemoryConfig({required this.rows, required this.cols});
  final int rows;
  final int cols;

  int get pairs => rows * cols ~/ 2;
  String get label => '$cols×$rows';
}
