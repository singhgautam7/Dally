import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/games/chess/chess_module.dart';
import '../../features/games/fifteen_puzzle/fifteen_puzzle_module.dart';
import '../../features/games/game_2048/game_2048_module.dart';
import '../../features/games/memory/memory_module.dart';
import '../../features/games/minesweeper/minesweeper_module.dart';
import '../../features/games/snake/snake_module.dart';
import '../../features/games/sudoku/sudoku_module.dart';
import '../../features/games/tic_tac_toe/tic_tac_toe_module.dart';
import 'game_module.dart';

/// The single place games are wired into the app. Home, filtering, stats and
/// routing all derive from this list — nothing else references a game module
/// directly. Adding a game means appending its module here (and nowhere else).
///
/// Order is the home-grid order from the design.
final List<GameModule> kGameModules = <GameModule>[
  Game2048Module(),
  MinesweeperModule(),
  SudokuModule(),
  SnakeModule(),
  MemoryModule(),
  FifteenPuzzleModule(),
  TicTacToeModule(),
  ChessModule(),
];

/// Exposes the ordered module list to the widget tree.
final gameRegistryProvider = Provider<List<GameModule>>((ref) => kGameModules);

/// Looks up a module by its stable id, or null if unknown (e.g. a stale deep
/// link after a game is removed).
final gameByIdProvider = Provider.family<GameModule?, String>((ref, id) {
  for (final m in ref.watch(gameRegistryProvider)) {
    if (m.id == id) return m;
  }
  return null;
});
