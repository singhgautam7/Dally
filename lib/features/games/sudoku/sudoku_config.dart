import '../../../core/game/game_module.dart';
import 'logic/sudoku.dart';

/// Sudoku setup: difficulty.
class SudokuConfig extends GameConfig {
  const SudokuConfig({required this.difficulty});
  final SudokuDifficulty difficulty;

  String get label => difficulty.label;
}
